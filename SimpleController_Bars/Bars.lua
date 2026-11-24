-- The chord bars, on Blizzard's own bar template: up to six chords (CB.CHORDS), a
-- shoulder with L2, R2 or both, in any order. Each is a setting (Settings.lua),
-- applied at the next reload.
--
-- While a shoulder is held Blizzard shows its targeting bar. A watcher parented to
-- that bar takes the eight keys for as long as it is visible. The player's own chords
-- (Custom 1-4, docs/proposals/pressed-chords.md) take them the same way while a
-- starter (a paddle, a stick click) is held: each starter is bound, written from the
-- chords set, to a button of ours whose secure press binds them and whose release,
-- with no starter left held, frees them. Whoever has the keys, each key's button reads
-- the pad (GetGamePadState, which secure code may call in a fight) for the chord, of
-- every chord on, whose buttons are exactly those held, the rule the editor picks bars
-- by. One: that chord, its slot, after an up-click on the hostile bar's cross spends a
-- shoulder's tab-target. None: the targeting bar's own button, or nothing.
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
CB.ACTIVE_LEVEL = 5 -- the frame level Blizzard raises the bar a trigger lights to
CB.LIT_BARS = { "leftBar", "rightBar", "stanceBar", "bottomBar" }

-- Each button's place in the pad's state (its buttons from 1; ButtonBindingToIndex
-- counts from 0), the mapped layout every pad shares.
local INDEX = {}
local function indexOf(key)
	if INDEX[key] == nil then
		local index = C_GamePad.ButtonBindingToIndex(key)
		INDEX[key] = index and index + 1 or false
	end
	return INDEX[key] or nil
end
local function padDown()
	local state = C_GamePad.GetDeviceMappedState()
	return function(key)
		local index = indexOf(key)
		return state and index and state.buttons[index]
	end
end

-- A chord's press look, on its big bar.
local function buildWatch(chord)
	local watch = CB.Watch(nil, chord.face.bar, chord.face.bar)
	for i, shown in ipairs(chord.face.bar.actionButtons) do
		watch:SetFrameRef("button" .. i, shown)
		watch:SetFrameRef("cover" .. i, CB.Cover(shown))
	end
	chord.watch = watch
end

-- With a shoulder in it, a chord's cast first spends that shoulder's tab-target.
local function consume(chord)
	local shoulder = tContains(chord.keys, "PADLSHOULDER") or tContains(chord.keys, "PADRSHOULDER")
	return shoulder and ("/click %s LeftButton\n"):format(CONSUME) or ""
end

-- The button that casts a chord's slot for key i, made once.
local function castFor(chord, i)
	local name = ("SimpleControllerBarsCast%s%d"):format(chord.setting, i)
	if not _G[name] then
		local cast = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
		cast:RegisterForClicks("AnyDown")
		cast:SetAttribute("useOnKeyDown", true)
		cast:SetAttribute("type", "action")
		cast:SetAttribute("action", chord.first + i - 1)
	end
	return name
end

-- A group's eight buttons (a shoulder's, or the player's own chords'), one per key,
-- each picking among `all`, every chord on, by `keys` (their buttons), so a press
-- reaches the same chord whichever group has the keys. Returns the snippets that bind
-- the keys to them and free them again, run by `binder`.
local function buildFires(group, all, keys, binder)
	local wants = {}
	for n, chord in ipairs(all) do
		wants[n] = CB.Pattern(keys, function(key) return tContains(chord.keys, key) end)
		binder:SetFrameRef("watch" .. n, chord.watch)
	end
	local bind = { "self:ClearBindings()" }
	group.fires = {}
	for i, key in ipairs(CB.KEYS) do
		local name = "SimpleControllerBarsFire" .. group.tag .. i
		local fire = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
		fire:RegisterForClicks("AnyDown", "AnyUp")
		fire:SetAttribute("useOnKeyDown", true)
		fire:SetAttribute("type", "macro")
		fire:SetAttribute("cb-pass", group.pass(i))
		for k, each in ipairs(keys) do fire:SetAttribute("cb-index" .. k, indexOf(each)) end
		for n, chord in ipairs(all) do
			fire:SetAttribute("cb-chord" .. n, consume(chord) .. ("/click %s LeftButton 1"):format(castFor(chord, i)))
			fire:SetAttribute("cb-slot" .. n, chord.first + i - 1)
			fire:SetAttribute("cb-want" .. n, wants[n])
			fire:SetFrameRef("watch" .. n, chord.watch)
		end
		SecureHandlerWrapScript(fire, "OnClick", binder, CB.FireSnippet(i, #all, #keys))
		group.fires[i] = fire
		bind[#bind + 1] = ("self:SetBindingClick(true, %q, %q, 'LeftButton')"):format(key, name)
	end
	local free = ([[
		self:ClearBindings()
		for n = 1, %d do
			local watch = self:GetFrameRef("watch" .. n)
			for i = 1, 8 do watch:RunAttribute("cb-release", i) end
		end
	]]):format(#all)
	return table.concat(bind, "\n"), free
end

-- A shoulder's: while its targeting bar shows; with no chord, that bar's own button.
local function buildShoulderKeys(shoulder, bars, all, keys)
	local binder = CreateFrame("Frame", nil, bars[shoulder.targeting], "SecureHandlerBaseTemplate")
	shoulder.pass = function(i)
		local pass = bars[shoulder.targeting].actionButtons[i]:GetName()
		return ("/click %s LeftButton 1\n/click %s LeftButton"):format(pass, pass)
	end
	local bind, free = buildFires(shoulder, all, keys, binder)
	SecureHandlerWrapScript(binder, "OnShow", binder, bind)
	SecureHandlerWrapScript(binder, "OnHide", binder, free)
end

local function starterOf(group, key)
	for _, chord in ipairs(group.chords) do
		if tContains(chord.keys, key) then return chord end
	end
end

-- The player's own chords': while a starter is held, each starter's button keeping
-- whether it is down (its own edges, never the pad's state, which may not have caught
-- up); with no chord, nothing. The starters are bound by `owner`, written from the
-- chords set (the player's choice: no Keybindings entry); non-priority, as the extra
-- buttons are, to win over the gamepad's own hold on a button (L3's auto run).
local function buildPressedKeys(group, all, keys, owner)
	local binder = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
	group.pass = function() return "" end
	local bind, free = buildFires(group, all, keys, binder)
	binder:SetAttribute("cb-bind", bind)
	binder:SetAttribute("cb-free", free)
	local starters = {}
	for _, chord in ipairs(group.chords) do
		for _, key in ipairs(chord.keys) do
			if CB.IsStarterKey(key) and not tContains(starters, key) then starters[#starters + 1] = key end
		end
	end
	for _, key in ipairs(starters) do
		local button = CreateFrame("Button", "SimpleControllerBarsStart" .. key, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
		button:RegisterForClicks("AnyDown", "AnyUp")
		button:SetFrameRef("binder", binder)
		button:SetAttribute("cb-key", key)
		for k, each in ipairs(starters) do button:SetAttribute("cb-starter" .. k, each) end
		SecureHandlerWrapScript(button, "OnClick", button, ([[
			local binder = self:GetFrameRef("binder")
			binder:SetAttribute("cb-held-" .. self:GetAttribute("cb-key"), down and true or nil)
			local held = false
			for k = 1, %d do held = held or binder:GetAttribute("cb-held-" .. self:GetAttribute("cb-starter" .. k)) end
			binder:RunAttribute(held and "cb-bind" or "cb-free")
			return false
		]]):format(#starters))
		SetOverrideBindingClick(owner, false, key, button:GetName(), "LeftButton")
		-- bound in Keybindings since the chord was set: the bar wins (the extra buttons
		-- leave it out, CB.IsStarter), and the player is told
		local action = GetBindingAction(key)
		if action ~= "" then
			CB.Say(("%s is bound to %s in Keybindings, but it starts %s: it does only that."):format(
				GetBindingText(key), CB.BindingName(action), CB.RowName(starterOf(group, key))))
		end
	end
end

local function syncMacros(groups, all)
	for _, group in ipairs(groups) do
		for i, fire in ipairs(group.fires) do
			for n, chord in ipairs(all) do
				local slot = chord.first + i - 1
				local body = GetActionInfo(slot) == "macro" and GetMacroBody(GetActionText(slot))
				fire:SetAttribute("cb-macro" .. n, body and consume(chord) .. body or nil)
			end
		end
	end
end

-- faces(chord): that chord's bars on this page unit. A shoulder's beside the bottom
-- bar; the player's own in a row over Blizzard's bars.
local ABOVE = 210
local function place(bars, groups, faces)
	local _, by = bars.bottomBar:GetCenter()
	local _, ly = bars.leftBar:GetCenter()
	if not by or not ly then return false end
	local y = ly * bars.leftBar:GetEffectiveScale() / bars.bottomBar:GetEffectiveScale() - by - BELOW_LEFT
	for _, group in ipairs(groups) do
		for n, chord in ipairs(group.chords) do
			local face = faces(chord)
			local x, up
			if group.pressed then
				x, up = (n - (#group.chords + 1) / 2) * (face.small:GetWidth() + GAP), ABOVE
			else
				x = group.dir * (BESIDE_BOTTOM + (n > 1 and face.small:GetWidth() + GAP or 0))
				up = n > 2 and face.small:GetHeight() + GAP or 0
			end
			for _, bar in ipairs({ face.small, face.bar }) do
				CB.Put(bars, bar, x, y + up, chord)
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
	face.prompt = CB.Prompt(chord.keys, face.bar, box)
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

local function show(group, held, bars)
	if group.held == held then return end
	local was = group.held
	group.held = held
	if held and not was then
		if group.targeting then C_GamepadTargeting.Disable() end
		playAll(group.unfaded)
	elseif was and not held then
		stopAll(group.unfaded)
	end
	showShoulder(group, held, bars, function(chord) return chord.face end)
	if not held and group.targeting and bars[group.targeting]:IsShown() then C_GamepadTargeting.Enable() end
end

-- the chord of `group` held now, of every chord on (`held`): a shoulder's only while
-- its targeting bar has the keys
local function heldIn(group, held, bars)
	if not (held and tContains(group.chords, held)) then return nil end
	if group.targeting and not bars[group.targeting]:IsShown() then return nil end
	return held
end

-- Blizzard's bind screen and Edit Action Bar hide the bars of play and draw their own:
-- there ours show greyed beside its copies, for they are edited in our own editor
-- (Simple Controller's), which a key hands over to.
local GREYED = 0.5
local function buildGreyed(edit, groups)
	local unit = edit.PageUnit
	local box = CB.Mirror(unit)
	local faces = {}
	for _, group in ipairs(groups) do
		for _, chord in ipairs(group.chords) do
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
			placed = place(unit.actionBars, groups, function(chord) return faces[chord] end)
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
	-- the groups that take the eight keys: each shoulder with its chords on, and the
	-- player's own chords
	local groups, all = {}, {}
	local pressed = { tag = "P", pressed = true, chords = {} }
	for _, shoulder in ipairs(SHOULDERS) do
		shoulder.chords = {}
		for _, chord in ipairs(CB.CHORDS) do
			if chord.shoulder == shoulder.tag and placed[chord] then shoulder.chords[#shoulder.chords + 1] = chord end
		end
		if #shoulder.chords > 0 then groups[#groups + 1] = shoulder end
	end
	for _, row in ipairs(CB.PRESSED) do
		if placed[row] then pressed.chords[#pressed.chords + 1] = row end
	end
	if #pressed.chords > 0 then groups[#groups + 1] = pressed end
	for _, group in ipairs(groups) do
		for _, chord in ipairs(group.chords) do
			chord.first = placed[chord].first
			all[#all + 1] = chord
		end
	end
	-- the editor (Simple Controller's) hides our bars of play while it is open, as it
	-- hides Blizzard's
	SimpleController.OnEditor(function(open) CB.Mirror(pageUnit):SetAlpha(open and 0 or 1) end)
	if #groups == 0 then return end

	for _, chord in ipairs(all) do
		if chord.flyout and pageUnit[chord.flyout] then RegisterStateDriver(pageUnit[chord.flyout], "visibility", "hide") end
		chord.face = buildFace(chord, pageUnit, "SimpleControllerBars")
		buildWatch(chord)
	end
	local keys = SimpleController.ChordKeys(all)
	local owner = CreateFrame("Frame")
	for _, group in ipairs(groups) do
		group.unfaded = {}
		if group.pressed then
			buildPressedKeys(group, all, keys, owner)
		else
			for _, key in ipairs({ "leftBar", "rightBar", "bottomBar", "stanceBar" }) do
				group.unfaded[#group.unfaded + 1] = heldAlpha(bars[key], 1)
			end
			buildShoulderKeys(group, bars, all, keys)
		end
		showShoulder(group, nil, bars, function(chord) return chord.face end)
	end
	local function ours(chord) return chord.face end
	place(bars, groups, ours)
	if GamepadActionBarEditFrame then buildGreyed(GamepadActionBarEditFrame, groups) end
	-- in the editor: each chord's keys, slots and its bars of play, where it is drawn
	for _, chord in ipairs(all) do
		SimpleController.AddBar({ keys = chord.keys, first = chord.first, small = chord.face.small, big = chord.face.bar })
	end
	local function replace() CB.AfterCombat(function() place(bars, groups, ours) end) end
	CB.OnRelayout(function()
		place(bars, groups, ours)
		for _, group in ipairs(groups) do showShoulder(group, group.held, bars, ours) end
	end)
	local function resync() CB.AfterCombat(function() syncMacros(groups, all) end) end
	syncMacros(groups, all)
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
		local held = SimpleController.Exact(all, padDown())
		for _, group in ipairs(groups) do show(group, heldIn(group, held, bars), bars) end
	end)
end)
