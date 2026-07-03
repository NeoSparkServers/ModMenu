local core = core or minetest
local S = mod_menu.S

mod_menu.FORMNAME = "mod_menu:main"
mod_menu.ADMIN_FORMNAME = "mod_menu:admin"
mod_menu.CONFIG_FORM_PREFIX = "mod_menu:config:"
mod_menu.player_state = mod_menu.player_state or {}
mod_menu.registered_settings = mod_menu.registered_settings or {}
mod_menu.registered_icons = mod_menu.registered_icons or {}
mod_menu.settings_form_status = mod_menu.settings_form_status or {}
mod_menu.settings_form_state = mod_menu.settings_form_state or {}
mod_menu.cached_mods = nil
mod_menu.storage = mod_menu.storage or core.get_mod_storage()
mod_menu.NO_IMAGE_TEXTURE = "mod_menu_no_image.png"

mod_menu.defaults = {
	sort = "asc",
	search = "",
	show_libraries = false,
}

function mod_menu.get_state(player_name)
	local state = mod_menu.player_state[player_name]
	if not state then
		state = {
			sort = mod_menu.defaults.sort,
			search = mod_menu.defaults.search,
			show_libraries = mod_menu.defaults.show_libraries,
			selected_id = nil,
		}
		mod_menu.player_state[player_name] = state
	end

	return state
end

function mod_menu.reset_cache()
	mod_menu.cached_mods = nil
end

local function storage_key(name)
	return "config_enabled:" .. name
end

function mod_menu.get_storage_bool(key, default)
	local value = mod_menu.storage:get_string(key)
	if value == "" then
		return default
	end

	return value == "true"
end

function mod_menu.set_storage_bool(key, value)
	mod_menu.storage:set_string(key, value and "true" or "false")
end

function mod_menu.players_allowed()
	return mod_menu.get_storage_bool("allow_players", true)
end

function mod_menu.set_players_allowed(value)
	mod_menu.set_storage_bool("allow_players", value)
end

function mod_menu.can_admin(player_name)
	return core.check_player_privs(player_name, { server = true })
end

function mod_menu.can_open(player_name)
	return mod_menu.players_allowed() or mod_menu.can_admin(player_name)
end

function mod_menu.is_config_enabled(mod_id)
	return mod_menu.get_storage_bool(storage_key(mod_id), true)
end

function mod_menu.set_config_enabled(mod_id, value)
	mod_menu.set_storage_bool(storage_key(mod_id), value)
end

function mod_menu.has_enabled_config(mod_id)
	return mod_menu.has_settings(mod_id) and mod_menu.is_config_enabled(mod_id)
end

function mod_menu.chat(player_name, message)
	core.chat_send_player(player_name, core.colorize("#d7e3ff", "[Mod Menu] ") .. message)
end

function mod_menu.checkbox_value(value, fallback)
	if value == nil then
		return fallback
	end

	return value == "true"
end

function mod_menu.localized_badge(id)
	if id == "game" then
		return S("Game")
	elseif id == "library" then
		return S("Library")
	elseif id == "core" then
		return S("Core")
	elseif id == "config" then
		return S("Config")
	end

	return id
end
