-- Wheels in Simple Controller's editor (Blizzard's bind screen and Edit Action
-- Bars remade), one target action (SimpleController.AddTargetAction, on bare
-- Cross, the one face button Blizzard's bind screen leaves free): handed over with
-- (binding, "Place on wheel": a wheel or a slot for a new one is chosen at once;
-- editing, "Add Wheel": a new, empty wheel is held, to put down like a
-- spell), and, holding a spell, item or macro, "Place on wheel": the wheels on the
-- bars light, and every other slot (a new wheel goes there, over what was there, and
-- opens); the one picked opens to flick where it goes (SW.Place; in Edit
-- Action Bars what was there comes back held, a swap as on a bar). Editing with
-- nothing held, Triangle ("Open wheel", ours only: in Blizzard's bind screen it is its
-- own Edit Action Bar) picks a wheel the same way, and the slot flicked comes off it,
-- held (SW.Take). A new wheel never put down goes when the editor closes, macro and all.
local _, SW = ...

-- The macro on bar slot `action`, by its name: a macro showing a spell (a wheel's
-- with SetMacroSpell) is given by GetActionInfo as that spell's ID, not the macro's.
local function MacroOn(action)
    return GetActionInfo(action) == "macro" and GetActionText(action) or nil
end

-- the wheel whose macro is on bar slot `action`
local function WheelOn(action)
    local name = MacroOn(action)
    local body = name and GetMacroBody(name)
    if not body then return end
    for key in pairs(SimpleControllerWheelsDB.wheels) do
        if body:find(WCWheel.Macro(key), 1, true) then return key end
    end
end

-- what the editor held, as a wheel's slot, or nil and why
local function Slot(thing)
    if not thing then return nil, "nothing is held" end
    local name = thing.name or "that"
    if thing.kind == "spell" then
        if C_Spell.IsSpellPassive(thing.id) then return nil, name .. " is passive" end
        return { spell = thing.id }
    elseif thing.kind == "item" then
        if not C_Item.GetItemSpell(thing.id) then return nil, name .. " has no use" end
        return { item = thing.id }
    elseif thing.kind == "macro" and thing.name then
        return { macro = thing.name } -- a wheel's too: a wheel on a wheel opens it
    end
    return nil, name .. " is not a spell, item or macro"
end

-- a macro on any action slot
local function OnBars(name)
    for action = 1, 400 do
        if MacroOn(action) == name then return true end
    end
end
local made = {} -- wheels made by Add Wheel this session, gone again if never put down
-- a macro on any wheel
local function OnWheels(name)
    for _, wheel in pairs(SimpleControllerWheelsDB.wheels) do
        for _, slot in ipairs(wheel.slots or {}) do
            if slot.macro == name then return true end
        end
    end
end
-- one of them still unused: empty, on no bar and no wheel
local function unused(key, label)
    local wheel = SimpleControllerWheelsDB.wheels[key]
    return wheel and #(wheel.slots or {}) == 0 and not OnBars(label) and not OnWheels(label)
end
SimpleController.AddTargetAction({
    key = "PAD1",
    handOver = "Add Wheel",
    label = "Place on wheel",
    choose = "Choose a wheel to add to, or a slot for a new wheel.",
    target = function() return true end,
    run = function(action, thing, editing, done)
        local slot, why = Slot(thing)
        if not slot then
            done()
            return SW.Say("Wheel: " .. why .. ", so it cannot go on a wheel")
        end
        local key = WheelOn(action)
        if not key then
            -- a new wheel in that slot, over whatever was there
            local label
            key, label = SW.NewWheel()
            if not key then return done() end
            PickupMacro(label)
            PlaceAction(action)
            ClearCursor()
        end
        SW.Place(key, slot, thing.name or "it", editing, done)
    end,
    fresh = function()
        -- the one made and let go of again, before another
        for key, label in pairs(made) do
            if unused(key, label) then return { func = PickupMacro, params = { label } } end
        end
        local key, label = SW.NewWheel()
        if not key then return end
        made[key] = label
        return { func = PickupMacro, params = { label } }
    end,
})

SimpleController.AddTargetAction({
    key = "PAD4",
    pick = { label = "Open wheel", choose = "Choose a wheel to take from." },
    target = function(action) return WheelOn(action) ~= nil end,
    run = function(action, _, _, done) SW.Take(WheelOn(action), done) end,
})

SimpleController.OnEditor(function(open)
    if open then return end
    for key, label in pairs(made) do
        if unused(key, label) then SW.Unmake(key, label) end
    end
    wipe(made)
end)
