# Releasing

A pushed tag (`v1.0.0`) releases every addon in the repository at that version:
`.github/workflows/release.yml` runs the tests, then the BigWigsMods packager
once per addon, each making its own zip (`SimpleController_Bars-v1.0.0-forever.zip`)
and uploading it to the GitHub release and to each site that has both a token
(repository secret) and a project ID (the addon's `.toc`).

Nothing below has been done yet. In order:

## 1. License

Add a `LICENSE` file at the repository root and commit it. CurseForge asks for
a license when a project is created.

## 2. GitHub repository

1. https://github.com/new: name `simple-controller`, public, and leave "Add a
   README", ".gitignore" and "license" unticked (the repository has them).
2. In `S:\github\simple-controller`:

       git remote add origin https://github.com/<owner>/simple-controller.git
       git push -u origin main

Nothing runs on this push; the workflow runs only on tags. The GitHub release
needs no token: the workflow uses its own (`GITHUB_TOKEN`, with
`contents: write` declared in the workflow).

## 3. Optional: a first tag with no sites

    git tag v0.1.0
    git push origin v0.1.0

With no site secrets yet, this only makes the GitHub release with both zips
(Actions tab > Release, then the Releases page). Use it to check the zips, and
for WoWInterface's first upload (step 6).

## 4. CurseForge (one project per addon)

1. https://authors.curseforge.com > Create Project > World of Warcraft >
   Addons. Name "Simple Controller: Bars", summary, category, license. Repeat
   for "Simple Controller: Spin". New projects wait for moderation.
2. The **Project ID** is on each project's page (the "About Project" box) and in
   the authors console. Put each into its addon's `.toc`, replacing
   `FILL_ME_CURSEFORGE_PROJECT_ID`.
3. API token: https://authors.curseforge.com/#/settings/api-tokens > Generate
   Token. Keep it for step 7 as `CF_API_TOKEN`.

## 5. Wago Addons (one project per addon)

1. https://addons.wago.io, sign in, Developer dashboard > Create Project, for
   each addon.
2. The **Project ID** (a short string such as `aBcD1234`) is in the project's
   settings. Put each into its `.toc`, replacing `FILL_ME_WAGO_PROJECT_ID`.
3. API key: https://addons.wago.io/account/apikeys. Keep it as `WAGO_API_TOKEN`.

## 6. WoWInterface (one entry per addon)

1. An entry is created by uploading a first file: sign in at
   https://www.wowinterface.com, Downloads > Upload, and upload each zip from
   step 3's GitHub release, choosing the "Forever" game version.
2. The **addon ID** is the number in the entry's address,
   `https://www.wowinterface.com/downloads/info<ID>-<Name>`. Put each into its
   `.toc`, replacing `FILL_ME_WOWINTERFACE_ADDON_ID`.
3. API token: https://www.wowinterface.com/downloads/filecpl.php?action=apitokens.
   Keep it as `WOWI_API_TOKEN`.

The packager (v2.7.0) does not upload Forever builds to WoWInterface yet: it
prints "No WoWInterface game type match for forever" and skips it, although
WoWInterface's own list has "WoW Forever" (1.60.1, interface 16001). Until the
packager adds it, each release is uploaded there by hand from the GitHub
release. The secret can be added anyway; it starts working when the packager
does.

## 7. Secrets

GitHub repository > Settings > Secrets and variables > Actions > New repository
secret, three times: `CF_API_TOKEN`, `WAGO_API_TOKEN`, `WOWI_API_TOKEN`. A
secret left out skips that site.

## 8. Commit the IDs and release

    git commit -am "Site project IDs"
    git push
    git tag v1.0.0
    git push origin v1.0.0

Watch Actions > Release. In each packaging job's log, check the line
`Uploading ... (<game version> release)` for CurseForge and Wago: it should
name `1.60.1`. If it says "No CurseForge game version match", the site has no
Forever version for that interface number yet (see below).

## Checking Forever's game version on CurseForge

The packager files Forever builds under CurseForge's game version type 88568,
named by version (`1.60.1` for interface 16001), falling back to the highest
Forever version CurseForge lists. Whether CurseForge lists `1.60.1` there was
not checked (its list needs a token). With the token:

    curl -s -H "x-api-token: <CF_API_TOKEN>" https://wow.curseforge.com/api/game/wow/versions | jq "map(select(.gameVersionTypeID == 88568))"
