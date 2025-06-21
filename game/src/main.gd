extends Control

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const MapControl = preload("res://src/view/city_map_control.gd")
const Tools = preload("res://src/tools/tool_catalog.gd")
const Zones = preload("res://src/tools/zone_command.gd")
const Signs = preload("res://src/tools/sign_command.gd")
const Queries = preload("res://src/tools/query_info.gd")
const Landscapes = preload("res://src/tools/landscape_command.gd")
const Random = preload("res://src/simulation/sim_random.gd")
const GameRandom = preload("res://src/simulation/game_lcg_random.gd")
const Buildings = preload("res://src/tools/building_command.gd")
const Networks = preload("res://src/tools/network_command.gd")
const Hydro = preload("res://src/tools/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/onramp_command.gd")
const Tunnels = preload("res://src/tools/tunnel_command.gd")
const Highways = preload("res://src/tools/highway_command.gd")

var city: CityState
var current_document: Sc2File
var palette: Sc2Palette
var large_sprites: Sc2SpriteArchive
var overlay_mode := "city"
var reference_root := ""
var selected_group := 9
var selected_subtool := 0
var last_edit_command: Dictionary = {}
var pending_sign_tile := Vector2i(-1, -1)
var tool_random := Random.new(1)
var nuisance_random := GameRandom.new(Time.get_ticks_msec() | 1)

var map_view: CityMapControl
var city_label: Label
var details_label: Label
var status_label: Label
var file_dialog: FileDialog
var save_dialog: FileDialog
var save_button: Button
var group_selector: OptionButton
var tool_selector: OptionButton
var undo_button: Button
var sign_dialog: ConfirmationDialog
var sign_input: LineEdit
var query_dialog: AcceptDialog


func _ready() -> void:
	_build_interface()
	reference_root = ProjectSettings.globalize_path("res://../references").simplify_path()
	palette = Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MSTR.BMP"))
	if not palette.is_valid():
		_show_error(palette.load_error)
		return
	large_sprites = SpriteArchive.load_path(reference_root.path_join("DATA/LARGE.DAT"))
	if not large_sprites.is_valid():
		_show_error(large_sprites.parse_error)
		return

	var initial_city := reference_root.path_join("CITIES/STARTER.SC2")
	if FileAccess.file_exists(initial_city):
		_load_city(initial_city)
	else:
		_show_error("Choose an original SC2 or SCN file to start.")


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("101820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 20)
	root_margin.add_theme_constant_override("margin_top", 16)
	root_margin.add_theme_constant_override("margin_right", 20)
	root_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(root_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	root_margin.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)

	var title := Label.new()
	title.text = "SIMCITY 2000"
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var open_button := Button.new()
	open_button.text = "Open City"
	open_button.pressed.connect(_open_city_dialog)
	header.add_child(open_button)

	save_button = Button.new()
	save_button.text = "Save Copy"
	save_button.disabled = true
	save_button.pressed.connect(_open_save_dialog)
	header.add_child(save_button)

	var mode_bar := HBoxContainer.new()
	mode_bar.add_theme_constant_override("separation", 6)
	page.add_child(mode_bar)
	for mode in ["city", "structures", "zones", "power", "water"]:
		var button := Button.new()
		button.text = mode.capitalize()
		button.pressed.connect(_set_overlay.bind(mode))
		mode_bar.add_child(button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	page.add_child(content)

	var map_panel := PanelContainer.new()
	map_panel.custom_minimum_size = Vector2(640, 640)
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(map_panel)

	map_view = MapControl.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.selection_completed.connect(_apply_map_selection)
	map_panel.add_child(map_view)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(295, 0)
	sidebar.add_theme_constant_override("separation", 12)
	content.add_child(sidebar)

	city_label = Label.new()
	city_label.text = "No city loaded"
	city_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	city_label.add_theme_font_size_override("font_size", 26)
	sidebar.add_child(city_label)

	details_label = Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.add_theme_font_size_override("font_size", 18)
	sidebar.add_child(details_label)

	var tool_heading := Label.new()
	tool_heading.text = "City Tool"
	tool_heading.add_theme_font_size_override("font_size", 20)
	sidebar.add_child(tool_heading)

	group_selector = OptionButton.new()
	for group_index in Tools.GROUPS.size():
		group_selector.add_item(Tools.GROUPS[group_index].name, group_index)
	group_selector.item_selected.connect(_select_tool_group)
	sidebar.add_child(group_selector)

	tool_selector = OptionButton.new()
	tool_selector.item_selected.connect(_select_subtool)
	sidebar.add_child(tool_selector)

	undo_button = Button.new()
	undo_button.text = "Undo Last Edit"
	undo_button.disabled = true
	undo_button.pressed.connect(_undo_last_edit)
	sidebar.add_child(undo_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("9db2c5"))
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(status_label)

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.SC2, *.sc2", "SimCity 2000 cities")
	file_dialog.add_filter("*.SCN, *.scn", "SimCity 2000 scenarios")
	file_dialog.file_selected.connect(_load_city)
	add_child(file_dialog)

	save_dialog = FileDialog.new()
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.add_filter("*.SC2, *.sc2", "SimCity 2000 cities")
	save_dialog.file_selected.connect(_save_copy)
	add_child(save_dialog)

	sign_dialog = ConfirmationDialog.new()
	sign_dialog.title = "City Sign"
	sign_dialog.dialog_text = "Enter sign text. An empty value removes the sign."
	sign_dialog.min_size = Vector2i(440, 170)
	sign_dialog.confirmed.connect(_commit_sign)
	sign_dialog.canceled.connect(_cancel_sign)
	sign_input = LineEdit.new()
	sign_input.max_length = 23
	sign_input.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sign_input.offset_left = 14
	sign_input.offset_top = 58
	sign_input.offset_right = -14
	sign_input.offset_bottom = 92
	sign_dialog.add_child(sign_input)
	add_child(sign_dialog)

	query_dialog = AcceptDialog.new()
	query_dialog.title = "Query"
	query_dialog.min_size = Vector2i(500, 440)
	add_child(query_dialog)

	group_selector.select(selected_group)
	_select_tool_group(selected_group)


func _open_city_dialog() -> void:
	var city_directory := ProjectSettings.globalize_path("res://../references/CITIES")
	if DirAccess.dir_exists_absolute(city_directory):
		file_dialog.current_dir = city_directory
	file_dialog.popup_centered_ratio(0.8)


func _open_save_dialog() -> void:
	if current_document == null:
		return
	var save_directory := ProjectSettings.globalize_path("user://cities")
	DirAccess.make_dir_recursive_absolute(save_directory)
	save_dialog.current_dir = save_directory
	save_dialog.current_file = current_document.source_path.get_file().get_basename() + ".SC2"
	save_dialog.popup_centered_ratio(0.8)


func _load_city(path: String) -> void:
	var document := Sc2Document.load_path(path)
	if not document.is_valid():
		_show_error(document.parse_error)
		return

	var loaded_city := CityModel.from_document(document)
	if not loaded_city.is_valid():
		_show_error(loaded_city.load_error)
		return

	city = loaded_city
	current_document = document
	last_edit_command = {}
	undo_button.disabled = true
	save_button.disabled = false
	city_label.text = (
		city.city_name() if not city.city_name().is_empty() else path.get_file().get_basename()
	)
	_refresh_details()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Loaded %s\nMap view: %s" % [path.get_file(), overlay_mode.capitalize()]
	_refresh_map()
	_update_edit_state()


func _save_copy(path: String) -> void:
	if current_document == null:
		_show_error("No city is loaded.")
		return
	var output_path := path
	if output_path.get_extension().is_empty():
		output_path += ".SC2"
	output_path = output_path.simplify_path()
	if output_path == reference_root or output_path.begins_with(reference_root + "/"):
		_show_error("Choose a location outside the read-only references directory.")
		return

	var serialized := current_document.serialize()
	if not serialized.ok:
		_show_error(serialized.error)
		return
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		_show_error("Cannot open save output: %s" % error_string(FileAccess.get_open_error()))
		return
	output.store_buffer(serialized.data)
	output.flush()
	var write_error := output.get_error()
	output.close()
	if write_error != OK:
		_show_error("Cannot write save output: %s" % error_string(write_error))
		return
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Saved city copy\n%s" % output_path


func _set_overlay(mode: String) -> void:
	overlay_mode = mode
	_update_edit_state()
	if city != null:
		status_label.text = "Map view: %s" % overlay_mode.capitalize()
		_refresh_map()


func _refresh_map() -> void:
	if city == null or palette == null:
		return
	var image: Image
	if overlay_mode == "city":
		var rendered := IsometricRenderer.create_image(city, palette, large_sprites)
		if not rendered.ok:
			_show_error(rendered.error)
			return
		image = rendered.image
	else:
		image = Minimap.create_image(city, palette, overlay_mode)
	map_view.set_city_view(city, ImageTexture.create_from_image(image))


func _select_tool_group(index: int) -> void:
	selected_group = group_selector.get_item_id(index)
	tool_selector.clear()
	var group := Tools.group(selected_group)
	for subtool_index in group.tools.size():
		var tool := Tools.tool(selected_group, subtool_index)
		var price := "Free" if tool.cost == 0 else "$%s" % _format_number(tool.cost)
		tool_selector.add_item("%s — %s" % [tool.name, price], subtool_index)
	selected_subtool = 0
	tool_selector.select(0)
	_update_edit_state()


func _select_subtool(index: int) -> void:
	selected_subtool = tool_selector.get_item_id(index)
	_update_edit_state()


func _update_edit_state() -> void:
	if map_view == null:
		return
	var is_zone_tool := Zones.supports_tool(selected_group, selected_subtool)
	var is_landscape_tool := Landscapes.supports_tool(selected_group, selected_subtool)
	var is_building_tool := Buildings.supports_tool(selected_group, selected_subtool)
	var is_network_tool := Networks.supports_tool(selected_group, selected_subtool)
	var is_hydro_tool := Hydro.supports_tool(selected_group, selected_subtool)
	var is_subway_to_rail_tool := SubwayToRail.supports_tool(selected_group, selected_subtool)
	var is_onramp_tool := Onramps.supports_tool(selected_group, selected_subtool)
	var is_tunnel_tool := Tunnels.supports_tool(selected_group, selected_subtool)
	var is_highway_tool := Highways.supports_tool(selected_group, selected_subtool)
	var is_sign_tool := selected_group == 15
	var is_query_tool := selected_group == 16
	var is_center_tool := selected_group == 17
	map_view.set_edit_enabled(
		city != null
		and overlay_mode == "city"
		and (
			is_zone_tool
			or is_landscape_tool
			or is_building_tool
			or is_network_tool
			or is_hydro_tool
			or is_subway_to_rail_tool
			or is_onramp_tool
			or is_tunnel_tool
			or is_highway_tool
			or is_sign_tool
			or is_query_tool
			or is_center_tool
		),
		"rectangle" if is_zone_tool else ("path" if is_landscape_tool or is_network_tool or is_highway_tool else "point"),
	)
	if city == null or status_label == null:
		return
	var tool := Tools.tool(selected_group, selected_subtool)
	status_label.remove_theme_color_override("font_color")
	if is_zone_tool:
		status_label.text = "%s selected. Drag on the city map to zone. Use the mouse wheel to zoom and the right or middle button to pan." % tool.name
	elif is_landscape_tool:
		status_label.text = "%s selected. Click or drag across eligible city tiles." % tool.name
	elif is_building_tool:
		status_label.text = "%s selected. Click a clear city site to build it." % tool.name
	elif is_network_tool:
		status_label.text = "%s selected. Drag between city tiles to build a route." % tool.name
	elif is_hydro_tool:
		status_label.text = "Hydroelectric Power Plant selected. Click an unused waterfall tile."
	elif is_subway_to_rail_tool:
		status_label.text = "Subway-to-Rail Connection selected. Click beside a rail or subway."
	elif is_onramp_tool:
		status_label.text = "On-ramp selected. Click on clear terrain between a highway and a perpendicular road."
	elif is_tunnel_tool:
		status_label.text = "Tunnel selected. Click a cardinal slope that faces through a hill."
	elif is_highway_tool:
		status_label.text = "Highway selected. Drag between city tiles to build a two-tile-wide route."
	elif is_sign_tool:
		status_label.text = "Place Sign selected. Click a city tile to add, edit, or remove a user sign."
	elif is_query_tool:
		status_label.text = "Query selected. Click a city tile to inspect it."
	elif is_center_tool:
		status_label.text = "Center View selected. Click a city tile to center the map on it."
	else:
		status_label.text = "%s is in the original tool catalog. Its command is not implemented yet." % tool.name


func _apply_map_selection(
	start: Vector2i, finish: Vector2i, path: Array[Vector2i]
) -> void:
	if city == null:
		return
	if selected_group == 17:
		if map_view.center_on_tile(finish):
			status_label.remove_theme_color_override("font_color")
			status_label.text = "Centered the map on tile %d, %d." % [finish.x, finish.y]
		return
	if selected_group == 16:
		_open_query(finish)
		return
	if selected_group == 15:
		_open_sign_dialog(finish)
		return
	if Landscapes.supports_tool(selected_group, selected_subtool):
		var landscape := Landscapes.apply_path(
			city, selected_group, selected_subtool, path, tool_random
		)
		if not landscape.ok:
			_show_error(
				"Cannot apply %s: %s"
				% [Tools.tool(selected_group, selected_subtool).name, landscape.error]
			)
			return
		last_edit_command = landscape
		undo_button.disabled = false
		_refresh_details()
		_refresh_map()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "%s changed %d path tiles for $%s." % [
			Tools.tool(selected_group, selected_subtool).name,
			landscape.tile_indices.size(),
			_format_number(landscape.cost),
		]
		if landscape.skipped_insufficient > 0:
			status_label.text += " Funds were not sufficient for %d later path tiles." % landscape.skipped_insufficient
		return
	if Networks.supports_tool(selected_group, selected_subtool):
		var network := Networks.apply(city, selected_group, selected_subtool, start, finish)
		if not network.ok:
			_show_error(
				"Cannot build %s: %s"
				% [Tools.tool(selected_group, selected_subtool).name, network.error]
			)
			return
		last_edit_command = network
		undo_button.disabled = false
		_refresh_details()
		_refresh_map()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built %d %s tiles for $%s." % [
			network.points.size(),
			Tools.tool(selected_group, selected_subtool).name,
			_format_number(network.cost),
		]
		if network.stopped_early:
			status_label.text += " The route stopped at an obstruction."
		return
	if Hydro.supports_tool(selected_group, selected_subtool):
		var hydro := Hydro.apply(city, selected_group, selected_subtool, finish, tool_random)
		if not hydro.ok:
			_show_error("Cannot build hydroelectric power: %s" % hydro.error)
			return
		last_edit_command = hydro
		undo_button.disabled = false
		_refresh_details()
		_refresh_map()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built hydroelectric power for $%s." % _format_number(hydro.cost)
		return
	if SubwayToRail.supports_tool(selected_group, selected_subtool):
		var connection := SubwayToRail.apply(city, selected_group, selected_subtool, finish)
		if not connection.ok:
			_show_error("Cannot build subway-to-rail connection: %s" % connection.error)
			return
		last_edit_command = connection
		undo_button.disabled = false
		_refresh_map()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built a subway-to-rail connection at no charge. Listed cost: $%s." % _format_number(connection.listed_cost)
		return
	if Onramps.supports_tool(selected_group, selected_subtool):
		var onramp := Onramps.apply(city, selected_group, selected_subtool, finish)
		if not onramp.ok:
			_show_error("Cannot build on-ramp: %s" % onramp.error)
			return
		last_edit_command = onramp
		undo_button.disabled = false
		_refresh_details()
		_refresh_map()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built an on-ramp for $%s." % _format_number(onramp.cost)
		return
	if Tunnels.supports_tool(selected_group, selected_subtool):
		var tunnel := Tunnels.apply(city, selected_group, selected_subtool, finish)
		if not tunnel.ok:
			_show_error("Cannot build tunnel: %s" % tunnel.error)
			return
		last_edit_command = tunnel
		undo_button.disabled = false
		_refresh_details()
		_refresh_map()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built a %d-tile tunnel for $%s." % [
			tunnel.points.size(), _format_number(tunnel.cost)
		]
		return
	if Highways.supports_tool(selected_group, selected_subtool):
		var highway := Highways.apply(city, selected_group, selected_subtool, start, finish)
		if not highway.ok:
			_show_error("Cannot build highway: %s" % highway.error)
			return
		last_edit_command = highway
		undo_button.disabled = false
		_refresh_details()
		_refresh_map()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built %d highway sections for $%s." % [
			highway.sections.size(), _format_number(highway.cost)
		]
		if highway.stopped_early:
			status_label.text += " The route stopped at an obstruction."
		return
	if Buildings.supports_tool(selected_group, selected_subtool):
		var building := Buildings.apply(
			city, selected_group, selected_subtool, finish, nuisance_random, tool_random
		)
		if not building.ok:
			_show_error(
				"Cannot build %s: %s"
				% [Tools.tool(selected_group, selected_subtool).name, building.error]
			)
			return
		last_edit_command = building
		undo_button.disabled = false
		_refresh_details()
		_refresh_map()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built %s for $%s." % [
			Tools.tool(selected_group, selected_subtool).name,
			_format_number(building.cost),
		]
		return
	var command := Zones.apply_rectangle(city, selected_group, selected_subtool, start, finish)
	if not command.ok:
		_show_error("Cannot apply %s: %s" % [Tools.tool(selected_group, selected_subtool).name, command.error])
		return
	command["command_type"] = "zone"
	last_edit_command = command
	undo_button.disabled = false
	_refresh_details()
	_refresh_map()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "%s changed %d tiles for $%s." % [
		Tools.tool(selected_group, selected_subtool).name,
		command.tile_indices.size(),
		_format_number(command.cost),
	]


func _undo_last_edit() -> void:
	if city == null or last_edit_command.is_empty():
		return
	var command_type: String = last_edit_command.get("command_type", "")
	var result: Dictionary
	if command_type == "sign":
		result = Signs.undo(city, last_edit_command)
	elif command_type == "landscape":
		result = Landscapes.undo(city, last_edit_command, tool_random)
	elif command_type == "building":
		result = Buildings.undo(city, last_edit_command, nuisance_random, tool_random)
	elif command_type == "network":
		result = Networks.undo(city, last_edit_command)
	elif command_type == "hydro":
		result = Hydro.undo(city, last_edit_command, tool_random)
	elif command_type == "subway_to_rail":
		result = SubwayToRail.undo(city, last_edit_command)
	elif command_type == "onramp":
		result = Onramps.undo(city, last_edit_command)
	elif command_type == "tunnel":
		result = Tunnels.undo(city, last_edit_command)
	elif command_type == "highway":
		result = Highways.undo(city, last_edit_command)
	else:
		result = Zones.undo(city, last_edit_command)
	if not result.ok:
		_show_error("Cannot undo the last edit: %s" % result.error)
		return
	last_edit_command = {}
	undo_button.disabled = true
	_refresh_details()
	_refresh_map()
	status_label.remove_theme_color_override("font_color")
	if command_type == "sign":
		status_label.text = "Restored the previous sign."
	elif command_type == "landscape":
		status_label.text = "Restored %d landscape actions and the previous funds value." % result.restored_tiles
	elif command_type == "building":
		status_label.text = "Removed the last building and restored %d tiles." % result.restored_tiles
	elif command_type == "network":
		status_label.text = "Restored the previous route across %d tiles." % result.restored_tiles
	elif command_type == "hydro":
		status_label.text = "Removed the last hydroelectric plant."
	elif command_type == "subway_to_rail":
		status_label.text = "Removed the last subway-to-rail connection."
	elif command_type == "onramp":
		status_label.text = "Removed the last on-ramp."
	elif command_type == "tunnel":
		status_label.text = "Removed the last tunnel."
	elif command_type == "highway":
		status_label.text = "Restored the previous highway route across %d tiles." % result.restored_tiles
	else:
		status_label.text = "Restored %d tiles and the previous funds value." % result.restored_tiles


func _open_sign_dialog(point: Vector2i) -> void:
	var overlay := city.text_overlay_id(point.x, point.y)
	if overlay > Signs.LAST_USER_LABEL:
		_show_error("This tile has a protected simulation label.")
		return
	pending_sign_tile = point
	sign_input.text = city.label(overlay) if overlay > 0 else ""
	sign_dialog.popup_centered()
	sign_input.grab_focus()
	sign_input.select_all()


func _commit_sign() -> void:
	if city == null or pending_sign_tile.x < 0:
		return
	var result := Signs.set_sign(city, pending_sign_tile, sign_input.text)
	pending_sign_tile = Vector2i(-1, -1)
	if not result.ok:
		_show_error("Cannot change sign: %s" % result.error)
		return
	last_edit_command = result
	undo_button.disabled = false
	_refresh_map()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Sign removed." if result.new_overlay == 0 else "Sign saved as label %d." % result.label_id


func _cancel_sign() -> void:
	pending_sign_tile = Vector2i(-1, -1)


func _open_query(point: Vector2i) -> void:
	var result := Queries.inspect(city, point)
	if not result.ok:
		_show_error("Cannot query tile: %s" % result.error)
		return
	query_dialog.dialog_text = Queries.format_text(result)
	query_dialog.popup_centered()


func _refresh_details() -> void:
	if city == null:
		return
	var demand := city.rci_demand()
	details_label.text = (
		"Mayor: %s\nDate: %04d-%02d-%02d\nPopulation: %s\nFunds: $%s\n\nDemand\nR: %+d\nC: %+d\nI: %+d"
		% [
			city.mayor_name() if not city.mayor_name().is_empty() else "Unknown",
			city.current_year(),
			city.current_month(),
			city.current_day(),
			_format_number(city.population()),
			_format_number(city.funds()),
			demand.x,
			demand.y,
			demand.z,
		]
	)


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("ff877d"))


func _format_number(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var output := ""
	while digits.length() > 3:
		output = "," + digits.right(3) + output
		digits = digits.left(digits.length() - 3)
	output = digits + output
	return "-" + output if negative else output
