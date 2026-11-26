-- Two entries in Blizzard's Options > AddOns. Simple Controller: Bars, one row per
-- bar, saved per character: a checkbox for each chord, all off until switched on; the
-- player's own (Custom 1-4), a button showing its chord, pressed to hold a new one
-- (Circle alone: none); the extra buttons last. Right of L1 + L2's and R1 + R2's
-- checkbox, what they take over for this character's class, nothing where they take
-- nothing: words of ours over Blizzard's row (it has no place for them), found each
-- frame by reading its list, never written (its rows are pooled and reused).
-- Simple Controller: Bars Layout: the button labels, and each bar on (since login)
-- under its own heading with its position sliders, applied at once. Two pages, because
-- no row of Blizzard's list may show or hide by a setting: rows shown by a predicate,
-- even one made of Blizzard's own functions, had moving up or down in the list give
-- "Interface action failed" (2026-11-24; the list's redraw asks the predicate, then
-- marks its rows for the controller through calls Blizzard refuses to addon code), and
-- a controller cannot open a sub-page. A row's words never come from a function, for
-- the same reason. The bars are built at login, so each checkbox carries Blizzard's
-- Apply and UIReload flags, as its graphics settings do: a change waits for Blizzard's
-- Apply button, which reloads the UI. Where each keeps its spells is chosen for it
-- (CB.Layout); a row given a controller page's slots says so once, and in its tooltip.
-- A custom bar's chord is checked (CB.ChordProblem) and waits for Apply too.
local _, CB = ...

local STEP = 5 -- a slider's step, in the bottom bar's units

-- Every button down now, by Blizzard's name for it.
local function down()
	local state = C_GamePad.GetDeviceMappedState()
	local held = {}
	for index, isDown in pairs(state and state.buttons or {}) do
		-- a Lua array from 1; ButtonIndexToBinding counts from 0
		local name = isDown and C_GamePad.ButtonIndexToBinding(index - 1)
		if name then held[#held + 1] = name end
	end
	return held
end

-- Holding a chord: a frame of ours takes the pad's buttons (none reach the menus),
-- waits for none held (the press that started it), then for buttons held and all let
-- go; the most held at once is the chord, given to `done`.
local capture = CreateFrame("Frame", nil, UIParent)
capture:SetFrameStrata("TOOLTIP")
capture:SetSize(1, 1)
capture:SetPoint("CENTER")
capture:Hide()
capture:SetScript("OnGamePadButtonDown", function() end)
CB.AfterCombat(function()
	capture:EnableGamePadButton(true)
	capture:SetPropagateKeyboardInput(false)
end)
local function hold(done)
	local cleared, most = false, {}
	capture:SetScript("OnUpdate", function()
		local held = down()
		if not cleared then
			cleared = #held == 0
			return
		end
		if #held > #most then most = held end
		if #held > 0 or #most == 0 then return end
		capture:SetScript("OnUpdate", nil)
		capture:Hide()
		done(most)
	end)
	capture:Show()
end

-- A starter bound in Keybindings is refused: the player unbinds it there first, so
-- one button never does two things (P1 casting an extra button's spell as it starts
-- a bar, 2026-11-24).
local function boundStarter(keys)
	for _, key in ipairs(keys) do
		local action = CB.IsStarterKey(key) and GetBindingAction(key)
		if action and action ~= "" then
			return ("%s is bound to %s in Keybindings: unbind it there first."):format(GetBindingText(key), CB.BindingName(action))
		end
	end
end

-- A starter Blizzard's play gives a job of its own (its legend of what each button does,
-- GamepadPersistentInputLegend.lua), not a binding: taken only when held a second time.
local NATIVE = { PADLSTICK = PROMPT_AUTO_RUN, PADRSTICK = PROMPT_PING }
local function nativeJobs(keys)
	local jobs = {}
	for _, key in ipairs(keys) do
		if NATIVE[key] then jobs[#jobs + 1] = NATIVE[key] end
	end
	return table.concat(jobs, " and ")
end

-- A slider's reach: the screen's whole width (or height) either way, in the bottom
-- bar's units (a bar's offset is from its place by Blizzard's bottom bar, CB.Put), so a
-- bar can go anywhere on screen.
local function reach(size, bottom)
	local most = math.ceil(size * UIParent:GetEffectiveScale() / bottom:GetEffectiveScale() / STEP) * STEP
	local options = Settings.CreateSliderOptions(-most, most, STEP)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
	return options
end

-- The Layout page: each bar on, its heading and its sliders.
local function layoutPage(db)
	local category, page = Settings.RegisterVerticalLayoutCategory("Simple Controller: Bars Layout")
	local function heading(text) page:AddInitializer(CreateSettingsListSectionHeaderInitializer(text)) end

	-- no controller interface: no bars to move (Bars.lua says so at login)
	local unit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
	local bottom = unit and unit.actionBars.bottomBar
	for _, row in ipairs(CB.Rows()) do
		if CB.placed[row] and bottom then
			heading(CB.RowName(row))
			for _, axis in ipairs({ { "X", "Left / right", UIParent:GetWidth() }, { "Y", "Down / up", UIParent:GetHeight() } }) do
				local setting = Settings.RegisterAddOnSetting(category, "SCBARS_" .. (row.setting .. axis[1]):upper(),
					row.setting .. axis[1], db, Settings.VarType.Number, axis[2], 0)
				setting:SetValueChangedCallback(CB.Relayout)
				Settings.CreateSlider(category, setting, reach(axis[3], bottom), "Moves this bar from where it starts.")
			end
		end
	end
	Settings.RegisterAddOnCategory(category)
end

-- What a chord's class button (Blizzard's, the chord opens it: Model.lua's `flyout`) is
-- for this character, by Blizzard's own table of them
-- (Blizzard_GamepadActionBars/Camelot: ClassSpellFlyout.lua, PetActionFlyout.lua,
-- PetSpellFlyout.lua); nil where this class has none.
local CLASS_FLYOUTS = {
	DRUID = { LeftClassAction = 262 },
	PALADIN = { LeftClassAction = 270 },
	WARRIOR = { RightClassAction = 269 },
}
local PET_FLYOUTS = { LeftClassAction = "pet commands", RightClassAction = "pet abilities" }
local function overrides(row)
	if not row.flyout then return nil end
	local class = UnitClassBase("player")
	local id = CLASS_FLYOUTS[class] and CLASS_FLYOUTS[class][row.flyout]
	if id then return (GetFlyoutInfo(id)) end
	if class == "HUNTER" or class == "WARLOCK" then return PET_FLYOUTS[row.flyout] end
end

-- The words right of a row's checkbox, while Blizzard's list shows that row in view.
local besides = {} -- [initializer] = words
local overlay = CreateFrame("Frame", nil, UIParent)
overlay:SetFrameStrata("DIALOG")
overlay:SetAllPoints()
local labels = {}
overlay:SetScript("OnUpdate", function()
	for _, label in pairs(labels) do label:Hide() end
	local list = SettingsPanel:IsShown() and SettingsPanel:GetSettingsList()
	if not list then return end
	local box = list.ScrollBox
	local top, bottom = box:GetTop(), box:GetBottom()
	for _, frame in box:EnumerateFrames() do
		local initializer = frame:GetElementData()
		local words = besides[initializer]
		local y = frame.Checkbox and select(2, frame.Checkbox:GetCenter())
		if words and y and top and y < top and y > bottom then
			local label = labels[initializer] or overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			labels[initializer] = label
			label:SetText(words)
			label:ClearAllPoints()
			label:SetPoint("LEFT", frame.Checkbox, "RIGHT", 8, 0)
			label:Show()
		end
	end
end)

-- The player's own bars' rows: its chord, pressed to hold a new one; one with no chord
-- is off.
local function pressedRows(category, page, db)
	local pending = {} -- [row] = keys (false: none) set since login, applied at the reload
	local confirming = {} -- [row] = a chord taking a job of Blizzard's, held once
	local holding -- the row whose chord is being held
	local function current(row)
		if pending[row] ~= nil then return pending[row] or nil end
		return row.keys
	end
	for _, row in ipairs(CB.PRESSED) do
		local chord = Settings.RegisterAddOnSetting(category, "SCBARS_" .. row.setting:upper() .. "_CHORD", row.setting,
			db, Settings.VarType.String, row.name, "")
		chord:SetCommitFlags(Settings.CommitFlag.Apply, Settings.CommitFlag.UIReload)
		local initializer
		-- the button's words: a string, set again here on each press (never a function)
		local function label(button)
			local text
			if holding == row then
				text = "Hold the buttons, let go"
			elseif confirming[row] then
				text = "Takes " .. confirming[row].jobs .. ": hold again"
			else
				local keys = current(row)
				text = keys and CB.KeysText(keys) or "Set Chord"
			end
			initializer.data.buttonText = text
			button:SetText(text)
		end
		local function press(button)
			if InCombatLockdown() then return CB.Say("Custom bars are set out of combat.") end
			holding = row
			label(button)
			hold(function(keys)
				holding = nil
				if #keys == 1 and keys[1] == "PAD2" then
					confirming[row], pending[row] = nil, false
					chord:SetValue("")
					return label(button)
				end
				-- checked against the others as they will be after Apply
				local others, mine = {}, nil
				for _, each in ipairs(CB.Rows()) do
					local shadow = each.pressed and { pressed = true, name = each.name, keys = current(each) } or each
					if each == row then mine = shadow end
					others[#others + 1] = shadow
				end
				local problem = CB.ChordProblem(keys, mine, others) or boundStarter(keys)
				local text = CB.ChordText(keys)
				if problem then
					confirming[row] = nil
					CB.Say(row.name .. ": " .. problem)
				elseif nativeJobs(keys) ~= "" and not (confirming[row] and confirming[row].text == text) then
					confirming[row] = { text = text, jobs = nativeJobs(keys) }
				else
					confirming[row] = nil
					pending[row] = keys
					chord:SetValue(text)
				end
				label(button)
			end)
		end
		initializer = CreateSettingsButtonInitializer(row.name, current(row) and CB.KeysText(current(row)) or "Set Chord", press,
			'Press "Set Chord" then hold and release the desired combination.', true)
		page:AddInitializer(initializer)
	end
end

CB.AtLogin(function()
	local db = SimpleControllerBarsDB
	local placed, paged = CB.placed, CB.paged
	for _, row in ipairs(paged) do
		CB.Say(("Simple Controller: %s keeps its spells on %s: no keyboard action bar was free."):format(CB.RowName(row), placed[row].name))
	end
	local category, page = Settings.RegisterVerticalLayoutCategory("Simple Controller: Bars")
	local function heading(text) page:AddInitializer(CreateSettingsListSectionHeaderInitializer(text)) end
	local function checkbox(row, note)
		local on = Settings.RegisterAddOnSetting(category, "SCBARS_" .. row.setting:upper(), row.setting,
			db, Settings.VarType.Boolean, CB.RowName(row), Settings.Default.False)
		on:SetCommitFlags(Settings.CommitFlag.Apply, Settings.CommitFlag.UIReload)
		local tooltip = note
		if placed[row] and placed[row].page then
			tooltip = (tooltip and tooltip .. "\n" or "") .. ("Keeps its spells on %s."):format(placed[row].name)
		end
		local taken = overrides(row)
		local initializer = Settings.CreateCheckbox(category, on, tooltip)
		if taken then besides[initializer] = "Overrides " .. taken end
	end
	heading("Bars")
	for _, chord in ipairs(CB.CHORDS) do checkbox(chord) end
	pressedRows(category, page, db)
	checkbox(CB.EXTRAS, "Each is bound to a button of your choice in Options > Keybindings > Simple Controller.")
	Settings.RegisterAddOnCategory(category)
	layoutPage(db)
end)
