# Simple Controller

Small controller addons for World of Warcraft: Forever. Each does one thing,
stands alone, and is built on Blizzard's own frames: settings on one page in
Options > AddOns, keys in Blizzard's Keybindings screen, bars filled with
Blizzard's own editor.

| Addon | What it does |
|---|---|
| [SimpleController_Bars](SimpleController_Bars/README.md) | Chord bars (a shoulder with L2, R2 or both) and extra buttons bound to any key |
| [SimpleController_Spin](SimpleController_Spin/README.md) | Turning in the air, scored |

Each addon is released as its own zip and listed separately on the addon sites.

## Layout

- `SimpleController_<Name>/`: one addon, exactly as it is installed, with its
  `.pkgmeta` for the packager. A new addon (Wheels is next) is a new folder
  like these, its name added to the other `.pkgmeta` files' `ignore` and to the
  workflow's `matrix`.
- `tests/`: `python tests/test_bars_model.py` (needs `pip install lupa`) checks
  Bars' rules in `Model.lua` over every chord, hold and slot choice.
- `.github/workflows/release.yml`: on a pushed tag, the tests, then each addon
  packaged and uploaded. See `RELEASING.md`.

To try an addon, copy its folder into
`World of Warcraft\_forever_\Interface\AddOns\`.
