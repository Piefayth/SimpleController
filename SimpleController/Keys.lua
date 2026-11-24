-- The buttons, with no game API (tested by tools/test_simplecontroller.py): a bar's
-- eight, and which bar the buttons held pick (the shoulders and triggers, and any other
-- a bar's chord has).
local _, SC = ...

-- The eight buttons of a controller bar, Blizzard's order: d-pad left, up, right, down,
-- then square, triangle, circle, cross; and the buttons a bar is picked by.
SC.KEYS = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1" }
SC.CHORD_KEYS = { "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER" }

-- The buttons `bars` are told apart by: the shoulders and triggers, then any other
-- button a bar's chord has (a paddle), in the order first met.
function SC.ChordKeys(bars)
	local keys, seen = {}, {}
	for _, key in ipairs(SC.CHORD_KEYS) do
		keys[#keys + 1], seen[key] = key, true
	end
	for _, bar in ipairs(bars) do
		for _, key in ipairs(bar.keys) do
			if not seen[key] then keys[#keys + 1], seen[key] = key, true end
		end
	end
	return keys
end

-- Which of `bars` is exactly the buttons down, in any order.
function SC.Exact(bars, isDown)
	local keys = SC.ChordKeys(bars)
	for _, bar in ipairs(bars) do
		local want = {}
		for _, key in ipairs(bar.keys) do want[key] = true end
		local exact = true
		for _, key in ipairs(keys) do
			if (want[key] or false) ~= (isDown(key) and true or false) then exact = false end
		end
		if exact then return bar end
	end
end
