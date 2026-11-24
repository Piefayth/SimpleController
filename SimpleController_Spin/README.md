# Simple Controller: Spin

Turning in the air is scored, like a dance game. Jump, turn your character
around while airborne out of combat, and the addon counts the circles, keeps a
combo going from jump to jump, names your tricks and judges each landing.

## What it does

- Every full circle you turn while airborne stamps the jump's degrees beside
  your character. Landing adds them to a combo.
- The combo goes on while each next jump is taken within half a second of
  landing and turns at least one circle. Otherwise it is a Miss.
- Each takeoff judges the time you spent on the ground, from Marvelous through
  Perfect, Great, Good, OK and Bad.
- Tricks: a **Switchback** is a circle the opposite way to the one before it in
  the same jump; a **Lookback** is a circle that spends at least half its time
  facing away from where it began; **Back to Back** is the same trick on
  consecutive jumps; **Tight** is a last circle closed just before landing.
- Each landing shows the jump's degrees per second and its air time, and draws
  how even the turn was.
- Your best spin and best combo are kept, shared by all your characters.

## Settings

Options > AddOns > Simple Controller: Spin. Changes apply at once and are kept
across characters.

- **Sounds**: a chime for each circle, and for a Tight one. Off by default.
- **Left / right** and **Down / up**: move the readouts from around your
  character. A sample shows while you move them.
- **Size**: how big the readouts are.

To turn Spin off, switch it off in the AddOns list like any addon.

## Known limits

- Scores only out of combat, and not while flying or swimming; entering any of
  these ends the combo.
- Nothing scores in instances: the game does not give the player's facing there.
- Turning on the ground scores nothing.

## Install

1. Download `SimpleController_Spin-<version>-forever.zip` from the
   [Releases page](https://github.com/piefayth/SimpleController/releases).
2. Extract it into `World of Warcraft\_forever_\Interface\AddOns`. The folder
   must end up as `Interface\AddOns\SimpleController_Spin` (with
   `SimpleController_Spin.toc` directly inside it, not in a second folder of
   the same name).
3. Restart the game. A new addon folder is only seen after a full restart, not
   a `/reload`.

- CurseForge: coming soon.
- Wago Addons: coming soon.
