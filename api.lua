local core = core or minetest
local S = mod_menu.S

local valid_setting_types = {
	bool = true,
	enum = true,
	number = true,
	int = true,
	string = true,
	section = true,
	list = true,
}

local saveable_setting_types = {
	bool = true,
	enum = true,
	number = true,
	int = true,
	string = true,
	list = true,
}

local function copy_list(values)
	local result = {}
	for index, value in ipairs(values or {}) do
		result[index] = tostring(value)
	end
	return result
end

local function copy_table(value)
	if type(value) ~= "table" then
		return value
	end

	local result = {}
	for key, child in pairs(value) do
		result[key] = copy_table(child)
	end
	return result
end

local function normalize_number(value, fallback)
	value = tonumber(value)
	if value == nil then
		return fallback
	end
	return value
end

local function safe_id(value, fallback)
	value = tostring(value or fallback or "item")
	value = value:gsub("[^%w_%-]", "_")
	if value == "" then
		return tostring(fallback or "item")
	end
	return value
end

local function value_in_list(value, values)
	for _, candidate in ipairs(values or {}) do
		if candidate == value then
			return true
		end
	end
	return false
end

local function clamp_number(value, item)
	local changed = false
	if item.min ~= nil and value < item.min then
		value = item.min
		changed = true
	end
	if item.max ~= nil and value > item.max then
		value = item.max
		changed = true
	end
	if item.type == "int" then
		local rounded = math.floor(value + 0.5)
		changed = changed or rounded ~= value
		value = rounded
	end
	return value, changed
end

local function number_to_string(value)
	value = tonumber(value) or 0
	if math.floor(value) == value then
		return tostring(value)
	end
	return ("%.4f"):format(value):gsub("0+$", ""):gsub("%.$", "")
end

local function normalize_simple_setting(item, index, uid)
	assert(type(item.key) == "string" and item.key ~= "", "mod_menu.register_settings: setting #" .. index .. " needs a key")

	local setting_type = item.type or "string"
	assert(valid_setting_types[setting_type], "mod_menu.register_settings: unsupported type for " .. item.key)

	local normalized = {
		uid = tostring(uid),
		id = safe_id(item.id or item.key, index),
		key = item.key,
		type = setting_type,
		label = tostring(item.label or item.key),
		description = item.description and tostring(item.description) or nil,
		category = item.category and tostring(item.category) or nil,
		indent = tonumber(item.indent) or 0,
		resettable = item.resettable ~= false,
		advanced = item.advanced == true,
		ui = item.ui and tostring(item.ui) or nil,
		slider_style = item.slider_style and tostring(item.slider_style) or nil,
		default = item.default,
		min = item.min,
		max = item.max,
	}

	if setting_type == "bool" then
		normalized.default = item.default == true
	elseif setting_type == "enum" then
		normalized.values = copy_list(item.values)
		assert(#normalized.values > 0, "mod_menu.register_settings: enum " .. item.key .. " needs values")
		normalized.default = tostring(item.default or normalized.values[1])
		if not value_in_list(normalized.default, normalized.values) then
			normalized.default = normalized.values[1]
		end
	elseif setting_type == "number" or setting_type == "int" then
		normalized.default = normalize_number(item.default, 0)
		normalized.min = item.min ~= nil and normalize_number(item.min, normalized.default) or nil
		normalized.max = item.max ~= nil and normalize_number(item.max, normalized.default) or nil
		if normalized.ui == "slider" and normalized.slider_style == nil then
			normalized.slider_style = "fixed_label"
		end
	elseif setting_type == "list" then
		normalized.default = type(item.default) == "table" and copy_table(item.default) or {}
		normalized.entry = type(item.entry) == "table" and item.entry or {}
	elseif setting_type == "string" then
		normalized.default = tostring(item.default or "")
	end

	return normalized
end

local normalize_items

local function normalize_section(item, index, context)
	local uid = context.next_uid()
	local children = item.children or item.settings or {}
	assert(type(children) == "table", "mod_menu.register_settings: section #" .. index .. " children must be a table")

	return {
		uid = tostring(uid),
		id = safe_id(item.id or item.label, index),
		type = "section",
		label = tostring(item.label or item.title or ("Section " .. index)),
		description = item.description and tostring(item.description) or nil,
		default_open = item.default_open ~= false,
		indent = tonumber(item.indent) or 0,
		children = normalize_items(children, context),
	}
end

local function normalize_list_entry(item, context)
	local entry = {}
	for index, child in ipairs(item.entry or {}) do
		assert(type(child) == "table", "mod_menu.register_settings: list entry setting #" .. index .. " must be a table")
		local child_type = child.type or "string"
		assert(child_type ~= "section" and child_type ~= "list", "mod_menu.register_settings: nested section/list entries are not supported")
		local uid = context.next_uid()
		entry[index] = normalize_simple_setting(child, index, uid)
	end
	return entry
end

normalize_items = function(items, context)
	local normalized = {}
	for index, item in ipairs(items or {}) do
		assert(type(item) == "table", "mod_menu.register_settings: setting #" .. index .. " must be a table")
		local setting_type = item.type or "string"
		assert(valid_setting_types[setting_type], "mod_menu.register_settings: unsupported type for setting #" .. index)

		if setting_type == "section" then
			normalized[#normalized + 1] = normalize_section(item, index, context)
		else
			local uid = context.next_uid()
			local setting = normalize_simple_setting(item, index, uid)
			if setting.type == "list" then
				setting.entry = normalize_list_entry(item, context)
			end
			normalized[#normalized + 1] = setting
		end
	end
	return normalized
end

local function collect_saveable(items, out)
	for _, item in ipairs(items or {}) do
		if item.type == "section" then
			collect_saveable(item.children, out)
		elseif saveable_setting_types[item.type] then
			out[#out + 1] = item
		end
	end
end

local function normalize_definition(mod_id, definition)
	assert(type(definition) == "table", "mod_menu.register_settings: definition must be a table")

	local uid_counter = 0
	local context = {
		next_uid = function()
			uid_counter = uid_counter + 1
			return uid_counter
		end,
	}

	local normalized = {
		mod_id = mod_id,
		title = definition.title and tostring(definition.title) or nil,
		icon = definition.icon and tostring(definition.icon) or nil,
		on_save = definition.on_save,
		tabs = {},
		saveable = {},
	}

	if normalized.on_save ~= nil then
		assert(type(normalized.on_save) == "function", "mod_menu.register_settings: on_save must be a function")
	end

	if type(definition.tabs) == "table" and #definition.tabs > 0 then
		for index, tab in ipairs(definition.tabs) do
			assert(type(tab) == "table", "mod_menu.register_settings: tab #" .. index .. " must be a table")
			local settings = tab.settings or tab.sections or {}
			assert(type(settings) == "table", "mod_menu.register_settings: tab #" .. index .. " settings must be a table")
			normalized.tabs[index] = {
				id = safe_id(tab.id or tab.label, index),
				label = tostring(tab.label or tab.title or tab.id or ("Tab " .. index)),
				settings = normalize_items(settings, context),
			}
		end
	else
		local settings = definition.settings or definition.sections or {}
		assert(type(settings) == "table", "mod_menu.register_settings: definition.settings must be a table")
		normalized.tabs[1] = {
			id = "general",
			label = tostring(definition.default_tab_label or S("General")),
			settings = normalize_items(settings, context),
		}
	end

	for _, tab in ipairs(normalized.tabs) do
		collect_saveable(tab.settings, normalized.saveable)
	end

	return normalized
end

function mod_menu.has_settings(mod_id)
	return mod_menu.registered_settings[mod_id] ~= nil
end

function mod_menu.register_icon(mod_id, texture_name)
	assert(type(mod_id) == "string" and mod_id ~= "", "mod_menu.register_icon: mod_id must be a non-empty string")
	assert(type(texture_name) == "string" and texture_name ~= "", "mod_menu.register_icon: texture_name must be a non-empty string")

	mod_menu.registered_icons[mod_id] = texture_name
	mod_menu.reset_cache()
end

function mod_menu.register_settings(mod_id, definition)
	assert(type(mod_id) == "string" and mod_id ~= "", "mod_menu.register_settings: mod_id must be a non-empty string")

	local normalized = normalize_definition(mod_id, definition)
	mod_menu.registered_settings[mod_id] = normalized
	if normalized.icon and normalized.icon ~= "" then
		mod_menu.registered_icons[mod_id] = normalized.icon
	end

	mod_menu.reset_cache()
end

function mod_menu.unregister_settings(mod_id)
	mod_menu.registered_settings[mod_id] = nil
	mod_menu.settings_form_status[mod_id] = nil
	mod_menu.reset_settings_form_states(mod_id)
	mod_menu.reset_cache()
end

function mod_menu.get_setting_value(item)
	local raw_value = core.settings:get(item.key)

	if item.type == "bool" then
		if raw_value == nil then
			return item.default
		end
		return raw_value == "true"
	elseif item.type == "enum" then
		local value = raw_value or item.default
		if not value_in_list(value, item.values) then
			value = item.default
		end
		return value
	elseif item.type == "number" or item.type == "int" then
		local value = normalize_number(raw_value, item.default)
		value = clamp_number(value, item)
		return value
	elseif item.type == "list" then
		local value = raw_value and core.deserialize(raw_value) or nil
		if type(value) ~= "table" then
			value = copy_table(item.default)
		end
		return value
	elseif item.type == "string" then
		return raw_value or item.default
	end

	return raw_value
end

function mod_menu.set_setting_value(item, value)
	if item.type == "bool" then
		core.settings:set_bool(item.key, value == true)
	elseif item.type == "number" or item.type == "int" then
		core.settings:set(item.key, number_to_string(value))
	elseif item.type == "list" then
		core.settings:set(item.key, core.serialize(type(value) == "table" and value or {}))
	else
		core.settings:set(item.key, tostring(value or ""))
	end
end

local function default_entry_values(list_item)
	local values = {}
	for _, child in ipairs(list_item.entry or {}) do
		values[child.key] = copy_table(child.default)
	end
	return values
end

local function reset_all_values(state, definition)
	for _, item in ipairs(definition.saveable or {}) do
		state.values[item.key] = copy_table(item.default)
	end
end

function mod_menu.reset_settings_form_states(mod_id)
	for _, by_mod in pairs(mod_menu.settings_form_state or {}) do
		by_mod[mod_id] = nil
	end
end

function mod_menu.reset_settings_form_state(player_name, mod_id)
	if mod_menu.settings_form_state[player_name] then
		mod_menu.settings_form_state[player_name][mod_id] = nil
	end
end

function mod_menu.get_settings_form_state(player_name, mod_id)
	mod_menu.settings_form_state[player_name] = mod_menu.settings_form_state[player_name] or {}
	local state = mod_menu.settings_form_state[player_name][mod_id]
	local definition = mod_menu.registered_settings[mod_id]

	if state or not definition then
		return state
	end

	state = {
		tab = 1,
		search = "",
		scroll = 0,
		open_sections = {},
		values = {},
	}

	for _, item in ipairs(definition.saveable) do
		state.values[item.key] = copy_table(mod_menu.get_setting_value(item))
	end

	for _, tab in ipairs(definition.tabs) do
		local function open_defaults(items)
			for _, item in ipairs(items or {}) do
				if item.type == "section" then
					state.open_sections[item.uid] = item.default_open
					open_defaults(item.children)
				end
			end
		end
		open_defaults(tab.settings)
	end

	mod_menu.settings_form_state[player_name][mod_id] = state
	return state
end

local function parse_simple_value(item, raw_value, fallback)
	local value = fallback
	local clamped = false

	if item.type == "bool" then
		if raw_value == S("Yes") or raw_value == "Yes" or raw_value == "true" or raw_value == S("Enabled") or raw_value == "Enabled" then
			value = true
		elseif raw_value == S("No") or raw_value == "No" or raw_value == "false" or raw_value == S("Disabled") or raw_value == "Disabled" then
			value = false
		end
	elseif item.type == "enum" then
		if raw_value ~= nil and value_in_list(raw_value, item.values) then
			value = raw_value
		end
	elseif item.type == "number" or item.type == "int" then
		local parsed = tonumber(raw_value)
		if parsed == nil then
			parsed = tonumber(value) or item.default
			clamped = clamped or raw_value ~= nil
		end
		value, clamped = clamp_number(parsed, item)
	elseif item.type == "string" then
		if raw_value ~= nil then
			value = raw_value
		end
	end

	return value, clamped
end

local function field_name(item)
	return "mm_setting_" .. item.uid
end

local function slider_name(item)
	return "mm_slider_" .. item.uid
end

local function scrollbar_event(raw_value)
	local value = tonumber(raw_value)
	if value ~= nil then
		return { type = "VAL", value = value }
	end

	if core.explode_scrollbar_event then
		local ok, event = pcall(core.explode_scrollbar_event, raw_value)
		if ok and event and event.value then
			return {
				type = event.type or "VAL",
				value = tonumber(event.value),
			}
		end
	end

	value = tonumber(tostring(raw_value or ""):match("(-?%d+)$"))
	if value ~= nil then
		return { type = "VAL", value = value }
	end

	return { type = "INV", value = nil }
end

local function scrollbar_value(raw_value)
	local event = scrollbar_event(raw_value)
	return event and event.value or nil
end

local function slider_to_value(item, raw_value)
	if item.min == nil or item.max == nil then
		return nil
	end

	local percent = scrollbar_value(raw_value)
	if not percent then
		return nil
	end

	percent = math.max(0, math.min(1000, percent))
	local value = item.min + (item.max - item.min) * (percent / 1000)
	return clamp_number(value, item)
end

local function value_to_slider(item, value)
	if item.min == nil or item.max == nil or item.max == item.min then
		return 0
	end

	local percent = ((tonumber(value) or item.min) - item.min) / (item.max - item.min)
	return math.max(0, math.min(1000, math.floor(percent * 1000 + 0.5)))
end

local function live_scrollbar_change(fields, definition)
	local saw_scrollbar = false
	local saw_setting_slider = false
	local slider_names = {}

	for _, item in ipairs(definition.saveable) do
		if item.type ~= "list" then
			slider_names[slider_name(item)] = true
		end
	end

	for name, raw in pairs(fields or {}) do
		if slider_names[name] then
			local event = scrollbar_event(raw)
			if not event or event.type ~= "CHG" then
				return false, false
			end
			saw_scrollbar = true
			saw_setting_slider = saw_setting_slider or slider_names[name] == true
		else
			return false, false
		end
	end

	return saw_scrollbar, saw_setting_slider
end

function mod_menu.update_settings_draft_from_fields(player_name, mod_id, fields)
	local definition = mod_menu.registered_settings[mod_id]
	if not definition then
		return false, true, false
	end

	local state = mod_menu.get_settings_form_state(player_name, mod_id)
	if not state then
		return false, true, false
	end

	local clamped = false
	local live_scrollbar, live_setting_slider = live_scrollbar_change(fields, definition)

	if fields.mm_search ~= nil then
		if state.search ~= fields.mm_search then
			state.scroll = 0
		end
		state.search = fields.mm_search
	end
	if fields.mm_tabs ~= nil then
		local tab_index = tonumber(fields.mm_tabs)
		if tab_index and definition.tabs[tab_index] then
			if state.tab ~= tab_index then
				state.scroll = 0
			end
			state.tab = tab_index
		end
	end
	if fields.mm_settings_scroll ~= nil then
		state.scroll = scrollbar_value(fields.mm_settings_scroll) or state.scroll or 0
	end

	for _, item in ipairs(definition.saveable) do
		if item.type ~= "list" then
			local raw = fields[field_name(item)]
			if raw ~= nil then
				local local_clamped
				state.values[item.key], local_clamped = parse_simple_value(item, raw, state.values[item.key])
				clamped = clamped or local_clamped
			end

			local slider_raw = fields[slider_name(item)]
			if slider_raw ~= nil then
				local value, local_clamped = slider_to_value(item, slider_raw)
				if value ~= nil then
					state.values[item.key] = value
					clamped = clamped or local_clamped
				end
			end

			if fields["mm_bool_" .. item.uid] then
				state.values[item.key] = not state.values[item.key]
			end
			if fields["mm_reset_" .. item.uid] and item.resettable then
				state.values[item.key] = copy_table(item.default)
			end
		else
			local list = state.values[item.key]
			if type(list) ~= "table" then
				list = {}
				state.values[item.key] = list
			end
			if fields["mm_list_add_" .. item.uid] then
				list[#list + 1] = default_entry_values(item)
			end
			for entry_index = #list, 1, -1 do
				if fields["mm_list_remove_" .. item.uid .. "_" .. entry_index] then
					table.remove(list, entry_index)
				end
			end
			if fields["mm_reset_" .. item.uid] and item.resettable then
				state.values[item.key] = copy_table(item.default)
				list = state.values[item.key]
			end
			for entry_index, entry in ipairs(list) do
				for _, child in ipairs(item.entry or {}) do
					local raw = fields["mm_list_" .. item.uid .. "_" .. entry_index .. "_" .. child.uid]
					if raw ~= nil then
						local local_clamped
						entry[child.key], local_clamped = parse_simple_value(child, raw, entry[child.key] or child.default)
						clamped = clamped or local_clamped
					end
				end
			end
		end
	end

	local function handle_sections(items)
		for _, item in ipairs(items or {}) do
			if item.type == "section" then
				if fields["mm_section_" .. item.uid] then
					state.open_sections[item.uid] = not state.open_sections[item.uid]
				end
				if fields["mm_reset_section_" .. item.uid] then
					local function reset_children(children)
						for _, child in ipairs(children or {}) do
							if child.type == "section" then
								reset_children(child.children)
							elseif saveable_setting_types[child.type] and child.resettable then
								state.values[child.key] = copy_table(child.default)
							end
						end
					end
					reset_children(item.children)
				end
				handle_sections(item.children)
			end
		end
	end

	for _, tab in ipairs(definition.tabs) do
		handle_sections(tab.settings)
	end

	if fields.mm_reset_all then
		reset_all_values(state, definition)
	end

	return clamped, not live_scrollbar, live_setting_slider
end

function mod_menu.save_settings(player_name, mod_id, fields)
	local definition = mod_menu.registered_settings[mod_id]
	if not definition then
		mod_menu.chat(player_name, S("This mod has not registered settings."))
		return false
	end

	local clamped = mod_menu.update_settings_draft_from_fields(player_name, mod_id, fields)
	local state = mod_menu.get_settings_form_state(player_name, mod_id)
	if not state then
		return false
	end

	for _, item in ipairs(definition.saveable) do
		mod_menu.set_setting_value(item, state.values[item.key])
	end

	local write_ok = core.settings:write()
	local values = copy_table(state.values)
	local save_ok = true
	if definition.on_save then
		local ok, err = pcall(definition.on_save, player_name, values, {
			mod_id = mod_id,
			write_ok = write_ok,
			clamped = clamped,
		})
		if not ok then
			save_ok = false
			core.log("error", "[mod_menu] Failed to apply settings for " .. mod_id .. ": " .. tostring(err))
			mod_menu.chat(player_name, S("Saved settings for @1, but applying them failed.", mod_id))
		end
	end

	mod_menu.settings_form_status[mod_id] = mod_menu.settings_form_status[mod_id] or {}
	if write_ok then
		mod_menu.settings_form_status[mod_id][player_name] = clamped and S("Saved; invalid values were clamped") or S("Saved")
	else
		mod_menu.settings_form_status[mod_id][player_name] = S("Applied in memory; config write failed")
	end

	return save_ok
end

function mod_menu.open_settings(player_name, mod_id)
	local definition = mod_menu.registered_settings[mod_id]
	if not definition then
		mod_menu.chat(player_name, S("This mod has not registered settings."))
		return
	end
	if not mod_menu.is_config_enabled(mod_id) then
		mod_menu.chat(player_name, S("Settings are disabled for @1.", mod_id))
		return
	end

	mod_menu.reset_settings_form_state(player_name, mod_id)
	if mod_menu.settings_form_status[mod_id] then
		mod_menu.settings_form_status[mod_id][player_name] = nil
	end

	core.show_formspec(player_name, mod_menu.CONFIG_FORM_PREFIX .. mod_id, mod_menu.build_settings_formspec(player_name, mod_id))
end

mod_menu._settings_field_name = field_name
mod_menu._settings_slider_name = slider_name
mod_menu._settings_value_to_slider = value_to_slider
mod_menu._settings_scrollbar_event = scrollbar_event
