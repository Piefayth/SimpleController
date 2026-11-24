-- What the wheels' files share: a notice, waiting for a fight's end and the
-- controller's glyphs.
local _, SW = ...

function SW.Say(text) SimpleController.Say(text, "Wheels") end

local afterCombat = {}
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
	local queued = afterCombat
	afterCombat = {}
	for _, fn in ipairs(queued) do fn() end
end)
function SW.AfterCombat(fn)
	if InCombatLockdown() then afterCombat[#afterCombat + 1] = fn else fn() end
end

-- a pad button's picture for the controller in use, else its name
function SW.Glyph(key)
	local ok, atlas = pcall(InputIconTextureSetUtility.GetNormalActiveInputIconButtonTexture, key)
	if ok and type(atlas) == "string" and C_Texture.GetAtlasInfo(atlas) then
		return CreateAtlasMarkup(atlas, 22, 22)
	end
	return GetBindingText(key)
end
