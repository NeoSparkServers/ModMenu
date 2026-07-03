# Publish Checklist

## Before Commit

- Run Lua parse checks for all Mod Menu Lua files.
- Run the Falling Leaves compatibility parse check if publishing the companion
  integration at the same time.
- Search the release tree for private path fragments, user profile paths, and
  absolute world/mod paths.
- Verify that the regular Mod Menu view does not show absolute mod paths.
- Verify that `/modmenu`, `/modmenu admin`, settings save/cancel/reset, and
  settings scrollbar drag work in Luanti.

## GitHub Desktop / GitHub UI

- Create or open a real Git repository rooted at this mod folder.
- Commit release-prep changes.
- Tag `v0.1.0-beta.1`.
- Create a GitHub Release using `RELEASE_NOTES.md`.

## ContentDB

- Create package type `Mod`.
- Technical name: `mod_menu`.
- Title: `Mod Menu for Luanti`.
- Maintenance state: `BETA`.
- Code license: `LGPL-3.0-or-later`.
- Media license: `CC-BY-4.0`.
- AI disclosure: `ASSISTED`.
- Upload `icon/MMI.png` as the package icon/thumbnail.
- Upload at least two screenshots. Re-capture screenshots after release-prep
  changes so public screenshots do not show local filesystem paths.
- Create the release from Git tag `v0.1.0-beta.1` or from an inspected clean
  archive.
