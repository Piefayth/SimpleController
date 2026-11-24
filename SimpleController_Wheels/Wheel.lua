-- Radial wheels of the player's own, each opened by a bar slot whose macro is
-- "/click WCWheel_<name> Macro" (WCWheel.Macro(name) gives the line).
-- Right stick points and letting it go uses (the one way); the d-pad keeps its bar actions;
-- the wheel's own button again uses what it used last; Circle closes; the left stick
-- keeps walking (Ring.Take blocks only the camera stick). Every button is secure, so a wheel works in combat; what is on
-- it is rebuilt out of combat only.
--
-- The ring's look, layout, aim and stick capture are Ring.lua's (shared with WoW
-- Companion's chat wheel); this file is the secure part: the buttons that open a
-- wheel and use its slots, the bindings it takes while open, and the axis CVar
-- that makes the stick's directions keys for them (the chat wheel reads the stick
-- from Lua and needs none of it). Adapted from
-- Improved Forever's Ring.lua by markg, MIT licence, see LICENSE-ImprovedForever.
--
-- Configured by other addons (WoW Companion's agents), in Lua, out of combat:
--   WCWheel.Set("travel", { label = "Travel", slots = {
--       { spell = "<a spell the character knows>" }, { item = 6948 }, { macro = "Ping" },
--       { emote = "WAVE" }, { macrotext = "/sit", label = "Sit", icon = 134400 } } })
--   four = true on a wheel: four slots (up, right, down, left) on the four-way art
--   default = n on a wheel: the slot its button shows and uses until one is picked
--       (else the first; the slot of the form you are in comes before either)
--   icon = fileID on a wheel: its bar macro's icon while it has nothing to show
--   names = true on a wheel: its slots show their names (else icons alone)
--   show = "[swimming] Aquatic Form; Travel Form" on a macrotext slot: the spell it
--       stands for, in macro conditions
--   WCWheel.Remove("travel")   WCWheel.List()
-- Read by other addons through WCWheel.Each(fn(name, wheel)) only: the saved
-- table is this file's.
-- No wheel ships: a character starts with none, and each is made on request
-- from what that character has.
-- A slot may carry `label` and `icon` to override what is looked up.
-- A slot { rule = "fight" }, { rule = "food" }, { rule = "quest" } or { rule = "gear" }
-- fills itself from what is carried (and, for gear, worn).
-- The player fills them in Simple Controller's editor (Place.lua): a spell, item
-- or macro bound onto a wheel's bar slot opens that wheel, and the flick puts it
-- in a slot or an "Add here" one (SW.Place); "New wheel" on an empty slot makes
-- an empty one there (SW.NewWheel).

local _, SW = ...
WCWheel = WCWheel or {}
local W = WCWheel

local MAX_SLOTS = SimpleControllerRing.PAGE
local AXIS_CVAR = "GamePadStickAxisButtons"
local MODIFIERS_LUA = [[newtable("", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-")]]

local ringData = {} -- [wheel] = { { label, icon, itemID, count, dx, dy }, ... }
local pending = false
local placing -- { slot, label }: what a flick puts on the wheel open (SW.Place)

local function Print(text) SW.Say("Wheel: " .. text) end

local function SetCVarSafe(name, value)
    local ok, result = pcall(C_CVar.SetCVar, name, value)
    return ok and result ~= false
end

local function GetCVarSafe(name)
    local ok, value = pcall(C_CVar.GetCVar, name)
    return ok and value or nil
end

---------------------------------------------------------------------------
-- Secure frames
---------------------------------------------------------------------------

local ring = CreateFrame("Frame", "WCWheelRing", UIParent, "SecureHandlerBaseTemplate")
ring:Hide()
-- the look, the aim, the stick capture and the camera hold (Ring.lua)
local look = SimpleControllerRing.Build(ring, { prompts = { { "PADRSTICKAXIS", "Choose" }, { "PAD2", "Close" } } })

local function SecureButton(name)
    local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
    SecureHandlerSetFrameRef(button, "ring", ring)
    return button
end

-- The slot nearest a direction (x, y), by the slots' own directions.
ring:SetAttribute("wc-aim", [[
    local dx, dy = ...
    local key = self:GetAttribute("wc-active")
    local best, bestDot
    for index = 1, self:GetAttribute(key .. "-count") or 0 do
        local dot = dx * self:GetAttribute(key .. "-dx-" .. index) + dy * self:GetAttribute(key .. "-dy-" .. index)
        if not bestDot or dot > bestDot then best, bestDot = index, dot end
    end
    return best
]])
-- The pick (wc-sticky, which the look shows) is the stick's own angle, read
-- every frame the ring is up: the slot nearest it whenever the stick is out
-- past 0.3, so every slot gets an equal slice and a release uses the last
-- reading before the stick fell back. Secure code reads the stick only in a
-- snippet, so the frame comes from Blizzard's state driver: while the ring is
-- up its manager ticks every frame (updatetime 0) and the sampler's driver,
-- cleared after each tick, fires on every one (Forever Tweaks' way,
-- ivribalko/wow-forever-tweaks GamepadQuickMenu.lua).
ring:SetAttribute("wc-sample", [[
    local state = GetGamePadState()
    local stick = state and state.sticks and state.sticks[2]
    if stick and stick.x and (stick.x * stick.x + stick.y * stick.y) >= 0.09 then
        self:SetAttribute("wc-sticky", self:RunAttribute("wc-aim", stick.x, stick.y))
    end
]])
-- the stick's direction keys still down (a release is the last one up)
ring:SetAttribute("wc-any-held", [[
    for _, key in ipairs(newtable("PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT")) do
        if self:GetAttribute("wc-held-" .. key) then return true end
    end
]])
-- forget the keys held (the ring opening or closing)
ring:SetAttribute("wc-forget", [[
    for _, key in ipairs(newtable("PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT")) do
        self:SetAttribute("wc-held-" .. key, nil)
    end
]])

-- open wheel `key` (nothing when it has no slots)
ring:SetAttribute("wc-show", [[
    local key = ...
    if (self:GetAttribute(key .. "-count") or 0) < 1 then return end
    self:SetAttribute("wc-sticky", nil)
    self:RunAttribute("wc-forget")
    self:SetAttribute("wc-active", key)
    self:Show()
]])

local sampler = CreateFrame("Frame", "WCWheelSampler", UIParent, "SecureHandlerStateTemplate")
SecureHandlerSetFrameRef(sampler, "ring", ring)
-- Its tick also opens a wheel asked for by our own code (wc-open, then the
-- state cleared so the next tick fires): a snippet run from addon code cannot
-- reach a button it has never seen securely ("Invalid 'header' frame handle",
-- a new wheel's button clicked, 2026-11-14); the driver's tick is secure.
sampler:SetAttribute("_onstate-aim", [[
    if newstate ~= "sample" then return end
    local ring = self:GetFrameRef("ring")
    local open = self:GetAttribute("wc-open")
    if open then
        self:SetAttribute("wc-open", nil)
        if not ring:IsShown() then ring:RunAttribute("wc-show", open) end
    end
    if not ring:IsShown() then return end -- left set, so the driver stops firing
    ring:RunAttribute("wc-sample")
    self:SetAttribute("state-aim", nil)
]])
RegisterStateDriver(sampler, "aim", "sample")
SecureHandlerSetFrameRef(ring, "sampler", sampler)
SecureHandlerSetFrameRef(ring, "driver", SecureStateDriverManager)

-- Loads a use onto `self` (type `t`, attribute `a` = `v`), remembered as the
-- wheel's last (before the ring closes, whose OnHide shows it on the macro),
-- and closes the ring; the secure action then runs it.
local LOAD = [[
    ring:SetAttribute(key .. "-last-type", t)
    ring:SetAttribute(key .. "-last-attr", a)
    ring:SetAttribute(key .. "-last-value", v)
    ring:Hide()
    for _, attribute in ipairs(newtable("spell", "item", "macro", "macrotext", "unit")) do
        self:SetAttribute(attribute, nil)
    end
    self:SetAttribute(a, v)
    self:SetAttribute("type", t)
]]

-- The same wheel's button closes it, using what it used last (kept as values,
-- so a rebuild of the wheel cannot turn it into another slot; gone at a
-- /reload), or only closes it while placing. Another wheel's switches to that
-- one. The use runs on whichever edge the macro's /click brought, hence
-- useOnKeyDown set to it. The button is reached through a macro (the bar slot's
-- /click), and a macro cannot run a macro: a single /cast line used last is turned
-- into its spell here, its conditions read as the game reads them
-- (SecureCmdOptionParse); a longer macro is not used again this way.
local OPEN_SNIPPET = [[
    self:SetAttribute("type", nil)
    if button ~= "Macro" and not down then return false end
    local ring = self:GetFrameRef("ring")
    local key = self:GetAttribute("wc-wheel")
    if ring:IsShown() then
        -- read before the hide, which ends placing
        local same = ring:GetAttribute("wc-active") == key and not ring:GetAttribute("wc-placing")
        ring:Hide()
        if not same then
        elseif ring:GetAttribute(key .. "-last-type") or ring:GetAttribute(key .. "-default-type") then
            local from = ring:GetAttribute(key .. "-last-type") and "-last-" or "-default-"
            local t, a, v = ring:GetAttribute(key .. from .. "type"), ring:GetAttribute(key .. from .. "attr"),
                ring:GetAttribute(key .. from .. "value")
            if a == "macrotext" then
                local line = not strfind(v, "\n") and strmatch(v, "^/cast%s+(.+)$")
                local spell = line and SecureCmdOptionParse(line)
                if not spell then return false end
                t, a, v = "spell", "spell", spell
            end
            self:SetAttribute("useOnKeyDown", down and true or false)
]] .. LOAD .. [[
            return
        else
            return false
        end
    end
    ring:RunAttribute("wc-show", key)
    return false
]]

local function OpenButton(name)
    local button = _G["WCWheel_" .. name]
    if button then return button end
    button = SecureButton("WCWheel_" .. name)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("wc-wheel", name)
    SecureHandlerWrapScript(button, "OnClick", button, OPEN_SNIPPET)
    return button
end

-- Right stick directions (as keys): only the release, the last key up, uses
-- the pick; every edge also reads the stick, in case the frame's tick has not
-- run yet. Each direction has its own button, because the game gives a
-- button one up edge however many keys hold it: on one shared button a
-- diagonal's second key never came up, and the wheel waited on it with the
-- spell unused (measured 2026-11-13). The action runs on the up edge, hence
-- useOnKeyDown false.
local STICK_KEYS = { "PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT" }
local AIM = [[
    self:SetAttribute("type", nil)
    local ring = self:GetFrameRef("ring")
    if not ring:IsShown() then return false end
    ring:SetAttribute("wc-held-" .. button, down or nil)
    ring:RunAttribute("wc-sample")
    if down or ring:RunAttribute("wc-any-held") then return false end
    local pick = ring:GetAttribute("wc-sticky")
    if not pick then return false end
    local key = ring:GetAttribute("wc-active")
    if ring:GetAttribute("wc-placing") and not PlayerInCombat() then
        -- placed before the hide, which ends placing
        ring:CallMethod("WCPlace", key, pick)
        ring:Hide()
        return false
    end
    local t, a, v = ring:GetAttribute(key .. "-type-" .. pick), ring:GetAttribute(key .. "-attr-" .. pick),
        ring:GetAttribute(key .. "-value-" .. pick)
    -- a gap, or a slot that cannot be used (a macro deleted, a spell unlearned): nothing
    if not (t and a) then
        ring:Hide()
        return false
    end
]] .. LOAD
local aims = {}
for _, key in ipairs(STICK_KEYS) do
    local aim = SecureButton("WCWheelAim" .. key)
    aim:RegisterForClicks("AnyDown", "AnyUp")
    aim:SetAttribute("useOnKeyDown", false)
    SecureHandlerWrapScript(aim, "OnClick", aim, AIM)
    aims[#aims + 1] = aim
end

-- Circle: close.
local close = SecureButton("WCWheelClose")
close:RegisterForClicks("AnyDown")
SecureHandlerWrapScript(close, "OnClick", close, [[
    self:GetFrameRef("ring"):Hide()
    return false
]])

-- While the ring is up it owns Circle and the right stick's directions, whatever
-- modifier the held triggers emulate.
SecureHandlerWrapScript(ring, "OnShow", ring, [[
    -- the stick read every frame while up (the sampler above); the manager's
    -- own pace (0.2 s unless another addon changed it) is put back on hide
    local driver = self:GetFrameRef("driver")
    if driver:GetAttribute("updatetime") ~= 0 then
        self:SetAttribute("wc-pace", driver:GetAttribute("updatetime") or 0.2)
        driver:SetAttribute("updatetime", 0)
    end
    self:GetFrameRef("sampler"):SetAttribute("state-aim", nil)
    for _, modifier in ipairs(]] .. MODIFIERS_LUA .. [[) do
        self:SetBindingClick(true, modifier .. "PAD2", "WCWheelClose", "LeftButton")
        -- the d-pad is left alone: it keeps its bar actions, so another
        -- wheel's button opens that wheel from inside this one
        for _, key in ipairs(newtable("PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT")) do
            self:SetBindingClick(true, modifier .. key, "WCWheelAim" .. key, key)
        end
    end
]])
SecureHandlerWrapScript(ring, "OnHide", ring, [[
    local driver = self:GetFrameRef("driver")
    if driver:GetAttribute("updatetime") == 0 and self:GetAttribute("wc-pace") then
        driver:SetAttribute("updatetime", self:GetAttribute("wc-pace"))
    end
    self:SetAttribute("wc-pace", nil)
    self:ClearBindings()
    self:RunAttribute("wc-forget")
]])

-- Stick directions only arrive as keys with GamePadStickAxisButtons on: on
-- while the ring is up, put back after (saved, so a /reload mid-ring still
-- restores it).
local function RestoreAxis()
    if ring:IsShown() then return end
    local db = SimpleControllerWheelsDB
    if db and db.axisSaved ~= nil and SetCVarSafe(AXIS_CVAR, db.axisSaved) then db.axisSaved = nil end
end
ring:HookScript("OnShow", function()
    local current = GetCVarSafe(AXIS_CVAR)
    if current and current ~= "1" then
        if SimpleControllerWheelsDB.axisSaved == nil then SimpleControllerWheelsDB.axisSaved = current end
        SetCVarSafe(AXIS_CVAR, "1")
    end
end)
ring:HookScript("OnHide", RestoreAxis)

-- the look shows the secure pick itself, never a reading of its own
ring:SetScript("OnUpdate", function()
    local pick = ring:GetAttribute("wc-sticky")
    if pick ~= look.lit then look:Light(pick, ringData[ring:GetAttribute("wc-active")] or {}) end
end)
-- An item slot shows how many are carried, as a bar button does: a stack or a
-- consumable (its charges counted), never a single thing like the Hearthstone.
-- Read at each opening, so a fight's use is counted too.
local function Counts(entries)
    for _, entry in ipairs(entries) do
        local id = entry.itemID
        if id then
            local consumable = C_Item.IsConsumableItem(id)
            if consumable or (C_Item.GetItemMaxStackSizeByID(id) or 1) > 1 then
                entry.count = tostring(C_Item.GetItemCount(id, false, consumable))
            end
        end
    end
end
-- The spell a slot stands for right now.
local function StandsFor(entry)
    if entry.show then return SecureCmdOptionParse(entry.show) end
    return entry.type == "spell" and entry.value or nil
end
local function FormName()
    local form = GetShapeshiftForm()
    local spell = form > 0 and select(4, GetShapeshiftFormInfo(form))
    return spell and C_Spell.GetSpellName(spell) or nil
end
-- A form's slot wears the icon the game gives that form now, as Blizzard's stance
-- bar does: the form you are in has its own.
local function FormIcons(entries)
    local icons = {}
    for form = 1, GetNumShapeshiftForms() do
        local icon, _, _, spell = GetShapeshiftFormInfo(form)
        icons[C_Spell.GetSpellName(spell)] = icon
    end
    for _, entry in ipairs(entries) do
        local shown = StandsFor(entry)
        entry.icon = shown and icons[shown] or entry.icon
    end
end

ring:HookScript("OnShow", function()
    local key = ring:GetAttribute("wc-active")
    Counts(ringData[key] or {})
    FormIcons(ringData[key] or {})
    local wheel = SimpleControllerWheelsDB.wheels[key]
    look:Open(placing and ("Place " .. placing.label), ringData[key] or {}, wheel and wheel.four,
        placing or (wheel and wheel.names))
end)

---------------------------------------------------------------------------
-- What is on each wheel (out of combat)
---------------------------------------------------------------------------

-- A slot as the secure button needs it: type, the attribute holding its
-- value, the value, and what is drawn. nil (and why) when it cannot be used.
local function Resolve(slot)
    if slot.spell then
        local info = C_Spell.GetSpellInfo(slot.spell)
        if not info then return nil, "no spell " .. tostring(slot.spell) end
        return { type = "spell", attr = "spell", value = info.name, label = slot.label or info.name,
            icon = slot.icon or info.iconID, spellID = info.spellID }
    elseif slot.item then
        local id = tonumber(slot.item) or (C_Item.GetItemInfoInstant(slot.item))
        if not id then return nil, "no item " .. tostring(slot.item) end
        return { type = "item", attr = "item", value = "item:" .. id, itemID = id,
            label = slot.label or C_Item.GetItemNameByID(id) or ("item " .. id),
            icon = slot.icon or C_Item.GetItemIconByID(id) }
    elseif slot.macro then
        local name, icon = GetMacroInfo(slot.macro)
        if not name then return nil, "no macro " .. tostring(slot.macro) end
        return { type = "macro", attr = "macro", value = name, label = slot.label or name, icon = slot.icon or icon }
    elseif slot.emote then
        local token = string.lower(slot.emote)
        return { type = "macro", attr = "macrotext", value = "/" .. token,
            label = slot.label or (token:gsub("^%l", string.upper)), icon = slot.icon or 236373 }
    elseif slot.macrotext then
        return { type = "macro", attr = "macrotext", value = slot.macrotext, label = slot.label or slot.macrotext,
            icon = slot.icon or 134400, show = slot.show }
    elseif slot.rule then
        return nil, "unknown rule " .. tostring(slot.rule)
    elseif not next(slot) then
        -- a gap, kept so the slots after it stay where they are
        return { empty = true, label = "" }
    end
    return nil, "not a slot"
end

-- Rules fill themselves, out of combat, each time the wheel is rebuilt. Each
-- takes items that have a Use: effect, once per item, in bag order:
--   "fight"  potions, elixirs, flasks, scrolls, bandages, explosives
--   "food"   food and drink
--   "quest"  quest items only
--   "gear"   anything equippable: what is worn first, then the bags
local RULES = {}
local QUEST_CLASS = 12
local function BagUsable(keep)
    local found, seen = {}, {}
    for bag = 0, 4 do
        local count = C_Container.GetContainerNumSlots(bag) or 0
        for index = 1, count do
            local info = C_Container.GetContainerItemInfo(bag, index)
            local id = info and info.itemID
            if id and not seen[id] then
                -- only what has a Use: effect; a quest item you only carry has
                -- no spell and stays off
                local classID, subclassID = select(6, C_Item.GetItemInfoInstant(id))
                local quest = C_Container.GetContainerItemQuestInfo(bag, index)
                local isQuest = classID == QUEST_CLASS or (quest and (quest.isQuestItem or quest.questID)) and true or false
                if C_Item.GetItemSpell(id) ~= nil and keep(isQuest, classID, subclassID) then
                    seen[id] = true
                    found[#found + 1] = { item = id }
                end
            end
        end
    end
    return found
end
-- Consumable (0) by subclass: potion 1, elixir 2, flask 3, scroll 4, food and
-- drink 5, bandage 7; and Trade Goods (7) explosives 2. Left out: "other"
-- consumables (crates, clams, camp gear), item enhancements, the Hearthstone.
local function OfKinds(kinds)
    return BagUsable(function(isQuest, classID, subclassID)
        return not isQuest and kinds[classID] and kinds[classID][subclassID] or false
    end)
end
local FIGHT = { [0] = { [1] = true, [2] = true, [3] = true, [4] = true, [7] = true }, [7] = { [2] = true } }
local FOOD = { [0] = { [5] = true } }
function RULES.fight() return OfKinds(FIGHT) end
function RULES.food() return OfKinds(FOOD) end
function RULES.quest() return BagUsable(function(isQuest) return isQuest end) end
function RULES.gear()
    local found, seen = {}, {}
    local function add(id)
        if id and not seen[id] and C_Item.GetItemSpell(id) ~= nil then
            seen[id] = true
            found[#found + 1] = { item = id }
        end
    end
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do add(GetInventoryItemID("player", slot)) end
    for bag = 0, 4 do
        for index = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, index)
            if info and C_Item.IsEquippableItem(info.itemID) then add(info.itemID) end
        end
    end
    return found
end

-- a wheel's slots with every rule replaced by what it finds now, and for each
-- the definition it came from ({ index, rule })
local function Expand(slots)
    local out, from = {}, {}
    for index, slot in ipairs(slots or {}) do
        local rule = slot.rule and RULES[slot.rule]
        if rule then
            local ok, found = pcall(rule)
            for _, each in ipairs(ok and found or {}) do
                out[#out + 1], from[#out + 1] = each, { index = index, rule = slot.rule }
            end
        else
            out[#out + 1], from[#out + 1] = slot, { index = index }
        end
    end
    return out, from
end

-- A wheel's bar macros show what a tap of them uses again: SetMacroSpell /
-- SetMacroItem, the game's feedback for a macro that opens with a bare
-- #showtooltip (measured 2026-11-14, in combat too: the Buffs macro took Mark
-- of the Wild's icon). Every macro holding the wheel's line counts.
local function WheelMacros(key, fn)
    local line = W.Macro(key)
    local global, character = GetNumMacros()
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    for index = 1, base + character do
        if index <= global or index > base then
            local body = select(3, GetMacroInfo(index))
            if body and body:find(line, 1, true) then fn(index, body) end
        end
    end
end

-- What a wheel's button uses before anything was picked: the slot of the form
-- you are in, so pressing it leaves that form, else the wheel's default.
local function DefaultEntry(wheel, entries)
    local form = FormName()
    for _, entry in ipairs(entries) do
        if form and StandsFor(entry) == form then return entry end
    end
    local chosen = entries[wheel.default or 1]
    if chosen and chosen.type then return chosen end
    for _, entry in ipairs(entries) do
        if entry.type then return entry end
    end
end

-- A chosen icon hides that feedback (measured 2026-11-20), so an icon is worn only
-- while there is no spell or item to show; the icon is out of combat only.
-- GetMacroInfo reports the feedback's icon as the macro's, so what each macro wears
-- is kept here (false: none).
local wearing = {}
-- EditMacro takes a file ID (a path left the macro with no icon at all, 2026-11-20)
local iconProbe = ring:CreateTexture()
iconProbe:Hide()
local function IconID(icon)
    if type(icon) ~= "string" then return icon end
    iconProbe:SetTexture(icon)
    return iconProbe:GetTextureFileID()
end
local function ShowLast(key)
    local from = ring:GetAttribute(key .. "-last-type") and "-last-" or "-default-"
    local attr, value = ring:GetAttribute(key .. from .. "attr"), ring:GetAttribute(key .. from .. "value")
    local entry
    for _, each in ipairs(ringData[key] or {}) do
        if each.attr == attr and each.value == value then entry = each break end
    end
    local set = (entry and entry.show or attr == "spell") and SetMacroSpell or (attr == "item" and SetMacroItem)
    local shown = entry and entry.show and StandsFor(entry) or value
    local wheel = SimpleControllerWheelsDB.wheels[key]
    local icon = not set and IconID(entry and entry.icon or wheel and wheel.icon) or false
    WheelMacros(key, function(index)
        local name = GetMacroInfo(index)
        if wearing[name] ~= icon then
            if InCombatLockdown() then
                SW.AfterCombat(function() ShowLast(key) end)
            else
                EditMacro(index, nil, icon or 134400)
                wearing[name] = icon
            end
        end
        if set then pcall(set, index, shown) end
    end)
end
ring:HookScript("OnHide", function()
    local key = ring:GetAttribute("wc-active")
    if key then ShowLast(key) end
end)

-- the macro text change is out of combat only, so it is made at each rebuild:
-- a bare #showtooltip on top, then the icon the wheel should wear now
local function PrepareMacros(key)
    WheelMacros(key, function(index, body)
        if not body:find("^#showtooltip") then EditMacro(index, nil, 134400, "#showtooltip\n" .. body) end
    end)
    ShowLast(key)
end

function W.Rebuild(quiet)
    if InCombatLockdown() then
        pending = true
        return false
    end
    pending = false
    ring:SetAttribute("wc-placing", placing and true or nil)
    for key in pairs(ringData) do ring:SetAttribute(key .. "-count", 0) end
    wipe(ringData)
    for key, wheel in pairs(SimpleControllerWheelsDB.wheels) do
        OpenButton(key)
        local entries = {}
        local most = wheel.four and 4 or MAX_SLOTS
        local slots, from = Expand(wheel.slots)
        for index, slot in ipairs(slots) do
            local entry, why = Resolve(slot)
            if why and not quiet then Print(key .. ": an empty slot, " .. why) end
            if #entries < most then
                -- one that cannot be used stays a gap, so the rest keep their directions
                entry = entry or { empty = true, label = "" }
                entry.from = from[index]
                entries[#entries + 1] = entry
            elseif not quiet and not wheel.four then
                -- a four-way wheel's slots past four are kept, hidden (Settings.lua)
                Print(key .. ": skipped a slot, the wheel is full")
            end
        end
        -- while placing, every free position shows itself: the gaps and all
        -- past the last slot
        if placing then
            for _, entry in ipairs(entries) do
                if entry.empty then entry.label, entry.icon = "Add here", 134400 end
            end
            for _ = #entries + 1, most do entries[#entries + 1] = { label = "Add here", icon = 134400, add = true } end
        end
        for index, entry in ipairs(entries) do
            entry.dx, entry.dy, entry.angle = SimpleControllerRing.Direction(index, wheel.four)
            ring:SetAttribute(key .. "-dx-" .. index, entry.dx)
            ring:SetAttribute(key .. "-dy-" .. index, entry.dy)
            ring:SetAttribute(key .. "-type-" .. index, entry.type)
            ring:SetAttribute(key .. "-attr-" .. index, entry.attr)
            ring:SetAttribute(key .. "-value-" .. index, entry.value)
        end
        ring:SetAttribute(key .. "-count", #entries)
        ringData[key] = entries
        local default = DefaultEntry(wheel, entries)
        ring:SetAttribute(key .. "-default-type", default and default.type)
        ring:SetAttribute(key .. "-default-attr", default and default.attr)
        ring:SetAttribute(key .. "-default-value", default and default.value)
        PrepareMacros(key)
    end
    return true
end

-- Placing: "Place on wheel" in the editor (Place.lua) opens that wheel at once (on
-- the sampler's next tick) with every free position shown, and the flick puts
-- the thing there (the secure release calls WCPlace instead of using the slot,
-- never in a fight). The wheel closing ends it, whatever closed it.
local function EndPlacing()
    if not placing then return end
    placing = nil
    W.Rebuild(true)
end
ring:HookScript("OnHide", EndPlacing)
function SW.Place(key, slot, label)
    placing = { slot = slot, label = label }
    W.Rebuild(true)
    sampler:SetAttribute("wc-open", key)
    sampler:SetAttribute("state-aim", nil)
end
function ring:WCPlace(key, index)
    local wheel = SimpleControllerWheelsDB.wheels[key]
    local entry = ringData[key] and ringData[key][index]
    if not (placing and wheel and entry) then return end
    if entry.from and entry.from.rule then
        return Print("that slot is filled from the bags (the " .. entry.from.rule .. " rule)")
    end
    wheel.slots = wheel.slots or {}
    local said = placing.label .. " added to " .. (wheel.label or key)
    if entry.add then
        -- past the last slot: gaps up to the position flicked
        local last = 0
        for i, each in ipairs(ringData[key]) do if not each.add then last = i end end
        for _ = last + 1, index - 1 do wheel.slots[#wheel.slots + 1] = {} end
        wheel.slots[#wheel.slots + 1] = placing.slot
    else
        if not entry.empty then said = placing.label .. " is on " .. (wheel.label or key) .. " in place of " .. tostring(entry.label) end
        wheel.slots[entry.from.index] = placing.slot
    end
    Print(said)
end

-- "Add Wheel" (Place.lua): a new, empty wheel and its character macro ("Wheel n");
-- returns its key and the macro's name, or nothing when there is no room for one.
function SW.NewWheel()
    local _, character = GetNumMacros()
    if character >= Constants.MacroConsts.MAX_CHARACTER_MACROS then
        return Print("no room for another character macro, so no new wheel")
    end
    local n = 1
    while SimpleControllerWheelsDB.wheels["w" .. n] or GetMacroIndexByName("Wheel " .. n) > 0 do n = n + 1 end
    local key, label = "w" .. n, "Wheel " .. n
    if not CreateMacro(label, 134400, "#showtooltip\n" .. W.Macro(key), true) then
        return Print("no new wheel: its macro could not be made")
    end
    -- four-way: the eight-way wheel's diagonals are hard to hit with a stick
    SimpleControllerWheelsDB.wheels[key] = { label = label, slots = {}, four = true }
    W.Rebuild(true)
    return key, label
end
-- a wheel made and never used: it and its macro go
function SW.Unmake(key, label)
    SimpleControllerWheelsDB.wheels[key] = nil
    if GetMacroIndexByName(label) > 0 then DeleteMacro(label) end
    W.Rebuild(true)
end

local function ValidName(name)
    return type(name) == "string" and name:match("^[%w_]+$") ~= nil
end

function W.Set(name, wheel)
    if not ValidName(name) then return Print("a wheel's name is letters, digits and _") end
    if InCombatLockdown() then return Print("not in combat") end
    SimpleControllerWheelsDB.wheels[name] = wheel
    W.Rebuild()
    Print("wheel " .. name .. " set, " .. #(ringData[name] or {}) .. " slots; its macro: " .. W.Macro(name))
end

function W.Remove(name)
    if InCombatLockdown() then return Print("not in combat") end
    SimpleControllerWheelsDB.wheels[name] = nil
    W.Rebuild()
    Print("wheel " .. tostring(name) .. " removed (its bar macro now does nothing)")
end

-- the icons of a wheel's slots, in order (gaps left out), for its settings row
function SW.Icons(key)
    local icons = {}
    for _, entry in ipairs(ringData[key] or {}) do
        if entry.icon and not entry.empty and not entry.add then icons[#icons + 1] = entry.icon end
    end
    return icons
end

function W.Macro(name)
    return "/click WCWheel_" .. name .. " Macro"
end

-- every wheel, name and definition (slots, label), for the addons that read
-- them (the export's reach, the Status tab, the buff glow); nothing before login
function W.Each(fn)
    for name, wheel in pairs(SimpleControllerWheelsDB and SimpleControllerWheelsDB.wheels or {}) do fn(name, wheel) end
end

function W.List()
    for key, wheel in pairs(SimpleControllerWheelsDB.wheels) do
        local names = {}
        for _, entry in ipairs(ringData[key] or {}) do names[#names + 1] = entry.label end
        Print(key .. " (" .. (wheel.label or key) .. "): " .. table.concat(names, ", "))
    end
end

-- EditMacro fires UPDATE_MACROS inside the call (a stack overflow, 2026-11-20), and
-- a rebuild edits macros: what the game reports waits for the next frame, so a
-- rebuild never runs inside another.
local queued
local function RebuildNextFrame()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        W.Rebuild(true)
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("UPDATE_MACROS")
events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("BAG_UPDATE_DELAYED") -- an items rule follows the bags
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED") -- and the gear rule what is worn
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then
        SimpleControllerWheelsDB = SimpleControllerWheelsDB or {}
        local db = SimpleControllerWheelsDB
        db.wheels = db.wheels or {}
        RestoreAxis()
        W.Rebuild()
        SW.Settings()
    elseif not SimpleControllerWheelsDB then
        return
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        if ring:IsShown() then
            FormIcons(ringData[ring:GetAttribute("wc-active")] or {})
            look:Icons()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- the secure release already refuses in a fight
        if placing and ring:IsShown() then ring:Hide() end
        EndPlacing()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then W.Rebuild(true) end
    elseif event == "CVAR_UPDATE" then
        if name == "ActionButtonUseKeyDown" then W.Rebuild(true) end
    else
        RebuildNextFrame()
    end
end)
