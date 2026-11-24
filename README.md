# Simple Controller

Simple Controller is a set of small controller addons for World of Warcraft:
Forever, each doing one thing and built on Blizzard's own frames and settings,
so they feel like part of the game.

## Simple Controller: Spin

Turning in the air is scored, like a dance game. Jump, turn your character
around while airborne out of combat, and Spin counts the circles, keeps a combo
going from jump to jump, names your tricks (Switchback, Lookback, Back to Back,
Tight) and judges each landing from Marvelous to Bad. Your best spin and best
combo are kept across characters.

Its settings are in Options > AddOns > Simple Controller: Spin: Sounds (off by
default), Left / right and Down / up to move the readouts, and Size. To turn it
off, switch it off in the AddOns list like any addon.

More detail: [SimpleController_Spin/README.md](SimpleController_Spin/README.md).

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

---

## For developers

### Layout

- `SimpleController_<Name>/`: one addon, exactly as it is installed, with its
  `.pkgmeta` for the packager and its own `README.md`. Each addon is released
  as its own zip and listed separately on the addon sites.
- `.github/workflows/release.yml`: on a pushed tag, each addon in its `matrix`
  is packaged by the BigWigsMods packager and attached to a GitHub Release, and
  uploaded to each addon site that has a token and a project ID.

To try an addon from the source, copy its folder into
`World of Warcraft\_forever_\Interface\AddOns\` and restart the game.

### Tests

Spin has no automated tests. A tag runs only the packaging.

### Releasing

See [RELEASING.md](RELEASING.md): the site accounts and projects, the tokens,
tagging a release, and how another addon is added to the repository.
