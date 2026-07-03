local core = core or minetest

local function trim(value)
	return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function split_csv(value)
	local result = {}
	value = trim(value)

	if value == "" then
		return result
	end

	for item in value:gmatch("[^,]+") do
		item = trim(item)
		if item ~= "" then
			result[#result + 1] = item
		end
	end

	return result
end

local function starts_with(value, prefix)
	return prefix ~= nil and prefix ~= "" and value:sub(1, #prefix) == prefix
end

local function read_file(path)
	if not io or not io.open then
		return nil
	end

	local ok, file = pcall(io.open, path, "r")
	if not ok or not file then
		return nil
	end

	local text = file:read("*a")
	file:close()
	return text
end

local function file_exists(path)
	if not io or not io.open then
		return false
	end

	local ok, file = pcall(io.open, path, "rb")
	if not ok or not file then
		return false
	end

	file:close()
	return true
end

local function basename(path)
	path = tostring(path or ""):gsub("\\", "/")
	return path:match("([^/]+)$") or path
end

local function parse_mod_conf(path)
	local data = {}
	local text = read_file(path)

	if not text then
		return data
	end

	for line in text:gmatch("[^\r\n]+") do
		line = trim(line)
		if line ~= "" and line:sub(1, 1) ~= "#" then
			local key, value = line:match("^([%w_%-%.]+)%s*=%s*(.-)%s*$")
			if key and value then
				data[key] = trim(value)
			end
		end
	end

	return data
end

local function lower(value)
	return tostring(value or ""):lower()
end

local function has_token(list, token)
	for _, item in ipairs(list) do
		if lower(item) == token then
			return true
		end
	end

	return false
end

local function detect_library(mod_id, conf)
	local badge_tokens = split_csv(conf.mod_menu_badges or conf.badges or "")
	if has_token(badge_tokens, "library") then
		return true
	end

	if lower(conf.library) == "true" or lower(conf.mod_menu_library) == "true" then
		return true
	end

	return mod_id:find("api", 1, true) ~= nil or mod_id:find("lib", 1, true) ~= nil
end

local function configured_icon(conf, key)
	local value = trim(conf[key] or "")
	if value == "" then
		return nil
	end

	return basename(value)
end

local function find_auto_icon(mod_id, mod_path, delim)
	local textures_path = mod_path .. delim .. "textures" .. delim
	local candidates = {
		mod_id .. "_icon.png",
		mod_id .. ".png",
		mod_id .. "_logo.png",
		"icon.png",
		"logo.png",
	}

	for _, candidate in ipairs(candidates) do
		if file_exists(textures_path .. candidate) then
			return candidate
		end
	end

	return nil
end

local function detect_icon(mod_id, mod_path, delim, conf)
	local registered_icon = mod_menu.registered_icons[mod_id]
	if registered_icon then
		return registered_icon, true
	end

	local icon = configured_icon(conf, "mod_menu_icon") or configured_icon(conf, "icon")
	if icon then
		return icon, true
	end

	icon = find_auto_icon(mod_id, mod_path, delim)
	if icon then
		return icon, true
	end

	if mod_menu.has_settings(mod_id) then
		return mod_menu.NO_IMAGE_TEXTURE, false
	end

	return nil, false
end

local function get_game_info()
	if core.get_game_info then
		return core.get_game_info() or {}
	end

	return {}
end

local function make_badges(mod_id, mod_path, conf, game_info)
	local badges = {}
	local game_path = game_info.path or ""

	if starts_with(mod_path, game_path) then
		badges[#badges + 1] = "game"
	end

	if mod_id == "builtin" or starts_with(mod_path, (core.get_builtin_path and core.get_builtin_path()) or "") then
		badges[#badges + 1] = "core"
	end

	if detect_library(mod_id, conf) then
		badges[#badges + 1] = "library"
	end

	if mod_menu.has_enabled_config(mod_id) then
		badges[#badges + 1] = "config"
	end

	return badges
end

local function make_mod_record(mod_id, game_info)
	local mod_path = core.get_modpath(mod_id) or ""
	local delim = rawget(_G, "DIR_DELIM") or "/"
	local conf = parse_mod_conf(mod_path .. delim .. "mod.conf")
	local title = trim(conf.title or conf.name or mod_id)
	local description = trim(conf.description or "")
	local author = trim(conf.author or conf.authors or "")
	local license = trim(conf.license or conf.licence or "")
	local depends = split_csv(conf.depends)
	local optional_depends = split_csv(conf.optional_depends)
	local badges = make_badges(mod_id, mod_path, conf, game_info)
	local icon, has_own_icon = detect_icon(mod_id, mod_path, delim, conf)
	local supported = mod_menu.has_settings(mod_id)

	return {
		id = mod_id,
		title = title,
		description = description,
		author = author,
		license = license,
		depends = depends,
		optional_depends = optional_depends,
		path = mod_path,
		badges = badges,
		icon = icon,
		has_own_icon = has_own_icon,
		supported = supported,
		compatible = supported,
		raw = conf,
		search_text = lower(table.concat({
			mod_id,
			title,
			description,
			author,
			license,
			table.concat(depends, " "),
			table.concat(optional_depends, " "),
			table.concat(badges, " "),
			supported and "supported" or "unsupported",
		}, " ")),
	}
end

local function sort_mods(mods, sort_mode)
	table.sort(mods, function(left, right)
		local left_title = lower(left.title ~= "" and left.title or left.id)
		local right_title = lower(right.title ~= "" and right.title or right.id)

		if left_title == right_title then
			return left.id < right.id
		end

		if sort_mode == "desc" then
			return left_title > right_title
		end

		return left_title < right_title
	end)
end

function mod_menu.get_all_mods()
	if mod_menu.cached_mods then
		return mod_menu.cached_mods
	end

	local game_info = get_game_info()
	local mods = {}

	for _, mod_id in ipairs(core.get_modnames()) do
		mods[#mods + 1] = make_mod_record(mod_id, game_info)
	end

	sort_mods(mods, "asc")
	mod_menu.cached_mods = mods
	return mods
end

function mod_menu.filter_mods(search, show_libraries, sort_mode)
	local filtered = {}
	search = lower(trim(search))

	for _, mod in ipairs(mod_menu.get_all_mods()) do
		local is_library = false
		for _, badge in ipairs(mod.badges) do
			if badge == "library" then
				is_library = true
				break
			end
		end

		if (show_libraries or not is_library) and (search == "" or mod.search_text:find(search, 1, true)) then
			filtered[#filtered + 1] = mod
		end
	end

	sort_mods(filtered, sort_mode)
	return filtered
end

function mod_menu.find_mod(mod_id)
	if not mod_id then
		return nil
	end

	for _, mod in ipairs(mod_menu.get_all_mods()) do
		if mod.id == mod_id then
			return mod
		end
	end

	return nil
end

function mod_menu.refresh_badges()
	for _, mod in ipairs(mod_menu.get_all_mods()) do
		local has_config_badge = false
		for _, badge in ipairs(mod.badges) do
			if badge == "config" then
				has_config_badge = true
				break
			end
		end

		if mod_menu.has_enabled_config(mod.id) and not has_config_badge then
			mod.badges[#mod.badges + 1] = "config"
		end
	end
end
