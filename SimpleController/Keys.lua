-- The buttons, with no game API (tested by tools/test_simplecontroller.py): a bar's
-- eight, and which bar the shoulders and triggers held pick.
local _, SC = ...

-- The eight buttons of a controller bar, Blizzard's order: d-pad left, up, right, down,
-- then square, triangle, circle, cross; and the buttons a bar is picked by.
SC.KEYS = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1" }
SC.CHORD_KEYS = { "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER" }

-- Which of `bars` is exactly the buttons down, in any order.
function SC.Exact(bars, isDown)
	for _, bar in ipairs(bars) do
		local want = {}
		for _, key in ipairs(bar.keys) do want[key] = true end
		local exact = true
		for _, key in ipairs(SC.CHORD_KEYS) do
			if (want[key] or false) ~= (isDown(key) and true or false) then exact = false end
		end
		if exact then return bar end
	end
end
