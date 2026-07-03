# Mod Menu for Luanti

Luanti port of the Mod Menu idea: a small in-game catalog for loaded mods.
This is an unofficial port inspired by TerraformersMC Mod Menu and is not
affiliated with or endorsed by TerraformersMC.

## Usage

Run:

```text
/modmenu
```

The menu shows loaded mods, search, sort order, library visibility, and details read from each mod's `mod.conf`.
Absolute filesystem paths are hidden from the regular Mod Menu view and only shown in the admin screen.

The formspec uses the client's reported `max_formspec_size` when available, so it scales close to fullscreen instead of staying as a small centered panel.

This v1 is a regular Lua mod. It does not patch Luanti, so it cannot add a real button to the engine ESC menu. A future engine-side integration could add that, but this port keeps the first release stable and portable.

## Settings API

Other mods can expose settings without writing formspecs or parsing raw fields. A flat `settings` list still works and is shown as one `General` tab:

```lua
mod_menu.register_settings("example_mod", {
	title = "Example Mod",
	icon = "example_mod_icon.png",
	settings = {
		{ key = "example_mod.enabled", type = "bool", label = "Enabled", default = true },
		{ key = "example_mod.mode", type = "enum", label = "Mode", values = { "fancy", "fast" }, default = "fancy" },
		{ key = "example_mod.amount", type = "number", label = "Amount", min = 0, max = 10, default = 1, ui = "slider" },
		{ key = "example_mod.max_items", type = "int", label = "Max items", min = 0, max = 64, default = 8, ui = "slider" },
	},
	on_save = function(player_name, values)
		-- Optional: reload cached config immediately after Mod Menu saves core.settings.
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
						{ key = "example_mod.enabled", type = "bool", label = "Enabled", default = true },
						{ key = "example_mod.scale", type = "number", label = "Scale", min = 0.1, max = 4, default = 1 },
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
						{ key = "namespace", type = "string", label = "Namespace", default = "" },
						{ key = "direction", type = "enum", label = "Direction", values = { "Up Right", "Down Left" }, default = "Up Right" },
					},
					default = {},
				},
			},
		},
	},
	on_save = function(player_name, values)
		-- Optional: reload cached config immediately after Mod Menu saves core.settings.
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

Settings may also use optional fields such as `description`, `indent`, `resettable`, `advanced`, `ui`, and `slider_style`. `section` entries are display groups with `children`; they are not saved directly.

Use `ui = "slider"` on `number` or `int` settings with `min` and `max` to show a compact slider with a fixed value label above the track. `fixed_label` is the default slider style. Older `slider_style = "text_over_thumb"` definitions remain compatible, but Mod Menu renders them with the safe fixed-label layout so the value text cannot overlap the thumb. The optional `slider_style = "stacked"` is also rendered with non-overlapping label and track rows.

Mod Menu builds the fullscreen formspec, handles search, tabs, collapsible sections, Reset buttons, bool buttons, enum dropdowns, numeric fields plus slider-style scrollbars, clamps numeric values, stores values through `core.settings`, calls `core.settings:write()`, and reports whether saving succeeded. Bool settings are handled internally, so mods do not need to interpret Luanti checkbox fields.

Mods without a config screen can still provide an icon:

```lua
mod_menu.register_icon("example_mod", "example_mod_icon.png")
```

## Metadata

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

If a mod has neither an icon nor registered settings, Mod Menu shows it below the unsupported-mods separator. If a mod has registered settings but no icon, Mod Menu uses `mod_menu_no_image.png`.

## Admin

Players with the `server` privilege can open:

```text
/modmenu admin
```

The admin screen can:

- allow or block regular players from opening `/modmenu`
- enable or disable registered settings screens per mod

These values are stored in Luanti mod storage and survive world restarts.

## Compatibility

Target baseline: Luanti `5.10+`.

The mod is intended to work with Mineclonia and VoxeLibre (`mineclone2`) while remaining usable in other games.

## License

This Luanti port's Lua code and documentation are licensed as `LGPL-3.0-or-later`.
Project-owned media is licensed as `CC-BY-4.0`.

The original Minecraft/Fabric Mod Menu source is MIT licensed. See `NOTICE.md`
and `THIRD_PARTY.md` for attribution.
