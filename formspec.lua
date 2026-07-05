local core = core or minetest
local S = mod_menu.S

local function esc(value)
	if core.formspec_escape then
		return core.formspec_escape(tostring(value or ""))
	end

	return tostring(value or "")
		:gsub("\\", "\\\\")
		:gsub("%[", "\\[")
		:gsub("%]", "\\]")
		:gsub(";", "\\;")
		:gsub(",", "\\,")
end

local function join_list(values, empty_text)
	if not values or #values == 0 then
		return empty_text or "-"
	end

	return table.concat(values, ", ")
end

local function number_text(value)
	value = tonumber(value) or 0
	if math.floor(value) == value then
		return tostring(value)
	end
	return ("%.4f"):format(value):gsub("0+$", ""):gsub("%.$", "")
end

local function badge_text(mod)
	local badges = {}
	for _, badge in ipairs(mod.badges or {}) do
		badges[#badges + 1] = mod_menu.localized_badge(badge)
	end

	return table.concat(badges, " ")
end

local function display_name(mod)
	if not mod then
		return ""
	end

	return mod.title ~= "" and mod.title or mod.id
end

local BUTTON_BG = "#b8bec8"
local BUTTON_BG_HOVER = "#d6dae1"
local BUTTON_TEXT = "#111827"
local SEARCH_TEXT = "#1d4ed8"
local RESET_TEXT = "#b91c1c"
local YES_TEXT = "#15803d"
local NO_TEXT = "#b91c1c"

local function button_style_type()
	return "style_type[button,button_exit;border=true;bgcolor=" .. BUTTON_BG ..
		";textcolor=" .. BUTTON_TEXT .. ";bgcolor_hovered=" .. BUTTON_BG_HOVER .. "]"
end

local function button_text_style(name, color)
	return "style[" .. name .. ";textcolor=" .. color .. "]"
end

local function detail_text(mod, show_path)
	if not mod then
		return S("Select a mod from the list.")
	end

	local lines = {
		S("ID: @1", mod.id),
		S("Name: @1", display_name(mod)),
		S("Description: @1", mod.description ~= "" and mod.description or "-"),
		S("Author: @1", mod.author ~= "" and mod.author or "-"),
		S("License: @1", mod.license ~= "" and mod.license or "-"),
		S("Depends: @1", join_list(mod.depends, "-")),
		S("Optional depends: @1", join_list(mod.optional_depends, "-")),
		S("Badges: @1", badge_text(mod) ~= "" and badge_text(mod) or "-"),
		S("Mod Menu support: @1", mod.supported and S("Yes") or S("Limited")),
	}

	if show_path then
		lines[#lines + 1] = S("Path: @1", mod.path ~= "" and mod.path or "-")
	end

	return table.concat(lines, "\n")
end

local function count_compatible_mods(mods)
	local count = 0
	for _, mod in ipairs(mods or {}) do
		if mod.supported then
			count = count + 1
		end
	end
	return count
end

local function group_mods(mods)
	local rows = {}
	local supported = {}
	local unsupported = {}

	for _, mod in ipairs(mods) do
		if mod.supported then
			supported[#supported + 1] = mod
		else
			unsupported[#unsupported + 1] = mod
		end
	end

	for _, mod in ipairs(supported) do
		rows[#rows + 1] = { mod = mod }
	end

	if #unsupported > 0 then
		rows[#rows + 1] = {
			separator = true,
			label = S("-----Unsupported mods, functionality limited-----"),
		}

		for _, mod in ipairs(unsupported) do
			rows[#rows + 1] = { mod = mod }
		end
	end

	return rows
end

local function find_selected_index(rows, selected_id)
	if selected_id then
		for index, row in ipairs(rows) do
			if row.mod and row.mod.id == selected_id then
				return index
			end
		end
	end

	for index, row in ipairs(rows) do
		if row.mod then
			return index
		end
	end

	return 0
end

local function selected_mod_from_state(rows, state)
	local selected_index = find_selected_index(rows, state.selected_id)
	local mod = rows[selected_index] and rows[selected_index].mod

	if mod then
		state.selected_id = mod.id
	end

	return mod, selected_index
end

local function clear_detail_edit_state(state)
	state.detail_edit_id = nil
	state.detail_draft = nil
end

local function build_mod_table(rows, state)
	local values = {}
	local image_indexes = {}
	local image_options = {}
	local row_map = {}

	for index, row in ipairs(rows) do
		if row.separator then
			values[#values + 1] = ""
			values[#values + 1] = esc(row.label)
			values[#values + 1] = ""
			row_map[index] = nil
		else
			local mod = row.mod
			local image_index = ""
			if mod.icon and mod.icon ~= "" then
				image_index = image_indexes[mod.icon]
				if not image_index then
					image_options[#image_options + 1] = mod.icon
					image_index = #image_options
					image_indexes[mod.icon] = image_index
				end
			end

			values[#values + 1] = image_index
			values[#values + 1] = esc(display_name(mod))
			values[#values + 1] = esc(badge_text(mod))
			row_map[index] = mod.id
		end
	end

	state.row_map = row_map

	local columns = { "tablecolumns[image" }
	for index, texture in ipairs(image_options) do
		columns[#columns + 1] = "," .. index .. "=" .. esc(texture)
	end
	columns[#columns + 1] = ";text;text]"

	return table.concat(values, ","), table.concat(columns)
end

local function get_layout(player_name)
	local width = 22
	local height = 12.35

	if core.get_player_window_information then
		local info = core.get_player_window_information(player_name)
		if info and info.max_formspec_size then
			width = math.max(16, tonumber(info.max_formspec_size.x) or width)
			height = math.max(9, tonumber(info.max_formspec_size.y) or height)
		end
	end

	local margin = 0.45
	local gap = 0.35
	local top = 0.3
	local search_y = 1.25
	local content_y = 2.1
	local footer_h = 0.85
	local content_h = height - content_y - footer_h - 0.25
	local left_w = math.max(7.2, (width - margin * 2 - gap) * 0.48)
	local right_x = margin + left_w + gap
	local right_w = width - right_x - margin

	return {
		width = width,
		height = height,
		margin = margin,
		gap = gap,
		top = top,
		search_y = search_y,
		content_y = content_y,
		content_h = content_h,
		left_w = left_w,
		right_x = right_x,
		right_w = right_w,
		footer_y = height - footer_h,
	}
end

function mod_menu.build_formspec(player_name)
	mod_menu.refresh_badges()

	local state = mod_menu.get_state(player_name)
	local mods = mod_menu.filter_mods(state.search, state.show_libraries, state.sort)
	local rows = group_mods(mods)
	local selected_mod, selected_index = selected_mod_from_state(rows, state)
	local sort_label = state.sort == "desc" and "Z-A" or "A-Z"
	local config_registered = selected_mod and mod_menu.has_settings(selected_mod.id)
	local config_enabled = selected_mod and mod_menu.has_enabled_config(selected_mod.id)
	local layout = get_layout(player_name)
	local table_content, table_columns = build_mod_table(rows, state)
	local detail_y = layout.content_y + 1.3
	local detail_h = layout.content_h - 1.6
	local all_mods = mod_menu.get_all_mods()
	local compatible_count = count_compatible_mods(all_mods)
	if state.detail_edit_id and (not selected_mod or state.detail_edit_id ~= selected_mod.id) then
		clear_detail_edit_state(state)
	end
	local generated_detail = detail_text(selected_mod, false)
	local detail_override = selected_mod and mod_menu.get_detail_override(selected_mod.id) or nil
	local visible_detail = detail_override or generated_detail
	local editing_detail = selected_mod and state.detail_edit_id == selected_mod.id
	local edit_text = editing_detail and (state.detail_draft or visible_detail) or ""
	local detail_box_color = editing_detail and "#1E1E1EFF" or "#1d2431FF"
	local button_y = layout.footer_y + 0.05
	local close_x = layout.width - layout.margin - 1.45
	local cancel_x = close_x - 1.6 - 0.25
	local edit_x = layout.right_x + 0.3
	local settings_x = edit_x + 1.5

	return table.concat({
		"formspec_version[6]",
		"size[", layout.width, ",", layout.height, "]",
		"position[0.5,0.5]",
		"anchor[0.5,0.5]",
		"padding[0,0]",
		"no_prepend[]",
		"bgcolor[#151923;true]",
		"style_type[label;textcolor=#edf2ff]",
		button_style_type(),
		button_text_style("apply_search", SEARCH_TEXT),
		"style_type[field;textcolor=#edf2ff;bgcolor=#222938]",
		"style_type[table;textcolor=#edf2ff]",
		"style[detail_edit_text;border=false;textcolor=#edf2ff]",
		"box[", layout.margin, ",", layout.top, ";", layout.width - layout.margin * 2, ",0.75;#222938]",
		"label[", layout.margin + 0.25, ",", layout.top + 0.33, ";", esc(S("Mod Menu")), "]",
		"button[", layout.width - layout.margin - 1.35, ",", layout.top + 0.1, ";1.35,0.55;refresh;", esc(S("Refresh")), "]",
		"field[", layout.margin, ",", layout.search_y, ";", layout.left_w - 2.35, ",0.6;search;;", esc(state.search), "]",
		"button[", layout.margin + layout.left_w - 2.2, ",", layout.search_y, ";1.1,0.6;apply_search;", esc(S("Search")), "]",
		"button[", layout.margin + layout.left_w - 1.0, ",", layout.search_y, ";1.0,0.6;sort_toggle;", esc(sort_label), "]",
		"checkbox[", layout.right_x, ",", layout.search_y + 0.08, ";show_libraries;", esc(S("Libraries")), ";", state.show_libraries and "true" or "false", "]",
		table_columns,
		"table[", layout.margin, ",", layout.content_y, ";", layout.left_w, ",", layout.content_h, ";mod_list;", table_content, ";", selected_index, "]",
		"label[", layout.margin, ",", layout.footer_y + 0.23, ";", esc(S("@1 loaded / @2 shown / @3 compatible", #all_mods, #mods, compatible_count)), "]",
		"box[", layout.right_x, ",", layout.content_y, ";", layout.right_w, ",", layout.content_h, ";#1d2431]",
		selected_mod and selected_mod.icon and ("image[" .. layout.right_x + 0.3 .. "," .. layout.content_y + 0.25 .. ";0.75,0.75;" .. esc(selected_mod.icon) .. "]") or "",
		"label[", layout.right_x + (selected_mod and selected_mod.icon and 1.15 or 0.3), ",", layout.content_y + 0.45, ";", esc(selected_mod and display_name(selected_mod) or S("No mod selected")), "]",
		"box[", layout.right_x + 0.3, ",", detail_y, ";", layout.right_w - 0.6, ",", detail_h, ";", detail_box_color, "]",
		editing_detail and ("textarea[" .. layout.right_x + 0.42 .. "," .. (detail_y + 0.12) .. ";" ..
			(layout.right_w - 0.84) .. "," .. (detail_h - 0.24) .. ";detail_edit_text;;" .. esc(edit_text) .. "]") or
			("textarea[" .. layout.right_x + 0.42 .. "," .. (detail_y + 0.12) .. ";" ..
				(layout.right_w - 0.84) .. "," .. (detail_h - 0.24) .. ";;;" .. esc(visible_detail) .. "]"),
		config_enabled and ("button[" .. settings_x .. "," .. button_y .. ";2.3,0.6;configure;" .. esc(S("Settings")) .. "]") or "",
		selected_mod and config_registered and not config_enabled and ("label[" .. settings_x .. "," .. (button_y + 0.2) .. ";" .. esc(S("Settings disabled by admin")) .. "]") or "",
		selected_mod and not config_registered and ("label[" .. settings_x .. "," .. (button_y + 0.2) .. ";" .. esc(S("No settings screen")) .. "]") or "",
		selected_mod and (editing_detail and
			("button[" .. edit_x .. "," .. button_y .. ";1.35,0.6;detail_edit_save;" .. esc(S("Save")) .. "]") or
			("button[" .. edit_x .. "," .. button_y .. ";1.35,0.6;detail_edit_start;" .. esc(S("Edit")) .. "]")) or "",
		editing_detail and ("button[" .. cancel_x .. "," .. button_y .. ";1.6,0.6;detail_edit_cancel;" .. esc(S("Cancel")) .. "]") or "",
		"button_exit[", close_x, ",", button_y, ";1.45,0.6;close;", esc(S("Close")), "]",
	})
end

function mod_menu.show(player_name)
	core.show_formspec(player_name, mod_menu.FORMNAME, mod_menu.build_formspec(player_name))
end

local function config_mods()
	local mods = {}
	for _, mod in ipairs(mod_menu.get_all_mods()) do
		if mod_menu.has_settings(mod.id) then
			mods[#mods + 1] = mod
		end
	end

	return mods
end

local function enum_index(value, values)
	for index, candidate in ipairs(values or {}) do
		if candidate == value then
			return index
		end
	end
	return 1
end

local function enum_items(values)
	local items = {}
	for index, value in ipairs(values or {}) do
		items[index] = esc(value)
	end
	return table.concat(items, ",")
end

local function text_contains(text, query)
	if query == "" then
		return true
	end
	return tostring(text or ""):lower():find(query, 1, true) ~= nil
end

local function setting_help_text(setting)
	local parts = {}
	if (setting.type == "number" or setting.type == "int") and setting.ui == "slider" then
		return setting.description or ""
	end
	if setting.type == "int" then
		parts[#parts + 1] = S("integer")
	end
	if (setting.type == "number" or setting.type == "int") and (setting.min ~= nil or setting.max ~= nil) then
		parts[#parts + 1] = tostring(setting.min or "-") .. ".." .. tostring(setting.max or "-")
	end
	if setting.description then
		parts[#parts + 1] = setting.description
	end
	return table.concat(parts, "; ")
end

local function item_matches(item, query)
	if query == "" then
		return true
	end
	if text_contains(item.label, query) or text_contains(item.description, query) or text_contains(item.key, query) then
		return true
	end
	if item.type == "section" then
		for _, child in ipairs(item.children or {}) do
			if item_matches(child, query) then
				return true
			end
		end
	elseif item.type == "list" then
		for _, child in ipairs(item.entry or {}) do
			if item_matches(child, query) then
				return true
			end
		end
	end
	return false
end

local function current_value(state, setting)
	local value = state.values[setting.key]
	if value == nil then
		return setting.default
	end
	return value
end

local SETTINGS_SCROLL_FACTOR = 0.1
local SETTINGS_BODY_PAD = 0.15
local SETTINGS_SCROLLBAR_W = 0.34
local SETTINGS_SCROLLBAR_GAP = 0.28
local SETTINGS_RESET_W = 1.15
local SETTINGS_CONTROL_GAP = 0.35
local settings_saveable_types = {
	bool = true,
	enum = true,
	number = true,
	int = true,
	string = true,
	list = true,
}

local function clamp(value, min_value, max_value)
	value = tonumber(value) or min_value
	if value < min_value then
		return min_value
	end
	if value > max_value then
		return max_value
	end
	return value
end

local function fit_text(text, width)
	text = tostring(text or "")
	local max_chars = math.max(10, math.floor((tonumber(width) or 1) * 8.5))
	local count = 0
	local out = {}
	for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		count = count + 1
		if count <= max_chars - 3 then
			out[#out + 1] = char
		end
	end
	if count > max_chars then
		return table.concat(out) .. "..."
	end
	return text
end

local function has_resettable_child(item)
	for _, child in ipairs(item.children or {}) do
		if child.type == "section" then
			if has_resettable_child(child) then
				return true
			end
		elseif settings_saveable_types[child.type] and child.resettable then
			return true
		end
	end
	return false
end

local function settings_scroll_max(content_h, visible_h)
	return math.max(0, math.ceil(math.max(0, content_h - visible_h) / SETTINGS_SCROLL_FACTOR))
end

local function clamp_settings_scroll(state, content_h, visible_h)
	local max_scroll = settings_scroll_max(content_h, visible_h)
	state.scroll = clamp(state.scroll or 0, 0, max_scroll)
	return max_scroll
end

local function reset_button(parts, setting, x, y)
	if setting.resettable then
		local name = "mm_reset_" .. setting.uid
		parts[#parts + 1] = button_text_style(name, RESET_TEXT)
		parts[#parts + 1] = "button[" .. x .. "," .. y .. ";" .. SETTINGS_RESET_W .. ",0.52;" .. name .. ";" .. esc(S("Reset")) .. "]"
	end
end

local function field_value(setting, value)
	if setting.type == "number" or setting.type == "int" then
		return number_text(value)
	end
	if setting.type == "bool" then
		return value and S("Yes") or S("No")
	end
	return tostring(value or "")
end

local function render_bool(parts, setting, value, x, y, w)
	local name = "mm_bool_" .. setting.uid
	local label = value and S("Yes") or S("No")
	local color = value and YES_TEXT or NO_TEXT
	parts[#parts + 1] = "style[" .. name .. ";border=true;bgcolor=" .. BUTTON_BG .. ";textcolor=" .. color .. ";bgcolor_hovered=" .. BUTTON_BG_HOVER .. "]"
	parts[#parts + 1] = "button[" .. x .. "," .. y .. ";" .. w .. ",0.52;" .. name .. ";" .. esc(label) .. "]"
end

local function render_setting(parts, setting, state, x, y, w, indent)
	indent = indent + (setting.indent or 0) * 0.35
	local label_x = x + indent
	local is_number = setting.type == "number" or setting.type == "int"
	local has_slider = is_number and setting.min ~= nil and setting.max ~= nil and setting.ui ~= "field"
	local reset_w = setting.resettable and SETTINGS_RESET_W or 0
	local reset_x = x + w - reset_w
	local control_w = math.min(has_slider and 5.65 or 4.8, math.max(2.85, w * 0.28))
	local control_x = reset_x - control_w - SETTINGS_CONTROL_GAP
	local label_w = math.max(2.4, control_x - label_x - SETTINGS_CONTROL_GAP)
	local value = current_value(state, setting)
	local help = setting_help_text(setting)
	local row_h = has_slider and (help ~= "" and 1.08 or 0.92) or (help ~= "" and 0.92 or 0.68)

	parts[#parts + 1] = "label[" .. label_x .. "," .. (y + 0.2) .. ";" .. esc(fit_text(setting.label, label_w)) .. "]"
	if help ~= "" then
		parts[#parts + 1] = "label[" .. (label_x + 0.15) .. "," .. (y + 0.52) .. ";" .. esc(fit_text(help, label_w - 0.15)) .. "]"
	end

	if setting.type == "bool" then
		if setting.ui == "dropdown" then
			parts[#parts + 1] = "dropdown[" .. control_x .. "," .. (y + 0.02) .. ";" .. control_w ..
				",0.52;" .. mod_menu._settings_field_name(setting) .. ";" .. esc(S("Yes")) .. "," ..
				esc(S("No")) .. ";" .. (value and 1 or 2) .. ";false]"
		else
			render_bool(parts, setting, value == true, control_x, y + 0.03, control_w)
		end
	elseif setting.type == "enum" then
		if setting.ui == "field" then
			parts[#parts + 1] = "field[" .. control_x .. "," .. y .. ";" .. control_w .. ",0.52;" ..
				mod_menu._settings_field_name(setting) .. ";;" .. esc(field_value(setting, value)) .. "]"
		else
			parts[#parts + 1] = "dropdown[" .. control_x .. "," .. (y + 0.02) .. ";" .. control_w ..
				",0.52;" .. mod_menu._settings_field_name(setting) .. ";" .. enum_items(setting.values) .. ";" ..
				enum_index(value, setting.values) .. ";false]"
		end
	elseif is_number then
		local show_slider = has_slider
		local show_field = setting.ui ~= "slider"
		local field_w = show_slider and show_field and 1.35 or control_w
		if show_field then
			parts[#parts + 1] = "field[" .. control_x .. "," .. y .. ";" .. field_w .. ",0.52;" ..
				mod_menu._settings_field_name(setting) .. ";;" .. esc(field_value(setting, value)) .. "]"
		end
		if show_slider then
			local slider_x = show_field and control_x + field_w + 0.18 or control_x
			local slider_w = show_field and math.max(0.9, control_w - field_w - 0.18) or control_w
			parts[#parts + 1] = "label[" .. slider_x .. "," .. (y + 0.04) .. ";" ..
				esc(S("Value: @1", field_value(setting, value))) .. "]"
			parts[#parts + 1] = "scrollbaroptions[min=0;max=1000;smallstep=10;largestep=100]"
			parts[#parts + 1] = "scrollbar[" .. slider_x .. "," .. (y + 0.36) .. ";" .. slider_w ..
				",0.22;horizontal;" .. mod_menu._settings_slider_name(setting) .. ";" ..
				mod_menu._settings_value_to_slider(setting, value) .. "]"
		end
	else
		parts[#parts + 1] = "field[" .. control_x .. "," .. y .. ";" .. control_w .. ",0.52;" ..
			mod_menu._settings_field_name(setting) .. ";;" .. esc(field_value(setting, value)) .. "]"
	end

	reset_button(parts, setting, reset_x, y + (has_slider and 0.2 or 0.03))
	return y + row_h
end

local function render_list_child(parts, list_item, child, entry, entry_index, x, y, w)
	local value = entry[child.key]
	if value == nil then
		value = child.default
	end
	local field_name = "mm_list_" .. list_item.uid .. "_" .. entry_index .. "_" .. child.uid
	local control_w = math.min(4.2, math.max(2.6, w * 0.25))
	local control_x = x + w - control_w
	parts[#parts + 1] = "label[" .. x .. "," .. (y + 0.2) .. ";" .. esc(child.label) .. "]"
	if child.type == "enum" then
		parts[#parts + 1] = "dropdown[" .. control_x .. "," .. (y + 0.02) .. ";" .. control_w .. ",0.52;" ..
			field_name .. ";" .. enum_items(child.values) .. ";" .. enum_index(value, child.values) .. ";false]"
	elseif child.type == "bool" then
		parts[#parts + 1] = "dropdown[" .. control_x .. "," .. (y + 0.02) .. ";" .. control_w .. ",0.52;" ..
			field_name .. ";" .. esc(S("Yes")) .. "," .. esc(S("No")) .. ";" .. (value and 1 or 2) .. ";false]"
	else
		parts[#parts + 1] = "field[" .. control_x .. "," .. y .. ";" .. control_w .. ",0.52;" ..
			field_name .. ";;" .. esc(field_value(child, value)) .. "]"
	end
	return y + 0.68
end

local function render_list(parts, setting, state, x, y, w, indent)
	local label_x = x + indent
	local list = current_value(state, setting)
	if type(list) ~= "table" then
		list = {}
	end
	parts[#parts + 1] = "label[" .. label_x .. "," .. (y + 0.2) .. ";" .. esc(setting.label) .. "]"
	local reset_x = x + w - SETTINGS_RESET_W
	parts[#parts + 1] = "button[" .. (reset_x - 1.7) .. "," .. (y + 0.03) .. ";1.55,0.52;mm_list_add_" ..
		setting.uid .. ";" .. esc(S("Add Entry")) .. "]"
	reset_button(parts, setting, reset_x, y + 0.03)
	y = y + 0.72
	for entry_index, entry in ipairs(list) do
		local entry_x = label_x + 0.35
		local entry_w = w - (entry_x - x)
		parts[#parts + 1] = "label[" .. entry_x .. "," .. (y + 0.2) .. ";" .. esc(S("Entry @1", entry_index)) .. "]"
		parts[#parts + 1] = "button[" .. (x + w - 1.15) .. "," .. (y + 0.03) .. ";1.15,0.52;mm_list_remove_" ..
			setting.uid .. "_" .. entry_index .. ";" .. esc(S("Remove")) .. "]"
		y = y + 0.62
		for _, child in ipairs(setting.entry or {}) do
			y = render_list_child(parts, setting, child, entry, entry_index, entry_x + 0.35, y, entry_w - 0.35)
		end
	end
	return y + 0.12
end

local render_settings_items

local function render_section(parts, section, state, x, y, w, query, indent)
	local label_x = x + indent
	local is_open = query ~= "" or state.open_sections[section.uid]
	local prefix = is_open and "- " or "+ "
	local has_reset = has_resettable_child(section)
	local button_w = math.max(1.6, math.min(5.2, w - indent - (has_reset and 1.5 or 0.2)))
	parts[#parts + 1] = "button[" .. label_x .. "," .. y .. ";" .. button_w ..
		",0.55;mm_section_" .. section.uid .. ";" .. esc(prefix .. section.label) .. "]"
	if has_reset then
		local reset_name = "mm_reset_section_" .. section.uid
		parts[#parts + 1] = button_text_style(reset_name, RESET_TEXT)
		parts[#parts + 1] = "button[" .. (label_x + button_w + 0.15) .. "," .. y .. ";" .. SETTINGS_RESET_W .. ",0.55;" ..
			reset_name .. ";" .. esc(S("Reset")) .. "]"
	end
	if section.description then
		parts[#parts + 1] = "label[" .. (label_x + 0.15) .. "," .. (y + 0.58) .. ";" .. esc(fit_text(section.description, w - indent - 0.4)) .. "]"
		y = y + 0.92
	else
		y = y + 0.68
	end
	if is_open then
		y = render_settings_items(parts, section.children, state, x, y, w, query, indent + 0.38)
	end
	return y + 0.08
end

render_settings_items = function(parts, items, state, x, y, w, query, indent)
	for _, item in ipairs(items or {}) do
		if item_matches(item, query) then
			if item.type == "section" then
				y = render_section(parts, item, state, x, y, w, query, indent)
			elseif item.type == "list" then
				y = render_list(parts, item, state, x, y, w, indent)
			else
				y = render_setting(parts, item, state, x, y, w, indent)
			end
		end
	end
	return y
end

local function tabheader_items(tabs)
	local items = {}
	for index, tab in ipairs(tabs or {}) do
		items[index] = esc(tab.label)
	end
	return table.concat(items, ",")
end

function mod_menu.build_settings_formspec(player_name, mod_id)
	local definition = mod_menu.registered_settings[mod_id]
	if not definition then
		return table.concat({
			"formspec_version[6]",
			"size[7,3]",
			"label[0.4,0.5;", esc(S("This mod has not registered settings.")), "]",
			"button[0.4,2.1;1.8,0.6;mod_menu_return;", esc(S("Back")), "]",
		})
	end

	local state = mod_menu.get_settings_form_state(player_name, mod_id)
	local layout = get_layout(player_name)
	local mod = mod_menu.find_mod(mod_id)
	local title = definition.title or ((mod and display_name(mod) or mod_id) .. " " .. S("Settings"))
	local status_by_player = mod_menu.settings_form_status[mod_id] or {}
	local status = status_by_player[player_name] or ""
	local margin = layout.margin
	local width = layout.width
	local height = layout.height
	local full_w = width - margin * 2
	local has_tabs = #definition.tabs > 1
	local header_h = has_tabs and 1.55 or 0.75
	local tabs_y = layout.top + 1.15
	local search_y = layout.top + header_h + 0.35
	local body_y = search_y + 0.78
	local footer_y = height - 0.85
	local body_h = math.max(4, footer_y - body_y - 0.15)
	local visible_h = body_h - SETTINGS_BODY_PAD * 2
	local scroll_w = full_w - SETTINGS_BODY_PAD * 2 - SETTINGS_SCROLLBAR_W - SETTINGS_SCROLLBAR_GAP
	local tab = definition.tabs[state.tab] or definition.tabs[1]
	local query = tostring(state.search or ""):lower()
	local content_parts = {}
	local content_y = 0.12

	content_y = render_settings_items(content_parts, tab.settings, state, 0, content_y, scroll_w, query, 0)
	if content_y <= 0.22 then
		content_parts[#content_parts + 1] = "label[0.2,0.3;" .. esc(S("No settings match search")) .. "]"
		content_y = 0.9
	end
	local max_scroll = clamp_settings_scroll(state, content_y + 0.16, visible_h)
	local show_scrollbar = max_scroll > 0

	return table.concat({
		"formspec_version[6]",
		"size[", width, ",", height, "]",
		"position[0.5,0.5]",
		"anchor[0.5,0.5]",
		"padding[0,0]",
		"no_prepend[]",
		"bgcolor[#151923;true]",
		"style_type[label;textcolor=#edf2ff]",
		button_style_type(),
		button_text_style("mm_search_button", SEARCH_TEXT),
		button_text_style("mm_reset_all", RESET_TEXT),
		"style_type[field;textcolor=#edf2ff;bgcolor=#222938]",
		"style_type[dropdown;textcolor=#111827]",
		"style_type[scrollbar;bgcolor=#2d3344]",
		"field_close_on_enter[mm_search;false]",
		"box[", margin, ",", layout.top, ";", full_w, ",", header_h, ";#222938FF]",
		"label[", margin + 0.25, ",", layout.top + 0.33, ";", esc(title), "]",
		status ~= "" and ("label[" .. (width - margin - 4.8) .. "," .. (layout.top + 0.33) .. ";" .. esc(status) .. "]") or "",
		has_tabs and ("tabheader[" .. margin .. "," .. tabs_y .. ";" .. full_w .. ",0.55;mm_tabs;" ..
			tabheader_items(definition.tabs) .. ";" .. state.tab .. ";false;false]") or "",
		"field[", margin, ",", search_y, ";", full_w - 1.4, ",0.6;mm_search;;", esc(state.search or ""), "]",
		"button[", width - margin - 1.2, ",", search_y, ";1.2,0.6;mm_search_button;", esc(S("Search")), "]",
		"box[", margin, ",", body_y, ";", full_w, ",", body_h, ";#1d2431FF]",
		"scroll_container[", margin + SETTINGS_BODY_PAD, ",", body_y + SETTINGS_BODY_PAD, ";", scroll_w, ",", visible_h,
			";mm_settings_scroll;vertical;", SETTINGS_SCROLL_FACTOR, ";", SETTINGS_BODY_PAD, "]",
		table.concat(content_parts),
		"scroll_container_end[]",
		show_scrollbar and ("scrollbaroptions[smallstep=7;largestep=" .. math.max(20, math.floor(visible_h / SETTINGS_SCROLL_FACTOR)) .. "]") or "",
		show_scrollbar and ("scrollbar[" .. (margin + full_w - SETTINGS_BODY_PAD - SETTINGS_SCROLLBAR_W) .. "," .. (body_y + SETTINGS_BODY_PAD) .. ";" ..
			SETTINGS_SCROLLBAR_W .. "," .. visible_h .. ";vertical;mm_settings_scroll;" .. (state.scroll or 0) .. "]") or "",
		"button[", margin, ",", footer_y + 0.05, ";2.0,0.6;mm_cancel;", esc(S("Cancel")), "]",
		"button[", margin + 2.2, ",", footer_y + 0.05, ";2.0,0.6;mm_reset_all;", esc(S("Reset All")), "]",
		"button[", width / 2 - 1.65, ",", footer_y + 0.05, ";3.3,0.6;mm_save_exit;", esc(S("Save & Exit")), "]",
		"button[", width - margin - 1.45, ",", footer_y + 0.05, ";1.45,0.6;mod_menu_return;", esc(S("Back")), "]",
	})
end

local function selected_admin_mod_from_state(mods, state)
	local selected_index = 0

	if state.admin_selected_id then
		for index, mod in ipairs(mods) do
			if mod.id == state.admin_selected_id then
				selected_index = index
				break
			end
		end
	end

	if selected_index == 0 and #mods > 0 then
		selected_index = 1
	end

	local mod = mods[selected_index]
	if mod then
		state.admin_selected_id = mod.id
	end

	return mod, selected_index
end

local function admin_table_values(mods, state)
	local values = {}
	local row_map = {}

	for index, mod in ipairs(mods) do
		values[#values + 1] = esc(display_name(mod))
		values[#values + 1] = esc(mod_menu.is_config_enabled(mod.id) and S("Enabled") or S("Disabled"))
		row_map[index] = mod.id
	end

	state.admin_row_map = row_map
	return table.concat(values, ",")
end

function mod_menu.build_admin_formspec(player_name)
	local state = mod_menu.get_state(player_name)
	local layout = get_layout(player_name)
	local mods = config_mods()
	local selected_mod, selected_index = selected_admin_mod_from_state(mods, state)
	local table_content = admin_table_values(mods, state)
	local selected_enabled = selected_mod and mod_menu.is_config_enabled(selected_mod.id)

	return table.concat({
		"formspec_version[6]",
		"size[", layout.width, ",", layout.height, "]",
		"position[0.5,0.5]",
		"anchor[0.5,0.5]",
		"padding[0,0]",
		"no_prepend[]",
		"bgcolor[#151923;true]",
		"style_type[label;textcolor=#edf2ff]",
		"style_type[button;border=false;bgcolor=#2d3344;textcolor=#edf2ff;bgcolor_hovered=#3f4a66]",
		"style_type[field;textcolor=#111827]",
		"style_type[table;textcolor=#edf2ff]",
		"box[", layout.margin, ",", layout.top, ";", layout.width - layout.margin * 2, ",0.75;#222938]",
		"label[", layout.margin + 0.25, ",", layout.top + 0.33, ";", esc(S("Mod Menu Admin")), "]",
		"checkbox[", layout.margin, ",", layout.search_y + 0.08, ";admin_allow_players;", esc(S("Allow players to open Mod Menu")), ";", mod_menu.players_allowed() and "true" or "false", "]",
		"button[", layout.width - layout.margin - 1.35, ",", layout.top + 0.1, ";1.35,0.55;admin_refresh;", esc(S("Refresh")), "]",
		"tablecolumns[text;text]",
		"table[", layout.margin, ",", layout.content_y, ";", layout.left_w, ",", layout.content_h, ";admin_list;", table_content, ";", selected_index, "]",
		"box[", layout.right_x, ",", layout.content_y, ";", layout.right_w, ",", layout.content_h, ";#1d2431]",
		"label[", layout.right_x + 0.3, ",", layout.content_y + 0.35, ";", esc(selected_mod and display_name(selected_mod) or S("No configurable mods")), "]",
		selected_mod and ("textarea[" .. layout.right_x + 0.3 .. "," .. layout.content_y + 0.85 .. ";" .. layout.right_w - 0.6 .. "," .. layout.content_h - 2.3 .. ";admin_details;;" .. esc(detail_text(selected_mod, true)) .. "]") or "",
		selected_mod and ("checkbox[" .. layout.right_x + 0.3 .. "," .. layout.footer_y - 0.65 .. ";admin_config_enabled;" .. esc(S("Allow this mod settings")) .. ";" .. (selected_enabled and "true" or "false") .. "]") or "",
		selected_mod and ("button[" .. layout.right_x + 0.3 .. "," .. layout.footer_y + 0.05 .. ";1.45,0.6;admin_save;" .. esc(S("Save")) .. "]") or "",
		"button[", layout.width - layout.margin - 3.05, ",", layout.footer_y + 0.05, ";1.45,0.6;admin_back;", esc(S("Back")), "]",
		"button_exit[", layout.width - layout.margin - 1.45, ",", layout.footer_y + 0.05, ";1.45,0.6;close;", esc(S("Close")), "]",
	})
end

function mod_menu.show_admin(player_name)
	core.show_formspec(player_name, mod_menu.ADMIN_FORMNAME, mod_menu.build_admin_formspec(player_name))
end

local function update_from_fields(state, fields)
	if fields.search ~= nil then
		state.search = fields.search
	end

	if fields.show_libraries ~= nil then
		state.show_libraries = mod_menu.checkbox_value(fields.show_libraries, state.show_libraries)
	end
end

local function handle_table_event(state, fields)
	if not fields.mod_list or not core.explode_table_event then
		return false
	end

	local event = core.explode_table_event(fields.mod_list)
	if (event.type == "CHG" or event.type == "DCL") and event.row > 0 and state.row_map and state.row_map[event.row] then
		local previous_id = state.selected_id
		state.selected_id = state.row_map[event.row]
		return previous_id ~= state.selected_id
	end

	return false
end

local function handle_admin_table_event(state, fields)
	if not fields.admin_list or not core.explode_table_event then
		return
	end

	local event = core.explode_table_event(fields.admin_list)
	if (event.type == "CHG" or event.type == "DCL") and event.row > 0 and state.admin_row_map and state.admin_row_map[event.row] then
		state.admin_selected_id = state.admin_row_map[event.row]
	end
end

local function current_settings_state(player_name, mod_id)
	local by_player = mod_menu.settings_form_state and mod_menu.settings_form_state[player_name]
	return by_player and by_player[mod_id] or nil
end

local function handle_settings_scroll_drag(player_name, mod_id, fields)
	if fields.mm_settings_scroll == nil or not mod_menu._settings_scrollbar_event then
		return false
	end

	local event = mod_menu._settings_scrollbar_event(fields.mm_settings_scroll)
	if not event or event.type ~= "CHG" then
		return false
	end

	-- Live vertical drag must not enter the normal update path: a server redraw
	-- during hold can drop the client's mouse capture and freeze the scrollbar.
	local state = current_settings_state(player_name, mod_id)
	if state and event.value ~= nil then
		state.scroll = event.value
	end
	return true
end

local function schedule_settings_redraw(player_name, mod_id, formname)
	local state = current_settings_state(player_name, mod_id)
	if not state or not core.after then
		return
	end

	state.slider_redraw_token = (state.slider_redraw_token or 0) + 1
	local token = state.slider_redraw_token

	core.after(0.2, function()
		local current = current_settings_state(player_name, mod_id)
		if not current or current.slider_redraw_token ~= token then
			return
		end
		if core.get_player_by_name and not core.get_player_by_name(player_name) then
			return
		end
		core.show_formspec(player_name, formname, mod_menu.build_settings_formspec(player_name, mod_id))
	end)
end

function mod_menu.handle_fields(player, formname, fields)
	if not player then
		return false
	end

	local player_name = player:get_player_name()

	if formname == mod_menu.FORMNAME then
		if not mod_menu.can_open(player_name) then
			return true
		end

		local state = mod_menu.get_state(player_name)
		update_from_fields(state, fields)

		if fields.sort_toggle then
			state.sort = state.sort == "asc" and "desc" or "asc"
		end

		if fields.refresh then
			mod_menu.reset_cache()
		end

		if handle_table_event(state, fields) then
			clear_detail_edit_state(state)
		end

		if fields.detail_edit_cancel then
			clear_detail_edit_state(state)
		elseif fields.detail_edit_save and state.detail_edit_id then
			if fields.detail_edit_text ~= nil then
				state.detail_draft = mod_menu.clean_detail_text(fields.detail_edit_text)
			end
			mod_menu.set_detail_override(state.detail_edit_id, state.detail_draft or "")
			clear_detail_edit_state(state)
		elseif fields.detail_edit_start and state.selected_id then
			local selected_mod = mod_menu.find_mod(state.selected_id)
			state.detail_edit_id = state.selected_id
			state.detail_draft = mod_menu.get_detail_override(state.selected_id) or detail_text(selected_mod, false)
		elseif fields.detail_edit_text ~= nil and state.detail_edit_id then
			state.detail_draft = mod_menu.clean_detail_text(fields.detail_edit_text)
		end

		if fields.configure and state.selected_id then
			mod_menu.open_settings(player_name, state.selected_id)
			return true
		end

		if not fields.quit then
			mod_menu.show(player_name)
		end

		return true
	end

	if formname == mod_menu.ADMIN_FORMNAME then
		if not mod_menu.can_admin(player_name) then
			return true
		end

		local state = mod_menu.get_state(player_name)
		if fields.admin_refresh then
			mod_menu.reset_cache()
		end
		if fields.admin_allow_players ~= nil then
			mod_menu.set_players_allowed(mod_menu.checkbox_value(fields.admin_allow_players, mod_menu.players_allowed()))
		end
		if fields.admin_save and state.admin_selected_id and fields.admin_config_enabled ~= nil then
			mod_menu.set_config_enabled(state.admin_selected_id, mod_menu.checkbox_value(fields.admin_config_enabled, true))
			mod_menu.reset_cache()
		end

		handle_admin_table_event(state, fields)

		if fields.admin_back then
			mod_menu.show(player_name)
		elseif not fields.quit then
			mod_menu.show_admin(player_name)
		end

		return true
	end

	if formname:sub(1, #mod_menu.CONFIG_FORM_PREFIX) == mod_menu.CONFIG_FORM_PREFIX then
		local mod_id = formname:sub(#mod_menu.CONFIG_FORM_PREFIX + 1)
		if handle_settings_scroll_drag(player_name, mod_id, fields) then
			return true
		end
		-- Live horizontal slider drag also has to bypass delayed redraws; otherwise
		-- the client can lose mouse capture and the thumb appears to freeze.
		if mod_menu.handle_settings_slider_drag and mod_menu.handle_settings_slider_drag(player_name, mod_id, fields) then
			return true
		end
		if fields.quit then
			mod_menu.reset_settings_form_state(player_name, mod_id)
			return true
		end
		if fields.mod_menu_return or fields.back or fields.mm_cancel then
			mod_menu.reset_settings_form_state(player_name, mod_id)
			mod_menu.show(player_name)
			return true
		end
		if fields.mm_save or fields.mm_save_exit then
			mod_menu.save_settings(player_name, mod_id, fields)
			mod_menu.reset_settings_form_state(player_name, mod_id)
			mod_menu.show(player_name)
			return true
		end

		local _, redraw, delayed_redraw = mod_menu.update_settings_draft_from_fields(player_name, mod_id, fields)
		if redraw == false then
			if delayed_redraw then
				schedule_settings_redraw(player_name, mod_id, formname)
			end
			return true
		end

		core.show_formspec(player_name, formname, mod_menu.build_settings_formspec(player_name, mod_id))
		return true
	end

	return false
end
