local core = core or minetest
local modname = "mod_menu"
local modpath = core.get_modpath(modname)

mod_menu = rawget(_G, "mod_menu") or {}
mod_menu.modname = modname
mod_menu.modpath = modpath
local translator = core.get_translator and core.get_translator(modname) or nil
local function placeholder_args(text)
	local max_index = 0
	for index in tostring(text or ""):gmatch("@(%d+)") do
		max_index = math.max(max_index, tonumber(index) or 0)
	end

	local args = {}
	for index = 1, max_index do
		args[index] = "@" .. index
	end
	return args
end

mod_menu.S = function(text, ...)
	local args = { ... }
	local translated
	if translator then
		translated = translator(tostring(text or ""), unpack(placeholder_args(text)))
	else
		translated = tostring(text or "")
	end
	return (translated:gsub("@(%d+)", function(index)
		return tostring(args[tonumber(index)] or "")
	end))
end

dofile(modpath .. "/config.lua")
dofile(modpath .. "/metadata.lua")
dofile(modpath .. "/api.lua")

core.register_privilege("modmenu_admin", {
	description = mod_menu.S("Can administer Mod Menu"),
	give_to_singleplayer = true,
})

mod_menu.register_settings(modname, {
	title = mod_menu.S("Mod Menu"),
	icon = "mod_menu_icon.png",
	settings = {
		{
			key = mod_menu.CANCEL_DETAIL_EDIT_ON_CLOSE_KEY,
			type = "bool",
			label = mod_menu.S("Cancel text edit on close"),
			description = mod_menu.S("Discard unsaved custom detail text edits when the main Mod Menu window is closed."),
			default = true,
		},
	},
})

dofile(modpath .. "/formspec.lua")

core.register_chatcommand("modmenu", {
	description = mod_menu.S("Open Mod Menu"),
	params = "[admin]",
	func = function(name, param)
		if not core.get_player_by_name(name) then
			return false, mod_menu.S("This command can only be used by an online player.")
		end

		param = tostring(param or ""):match("^%s*(.-)%s*$")
		if param == "admin" then
			if not mod_menu.can_admin(name) then
				return false, mod_menu.S("You need the modmenu_admin privilege to open Mod Menu admin.")
			end

			mod_menu.show_admin(name)
			return true
		end

		if not mod_menu.can_open(name) then
			return false, mod_menu.S("Mod Menu is currently disabled by an administrator.")
		end

		mod_menu.show(name)
		return true
	end,
})

core.register_on_player_receive_fields(function(player, formname, fields)
	return mod_menu.handle_fields(player, formname, fields)
end)
