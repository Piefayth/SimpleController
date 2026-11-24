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
-- it in its glowing focused state (modifierIcon, in play too), and in the bind
-- screen a focus background frame behind it, sparkles on its two halves and a
-- shadow and glow on each button (Blizzard_GamepadActionBars/ActionBarFocusFX.lua).
-- While our chord is held the frames are held invisible by animations of ours (a
-- frame's alpha, over the animations Blizzard plays on what is in it), and the
-- button textures, which Blizzard's own animation leaves visible, are set invisible
-- each frame there (art, not state; measured at alpha 0 by a probe, 2026-11-23). In
-- the bind screen our bar plays the same focus as theirs.
local function glowParts(bar)
	local parts = { bar.EditModeFocusBackground, bar.modifierIcon }
	for _, half in ipairs({ bar.Left, bar.Right }) do
		if half and half.EditModeFocusParticlesSingle then parts[#parts + 1] = half.EditModeFocusParticlesSingle end
	end
	return parts
end

-- Each button carries a square and a round glow with their shadows (Blizzard uses the
-- square ones on the d-pad's four, the round ones on the face buttons'), and the gold
-- checked frame the bind screen shows on every button of the bar it binds to.
local GLOWS = { "SquareGlowFocus", "SquareShadowFocus", "CircleGlowFocus", "CircleShadowFocus", "CheckedTexture" }
local function buttonGlows(bar, alpha)
	for _, button in ipairs(bar.actionButtons) do
		for _, key in ipairs(GLOWS) do
			if button[key] then button[key]:SetAlpha(alpha) end
		end
	end
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
		small = CreateFrame("Frame", prefix .. "Rest" .. chord.setting, box, "GamepadActionBarTemplate"),
		bar = CreateFrame("Frame", prefix .. chord.setting, box, "GamepadActionBarTemplate"),
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
		-- whichever bar Blizzard lit: in the bind screen it may not be the chord's
		for _, key in ipairs(CB.LIT_BARS) do
			if bars[key]:GetFrameLevel() == CB.ACTIVE_LEVEL then
				playAll(face.shrunk[key])
				playAll(hiderOf(bars[key]))
			end
		end
		if face.bind then glow(face.bar, true) end
		return
	end
	face.prompt:SetPressable()
	face.hideBig:Play()
	face.hideSmall:Stop()
	for _, key in ipairs(CB.LIT_BARS) do
		stopAll(face.shrunk[key])
		stopAll(hiderOf(bars[key]))
		if face.bind then buttonGlows(bars[key], 1) end
	end
	if face.bind then glow(face.bar, false) end
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

-- Blizzard's bind screen hides the real bars and draws its own, so ours get a copy
-- on its page unit, which grows as in play; what a chord does there is Blizzard's own
-- editing, on our spells traded into its slots (buildBindScreen). The chord held is read from
-- the buttons down, not from the bar Blizzard lights: its editor does not light again
-- when a trigger joins (L1 + L2, then R2, kept L2's bar lit).
local function heldThere(shoulders)
	for _, shoulder in ipairs(shoulders) do
		local chord = CB.ChordForKeys(shoulder.chords, IsKeyDown)
		if chord then return chord, shoulder end
	end
end

local function buildBindScreen(edit, shoulders)
	local unit = edit.PageUnit
	local bars = unit.actionBars
	local function faces(chord) return chord.bindFace end
	for _, shoulder in ipairs(shoulders) do
		for _, chord in ipairs(shoulder.chords) do
			chord.bindFace = buildFace(chord, unit, "SimpleControllerBarsBind")
			chord.bindFace.bind = true
		end
		showShoulder(shoulder, nil, bars, faces)
	end

	local placed, lit, litShoulder = false, nil, nil
	CB.OnRelayout(function() placed = false end)

	-- Blizzard's editor, in any of its modes, works on its own slots only. While one of
	-- our chords is held there, our chord's eight spells and those of the bar Blizzard
	-- lit trade slots, and our bar there shows the lit slots: the editor binds, picks
	-- up, puts down, clears and undoes on our spells natively, and closes itself after
	-- a bind. Let go (or the screen closed), they trade back, carrying the result into
	-- our slots. A spell of ours picked up and still held by the editor keeps them
	-- traded until it is put down, so its undo lands where it came from.
	local swapped
	local function exchange(a, b)
		ClearCursor()
		if HasAction(a) then
			PickupAction(a)
			PlaceAction(b)
			if GetCursorInfo() then PlaceAction(a) end
		elseif HasAction(b) then
			PickupAction(b)
			PlaceAction(a)
		end
		ClearCursor()
	end
	-- Our bar shows the traded spells by pictures in place of its icons, never by pointing
	-- its buttons at Blizzard's slots: a button of ours on one of Blizzard's slots gets
	-- that slot's updates from inside Blizzard's own work on it (its bind, its range and
	-- usable checks), which then runs tainted. Pointed there, entering Edit Action Bar
	-- after a bind was refused its focus call; with pictures, not (bisected, 2026-11-23).
	local pictureOf = {} -- button -> its picture: no fields on a template button
	-- a button showing `slot`'s spell as a picture over its own icon, hidden (nil: as it is)
	local function cover(button, slot)
		local picture = pictureOf[button]
		if not picture then
			picture = button:CreateTexture(nil, "ARTWORK", nil, 7)
			picture:SetAllPoints(button.icon)
			-- shaped as the button's own icon: round on a face button, square on the d-pad
			for i = 1, button.icon:GetNumMaskTextures() do picture:AddMaskTexture(button.icon:GetMaskTexture(i)) end
			pictureOf[button] = picture
		end
		picture:SetTexture(slot and GetActionTexture(slot) or nil)
		picture:SetShown(slot ~= nil and HasAction(slot))
		for _, key in ipairs({ "icon", "Count", "Name" }) do
			if button[key] then button[key]:SetAlpha(slot and 0 or 1) end
		end
	end
	-- While traded, each bar shows its own spells, wherever they sit: ours (in Blizzard's
	-- slots) on our enlarged bar, Blizzard's (in ours) on its shrunk one, whose pictures
	-- are inside its buttons so its shrink carries them (their alpha is art, not state).
	local function pictures(trade)
		for i, button in ipairs(trade.chord.bindFace.bar.actionButtons) do
			cover(button, trade.traded[trade.theirs[i]] and trade.theirs[i] or trade.chord.first + i - 1)
		end
		for i, button in ipairs(bars[trade.key].actionButtons) do
			cover(button, trade.traded[trade.theirs[i]] and trade.chord.first + i - 1 or nil)
		end
	end
	local function unpictured(trade)
		for _, button in ipairs(trade.chord.bindFace.bar.actionButtons) do cover(button, nil) end
		for _, button in ipairs(bars[trade.key].actionButtons) do cover(button, nil) end
	end
	-- the bar Blizzard's editor acts on: its active one, which follows the triggers held
	-- (measured: L1 + L2, then R2, moved it from L2's to L2 + R2's); a bar of the
	-- triggers', never the top bar of no trigger
	local function activeKey()
		for _, key in ipairs(CB.LIT_BARS) do
			if bars[key] == unit.activeBar then return key end
		end
	end
	-- Let go of the chord while the editor holds a spell picked from a traded slot: all
	-- trade back but that pair, so Blizzard's bar is its own again to put the spell on;
	-- the pair trades back when the editor is done with the spell, wherever it went, but
	-- for one press: that same button on that same bar of Blizzard's, which to Blizzard
	-- is putting it back where it came from (its slot), and to the player is putting it
	-- on Blizzard's button. Then the two spells stay swapped, as the editor swaps onto an
	-- occupied button. Told apart by the button down when the editor finished (its own
	-- rule: it acts on the button pressed on its active bar); a cancel is circle with no
	-- trigger, on Blizzard's top bar. The mirror: a spell picked up from Blizzard's bar
	-- before the trade (its slot left out of it, CB.TradeSlots) put down on that same
	-- button of ours is, to Blizzard, put back; then ours and it are swapped after.
	-- `pressed`: the last button pressed while the editor held a spell (a press, not a
	-- button down: the one that picked it up does not count).
	local pending, pressed
	local wasDown, wasHolding = {}, false
	local function track()
		local isHolding = edit.activeMode == "PLACE_OR_CLEAR_HELD_ACTION"
		for i, key in ipairs(CB.KEYS) do
			local down = IsKeyDown(key)
			if down and not wasDown[i] and wasHolding then pressed = { index = i, key = activeKey() } end
			wasDown[i] = down
		end
		if isHolding and not wasHolding then pressed = nil end
		wasHolding = isHolding
	end
	local function holding(slot)
		return edit.activeMode == "PLACE_OR_CLEAR_HELD_ACTION" and edit.pickupSlot == slot
	end
	local function unswap()
		if not swapped then return end
		for i, slot in ipairs(swapped.theirs) do
			if swapped.traded[slot] then
				if holding(slot) then
					pending = { ours = swapped.chord.first + i - 1, theirs = slot, index = i, key = swapped.key }
				else
					exchange(swapped.chord.first + i - 1, slot)
				end
			end
		end
		unpictured(swapped)
		swapped = nil
		CB.traded = nil
	end
	local function samePress(index, key) return pressed and pressed.index == index and pressed.key == key end
	local function settle()
		if pending and not holding(pending.theirs) then
			if not samePress(pending.index, pending.key) then exchange(pending.ours, pending.theirs) end
			pending = nil
		end
		local left = swapped and swapped.left
		if left and not holding(left.theirs) then
			if samePress(left.index, swapped.key) then exchange(left.ours, left.theirs) end
			swapped.left = nil
		end
	end
	local function swapTo(chord)
		local key = activeKey()
		if not key then return end
		local theirs = {}
		for i, button in ipairs(bars[key].actionButtons) do theirs[i] = button.action or button:GetAttribute("action") end
		if #theirs ~= 8 then return end
		local traded, left = {}, nil
		for _, slot in ipairs(CB.TradeSlots(theirs, edit.activeMode, edit.pickupSlot)) do traded[slot] = true end
		for i, slot in ipairs(theirs) do
			if traded[slot] then
				exchange(chord.first + i - 1, slot)
			else
				left = { ours = chord.first + i - 1, theirs = slot, index = i }
			end
		end
		swapped = { chord = chord, theirs = theirs, key = key, traded = traded, left = left }
		pictures(swapped)
		CB.traded = swapped -- read by the in-game test run (tools/sc_bars_test.lua)
	end

	CB.OnEditor(function(shown)
		if not shown then
			CB.AfterCombat(function()
				unswap()
				settle()
			end)
		end
	end)
	local catch = CreateFrame("Frame", nil, edit)
	catch:SetScript("OnUpdate", function()
		if not placed and not InCombatLockdown() and bars.bottomBar:GetCenter() then
			placed = place(bars, shoulders, faces)
			for _, shoulder in ipairs(shoulders) do showShoulder(shoulder, nil, bars, faces) end
		end
		local held, shoulder
		if CB.Editing(edit) then held, shoulder = heldThere(shoulders) end
		if held ~= lit then
			if litShoulder then showShoulder(litShoulder, nil, bars, faces) end
			if held then showShoulder(shoulder, held, bars, faces) end
			lit, litShoulder = held, shoulder
		end
		if not InCombatLockdown() then
			track()
			if swapped and (swapped.chord ~= held or swapped.key ~= activeKey()) then unswap() end
			settle()
			if held and not swapped then swapTo(held) end
			if swapped then pictures(swapped) end
		end
		-- every frame while held: the editor lights its bars when it likes, a frame
		-- after the chord changed or later, and must not show one enlarged meanwhile
		if lit then
			for _, key in ipairs(CB.LIT_BARS) do
				if bars[key]:GetFrameLevel() == CB.ACTIVE_LEVEL then
					playAll(lit.bindFace.shrunk[key])
					playAll(hiderOf(bars[key]))
					buttonGlows(bars[key], 0)
				else
					stopAll(lit.bindFace.shrunk[key])
					stopAll(hiderOf(bars[key]))
				end
			end
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
	local placed = CB.Layout(SimpleControllerBarsDB, CB.IsEmpty)
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
	if GamepadActionBarEditFrame then buildBindScreen(GamepadActionBarEditFrame, shoulders) end
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
