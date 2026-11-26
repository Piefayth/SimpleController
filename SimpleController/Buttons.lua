-- The suite's action buttons: they show an action slot and press nothing (the bars'
-- casts are secure buttons of their own). Ours from the ground up, wearing Blizzard's
-- gamepad art: never Blizzard's action-bar button templates or their code
-- (docs/proposals/own-bar-buttons.md). An ActionBarButtonTemplate button enters
-- Blizzard's shared button lists as it is made, and Blizzard's loops over those lists
-- (plain pairs) then run as ours for every button after it: its own bars' fields turned
-- ours and in a fight their shoulder switch and casts were refused (taint.log,
-- 2026-11-24). The base ActionButtonTemplate enters no list (BaseActionButtonMixin_OnLoad,
-- Blizzard_ActionBar/Shared/ActionButton.lua:1607), as LibActionButton builds on it.
--
-- SimpleController.ActionButton(parent, shape, secure) -> button; shape "Circle" or
-- "Square"; secure: protected, for a bar of play whose secure press moves it (a copy
-- in an editor is plain, so it shows and moves in a fight).
-- button:SetAction(slot), button:SetExpanded(on) (Blizzard's two sizes), and the art
-- the bars use: icon, SlotArt, PushedTexture, Count, Name.
local _, SC = ...

local SHAPES = {
	Circle = {
		normal = "gamepad-actionbar-circleslot-border-normal",
		pushed = "gamepad-actionbar-circleslot-border-pressed",
		checked = "gamepad-actionbar-circleslot-border-selected",
		border = "gamepad-actionbar-circleslot-iconframe-border",
		shadow = "gamepad-actionbar-circleslot-dropshadow",
		focus = "gamepad-actionbar-focus-bg-circ", glow = "gamepad-actionbar-fx-circglw", glowOut = 4,
		mask = "CircleMask",
		collapsed = 30, expanded = 38, -- GamepadActionBarStyleUtil.CIRCULAR_BUTTON_*_SIZE
	},
	Square = {
		normal = "gamepad-actionbar-squareslot-border-normal",
		pushed = "gamepad-actionbar-squareslot-border-pressed",
		checked = "gamepad-actionbar-squareslot-border-selected",
		border = "UI-HUD-ActionBar-IconFrame-Border",
		shadow = "gamepad-actionbar-squareslot-dropshadow",
		focus = "gamepad-actionbar-focus-bg-square", glow = "gamepad-actionbar-fx-squareglw", glowOut = 5,
		mask = "SquareMask",
		collapsed = 32, expanded = 40, -- GamepadActionBarStyleUtil.SQUARE_BUTTON_*_SIZE
	},
}
local EMPTY_SLOT = "UI-HUD-ActionBar-IconFrame-Slot"
-- A bar's empty slots wear their button: the d-pad's arrows, the face buttons'
-- symbols in the controller's icon set (InputDeviceIconSetManager's), as Blizzard's
-- bars do (its INPUT_DEVICE_ACTION_BUTTON_TEXTURE_SETS, ActionBarButton.lua, local
-- to its file, so its atlas names are here). By the button's place on the bar, 1-8.
local DPAD = { "dpadleft", "dpadup", "dpadright", "dpaddown" }
local FACES = {
	Generic = { "xbox-x", "xbox-y", "xbox-b", "xbox-a" },
	Letters = { "xbox-x", "xbox-y", "xbox-b", "xbox-a" },
	Shapes = { "ps-square", "ps-triangle", "ps-circle", "ps-cross" },
	Reverse = { "xbox-y", "xbox-x", "xbox-a", "xbox-b" },
}
local function emptyArt(place)
	if not place then return EMPTY_SLOT end
	if place <= 4 then return ("gamepad-actionbar-squareslot-generic-%s-normal"):format(DPAD[place]) end
	local set = FACES[InputDeviceIconSetManager:GetActiveInputDeviceIconSet()] or FACES.Generic
	return ("gamepad-actionbar-circleslot-%s-normal"):format(set[place - 4])
end
local MANA = { 0.5, 0.5, 1 }
local UNUSABLE = { 0.4, 0.4, 0.4 }
local FAR = { 0.8, 0.1, 0.1 }

local bySlot = {} -- slot -> { [button] = true }
local all = {}

local function tint(button)
	local slot = button.slot
	local color
	if slot and C_ActionBar.HasAction(slot) then
		local usable, lacking = C_ActionBar.IsUsableAction(slot)
		if button.far then color = FAR elseif lacking then color = MANA elseif not usable then color = UNUSABLE end
	end
	if color then button.icon:SetVertexColor(color[1], color[2], color[3]) else button.icon:SetVertexColor(1, 1, 1) end
end

-- cooldown numbers follow the game's own option, as Blizzard's buttons do
local function numbers(button)
	button.cooldown:SetHideCountdownNumbers(not C_CVar.GetCVarBool("countdownForCooldowns"))
end

local function cooldowns(button)
	local slot = button.slot
	if not (slot and C_ActionBar.HasAction(slot)) then
		button.cooldown:Clear()
		button.chargeCooldown:Clear()
		return
	end
	-- duration objects: the one way addon code may show a cooldown whose values are
	-- secret (12.0.1; SetCooldownFromDurationObject, clearing when it is zero). An
	-- action with no charges has no charge duration (nil, measured 2026-11-24).
	local function show(cooldown, duration)
		if duration then cooldown:SetCooldownFromDurationObject(duration, true) else cooldown:Clear() end
	end
	show(button.cooldown, C_ActionBar.GetActionCooldownDuration(slot, false))
	show(button.chargeCooldown, C_ActionBar.GetActionChargeDuration(slot))
end

local function refresh(button)
	local slot = button.slot
	local has = slot and C_ActionBar.HasAction(slot)
	button.icon:SetTexture(has and C_ActionBar.GetActionTexture(slot) or nil)
	button.icon:SetShown(has and true or false)
	button.SlotArt:SetAtlas(emptyArt(button.place))
	button.SlotArt:SetShown(not has)
	button.Count:SetText(has and C_ActionBar.GetActionDisplayCount(slot, 9999) or "")
	-- a macro's name, as Blizzard's buttons show it (UpdateAction, ActionButton.lua)
	button.Name:SetText(has and C_ActionBar.UsesActionText(slot) and C_ActionBar.GetActionText(slot) or "")
	button:SetChecked(has and (C_ActionBar.IsCurrentAction(slot) or C_ActionBar.IsAutoRepeatAction(slot)) or false)
	tint(button)
	cooldowns(button)
end

local methods = {}
function methods:SetAction(slot)
	if self.slot then
		local on = bySlot[self.slot]
		if on then on[self] = nil end
	end
	self.slot, self.far = slot, nil
	if slot then
		bySlot[slot] = bySlot[slot] or {}
		bySlot[slot][self] = true
		C_ActionBar.EnableActionRangeCheck(slot, true)
	end
	refresh(self)
end
-- Blizzard's two looks (ActionBarStyles.lua): at rest its drop shadow 4 out; grown,
-- the focus shadow 13 out, at the alpha its gameplay focus animation ends on
local SHADOW = { [false] = 4, [true] = 13 }
local function outset(texture, by)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", -by, by)
	texture:SetPoint("BOTTOMRIGHT", by, -by)
end
function methods:SetExpanded(on)
	on = on and true or false
	local size = on and self.shape.expanded or self.shape.collapsed
	self:SetSize(size, size)
	outset(on and self.focus or self.shadow, SHADOW[on])
	self.shadow:SetShown(not on)
	self.focus:SetShown(on)
	self.focus:SetAlpha(on and 0.4 or 1)
	if on then outset(self.CheckedTexture, 4) else self.CheckedTexture:SetAllPoints(self) end
end

function SC.ActionButton(parent, shape, secure)
	local art = SHAPES[shape]
	local button = CreateFrame("CheckButton", nil, parent, secure and "ActionButtonTemplate, SecureFrameTemplate" or "ActionButtonTemplate")
	button:EnableMouse(false)
	button.shape = art
	for name, fn in pairs(methods) do button[name] = fn end
	-- Blizzard's gamepad look: its own mask and frame for the shape
	button.IconMask:Hide()
	button.icon:RemoveMaskTexture(button.IconMask)
	local mask = button:CreateMaskTexture()
	mask:SetAtlas(art.mask)
	mask:SetPoint("TOPLEFT", 3, -3)
	mask:SetPoint("BOTTOMRIGHT", -3, 3)
	button.icon:AddMaskTexture(mask)
	button.SlotArt:SetAtlas(EMPTY_SLOT)
	button.SlotArt:AddMaskTexture(mask)
	button.SlotBackground:Hide()
	-- the shadows and the editor's lit look, named as Blizzard's buttons name them
	-- (<Shape>Shadow, <Shape>ShadowFocus, <Shape>GlowFocus, their animations;
	-- ActionBarButton.xml)
	local shadow = button:CreateTexture(nil, "BACKGROUND", nil, -2)
	shadow:SetAtlas(art.shadow)
	button.shadow = shadow
	button[shape .. "Shadow"] = shadow
	local focus = button:CreateTexture(nil, "BACKGROUND", nil, -1)
	focus:SetAtlas(art.focus)
	focus:Hide()
	button.focus = focus
	button[shape .. "ShadowFocus"] = focus
	local glow = button:CreateTexture(nil, "BACKGROUND", nil, -1)
	glow:SetAtlas(art.glow)
	outset(glow, art.glowOut)
	glow:Hide()
	button[shape .. "GlowFocus"] = glow
	local start = button:CreateAnimationGroup()
	start:SetToFinalAlpha(true)
	for _, each in ipairs({ { glow, 0 }, { focus, 0.6 } }) do
		local fade = start:CreateAnimation("Alpha")
		fade:SetTarget(each[1])
		fade:SetDuration(0.33)
		fade:SetFromAlpha(1)
		fade:SetToAlpha(each[2])
	end
	button["EditMode" .. shape .. "FocusStartAnim"] = start
	-- the editor's art for a slot that binds nothing (its SetupNonBindableActionArt)
	local special = button:CreateTexture(nil, "BACKGROUND")
	special:SetTexture([[Interface\Cursor\Interact]])
	special:SetAllPoints()
	special:AddMaskTexture(mask)
	special:Hide()
	button.SpecialActionIcon = special
	local permabound = button:CreateTexture(nil, "OVERLAY")
	permabound:SetAtlas("gamepad-actionbar-circleslot-permabound")
	permabound:SetPoint("TOPLEFT", 3, -2)
	permabound:SetPoint("BOTTOMRIGHT", -2, 3)
	permabound:Hide()
	button.PermaboundOverlay = permabound
	button:SetNormalAtlas(art.normal)
	button:SetPushedAtlas(art.pushed)
	button.CheckedTexture:SetAtlas(art.checked)
	button.CheckedTexture:SetBlendMode("BLEND")
	-- the base template draws its frame art larger than the button (the keyboard bars'
	-- look); the gamepad's fits it exactly (UpdateButtonArtAnchoring, ActionBarButton.lua)
	for _, key in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture", "Border",
		"Flash", "NewActionTexture", "SpellHighlightTexture" }) do
		local art = button[key]
		if art then
			art:ClearAllPoints()
			art:SetAllPoints(button)
		end
	end
	button.NormalTexture:SetDrawLayer("OVERLAY")
	button.PushedTexture:SetDrawLayer("OVERLAY")
	if button.Border then button.Border:SetAtlas(art.border) button.Border:Hide() end
	if button.HotKey then button.HotKey:Hide() end
	button.cooldown:SetSwipeTexture(art.mask == "CircleMask" and "Interface\\CharacterFrame\\TempPortraitAlphaMask" or "Interface\\Buttons\\WHITE8X8")
	numbers(button)
	button:SetExpanded(false)
	all[button] = true
	return button
end

-- SimpleController.ActionBar(parent, name, secure) -> bar: eight of ours (secure as above) in Blizzard's gamepad bar
-- layout, d-pad squares left and face circles right, with the parts of
-- GamepadActionBarTemplate the suite uses: actionButtons, Left/Right.ActionButton1-4
-- (left, top, right, bottom), BackgroundFocus, EditModeFocusBackground and each
-- half's EditModeFocusParticlesSingle (Blizzard's own art templates, which run no
-- code); CollapseActionButtons, ExpandActionButtons, Show/HideButtonIcons,
-- SetActionButtonsSaturation, SetAction(i, slot).
-- Sizes and places: Blizzard's LEFTSQUARE_RIGHTCIRCLE style (ActionBarStyles.lua).
local BAR_SIZE = { [false] = { 208, 68 }, [true] = { 266, 86 } }
local PLACES = { -- [expanded][half][button] = { x, y } from the bar's centre
	[false] = {
		Left = { { -92, 0 }, { -58, 17 }, { -24, 0 }, { -58, -17 } },
		Right = { { 25, 0 }, { 55, 18 }, { 85, 0 }, { 55, -18 } },
	},
	[true] = {
		Left = { { -119, 0 }, { -75, 23 }, { -31, 0 }, { -75, -23 } },
		Right = { { 32, 0 }, { 70, 23 }, { 108, 0 }, { 70, -23 } },
	},
}
local GLYPHS = {
	Left = { "GAMEPAD_DPAD_LEFT", "GAMEPAD_DPAD_TOP", "GAMEPAD_DPAD_RIGHT", "GAMEPAD_DPAD_BOTTOM" },
	Right = { "GAMEPAD_FACE_LEFT", "GAMEPAD_FACE_TOP", "GAMEPAD_FACE_RIGHT", "GAMEPAD_FACE_BOTTOM" },
}

local barMethods = {}
local function layOut(bar, expanded)
	bar:SetSize(unpack(BAR_SIZE[expanded]))
	for _, half in ipairs({ "Left", "Right" }) do
		for i = 1, 4 do
			local button, place = bar[half]["ActionButton" .. i], PLACES[expanded][half][i]
			button:SetExpanded(expanded)
			button:ClearAllPoints()
			button:SetPoint("CENTER", bar, "CENTER", place[1], place[2])
		end
	end
end
function barMethods:CollapseActionButtons() layOut(self, false) end
function barMethods:ExpandActionButtons() layOut(self, true) end
function barMethods:ShowButtonIcons() for _, button in ipairs(self.actionButtons) do button.ButtonIcon:Show() end end
function barMethods:HideButtonIcons() for _, button in ipairs(self.actionButtons) do button.ButtonIcon:Hide() end end
function barMethods:SetActionButtonsSaturation(desaturation)
	for _, button in ipairs(self.actionButtons) do button.icon:SetDesaturation(desaturation) end
end

function SC.ActionBar(parent, name, secure)
	local bar = CreateFrame("Frame", name, parent)
	for key, fn in pairs(barMethods) do bar[key] = fn end
	bar.actionButtons = {}
	for _, half in ipairs({ "Left", "Right" }) do
		local group = CreateFrame("Frame", nil, bar)
		group:SetSize(256, 128)
		group:SetPoint(half == "Left" and "LEFT" or "RIGHT")
		bar[half] = group
		local particles = CreateFrame("Frame", nil, group, "GamepadActionBarGroupParticlesSingle")
		particles:SetPoint("CENTER", half == "Left" and -70 or 62, 0)
		particles:Hide()
		group.EditModeFocusParticlesSingle = particles
		for i = 1, 4 do
			local button = SC.ActionButton(bar, half == "Left" and "Square" or "Circle", secure)
			local glyph = CreateFrame("Frame", nil, button, "InputIconTextureFrameTemplate")
			glyph:SetSize(15, 15)
			glyph:SetPoint("TOPRIGHT", 0, half == "Left" and -1 or -3)
			glyph:SetInputKey(_G[GLYPHS[half][i]])
			glyph:Hide()
			button.ButtonIcon = glyph
			group["ActionButton" .. i] = button
			bar.actionButtons[#bar.actionButtons + 1] = button
			button.place = #bar.actionButtons
			refresh(button)
		end
	end
	local background = CreateFrame("Frame", nil, bar, "GamepadActionBarEditModeFocusBackground")
	background:SetPoint("CENTER")
	bar.EditModeFocusBackground = background
	local focus = bar:CreateTexture(nil, "BACKGROUND")
	focus:SetAtlas("gamepad-actionbar-focus-bg-section")
	focus:SetSize(512, 160)
	focus:SetPoint("CENTER")
	focus:SetAlpha(0.375)
	focus:Hide()
	bar.BackgroundFocus = focus
	layOut(bar, false)
	return bar
end

-- every button of ours, for addons that dress them (Wheels' icons)
function SC.EachActionButton(fn) for button in pairs(all) do fn(button) end end

-- One frame of ours keeps every button current, from the game's events alone.
local events = CreateFrame("Frame")
local function each(fn) for button in pairs(all) do fn(button) end end
local function onSlot(slot, fn)
	local on = bySlot[slot]
	if on then for button in pairs(on) do fn(button) end end
end
local handlers = {
	ACTIONBAR_SLOT_CHANGED = function(slot) if slot == 0 then each(refresh) else onSlot(slot, refresh) end end,
	ACTIONBAR_UPDATE_COOLDOWN = function() each(cooldowns) end,
	SPELL_UPDATE_COOLDOWN = function() each(cooldowns) end,
	SPELL_UPDATE_CHARGES = function() each(refresh) end,
	ACTIONBAR_UPDATE_STATE = function() each(refresh) end,
	ACTIONBAR_UPDATE_USABLE = function() each(tint) end,
	ACTION_USABLE_CHANGED = function(changes)
		for _, change in ipairs(changes) do onSlot(change.slot, tint) end
	end,
	ACTION_RANGE_CHECK_UPDATE = function(slot, inRange, checksRange)
		onSlot(slot, function(button)
			button.far = checksRange and not inRange
			tint(button)
		end)
	end,
	PLAYER_ENTERING_WORLD = function() each(refresh) end,
	UPDATE_SHAPESHIFT_FORM = function() each(refresh) end,
	UPDATE_MACROS = function() each(refresh) end,
	SPELLS_CHANGED = function() each(refresh) end,
	BAG_UPDATE_DELAYED = function() each(refresh) end,
	PLAYER_TARGET_CHANGED = function() each(tint) end,
	CVAR_UPDATE = function(name) if name == "countdownForCooldowns" then each(numbers) end end,
}
for event in pairs(handlers) do events:RegisterEvent(event) end
-- another controller's symbols on the empty face slots
InputDeviceIconSetManager:RegisterActiveInputDeviceIconSetUpdatedCallback(function() each(refresh) end, events)
events:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
