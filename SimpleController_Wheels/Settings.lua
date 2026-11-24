-- The wheels' page in Options > AddOns: this character's wheels by name, each
-- Four-way or Eight-way, applied at once (new wheels are four-way: an eight-way
-- wheel's diagonals are hard to hit with a stick). A wheel set four-way keeps its
-- other slots, hidden, back when set eight-way again. The wheels are listed as they
-- are at login: one made later shows after a reload.
local _, SW = ...

local function ways()
	local options = Settings.CreateControlTextContainer()
	options:Add(4, "Four-way")
	options:Add(8, "Eight-way")
	return options:GetData()
end

function SW.Settings()
	local category, page = Settings.RegisterVerticalLayoutCategory("Simple Controller: Wheels")
	local wheels = SimpleControllerWheelsDB.wheels
	local keys = {}
	for key in pairs(wheels) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return (wheels[a].label or a) < (wheels[b].label or b) end)
	if #keys == 0 then
		page:AddInitializer(CreateSettingsListSectionHeaderInitializer("No wheels yet: Add Wheel in Edit Action Bars."))
	end

	for _, key in ipairs(keys) do
		-- its name, then what is on it: a wheel's macro icon follows what it used last
		local name = wheels[key].label or key
		for _, icon in ipairs(SW.Icons(key)) do name = name .. " |T" .. icon .. ":18|t" end
		local setting = Settings.RegisterProxySetting(category, "SCWHEELS_" .. key:upper(), Settings.VarType.Number,
			name, 4,
			function() return wheels[key] and wheels[key].four and 4 or 8 end,
			function(value)
				if not wheels[key] then return end
				wheels[key].four = value == 4 or nil
				SW.AfterCombat(function() WCWheel.Rebuild(true) end)
			end)
		Settings.CreateDropdown(category, setting, ways, "Four-way: up, right, down, left. Eight-way adds the diagonals.")
	end
	Settings.RegisterAddOnCategory(category)
end
