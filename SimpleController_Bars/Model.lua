-- The rules, with no game API: which chords there are, where each keeps its spells,
-- which chord a press belongs to, and the secure snippet that decides it in play.
-- Tested by tests/test_bars_model.py, every combination.
local _, CB = ...

CB.ACTIVE_LEVEL = 5 -- the frame level Blizzard raises the active gamepad bar to

-- The bars Blizzard lights for a trigger held.
CB.LIT_BARS = { "leftBar", "rightBar", "stanceBar", "bottomBar" }

-- The shoulders and triggers, the buttons a chord is made of.
CB.CHORD_KEYS = { "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER" }

-- Which of `chords` is exactly the buttons down (`isDown(key)`), in any order: where
-- the keys can be read (the bind screen), unlike the secure code of play.
function CB.ChordForKeys(chords, isDown)
	for _, chord in ipairs(chords) do
		local want = {}
		for _, key in ipairs(chord.keys) do want[key] = true end
		local exact = true
		for _, key in ipairs(CB.CHORD_KEYS) do
			if (want[key] or false) ~= (isDown(key) and true or false) then exact = false end
		end
		if exact then return chord end
	end
end

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

-- The six chords the game lets us tell apart (docs/proposals/native-chords.md): a
-- shoulder, which shows its targeting bar, with L2, R2 or both, which light one bar
-- of Blizzard's (`lit`). `note`: what switching it on changes.
CB.CHORDS = {
	{ setting = "left", shoulder = "L", lit = { "leftBar" },
		keys = { "PADLSHOULDER", "PADLTRIGGER" }, flyout = "LeftClassAction",
		note = "Hides the class or pet flyout that L1 + L2 opened." },
	{ setting = "leftCross", shoulder = "L", lit = { "rightBar", "stanceBar" },
		keys = { "PADLSHOULDER", "PADRTRIGGER" },
		note = "Fires instead of your R2 bar while L1 is held. R2 alone still fires it." },
	{ setting = "leftBoth", shoulder = "L", lit = { "bottomBar" },
		keys = { "PADLSHOULDER", "PADLTRIGGER", "PADRTRIGGER" },
		note = "Fires instead of your L2 + R2 bar while L1 is held. L2 + R2 alone still fires it." },
	{ setting = "right", shoulder = "R", lit = { "rightBar", "stanceBar" },
		keys = { "PADRSHOULDER", "PADRTRIGGER" }, flyout = "RightClassAction",
		note = "Hides the class or pet flyout that R1 + R2 opened." },
	{ setting = "rightCross", shoulder = "R", lit = { "leftBar" },
		keys = { "PADRSHOULDER", "PADLTRIGGER" },
		note = "Fires instead of your L2 bar while R1 is held. L2 alone still fires it." },
	{ setting = "rightBoth", shoulder = "R", lit = { "bottomBar" },
		keys = { "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER" },
		note = "Fires instead of your L2 + R2 bar while R1 is held. L2 + R2 alone still fires it." },
}
CB.EXTRAS = { setting = "extras" }

-- Every row that keeps spells: the six chords and the extra buttons.
function CB.Rows()
	local rows = {}
	for _, chord in ipairs(CB.CHORDS) do rows[#rows + 1] = chord end
	rows[#rows + 1] = CB.EXTRAS
	return rows
end

local function slotsKey(row) return row.setting .. "Slots" end
CB.SlotsKey = slotsKey

-- Every row is off until the player switches it on, per character: a character
-- with nothing saved has Blizzard's controls as they are.
local function enabled(db, row)
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

-- Which of `chords` (one shoulder's, in order) a press belongs to, from what the
-- game shows: whether that shoulder's targeting bar is up, and each bar's level.
function CB.ChordFor(chords, shown, level)
	if not shown then return nil end
	for n, chord in ipairs(chords) do
		for _, key in ipairs(chord.lit) do
			if level(key) == CB.ACTIVE_LEVEL then return chord, n end
		end
	end
end

-- The slots of Blizzard's bar to trade with ours: all eight but the one its editor is
-- holding a spell from, which stays Blizzard's (picked up before the trade, from its own
-- bar: traded, its undo would land on our spell, 2026-11-23).
function CB.TradeSlots(theirs, mode, pickupSlot)
	local out = {}
	for _, slot in ipairs(theirs) do
		if not (mode == "PLACE_OR_CLEAR_HELD_ACTION" and slot == pickupSlot) then out[#out + 1] = slot end
	end
	return out
end

-- The secure snippet on key `i`'s button for a shoulder with `count` chords
-- (OnClick, wrapped: self, button, down). Down: the first chord whose bar is lit
-- (refs a<n>, b<n>) presses its look (watch<n>) and casts its slot, or its macro's
-- text; none: the targeting bar's own button (cb-pass). Up: the chord pressed lets
-- its look go, and the click stops there.
function CB.FireSnippet(i, count)
	return ([[
		if not down then
			local held = self:GetAttribute("cb-held")
			if held then self:GetFrameRef("watch" .. held):RunAttribute("cb-release", %d) end
			self:SetAttribute("cb-held", nil)
			return false
		end
		local text = self:GetAttribute("cb-pass")
		for n = 1, %d do
			local a, b = self:GetFrameRef("a" .. n), self:GetFrameRef("b" .. n)
			if a:GetFrameLevel() == %d or (b and b:GetFrameLevel() == %d) then
				self:GetFrameRef("watch" .. n):RunAttribute("cb-press", %d)
				self:SetAttribute("cb-held", n)
				local macro = GetActionInfo(self:GetAttribute("cb-slot" .. n)) == "macro" and self:GetAttribute("cb-macro" .. n)
				text = macro or self:GetAttribute("cb-chord" .. n)
				break
			end
		end
		self:SetAttribute("macrotext", text)
	]]):format(i, count, CB.ACTIVE_LEVEL, CB.ACTIVE_LEVEL, i)
end
