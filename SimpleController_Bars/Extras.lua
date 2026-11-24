-- Extra buttons: eight entries in Blizzard's Keybindings screen ("Simple Controller"),
-- each casting its own slot (CB.Layout), filled in Simple Controller's editor by the
-- extra's own key.
-- The player binds them to any key there; the binding is the one truth, and is
-- mirrored as a non-priority override, which beats the gamepad context's own hold
-- on a button (L3's auto run) in play and still loses to the menus' and to the
-- priority ones (shoulder+L3, centre camera). Each bound button shows in a row under
-- the bottom bar, with its key's prompt; unbound ones show nowhere.
-- One button per extra: Blizzard's Keybindings screen binds a single button (L1 and
-- L2 combos only where the game makes them Ctrl and Shift). Chords of any buttons
-- (R1 + L3) would need the keys in our own settings, pressed to set and read from the
-- pad, as WoW Companion's are: the answer if anyone asks for them.
local _, CB = ...

local COUNT = 8
-- An empty extra button's slot: Blizzard's empty slot of its keyboard bars, made round
-- by the button's own icon mask (its face buttons' slots carry their button's symbol,
-- meaningless on an extra; its plain round slot is a black void).
local NEUTRAL_SLOT = "UI-HUD-ActionBar-IconFrame-Slot"
local FIRST -- the first of their slots, from the layout at login
local BELOW_BOTTOM = 72 -- clears the bottom bar's own prompt
local GAP = 8

local function command(i) return ("CLICK SimpleControllerBarsExtra%d:LeftButton"):format(i) end

for i = 1, COUNT do _G["BINDING_NAME_" .. command(i)] = ("Extra button %d"):format(i) end

-- The key bound to each extra, the first of its keys.
local function keys()
	local out = {}
	for i = 1, COUNT do out[i] = GetBindingKey(command(i)) end
	return out
end

-- Eight round buttons in a row, holding our slots: the template's face-button four
-- (5-8) of two bars of it, since its d-pad four are square, shaped for the d-pad.
-- The second bar only lends its buttons.
local function buildRow(name, box)
	local bar = CB.InBox(CreateFrame("Frame", name, box, "GamepadActionBarTemplate"), box)
	local lender = CB.InBox(CreateFrame("Frame", nil, box, "GamepadActionBarTemplate"), box)
	local hidden = CreateFrame("Frame", nil, bar)
	hidden:Hide()
	local buttons = {}
	for _, from in ipairs({ bar, lender }) do
		from:CollapseActionButtons()
		from:HideButtonIcons()
		for i, button in ipairs(from.actionButtons) do
			if i > 4 then buttons[#buttons + 1] = button else button:SetParent(hidden) end
		end
	end
	lender:Hide()
	for i, button in ipairs(buttons) do
		button:SetParent(bar)
		button:SetAttribute("action", FIRST + i - 1)
		button:SetID(FIRST + i - 1)
		button:UpdateAction()
	end
	bar:Show()
	local center = CreateFrame("Frame", nil, bar, "SecureHandlerBaseTemplate")
	center:SetSize(1, 1)
	center:SetPoint("CENTER")
	-- each button's key under it: Blizzard's prompt, or its name where Blizzard has no
	-- picture for it (a paddle, a keyboard key)
	local row = { bar = bar, buttons = buttons, hidden = hidden, center = center, prompts = {}, names = {} }
	for _, button in ipairs(buttons) do
		for i = 1, button.icon:GetNumMaskTextures() do button.SlotArt:AddMaskTexture(button.icon:GetMaskTexture(i)) end
	end
	-- Blizzard sets the slot art again when the controller changes: kept neutral
	local keeper = CreateFrame("Frame", nil, bar)
	keeper:SetScript("OnUpdate", function()
		for _, button in ipairs(buttons) do
			if button.SlotArt:GetAtlas() ~= NEUTRAL_SLOT then button.SlotArt:SetAtlas(NEUTRAL_SLOT) end
		end
	end)
	for i, button in ipairs(buttons) do
		local prompt = CB.InBox(CreateFrame("Frame", nil, box, "InputPromptOneIconTemplate"), box)
		prompt:SetUseDropShadow(true)
		prompt:SetPoint("CENTER", button, "CENTER", 0, CB.PROMPT_Y)
		row.prompts[i] = prompt
		local name = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		name:SetPoint("CENTER", button, "CENTER", 0, CB.PROMPT_Y)
		row.names[i] = name
	end
	return row
end

-- Bound buttons in a row, centred; the rest under a hidden parent.
local function layRow(row, bound)
	local shown = {}
	for i, button in ipairs(row.buttons) do
		if bound[i] then shown[#shown + 1] = i else button:SetParent(row.hidden) end
		local labelled = CB.ShowPrompts() and bound[i] ~= nil
		local pictured = labelled and CB.HasPicture(bound[i])
		row.prompts[i]:SetShown(pictured)
		row.names[i]:SetShown(labelled and not pictured)
		row.names[i]:SetText(labelled and GetBindingText(bound[i]) or "")
	end
	local width = row.buttons[1]:GetWidth() + GAP
	for n, i in ipairs(shown) do
		local button = row.buttons[i]
		button:SetParent(row.bar)
		button:ClearAllPoints()
		button:SetPoint("CENTER", row.center, "CENTER", (n - (#shown + 1) / 2) * width, 0)
		local prompt = row.prompts[i]
		if prompt:IsShown() then
			prompt:SetPromptInputIconKey(1, bound[i])
			prompt:RefreshInputPromptSize()
		end
	end
end

local function buildCasts(row, owner)
	local watch = CB.Watch(nil, row.bar, row.bar)
	for i, button in ipairs(row.buttons) do
		watch:SetFrameRef("button" .. i, button)
		watch:SetFrameRef("cover" .. i, CB.Cover(button))
		local cast = CreateFrame("Button", "SimpleControllerBarsExtra" .. i, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
		cast:RegisterForClicks("AnyDown", "AnyUp")
		cast:SetAttribute("useOnKeyDown", true)
		cast:SetAttribute("type", "action")
		cast:SetAttribute("action", FIRST + i - 1)
		cast:SetFrameRef("watch", watch)
		SecureHandlerWrapScript(cast, "OnClick", watch, ([[
			local watch = self:GetFrameRef("watch")
			if not down then
				watch:RunAttribute("cb-release", %d)
				return false
			end
			watch:RunAttribute("cb-press", %d)
		]]):format(i, i))
	end
	return function(bound)
		ClearOverrideBindings(owner)
		for i = 1, COUNT do
			for _, key in ipairs({ GetBindingKey(command(i)) }) do
				SetOverrideBindingClick(owner, false, key, "SimpleControllerBarsExtra" .. i, "LeftButton")
			end
		end
		layRow(row, bound)
	end
end

CB.AtLogin(function()
	local pageUnit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
	if not (CB.ControllerMode() and pageUnit and CB.placed[CB.EXTRAS]) then return end
	FIRST = CB.placed[CB.EXTRAS].first
	local bars = pageUnit.actionBars
	local row = buildRow("SimpleControllerBarsExtras", CB.Mirror(pageUnit))
	local owner = CreateFrame("Frame")
	local apply = buildCasts(row, owner)
	-- in Blizzard's editor, a greyed copy beside its bars (Bars.lua's buildGreyed says why)
	local edit = GamepadActionBarEditFrame
	local greyed = edit and buildRow("SimpleControllerBarsExtraGreyed", CB.Mirror(edit.PageUnit))
	if greyed then
		greyed.bar:SetAlpha(0.5)
		for _, button in ipairs(greyed.buttons) do button:DesaturateHierarchy(1) end
		local placer = CreateFrame("Frame", nil, edit)
		placer:SetScript("OnUpdate", function()
			if not InCombatLockdown() and edit.PageUnit.actionBars.bottomBar:GetCenter() then
				CB.Put(edit.PageUnit.actionBars, greyed.bar, 0, -BELOW_BOTTOM, CB.EXTRAS)
				placer:SetScript("OnUpdate", nil)
			end
		end)
	end
	-- for our editor: each extra is its own key's slot
	SimpleController.AddExtras({ first = FIRST, bar = row.bar, keys = keys,
		copy = function(box)
			local copy = buildRow(nil, box)
			layRow(copy, keys())
			return copy
		end })
	-- Our overrides raise UPDATE_BINDINGS too: they are set again only when the
	-- player's own bindings (GetBindingKey reads no overrides) have changed.
	local was
	local function refresh()
		CB.AfterCombat(function()
			local bound, all = keys(), {}
			for i = 1, COUNT do all[i] = table.concat({ GetBindingKey(command(i)) }, " ") end
			local now = table.concat(all, ";")
			if now ~= was then
				was = now
				apply(bound)
				if greyed then layRow(greyed, bound) end
			end
			CB.Put(bars, row.bar, 0, -BELOW_BOTTOM, CB.EXTRAS)
		end)
	end
	refresh()
	CB.OnRelayout(function()
		was = nil
		refresh()
	end)
	for _, event in ipairs({ "UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED" }) do
		owner:RegisterEvent(event)
	end
	owner:SetScript("OnEvent", refresh)
end)
