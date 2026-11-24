# Simple Controller: Spin

Turning in the air is scored, like a dance game.

## What it does

- Every full circle you turn while airborne stamps the jump's degrees beside
  your character, with a chime. Landing adds them to a combo.
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
- Your best spin and best combo are saved, shared by all your characters.

## Settings

None. Disable the addon in the AddOns list to turn it off.

## Known limits

- Scores only out of combat, and not while flying or swimming; entering any of
  these ends the combo.
- Nothing scores in instances: the game does not give the player's facing there.
- Turning on the ground scores nothing.
