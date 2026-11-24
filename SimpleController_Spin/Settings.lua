-- The addon's page in Blizzard's Options > AddOns, applied at once: its sounds, and
-- where and how big its readouts are (moved from around the character, at the
-- screen's centre). Moving or sizing them shows a sample for a moment. Kept across
-- characters, as its bests are. Switched off in the AddOns list, as any addon is.
local _, ST = ...

local MOVE, STEP = 800, 5

ST.DEFAULTS = { sounds = false, x = 0, y = 0, size = 1 } -- sounds off until they are designed

function ST.Settings()
	local db = SimpleControllerSpinDB
	local category = Settings.RegisterVerticalLayoutCategory("Simple Controller: Spin")
	local function placed(setting)
		setting:SetValueChangedCallback(function() ST.Place() ST.Preview() end)
		return setting
	end
	Settings.CreateCheckbox(category, Settings.RegisterAddOnSetting(category, "SCSPIN_SOUNDS", "sounds", db,
		Settings.VarType.Boolean, "Sounds", Settings.Default.False), "A chime for each circle, and for a Tight! one.")
	local move = Settings.CreateSliderOptions(-MOVE, MOVE, STEP)
	move:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
	for _, axis in ipairs({ { "x", "Left / right" }, { "y", "Down / up" } }) do
		Settings.CreateSlider(category, placed(Settings.RegisterAddOnSetting(category, "SCSPIN_" .. axis[1]:upper(), axis[1], db,
			Settings.VarType.Number, axis[2], 0)), move, "Moves the readouts from around your character.")
	end
	local size = Settings.CreateSliderOptions(0.5, 2, 0.05)
	size:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
	Settings.CreateSlider(category, placed(Settings.RegisterAddOnSetting(category, "SCSPIN_SIZE", "size", db,
		Settings.VarType.Number, "Size", 1)), size, "How big the readouts are.")
	Settings.RegisterAddOnCategory(category)
end
