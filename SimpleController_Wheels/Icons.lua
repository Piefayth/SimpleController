-- A wheel's bar slots show what its button uses on a tap now (SW.WheelShown: what it
-- used last, else its default; its icon and its count), on Blizzard's gamepad bars, its editor's, and the
-- suite's own. The macros are never changed for it: a macro changed from addon code has
-- the game refresh every gamepad bar inside the call, as ours, and those bars stayed
-- ours until a reload, refusing to change in the next fight (2026-11-24). Only the
-- button's icon texture and count text are set, which are art, not Lua state
-- (CLAUDE.md), and set again by post-hooks whenever Blizzard sets them (the count
-- otherwise follows the macro's old #showtooltip item), so its border, cooldown and
-- pressed look stay its own.
local _, SW = ...

local hooked = {} -- button -> true
local applying = false

-- the slot a button shows: ours keep it as `slot`, Blizzard's as `action`
local function slotOf(button) return button.slot or button.action end

local function apply(button)
	local slot = slotOf(button)
	local key = slot and SW.WheelOn(slot)
	if not key then return end
	local icon, count = SW.WheelShown(key)
	if not icon then return end
	applying = true
	button.icon:SetTexture(icon)
	button.Count:SetText(count or "")
	applying = false
end

local function watch(button)
	if hooked[button] or not (button.icon and button.Count) then return end
	hooked[button] = true
	local function again() if not applying then apply(button) end end
	-- rules: ok post-hooks on a button's icon and count: Blizzard's setter runs first, untouched
	hooksecurefunc(button.icon, "SetTexture", again)
	hooksecurefunc(button.Count, "SetText", again)
end

local function eachButton(fn)
	for _, frame in ipairs({ GamepadMainActionBarFrame, GamepadActionBarEditFrame }) do
		local unit = frame and frame.PageUnit
		for _, bar in pairs(unit and unit.actionBars or {}) do
			if type(bar) == "table" and type(bar.actionButtons) == "table" then
				for _, button in ipairs(bar.actionButtons) do fn(button) end
			end
		end
	end
	SimpleController.EachActionButton(fn)
end

local function refresh()
	eachButton(function(button)
		watch(button)
		apply(button)
	end)
end

-- after the game's own handlers have set the icons for the same change
local queued = false
local function refreshSoon()
	if queued then return end
	queued = true
	C_Timer.After(0, function()
		queued = false
		refresh()
	end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
	"UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "UPDATE_MACROS", "MODIFIER_STATE_CHANGED",
	"BAG_UPDATE_DELAYED" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", refreshSoon)
-- a tap's use is kept on the ring as attributes (Wheel.lua's LOAD), in fights too
WCWheelRing:HookScript("OnAttributeChanged", function(_, name)
	if name:find("-last-", 1, true) or name:find("-default-", 1, true) then refreshSoon() end
end)
-- rules: ok post-hook on our own table
hooksecurefunc(WCWheel, "Rebuild", refreshSoon)
