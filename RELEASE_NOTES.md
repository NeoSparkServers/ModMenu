# Release Notes

## v0.1.0-beta.1

Initial Luanti port of Mod Menu.

- Added `/modmenu` fullscreen UI for viewing loaded mods.
- Added search, A-Z/Z-A sorting, library filtering, mod icons, badges, and
  details from `mod.conf`.
- Added schema-based settings API through `mod_menu.register_settings`.
- Added tabs, sections, Reset, Reset All, bool buttons, enum dropdowns,
  numeric fields, and slider-style controls.
- Added `/modmenu admin` for players with the `server` privilege.
- Added support targets for Luanti 5.10+, Mineclonia, and VoxeLibre
  (`mineclone2`).

Known limitation:

- Stock Luanti Lua mods cannot add a stable button to the engine ESC/pause
  menu. Use `/modmenu`.
