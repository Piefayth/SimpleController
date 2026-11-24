# Simple Controller: Bars

More action bars for Blizzard's controller interface in WoW: Forever, built on
Blizzard's own bar template so they look and fill like the game's bars.

## What it does

- **Chord bars.** A shoulder held with L2, R2 or both is a chord, and each chord
  you switch on gets a bar of eight buttons (d-pad and face buttons). There are
  six: L1 + L2, L1 + R2, L1 + L2 + R2, R1 + R2, R1 + L2 and R1 + L2 + R2. The
  buttons can be pressed in any order. While a chord is held its bar is shown
  large and the trigger's own Blizzard bar small. A shoulder held without a
  chord still does Blizzard's targeting.
- **Extra buttons.** Eight buttons that appear in Blizzard's Keybindings screen
  under "Simple Controller". Bind them to any key, L3 and paddles included. Each
  bound button shows in a row under the bottom bar, labelled with its key.
- **Filling them.** Use Blizzard's own bar editor (the controller bind screen).
  Hold a chord there and the editor works on that chord's bar: binding, picking
  up, putting down, clearing and undo all work as on Blizzard's bars. For an
  extra button, press its key while the editor is binding a spell.

## Settings

Options > AddOns > Simple Controller: Bars. Everything is saved per character,
and everything starts off, so a character with nothing set keeps Blizzard's
controls as they are.

- **Bars:** a checkbox for each chord and one for the extra buttons. A change
  waits for Blizzard's Apply button, which reloads the UI.
- **Layout:** button labels on or off, and for each bar that is on, left/right
  and down/up sliders to move it. These apply at once.

Keys for the extra buttons are set in Blizzard's Keybindings screen.

## Where the spells are kept

Each bar keeps its eight spells in real action slots, chosen once and then kept
so they never move: the first eight slots of an empty keyboard action bar (bars
2 to 8, which a controller player does not see) first, a keyboard bar holding
spells next, then the bars of controller pages 2 and 3. If a bar has to use a
controller page, the addon says so once at login, and the setting's tooltip
names the page.

## Known limits

- It does nothing while Blizzard's controller interface is off (Options >
  Controls > Controller).
- No chord can use both shoulders: holding L1 and R1 together hides both of
  Blizzard's targeting bars, so the game gives nothing to tell such chords apart.
- Switching on L1 + L2 hides Blizzard's class or pet flyout that L1 + L2 opens
  (Druid forms, Paladin auras, pet commands); R1 + R2 hides the one R1 + R2 opens
  (Warrior stances, pet spells). Whether Blizzard can bring the flyout back after
  you learn a new spell has not been measured.
- Bars are filled out of combat only.
- An extra button bound to a key with a modifier cannot be filled from the bind
  screen.
- An extra button loses to Blizzard's menus and to its priority bindings
  (shoulder + L3, centre camera).
- Labels on Blizzard's own bars are set in Edit Mode (Show Button Prompts),
  which needs a mouse.
- Not yet tested through a full fight.
