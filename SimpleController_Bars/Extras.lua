-- Extra buttons: eight entries in Blizzard's Keybindings screen ("Simple Controller"),
-- each casting its own slot: by default Action Bar 8's first eight (CB.Layout).
-- The player binds them to any key there; the binding is the one truth, and is
-- mirrored as a non-priority override, which beats the gamepad context's own hold
-- on a button (L3's auto run) in play and still loses to the menus' and to the
-- priority ones (shoulder+L3, centre camera). Each bound button shows in a row under
-- the bottom bar, with its key's prompt; unbound ones show nowhere.
-- Filled like the chord bars: in Blizzard's bind screen, press the extra's key while
-- it is binding a spell.
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
local function buildRow(name, pageUnit)
	local box = CB.Mirror(pageUnit)
	local bar = CreateFrame("Frame", name, box, "GamepadActionBarTemplate")
	local lender = CreateFrame("Frame", nil, box, "GamepadActionBarTemplate")
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
		local prompt = CreateFrame("Frame", nil, box, "InputPromptOneIconTemplate")
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

-- In Blizzard's bind screen: a copy of the row, and an extra's key pressed while it
-- is binding puts the spell there. Blizzard blocks some keys on that screen (L3),
-- so they are read rather than caught; a key with a modifier is not read.
local function buildBindScreen(edit)
	local unit = edit.PageUnit
	local row = buildRow("SimpleControllerBarsExtraBind", unit)
	local watched, down, placed = {}, {}, false
	CB.OnRelayout(function() placed = false end)
	local function relay(bound)
		layRow(row, bound)
		watched = bound
	end
	CB.OnEditor(function(shown)
		if shown then
			for i, key in pairs(watched) do down[i] = not key:find("-") and IsKeyDown(key) end
		end
	end)
	local reader = CreateFrame("Frame", nil, edit)
	reader:SetScript("OnUpdate", function()
		if not placed and not InCombatLockdown() and unit.actionBars.bottomBar:GetCenter() then
			CB.Put(unit.actionBars, row.bar, 0, -BELOW_BOTTOM, CB.EXTRAS)
			placed = true
		end
		local binding = CB.Binding(edit)
		for i, key in pairs(watched) do
			local now = not key:find("-") and IsKeyDown(key)
			if now and not down[i] and binding then CB.PlaceHeld(edit, FIRST + i - 1, GetBindingText(key)) end
			down[i] = now
		end
	end)
	return relay
end

CB.AtLogin(function()
	local pageUnit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
	local placed = CB.Layout(SimpleControllerBarsDB, CB.IsEmpty)
	if not (CB.ControllerMode() and pageUnit and placed[CB.EXTRAS]) then return end
	FIRST = placed[CB.EXTRAS].first
	local bars = pageUnit.actionBars
	local row = buildRow("SimpleControllerBarsExtras", pageUnit)
	local owner = CreateFrame("Frame")
	local apply = buildCasts(row, owner)
	local bindScreen = GamepadActionBarEditFrame and buildBindScreen(GamepadActionBarEditFrame)
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
				if bindScreen then bindScreen(bound) end
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
