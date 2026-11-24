-- The ring: one radial menu for every wheel (Wheel.lua's secure wheels, and WoW
-- Companion's chat wheel, through the global SimpleControllerRing). Our art in Forever's
-- radial style, eight slots or four (top first, clockwise), the right stick aiming, taken
-- while it is up (the camera stays put) and held a moment after it closes if
-- still pushed (so the camera does not swing); the left stick always walks.
-- Adapted from Improved Forever's Ring.lua by markg, MIT licence (see
-- LICENSE-ImprovedForever).
--
-- Only the look and the aim live here; what a slot does is its owner's (Wheel.lua's
-- secure buttons). Nothing here is secure, so it may be built on
-- a secure frame; it is built at load, out of combat.
--
--   local r = SimpleControllerRing.Build(frame, { prompts = { { key, text }, ... } })   frame: the
--                             owner's; prompts are the controller's own glyphs, under the wheel
--   r:Open(note, entries, four, names)  note: shown under the wheel while nothing is aimed
--                             at (nil: nothing); names: slots show their labels, else icons
--                             alone; entries: up to SimpleControllerRing.PAGE of { label, icon,
--                             count, spellID, itemID }, or with `four` up to four
--                             (up, right, down, left) on the four-way art; each gets
--                             dx, dy, angle (its segment); count (text) shows on the icon as
--                             on a bar button, and a spell's or item's cooldown
--                             (the global one too) sweeps it while the ring is up
--   r:Aim(entries, sticky)    in the owner's OnUpdate: lights what the right
--                             stick points at, else `sticky`; returns it
--   r:Picked(entries)         the slot the right stick points at, or nil
--   SimpleControllerRing.Direction(i, four)  slot i's segment: dx, dy, angle
--
-- A page is SimpleControllerRing.PAGE slots; owners that page (Later in docs/PLAN.md) open
-- the ring again with the next page's entries.

local _, SW = ...
local Ring = {}
SimpleControllerRing = Ring
Ring.PAGE = 8
Ring.built = {} -- every ring built, for the cooldown events

local WIDTH, HEIGHT = 540, 541 -- Forever's GamepadRadial, measured by Improved Forever
local SCALE = 0.8 -- the wheel's body; the words under it stay full size
local UNDER_GAP = 10
-- Where the wheel's painted edge ends below its centre; the art has clear margin.
local EDGE = 221
local ICON_SIZE = 45 -- Blizzard's segment icon size
local PICK_SQ = 0.25
local RELEASE_SQ, RELEASE_MAX = 0.04, 0.5

-- Slot i sits in direction i, from the top, clockwise: eight on the cardinals and
-- diagonals, or four on the cardinals (a four-way wheel); a ring of three uses three.
function Ring.Direction(index, four)
	local angle = math.pi / 2 - (index - 1) * math.pi / (four and 2 or 4)
	return math.cos(angle), math.sin(angle), angle
end

-- Our art (tools/make_ring_art.py): one piece per wheel, at rest and lit, the top
-- one, turned into place for each direction.
local ART = "Interface\\AddOns\\SimpleController_Wheels\\Art\\"
local ART_SIZE, REACH, LABEL = 460, 147, 36
local GREYED = 0.3 -- a direction with nothing to choose
local function art(four, state)
	return ART .. (four and "Ring4-" or "Ring8-") .. state .. ".tga"
end

local function atlas(texture, name, fallback)
	if C_Texture.GetAtlasInfo(name) then
		texture:SetAtlas(name)
	elseif fallback then
		texture:SetColorTexture(unpack(fallback))
	end
end

local function rightStick()
	local ok, state = pcall(C_GamePad.GetDeviceMappedState, C_GamePad.GetActiveDeviceID())
	local stick = ok and state and state.sticks and state.sticks[2]
	if stick and stick.x and stick.y then return stick.x, stick.y end
end

-- Taking the camera stick and not the walking one. A frame that takes stick
-- events takes both sticks whatever its handler returns, and walking stopped
-- while a wheel was up (measured 2026-11-14). ConsolePort's way (Controller/
-- Radial.lua, Sebastian Lindfors, Artistic License 2.0): each frame the game
-- delivers the raw sticks (Left, Right) and then the twins it acts on
-- (Movement, Camera), in that order. A watcher that passes everything on sees
-- the raw ones; when the right stick is pushed it shows a blocker that takes
-- events, as soon as Movement has gone by, so the blocker eats only Camera,
-- and the frame's end hides it again. Show and Hide of these plain frames are
-- allowed in a fight; their propagation is set once, at load.
local takers = {}
local blocker = CreateFrame("Frame")
blocker:SetFrameStrata("TOOLTIP")
local watcher = CreateFrame("Frame")
watcher:SetFrameStrata("BACKGROUND")
if blocker.EnableGamePadStick then
	blocker:SetPropagateKeyboardInput(false)
	blocker:EnableGamePadStick(true)
	blocker:SetScript("OnGamePadStick", function() end)
	watcher:SetPropagateKeyboardInput(true)
	watcher:EnableGamePadStick(true)
end
blocker:Hide()
watcher:Hide()
local leftSeen, armed = false, false
watcher:SetScript("OnGamePadStick", function(_, stick, x, y)
	if stick == "Left" then
		leftSeen = true
	elseif stick == "Right" then
		if (x ~= 0 or y ~= 0) and not blocker:IsShown() then
			-- the left stick's twin is still to come this frame: wait for it
			if leftSeen then armed = true else blocker:Show() end
		end
	elseif stick == "Movement" and armed then
		armed = false
		blocker:Show()
	end
end)
watcher:SetScript("OnUpdate", function()
	leftSeen, armed = false, false
	blocker:Hide()
end)
function Ring.Take(r, on)
	takers[r] = on or nil
	local any = next(takers) ~= nil
	watcher:SetShown(any)
	if not any then blocker:Hide() end
end

local R = {}
R.__index = R

function Ring.Build(frame, opts)
	opts = opts or {}
	local r = setmetatable({ frame = frame, slots = {} }, R)
	Ring.built[#Ring.built + 1] = r
	-- a child, so it ticks only while the ring is on screen
	local since = 0
	CreateFrame("Frame", nil, frame):SetScript("OnUpdate", function(_, elapsed)
		since = since + elapsed
		if since >= 0.1 then
			since = 0
			r:States()
		end
	end)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetScale(SCALE)
	frame:SetPoint("CENTER", UIParent, "CENTER", 312 / SCALE, 10 / SCALE) -- where the native radial sits
	frame:SetFrameStrata("DIALOG")

	-- While the ring is up, and a moment after it closes if the right stick is
	-- still pushed (so the camera does not swing round), the camera stick is
	-- taken and the walking stick is not (Take, below).
	local after = CreateFrame("Frame", nil, UIParent)
	after:Hide()
	after:SetScript("OnUpdate", function(self, elapsed)
		self.held = (self.held or 0) + elapsed
		local x, y = rightStick()
		if self.held >= RELEASE_MAX or not x or x * x + y * y <= RELEASE_SQ then
			self:Hide()
			Ring.Take(r, false)
		end
	end)
	frame:HookScript("OnShow", function()
		after:Hide()
		Ring.Take(r, true)
	end)
	frame:HookScript("OnHide", function()
		local x, y = rightStick()
		if x and x * x + y * y > RELEASE_SQ then
			after.held = 0
			after:Show()
		else
			Ring.Take(r, false)
		end
	end)

	-- a piece per direction, and the lit one over the picked
	r.pieces = {}
	for index = 1, Ring.PAGE do
		local piece = frame:CreateTexture(nil, "OVERLAY", nil, -3)
		piece:SetPoint("CENTER")
		piece:SetSize(ART_SIZE, ART_SIZE)
		r.pieces[index] = piece
	end
	r.litPiece = frame:CreateTexture(nil, "OVERLAY", nil, -2)
	r.litPiece:SetPoint("CENTER")
	r.litPiece:SetSize(ART_SIZE, ART_SIZE)
	r.litPiece:Hide()
	local under = CreateFrame("Frame", nil, frame)
	under:SetScale(1 / SCALE)
	under:SetSize(1, 1)
	r.under = under
	r.prompts = under:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	r.prompts:SetPoint("TOP")
	r.selected = under:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	r.selected:SetPoint("TOP", r.prompts, "BOTTOM", 0, -6)
	r.promptDefs = opts.prompts or {}

	for index = 1, Ring.PAGE do
		local slot = {}
		slot.icon = frame:CreateTexture(nil, "OVERLAY")
		slot.icon:SetSize(ICON_SIZE, ICON_SIZE)
		-- round: Blizzard's portrait circle mask, clamped to black outside so
		-- nothing past the circle shows (Blizzard_ArtifactPowerButton.xml)
		local mask = frame:CreateMaskTexture()
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetPoint("TOPLEFT", slot.icon, "TOPLEFT", 3, -3)
		mask:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", -3, 3)
		slot.icon:AddMaskTexture(mask)
		-- the gamepad bar's own round frame over the icon, its size
		slot.border = frame:CreateTexture(nil, "OVERLAY", nil, 2)
		atlas(slot.border, "gamepad-actionbar-circleslot-border-normal")
		slot.border:SetAllPoints(slot.icon)
		slot.shadow = frame:CreateTexture(nil, "OVERLAY", nil, -1)
		atlas(slot.shadow, "gamepad-actionbar-circleslot-dropshadow")
		slot.shadow:SetPoint("TOPLEFT", slot.icon, "TOPLEFT", -4, 4)
		slot.shadow:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", 4, -4)
		-- the bar button's own count: its font, bottom right of the icon
		-- the bar's own round cooldown swipe (Blizzard's gamepad bar and forms
		-- wheel), inside the round border
		slot.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
		slot.cooldown:SetAllPoints(mask)
		slot.cooldown:SetSwipeTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		slot.cooldown:SetSwipeColor(0, 0, 0)
		slot.cooldown:SetDrawEdge(false)
		slot.count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		slot.count:SetDrawLayer("OVERLAY", 3) -- over the round border
		slot.count:SetJustifyH("RIGHT")
		slot.count:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", 2, -2)
		slot.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		slot.label:SetSize(80, 40)
		slot.label:SetWordWrap(true)
		-- two lines at most, ending in "..." past that, inside its triangle
		slot.label:SetMaxLines(2)
		slot.label:SetJustifyH("CENTER")
		slot.label:SetJustifyV("MIDDLE")
		r.slots[index] = slot
	end
	return r
end

-- Read at each opening: the glyphs follow the controller in use.
local function promptText(defs)
	local parts = {}
	for i, def in ipairs(defs) do parts[i] = SW.Glyph(def[1]) .. " " .. def[2] end
	return table.concat(parts, "     ")
end

-- entries get their segment; the slots are laid out and the words under the art set
function R:Open(note, entries, four, names)
	self.note = note
	self.four = four
	self.names = names
	self.prompts:SetText(promptText(self.promptDefs))
	self.under:ClearAllPoints()
	-- an anchor's offset is in the anchored frame's own scale, and `under` is 1 / SCALE
	self.under:SetPoint("TOP", self.frame, "CENTER", 0, -(EDGE + UNDER_GAP) * SCALE)
	-- each direction's piece, greyed where there is nothing to choose
	local count = four and 4 or Ring.PAGE
	for index, piece in ipairs(self.pieces) do
		piece:SetShown(index <= count)
		if index <= count then
			local _, _, angle = Ring.Direction(index, four)
			piece:SetTexture(art(four, "Rest"))
			piece:SetRotation(angle - math.pi / 2) -- the art's piece is the top one
			local entry = entries[index]
			piece:SetAlpha((entry and not entry.empty) and 1 or GREYED)
		end
	end
	self.litPiece:SetTexture(art(four, "Lit"))
	for index, slot in ipairs(self.slots) do
		local entry = entries[index]
		if entry then
			entry.dx, entry.dy, entry.angle = Ring.Direction(index, four)
			slot.icon:SetPoint("CENTER", self.frame, "CENTER", entry.dx * REACH, entry.dy * REACH)
			-- its label inside its piece, on the icon's outer side (under a side's)
			local lx, ly = 0, entry.dy > 0.1 and LABEL or -LABEL
			slot.label:ClearAllPoints()
			slot.label:SetPoint("CENTER", slot.icon, "CENTER", lx, ly)
			slot.label:SetText(entry.label)
			slot.count:SetText(entry.count or "")
		end
		for _, part in ipairs({ slot.icon, slot.shadow, slot.border, slot.count }) do part:SetShown(entry ~= nil and not entry.empty) end
		slot.label:SetShown(names and entry ~= nil and not entry.empty)
		slot.cooldown:Clear()
	end
	self.entries = entries
	self:Icons()
	self:Cooldowns()
	self:States()
	self.lit = false
	self:Light(nil, entries)
end

function R:Icons()
	for index, slot in ipairs(self.slots) do
		local entry = self.entries and self.entries[index]
		if entry then slot.icon:SetTexture(entry.icon or 134400) end
	end
end

-- Each slot's cooldown as its bar button would show it. In a fight a spell's
-- cooldown times are secret, which our code may not compare or pass to
-- SetCooldown (measured 2026-11-14); the game's duration object carries them
-- unread into the swipe, which clears itself when there is none. Item
-- cooldowns are not secret.
local function Apply(slot, entry)
	if entry.spellID then
		slot.cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(entry.spellID, false), true)
	else
		local start, duration, enabled = C_Item.GetItemCooldown(entry.itemID)
		if enabled and duration and duration > 0 then slot.cooldown:SetCooldown(start, duration) else slot.cooldown:Clear() end
	end
end
function R:Cooldowns()
	for index, slot in ipairs(self.slots) do
		local entry = self.entries and self.entries[index]
		if entry and (entry.spellID or entry.itemID) then
			local ok, err = pcall(Apply, slot, entry)
			if not ok and not Ring.cooldownRefused then
				Ring.cooldownRefused = tostring(err)
				SW.Say("Wheel: the game kept a cooldown from the wheel (" .. Ring.cooldownRefused .. ")")
			end
		end
	end
end
local cooldownEvents = CreateFrame("Frame")
cooldownEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
cooldownEvents:RegisterEvent("BAG_UPDATE_COOLDOWN")
cooldownEvents:SetScript("OnEvent", function()
	for _, r in ipairs(Ring.built) do
		if r.frame:IsVisible() then r:Cooldowns() end
	end
end)

-- What a slot stands for now: out of range, usable, short of mana. A macro counts
-- as the spell or item its conditionals pick.
local function State(entry)
	local macro = entry.attr == "macro" and entry.value
	local spell = entry.spellID or (entry.show and SecureCmdOptionParse(entry.show)) or (macro and GetMacroSpell(macro))
	if spell and spell ~= "" then
		local far = C_Spell.IsSpellInRange(spell) == false
		return far, C_Spell.IsSpellUsable(spell)
	end
	local item = entry.itemID or (macro and GetMacroItem(macro))
	if not item then return false, true, false end
	local ok, inRange = pcall(C_Item.IsItemInRange, item, "target")
	local far = ok and UnitExists("target") and inRange == false
	return far, C_Item.IsUsableItem(item)
end
-- Blizzard's icon colours, range first (CooldownViewer.lua, RefreshIconColor)
function R:States()
	for index, slot in ipairs(self.slots) do
		local entry = self.entries and self.entries[index]
		if entry and not entry.empty then
			local ok, far, usable, noMana = pcall(State, entry)
			if not ok then
				if not Ring.stateRefused then
					Ring.stateRefused = tostring(far)
					SW.Say("Wheel: the game kept a button's state from the wheel (" .. Ring.stateRefused .. ")")
				end
				slot.icon:SetVertexColor(1, 1, 1)
			elseif far then slot.icon:SetVertexColor(0.64, 0.15, 0.15)
			elseif usable then slot.icon:SetVertexColor(1, 1, 1)
			elseif noMana then slot.icon:SetVertexColor(0.5, 0.5, 1)
			else slot.icon:SetVertexColor(0.4, 0.4, 0.4) end
		end
	end
end

function R:Light(pick, entries)
	self.lit = pick
	local entry = pick and entries[pick]
	self.litPiece:SetShown(entry ~= nil)
	if entry then self.litPiece:SetRotation(entry.angle - math.pi / 2) end -- the art's lit piece is the top one
	self.selected:SetText(entry and self.names and entry.label or self.note or "")
	for index, slot in ipairs(self.slots) do
		if index == pick then slot.label:SetTextColor(1, 1, 1) else slot.label:SetTextColor(1, 0.82, 0) end
		-- the picked one wears the bar's "selected" frame, as a focused button does
		atlas(slot.border, index == pick and "gamepad-actionbar-circleslot-border-selected"
			or "gamepad-actionbar-circleslot-border-normal")
	end
end

function R:Picked(entries)
	local x, y = rightStick()
	if not x or x * x + y * y < PICK_SQ then return nil end
	local best, bestDot
	for index, entry in ipairs(entries) do
		if entry.dx then
			local dot = x * entry.dx + y * entry.dy
			if not bestDot or dot > bestDot then best, bestDot = index, dot end
		end
	end
	return best
end

function R:Aim(entries, sticky)
	local pick = self:Picked(entries) or sticky
	if pick ~= self.lit then self:Light(pick, entries) end
	return pick
end
