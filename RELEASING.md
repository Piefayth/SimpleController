# Releasing

A pushed tag naming an addon releases that addon: `spin-v1.0.1` Spin,
`bars-v0.1.0` Bars, `wheels-v0.1.0` Wheels (Bars' and Wheels' zips carry the core,
`SimpleController`, beside them). A tag with `alpha` or `beta` in it is a
prerelease. `.github/workflows/release.yml` runs the BigWigsMods packager for the
named addon. It makes the zip (`SimpleController_Spin-spin-v1.0.1-forever.zip`),
attaches it to a GitHub Release
named after the tag, and uploads it to each addon site that has both a token
(a repository secret) and a project ID (in the addon's `.toc`).

The GitHub Release needs nothing from you: the workflow uses its own
`GITHUB_TOKEN` (`permissions: contents: write`). A site whose secret is not set
is skipped without failing the job (the packager's upload functions return
early on an empty token), so a tag pushed before any site project exists still
makes the GitHub Release.

Packager documentation: https://github.com/BigWigsMods/packager#readme

Steps not yet done, in order:

## 1. License

MIT (`LICENSE`). CurseForge and Wago ask for it when a project is created.

## 2. Optional: a first tag with no sites

    git tag bars-v0.1.0-beta
    git push origin bars-v0.1.0-beta

With no site secrets, this only makes the GitHub Release with the zip (watch
GitHub > Actions > Release, then the Releases page). Use it to check the zip,
and as the file for WoWInterface's first upload (step 5).

## 3. CurseForge

1. Create an account at https://www.curseforge.com (sign in also opens the
   authors console, https://authors.curseforge.com).
2. In the authors console, create a project: game **World of Warcraft**, type
   **Addons**. Name it "Simple Controller: Spin", write a short summary (the
   README's first paragraph will do), pick a main category (Minigames fits;
   Miscellaneous otherwise) and the license from step 1. New projects wait for
   CurseForge's moderation before they are public. The exact form changes from
   time to time; CurseForge's author guides are at
   https://support.curseforge.com (the authors' section).
3. The **Project ID** is a number shown on the project's page (the "About
   Project" box) and in the authors console. Put it in
   `SimpleController_Spin/SimpleController_Spin.toc`, replacing
   `FILL_ME_CURSEFORGE_PROJECT_ID`.
4. API token: in the authors console, account settings > API tokens (at the
   time of writing https://authors.curseforge.com/#/api-tokens; if that has
   moved, see https://support.curseforge.com/en/support/solutions/articles/9000197321-curseforge-upload-api).
   Generate one and keep it for step 6 as `CF_API_TOKEN`.

The packager fills the addon folder name from the zip, so there is nothing to
set for it on the site; the zip's folder is `SimpleController_Spin`.

## 4. Wago Addons

1. Sign in at https://addons.wago.io (it uses a Wago account; sign-in with
   Discord, GitHub and others is offered).
2. Developer access: Wago Addons asks authors to apply before they can create
   projects. Look for the developer or "Create Project" entry from your
   account menu, or start at https://addons.wago.io/developers and
   https://docs.wago.io. The exact path is not verified here.
3. Create the project "Simple Controller: Spin" for World of Warcraft, with
   Forever as a supported game version if offered.
4. The **Project ID** is a short string (such as `aBcD1234`) shown in the
   project's settings or developer dashboard. Put it in the `.toc`, replacing
   `FILL_ME_WAGO_PROJECT_ID`.
5. API key: https://addons.wago.io/account/apikeys. Keep it for step 6 as
   `WAGO_API_TOKEN`.

## 5. WoWInterface (manual uploads)

The packager (v2.7.0) does not upload Forever builds to WoWInterface: it prints
"No WoWInterface game type match for forever" and skips it, although
WoWInterface lists "WoW Forever". Until the packager supports it, each release
is uploaded there by hand:

1. Create an account at https://www.wowinterface.com.
2. Download the zip from the GitHub Release (step 2, or any later tag).
3. Sign in, open Downloads > Upload (the author control panel,
   https://www.wowinterface.com/downloads/filecpl.php), fill in the name, a
   description, the category, and choose the "WoW Forever" game version, then
   upload the zip. The first upload creates the entry; later versions are
   uploaded from the same control panel as updates to it.
4. Optional, for when the packager supports Forever: the **addon ID** is the
   number in the entry's address, `https://www.wowinterface.com/downloads/info<ID>-<Name>`.
   Put it in the `.toc`, replacing `FILL_ME_WOWINTERFACE_ADDON_ID`; the API
   token is at https://www.wowinterface.com/downloads/filecpl.php?action=apitokens,
   as `WOWI_API_TOKEN`.

## 6. Repository secrets

https://github.com/piefayth/SimpleController > Settings > Secrets and
variables > Actions > New repository secret, once per site:

| Secret | Value |
|---|---|
| `CF_API_TOKEN` | the CurseForge API token (step 3) |
| `WAGO_API_TOKEN` | the Wago API key (step 4) |
| `WOWI_API_TOKEN` | optional, the WoWInterface token (step 5) |

A secret left out skips that site. Add a site's secret only after its project
ID is in the `.toc`: with a token set and the `FILL_ME_...` placeholder still
there, the upload is attempted and fails (a CurseForge failure stops the other
uploads).

## 7. Commit the IDs and release

    git commit -am "Site project IDs"
    git push
    git tag spin-v1.0.1
    git push origin spin-v1.0.1

The tag starts GitHub > Actions > Release. When it finishes, the Releases page
has `spin-v1.0.1` with the zip and a changelog made from the commits since the last
tag, and each site with a secret has the new file. In the job's log, check the
CurseForge and Wago lines `Uploading ... (<game version> release)`: they should
name `1.60.1`. If one says "No CurseForge game version match", the site has no
Forever version for that interface number yet (below).

### Forever's game version on CurseForge

The packager files Forever builds under CurseForge's game version type 88568,
named by version (`1.60.1` for interface 16001), falling back to the highest
Forever version CurseForge lists. Whether CurseForge lists `1.60.1` was not
checked (its list needs a token). With the token:

    curl -s -H "x-api-token: <CF_API_TOKEN>" https://wow.curseforge.com/api/game/wow/versions | jq "map(select(.gameVersionTypeID == 88568))"

## Adding another addon

The repository holds one addon per top-level folder. To add one (Bars, Wheels):

1. Copy the addon's folder in as `SimpleController_<Name>/`, its `.toc` with
   `## Version: @project-version@` and the three `X-...-ID` placeholder lines,
   and a `README.md` for players.
2. Give it a `.pkgmeta` like Spin's (`package-as`, `move-folders` and `ignore`
   with its own name), its `ignore` listing every other addon's folder.
3. Add the new folder to every other addon's `.pkgmeta` `ignore`.
4. Add its folder name to the workflow's `matrix`, and with two or more addons
   set `max-parallel: 1` under `strategy`, since every zip goes to the same
   GitHub Release. If it has tests, add a test job that `package` needs.
5. Create its own projects on the sites (steps 3 to 5) and put their IDs in its
   `.toc`; the secrets are shared.
6. Add it to the root `README.md`.
