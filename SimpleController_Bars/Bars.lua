-- The chord bars, on Blizzard's own bar template: up to six chords (CB.CHORDS), a
-- shoulder with L2, R2 or both, in any order. Each is a setting (Settings.lua),
-- applied at the next reload.
--
-- While a shoulder is held Blizzard shows its targeting bar. A watcher parented to
-- that bar takes the eight keys for as long as it is visible; each key's button
-- asks which of the shoulder's chords has its bar lit (frame level 5, ShowHighlight;
-- Blizzard lights one bar at a time). One lit: that chord, its slot, after an up-click
-- on the hostile bar's cross spends the shoulder's tab-target. None: the targeting
-- bar's own button.
--
-- The bars only display. A Blizzard-template button made by an addon is refused
-- the cast (ADDON_ACTION_FORBIDDEN), so a plain secure button casts. A macro in a
-- chord slot did nothing through that button, from inside the chord's own macro,
-- so its text runs in the chord's macro instead, kept current out of combat.
--
-- Which bar a chord fires shows by size: ours is big and the trigger's own bar small.
-- Sizes are protected in a fight and a shoulder pressed second gives secure code no
-- event, so everything is an animation, which the game plays on protected frames. Ours
-- is two real bars, Blizzard's collapsed and expanded layouts, one hidden by alpha at a
-- time (scaling our buttons flashed oversized); theirs is moved to the collapsed layout.
-- A shoulder's chords sit beside the bottom bar, small at rest: the first beside it,
-- the second outward of the first, the third above the second (above the first is
-- Blizzard's own trigger bar). A held chord shows big in its place.
-- A chord is not targeting: the game's targeting mode is off while one is held, and the
-- fade Blizzard gives the other bars during targeting is held off the same way.
--
-- L1+L2 and R1+R2 take over Blizzard's class button they open (a `flyout`): its
-- flyout opens from its own OnUpdate while the chord is held, so a state driver keeps
-- that button hidden.
local _, CB = ...

local CONSUME = "GamepadMainActionBarFramePageUnitHostileTargetingActionBarActionButton8"
local SHOULDERS = {
	{ tag = "L", targeting = "friendlyTargetingBar", dir = -1 },
	{ tag = "R", targeting = "hostileTargetingBar", dir = 1 },
}
-- Half an expanded bar's width twice: ours and the bottom bar never touch.
local BESIDE_BOTTOM = 270
local BELOW_LEFT = 88
local GAP = 8 -- between a shoulder's bars

-- One shoulder's keys: a button per key that picks the chord whose bar is lit.
local function buildKeys(shoulder, bars)
	local binder = CreateFrame("Frame", nil, bars[shoulder.targeting], "SecureHandlerBaseTemplate")
	for n, chord in ipairs(shoulder.chords) do
		local watch = CB.Watch(nil, chord.face.bar, chord.face.bar)
		for i, shown in ipairs(chord.face.bar.actionButtons) do
			watch:SetFrameRef("button" .. i, shown)
			watch:SetFrameRef("cover" .. i, CB.Cover(shown))
		end
		binder:SetFrameRef("watch" .. n, watch)
		chord.watch = watch
	end
	local bind = { "self:ClearBindings()" }
	shoulder.fires = {}
	for i, key in ipairs(CB.KEYS) do
		local name = "SimpleControllerBarsFire" .. shoulder.tag .. i
		local fire = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
		fire:RegisterForClicks("AnyDown", "AnyUp")
		fire:SetAttribute("useOnKeyDown", true)
		fire:SetAttribute("type", "macro")
		local pass = bars[shoulder.targeting].actionButtons[i]:GetName()
		fire:SetAttribute("cb-pass", ("/click %s LeftButton 1\n/click %s LeftButton"):format(pass, pass))
		for n, chord in ipairs(shoulder.chords) do
			local cast = CreateFrame("Button", ("SimpleControllerBarsCast%s%d"):format(chord.setting, i), UIParent, "SecureActionButtonTemplate")
			cast:RegisterForClicks("AnyDown")
			cast:SetAttribute("useOnKeyDown", true)
			cast:SetAttribute("type", "action")
			cast:SetAttribute("action", chord.first + i - 1)
			fire:SetAttribute("cb-chord" .. n, ("/click %s LeftButton\n/click %s LeftButton 1"):format(CONSUME, cast:GetName()))
			fire:SetAttribute("cb-slot" .. n, chord.first + i - 1)
			fire:SetFrameRef("a" .. n, bars[chord.lit[1]])
			if chord.lit[2] then fire:SetFrameRef("b" .. n, bars[chord.lit[2]]) end
			fire:SetFrameRef("watch" .. n, chord.watch)
		end
		SecureHandlerWrapScript(fire, "OnClick", binder, CB.FireSnippet(i, #shoulder.chords))
		shoulder.fires[i] = fire
		bind[#bind + 1] = ("self:SetBindingClick(true, %q, %q, 'LeftButton')"):format(key, name)
	end
	SecureHandlerWrapScript(binder, "OnShow", binder, table.concat(bind, "\n"))
	SecureHandlerWrapScript(binder, "OnHide", binder, ([[
		self:ClearBindings()
		for n = 1, %d do
			local watch = self:GetFrameRef("watch" .. n)
			for i = 1, 8 do watch:RunAttribute("cb-release", i) end
		end
	]]):format(#shoulder.chords))
end

local function syncMacros(shoulders)
	for _, shoulder in ipairs(shoulders) do
		for i, fire in ipairs(shoulder.fires) do
			for n, chord in ipairs(shoulder.chords) do
				local slot = chord.first + i - 1
				local body = GetActionInfo(slot) == "macro" and GetMacroBody(GetActionText(slot))
				fire:SetAttribute("cb-macro" .. n, body and ("/click %s LeftButton\n%s"):format(CONSUME, body) or nil)
			end
		end
	end
end

-- faces(chord): that chord's bars on this page unit
local function place(bars, shoulders, faces)
	local _, by = bars.bottomBar:GetCenter()
	local _, ly = bars.leftBar:GetCenter()
	if not by or not ly then return false end
	local y = ly * bars.leftBar:GetEffectiveScale() / bars.bottomBar:GetEffectiveScale() - by - BELOW_LEFT
	for _, shoulder in ipairs(shoulders) do
		for n, chord in ipairs(shoulder.chords) do
			local face = faces(chord)
			local out = n > 1 and face.small:GetWidth() + GAP or 0
			local up = n > 2 and face.small:GetHeight() + GAP or 0
			for _, bar in ipairs({ face.small, face.bar }) do
				CB.Put(bars, bar, shoulder.dir * (BESIDE_BOTTOM + out), y + up, chord)
				CB.ButtonIcons(bar)
			end
		end
	end
	return true
end

-- What each button does between the two layouts.
local function measure(big, small)
	local layout = {}
	for i, button in ipairs(big.actionButtons) do
		local other = small.actionButtons[i]
		local _, _, _, x, y = button:GetPoint(1)
		local _, _, _, ox, oy = other:GetPoint(1)
		layout[i] = { x = x - ox, y = y - oy, size = button:GetWidth() / other:GetWidth() }
	end
	return layout
end

-- Jumps to a size and an offset, as Blizzard's bars do, and stays until stopped.
local function moved(button, scale, x, y)
	local group = button:CreateAnimationGroup()
	local grow = group:CreateAnimation("Scale")
	grow:SetDuration(CB.HOLD_TIME)
	grow:SetScaleFrom(scale, scale)
	grow:SetScaleTo(scale, scale)
	grow:SetOrigin("CENTER", 0, 0)
	local slide = group:CreateAnimation("Translation")
	slide:SetDuration(0)
	slide:SetOffset(x, y)
	return group
end

local function heldAlpha(bar, alpha)
	local group = bar:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	local hold = group:CreateAnimation("Alpha")
	hold:SetFromAlpha(alpha)
	hold:SetToAlpha(alpha)
	hold:SetDuration(CB.HOLD_TIME)
	return group
end

local function collapsed(bar, layout)
	local groups = {}
	for i, button in ipairs(bar.actionButtons) do
		groups[i] = moved(button, 1 / layout[i].size, -layout[i].x, -layout[i].y)
	end
	local group = bar:CreateAnimationGroup()
	local dim = group:CreateAnimation("Alpha")
	dim:SetTarget(bar.BackgroundFocus)
	dim:SetFromAlpha(0)
	dim:SetToAlpha(0)
	dim:SetDuration(CB.HOLD_TIME)
	groups[#groups + 1] = group
	return groups
end

-- Blizzard's focus on its lit bar, beyond BackgroundFocus: the trigger prompt under
-- it in its glowing focused state (modifierIcon), and the focus frames and sparkles
-- of its editor's look (Blizzard_GamepadActionBars/ActionBarFocusFX.lua). While our
-- chord is held they are held invisible by animations of ours (a frame's alpha, over
-- the animations Blizzard plays on what is in it).
local function glowParts(bar)
	local parts = { bar.EditModeFocusBackground, bar.modifierIcon }
	for _, half in ipairs({ bar.Left, bar.Right }) do
		if half and half.EditModeFocusParticlesSingle then parts[#parts + 1] = half.EditModeFocusParticlesSingle end
	end
	return parts
end

local hiders = {}
local function hiderOf(bar)
	if hiders[bar] then return hiders[bar] end
	local groups = {}
	for _, part in ipairs(glowParts(bar)) do
		local group = part:CreateAnimationGroup()
		group:SetLooping("REPEAT")
		local hold = group:CreateAnimation("Alpha")
		hold:SetTarget(part)
		hold:SetFromAlpha(0)
		hold:SetToAlpha(0)
		hold:SetDuration(CB.HOLD_TIME)
		groups[#groups + 1] = group
	end
	hiders[bar] = groups
	return groups
end

local function playAll(groups)
	for _, group in ipairs(groups) do group:Play() end
end

local function stopAll(groups)
	for _, group in ipairs(groups) do group:Stop() end
end

-- One chord's bar on one page unit: both layouts, and what shrinks whichever of
-- Blizzard's bars is lit while it is held.
local function buildFace(chord, unit, prefix)
	local box = CB.Mirror(unit)
	local face = {
		small = CB.InBox(CreateFrame("Frame", prefix .. "Rest" .. chord.setting, box, "GamepadActionBarTemplate"), box),
		bar = CB.InBox(CreateFrame("Frame", prefix .. chord.setting, box, "GamepadActionBarTemplate"), box),
		shrunk = {},
	}
	for _, bar in ipairs({ face.small, face.bar }) do
		for i = 1, 8 do
			local button = bar.actionButtons[i]
			button:SetAttribute("action", chord.first + i - 1)
			button:SetID(chord.first + i - 1)
			button:UpdateAction()
		end
	end
	face.small:CollapseActionButtons()
	face.bar:ExpandActionButtons()
	face.bar.BackgroundFocus:Show()
	for _, bar in ipairs({ face.small, face.bar }) do
		bar:HideButtonIcons()
		bar:Show()
	end
	face.hideSmall, face.hideBig = heldAlpha(face.small, 0), heldAlpha(face.bar, 0)
	local layout = measure(face.bar, face.small)
	for _, key in ipairs(CB.LIT_BARS) do face.shrunk[key] = collapsed(unit.actionBars[key], layout) end
	local template = #chord.keys == 3 and "InputPromptThreeIconTemplate" or "InputPromptTwoIconTemplate"
	face.prompt = CB.Prompt(template, chord.keys, face.bar, box)
	return face
end

-- Held: big, Blizzard's lit bar shrunk. Otherwise small.
local function showFace(face, held, bars)
	face.prompt:SetShown(CB.ShowPrompts())
	if held then
		face.prompt:SetFocused()
		face.hideBig:Stop()
		face.hideSmall:Play()
		for _, key in ipairs(CB.LIT_BARS) do
			if bars[key]:GetFrameLevel() == CB.ACTIVE_LEVEL then
				playAll(face.shrunk[key])
				playAll(hiderOf(bars[key]))
			end
		end
		return
	end
	face.prompt:SetPressable()
	face.hideBig:Play()
	face.hideSmall:Stop()
	for _, key in ipairs(CB.LIT_BARS) do
		stopAll(face.shrunk[key])
		stopAll(hiderOf(bars[key]))
	end
end

local function showShoulder(shoulder, held, bars, faces)
	for _, chord in ipairs(shoulder.chords) do showFace(faces(chord), chord == held, bars) end
end

local function show(shoulder, held, bars)
	if shoulder.held == held then return end
	local was = shoulder.held
	shoulder.held = held
	if held and not was then
		C_GamepadTargeting.Disable()
		playAll(shoulder.unfaded)
	elseif was and not held then
		stopAll(shoulder.unfaded)
	end
	showShoulder(shoulder, held, bars, function(chord) return chord.face end)
	if not held and bars[shoulder.targeting]:IsShown() then C_GamepadTargeting.Enable() end
end

local function heldChord(shoulder, bars)
	return (CB.ChordFor(shoulder.chords, bars[shoulder.targeting]:IsShown(), function(key) return bars[key]:GetFrameLevel() end))
end

-- Blizzard's bind screen and Edit Action Bar hide the bars of play and draw their own:
-- there ours show greyed beside its copies, for they are edited in our own editor
-- (Simple Controller's), which a key hands over to.
local GREYED = 0.5
local function buildGreyed(edit, shoulders)
	local unit = edit.PageUnit
	local box = CB.Mirror(unit)
	local faces = {}
	for _, shoulder in ipairs(shoulders) do
		for _, chord in ipairs(shoulder.chords) do
			local bar = CB.InBox(CreateFrame("Frame", nil, box, "GamepadActionBarTemplate"), box)
			for i = 1, 8 do
				local button = bar.actionButtons[i]
				button:SetAttribute("action", chord.first + i - 1)
				button:SetID(chord.first + i - 1)
				button:UpdateAction()
			end
			bar:CollapseActionButtons()
			bar:HideButtonIcons()
			bar:SetActionButtonsSaturation(1)
			bar:SetAlpha(GREYED)
			bar:Show()
			faces[chord] = { small = bar, bar = bar }
		end
	end
	local placed = false
	CB.OnRelayout(function() placed = false end)
	local placer = CreateFrame("Frame", nil, edit)
	placer:SetScript("OnUpdate", function()
		if not placed and not InCombatLockdown() and unit.actionBars.bottomBar:GetCenter() then
			placed = place(unit.actionBars, shoulders, function(chord) return faces[chord] end)
		end
	end)
end

CB.AtLogin(function()
	if not CB.ControllerMode() then
		return CB.Say("Simple Controller: Bars does nothing while Blizzard's controller interface is off (Options > Controls > Controller).")
	end
	local pageUnit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
	if not pageUnit then return end
	local bars = pageUnit.actionBars
	local placed = CB.placed
	local shoulders = {}
	for _, shoulder in ipairs(SHOULDERS) do
		shoulder.chords = {}
		for _, chord in ipairs(CB.CHORDS) do
			if chord.shoulder == shoulder.tag and placed[chord] then
				chord.first = placed[chord].first
				shoulder.chords[#shoulder.chords + 1] = chord
			end
		end
		if #shoulder.chords > 0 then shoulders[#shoulders + 1] = shoulder end
	end
	-- the editor (Simple Controller's) hides our bars of play while it is open, as it
	-- hides Blizzard's
	SimpleController.OnEditor(function(open) CB.Mirror(pageUnit):SetAlpha(open and 0 or 1) end)
	if #shoulders == 0 then return end

	for _, shoulder in ipairs(shoulders) do
		for _, chord in ipairs(shoulder.chords) do
			if chord.flyout and pageUnit[chord.flyout] then RegisterStateDriver(pageUnit[chord.flyout], "visibility", "hide") end
			chord.face = buildFace(chord, pageUnit, "SimpleControllerBars")
		end
		shoulder.unfaded = {}
		for _, key in ipairs({ "leftBar", "rightBar", "bottomBar", "stanceBar" }) do
			shoulder.unfaded[#shoulder.unfaded + 1] = heldAlpha(bars[key], 1)
		end
		buildKeys(shoulder, bars)
		showShoulder(shoulder, nil, bars, function(chord) return chord.face end)
	end
	local function ours(chord) return chord.face end
	place(bars, shoulders, ours)
	if GamepadActionBarEditFrame then buildGreyed(GamepadActionBarEditFrame, shoulders) end
	-- in the editor: each chord's keys, slots and its bars of play, where it is drawn
	for _, shoulder in ipairs(shoulders) do
		for _, chord in ipairs(shoulder.chords) do
			SimpleController.AddBar({ keys = chord.keys, first = chord.first, small = chord.face.small, big = chord.face.bar })
		end
	end
	local function replace() CB.AfterCombat(function() place(bars, shoulders, ours) end) end
	CB.OnRelayout(function()
		place(bars, shoulders, ours)
		for _, shoulder in ipairs(shoulders) do showShoulder(shoulder, shoulder.held, bars, ours) end
	end)
	local function resync() CB.AfterCombat(function() syncMacros(shoulders) end) end
	syncMacros(shoulders)
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" or event == "EDIT_MODE_LAYOUTS_UPDATED" then replace() end
		if event ~= "EDIT_MODE_LAYOUTS_UPDATED" then resync() end
	end)

	local driver = CreateFrame("Frame")
	driver:SetScript("OnUpdate", function()
		for _, shoulder in ipairs(shoulders) do show(shoulder, heldChord(shoulder, bars), bars) end
	end)
end)
