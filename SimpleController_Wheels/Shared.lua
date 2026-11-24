-- What the wheels' files share: a notice, waiting for a fight's end and the
-- controller's glyphs.
local _, SW = ...

-- A notice: a line in chat, as other addons print theirs (measured with the taint log on,
-- 2026-11-24).
function SW.Say(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Simple Controller: Wheels:|r " .. text) -- rules: ok the player wants chat; measured with the taint log on (2026-11-24)
end

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
