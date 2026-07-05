<p align="center">
  <img src="icon/MMI.png" alt="Mod Menu for Luanti icon" width="220">
</p>

<h1 align="center">Mod Menu for Luanti</h1>

<p align="center">
  Fullscreen in-game mod catalog and schema-based settings menu for Luanti.
</p>

<p align="center">
  <img alt="Luanti 5.10+" src="https://img.shields.io/badge/Luanti-5.10%2B-2ea44f">
  <img alt="Dev state beta" src="https://img.shields.io/badge/dev%20state-beta-f0ad4e">
  <img alt="Code license LGPL-3.0-or-later" src="https://img.shields.io/badge/code-LGPL--3.0--or--later-blue">
  <img alt="Media license CC-BY-4.0" src="https://img.shields.io/badge/media-CC--BY--4.0-blue">
  <img alt="AI assisted" src="https://img.shields.io/badge/AI-assisted-6f42c1">
</p>

Mod Menu for Luanti adds `/modmenu`: a fullscreen interface for viewing loaded
mods, searching and sorting them, inspecting metadata, and opening settings
screens registered by compatible mods.

This is a regular Lua mod. It does not patch Luanti and cannot add a stable
button to the engine ESC/pause menu. Use `/modmenu` in-game.

This project is an unofficial Luanti port inspired by TerraformersMC Mod Menu.
It is not affiliated with or endorsed by TerraformersMC.

## Table of Contents

1. [Compatibility](#compatibility)
2. [Usage](#usage)
3. [Features](#features)
4. [Settings API](#settings-api)
5. [Metadata Hints](#metadata-hints)
6. [Admin Controls](#admin-controls)
7. [Manual Test Matrix](#manual-test-matrix)
8. [ContentDB Metadata](#contentdb-metadata)
9. [Credits And Licensing](#credits-and-licensing)

## Compatibility

- Luanti 5.10 or later.
- Mineclonia (`mineclonia`).
- VoxeLibre (`mineclone2`).

The mod is designed to remain usable in other Luanti games, but the first beta
release only declares Mineclonia and VoxeLibre as supported games.

## Usage

Open the main menu:

```text
/modmenu
```

Open the admin menu:

```text
/modmenu admin
```

The regular Mod Menu view hides absolute filesystem paths. The admin view can
show paths for diagnostics.

## Features

- Fullscreen formspec layout using the client's reported maximum formspec size
  when available.
- Loaded mod list with search, A-Z/Z-A sorting, library filtering, icons,
  compatibility badges, and unsupported-mod separation.
- Details panel populated from `mod.conf`, including name, title, description,
  author, license, dependencies, optional dependencies, and Mod Menu support.
- Schema-based settings screens for compatible mods.
- Mod Menu registers its own settings screen, so it appears as a compatible mod
  and doubles as a small built-in API example.
- Tabs, collapsible sections, Reset, Reset All, bool buttons, enum dropdowns,
  string fields, numeric fields, and slider-style controls.
- Admin controls for allowing or blocking regular player access and disabling
  individual settings screens.

## Settings API

Compatible mods can expose settings without writing formspecs or parsing raw
fields. A flat `settings` list is displayed as a single `General` tab:

Mod Menu itself uses this same API for its own small settings screen. That makes
the built-in entry a practical reference for other mods.

```lua
mod_menu.register_settings("example_mod", {
	title = "Example Mod",
	icon = "example_mod_icon.png",
	settings = {
		{
			key = "example_mod.enabled",
			type = "bool",
			label = "Enabled",
			default = true,
		},
		{
			key = "example_mod.mode",
			type = "enum",
			label = "Mode",
			values = { "fancy", "fast" },
			default = "fancy",
		},
		{
			key = "example_mod.amount",
			type = "number",
			label = "Amount",
			min = 0,
			max = 10,
			default = 1,
			ui = "slider",
		},
		{
			key = "example_mod.max_items",
			type = "int",
			label = "Max items",
			min = 0,
			max = 64,
			default = 8,
			ui = "slider",
		},
	},
	on_save = function(player_name, values)
		-- Optional: reload cached config after Mod Menu saves core.settings.
	end,
})
```

For larger mods, use tabs and sections:

```lua
mod_menu.register_settings("example_mod", {
	title = "Example Mod",
	icon = "example_mod_icon.png",
	tabs = {
		{
			id = "general",
			label = "General",
			settings = {
				{
					type = "section",
					id = "rendering",
					label = "Rendering",
					default_open = true,
					children = {
						{
							key = "example_mod.enabled",
							type = "bool",
							label = "Enabled",
							default = true,
						},
						{
							key = "example_mod.scale",
							type = "number",
							label = "Scale",
							min = 0.1,
							max = 4,
							default = 1,
						},
					},
				},
			},
		},
		{
			id = "advanced",
			label = "Advanced",
			settings = {
				{
					key = "example_mod.rules",
					type = "list",
					label = "Rules",
					entry = {
						{
							key = "namespace",
							type = "string",
							label = "Namespace",
							default = "",
						},
						{
							key = "direction",
							type = "enum",
							label = "Direction",
							values = { "Up Right", "Down Left" },
							default = "Up Right",
						},
					},
					default = {},
				},
			},
		},
	},
	on_save = function(player_name, values)
		-- Optional: reload cached config after Mod Menu saves core.settings.
	end,
})
```

Supported setting types:

- `bool`
- `enum`
- `number`
- `int`
- `string`
- `list`

Optional fields include `description`, `indent`, `resettable`, `advanced`,
`ui`, and `slider_style`. `section` entries group child settings and are not
saved directly.

Use `ui = "slider"` on `number` or `int` settings with `min` and `max` to show
a compact slider with a fixed value label above the track. Older
`slider_style = "text_over_thumb"` definitions remain compatible, but Mod Menu
renders them with the safe fixed-label layout so value text cannot overlap the
thumb.

Mod Menu handles search, tabs, collapsible sections, Reset buttons, bool
buttons, enum dropdowns, numeric clamping, `core.settings` storage,
`core.settings:write()`, and save status messages.

Mods without a settings screen can still provide an icon:

```lua
mod_menu.register_icon("example_mod", "example_mod_icon.png")
```

## Metadata Hints

Mod Menu reads common `mod.conf` fields:

- `title`
- `name`
- `description`
- `author` / `authors`
- `license` / `licence`
- `depends`
- `optional_depends`

Optional Mod Menu hints:

```conf
mod_menu_icon = example_mod_icon.png
mod_menu_badges = library
```

or:

```conf
mod_menu_library = true
```

If a mod has registered settings but no icon, Mod Menu uses
`mod_menu_no_image.png`. If a mod has neither an icon nor registered settings,
it is shown below the unsupported-mods separator.

## Admin Controls

Players with the `server` privilege can open `/modmenu admin`.

The admin menu can:

- allow or block regular players from opening `/modmenu`;
- enable or disable registered settings screens per mod.

These values are stored in Luanti mod storage and survive world restarts.

## Manual Test Matrix

Recommended checks before publishing:

- Mineclonia starts with Mod Menu enabled.
- VoxeLibre starts with Mod Menu enabled.
- `/modmenu` opens and lists loaded mods.
- Search, sort, library filtering, and unsupported-mod separation work.
- Compatible mods show a Settings button.
- Settings screens support Save & Exit, Cancel, Reset, Reset All, bool
  buttons, dropdowns, numeric sliders, search, tabs, sections, and vertical
  scrollbar dragging.
- `/modmenu admin` requires the `server` privilege.
- Regular Mod Menu details do not show absolute filesystem paths.

## ContentDB Metadata

- Package type: `MOD`
- Technical name: `mod_menu`
- Title: `Mod Menu for Luanti`
- Dev state: `BETA`
- Code license: `LGPL-3.0-or-later`
- Media license: `CC-BY-4.0`
- AI disclosure: `ASSISTED`
- Supported games: `mineclonia`, `mineclone2`
- Minimum Luanti version: `5.10`

The `icon/` and `screenshots/` folders are page assets. They are excluded from
Git-based ContentDB release archives through `.gitattributes`.

## Credits And Licensing

Mod Menu for Luanti code is licensed under `LGPL-3.0-or-later`.

Project media is licensed under `CC-BY-4.0`.

The project icon was created manually by the project maintainer. Development of
this Luanti port was assisted by OpenAI Codex.

This project was inspired by TerraformersMC Mod Menu, which is licensed under
MIT. The upstream source is not bundled in this Luanti release archive. See
`NOTICE.md` and `THIRD_PARTY.md` for attribution and third-party notices.
