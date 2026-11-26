-- The rules, with no game API: which chords there are, where each keeps its spells,
-- and the secure snippet that picks a press's chord in play. Tested by
-- tools/test_simplecontroller.py, every combination.
local _, CB = ...

-- Where a row keeps its eight spells, best first: the first eight slots of one of
-- Blizzard's keyboard action bars 2-8, which a controller player never sees, and
-- last a bar of a controller page, which its d-pad paging shows.
CB.SOURCES = {
	{ id = "bar2", name = "Action Bar 2", first = 61 },
	{ id = "bar3", name = "Action Bar 3", first = 49 },
	{ id = "bar4", name = "Action Bar 4", first = 25 },
	{ id = "bar5", name = "Action Bar 5", first = 37 },
	{ id = "bar6", name = "Action Bar 6", first = 145 },
	{ id = "bar7", name = "Action Bar 7", first = 157 },
	{ id = "bar8", name = "Action Bar 8", first = 169 },
	{ id = "page2left", name = "controller page 2's left bar", first = 213, page = true },
	{ id = "page2right", name = "controller page 2's right bar", first = 221, page = true },
	{ id = "page2bottom", name = "controller page 2's bottom bar", first = 229, page = true },
	{ id = "page3left", name = "controller page 3's left bar", first = 241, page = true },
	{ id = "page3right", name = "controller page 3's right bar", first = 249, page = true },
	{ id = "page3bottom", name = "controller page 3's bottom bar", first = 257, page = true },
}
local SOURCE = {}
for _, source in ipairs(CB.SOURCES) do SOURCE[source.id] = source end

-- The six chords (docs/proposals/native-chords.md): a shoulder, which shows its
-- targeting bar and so takes the eight keys, with L2, R2 or both. `flyout`: Blizzard's
-- class button the chord opens, which it takes over (Settings.lua says so by class).
CB.CHORDS = {
	{ setting = "left", shoulder = "L", keys = { "PADLSHOULDER", "PADLTRIGGER" }, flyout = "LeftClassAction" },
	{ setting = "leftCross", shoulder = "L", keys = { "PADLSHOULDER", "PADRTRIGGER" } },
	{ setting = "leftBoth", shoulder = "L", keys = { "PADLSHOULDER", "PADLTRIGGER", "PADRTRIGGER" } },
	{ setting = "right", shoulder = "R", keys = { "PADRSHOULDER", "PADRTRIGGER" }, flyout = "RightClassAction" },
	{ setting = "rightCross", shoulder = "R", keys = { "PADRSHOULDER", "PADLTRIGGER" } },
	{ setting = "rightBoth", shoulder = "R", keys = { "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER" } },
}
CB.EXTRAS = { setting = "extras" }

-- Bars on chords the player sets by holding them (docs/proposals/pressed-chords.md),
-- saved as the buttons joined by "+" (db[setting]; none: off); `keys` is read from that
-- at login. A chord has a
-- starter, whose press takes the eight keys: any button but the bars' own eight, the
-- shoulders and triggers (which may join one), the reserved and the stick directions.
-- Never in a chord: what a controller reaches the menus with, in Blizzard's own legend
-- of what each button does in play (Blizzard_Gamepad's GamepadPersistentInputLegend.lua).
CB.RESERVED = { PADBACK = "Focus UI", PADFORWARD = "the game menu" }
-- a stick pushed, which the game also reports as buttons (GamePadStickAxisButtons)
local STICK_DIRECTIONS = { "PADLSTICKUP", "PADLSTICKDOWN", "PADLSTICKLEFT", "PADLSTICKRIGHT",
	"PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT" }
CB.PRESSED = {}
for n = 1, 4 do CB.PRESSED[n] = { setting = "pressed" .. n, name = "Custom " .. n, pressed = true } end

-- Every row that keeps spells: the six chords, the extra buttons, the player's own.
function CB.Rows()
	local rows = {}
	for _, chord in ipairs(CB.CHORDS) do rows[#rows + 1] = chord end
	rows[#rows + 1] = CB.EXTRAS
	for _, row in ipairs(CB.PRESSED) do rows[#rows + 1] = row end
	return rows
end

local function has(list, key)
	for _, each in ipairs(list) do
		if each == key then return true end
	end
	return false
end

function CB.IsStarterKey(key)
	return not (has(SimpleController.KEYS, key) or has(SimpleController.CHORD_KEYS, key)
		or CB.RESERVED[key] or has(STICK_DIRECTIONS, key))
end

-- A chord saved and read back: its buttons in one order, the shoulders and triggers
-- first, then the starters by name.
function CB.ChordText(keys)
	local out, starters = {}, {}
	for _, key in ipairs(SimpleController.CHORD_KEYS) do
		if has(keys, key) then out[#out + 1] = key end
	end
	for _, key in ipairs(keys) do
		if CB.IsStarterKey(key) then starters[#starters + 1] = key end
	end
	table.sort(starters)
	for _, key in ipairs(starters) do out[#out + 1] = key end
	return table.concat(out, "+")
end
function CB.ChordKeys(text)
	local keys = {}
	for key in (text or ""):gmatch("[^+]+") do keys[#keys + 1] = key end
	return keys
end

-- Why `keys`, held together, cannot be `row`'s chord (one of `rows`), or nil.
function CB.ChordProblem(keys, row, rows)
	local starter = false
	for _, key in ipairs(keys) do
		if has(SimpleController.KEYS, key) then return "The d-pad and face buttons are the bar's own buttons." end
		if CB.RESERVED[key] then
			return GetBindingText(key) .. " is " .. CB.RESERVED[key] .. ": it cannot be part of a chord."
		elseif has(STICK_DIRECTIONS, key) then
			return "A stick pushed cannot be part of a chord."
		elseif CB.IsStarterKey(key) then
			starter = true
		end
	end
	if not starter then
		return "Add another button (a paddle, a stick click): Blizzard's own play uses the shoulders and triggers alone."
	end
	if #keys > 3 then return "A chord is at most three buttons." end
	local text = CB.ChordText(keys)
	for _, other in ipairs(rows) do
		if other ~= row and other.keys and CB.ChordText(other.keys) == text then
			return other.name .. " has that chord." -- only the player's own bars have a starter
		end
	end
end

local function slotsKey(row) return row.setting .. "Slots" end
CB.SlotsKey = slotsKey

-- Every row is off until the player switches it on, per character: a character
-- with nothing saved has Blizzard's controls as they are.
local function enabled(db, row)
	if row.pressed then return type(db[row.setting]) == "string" and db[row.setting] ~= "" end
	return db[row.setting] == true
end
CB.Enabled = enabled

-- Each enabled row's source. A row keeps the one it was given (db[<row>Slots]), on
-- or off, so its spells never move; one without takes the least bad free source:
-- an empty keyboard bar, a keyboard bar holding spells, an empty controller page
-- bar, a page bar holding spells. `isEmpty(source)` asks the game. Returns the
-- placed rows' sources and the rows just given a controller page, to say so.
function CB.Layout(db, isEmpty)
	local rows, taken, placed, paged = CB.Rows(), {}, {}, {}
	for _, row in ipairs(rows) do
		local id = db[slotsKey(row)]
		if SOURCE[id] and not taken[id] then taken[id] = row else db[slotsKey(row)] = nil end
	end
	for _, row in ipairs(rows) do
		if enabled(db, row) then
			if not db[slotsKey(row)] then
				local best
				for _, want in ipairs({ { false, true }, { false, false }, { true, true }, { true, false } }) do
					for _, source in ipairs(CB.SOURCES) do
						if not best and not taken[source.id] and (source.page or false) == want[1] and isEmpty(source) == want[2] then
							best = source
						end
					end
				end
				db[slotsKey(row)] = best.id
				taken[best.id] = row
				if best.page then paged[#paged + 1] = row end
			end
			placed[row] = SOURCE[db[slotsKey(row)]]
		end
	end
	return placed, paged
end

-- A chord as the secure snippet compares it: "1" or "0" for each of `keys` (every
-- chord's buttons, SimpleController.ChordKeys), in that order, held or not.
function CB.Pattern(keys, isDown)
	local held = {}
	for k, key in ipairs(keys) do held[k] = isDown(key) and "1" or "0" end
	return table.concat(held)
end

CB.ACTIVE_LEVEL = 5 -- the frame level Blizzard raises its active bar to (ActionBar.lua)

-- The secure snippet on key `i`'s button for a group (OnClick, wrapped: self, button,
-- down), among `count` chords told apart by `keys` buttons. Down: the chord whose
-- buttons are exactly those the pad holds (GetGamePadState, its buttons at cb-index<k>
-- for the k-th key; chord n's pattern is cb-want<n>) presses its look (watch<n>) and
-- casts its slot, or its macro's text. None: what Blizzard's press would do, the
-- button at cb-pass<b> of whichever of its `bars` (bar<b>) is active, or nothing; then
-- a shoulder's binder (ref binder) asks again whether it keeps the keys. Up: the chord
-- pressed lets its look go, and the click stops there.
function CB.FireSnippet(i, count, keys, bars)
	return ([[
		if not down then
			local held = self:GetAttribute("cb-held")
			if held then self:GetFrameRef("watch" .. held):RunAttribute("cb-release", %d) end
			self:SetAttribute("cb-held", nil)
			return false
		end
		local state, held = GetGamePadState(), ""
		for k = 1, %d do
			held = held .. (state and state.buttons[self:GetAttribute("cb-index" .. k)] and "1" or "0")
		end
		for n = 1, %d do
			if self:GetAttribute("cb-want" .. n) == held then
				self:GetFrameRef("watch" .. n):RunAttribute("cb-press", %d)
				self:SetAttribute("cb-held", n)
				local macro = GetActionInfo(self:GetAttribute("cb-slot" .. n)) == "macro" and self:GetAttribute("cb-macro" .. n)
				self:SetAttribute("macrotext", macro or self:GetAttribute("cb-chord" .. n))
				return
			end
		end
		local text = ""
		for b = 1, %d do
			local bar = self:GetFrameRef("bar" .. b)
			if bar:IsVisible() and bar:GetFrameLevel() == %d then
				text = self:GetAttribute("cb-pass" .. b)
				break
			end
		end
		self:SetAttribute("macrotext", text)
		local binder = self:GetFrameRef("binder")
		if binder then binder:RunAttribute("cb-sync") end
	]]):format(i, keys, count, i, bars, CB.ACTIVE_LEVEL)
end

-- A shoulder's binder (cb-sync, run by it): it has the eight keys while the shoulder's
-- targeting bar shows or the pad holds the shoulder (cb-shoulder, its place in the pad's
-- state). Compact hides the targeting bar while a trigger is held with the shoulder,
-- so its showing alone is not enough; Blizzard's bars showing and hiding, and each
-- press, ask again.
CB.SYNC = [[
	local state = GetGamePadState()
	local bound = (self:GetFrameRef("targeting"):IsShown() or (state and state.buttons[self:GetAttribute("cb-shoulder")])) and true or false
	if bound == (self:GetAttribute("cb-bound") or false) then return end
	self:SetAttribute("cb-bound", bound)
	self:RunAttribute(bound and "cb-bind" or "cb-free")
]]
