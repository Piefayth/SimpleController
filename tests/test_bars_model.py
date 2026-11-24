"""Tests for Simple Controller: Bars' rules (SimpleController_Bars/Model.lua).

    python tests/test_bars_model.py [random runs] [seed]   (needs `pip install lupa`)

The model runs under Lua 5.1 (LuaJIT, as the game's). The game is simulated by
what was measured in the game: a shoulder held alone shows
its targeting bar; both shoulders down hide both, and a shoulder's bar stays
hidden after the other is let go until it is pressed again; L2 and R2 light
Blizzard's bottom bar together, L2 alone the left bar, R2 alone the right bar
(the stance bar in a form).

  1. every press reaches the right chord: for every set of chords switched on,
     every set of shoulders and triggers held, in every order and with letting
     go, in and out of a form, each of the eight keys' secure snippet (run
     against mock frames) casts the chord whose buttons are exactly those held,
     or passes the press to Blizzard's targeting bar when there is none; its
     release lets go of the look it pressed. The model's ChordFor agrees.
  2. a macro in a chord's slot runs as the chord's macro text.
  2d. a trade leaves out the slot the editor holds a spell from, and only that.
  2b. in the bind screen, where the buttons down are read, every set held in every
     order reaches the chord whose buttons are exactly those, or none.
  3. the layout never gives two rows the same slots, and never moves a row's
     spells: random saved states (rows on and off, slots already kept, some
     stale or doubled) and random bars already holding spells. A row keeps a
     valid slot it was given; a row without one takes the least bad free
     source (empty keyboard bar, keyboard bar with spells, empty controller
     page bar, page bar with spells) and is named as paged exactly when it got
     a page; laying out again changes nothing. No source overlaps another, the
     main bar (1-12) or Blizzard's form and vehicle pages (73-144).
"""
import itertools
import os
import random
import sys

from lupa import luajit21

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = os.path.join(HERE, "..", "SimpleController_Bars", "Model.lua")
SHOULDER_KEYS = {"L": "PADLSHOULDER", "R": "PADRSHOULDER"}
TARGETING = {"L": "friendlyTargetingBar", "R": "hostileTargetingBar"}
BUTTONS = ["L1", "R1", "L2", "R2"]
KEY_OF = {"L1": "PADLSHOULDER", "R1": "PADRSHOULDER", "L2": "PADLTRIGGER", "R2": "PADRTRIGGER"}

lua = luajit21.LuaRuntime(unpack_returned_tuples=True)
CB = lua.table()
lua.execute("GetBindingText = function(k) return k end")
lua.globals().loadfile(MODEL)("SimpleController_Bars", CB)
ACTIVE = CB.ACTIVE_LEVEL


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


CHORDS = lua_list(CB.CHORDS)


class Game:
    """What the game shows, by the measured rules."""

    def __init__(self, in_form):
        self.down = set()
        self.stuck = set()  # shoulders whose bar stays hidden until pressed again
        self.in_form = in_form

    def press(self, b):
        self.down.add(b)
        if b in ("L1", "R1") and {"L1", "R1"} <= self.down:
            self.stuck |= {"L", "R"}

    def release(self, b):
        self.down.discard(b)
        if b in ("L1", "R1"):
            self.stuck.discard(b[0])

    def shown(self, s):
        other = "R1" if s == "L" else "L1"
        return s + "1" in self.down and other not in self.down and s not in self.stuck

    def lit(self):
        l2, r2 = "L2" in self.down, "R2" in self.down
        if l2 and r2:
            return "bottomBar"
        if l2:
            return "leftBar"
        if r2:
            return "stanceBar" if self.in_form else "rightBar"
        return None

    def level(self, bar):
        return ACTIVE if bar == self.lit() else 4


# The secure snippet run against mock frames, all Lua: bars report their level,
# watches log what they are asked to run, and the button keeps its attributes.
HARNESS = lua.execute("""
return function(src, levels, attrs, refs, macroSlots)
    local log = {}
    local made = {}
    for k, r in pairs(refs) do
        if r.bar then
            made[k] = { GetFrameLevel = function() return levels[r.bar] end }
        else
            made[k] = { RunAttribute = function(_, attr, i) log[#log + 1] = r.watch .. ":" .. attr .. ":" .. i end }
        end
    end
    local me = {
        GetAttribute = function(_, k) return attrs[k] end,
        SetAttribute = function(_, k, v) attrs[k] = v end,
        GetFrameRef = function(_, k) return made[k] end,
    }
    GetActionInfo = function(slot) return macroSlots[slot] and "macro" or "spell" end
    local fn = loadstring("return function(self, button, down) " .. src .. " end")()
    return function(down)
        for i = #log, 1, -1 do log[i] = nil end
        return fn(me, "LeftButton", down), log
    end
end
""")
BARS = ["leftBar", "rightBar", "stanceBar", "bottomBar"]


def build_fire(chords, i, game, slots, macros):
    """One shoulder's key-i button, its attributes and refs as Bars.lua sets them:
    returns click(down) -> (result, log) and its attribute table."""
    attrs, refs = {"cb-pass": "pass"}, {}
    for n, chord in enumerate(chords, 1):
        lit = lua_list(chord.lit)
        refs["a%d" % n] = lua.table_from({"bar": lit[0]})
        if len(lit) > 1:
            refs["b%d" % n] = lua.table_from({"bar": lit[1]})
        refs["watch%d" % n] = lua.table_from({"watch": chord.setting})
        attrs["cb-chord%d" % n] = "chord:" + chord.setting
        attrs["cb-slot%d" % n] = slots[chord.setting] + i - 1
        if macros.get(chord.setting):
            attrs["cb-macro%d" % n] = "macro:" + chord.setting
    attrs = lua.table_from(attrs)
    levels = lua.table_from({bar: game.level(bar) for bar in BARS})
    macro_slots = lua.table_from({slot: True for slot in macros.get("slots", ())})
    click = HARNESS(CB.FireSnippet(i, len(chords)), levels, attrs, lua.table_from(refs), macro_slots)

    def run(down):
        result, log = click(down)
        return result, lua_list(log)
    return run, attrs


def expect(on, game, shoulder):
    if not game.shown(shoulder):
        return None
    held = frozenset(KEY_OF[b] for b in game.down)
    for chord in on:
        if chord.shoulder == shoulder and frozenset(lua_list(chord["keys"])) == held:
            return chord.setting
    return None


def check_press(on, game, macros, slots, failures, what):
    for shoulder in ("L", "R"):
        chords = [c for c in on if c.shoulder == shoulder]
        if not chords:
            continue
        want = expect(on, game, shoulder)
        found = CB.ChordFor(lua.table_from(chords), game.shown(shoulder), lambda bar: game.level(bar))
        got = found[0].setting if found else None
        if got != want:
            failures.append(f"{what}: ChordFor {shoulder} gave {got}, wanted {want}")
        if not game.shown(shoulder):
            continue  # the shoulder's keys are bound only while its bar is shown
        for i in range(1, 9):
            click, attrs = build_fire(chords, i, game, slots, macros)
            _, log = click(True)
            text = attrs["macrotext"]
            if want is None:
                ok = text == "pass" and not log
            else:
                kind = "macro:" if macros.get(want) else "chord:"
                ok = text == kind + want and log == [f"{want}:cb-press:{i}"]
            if not ok:
                failures.append(f"{what}: key {i} on {shoulder} gave {text} {log}, wanted {want}")
                return
            result, log = click(False)
            if result is not False:
                failures.append(f"{what}: release went on to a click")
            if want is not None and log != [f"{want}:cb-release:{i}"]:
                failures.append(f"{what}: release of key {i} gave {log}")
            if attrs["cb-held"] is not None:
                failures.append(f"{what}: held stayed set after release")


def presses(rng, runs):
    failures = []
    slots = {c.setting: 1000 + 10 * n for n, c in enumerate(CHORDS)}
    for mask in range(1 << len(CHORDS)):
        on = [c for n, c in enumerate(CHORDS) if mask >> n & 1]
        for in_form in (False, True):
            for k in range(1, 5):
                for order in itertools.permutations(BUTTONS, k):
                    game = Game(in_form)
                    for b in order:
                        game.press(b)
                    check_press(on, game, {}, slots, failures, f"on={[c.setting for c in on]} form={in_form} pressed {order}")
                    if failures:
                        return failures
    # letting go: random walks of presses and releases
    for run in range(runs):
        on = [c for c in CHORDS if rng.random() < 0.5]
        game = Game(rng.random() < 0.5)
        steps = []
        for _ in range(12):
            b = rng.choice(BUTTONS)
            (game.release if b in game.down else game.press)(b)
            steps.append(("-" if b not in game.down else "+") + b)
            check_press(on, game, {}, slots, failures, f"run {run} {steps}")
            if failures:
                return failures
    return failures


def macros_run():
    failures = []
    slots = {c.setting: 1000 + 10 * n for n, c in enumerate(CHORDS)}
    game = Game(False)
    for b in ("L1", "R2"):
        game.press(b)
    left_cross = [c for c in CHORDS if c.setting == "leftCross"][0]
    macros = {"leftCross": True, "slots": {slots["leftCross"] + 2}}
    click, attrs = build_fire([left_cross], 3, game, slots, macros)
    click(True)
    if attrs["macrotext"] != "macro:leftCross":
        failures.append(f"a macro slot cast {attrs['macrotext']}")
    return failures


def bind_screen():
    failures = []
    for mask in range(1 << len(CHORDS)):
        on = [c for n, c in enumerate(CHORDS) if mask >> n & 1]
        for k in range(1, 5):
            for held in itertools.combinations(BUTTONS, k):
                down = {KEY_OF[b] for b in held}
                found = CB.ChordForKeys(lua.table_from(on), lambda key: key in down)
                got = found.setting if found else None
                want = None
                for chord in on:
                    if frozenset(lua_list(chord["keys"])) == frozenset(down):
                        want = chord.setting
                if got != want:
                    failures.append(f"bind screen: on={[c.setting for c in on]} held {held} gave {got}, wanted {want}")
                    return failures
    return failures


def trade_slots():
    """A trade leaves out the slot the editor holds a spell from, and only that."""
    failures = []
    theirs = list(range(201, 209))
    for mode in ("BIND_ACTION", "SELECT_ACTION_TO_PICKUP", "PLACE_OR_CLEAR_HELD_ACTION"):
        for pickup in [None, 61] + theirs:
            got = lua_list(CB.TradeSlots(lua.table_from(theirs), mode, pickup))
            want = [s for s in theirs if not (mode == "PLACE_OR_CLEAR_HELD_ACTION" and s == pickup)]
            if got != want:
                failures.append(f"trade slots: mode {mode} pickup {pickup} gave {got}")
    return failures


def layouts(rng, runs):
    failures = []
    sources = lua_list(CB.SOURCES)
    ids = [src.id for src in sources]
    ranges = [(src.first, src.first + 7) for src in sources]
    for (a0, a1), (b0, b1) in itertools.combinations(ranges, 2):
        if a0 <= b1 and b0 <= a1:
            failures.append(f"sources overlap: {a0}-{a1} and {b0}-{b1}")
    for a0, a1 in ranges:
        if a0 <= 12 or (a0 <= 144 and a1 >= 73):
            failures.append(f"source {a0}-{a1} is on the main bar or a form/vehicle page")
    rows = lua_list(CB.Rows())
    for run in range(runs):
        full = {i for i in ids if rng.random() < 0.4}
        db = lua.table()
        for row in rows:
            if rng.random() < 0.7:
                db[row.setting] = rng.random() < 0.5
            if rng.random() < 0.4:
                db[CB.SlotsKey(row)] = rng.choice(ids + ["nonsense"])
        before = {row.setting: db[CB.SlotsKey(row)] for row in rows}
        # what a correct layout keeps: valid, first claim wins, in row order
        kept, taken = {}, set()
        for row in rows:
            want = before[row.setting]
            if want in ids and want not in taken:
                kept[row.setting] = want
                taken.add(want)
        placed, paged = CB.Layout(db, lambda src: src.id not in full)
        paged = {r.setting for r in lua_list(paged)}
        rank = lambda i: (2 if i.startswith("page") else 0) + (1 if i in full else 0)
        free = [i for i in ids if i not in taken]
        seen = set()
        for row in rows:
            got = db[CB.SlotsKey(row)]
            if got is not None:
                if got in seen:
                    failures.append(f"run {run}: {got} given twice")
                seen.add(got)
            if not CB.Enabled(db, row):
                if placed[row] is not None:
                    failures.append(f"run {run}: {row.setting} is off but placed")
                if got != kept.get(row.setting):
                    failures.append(f"run {run}: {row.setting} is off and its slots changed to {got}")
                continue
            if placed[row] is None or placed[row].id != got:
                failures.append(f"run {run}: {row.setting} placed {placed[row]} but kept {got}")
            if row.setting in kept:
                if got != kept[row.setting]:
                    failures.append(f"run {run}: {row.setting} moved from {kept[row.setting]} to {got}")
                continue
            best = min(rank(i) for i in free)
            if rank(got) != best:
                failures.append(f"run {run}: {row.setting} got {got} (rank {rank(got)}), a rank {best} source was free")
            if (row.setting in paged) != got.startswith("page"):
                failures.append(f"run {run}: {row.setting} on {got}, said paged: {row.setting in paged}")
            free.remove(got)
        again = {row.setting: db[CB.SlotsKey(row)] for row in rows}
        _, paged2 = CB.Layout(db, lambda src: src.id not in full)
        if again != {row.setting: db[CB.SlotsKey(row)] for row in rows} or lua_list(paged2):
            failures.append(f"run {run}: laying out again changed something")
        if failures:
            return failures
    return failures


def main():
    runs = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    rng = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
    results = {"presses": presses(rng, runs), "macros": macros_run(), "bind screen": bind_screen(), "trade slots": trade_slots(), "layouts": layouts(rng, runs)}
    bad = False
    for name, failures in results.items():
        print(f"{name}: {'ok' if not failures else 'FAILED'}")
        for f in failures[:5]:
            print("   ", f)
        bad = bad or bool(failures)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
