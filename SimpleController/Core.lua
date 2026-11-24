-- Simple Controller: the core the suite's bar addons share. It holds the one editor
-- (Editor.lua: Blizzard's bind screen and Edit Action Bars, extended), which addons
-- extend through the global SimpleController:
--   AddBar{ keys, first, small, big }  a bar of eight slots from `first`, picked in the
--       editor by `keys` held (shoulders and triggers), drawn where `small` and `big`
--       (its frames of play, at rest and grown) are
--   AddExtras{ first, bar, keys = fn, copy = fn(parent) }  buttons each on its own key
--       (keys() gives them by index), their row of play `bar`, a copy of it for the editor
--   OnEditor(fn(open))  the editor opening and closing (its owner hides its bars of play)
--   AddTargetAction{ key, handOver, label, choose, target = fn(slot), run = fn(slot, thing),
--       fresh = fn() }  somewhere other than a bar slot to put what is held (Wheels: a
--       wheel). In Blizzard's bind screen and Edit Action Bar, bare `key` hands over too
--       (prompt `label` binding, `handOver` editing): binding, its targets are chosen at
--       once; editing, `fresh()`
--       ({ func, params } putting a new thing on the cursor) is held. Holding something,
--       `key` (prompt `label`) lights the slots `target` accepts, fading the rest, the
--       box saying `label` and `choose`; the one pressed gets
--       run(slot, thing), thing = { kind, id, name, icon }, after the editor closes
-- Alone, with nothing using it, it says so at login.
local _, SC = ...

SimpleController = SC
SC.bars, SC.onEditor, SC.targetActions = {}, {}, {}

function SC.AddBar(bar) SC.bars[#SC.bars + 1] = bar end
function SC.AddExtras(extras) SC.extras = extras end
function SC.OnEditor(fn) SC.onEditor[#SC.onEditor + 1] = fn end
function SC.AddTargetAction(action) SC.targetActions[#SC.targetActions + 1] = action end

-- something extends the editor
function SC.Used()
	return #SC.bars > 0 or SC.extras ~= nil or #SC.targetActions > 0
end

-- A notice: a line in chat, as other addons print theirs (measured with the taint log on,
-- 2026-11-24).
function SC.Say(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Simple Controller:|r " .. text) -- rules: ok the player wants chat; measured with the taint log on (2026-11-24)
end

local afterCombat = {}
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD") -- after every addon's PLAYER_LOGIN, where they register
events:SetScript("OnEvent", function(_, event, initial)
	if event == "PLAYER_ENTERING_WORLD" then
		if initial and not SC.Used() then
			SC.Say("Simple Controller does nothing on its own: Simple Controller: Bars or Wheels uses it.")
		end
		-- the editor's copies made under the loading screen: made at its first opening,
		-- they cost a frame you could feel
		if initial and SC.Used() then SC.AfterCombat(SC.Prebuild) end
		return
	end
	local queued = afterCombat
	afterCombat = {}
	for _, fn in ipairs(queued) do fn() end
end)
function SC.AfterCombat(fn)
	if InCombatLockdown() then afterCombat[#afterCombat + 1] = fn else fn() end
end
