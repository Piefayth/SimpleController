-- The addon's page in Blizzard's Options > AddOns: a checkbox per chord and one for
-- the extra buttons, all off until switched on, saved per character. The bars are
-- built at login, so each carries Blizzard's Apply and UIReload flags, as its
-- graphics settings do: a change waits for Blizzard's Apply button, which reloads
-- the UI. Where each keeps its spells is chosen for it (CB.Layout); a row given a
-- controller page's slots says so once. Its Layout settings (button labels, a bar's
-- position) apply at once.
local _, CB = ...

local MOVE, STEP = 600, 5 -- how far a slider moves a bar, in the bottom bar's units

CB.AtLogin(function()
	local db = SimpleControllerBarsDB
	local placed, paged = CB.Layout(db, CB.IsEmpty)
	for _, row in ipairs(paged) do
		CB.Say(("Simple Controller: %s keeps its spells on %s: no keyboard action bar was free."):format(CB.RowName(row), placed[row].name))
	end
	local category, page = Settings.RegisterVerticalLayoutCategory("Simple Controller: Bars")
	local function heading(text) page:AddInitializer(CreateSettingsListSectionHeaderInitializer(text)) end
	heading("Bars")
	for _, row in ipairs(CB.Rows()) do
		local setting = Settings.RegisterAddOnSetting(category, "SCBARS_" .. row.setting:upper(), row.setting,
			db, Settings.VarType.Boolean, CB.RowName(row), Settings.Default.False)
		setting:SetCommitFlags(Settings.CommitFlag.Apply, Settings.CommitFlag.UIReload)
		local tooltip = row.note or "Eight buttons you bind to any key in Keybindings > Simple Controller."
		if placed[row] and placed[row].page then
			tooltip = tooltip .. ("\nKeeps its spells on %s."):format(placed[row].name)
		end
		Settings.CreateCheckbox(category, setting, tooltip)
	end

	-- Layout, on the same page (a controller cannot open a sub-page in Options' list),
	-- shown at once with no reload: our labels, and per switched-on bar a slider for
	-- each direction, moving it from where it is put beside Blizzard's controller bars.
	local function live(setting)
		setting:SetValueChangedCallback(CB.Relayout)
		return setting
	end
	heading("Layout (beside Blizzard's controller bars)")
	Settings.CreateCheckbox(category, live(Settings.RegisterAddOnSetting(category, "SCBARS_PROMPTS", "prompts", db,
		Settings.VarType.Boolean, "Button labels", Settings.Default.True)),
		"The buttons to press, under each of these bars and extra buttons. Blizzard's own bars' labels are set in Edit Mode (Show Button Prompts), which needs a mouse.")
	local options = Settings.CreateSliderOptions(-MOVE, MOVE, STEP)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
	for _, row in ipairs(CB.Rows()) do
		if placed[row] then
			heading(CB.RowName(row))
			for _, axis in ipairs({ { "X", "Left / right" }, { "Y", "Down / up" } }) do
				local setting = live(Settings.RegisterAddOnSetting(category, "SCBARS_" .. (row.setting .. axis[1]):upper(),
					row.setting .. axis[1], db, Settings.VarType.Number, axis[2], 0))
				Settings.CreateSlider(category, setting, options, "Moves this bar from where it starts.")
			end
		end
	end
	Settings.RegisterAddOnCategory(category)
end)
