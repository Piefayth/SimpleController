-- Spin tricks (the player, 2026-11-18): turning while airborne out of combat is
-- scored. Every full circle in the air stamps this jump's degrees to the right
-- of the character, with a chime; the landing sucks them whole into the combo
-- beside them, which bursts in their colour as they arrive (its only sparks)
-- and counts up through them, each
-- step a visible bump ("720 x1" ticks x2, x3).
-- Landing confirms nothing:
-- the combo goes on while each next jump, taken off within COMBO_GAP seconds of
-- landing, makes at least one circle. No jump in time or a jump with no circle is a
-- Miss; under it on the same diagonal, "no jump" or the degrees that jump did turn.
-- Combat ends the combo, saying so.
-- A completed circle is banked: the next may turn either way
-- (left then right is 720, not 0), measured from where the turn reversed, so
-- overshooting a circle costs the next nothing.
-- A Switchback (2026-11-23) is a circle the opposite way to the one before it in
-- the same jump: right, left, right is Switchback x2.
-- A Lookback (2026-11-23) is a circle that spends at least half its time within
-- LOOK_WITHIN of facing opposite where that circle began, named as it closes; a
-- jump counts them (Lookback x2), and one circle can be a Switchback as well.
-- Consecutive jumps holding the same trick are Back to Back, on its own line above
-- the tricks from the moment the second one's is made; a third in a row is Back to
-- Back x2, and so on, centred over the trick it counts: the longer run of two, the
-- first done when they tie.
-- The combo heats up to HOT: its count grows, bumps harder and climbs COMBO_COLORS,
-- bronze to white gold, its bursts grow, and at HOT it shimmers. The degrees
-- are never its colours: each circle of the jump makes them bigger, stamps them
-- harder and moves them along DEG_COLORS, cold to hot; past the last they shimmer.
-- Each takeoff judges the landing before it by the time on
-- the ground, the way DDR judges a step (the player): the best word that time
-- reaches, from JUDGES, the time beneath, until the next. A Miss
-- is the combo breaking: its count reddens, swells, and flies up tilting to stay
-- above the Miss that stamps diagonally beneath it ("x15 / Miss / 212°"), on a
-- frame of its own so jumping again cannot wipe it; the first circle of a new
-- combo fades it at once. Turning on the ground is free (2026-11-20).
-- Every scoring jump lands showing its degrees per second in the air and its
-- time, so a short jump and a long one are measured alike (the player).
-- Tight (2026-11-23): the jump's last circle closed within TIGHT seconds of the
-- landing. It stamps above the combo with a chime and stays until the next circle.
-- The jump's numbers (f.meter) and the gap's (f.judge, f.line) have a line each, so a
-- frame-perfect next jump cannot wipe the numbers its landing just showed.
-- Smoothness is a picture (the player, 2026-11-20): each landing draws the jump,
-- takeoff to landing left to right, as beads on a vine: the speed of the turn,
-- relative to the jump's own average, which is the vine. A bead rises for faster
-- and sinks for slower, full height at double the average or at a stop, and only
-- faster reddens, so a steady spin is a calm bronze line. Each bead's speed is
-- over PACE_SPAN slices of the air, so the game's facing moving in bursts frame
-- to frame costs nothing.
-- A landing is a frame with IsFalling false, or the jump key pressed on the
-- ground while it never read false (a frame-perfect hop).
-- Facing comes from GetPlayerFacing (nil in instances: nothing scores there).

local COMBO_GAP = 0.5
-- the gap's windows: time on the ground in seconds (DDR's, with Marvelous
-- tightened by the player); the first it fits is its word
local JUDGES = {
	{ 'Marvelous', 0.01, { 1, 0.97, 0.85 } },
	{ 'Perfect', 0.033, { 1, 0.82, 0.2 } },
	{ 'Great', 0.092, { 0.4, 0.95, 0.4 } },
	{ 'Good', 0.142, { 0.35, 0.7, 1 } },
	{ 'OK', 0.225, { 0.8, 0.5, 1 } },
	{ 'Bad', COMBO_GAP, { 0.85, 0.35, 0.25 } },
}
local MISS = { 1, 0.2, 0.2 }
local MISS_TILT = math.rad(20)
-- a circle counts at 357 real degrees; the 3 forgiven are spread evenly over
-- the circle (every degree shown is 360/357 of one turned), so nothing jumps
local STRETCH = 360 / (360 - 3)
local HOT = 24
local TAU = 2 * math.pi
local PACE_COLS, PACE_STEP, PACE_BEAD, PACE_TALL, PACE_SPAN = 28, 6, 5, 15, 3
local PACE_OFF = { 1, 0.25, 0.15 }
local RADIUS = 120 -- how far the readouts stand from the character
local COMBO_X, COMBO_Y = 215, -40 -- where the degrees meet the combo, directly right of the character
local MISS_X, MISS_Y = COMBO_X + 10, COMBO_Y + 85 -- the Miss, just above them
local TRICK_Y = COMBO_Y - 42 -- the top of the trick's name, just under them
local BACK_H = 30 -- how far Back to Back pushes the tricks down
local TRICK_SEP = '|cff9a8a6a + |r'
local LOOK_WITHIN = math.rad(45)
local TIGHT, TIGHT_Y = 0.05, COMBO_Y + 48 -- seconds before landing that count, and where it stamps
local SUCK = 0.24 -- seconds for the degrees to fly into the combo
local BREAK_SWELL, BREAK_FLY = 0.09, 0.16 -- seconds the broken combo swells, then flies to the Miss
local LOST_RISE, LOST_SIZE = 42, 30 -- the lost count: how far up the Miss's diagonal, its size
local LOST_X, LOST_Y = MISS_X - LOST_RISE * math.sin(MISS_TILT), MISS_Y + LOST_RISE * math.cos(MISS_TILT)
local BREAK_GROW = 1.25 -- how far the broken combo swells
local MISS_CLEAR = 0.2 -- seconds the Miss takes to fade once a new combo starts
local TICK = 0.16 -- seconds between the combo's steps as it counts them up
local DEG_COLORS = { { 0.3, 0.8, 1 }, { 0.62, 0.5, 1 }, { 1, 0.3, 0.85 }, { 1, 0.25, 0.3 } }
local DEG_SHIMMER = 3 -- colours a second, past the last
local DROP = 46 -- the readouts' top under the frame: their last line clears the action bars
local DISC = 'Interface\\CharacterFrame\\TempPortraitAlphaMask'
local SPARK = 'AftLevelup-WhiteStarBurst'
local SOUNDS = { 'IG_QUEST_LIST_COMPLETE', 'UI_GARRISON_TOAST_MISSION_COMPLETE', 'UI_ADVENTURES_ADVENTURER_LEVEL_UP' }

local LIT = { 0.95, 0.80, 0.53 }
local COMBO_COLORS = { LIT, { 1, 0.62, 0.2 }, { 1, 0.84, 0.25 }, { 1, 0.97, 0.82 } }
local COMBO_SHIMMER = 7 -- radians a second, at HOT

local function sound(circles)
	local id = SOUNDKIT and SOUNDKIT[SOUNDS[math.min(circles, #SOUNDS)]]
	if id then PlaySound(id) end
end

local function mix(a, b, k)
	return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k
end

-- 0 at no combo, 1 at HOT
local function heat(combo) return math.min(combo / HOT, 1) end
local function tint(h)
	local t = h * (#COMBO_COLORS - 1)
	local i = math.min(math.floor(t), #COMBO_COLORS - 2)
	return mix(COMBO_COLORS[i + 1], COMBO_COLORS[i + 2], t - i)
end
local function comboSize(n) return 44 + 28 * heat(n) end
local function comboColor(n, now)
	if n < HOT then return tint(heat(n)) end
	return mix(COMBO_COLORS[3], COMBO_COLORS[4], 0.5 + 0.5 * math.sin(now * COMBO_SHIMMER))
end

-- the degrees' look for a jump of n circles
local function degSize(n) return math.min(38 + 8 * n, 66) end
local function degStamp(n) return math.min(1.8 + 0.4 * n, 3.4) end
local function degColor(n, now)
	if n <= #DEG_COLORS then
		local c = DEG_COLORS[math.max(n, 1)]
		return c[1], c[2], c[3]
	end
	local t = (now * DEG_SHIMMER) % #DEG_COLORS
	local i = math.floor(t)
	return mix(DEG_COLORS[i + 1], DEG_COLORS[(i + 1) % #DEG_COLORS + 1], t - i)
end

-- each piece made once per session, so a new version adds only what it lacks
-- A thin vine across `owner` (16 high): round ends and a repeating run between,
-- never snapped to the pixel grid, so its pieces meet without a step.
local ART = [[Interface\AddOns\SimpleController_Spin\Art\Vine-Thin]]
local function vine(owner)
	local function piece(name, w)
		local t = owner:CreateTexture(nil, 'ARTWORK')
		t:SetTexelSnappingBias(0)
		t:SetSnapToPixelGrid(false)
		t:SetTexture(ART .. name .. '-9', w and 'CLAMP' or 'REPEAT', 'CLAMP')
		t:SetHeight(16)
		if w then t:SetWidth(w) end
		return t
	end
	local left, right, mid = piece('Left', 32), piece('Right', 32), piece('Mid')
	left:SetPoint('LEFT')
	right:SetPoint('RIGHT')
	mid:SetPoint('LEFT', left, 'RIGHT')
	mid:SetPoint('RIGHT', right, 'LEFT')
	owner:SetScript('OnSizeChanged', function(_, w) mid:SetTexCoord(0, math.max(w - 64, 0) / 64, 0, 1) end)
end

local function build()
	local f = CreateFrame('Frame', 'SimpleControllerSpin', UIParent)
	f:SetSize(2 * RADIUS + 12, 2 * RADIUS + 12)
	f:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	f:SetFrameStrata('HIGH')
	f.combo = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	f.line = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	local out = f:CreateAnimationGroup()
	local fade = out:CreateAnimation('Alpha')
	fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetStartDelay(2); fade:SetDuration(0.5)
	out:SetScript('OnFinished', function() f:Hide() end)
	f.out = out
	-- the spark on the combo
	f.spark = f:CreateTexture(nil, 'OVERLAY')
	f.spark:SetAtlas(SPARK)
	f.spark:SetBlendMode('ADD')
	f.spark:SetSize(70, 70)
	f.spark:SetAlpha(0)
	local burst = f:CreateAnimationGroup()
	local grow = burst:CreateAnimation('Scale')
	grow:SetTarget(f.spark)
	grow:SetScaleFrom(0.3, 0.3); grow:SetScaleTo(1.4, 1.4); grow:SetDuration(0.35); grow:SetSmoothing('OUT')
	local show = burst:CreateAnimation('Alpha')
	show:SetTarget(f.spark)
	show:SetFromAlpha(1); show:SetToAlpha(0); show:SetDuration(0.35)
	f.burst = burst
	f.motes, f.spare = {}, {}
	-- the jump's picture: beads behind a thin vine
	local p = CreateFrame('Frame', nil, f)
	p:SetSize(PACE_COLS * PACE_STEP, 2 * PACE_TALL + 2)
	local rule = CreateFrame('Frame', nil, p)
	rule:SetPoint('LEFT')
	rule:SetPoint('RIGHT')
	rule:SetHeight(16)
	vine(rule)
	p.beads = {}
	for i = 1, PACE_COLS do
		local b = p:CreateTexture(nil, 'ARTWORK')
		b:SetTexture(DISC)
		b:SetWidth(PACE_BEAD)
		p.beads[i] = b
	end
	p:Hide()
	f.pace = p
	f.pace:ClearAllPoints()
	f.pace:SetPoint('TOP', f, 'BOTTOM', 0, -DROP)
	local m = CreateFrame('Frame', nil, UIParent)
	m:SetFrameStrata('HIGH')
	m:SetAllPoints(f)
	m.stamp = m:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	m.stamp:SetFont(m.stamp:GetFont(), 46, 'THICKOUTLINE')
	m.stamp:SetTextColor(MISS[1], MISS[2], MISS[3])
	m.stamp:SetText('Miss')
	m.stamp:SetRotation(MISS_TILT)
	m.why = m:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	m.why:SetFont(m.why:GetFont(), 20, 'OUTLINE')
	m.why:SetTextColor(MISS[1], MISS[2], MISS[3])
	m.why:SetRotation(MISS_TILT)
	m.why:SetPoint('CENTER', m.stamp, 'CENTER', 36 * math.sin(MISS_TILT), -36 * math.cos(MISS_TILT))
	local pop = m:CreateAnimationGroup()
	for _, text in ipairs({ m.stamp, m.why }) do
		local drop = pop:CreateAnimation('Scale')
		drop:SetTarget(text)
		drop:SetScaleFrom(2.4, 2.4); drop:SetScaleTo(1, 1); drop:SetDuration(0.14); drop:SetSmoothing('IN')
	end
	m.pop = pop
	local out = m:CreateAnimationGroup()
	local fade = out:CreateAnimation('Alpha')
	fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetStartDelay(3); fade:SetDuration(0.5)
	out:SetScript('OnFinished', function() m:Hide() end)
	m.out = out
	m:Hide()
	f.miss = m
	f.miss.stamp:ClearAllPoints()
	f.miss.stamp:SetPoint('CENTER', f.miss, 'CENTER', MISS_X, MISS_Y)
	-- the combo's count, breaking into the Miss
	local m = f.miss
	m.broke = m:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	m.broke:SetFont(m.broke:GetFont(), 44, 'THICKOUTLINE')
	m.broke:SetTextColor(MISS[1], MISS[2], MISS[3])
	m.broke:Hide()
	local brk = m:CreateAnimationGroup()
	local swell = brk:CreateAnimation('Scale')
	swell:SetTarget(m.broke); swell:SetOrder(1)
	swell:SetScaleFrom(1, 1); swell:SetScaleTo(BREAK_GROW, BREAK_GROW); swell:SetDuration(BREAK_SWELL); swell:SetSmoothing('OUT')
	local move = brk:CreateAnimation('Translation')
	move:SetTarget(m.broke); move:SetOrder(2)
	move:SetDuration(BREAK_FLY); move:SetSmoothing('IN')
	local tilt = brk:CreateAnimation('Rotation')
	tilt:SetTarget(m.broke); tilt:SetOrder(2)
	tilt:SetDegrees(math.deg(MISS_TILT)); tilt:SetDuration(BREAK_FLY); tilt:SetSmoothing('IN')
	local fade = brk:CreateAnimation('Alpha')
	fade:SetTarget(m.broke); fade:SetOrder(2)
	fade:SetFromAlpha(1); fade:SetToAlpha(0.3); fade:SetDuration(BREAK_FLY); fade:SetSmoothing('IN')
	m.brk, m.brokeMove = brk, move
	-- the count that was lost, above the Miss on its diagonal
	local m = f.miss
	m.lost = m:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	m.lost:SetFont(m.lost:GetFont(), LOST_SIZE, 'THICKOUTLINE')
	m.lost:SetTextColor(MISS[1], MISS[2], MISS[3])
	m.lost:SetRotation(MISS_TILT)
	m.lost:SetPoint('CENTER', m, 'CENTER', LOST_X, LOST_Y)
	m.lost:Hide()
	local drop = m.pop:CreateAnimation('Scale')
	drop:SetTarget(m.lost)
	drop:SetScaleFrom(1.5, 1.5); drop:SetScaleTo(1, 1); drop:SetDuration(0.14); drop:SetSmoothing('IN')
	local shrink = m.brk:CreateAnimation('Scale')
	shrink:SetTarget(m.broke); shrink:SetOrder(2)
	shrink:SetScaleFrom(1, 1); shrink:SetDuration(BREAK_FLY); shrink:SetSmoothing('IN')
	m.brokeShrink = shrink
	f.miss.brk:SetScript('OnFinished', function()
		local m = f.miss
		m.broke:Hide()
		m.lost:Show()
		m.stamp:Show()
		m.why:Show()
		m.pop:Stop(); m.pop:Play()
		m.out:Play()
	end)
	local m = f.miss
	local clear = m:CreateAnimationGroup()
	local fade = clear:CreateAnimation('Alpha')
	fade:SetToAlpha(0); fade:SetDuration(MISS_CLEAR)
	clear:SetScript('OnFinished', function() m:Hide() end)
	m.clear, m.clearFade = clear, fade
	f.miss.broke:ClearAllPoints()
	f.miss.broke:SetPoint('LEFT', f.miss, 'CENTER', COMBO_X + 6, COMBO_Y)
	f:Hide()
	return f
end

-- motes: soft additive dots flying from a point, falling (g < 0) or rising
local function mote(f, x, y, vx, vy, g, size, life, r, gg, b)
	local m = table.remove(f.spare)
	if not m then
		m = { tex = f:CreateTexture(nil, 'OVERLAY') }
		m.tex:SetTexture(DISC)
		m.tex:SetBlendMode('ADD')
	end
	m.x, m.y, m.vx, m.vy, m.g, m.size, m.life, m.t = x, y, vx, vy, g, size, life, 0
	m.tex:SetVertexColor(r, gg, b)
	m.tex:Show()
	f.motes[#f.motes + 1] = m
end

local function stepMotes(f, dt)
	local motes = f.motes
	for i = #motes, 1, -1 do
		local m = motes[i]
		m.t = m.t + dt
		if m.t >= m.life then
			m.tex:Hide()
			table.remove(motes, i)
			f.spare[#f.spare + 1] = m
		else
			m.vy = m.vy + m.g * dt
			m.x, m.y = m.x + m.vx * dt, m.y + m.vy * dt
			local k = 1 - m.t / m.life
			m.tex:ClearAllPoints()
			m.tex:SetPoint('CENTER', f, 'CENTER', m.x, m.y)
			m.tex:SetSize(m.size * (0.4 + 0.6 * k), m.size * (0.4 + 0.6 * k))
			m.tex:SetAlpha(k)
		end
	end
end

-- the degrees arrive: a star and a burst in their colour, growing with the combo
local function spark(f, combo, circles, x)
	local h = heat(combo)
	f.spark:ClearAllPoints()
	f.spark:SetPoint('CENTER', f, 'CENTER', x, COMBO_Y)
	f.spark:SetVertexColor(degColor(circles, GetTime()))
	f.spark:SetSize(70 + 110 * h, 70 + 110 * h)
	f.burst:Stop(); f.burst:Play()
	for _ = 1, math.min(8 + combo * 4, 60) do
		local a = math.random() * TAU
		local speed = (80 + 260 * h) * (0.5 + math.random())
		mote(f, x, COMBO_Y, speed * math.cos(a), speed * math.sin(a), -260,
			5 + 7 * h * math.random(), 0.45 + 0.5 * h, degColor(circles, GetTime() + math.random()))
	end
end

local function enable()
	local f = build()
	f.combo:SetFont(f.combo:GetFont(), 44, 'THICKOUTLINE')
	f.combo:ClearAllPoints()
	f.combo:SetPoint('LEFT', f, 'CENTER', COMBO_X + 6, COMBO_Y)
	local step = f:CreateAnimationGroup()
	local bump = step:CreateAnimation('Scale')
	bump:SetTarget(f.combo)
	bump:SetScaleTo(1, 1); bump:SetDuration(0.13); bump:SetSmoothing('OUT')
	f.comboStep = step
	local comboBump = f.comboStep:GetAnimations()
	f.degs = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	local pop = f:CreateAnimationGroup()
	local drop = pop:CreateAnimation('Scale')
	drop:SetTarget(f.degs)
	drop:SetScaleFrom(2.2, 2.2); drop:SetScaleTo(1, 1); drop:SetDuration(0.14); drop:SetSmoothing('IN')
	f.degsStamp = pop
	local degsDrop = f.degsStamp:GetAnimations()
	f.degs:SetFont(f.combo:GetFont(), degSize(1), 'THICKOUTLINE')
	f.degs:ClearAllPoints()
	f.degs:SetPoint('RIGHT', f, 'CENTER', COMBO_X - 6, COMBO_Y)
	-- the landed degrees on their way into the combo
	f.ghost = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	f.meter = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	f.meter:ClearAllPoints()
	f.meter:SetPoint('TOP', f.pace, 'BOTTOM', 0, -2)
	f.judge = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	local pop = f:CreateAnimationGroup()
	local grow = pop:CreateAnimation('Scale')
	grow:SetTarget(f.judge)
	grow:SetScaleFrom(1.7, 1.7); grow:SetScaleTo(1, 1); grow:SetDuration(0.12); grow:SetSmoothing('IN')
	f.judgePop = pop
	f.judge:SetFont(f.judge:GetFont(), 28, 'THICKOUTLINE')
	f.judge:ClearAllPoints()
	f.judge:SetPoint('TOP', f.meter, 'BOTTOM', 0, -4)
	local lineFont, lineSize = f.line:GetFont()
	f.line:SetFont(lineFont, lineSize, 'OUTLINE')
	f.line:ClearAllPoints()
	f.line:SetPoint('TOP', f.meter, 'BOTTOM', 0, -36)
	f.line:SetTextColor(0.6, 0.6, 0.6)
	f.trick = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	local pop = f:CreateAnimationGroup()
	local drop = pop:CreateAnimation('Scale')
	drop:SetTarget(f.trick)
	drop:SetScaleFrom(1.8, 1.8); drop:SetScaleTo(1, 1); drop:SetDuration(0.14); drop:SetSmoothing('IN')
	f.trickStamp = pop
	f.trick:SetFont(f.trick:GetFont(), 26, 'THICKOUTLINE')
	f.trick:SetTextColor(LIT[1], LIT[2], LIT[3])
	f.trick:SetJustifyH('LEFT')
	f.trick:ClearAllPoints()
	f.trick:SetPoint('TOPLEFT', f, 'CENTER', RADIUS + 5, TRICK_Y) -- grows right, away from the character
	f.back = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	local pop = f:CreateAnimationGroup()
	local drop = pop:CreateAnimation('Scale')
	drop:SetTarget(f.back)
	drop:SetScaleFrom(1.8, 1.8); drop:SetScaleTo(1, 1); drop:SetDuration(0.14); drop:SetSmoothing('IN')
	f.backStamp = pop
	f.back:SetFont(f.trick:GetFont(), 26, 'THICKOUTLINE')
	f.back:SetTextColor(1, 0.82, 0)
	f.tight = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	local pop = f:CreateAnimationGroup()
	local drop = pop:CreateAnimation('Scale')
	drop:SetTarget(f.tight)
	drop:SetScaleFrom(2.2, 2.2); drop:SetScaleTo(1, 1); drop:SetDuration(0.14); drop:SetSmoothing('IN')
	f.tightStamp = pop
	f.tight:SetFont(f.tight:GetFont(), 34, 'THICKOUTLINE')
	f.tight:SetTextColor(1, 0.82, 0)
	f.tight:ClearAllPoints()
	f.tight:SetPoint('CENTER', f, 'CENTER', COMBO_X, TIGHT_Y)
	local circleAt = 0 -- when this jump's last circle closed
	-- the circle under way: its running angle and the seconds at each
	local spinA, spinT = {}, {}
	-- this jump's tricks, first done first, and how many of each
	local chain, held = {}, {}
	local runs = {} -- per trick, how many jumps in a row before this one held it
	-- the jump's running angle, and its extremes since the last banked circle
	local air, last, turned, low, high, circles = false, nil, 0, 0, 0, 0
	local lastDir = nil -- the direction of this jump's last circle
	local combo, landedAt = 0, nil
	local takeoff = 0
	-- circles the combo shows, those landed (some perhaps still on their way into
	-- it), and when it next steps up; the degrees are the circles of the jump under way
	local fed, banked, tickAt = 0, 0, nil
	local flying = 0 -- circles in the degrees on their way to the combo
	local function counters()
		local owed = combo - banked
		f.degs:SetText(owed > 0 and ('%d°'):format(owed * 360) or '')
		f.combo:SetFont(f.combo:GetFont(), comboSize(fed), 'THICKOUTLINE')
		f.combo:SetText(fed > 0 and ('x%d'):format(fed) or '')
	end
	-- the flight, drawn by hand so it ends exactly on the count it feeds:
	-- from the degrees' centre to the centre of the combo's next number
	local suckAt, suckFrom, suckTo = nil, 0, 0
	local function suckStep(k)
		local e = k * k
		f.ghost:ClearAllPoints()
		f.ghost:SetPoint('CENTER', f, 'CENTER', suckFrom + (suckTo - suckFrom) * e, COMBO_Y)
		f.ghost:SetTextScale(1 - 0.8 * e)
		f.ghost:SetAlpha(1 - 0.8 * e)
	end
	-- this jump's angle each frame from takeoff (seconds, degrees turned either way)
	local traceT, traceD = {}, {}

	-- the jump's picture: the angle at each slice's edge, read between the two
	-- frames around it, then each bead's speed over the PACE_SPAN slices round it
	local function drawPace(now)
		local n = #traceT + 1
		traceT[n], traceD[n] = now, traceD[n - 1]
		local t0, T = traceT[1], now - traceT[1]
		local edge, i = { [0] = 0 }, 2
		for c = 1, PACE_COLS do
			local at = t0 + T * c / PACE_COLS
			while i < n and traceT[i] < at do i = i + 1 end
			local a = traceT[i - 1]
			edge[c] = traceD[i - 1] + (traceD[i] - traceD[i - 1]) * (at - a) / (traceT[i] - a)
		end
		local mean = traceD[n] / PACE_COLS
		local reach = (PACE_SPAN - 1) / 2
		for c, bead in ipairs(f.pace.beads) do
			local from, to = math.max(c - 1 - reach, 0), math.min(c + reach, PACE_COLS)
			local off = (edge[to] - edge[from]) / (to - from) / mean - 1
			local k = math.min(1, math.abs(off))
			local red = off > 0 and k or 0
			local h = PACE_BEAD + k * (PACE_TALL - PACE_BEAD)
			bead:ClearAllPoints()
			bead:SetPoint('CENTER', f.pace, 'LEFT', (c - 0.5) * PACE_STEP, (off < 0 and -1 or 1) * (h - PACE_BEAD) / 2)
			bead:SetHeight(h)
			bead:SetVertexColor(LIT[1] + (PACE_OFF[1] - LIT[1]) * red, LIT[2] + (PACE_OFF[2] - LIT[2]) * red,
				LIT[3] + (PACE_OFF[3] - LIT[3]) * red)
		end
		f.pace:Show()
	end

	-- the next takeoff judges the landing
	local function judge(j, gap)
		local c = j[3]
		f.judge:SetText(j[1])
		f.judge:SetTextColor(c[1], c[2], c[3])
		f.line:SetText(('|cff%02x%02x%02x%.2fs|r'):format(c[1] * 255, c[2] * 255, c[3] * 255, gap))
		f.judgePop:Stop(); f.judgePop:Play()
	end

	local function live()
		f.out:Stop()
		f:SetAlpha(1)
		f:Show()
	end

	-- a new combo began: the last one's Miss gets out of its way
	local function clearMiss()
		local m = f.miss
		if not m:IsShown() or m.clear:IsPlaying() then return end
		if m.brk:IsPlaying() then
			m.brk:Stop()
			m.broke:Hide()
			m:Hide()
			return
		end
		m.clearFade:SetFromAlpha(m:GetAlpha())
		m.out:Stop()
		m.clear:Play()
	end

	local function clearTricks()
		f.trick:SetText('')
		f.back:SetText('')
	end

	-- the combo ends: a Miss stamps, combat says so under the count, which fades
	local function endCombo(why)
		if combo >= 2 and combo > SimpleControllerSpinDB.bestCombo then SimpleControllerSpinDB.bestCombo = combo end
		suckAt = nil
		f.ghost:SetText('')
		if f:IsShown() then
			if why ~= 'combat' then
				f.combo:SetText(''); f.degs:SetText(''); f.meter:SetText('')
				f.judge:SetText(''); f.line:SetText(''); clearTricks(); f.tight:SetText(''); f.pace:Hide()
				local m = f.miss
				m.why:SetText(why)
				m.out:Stop(); m.pop:Stop(); m.brk:Stop(); m.clear:Stop()
				m.stamp:Hide(); m.why:Hide(); m.lost:Hide()
				m:SetAlpha(1)
				local size = comboSize(banked)
				m.lost:SetText(('x%d'):format(banked))
				m.broke:SetFont(m.broke:GetFont(), size, 'THICKOUTLINE')
				m.broke:SetText(('x%d'):format(banked))
				m.brokeMove:SetOffset(LOST_X - COMBO_X - 6 - m.broke:GetStringWidth() / 2, LOST_Y - COMBO_Y)
				local shrink = LOST_SIZE / (size * BREAK_GROW)
				m.brokeShrink:SetScaleTo(shrink, shrink)
				m.broke:Show()
				m:Show()
				m.brk:Play()
			else
				f.line:SetText(why)
			end
			f.out:Play()
		end
		combo, landedAt, fed, banked, tickAt, runs = 0, nil, 0, 0, nil, {}
	end

	-- what heats with the combo, each frame it shows
	local function glow(now)
		f.combo:SetTextColor(comboColor(fed, now))
		f.degs:SetTextColor(degColor(circles, now))
		f.ghost:SetTextColor(degColor(flying, now))
	end

	-- this jump's tricks in one line under the combo, in the order first done
	local function showTricks()
		local line, run, over = '', 0, 0
		for _, trick in ipairs(chain) do
			local n = held[trick]
			local name = trick .. (n > 1 and (' x%d'):format(n) or '')
			f.trick:SetText(name)
			local width = f.trick:GetStringWidth()
			line = line .. (line ~= '' and TRICK_SEP or '') .. name
			f.trick:SetText(line)
			if (runs[trick] or 0) > run then
				run, over = runs[trick], f.trick:GetStringWidth() - width / 2
			end
		end
		f.trick:ClearAllPoints()
		f.trick:SetPoint('TOPLEFT', f, 'CENTER', RADIUS + 5, TRICK_Y - (run > 0 and BACK_H or 0))
		f.back:ClearAllPoints()
		f.back:SetPoint('TOP', f, 'CENTER', RADIUS + 5 + over, TRICK_Y)
		f.back:SetText(run > 0 and ('Back to Back%s'):format(run > 1 and (' x%d'):format(run) or '') or '')
		f.trickStamp:Stop(); f.trickStamp:Play()
		if run > 0 then f.backStamp:Stop(); f.backStamp:Play() end
	end

	local function did(trick)
		if not held[trick] then
			held[trick] = 0
			chain[#chain + 1] = trick
		end
		held[trick] = held[trick] + 1
	end

	-- did the circle that began at angle `from` spend half its time facing away?
	-- Its time starts when it last stood at `from`, so a pause before turning is not in it
	local function lookedBack(from)
		local first = 1
		for i = #spinA, 1, -1 do
			if spinA[i] == from then first = i; break end
		end
		local total, away = 0, 0
		for i = first, #spinA do
			total = total + spinT[i]
			if math.abs((spinA[i] - from) % TAU - math.pi) <= LOOK_WITHIN then away = away + spinT[i] end
		end
		return total > 0 and away >= total / 2
	end

	-- a landing: the jump scores, or misses the combo
	local function land(now)
		local deg = (circles + (high - low) * STRETCH / TAU) * 360
		air = false
		if circles > 0 then
			local t = now - takeoff
			-- whatever was still flying has arrived; this jump's degrees take off
			landedAt, fed, banked, tickAt = now, banked, combo, nil
			flying = circles
			f.ghost:SetTextScale(1)
			f.ghost:SetFont(f.combo:GetFont(), degSize(circles), 'THICKOUTLINE')
			f.ghost:SetText(('%d°'):format(circles * 360))
			f.combo:SetFont(f.combo:GetFont(), comboSize(fed + 1), 'THICKOUTLINE')
			f.combo:SetText(('x%d'):format(fed + 1))
			suckFrom = COMBO_X - 6 - f.ghost:GetStringWidth() / 2
			suckTo = COMBO_X + 6 + f.combo:GetStringWidth() / 2
			suckAt = now
			suckStep(0)
			counters()
			local rate = math.floor(deg / t + 0.5)
			drawPace(now)
			f.meter:SetText(('%d°/s  ·  %.2fs'):format(rate, t))
			if now - circleAt <= TIGHT then
				f.tight:SetText('Tight!')
				f.tightStamp:Stop(); f.tightStamp:Play()
				PlaySound(SOUNDKIT.UI_EPICLOOT_TOAST)
			end
		elseif combo > 0 then
			endCombo(('%d°'):format(math.floor(deg)))
		elseif f:IsShown() then
			f.out:Play()
		end
		local before = runs
		runs = {}
		for _, trick in ipairs(chain) do runs[trick] = (before[trick] or 0) + 1 end
	end

	-- the jump key pressed on the ground. A jump taken the frame it lands never
	-- shows IsFalling false to a frame; this press says it touched down. A jump
	-- repeated by holding the key calls nothing, and is still not seen: the game
	-- has no landing event and UnitPosition's height reads 0 (measured 2026-11-21).
	local hopped, hopLast = false, nil
	hooksecurefunc('JumpOrAscendStart', function() if not IsFalling() then hopped = true end end)

	local driver = CreateFrame('Frame')
	driver:SetScript('OnUpdate', function(_, dt)
		local now = GetTime()
		if suckAt then
			local k = (now - suckAt) / SUCK
			if k >= 1 then
				suckAt, tickAt = nil, now
				f.ghost:SetText('')
				spark(f, banked, flying, suckTo)
			else
				suckStep(k)
			end
		end
		if tickAt and now >= tickAt then
			fed = fed + 1
			counters()
			local bump = 1.6 + 0.8 * heat(fed)
			comboBump:SetScaleFrom(bump, bump)
			f.comboStep:Stop(); f.comboStep:Play()
			tickAt = fed < banked and tickAt + TICK or nil
		end
		if f:IsShown() then
			stepMotes(f, dt)
			glow(now)
		end
		if InCombatLockdown() or IsFlying() or IsSwimming() then
			if air or combo > 0 then
				air, last, circles = false, nil, 0
				endCombo('combat')
			end
			return
		end
		local falling = IsFalling()
		if falling and air and hopped then
			-- landed and left again between two frames: score the landing, and
			-- the new jump turns on from the last facing seen
			land(now)
			hopLast = last
		end
		hopped = false
		-- checked before a takeoff is read, so a jump past the window cannot save it
		if not air and landedAt and now - landedAt > COMBO_GAP then endCombo('no jump') end
		if falling then
			local facing = GetPlayerFacing()
			if not facing then air, last = false, nil; return end
			if not air then
				air, last, turned, low, high, circles = true, hopLast or facing, 0, 0, 0, 0
				lastDir = nil
				spinA, spinT, chain, held = {}, {}, {}, {}
				hopLast = nil
				-- the gap just left judges the landing before it
				if landedAt then
					local gap = now - landedAt
					for _, j in ipairs(JUDGES) do
						if gap <= j[2] then
							judge(j, gap)
							break
						end
					end
				end
				takeoff = now
				traceT, traceD = { now }, { 0 }
				return
			end
			local d = facing - last
			if d > math.pi then d = d - TAU elseif d < -math.pi then d = d + TAU end
			turned, last = turned + d, facing
			low, high = math.min(low, turned), math.max(high, turned)
			spinA[#spinA + 1], spinT[#spinT + 1] = turned, dt
			local n = #traceT
			traceT[n + 1], traceD[n + 1] = now, traceD[n] + math.abs(d) * 360 / TAU
			local full = TAU / STRETCH
			while high - low >= full do
				local dir = d > 0 and 1 or -1
				local looked = lookedBack(dir > 0 and low or high)
				if dir > 0 then low = low + full else high = high - full end
				if not lastDir then
					clearTricks(); f.tight:SetText('')
				end
				local switched = lastDir and dir ~= lastDir
				if switched then did('Switchback') end
				if looked then did('Lookback') end
				if switched or looked then showTricks() end
				lastDir, circleAt = dir, now
				spinA, spinT = {}, {}
				circles, combo = circles + 1, combo + 1
				if combo == 1 then clearMiss() end
				f.degs:SetFont(f.combo:GetFont(), degSize(circles), 'THICKOUTLINE')
				counters()
				if circles > SimpleControllerSpinDB.bestSpin then SimpleControllerSpinDB.bestSpin = circles end
				live()
				sound(circles)
				f.degsStamp:Stop()
				degsDrop:SetScaleFrom(degStamp(circles), degStamp(circles))
				f.degsStamp:Play()
			end
			local deg = (circles + (high - low) / full) * 360
			if deg >= 15 or combo > 0 then
				live()
				if combo == 0 then
					f.combo:SetText(''); f.degs:SetText(''); f.line:SetText(''); f.meter:SetText(''); f.judge:SetText(''); clearTricks(); f.tight:SetText(''); f.pace:Hide()
				end
			end
		elseif air then
			land(now)
		end
	end)
end

local login = CreateFrame('Frame')
login:RegisterEvent('PLAYER_LOGIN')
login:SetScript('OnEvent', function()
	-- the bests, kept across characters
	SimpleControllerSpinDB = SimpleControllerSpinDB or { bestSpin = 0, bestCombo = 0 }
	enable()
end)
