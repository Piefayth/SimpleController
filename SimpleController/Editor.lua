-- Blizzard's bind screen and Edit Action Bar, extended to the suite's (the player,
-- 2026-11-23; the core's since 2026-11-24, which addons extend: Core.lua). Blizzard's editor edits only its own slots, and its state is never ours
-- to write (it taints, and A and B die), so while it is open ours show greyed there and
-- a prompt of ours beside its footer offers bare Square, which its editor leaves free
-- (no trigger: the top bar, whose face buttons bind nothing); Bind in the spellbook is
-- Square too, so binding to ours is Square twice. That key is bound for the moment to
-- the Blizzard button behind the editor's own Back prompt: a real press of it, so the
-- editor closes itself, untainted, and ours opens in its place, holding what it held.
--
-- Ours is the same screen, made of the same parts on frames of ours: the shade, the
-- info box (its border, title box and Blizzard's own words), Blizzard's bar template
-- for every bar (theirs of play and ours, each where it is in play, the one the
-- triggers or a chord pick grown and lit), the controller's focus taken off the window
-- under it. Binding: a press puts the spell there and the screen closes. Editing: a
-- press picks up, the next puts down (what was there is then held, as Blizzard's
-- does), Square unbinds what is held, Circle puts it back or closes. An extra button's
-- own key is its slot. Out of combat only, as Blizzard's.
--
-- Nothing of Blizzard's is written or called: a plain frame of ours takes the pad's
-- buttons while open (enabled once out of combat, as the controller keyboard's
-- catcher); the bars of play are only read (their slots and places); spells move on the
-- game's cursor (PickupAction, PlaceAction), as Blizzard's editor moves them.
local _, SC = ...

local HAND_OVER = "PAD3"
local BACK_BUTTON = "InputFunctionBindingButton_PAD2" -- Blizzard's button behind its editor's Back prompt
local L, R = "PADLTRIGGER", "PADRTRIGGER"
local CANCEL_KEY, UNBIND_KEY = "PAD2", "PAD3"

-- Blizzard's shade (ActionBarEditFrame.xml) over everything under the screen, a frame
-- of its own: it stays while a target action's own screen (a wheel) follows ours
local dim = CreateFrame("Frame", nil, UIParent)
dim:SetFrameStrata("HIGH")
dim:SetAllPoints()
dim:Hide()
local screen = CreateFrame("Frame", nil, UIParent)
screen:SetFrameStrata("HIGH")
screen:SetFrameLevel(dim:GetFrameLevel() + 2)
screen:SetAllPoints()
screen:Hide()
local shade = dim:CreateTexture(nil, "BACKGROUND")
shade:SetPoint("TOPLEFT", -6, 6)
shade:SetPoint("BOTTOMRIGHT", 6, -6)
shade:SetColorTexture(0, 0, 0, 0.75)

-- Blizzard's info box: a dialog border, a glowing title box on its top edge, its
-- instruction under it (GamepadActionBarEdit*InfoFrameTemplate)
local function infoBox(height, title, instruction)
	local box = CreateFrame("Frame", nil, screen)
	box:SetFrameStrata("DIALOG")
	box:SetSize(485, height)
	box:SetPoint("CENTER", 0, 75)
	CreateFrame("Frame", nil, box, "DialogBorderTemplate"):SetAllPoints()
	local glow = CreateFrame("Frame", nil, box, "DialogFrameGlowTemplate")
	glow:SetPoint("TOPLEFT", -6, 6)
	glow:SetPoint("BOTTOMRIGHT", 6, -6)
	local titleBox = CreateFrame("Frame", nil, box)
	titleBox:SetFrameStrata("DIALOG")
	titleBox:SetFrameLevel(box:GetFrameLevel() + 5)
	titleBox:SetPoint("CENTER", box, "TOP", 0, -7)
	CreateFrame("Frame", nil, titleBox, "DialogBorderDarkTemplate"):SetAllPoints()
	local titleGlow = CreateFrame("Frame", nil, titleBox, "DialogFrameGlowTemplate")
	titleGlow:SetPoint("TOPLEFT", -6, 6)
	titleGlow:SetPoint("BOTTOMRIGHT", 6, -6)
	local titleText = titleBox:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge2")
	titleText:SetPoint("CENTER")
	local text = box:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	text:SetPoint("TOP", 0, -50)
	-- its words, Blizzard's unless choosing a target action's target
	function box.Say(newTitle, newInstruction)
		titleText:SetText(newTitle)
		titleBox:SetSize(titleText:GetWidth() + 60, titleText:GetHeight() + 34)
		text:SetText(newInstruction)
	end
	box.Say(title, instruction)
	return box
end

-- Blizzard's footer (InputLegendPromptGroup.lua): its backing box, one prompt per entry
local PAD, GAP = 10, 15
local function legend(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetFrameStrata("DIALOG")
	local slot = frame:CreateTexture(nil, "BACKGROUND")
	slot:SetAtlas("gamepad-footer-slot-bg")
	slot:SetAllPoints()
	local border = frame:CreateTexture(nil, "BORDER")
	border:SetAtlas("gamepad-footer-slot-frameneutral")
	border:SetAllPoints()
	local prompts = {}
	-- entries: { { key, label }, ... }
	function frame.Set(entries)
		local x = PAD
		for i, entry in ipairs(entries) do
			local prompt = prompts[i] or CreateFrame("Frame", nil, frame, "InputPromptOneIconWithTextTemplate")
			prompts[i] = prompt
			prompt:SetPromptInputIconKey(1, entry[1])
			prompt:SetPromptText(entry[2])
			prompt:EnablePrompt()
			prompt:Show()
			prompt:ClearAllPoints()
			prompt:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -PAD)
			x = x + prompt:GetWidth() + GAP
		end
		for i = #entries + 1, #prompts do prompts[i]:Hide() end
		frame:SetSize(x - GAP + PAD, 24 + 2 * PAD)
	end
	return frame
end
local bindBox = infoBox(180, GAMEPAD_EDIT_FRAME_BIND_INFO_FRAME_TITLE, GAMEPAD_EDIT_FRAME_BIND_INFO_FRAME_BIND_INSTRUCTION)
local actionName = bindBox:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge2")
actionName:SetPoint("CENTER", 0, -5)
local actionIcon = bindBox:CreateTexture(nil, "ARTWORK")
actionIcon:SetSize(40, 40)
actionIcon:SetPoint("TOP", actionName, "BOTTOM", 0, -10)
local editBox = infoBox(110, GAMEPAD_EDIT_FRAME_EDIT_ACTION_BARS_INFO_FRAME_TITLE,
	GAMEPAD_EDIT_FRAME_EDIT_ACTION_BARS_INFO_FRAME_PICKUP_INSTRUCTION)
-- ours, under whichever box shows, where Blizzard's footer is
local footer = legend(screen)

-- Blizzard's lit look on a bar: its focus background, sparkles and each button's glow
local function glow(bar, on)
	local bg = bar.EditModeFocusBackground
	for _, part in ipairs({ bg.EditBackgroundFocus, bg.FocusParticles1, bg.FocusParticles2, bg.FocusParticles3 }) do
		part:SetShown(on)
	end
	if on then bg.EditFocusAllStart:Play() else bg.EditFocusAllStart:Stop() end
	for i, button in ipairs(bar.actionButtons) do
		local shape = i <= 4 and "Square" or "Circle"
		button[shape .. "GlowFocus"]:SetShown(on)
		button[shape .. "ShadowFocus"]:SetShown(on)
		button.CheckedTexture:SetShown(on)
		local start = button["EditMode" .. shape .. "FocusStartAnim"]
		if on then start:Play() else start:Stop() end
	end
end

-- The main bar's face buttons bind nothing (interact, inspect, back, jump): drawn as
-- Blizzard's editor draws them (SetupNonBindableActionArt), on our copy of it.
local function nonBindable(bar)
	local right = bar.Right
	local art = {
		{ right.ActionButton1, nil, 0 },
		{ right.ActionButton2, "crosshair_inspect_32", 3 },
		{ right.ActionButton3, "128-redbutton-exit", 6 },
		{ right.ActionButton4, "gamepad-ability-icon-jump", 0 },
	}
	for _, each in ipairs(art) do
		local button, atlas, grow = each[1], each[2], each[3]
		local icon = button.SpecialActionIcon
		if atlas then icon:SetAtlas(atlas) end
		if grow > 0 then
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", button, "TOPLEFT", -grow, grow)
			icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", grow, -grow)
		end
		button.icon:SetAlpha(0)
		icon:Show()
		icon:SetDesaturation(1)
		button.PermaboundOverlay:Show()
	end
end

-- A bar as Blizzard's editor shows one: small at rest, grown and lit while picked, the
-- buttons that pick it under it, as in play (none for the top bar).
local PROMPT_Y = -35 -- where Blizzard's XML puts each bar's trigger prompt
local function barPair(keys)
	local pair = {}
	for _, layout in ipairs({ "small", "big" }) do
		-- the template fixes its own strata (LOW): set to the screen's, over its shade
		local bar = CreateFrame("Frame", nil, screen, "GamepadActionBarTemplate")
		bar:SetFrameStrata(screen:GetFrameStrata())
		if layout == "small" then bar:CollapseActionButtons() else bar:ExpandActionButtons() end
		bar:HideButtonIcons()
		bar:Show()
		pair[layout] = bar
	end
	glow(pair.big, true)
	if #keys > 0 then
		local prompt = SC.Prompt(screen, keys)
		prompt:SetFrameStrata(screen:GetFrameStrata())
		prompt:SetPoint("CENTER", pair.big, "CENTER", 0, PROMPT_Y)
		prompt:SetFrameLevel(pair.big:GetFrameLevel() + 10) -- over the bar's buttons
		pair.prompt = prompt
	end
	return pair
end
-- its slots (nil: no slot there, the top bar's face buttons) and where it is in play
local function setPair(pair, slots, small, big)
	for layout, anchor in pairs({ small = small, big = big }) do
		local bar = pair[layout]
		for i, button in ipairs(bar.actionButtons) do
			local slot = slots[i]
			if slot then
				button:SetAttribute("action", slot)
				button:SetID(slot)
				button:UpdateAction()
			end
		end
		bar:SetScale(anchor:GetEffectiveScale() / screen:GetEffectiveScale())
		bar:ClearAllPoints()
		bar:SetPoint("CENTER", anchor, "CENTER")
	end
end

-- Every bar: Blizzard's of play (top, L2, R2 or the form's, L2 + R2), our chords, the
-- extras (their own keys). Built once, set again at each opening.
local entries, extrasCopy, extraSlot
local function build()
	if entries then return end
	entries = {}
	for _, keys in ipairs({ {}, { L }, { R }, { L, R } }) do entries[#entries + 1] = { pair = barPair(keys), keys = keys } end
	nonBindable(entries[1].pair.small)
	nonBindable(entries[1].pair.big)
	for _, row in ipairs(SC.bars) do entries[#entries + 1] = { pair = barPair(row.keys), row = row, keys = row.keys } end
	if SC.extras then extrasCopy = { row = SC.extras, copy = SC.extras.copy(screen) } end
end
SC.Prebuild = build

local function setAll()
	local played = GamepadMainActionBarFrame.PageUnit.actionBars
	local right = played.stanceBar:IsShown() and played.stanceBar or played.rightBar
	local blizzard = { { played.topBar, 4 }, { played.leftBar, 8 }, { right, 8 }, { played.bottomBar, 8 } }
	for n, bar in ipairs(blizzard) do
		local entry, slots = entries[n], {}
		for i = 1, bar[2] do
			local button = bar[1].actionButtons[i]
			local slot = button.action or button:GetAttribute("action")
			if type(slot) == "number" and slot > 0 then slots[i] = slot end
		end
		entry.slots = slots
		setPair(entry.pair, slots, bar[1], bar[1])
	end
	for _, entry in ipairs(entries) do
		if entry.row then
			entry.slots = {}
			for i = 1, 8 do entry.slots[i] = entry.row.first + i - 1 end
			setPair(entry.pair, entry.slots, entry.row.small, entry.row.big)
		end
	end
	extraSlot = {}
	if extrasCopy then
		local copy, row = extrasCopy.copy, extrasCopy.row
		copy.bar:SetScale(row.bar:GetEffectiveScale() / screen:GetEffectiveScale())
		copy.bar:ClearAllPoints()
		copy.bar:SetPoint("CENTER", row.bar, "CENTER")
		for i, key in pairs(row.keys()) do
			if not key:find("-") then extraSlot[key] = row.first + i - 1 end
		end
	end
end

-- "bind" or "edit"; what is being bound; the slot what is held came from; the bar
-- picked; the target action whose targets are being chosen
local mode, binding, from, lit, choosing
local hold -- below
local catcher = CreateFrame("Frame", nil, UIParent)
catcher:SetFrameStrata("TOOLTIP")
catcher:SetSize(1, 1)
catcher:SetPoint("CENTER")
catcher:Hide()

local function holding() return GetCursorInfo() ~= nil end

-- a target action being chosen for: its words, and its target and run
local function choice(words, action)
	return { label = words.label, choose = words.choose, target = action.target, run = action.run }
end

-- what is held, as the game names it: { kind, id, name, icon } (spell, item or macro)
local function heldThing()
	local kind, a, c
	if binding then
		kind, a, c = binding.kind, binding.a, binding.c
	else
		kind, a, _, c = GetCursorInfo()
	end
	if kind == "spell" then return { kind = kind, id = c or a, name = C_Spell.GetSpellName(c or a), icon = C_Spell.GetSpellTexture(c or a) } end
	if kind == "item" then return { kind = kind, id = a, name = C_Item.GetItemNameByID(a), icon = C_Item.GetItemIconByID(a) } end
	if kind == "macro" then
		local name, icon = GetMacroInfo(a)
		return { kind = kind, id = a, name = name, icon = icon }
	end
end

-- Every button of our copies, with its slot: choosing lights only the targets; else the
-- picked bar is lit whole, as Blizzard's.
local function eachButton(fn)
	for _, entry in ipairs(entries) do
		for _, bar in ipairs({ entry.pair.small, entry.pair.big }) do
			for i, button in ipairs(bar.actionButtons) do fn(button, entry.slots[i], i > 4) end
		end
	end
	if extrasCopy then
		for i, button in ipairs(extrasCopy.copy.buttons) do fn(button, extrasCopy.row.first + i - 1, true) end
	end
end
-- choosing: the targets lit, every other button faded
local FADED = 0.25
local function markTargets()
	eachButton(function(button, slot, round)
		local on = choosing ~= nil and slot ~= nil and choosing.target(slot)
		local shape = round and "Circle" or "Square"
		button[shape .. "GlowFocus"]:SetShown(on)
		button[shape .. "ShadowFocus"]:SetShown(on)
		button:SetAlpha((choosing and not on) and FADED or 1)
	end)
	if not choosing then
		for _, entry in ipairs(entries) do glow(entry.pair.big, true) end
	end
end

local function draw()
	for _, entry in ipairs(entries) do
		entry.pair.big:SetShown(entry == lit)
		entry.pair.small:SetShown(entry ~= lit)
		local prompt = entry.pair.prompt
		if prompt then
			if entry == lit then prompt:SetFocused() else prompt:SetPressable() end
		end
	end
	local held = heldThing()
	local showBind = held ~= nil or choosing ~= nil
	bindBox:SetShown(showBind)
	editBox:SetShown(not showBind)
	GameTooltip:Hide()
	if held then
		if held.kind == "spell" then
			GameTooltip:SetOwner(bindBox, "ANCHOR_NONE")
			GameTooltip:SetPoint("LEFT", bindBox, "RIGHT", 10, 0)
			GameTooltip:SetSpellByID(held.id)
		end
		actionName:SetText(held.name or "")
		actionIcon:SetTexture(held.icon)
	else
		actionName:SetText("")
		actionIcon:SetTexture(nil)
	end
	-- Blizzard's own footer words (its editor's prompted bindings), and the target actions'
	footer:ClearAllPoints()
	footer:SetPoint("TOPLEFT", showBind and bindBox or editBox, "BOTTOMLEFT")
	local prompts = {}
	if choosing then
		prompts = { { CANCEL_KEY, FRAME_ACTION_CANCEL } }
	else
		if mode == "edit" and held then prompts[#prompts + 1] = { UNBIND_KEY, FRAME_ACTION_UNBIND } end
		for _, action in ipairs(SC.targetActions) do
			local words
			if held then
				words = action.label
			elseif mode == "edit" then
				words = action.handOver or action.pick and action.pick.label
			end
			if words then prompts[#prompts + 1] = { action.key, words } end
		end
		prompts[#prompts + 1] = { CANCEL_KEY, mode == "bind" and FRAME_ACTION_BACK or FRAME_ACTION_CANCEL }
	end
	footer.Set(prompts)
	if choosing then
		bindBox.Say(choosing.label, choosing.choose)
	else
		bindBox.Say(GAMEPAD_EDIT_FRAME_BIND_INFO_FRAME_TITLE, GAMEPAD_EDIT_FRAME_BIND_INFO_FRAME_BIND_INSTRUCTION)
	end
	markTargets()
end

-- The bars of play go while ours is open, as Blizzard's editor hides them: ours made
-- transparent (our frames), Blizzard's held invisible by an alpha animation of ours
-- aimed at its bar frame, nothing of its set. So does the controller's pointer on the
-- window under it (the spellbook): the window keeps its focus, our catcher takes the
-- pad's buttons, and only the pointer is hidden. Taking the focus off the window
-- instead, through the manager call Blizzard wraps for addons (FrameHidden), had its
-- binding update reach SetPreferredGamepadInteractTarget tainted: A and B blocked
-- (taint.log, 2026-11-24).
local hiders
local function hidePlay(on)
	if not hiders then
		hiders = {}
		for _, target in ipairs({ GamepadMainActionBarFrame, SmartNavigation.Pointer }) do
			local group = screen:CreateAnimationGroup()
			group:SetLooping("REPEAT")
			local hold = group:CreateAnimation("Alpha")
			hold:SetTarget(target)
			hold:SetFromAlpha(0)
			hold:SetToAlpha(0)
			hold:SetDuration(1)
			hiders[#hiders + 1] = group
		end
	end
	for _, group in ipairs(hiders) do
		if on then group:Play() else group:Stop() end
	end
	for _, fn in ipairs(SC.onEditor) do fn(on) end
end

-- `keepDim`: the shade and the bars of play stay hidden, for a target action's screen
local function undim()
	if mode then return end
	dim:Hide()
	hidePlay(false)
end
local function close(keepDim)
	if mode == "edit" and holding() and from and not HasAction(from) then PlaceAction(from) end
	ClearCursor()
	mode, binding, from, lit, choosing = nil, nil, nil, nil, nil
	catcher:Hide()
	screen:Hide()
	GameTooltip:Hide()
	if not keepDim then undim() end
end

-- a slot pressed
local function act(slot)
	if choosing then
		if not choosing.target(slot) then return end
		-- what is held goes to the target, off the bars: moved, as a put-down moves it
		local action, thing, editing = choosing, heldThing(), mode == "edit"
		ClearCursor()
		from = nil
		close(true)
		return action.run(slot, thing, editing, undim)
	end
	if mode == "bind" then
		local bringing = { func = binding.func, params = binding.params }
		close()
		ClearCursor()
		if pcall(bringing.func, unpack(bringing.params)) then PlaceAction(slot) end
		return ClearCursor()
	end
	if holding() then
		PlaceAction(slot)
		from = holding() and slot or nil
	elseif HasAction(slot) then
		PickupAction(slot)
		from = slot
	end
	draw()
end

-- a target action's fresh thing held (a new wheel), as if picked up
hold = function(action)
	local fresh = action.fresh()
	if fresh then
		ClearCursor()
		pcall(fresh.func, unpack(fresh.params))
		from = nil
	end
end

local catching = false
SC.AfterCombat(function()
	catcher:SetScript("OnGamePadButtonDown", function(_, key)
		if InCombatLockdown() then return end
		if extraSlot[key] then return act(extraSlot[key]) end
		local index = tIndexOf(SC.KEYS, key)
		if index and lit and lit.slots[index] then return act(lit.slots[index]) end
		if choosing then
			if key == CANCEL_KEY then
				choosing = nil
				draw()
			end
			return
		end
		for _, action in ipairs(SC.targetActions) do
			if key == action.key then
				if heldThing() then
					if action.label then choosing = choice(action, action) end
				elseif mode == "edit" and action.pick then
					choosing = choice(action.pick, action)
				elseif mode == "edit" and action.fresh then
					hold(action)
				end
				return draw()
			end
		end
		if key == UNBIND_KEY and mode == "edit" and holding() then
			ClearCursor()
			from = nil
			draw()
		elseif key == CANCEL_KEY then
			if mode == "edit" and holding() then
				if from and not HasAction(from) then PlaceAction(from) end
				ClearCursor()
				from = nil
				draw()
			else
				close()
			end
		end
	end)
	catcher:SetPropagateKeyboardInput(false)
	catcher:EnableGamePadButton(true)
	catching = true
end)
-- the bar follows the buttons held, as Blizzard's editor does
catcher:SetScript("OnUpdate", function()
	local now = SC.Exact(entries, IsKeyDown)
	if now ~= lit then
		lit = now
		draw()
	end
end)
-- a fight closes it, while its first moment still takes our calls
local fight = CreateFrame("Frame")
fight:RegisterEvent("PLAYER_REGEN_DISABLED")
fight:SetScript("OnEvent", function() if mode then close() end end)

-- `bringing`: what Blizzard's bind screen was binding, { func, params }; nil: editing.
-- `action`: a target action the player handed over with: binding, its targets are
-- chosen at once; editing, its fresh thing is held.
local function start(bringing, action)
	if InCombatLockdown() or not catching then return end
	build()
	setAll()
	ClearCursor()
	binding = nil
	if bringing then
		-- what it is, for the box; off the cursor again until a slot is pressed: the
		-- cursor is cleared under us as the window under it leaves the focus
		if not (pcall(bringing.func, unpack(bringing.params)) and holding()) then return ClearCursor() end
		local kind, a, _, c = GetCursorInfo()
		binding = { func = bringing.func, params = bringing.params, kind = kind, a = a, c = c }
		ClearCursor()
	end
	mode, from, lit, choosing = bringing and "bind" or "edit", nil, nil, nil
	hidePlay(true)
	dim:Show()
	screen:Show()
	catcher:Show()
	if action and bringing then
		choosing = choice(action, action)
	elseif action and action.pick then
		choosing = choice(action.pick, action)
	elseif action then
		hold(action)
	end
	draw()
end

-- the editor opened editing, holding what `pickup` ({ func, params }) puts on the
-- cursor, or nothing (nil)
function SC.EditHolding(pickup)
	start(nil, { fresh = function() return pickup end })
	undim() -- refused (a fight): the shade a wheel kept goes
end

-- The extension keys, while Blizzard's bind screen or Edit Action Bar is open (picking,
-- not holding: its Back then undoes): bare Square for all bars, and each target
-- action's (bare Cross: Wheels; Triangle too in Edit Action Bar, where it is free, but
-- not in the bind screen, where it is Blizzard's own Edit Action Bar), which its editor
-- leaves free (no trigger: the top bar, whose face buttons bind nothing; Circle is its
-- Back). Each closes Blizzard's through its Back and opens ours, in the same mode.
-- their prompts: Blizzard's footer look, at the other end of its info box from its own
local notice = legend(UIParent)
notice:Hide()
local owner = CreateFrame("Frame")
local armed, bringing, handing, wasDown = false, nil, nil, {}
-- a target action's prompt in Blizzard's screen, or nil where it is not handed over
local function handOverWords(action, editing)
	if editing == "BIND_ACTION" then return action.handOver and action.label end
	return action.handOver or action.pick and action.pick.label
end
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	local edit = GamepadActionBarEditFrame
	local shown = edit ~= nil and edit:IsShown()
	local editing = shown and edit.activeMode
	-- bare: with a trigger or shoulder held, these are slots of Blizzard's bars
	local bare = true
	for _, key in ipairs(SC.CHORD_KEYS) do bare = bare and not IsKeyDown(key) end
	local keys = { { key = HAND_OVER } }
	for _, action in ipairs(SC.targetActions) do
		if handOverWords(action, editing) then keys[#keys + 1] = { key = action.key, action = action } end
	end
	for _, each in ipairs(keys) do
		local down = IsKeyDown(each.key)
		if down and not wasDown[each.key] and armed and bare then handing = { bringing = bringing, action = each.action } end
		wasDown[each.key] = down
	end
	if handing and not shown then
		start(handing.bringing, handing.action)
		handing = nil
	end
	local want = (editing == "BIND_ACTION" or editing == "SELECT_ACTION_TO_PICKUP") and not InCombatLockdown()
		and _G[BACK_BUTTON] ~= nil and SC.Used() and editing
	if want ~= armed then
		ClearOverrideBindings(owner)
		if want then
			local prompts = { { HAND_OVER, "All Bars" } }
			SetOverrideBindingClick(owner, true, HAND_OVER, BACK_BUTTON)
			for _, action in ipairs(SC.targetActions) do
				local words = handOverWords(action, editing)
				if words then
					SetOverrideBindingClick(owner, true, action.key, BACK_BUTTON)
					prompts[#prompts + 1] = { action.key, words }
				end
			end
			notice.Set(prompts)
			notice:ClearAllPoints()
			notice:SetPoint("TOPRIGHT", editing == "BIND_ACTION" and edit.BindingInfoFrame or edit.EditActionBarsInfoFrame, "BOTTOMRIGHT")
		end
		notice:SetShown(want and true or false)
		armed = want
	end
	bringing = armed and editing == "BIND_ACTION" and edit.pickupFunc
		and { func = edit.pickupFunc, params = edit.pickupParams or {} } or nil
end)
