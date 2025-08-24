extends Control

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const PeBitmap = preload("res://src/assets/pe_bitmap_resource.gd")
const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const RenderJob = preload("res://src/view/city_render_job.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const MapControl = preload("res://src/view/city_map_control.gd")
const Tools = preload("res://src/tools/tool_catalog.gd")
const ToolAvailability = preload("res://src/tools/tool_availability.gd")
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
const Demolish = preload("res://src/tools/demolish_command.gd")
const TerrainTools = preload("res://src/tools/terrain_command.gd")
const Dispatch = preload("res://src/tools/dispatch_command.gd")
const CityRotation = preload("res://src/tools/city_rotation_command.gd")
const Simulation = preload("res://src/simulation/simulation_engine.gd")
const GameSpeed = preload("res://src/simulation/game_speed_controller.gd")
const DisasterStart = preload("res://src/simulation/disaster_start_phase.gd")
const Budget = preload("res://src/simulation/budget_phase.gd")
const Bonds = preload("res://src/simulation/bond_command.gd")
const RciAftermath = preload("res://src/simulation/rci_aftermath_phase.gd")

const NEWS_NAMES := {
	1: "Local news",
	4: "New invention",
	5: "New innovation",
	6: "War report",
	7: "Market report",
	8: "Sports report",
	9: "Federal rate increase",
	10: "Federal rate decrease",
	0x0b: "Political report",
	0x0c: "Diplomatic report",
	0x0d: "Disaster report",
	0x0e: "Medical report",
	0x0f: "Upbeat report",
	0x10: "High crime",
	0x11: "High traffic",
	0x12: "High pollution",
	0x13: "Poor education",
	0x14: "Poor health",
	0x15: "Poor employment",
	3: "City milestone",
	0x24: "Power plant report",
	0x26: "Education report",
	39: "Bridge collapse",
	0x29: "New ordinance",
	0x3d: "Low crime",
	0x3e: "Low traffic",
	0x3f: "Low pollution",
	0x40: "Good education",
	0x41: "Good health",
	0x42: "Good employment",
	0x1f8: "Explosion",
	0x1fe: "Traffic report",
	0x201: "High mayor approval",
	0x202: "Monster attack",
	0x203: "Air disaster",
	0x205: "Cargo ship report",
	0x206: "Airplane takeoff",
	0x207: "Airplane landing",
	0x20c: "Train report",
	0x20f: "Sailboat distress",
	0x211: "Arcology launch",
	0x212: "Arcology launch complete",
}

const BUDGET_NAMES := [
	"Residential Tax",
	"Commercial Tax",
	"Industrial Tax",
	"Ordinances",
	"Bonds",
	"Police",
	"Fire",
	"Health",
	"School",
	"College",
	"Road",
	"Highway",
	"Bridge",
	"Rail",
	"Subway",
	"Tunnel",
]
const MAP_DISPLAY_MODES := ["city", "underground", "structures", "zones", "power", "water"]

var city: CityState
var current_document: Sc2File
var palette: Sc2Palette
var palette_index_encoding: Sc2Palette
var large_sprites: Sc2SpriteArchive
var small_medium_sprites: Sc2SpriteArchive
var overlay_mode := "city"
var reference_root := ""
var selected_group := 9
var selected_subtool := 0
var selected_tool_available := false
var last_edit_command: Dictionary = {}
var pending_sign_tile := Vector2i(-1, -1)
var tool_random := Random.new(1)
var nuisance_random := GameRandom.new(Time.get_ticks_msec() | 1)
var dispatch_cycles := PackedInt32Array([0, 0, 0])
var dispatch_initialized := false
var simulation_engine: SimulationEngine
var speed_controller: GameSpeedController
var simulation_map_dirty := false
var recent_news := PackedStringArray()
var annual_budget_pending := false
var military_proposal_pending := false
var game_over_active := false
var static_city_image: Image
var static_occlusion_commands: Array[Dictionary] = []
var static_occlusion_grid: Dictionary = {}
var static_visual_signature: Array = []
var static_render_mode := ""
var static_display_city: CityState
var static_view_cache: Dictionary = {}
var dynamic_sprite_cache: Dictionary = {}
var dynamic_foreground_cache: Dictionary = {}
var static_render_thread: Thread
var static_render_job: CityRenderJob
var static_render_epoch := 0
var palette_cycle_ticks := 0
var palette_cycle_texture: ImageTexture

var map_view: CityMapControl
var city_label: Label
var details_label: Label
var status_label: Label
var file_dialog: FileDialog
var save_dialog: FileDialog
var save_button: Button
var budget_button: Button
var group_selector: OptionButton
var tool_selector: OptionButton
var undo_button: Button
var speed_selector: OptionButton
var news_label: Label
var title_stats_label: Label
var fps_label: Label
var zoom_label: Label
var zoom_in_button: Button
var zoom_out_button: Button
var rotate_counter_clockwise_button: Button
var rotate_clockwise_button: Button
var toolbar_buttons: Array[Button] = []
var sidebar_panel: PanelContainer
var sidebar_toggle_button: Button
var sign_dialog: ConfirmationDialog
var sign_input: LineEdit
var bridge_dialog: ConfirmationDialog
var bridge_choice_buttons: Array[Button] = []
var pending_bridge_request: Dictionary = {}
var tool_choice_dialog: ConfirmationDialog
var tool_choice_buttons: Array[Button] = []
var pending_tool_choices: Dictionary = {}
var stadium_dialog: ConfirmationDialog
var stadium_team_selector: OptionButton
var stadium_name_input: LineEdit
var pending_stadium_command: Dictionary = {}
var highway_connection_dialog: ConfirmationDialog
var pending_highway_connection: Dictionary = {}
var tunnel_dialog: ConfirmationDialog
var pending_tunnel_request: Dictionary = {}
var query_dialog: AcceptDialog
var sound_player: AudioStreamPlayer
var budget_dialog: ConfirmationDialog
var budget_notice_label: Label
var budget_controls: Array[SpinBox] = []
var auto_budget_check: CheckBox
var bond_summary_label: Label
var issue_bond_button: Button
var repay_bond_button: Button
var bond_dialog: ConfirmationDialog
var pending_bond_action := ""
var game_over_dialog: AcceptDialog
var military_dialog: ConfirmationDialog
var fps_update_seconds := 0.0


func _ready() -> void:
	reference_root = ProjectSettings.globalize_path("res://../references").simplify_path()
	var toolbar_resource := PeBitmap.load_numeric(
		reference_root.path_join("SIMCITY.EXE"), 2
	)
	var toolbar_art: Image = toolbar_resource.get("image") as Image if toolbar_resource.ok else null
	_build_interface(toolbar_art)
	palette = Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MSTR.BMP"))
	if not palette.is_valid():
		_show_error(palette.load_error)
		return
	palette_index_encoding = Palette.index_encoding()
	_update_palette_cycle_texture()
	large_sprites = SpriteArchive.load_path(reference_root.path_join("DATA/LARGE.DAT"))
	if not large_sprites.is_valid():
		_show_error(large_sprites.parse_error)
		return
	var base_small_medium := SpriteArchive.load_path(
		reference_root.path_join("DATA/SMALLMED.DAT")
	)
	if not base_small_medium.is_valid():
		_show_error(base_small_medium.parse_error)
		return
	var special_sprites := SpriteArchive.load_path(
		reference_root.path_join("DATA/SPECIAL.DAT")
	)
	if not special_sprites.is_valid():
		_show_error(special_sprites.parse_error)
		return
	small_medium_sprites = SpriteArchive.combine([base_small_medium, special_sprites])

	var initial_city := reference_root.path_join("CITIES/STARTER.SC2")
	if FileAccess.file_exists(initial_city):
		_load_city(initial_city)
	else:
		_show_error("Choose an original SC2 or SCN file to start.")


func _process(delta: float) -> void:
	_update_fps(delta)
	_poll_static_render()
	if speed_controller == null or city == null:
		return
	var interaction_suspended := (
		(map_view != null and map_view.is_left_drag_active())
		or budget_dialog.visible
		or bridge_dialog.visible
		or tool_choice_dialog.visible
		or stadium_dialog.visible
		or highway_connection_dialog.visible
		or tunnel_dialog.visible
		or bond_dialog.visible
		or military_dialog.visible
		or game_over_active
	)
	var result := speed_controller.advance_time(
		delta * 1000.0,
		Time.get_ticks_msec(),
		interaction_suspended
	)
	if not result.ok:
		speed_controller.set_speed(GameSpeed.Speed.PAUSED)
		speed_selector.select(0)
		_show_error("Simulation stopped: %s" % result.error)
		return
	if (
		result.base_ticks > 0
		and speed_controller.speed != GameSpeed.Speed.PAUSED
		and not interaction_suspended
	):
		palette_cycle_ticks += int(result.base_ticks)
		_update_palette_cycle_texture()

	_consume_simulation_result(result)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or map_view == null:
		return
	if event.keycode == KEY_PLUS or event.keycode == KEY_EQUAL:
		if map_view.zoom_in():
			get_viewport().set_input_as_handled()
	elif event.keycode == KEY_MINUS:
		if map_view.zoom_out():
			get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Q:
		_rotate_city(true)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_W:
		_rotate_city(false)
		get_viewport().set_input_as_handled()


func _consume_simulation_result(result: Dictionary) -> void:
	var ran_days: bool = not result.day_results.is_empty()
	var changed_disaster_map := false
	for disaster in result.disaster_results:
		if disaster.get("map_changed", false):
			changed_disaster_map = true
			break
	var moved_things := _moving_things_are_active(result.moving_results)
	if ran_days or moved_things or changed_disaster_map:
		last_edit_command = {}
		undo_button.disabled = true
		simulation_map_dirty = true
	if ran_days:
		_refresh_details()

	var force_refresh: bool = (
		not result.effect_events.is_empty()
		or not result.view_center_requests.is_empty()
	)
	var map_refresh_requested: bool = simulation_map_dirty and (
		result.base_ticks > 0 or force_refresh
	)
	if map_refresh_requested:
		_refresh_map(false)
		simulation_map_dirty = false
	elif result.base_ticks > 0:
		_refresh_moving_things()
	for point in result.view_center_requests:
		map_view.center_on_tile(point)
	if not result.effect_events.is_empty() or not result.sound_events.is_empty():
		_show_effect_events(result.effect_events, result.sound_events)
	if not result.news_items.is_empty():
		_show_news_items(result.news_items)
	if not result.game_over_events.is_empty():
		_show_game_over_events(result.game_over_events)
	for request in result.interaction_requests:
		if request.get("type", "") == "annual_budget":
			_open_budget_dialog(request.get("funding_values", PackedInt32Array()), true)
		elif request.get("type", "") == "military_proposal":
			_open_military_proposal()


func _build_interface(toolbar_art: Image) -> void:
	theme = _create_classic_theme()
	var background := ColorRect.new()
	background.color = Color("c0c0c0")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)

	var menu_bar := PanelContainer.new()
	menu_bar.custom_minimum_size = Vector2(0, 27)
	menu_bar.add_theme_stylebox_override("panel", _classic_box(Color("c0c0c0"), Color("ffffff"), 0))
	page.add_child(menu_bar)
	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 0)
	menu_bar.add_child(menu_row)
	_add_menu(menu_row, "File", [
		["Open City...", 0], ["Save City As...", 1], ["Exit", 2],
	], _on_file_menu)
	_add_menu(menu_row, "Speed", [
		["Pause", 0], ["Turtle", 1], ["Llama", 2], ["Cheetah", 3],
		["African Swallow", 4],
	], _on_speed_menu)
	_add_menu(menu_row, "Options", [
		["City View", 0], ["Underground View", 1], ["Structures Map", 2],
		["Zones Map", 3], ["Power Map", 4], ["Water Map", 5],
	], _on_options_menu)
	var disasters_menu := _add_menu(menu_row, "Disasters", [
		["Fire", 1], ["Flood", 2], ["Riot", 3], ["Toxic Spill", 4],
		["Air Crash", 5], ["Earthquake", 6], ["Tornado", 7], ["Monster", 8],
		["Meltdown", 9], ["Microwave", 10], ["Volcano", 11], ["Firestorm", 12],
		["Mass Riots", 13], ["Mass Floods", 14], ["Pollution", 15],
		["Hurricane", 16], ["Helicopter Crash", 17], ["Plane Crash", 18],
	], _on_disaster_menu)
	var implemented_disasters := {
		1: true, 2: true, 3: true, 4: true, 5: true, 6: true, 7: true, 8: true,
		9: true, 10: true, 11: true, 12: true, 13: true, 14: true, 15: true,
		16: true, 17: true, 18: true,
	}
	for item_index in disasters_menu.get_popup().item_count:
		var disaster_id := disasters_menu.get_popup().get_item_id(item_index)
		disasters_menu.get_popup().set_item_disabled(
			item_index, not implemented_disasters.has(disaster_id)
		)
	disasters_menu.tooltip_text = (
		"Air Crash and Helicopter Crash do nothing when selected, as in the original Windows game."
	)
	_add_menu(menu_row, "Windows", [["Budget", 0], ["City Information", 1]], _on_windows_menu)
	_add_menu(menu_row, "Newspaper", [["Show Latest Reports", 0]], _on_newspaper_menu)
	_add_menu(menu_row, "Help", [["City Window Help", 0]], _on_help_menu)

	var title_bar := ColorRect.new()
	title_bar.color = Color("000080")
	title_bar.custom_minimum_size = Vector2(0, 28)
	page.add_child(title_bar)
	var title_row := HBoxContainer.new()
	title_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_row.offset_left = 6
	title_row.offset_right = -6
	title_bar.add_child(title_row)
	city_label = Label.new()
	city_label.text = "OpenSC2K — No city loaded"
	city_label.add_theme_color_override("font_color", Color.WHITE)
	city_label.add_theme_font_size_override("font_size", 15)
	city_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(city_label)
	title_stats_label = Label.new()
	title_stats_label.text = "Paused"
	title_stats_label.add_theme_color_override("font_color", Color.WHITE)
	title_row.add_child(title_stats_label)
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.custom_minimum_size = Vector2(76, 0)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	title_row.add_child(fps_label)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	page.add_child(content)

	var toolbar_panel := PanelContainer.new()
	toolbar_panel.custom_minimum_size = Vector2(190, 0)
	toolbar_panel.add_theme_stylebox_override("panel", _classic_box(Color("c0c0c0"), Color("808080"), 2))
	content.add_child(toolbar_panel)
	var toolbar_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		toolbar_margin.add_theme_constant_override("margin_" + side, 7)
	toolbar_panel.add_child(toolbar_margin)
	var toolbar := VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 5)
	toolbar_margin.add_child(toolbar)
	var toolbar_title := Label.new()
	toolbar_title.text = "City Toolbar"
	toolbar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar_title.add_theme_color_override("font_color", Color("000080"))
	toolbar_title.add_theme_font_size_override("font_size", 15)
	toolbar.add_child(toolbar_title)

	var tool_grid := GridContainer.new()
	tool_grid.columns = 3
	tool_grid.add_theme_constant_override("h_separation", 3)
	tool_grid.add_theme_constant_override("v_separation", 3)
	tool_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toolbar.add_child(tool_grid)
	var tool_button_group := ButtonGroup.new()
	for group_index in Tools.GROUPS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(48, 38)
		button.toggle_mode = true
		button.button_group = tool_button_group
		button.tooltip_text = Tools.GROUPS[group_index].name
		button.icon = _toolbar_group_icon(toolbar_art, group_index)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.text = str(group_index + 1) if button.icon == null else ""
		button.pressed.connect(_choose_tool_group.bind(group_index))
		tool_grid.add_child(button)
		toolbar_buttons.append(button)

	var camera_row := HBoxContainer.new()
	camera_row.alignment = BoxContainer.ALIGNMENT_CENTER
	camera_row.add_theme_constant_override("separation", 3)
	toolbar.add_child(camera_row)
	rotate_counter_clockwise_button = _icon_button(
		toolbar_art, Rect2i(405, 0, 27, 23), "Rotate Counter-Clockwise (Q)"
	)
	rotate_counter_clockwise_button.disabled = true
	rotate_counter_clockwise_button.pressed.connect(_rotate_city.bind(true))
	camera_row.add_child(rotate_counter_clockwise_button)
	rotate_clockwise_button = _icon_button(
		toolbar_art, Rect2i(433, 0, 27, 23), "Rotate Clockwise (W)"
	)
	rotate_clockwise_button.disabled = true
	rotate_clockwise_button.pressed.connect(_rotate_city.bind(false))
	camera_row.add_child(rotate_clockwise_button)
	zoom_out_button = _icon_button(toolbar_art, Rect2i(462, 0, 23, 23), "Zoom Out")
	zoom_out_button.pressed.connect(_zoom_out)
	camera_row.add_child(zoom_out_button)
	zoom_in_button = _icon_button(toolbar_art, Rect2i(486, 0, 23, 23), "Zoom In")
	zoom_in_button.pressed.connect(_zoom_in)
	camera_row.add_child(zoom_in_button)
	zoom_label = Label.new()
	zoom_label.text = "100%"
	zoom_label.custom_minimum_size = Vector2(48, 0)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_row.add_child(zoom_label)

	var category_label := Label.new()
	category_label.text = "Tool Category"
	toolbar.add_child(category_label)
	group_selector = OptionButton.new()
	for group_index in Tools.GROUPS.size():
		group_selector.add_item(Tools.GROUPS[group_index].name, group_index)
	group_selector.item_selected.connect(_select_tool_group)
	toolbar.add_child(group_selector)
	var tool_label := Label.new()
	tool_label.text = "Active Tool"
	toolbar.add_child(tool_label)
	tool_selector = OptionButton.new()
	tool_selector.item_selected.connect(_select_subtool)
	toolbar.add_child(tool_selector)
	undo_button = Button.new()
	undo_button.text = "Undo Last Edit"
	undo_button.disabled = true
	undo_button.pressed.connect(_undo_last_edit)
	toolbar.add_child(undo_button)

	var map_panel := PanelContainer.new()
	map_panel.custom_minimum_size = Vector2(560, 480)
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override(
		"panel", _classic_box(Color("18242c"), Color("404040"), 2)
	)
	content.add_child(map_panel)

	map_view = MapControl.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.selection_completed.connect(_apply_map_selection)
	map_view.selection_canceled.connect(_on_map_selection_canceled)
	map_view.zoom_changed.connect(_on_city_zoom_changed)
	map_panel.add_child(map_view)

	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)

	sidebar_toggle_button = Button.new()
	sidebar_toggle_button.text = ">"
	sidebar_toggle_button.tooltip_text = "Hide City Information"
	sidebar_toggle_button.custom_minimum_size = Vector2(24, 0)
	sidebar_toggle_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sidebar_toggle_button.pressed.connect(_toggle_sidebar)
	content.add_child(sidebar_toggle_button)

	sidebar_panel = PanelContainer.new()
	sidebar_panel.custom_minimum_size = Vector2(245, 0)
	sidebar_panel.add_theme_stylebox_override("panel", _classic_box(Color("c0c0c0"), Color("808080"), 2))
	content.add_child(sidebar_panel)
	var sidebar_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		sidebar_margin.add_theme_constant_override("margin_" + side, 8)
	sidebar_panel.add_child(sidebar_margin)
	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 7)
	sidebar_margin.add_child(sidebar)
	var city_information_heading := Label.new()
	city_information_heading.text = "City Information"
	city_information_heading.add_theme_color_override("font_color", Color("000080"))
	city_information_heading.add_theme_font_size_override("font_size", 16)
	sidebar.add_child(city_information_heading)

	details_label = Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(details_label)

	var simulation_heading := Label.new()
	simulation_heading.text = "Simulation Speed"
	simulation_heading.add_theme_color_override("font_color", Color("000080"))
	sidebar.add_child(simulation_heading)

	speed_selector = OptionButton.new()
	for speed_value in range(GameSpeed.Speed.PAUSED, GameSpeed.Speed.AFRICAN_SWALLOW + 1):
		speed_selector.add_item(GameSpeed.SPEED_NAMES[speed_value], speed_value)
	speed_selector.disabled = true
	speed_selector.item_selected.connect(_select_speed)
	sidebar.add_child(speed_selector)

	news_label = Label.new()
	news_label.text = "Latest Reports\nNo new reports."
	news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	news_label.add_theme_color_override("font_color", Color("202020"))
	sidebar.add_child(news_label)

	var view_heading := Label.new()
	view_heading.text = "Map Display"
	view_heading.add_theme_color_override("font_color", Color("000080"))
	sidebar.add_child(view_heading)
	var view_grid := GridContainer.new()
	view_grid.columns = 2
	view_grid.add_theme_constant_override("h_separation", 4)
	view_grid.add_theme_constant_override("v_separation", 4)
	sidebar.add_child(view_grid)
	for mode in MAP_DISPLAY_MODES:
		var button := Button.new()
		button.text = mode.capitalize()
		button.pressed.connect(_set_overlay.bind(mode))
		view_grid.add_child(button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)
	var open_button := Button.new()
	open_button.text = "Open City..."
	open_button.pressed.connect(_open_city_dialog)
	sidebar.add_child(open_button)
	budget_button = Button.new()
	budget_button.text = "Budget..."
	budget_button.disabled = true
	budget_button.pressed.connect(_open_manual_budget)
	sidebar.add_child(budget_button)
	save_button = Button.new()
	save_button.text = "Save City As..."
	save_button.disabled = true
	save_button.pressed.connect(_open_save_dialog)
	sidebar.add_child(save_button)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(0, 34)
	status_panel.add_theme_stylebox_override("panel", _classic_box(Color("c0c0c0"), Color("808080"), 2))
	page.add_child(status_panel)
	status_label = Label.new()
	status_label.text = "Ready."
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("202020"))
	status_panel.add_child(status_label)

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

	bridge_dialog = ConfirmationDialog.new()
	bridge_dialog.title = "Select Bridge"
	bridge_dialog.dialog_text = "Select a bridge type."
	bridge_dialog.min_size = Vector2i(660, 250)
	bridge_dialog.exclusive = true
	bridge_dialog.get_ok_button().visible = false
	bridge_dialog.get_cancel_button().text = "Cancel"
	bridge_dialog.canceled.connect(_cancel_bridge)
	var bridge_choices := HBoxContainer.new()
	bridge_choices.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bridge_choices.offset_left = 16
	bridge_choices.offset_top = 72
	bridge_choices.offset_right = -16
	bridge_choices.offset_bottom = 180
	bridge_choices.add_theme_constant_override("separation", 8)
	bridge_dialog.add_child(bridge_choices)
	for choice_index in 3:
		var choice_button := Button.new()
		choice_button.custom_minimum_size = Vector2(200, 104)
		choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_button.pressed.connect(_choose_bridge.bind(choice_index))
		bridge_choices.add_child(choice_button)
		bridge_choice_buttons.append(choice_button)
	add_child(bridge_dialog)

	tool_choice_dialog = ConfirmationDialog.new()
	tool_choice_dialog.title = "Select Building"
	tool_choice_dialog.dialog_text = "Select a building type."
	tool_choice_dialog.min_size = Vector2i(680, 390)
	tool_choice_dialog.exclusive = true
	tool_choice_dialog.get_ok_button().visible = false
	tool_choice_dialog.get_cancel_button().text = "Cancel"
	tool_choice_dialog.canceled.connect(_cancel_tool_choice)
	var tool_choices := GridContainer.new()
	tool_choices.columns = 3
	tool_choices.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tool_choices.offset_left = 16
	tool_choices.offset_top = 72
	tool_choices.offset_right = -16
	tool_choices.offset_bottom = 320
	tool_choices.add_theme_constant_override("h_separation", 8)
	tool_choices.add_theme_constant_override("v_separation", 8)
	tool_choice_dialog.add_child(tool_choices)
	for choice_index in 9:
		var choice_button := Button.new()
		choice_button.custom_minimum_size = Vector2(205, 72)
		choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_button.pressed.connect(_choose_tool_variant.bind(choice_index))
		tool_choices.add_child(choice_button)
		tool_choice_buttons.append(choice_button)
	add_child(tool_choice_dialog)

	stadium_dialog = ConfirmationDialog.new()
	stadium_dialog.title = "Select Stadium Team"
	stadium_dialog.dialog_text = "Select an unused team and edit its name."
	stadium_dialog.min_size = Vector2i(520, 260)
	stadium_dialog.exclusive = true
	stadium_dialog.get_ok_button().text = "Assign Team"
	stadium_dialog.get_cancel_button().text = "No Team"
	stadium_dialog.confirmed.connect(_confirm_stadium_team)
	stadium_dialog.canceled.connect(_cancel_stadium_team)
	var stadium_fields := VBoxContainer.new()
	stadium_fields.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stadium_fields.offset_left = 16
	stadium_fields.offset_top = 72
	stadium_fields.offset_right = -16
	stadium_fields.offset_bottom = 170
	stadium_fields.add_theme_constant_override("separation", 10)
	stadium_dialog.add_child(stadium_fields)
	stadium_team_selector = OptionButton.new()
	stadium_team_selector.item_selected.connect(_select_stadium_team)
	stadium_fields.add_child(stadium_team_selector)
	stadium_name_input = LineEdit.new()
	stadium_name_input.max_length = 23
	stadium_name_input.placeholder_text = "Team name"
	stadium_fields.add_child(stadium_name_input)
	add_child(stadium_dialog)

	highway_connection_dialog = ConfirmationDialog.new()
	highway_connection_dialog.title = "Neighbor Connection"
	highway_connection_dialog.dialog_text = (
		"Build a highway connection to a neighboring city for $1,500?"
	)
	highway_connection_dialog.min_size = Vector2i(520, 210)
	highway_connection_dialog.exclusive = true
	highway_connection_dialog.get_ok_button().text = "Build Connection"
	highway_connection_dialog.get_cancel_button().text = "Keep Highway"
	highway_connection_dialog.confirmed.connect(_confirm_highway_connection)
	highway_connection_dialog.canceled.connect(_cancel_highway_connection)
	add_child(highway_connection_dialog)

	tunnel_dialog = ConfirmationDialog.new()
	tunnel_dialog.title = "Construct Tunnel"
	tunnel_dialog.dialog_text = "Do you wish to construct the tunnel?"
	tunnel_dialog.min_size = Vector2i(500, 200)
	tunnel_dialog.exclusive = true
	tunnel_dialog.get_ok_button().text = "Yes"
	tunnel_dialog.get_cancel_button().text = "No"
	tunnel_dialog.confirmed.connect(_confirm_tunnel)
	tunnel_dialog.canceled.connect(_cancel_tunnel)
	add_child(tunnel_dialog)

	query_dialog = AcceptDialog.new()
	query_dialog.title = "Query"
	query_dialog.min_size = Vector2i(500, 440)
	add_child(query_dialog)
	game_over_dialog = AcceptDialog.new()
	game_over_dialog.min_size = Vector2i(460, 220)
	add_child(game_over_dialog)
	military_dialog = ConfirmationDialog.new()
	military_dialog.title = "Military Base Proposal"
	military_dialog.dialog_text = (
		"The military wants to build a base in the city. "
		+ "The base does not cost city funds. Do you accept the proposal?"
	)
	military_dialog.min_size = Vector2i(500, 210)
	military_dialog.get_ok_button().text = "Accept"
	military_dialog.get_cancel_button().text = "Decline"
	military_dialog.exclusive = true
	military_dialog.confirmed.connect(_accept_military_proposal)
	military_dialog.canceled.connect(_decline_military_proposal)
	add_child(military_dialog)

	budget_dialog = ConfirmationDialog.new()
	budget_dialog.title = "Budget"
	budget_dialog.min_size = Vector2i(680, 720)
	budget_dialog.get_ok_button().text = "Apply"
	budget_dialog.confirmed.connect(_commit_budget)
	budget_dialog.canceled.connect(_cancel_budget)
	var budget_scroll := ScrollContainer.new()
	budget_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	budget_scroll.offset_left = 16
	budget_scroll.offset_top = 48
	budget_scroll.offset_right = -16
	budget_scroll.offset_bottom = -58
	budget_dialog.add_child(budget_scroll)
	var budget_rows := VBoxContainer.new()
	budget_rows.custom_minimum_size = Vector2(620, 0)
	budget_rows.add_theme_constant_override("separation", 6)
	budget_scroll.add_child(budget_rows)
	budget_notice_label = Label.new()
	budget_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	budget_notice_label.custom_minimum_size = Vector2(600, 48)
	budget_rows.add_child(budget_notice_label)
	auto_budget_check = CheckBox.new()
	auto_budget_check.text = "Use the same funding automatically next year"
	budget_rows.add_child(auto_budget_check)
	for budget_id in BUDGET_NAMES.size():
		var row := HBoxContainer.new()
		var row_label := Label.new()
		row_label.text = BUDGET_NAMES[budget_id]
		row_label.custom_minimum_size = Vector2(360, 0)
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(row_label)
		var control := SpinBox.new()
		control.custom_minimum_size = Vector2(180, 32)
		control.rounded = true
		control.step = 1
		control.min_value = -2147483648
		control.max_value = 2147483647
		if budget_id <= Budget.BUDGET_INDUSTRIAL:
			control.min_value = 0
			control.max_value = 22
			control.suffix = "% tax"
		elif budget_id >= Budget.BUDGET_POLICE:
			control.min_value = 0
			control.max_value = 100
			control.suffix = "% funded"
		else:
			control.editable = false
		if budget_id == Budget.BUDGET_BONDS:
			control.visible = false
		row.add_child(control)
		budget_controls.append(control)
		budget_rows.add_child(row)
		if budget_id == Budget.BUDGET_BONDS:
			var bond_controls := HBoxContainer.new()
			bond_controls.add_theme_constant_override("separation", 8)
			bond_summary_label = Label.new()
			bond_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bond_controls.add_child(bond_summary_label)
			issue_bond_button = Button.new()
			issue_bond_button.text = "Issue $10K Bond"
			issue_bond_button.pressed.connect(_request_issue_bond)
			bond_controls.add_child(issue_bond_button)
			repay_bond_button = Button.new()
			repay_bond_button.text = "Repay $10K Bond"
			repay_bond_button.pressed.connect(_request_repay_bond)
			bond_controls.add_child(repay_bond_button)
			budget_rows.add_child(bond_controls)
	add_child(budget_dialog)

	bond_dialog = ConfirmationDialog.new()
	bond_dialog.title = "Bond"
	bond_dialog.min_size = Vector2i(500, 210)
	bond_dialog.exclusive = true
	bond_dialog.get_ok_button().text = "Yes"
	bond_dialog.get_cancel_button().text = "No"
	bond_dialog.confirmed.connect(_confirm_bond_action)
	bond_dialog.canceled.connect(_cancel_bond_action)
	add_child(bond_dialog)

	group_selector.select(selected_group)
	_select_tool_group(selected_group)
	_update_zoom_controls(map_view.zoom_percent())


func _create_classic_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	result.set_color("font_color", "Label", Color("101010"))
	result.set_color("font_color", "Button", Color("101010"))
	result.set_color("font_hover_color", "Button", Color("101010"))
	result.set_color("font_pressed_color", "Button", Color("101010"))
	result.set_color("font_color", "OptionButton", Color("101010"))
	result.set_stylebox("normal", "Button", _classic_box(Color("c0c0c0"), Color("ffffff"), 2))
	result.set_stylebox("hover", "Button", _classic_box(Color("d0d0d0"), Color("ffffff"), 2))
	result.set_stylebox("pressed", "Button", _classic_box(Color("a0a0a0"), Color("404040"), 2))
	result.set_stylebox("focus", "Button", _classic_box(Color("c0c0c0"), Color("000000"), 1))
	result.set_stylebox("normal", "OptionButton", _classic_box(Color("ffffff"), Color("808080"), 2))
	result.set_stylebox("hover", "OptionButton", _classic_box(Color("ffffff"), Color("000080"), 2))
	result.set_stylebox("pressed", "OptionButton", _classic_box(Color("e0e0e0"), Color("404040"), 2))
	result.set_stylebox("normal", "PanelContainer", _classic_box(Color("c0c0c0"), Color("808080"), 1))
	return result


func _classic_box(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = 5
	box.content_margin_top = 3
	box.content_margin_right = 5
	box.content_margin_bottom = 3
	return box


func _add_menu(parent: Control, label: String, items: Array, callback: Callable) -> MenuButton:
	var menu := MenuButton.new()
	menu.text = label
	menu.flat = true
	menu.custom_minimum_size = Vector2(0, 25)
	parent.add_child(menu)
	for item in items:
		menu.get_popup().add_item(item[0], item[1])
	if callback.is_valid():
		menu.get_popup().id_pressed.connect(callback)
	return menu


func _toolbar_group_icon(toolbar_art: Image, group_index: int) -> Texture2D:
	const REGIONS := [
		Rect2i(0, 0, 23, 23), Rect2i(24, 0, 26, 23), Rect2i(50, 0, 20, 23),
		Rect2i(70, 0, 25, 23), Rect2i(95, 0, 21, 23), Rect2i(116, 0, 24, 23),
		Rect2i(140, 0, 23, 23), Rect2i(163, 0, 23, 23), Rect2i(186, 0, 23, 23),
		Rect2i(209, 0, 23, 23), Rect2i(232, 0, 23, 23), Rect2i(255, 0, 23, 23),
		Rect2i(278, 0, 23, 23), Rect2i(302, 0, 23, 23), Rect2i(325, 0, 23, 23),
		Rect2i(348, 0, 29, 23), Rect2i(377, 0, 26, 23), Rect2i(510, 0, 23, 23),
	]
	if group_index < 0 or group_index >= REGIONS.size():
		return null
	return _toolbar_icon(toolbar_art, REGIONS[group_index])


func _toolbar_icon(toolbar_art: Image, region: Rect2i) -> Texture2D:
	if toolbar_art == null or not Rect2i(Vector2i.ZERO, toolbar_art.get_size()).encloses(region):
		return null
	var image := toolbar_art.get_region(region)
	image.convert(Image.FORMAT_RGBA8)
	var background := image.get_pixel(0, 0)
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.is_equal_approx(background):
				image.set_pixel(x, y, Color(color.r, color.g, color.b, 0.0))
			else:
				minimum.x = mini(minimum.x, x)
				minimum.y = mini(minimum.y, y)
				maximum.x = maxi(maximum.x, x)
				maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x:
		return null
	var bounds := Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	return ImageTexture.create_from_image(image.get_region(bounds))


func _icon_button(toolbar_art: Image, region: Rect2i, tooltip: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(40, 34)
	button.icon = _toolbar_icon(toolbar_art, region)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.text = tooltip.left(1) if button.icon == null else ""
	button.tooltip_text = tooltip
	return button


func _choose_tool_group(group_index: int) -> void:
	group_selector.select(group_index)
	_select_tool_group(group_index)


func _zoom_in() -> void:
	map_view.zoom_in()


func _zoom_out() -> void:
	map_view.zoom_out()


func _rotate_city(counter_clockwise: bool) -> void:
	if city == null:
		_show_error("No city is loaded.")
		return
	var old_center := Vector2i(-1, -1)
	if overlay_mode == "city" or overlay_mode == "underground":
		old_center = map_view.center_tile()
	var new_center := CityRotation.rotate_point(
		old_center, CityState.MAP_SIZE, counter_clockwise
	)
	var result := CityRotation.apply(city, counter_clockwise)
	if not result.ok:
		_show_error("Cannot rotate city: %s" % result.error)
		return
	if simulation_engine != null:
		simulation_engine.rotate_runtime_coordinates(counter_clockwise)
	last_edit_command = {}
	undo_button.disabled = true
	map_view.show_transient_effects([])
	_refresh_map()
	if new_center.x >= 0:
		map_view.center_on_tile(new_center)
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Rotated %s. Compass: %d." % [
		"counter-clockwise" if counter_clockwise else "clockwise",
		result.new_compass,
	]


func _update_zoom_controls(percent: int) -> void:
	if zoom_label != null:
		zoom_label.text = "%d%%" % percent
	if zoom_in_button != null:
		zoom_in_button.disabled = not map_view.can_zoom_in()
	if zoom_out_button != null:
		zoom_out_button.disabled = not map_view.can_zoom_out()
	if rotate_counter_clockwise_button != null:
		rotate_counter_clockwise_button.disabled = city == null
	if rotate_clockwise_button != null:
		rotate_clockwise_button.disabled = city == null


func _update_fps(delta: float) -> void:
	fps_update_seconds += delta
	if fps_label == null or fps_update_seconds < 0.25:
		return
	fps_update_seconds = fmod(fps_update_seconds, 0.25)
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_city_zoom_changed(percent: int) -> void:
	_update_zoom_controls(percent)
	if city != null and overlay_mode in ["city", "underground"]:
		_refresh_map(false)


func _on_map_selection_canceled() -> void:
	if status_label == null:
		return
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Selection canceled. No action was taken."


func _on_file_menu(id: int) -> void:
	match id:
		0: _open_city_dialog()
		1: _open_save_dialog()
		2: get_tree().quit()


func _on_speed_menu(id: int) -> void:
	if speed_controller == null:
		return
	speed_selector.select(id)
	_select_speed(id)


func _on_options_menu(id: int) -> void:
	if id >= 0 and id < MAP_DISPLAY_MODES.size():
		_set_overlay(MAP_DISPLAY_MODES[id])


func _on_disaster_menu(id: int) -> void:
	if city == null or simulation_engine == null:
		_show_error("Load a city before you start a disaster.")
		return
	var point := map_view.center_tile()
	if point.x < 0:
		point = Vector2i(64, 64)
	var result := simulation_engine.start_disaster(id, point)
	if not result.get("ok", false):
		_show_error("Cannot start the disaster: %s" % result.get("error", "unknown error"))
		return
	if not result.get("started", false):
		_show_error("The selected disaster could not start.")
		return
	last_edit_command = {}
	undo_button.disabled = true
	simulation_map_dirty = false
	_refresh_map(false)
	for requested_point in result.get("view_center_requests", []):
		map_view.center_on_tile(requested_point)
	_show_effect_events(
		result.get("effect_events", []), result.get("sound_events", [])
	)
	_show_news_items(result.get("news_items", []))
	var disaster_name: String = {
		DisasterStart.DISASTER_FIRE: "Fire",
		DisasterStart.DISASTER_FLOOD: "Flood",
		DisasterStart.DISASTER_RIOT: "Riot",
		DisasterStart.DISASTER_TOXIC_SPILL: "Toxic Spill",
		DisasterStart.DISASTER_AIR_CRASH: "Air Crash",
		DisasterStart.DISASTER_EARTHQUAKE: "Earthquake",
		DisasterStart.DISASTER_TORNADO: "Tornado",
		DisasterStart.DISASTER_MONSTER: "Monster",
		DisasterStart.DISASTER_MELTDOWN: "Meltdown",
		DisasterStart.DISASTER_MICROWAVE: "Microwave",
		DisasterStart.DISASTER_VOLCANO: "Volcano",
		DisasterStart.DISASTER_FIRESTORM: "Firestorm",
		DisasterStart.DISASTER_MASS_RIOTS: "Mass Riots",
		DisasterStart.DISASTER_MASS_FLOODS: "Mass Floods",
		DisasterStart.DISASTER_POLLUTION: "Pollution",
		DisasterStart.DISASTER_HURRICANE: "Hurricane",
		DisasterStart.DISASTER_HELICOPTER_CRASH: "Helicopter Crash",
		DisasterStart.DISASTER_PLANE_CRASH: "Plane Crash",
	}.get(id, "Disaster")
	status_label.remove_theme_color_override("font_color")
	status_label.text = "%s started." % disaster_name


func _on_windows_menu(id: int) -> void:
	if id == 0:
		_open_manual_budget()
	elif id == 1:
		_set_sidebar_expanded(not sidebar_panel.visible)


func _toggle_sidebar() -> void:
	_set_sidebar_expanded(not sidebar_panel.visible)


func _set_sidebar_expanded(expanded: bool) -> void:
	if sidebar_panel == null or sidebar_toggle_button == null:
		return
	sidebar_panel.visible = expanded
	sidebar_toggle_button.text = ">" if expanded else "<"
	sidebar_toggle_button.tooltip_text = (
		"Hide City Information" if expanded else "Show City Information"
	)


func _on_newspaper_menu(_id: int) -> void:
	status_label.text = "The latest reports are visible in the City Information panel."


func _on_help_menu(_id: int) -> void:
	status_label.text = "Select a tool, then use the city view. Use the wheel to zoom. Use the right or middle mouse button to pan."


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


func _open_manual_budget() -> void:
	if city == null:
		return
	_open_budget_dialog(Budget.funding_values(city), false)


func _open_budget_dialog(values: PackedInt32Array, annual: bool) -> void:
	if city == null or values.size() != Budget.BUDGET_COUNT:
		_show_error("Cannot open the budget because its saved values are invalid.")
		return
	annual_budget_pending = annual
	budget_dialog.title = "Annual Budget" if annual else "Budget"
	budget_notice_label.text = (
		"Set the tax rates and service funding. Apply this budget to finish the annual settlement."
		if annual
		else "Set the tax rates and service funding. Ordinance and bond values are calculated by the simulation."
	)
	auto_budget_check.button_pressed = city.document.misc_u32(Budget.MISC_AUTO_BUDGET) != 0
	budget_dialog.get_cancel_button().disabled = annual
	budget_dialog.exclusive = annual
	for budget_id in Budget.BUDGET_COUNT:
		budget_controls[budget_id].value = values[budget_id]
	_update_bond_controls()
	budget_dialog.popup_centered()


func _request_issue_bond() -> void:
	if city == null:
		return
	var result := Bonds.issue(city)
	if not result.ok:
		_show_error("Cannot issue a bond: %s" % result.error)
		return
	_update_bond_controls()
	match result.status:
		"confirmation_required":
			pending_bond_action = "issue"
			bond_dialog.title = "Issue Bond"
			bond_dialog.dialog_text = (
				"Current Rates are %d%%.\nDo You Want to Issue the Bond?" % int(result.rate)
			)
			bond_dialog.popup_centered()
		"credit_denied":
			_show_error(
				"Sorry, your city may not issue more bonds\nuntil your credit rating improves."
			)
		"maximum_bonds":
			_show_error("The City Council believes that 50 outstanding bonds are enough.")
		_:
			_show_error("The bond could not be issued.")


func _request_repay_bond() -> void:
	if city == null:
		return
	var result := Bonds.repay(city)
	if not result.ok:
		_show_error("Cannot repay a bond: %s" % result.error)
		return
	match result.status:
		"confirmation_required":
			pending_bond_action = "repay"
			bond_dialog.title = "Repay Bond"
			bond_dialog.dialog_text = (
				"Oldest Bond Rate is %d%%\nDo You Want to Repay the Bond?" % int(result.rate)
			)
			bond_dialog.popup_centered()
		"insufficient_funds":
			_show_error("You Need $10,000 Cash\nto Repay an Outstanding Bond.")
		"no_bonds":
			_show_error("There are no outstanding bonds to repay.")
		_:
			_show_error("The bond could not be repaid.")


func _confirm_bond_action() -> void:
	_resolve_bond_action(Bonds.CONFIRMATION_CONFIRMED)


func _cancel_bond_action() -> void:
	_resolve_bond_action(Bonds.CONFIRMATION_CANCELLED)


func _resolve_bond_action(confirmation: int) -> void:
	if city == null or pending_bond_action.is_empty():
		return
	var action := pending_bond_action
	pending_bond_action = ""
	var result := (
		Bonds.issue(city, confirmation)
		if action == "issue"
		else Bonds.repay(city, confirmation)
	)
	if not result.ok:
		_show_error("Cannot update bonds: %s" % result.error)
		return
	_update_bond_controls()
	_refresh_details()
	status_label.remove_theme_color_override("font_color")
	match result.status:
		"issued":
			status_label.text = "Issued a $10,000 bond at %d%%." % int(result.rate)
		"repaid":
			status_label.text = "Repaid the oldest $10,000 bond at %d%%." % int(result.rate)
		"cancelled":
			status_label.text = "Bond action canceled. No bond balance changed."
		"credit_denied":
			_show_error(
				"Sorry, your city may not issue more bonds\nuntil your credit rating improves."
			)
		"maximum_bonds":
			_show_error("The City Council believes that 50 outstanding bonds are enough.")
		_:
			_show_error("The bond action did not complete.")


func _update_bond_controls() -> void:
	if city == null or bond_summary_label == null:
		return
	var bond_count := city.document.misc_u32(Bonds.MISC_BONDS)
	var funds := city.funds()
	var average_fixed := city.document.misc_i32(
		Budget.MISC_BUDGETS
		+ Budget.BUDGET_BONDS * Budget.BUDGET_RECORD_SIZE
		+ Budget.BUDGET_FUNDING
	)
	budget_controls[Budget.BUDGET_BONDS].value = average_fixed
	if bond_count == 0:
		bond_summary_label.text = "No outstanding bonds"
	else:
		var oldest := city.document.misc_u32(Bonds.MISC_BOND_RATES) & 0xffff
		bond_summary_label.text = "%d outstanding; oldest %d%%; average %.2f%%" % [
			bond_count, oldest, float(average_fixed) / 10000.0,
		]
	issue_bond_button.disabled = bond_count > Bonds.MAX_BONDS
	repay_bond_button.disabled = bond_count == 0 or funds < Bonds.BOND_VALUE


func _budget_values() -> PackedInt32Array:
	var values := PackedInt32Array()
	for control in budget_controls:
		values.append(roundi(control.value))
	return values


func _commit_budget() -> void:
	if city == null:
		return
	var values := _budget_values()
	var auto_budget := auto_budget_check.button_pressed
	if annual_budget_pending:
		var result := speed_controller.resolve_annual_budget(values, auto_budget)
		if not result.ok:
			_show_error("Cannot apply the annual budget: %s" % result.error)
			call_deferred("_restore_annual_budget_dialog")
			return
		annual_budget_pending = false
		_consume_simulation_result(result)
		_refresh_details()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Annual budget applied. The simulation can continue."
		return
	var stored := Budget.set_funding(city, values, auto_budget)
	if not stored.ok:
		_show_error("Cannot save the budget: %s" % stored.error)
		return
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Budget funding saved."


func _cancel_budget() -> void:
	if annual_budget_pending:
		_commit_budget()


func _restore_annual_budget_dialog() -> void:
	if annual_budget_pending:
		budget_dialog.popup_centered()


func _open_military_proposal() -> void:
	military_proposal_pending = true
	military_dialog.popup_centered()


func _accept_military_proposal() -> void:
	_resolve_military_proposal(true)


func _decline_military_proposal() -> void:
	_resolve_military_proposal(false)


func _resolve_military_proposal(accepted: bool) -> void:
	if not military_proposal_pending or speed_controller == null:
		return
	var result := speed_controller.resolve_military_proposal(accepted)
	if not result.ok:
		_show_error("Cannot resolve the military proposal: %s" % result.error)
		call_deferred("_restore_military_proposal_dialog")
		return
	military_proposal_pending = false
	_consume_simulation_result(result)
	_refresh_details()
	status_label.remove_theme_color_override("font_color")
	var proposal: Dictionary = result.day_results[0].phase_results.military_proposal
	match int(proposal.base_type):
		2:
			status_label.text = "The Army base site is reserved."
		3:
			status_label.text = "The Air Force base site is reserved."
		5:
			status_label.text = "The missile silo sites are reserved."
		_:
			status_label.text = (
				"The military proposal was declined."
				if not accepted
				else "The military could not find a suitable site."
			)


func _restore_military_proposal_dialog() -> void:
	if military_proposal_pending:
		military_dialog.popup_centered()


func _load_city(path: String) -> void:
	var document := Sc2Document.load_path(path)
	if not document.is_valid():
		_show_error(document.parse_error)
		return

	var loaded_city := CityModel.from_document(document)
	if not loaded_city.is_valid():
		_show_error(loaded_city.load_error)
		return

	if budget_dialog.visible:
		budget_dialog.hide()
	pending_bond_action = ""
	if bond_dialog.visible:
		bond_dialog.hide()
	if game_over_dialog.visible:
		game_over_dialog.hide()
	military_proposal_pending = false
	if military_dialog.visible:
		military_dialog.hide()
	pending_bridge_request.clear()
	if bridge_dialog.visible:
		bridge_dialog.hide()
	pending_tool_choices.clear()
	if tool_choice_dialog.visible:
		tool_choice_dialog.hide()
	pending_stadium_command.clear()
	if stadium_dialog.visible:
		stadium_dialog.hide()
	pending_highway_connection.clear()
	if highway_connection_dialog.visible:
		highway_connection_dialog.hide()
	pending_tunnel_request.clear()
	if tunnel_dialog.visible:
		tunnel_dialog.hide()
	annual_budget_pending = false
	game_over_active = false
	city = loaded_city
	current_document = document
	static_render_epoch += 1
	static_city_image = null
	static_occlusion_commands.clear()
	static_occlusion_grid.clear()
	static_visual_signature = []
	static_render_mode = ""
	static_display_city = null
	static_view_cache.clear()
	palette_cycle_ticks = 0
	_update_palette_cycle_texture()
	dynamic_sprite_cache.clear()
	dynamic_foreground_cache.clear()
	var process_seed := tool_random.state
	var game_seed := nuisance_random.state
	var lfsr_seed := (
		simulation_engine.lfsr_random.state
		if simulation_engine != null
		else (Time.get_ticks_msec() & 0xffff) | 1
	)
	simulation_engine = Simulation.new(city, process_seed, lfsr_seed, game_seed)
	speed_controller = GameSpeed.new(simulation_engine)
	tool_random = simulation_engine.random
	nuisance_random = simulation_engine.game_random
	speed_selector.select(speed_controller.speed - GameSpeed.Speed.PAUSED)
	speed_selector.disabled = false
	simulation_map_dirty = false
	recent_news.clear()
	news_label.text = "Latest Reports\nNo new reports."
	last_edit_command = {}
	dispatch_cycles = PackedInt32Array([0, 0, 0])
	dispatch_initialized = false
	undo_button.disabled = true
	save_button.disabled = false
	budget_button.disabled = false
	_update_zoom_controls(map_view.zoom_percent())
	city_label.text = "OpenSC2K — %s" % (
		city.city_name() if not city.city_name().is_empty() else path.get_file().get_basename()
	)
	_refresh_details()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Loaded %s. Map view: %s." % [path.get_file(), overlay_mode.capitalize()]
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
	status_label.text = "Saved city copy: %s" % output_path


func _set_overlay(mode: String) -> void:
	if not MAP_DISPLAY_MODES.has(mode):
		return
	overlay_mode = mode
	_update_edit_state()
	if city != null:
		status_label.text = "Map view: %s" % overlay_mode.capitalize()
		_refresh_map(false)


func _select_speed(index: int) -> void:
	if speed_controller == null:
		return
	var selected_speed := speed_selector.get_item_id(index)
	if not speed_controller.set_speed(selected_speed):
		_show_error("Cannot change the simulation speed.")
		return
	status_label.remove_theme_color_override("font_color")
	status_label.text = "%s speed selected." % speed_controller.speed_name()


func _refresh_map(force := true) -> void:
	if city == null or palette == null:
		return
	var image: Image
	if overlay_mode == "city" or overlay_mode == "underground":
		var view_size := _city_view_size()
		var sprite_archive := _sprite_archive_for_view(view_size)
		var current_signature := _static_signature_for_mode(overlay_mode, view_size)
		var cached: Dictionary = static_view_cache.get(overlay_mode, {})
		if (
			not cached.is_empty()
			and cached.get("signature", []) == current_signature
			and int(cached.get("view_size", -1)) == view_size
		):
			static_city_image = cached.image
			_set_static_occlusion_commands(
				cached.get("occlusion_commands", []), view_size
			)
			static_visual_signature = current_signature
			static_render_mode = overlay_mode
			static_display_city = cached.display_city
			var cached_texture := ImageTexture.create_from_image(static_city_image)
			map_view.set_city_view(
				static_display_city, cached_texture, cached_texture, true
			)
			if overlay_mode == "city":
				_refresh_moving_things(view_size)
			else:
				map_view.set_dynamic_sprites([])
			return
		if (
			not force
			and static_city_image != null
			and static_render_mode == overlay_mode
			and current_signature == static_visual_signature
		):
			if overlay_mode == "city":
				_refresh_moving_things(view_size)
			return
		if not force:
			_request_static_render(current_signature, view_size, sprite_archive, overlay_mode)
			if overlay_mode == "city":
				_refresh_moving_things(view_size)
			else:
				map_view.set_dynamic_sprites([])
			return
		static_render_epoch += 1
		var display_city := city
		var indexed: Dictionary
		if overlay_mode == "underground":
			indexed = UndergroundView.create_image(
				display_city, palette_index_encoding, sprite_archive, view_size, true
			)
		else:
			indexed = IsometricRenderer.create_image(
				display_city, palette_index_encoding, sprite_archive, view_size,
				int(Time.get_ticks_msec() / 100), false, true, true, false
			)
		if not indexed.ok:
			_show_error(indexed.error)
			return
		image = indexed.image
		if view_size != IsometricRenderer.VIEW_LARGE:
			image.resize(
				IsometricRenderer.IMAGE_SIZE_LARGE.x,
				IsometricRenderer.IMAGE_SIZE_LARGE.y,
				Image.INTERPOLATE_NEAREST,
			)
		static_city_image = image
		var occlusion_commands: Array[Dictionary] = (
			IsometricRenderer.static_occlusion_commands(display_city, sprite_archive, view_size)
			if overlay_mode == "city"
			else []
		)
		_set_static_occlusion_commands(occlusion_commands, view_size)
		static_visual_signature = current_signature
		static_render_mode = overlay_mode
		static_display_city = display_city
		static_view_cache[overlay_mode] = {
			"image": image,
			"occlusion_commands": static_occlusion_commands,
			"signature": current_signature,
			"display_city": display_city,
			"view_size": view_size,
		}
	else:
		image = Minimap.create_image(city, palette, overlay_mode)
		image.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
		static_city_image = null
		static_occlusion_commands.clear()
		static_occlusion_grid.clear()
		static_visual_signature = []
		map_view.set_dynamic_sprites([])
	var texture := ImageTexture.create_from_image(image)
	map_view.set_city_view(
		static_display_city if overlay_mode in ["city", "underground"] else city,
		texture, texture if overlay_mode in ["city", "underground"] else null,
		overlay_mode in ["city", "underground"]
	)
	if overlay_mode == "city":
		_refresh_moving_things(_city_view_size())


func _request_static_render(
	signature: Array, view_size: int, sprite_archive: Sc2SpriteArchive, render_mode := "city"
) -> void:
	if static_render_thread != null:
		return
	var snapshot_document := current_document.duplicate_document()
	var snapshot := CityModel.from_document(snapshot_document)
	if not snapshot.is_valid():
		_show_error("Cannot prepare the city for drawing: %s" % snapshot.load_error)
		return
	static_render_job = RenderJob.new()
	static_render_job.city_snapshot = snapshot
	static_render_job.index_palette = palette_index_encoding
	static_render_job.sprites = sprite_archive
	static_render_job.view_size = view_size
	static_render_job.animation_phase = int(Time.get_ticks_msec() / 100)
	static_render_job.signature = signature.duplicate()
	static_render_job.epoch = static_render_epoch
	static_render_job.render_mode = render_mode
	static_render_thread = Thread.new()
	var start_error := static_render_thread.start(
		static_render_job.run, Thread.PRIORITY_LOW
	)
	if start_error != OK:
		static_render_thread = null
		static_render_job = null
		_show_error("Cannot start the city renderer: %s" % error_string(start_error))


func _poll_static_render() -> void:
	if static_render_thread == null or static_render_thread.is_alive():
		return
	var rendered: Dictionary = static_render_thread.wait_to_finish()
	static_render_thread = null
	static_render_job = null
	if not rendered.get("ok", false):
		_show_error(rendered.get("error", "city rendering failed"))
		return
	if (
		city == null
		or int(rendered.epoch) != static_render_epoch
		or int(rendered.view_size) != _city_view_size()
		or String(rendered.get("render_mode", "city")) != overlay_mode
	):
		if city != null and overlay_mode in ["city", "underground"]:
			_refresh_map(false)
		return
	static_city_image = rendered.index_image
	_set_static_occlusion_commands(rendered.occlusion_commands, int(rendered.view_size))
	static_visual_signature = rendered.signature
	static_render_mode = String(rendered.render_mode)
	static_display_city = rendered.display_city
	static_view_cache[static_render_mode] = {
		"image": static_city_image,
		"occlusion_commands": static_occlusion_commands,
		"signature": static_visual_signature,
		"display_city": static_display_city,
		"view_size": int(rendered.view_size),
	}
	var texture := ImageTexture.create_from_image(static_city_image)
	map_view.set_city_view(
		static_display_city, texture, texture, true
	)
	if overlay_mode == "city":
		_refresh_moving_things(int(rendered.view_size))
	else:
		map_view.set_dynamic_sprites([])
	var latest_signature := _static_signature_for_mode(
		overlay_mode, int(rendered.view_size)
	)
	if latest_signature != static_visual_signature:
		_request_static_render(
			latest_signature,
			int(rendered.view_size),
			_sprite_archive_for_view(int(rendered.view_size)),
			overlay_mode,
		)


func _static_signature_for_mode(mode: String, view_size: int) -> Array:
	if mode == "underground":
		return UndergroundView.visual_signature(city, view_size)
	return IsometricRenderer.static_visual_signature(city, view_size)


func _exit_tree() -> void:
	if static_render_thread != null and static_render_thread.is_started():
		static_render_thread.wait_to_finish()
	static_render_thread = null
	static_render_job = null


func _update_palette_cycle_texture() -> void:
	if palette == null or not palette.is_valid():
		return
	var image := palette.animation_image(palette_cycle_ticks)
	if palette_cycle_texture == null:
		palette_cycle_texture = ImageTexture.create_from_image(image)
	else:
		palette_cycle_texture.update(image)
	if map_view != null:
		map_view.set_animated_palette(palette_cycle_texture)


func _city_view_size() -> int:
	if map_view.zoom_percent() <= 25:
		return IsometricRenderer.VIEW_SMALL
	if map_view.zoom_percent() <= 50:
		return IsometricRenderer.VIEW_MEDIUM
	return IsometricRenderer.VIEW_LARGE


func _sprite_archive_for_view(view_size: int) -> Sc2SpriteArchive:
	return small_medium_sprites if view_size < IsometricRenderer.VIEW_LARGE else large_sprites


func _refresh_moving_things(view_size := -1) -> void:
	if city == null or palette == null or map_view == null or overlay_mode != "city":
		if map_view != null:
			map_view.set_dynamic_sprites([])
		return
	if view_size < 0:
		view_size = _city_view_size()
	var sprite_archive := _sprite_archive_for_view(view_size)
	var configuration := IsometricRenderer.view_configuration(view_size)
	var divisor := int(configuration.divisor)
	var commands := IsometricRenderer.dynamic_draw_commands(
		city, sprite_archive, view_size, int(Time.get_ticks_msec() / 100)
	)
	var visuals: Array[Dictionary] = []
	for command in commands:
		var resource := _dynamic_sprite_resource(
			sprite_archive, command.sprite_id, command.flip, divisor
		)
		if resource.is_empty():
			continue
		var position := Vector2i(command.position) * divisor
		var texture: Texture2D = resource.texture
		var index_texture: Texture2D = resource.index_texture
		var occluder_mask := _dynamic_occluder_image(
			sprite_archive, divisor, position, resource.image.get_size(),
			int(command.get("depth_order", -1)), bool(command.get("train", false))
		)
		if command.shadow:
			var shadow_image := _dynamic_shadow_image(resource.image, position, occluder_mask)
			if shadow_image == null:
				continue
			texture = ImageTexture.create_from_image(shadow_image)
			index_texture = null
		else:
			var occluded := IsometricRenderer.occlude_dynamic_with_mask(
				resource.image, occluder_mask, position, static_city_image,
				command.get("same_tile_foreground_indices", PackedInt32Array())
			)
			if int(occluded.occluded_pixels) > 0:
				texture = ImageTexture.create_from_image(occluded.image)
				index_texture = texture
		visuals.append({
			"texture": texture,
			"index_texture": index_texture,
			"palette_lookup_all": true,
			"position": Vector2(position),
			"size": Vector2(resource.image.get_size()),
		})
	map_view.set_dynamic_sprites(visuals)


func _dynamic_occluder_image(
	sprite_archive: Sc2SpriteArchive,
	divisor: int,
	position: Vector2i,
	size: Vector2i,
	draw_order: int,
	is_train := false
) -> Image:
	if draw_order < 0 or static_occlusion_commands.is_empty():
		return null
	var bounds := Rect2i(position, size)
	if static_occlusion_grid.is_empty():
		static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
			static_occlusion_commands, divisor
		)
	var mask: Image
	var later_occluder_added := false
	var candidate_indices := IsometricRenderer.occlusion_candidate_indices(
		static_occlusion_grid, bounds
	)
	for command_index in candidate_indices:
		var command := static_occlusion_commands[command_index]
		var later_static := int(command.depth_order) > draw_order
		var train_foreground := (
			is_train and command.has("train_foreground_reference_sprite_id")
		)
		var use_later_static := (
			later_static and not later_occluder_added and not train_foreground
		)
		if not use_later_static and not train_foreground:
			continue
		var occluder_position := Vector2i(command.position) * divisor
		var occluder_size := Vector2i(command.size) * divisor
		var overlap := bounds.intersection(
			Rect2i(occluder_position, occluder_size)
		)
		if overlap.get_area() <= 0:
			continue
		var resource := _dynamic_sprite_resource(
			sprite_archive, int(command.sprite_id), bool(command.flip), divisor
		)
		if resource.is_empty():
			continue
		var occluder_image: Image = resource.image
		if train_foreground:
			occluder_image = _dynamic_train_foreground_image(
				sprite_archive, command, divisor, resource.image
			)
		if mask == null:
			mask = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			mask.fill(Color.TRANSPARENT)
		mask.blend_rect(
			occluder_image,
			Rect2i(overlap.position - occluder_position, overlap.size),
			overlap.position - position,
		)
		if use_later_static:
			later_occluder_added = true
			if not is_train:
				break
	return mask


func _set_static_occlusion_commands(commands: Array, view_size: int) -> void:
	static_occlusion_commands.assign(commands)
	var divisor := int(IsometricRenderer.view_configuration(view_size).divisor)
	static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
		static_occlusion_commands, divisor
	)


func _dynamic_train_foreground_image(
	sprite_archive: Sc2SpriteArchive,
	command: Dictionary,
	divisor: int,
	surface: Image
) -> Image:
	var reference_sprite_id := int(command.train_foreground_reference_sprite_id)
	if reference_sprite_id < 0:
		return surface
	var key := "%d:%d:%d:%d" % [
		int(command.sprite_id), int(command.flip), divisor, reference_sprite_id,
	]
	if dynamic_foreground_cache.has(key):
		return dynamic_foreground_cache[key]
	var reference := _dynamic_sprite_resource(
		sprite_archive, reference_sprite_id, bool(command.flip), divisor
	)
	if reference.is_empty():
		return surface
	var foreground := IsometricRenderer.foreground_difference_mask(
		surface, reference.image
	)
	dynamic_foreground_cache[key] = foreground
	return foreground


func _dynamic_sprite_resource(
	sprite_archive: Sc2SpriteArchive, sprite_id: int, flip: bool, divisor: int
) -> Dictionary:
	var key := "%d:%d:%d" % [sprite_id, int(flip), divisor]
	if dynamic_sprite_cache.has(key):
		return dynamic_sprite_cache[key]
	var entry := sprite_archive.find_sprite(sprite_id)
	if entry == null:
		return {}
	var indexed := entry.create_image(palette_index_encoding)
	if not indexed.ok:
		return {}
	var image: Image = indexed.image
	if flip or divisor > 1:
		image = image.duplicate()
	if flip:
		image.flip_x()
	if divisor > 1:
		image.resize(
			image.get_width() * divisor,
			image.get_height() * divisor,
			Image.INTERPOLATE_NEAREST
		)
	var texture := ImageTexture.create_from_image(image)
	var resource := {
		"image": image,
		"texture": texture,
		"index_texture": texture,
	}
	dynamic_sprite_cache[key] = resource
	return resource


func _dynamic_shadow_image(
	mask: Image, position: Vector2i, occluder_mask: Image = null
) -> Image:
	if static_city_image == null:
		return null
	var shadow := Image.create(
		mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8
	)
	shadow.fill(Color.TRANSPARENT)
	var changed_pixels := 0
	for source_y in mask.get_height():
		var output_y := position.y + source_y
		if output_y < 0 or output_y >= static_city_image.get_height():
			continue
		for source_x in mask.get_width():
			if mask.get_pixel(source_x, source_y).a == 0.0:
				continue
			if (
				occluder_mask != null
				and occluder_mask.get_pixel(source_x, source_y).a > 0.0
			):
				continue
			var output_x := position.x + source_x
			if output_x < 0 or output_x >= static_city_image.get_width():
				continue
			var current := static_city_image.get_pixel(output_x, output_y)
			var palette_index := roundi(current.r * 255.0)
			var changed_index := IsometricRenderer.shadow_palette_index(palette_index)
			if changed_index != palette_index:
				shadow.set_pixel(
					source_x, source_y,
					Color8(changed_index, changed_index, changed_index, 255)
				)
				changed_pixels += 1
	return shadow if changed_pixels > 0 else null


func _show_effect_events(effect_events: Array, sound_events: Array) -> void:
	if city == null:
		return
	var visuals: Array[Dictionary] = []
	for effect in effect_events:
		if effect.get("type", "") == "earthquake":
			map_view.shake_view(
				int(effect.get("frames", 24)),
				float(effect.get("frame_msec", 5)) / 1000.0,
				float(effect.get("distance", 4)),
			)
	if overlay_mode == "city":
		var view_size := _city_view_size()
		var sprite_archive := _sprite_archive_for_view(view_size)
		var divisor := int(IsometricRenderer.view_configuration(view_size).divisor)
		for effect in effect_events:
			if effect.get("type", "") == "earthquake":
				continue
			var sprite_id := IsometricRenderer.effect_sprite_id(
				int(effect.get("sprite_id", 0)), view_size
			)
			var sprite := sprite_archive.find_sprite(sprite_id)
			if sprite == null:
				continue
			var rendered := sprite.create_image(palette)
			if not rendered.ok:
				continue
			var effect_image: Image = rendered.image
			if effect.get("flip", false):
				effect_image.flip_x()
			var position := IsometricRenderer.transient_effect_position(
				city, effect, effect_image.get_height(), view_size
			)
			if position.x < 0 or position.y < 0:
				continue
			if divisor > 1:
				effect_image.resize(
					effect_image.get_width() * divisor,
					effect_image.get_height() * divisor,
					Image.INTERPOLATE_NEAREST
				)
			visuals.append({
				"texture": ImageTexture.create_from_image(effect_image),
				"position": Vector2(position * divisor),
				"frame": int(effect.get("frame", 0)),
			})
		map_view.show_transient_effects(visuals, 0.1)
	if sound_events.is_empty():
		return
	var sound_path := reference_root.path_join(
		"SOUNDS/%d.WAV" % int(sound_events[0])
	)
	if not FileAccess.file_exists(sound_path):
		return
	var stream := AudioStreamWAV.load_from_file(sound_path)
	if stream != null:
		sound_player.stream = stream
		sound_player.play()


func _show_news_items(news_items: Array) -> void:
	for item in news_items:
		var news_type := int(item.get("type", 0))
		var name: String = NEWS_NAMES.get(news_type, "City report")
		recent_news.insert(0, "%s (0x%X)" % [name, news_type])
	while recent_news.size() > 3:
		recent_news.remove_at(recent_news.size() - 1)
	if not recent_news.is_empty():
		news_label.text = "Latest Reports\n" + "\n".join(recent_news)


func _show_game_over_events(events: Array) -> void:
	game_over_active = true
	var messages := PackedStringArray()
	for event in events:
		match event.get("type", ""):
			"scenario_victory":
				messages.append("The scenario goals are complete.")
			"scenario_failure":
				messages.append("The scenario time limit expired.")
			"bankruptcy":
				messages.append("The city is bankrupt. The mayor was impeached.")
	game_over_dialog.title = "Game Over" if events.size() != 1 else (
		"Scenario Complete"
		if events[0].get("type", "") == "scenario_victory"
		else "Game Over"
	)
	game_over_dialog.dialog_text = "\n".join(messages) + "\n\nOpen another city to continue."
	game_over_dialog.popup_centered()
	status_label.add_theme_color_override("font_color", Color("ffcf70"))
	status_label.text = "\n".join(messages)


func _moving_things_are_active(results: Array) -> bool:
	for result in results:
		for key in [
			"active_airplanes",
			"active_helicopters",
			"active_ships",
			"active_monsters",
			"active_explosions",
			"active_sailboats",
			"active_trains",
			"active_tornadoes",
			"active_maxis_men",
		]:
			if int(result.get(key, 0)) > 0:
				return true
	return false


func _select_tool_group(index: int) -> void:
	selected_group = group_selector.get_item_id(index)
	for button_index in toolbar_buttons.size():
		toolbar_buttons[button_index].button_pressed = button_index == selected_group
	if selected_group == Dispatch.GROUP_DISPATCH:
		dispatch_cycles = PackedInt32Array([0, 0, 0])
		dispatch_initialized = false
	tool_selector.clear()
	var group := Tools.group(selected_group)
	var first_available_index := -1
	for subtool_index in group.tools.size():
		if _is_tool_variant(selected_group, subtool_index):
			continue
		var tool := Tools.tool(selected_group, subtool_index)
		var price := "Free" if tool.cost == 0 else "$%s" % _format_number(tool.cost)
		tool_selector.add_item("%s — %s" % [tool.name, price], subtool_index)
		var item_index := tool_selector.item_count - 1
		var available := city == null or ToolAvailability.is_available(
			city, selected_group, subtool_index
		)
		tool_selector.set_item_disabled(item_index, not available)
		if available and first_available_index < 0:
			first_available_index = item_index
	tool_selector.disabled = first_available_index < 0
	var selected_item := first_available_index if first_available_index >= 0 else 0
	tool_selector.select(selected_item)
	selected_subtool = tool_selector.get_item_id(selected_item)
	_update_edit_state()


func _select_subtool(index: int) -> void:
	selected_subtool = tool_selector.get_item_id(index)
	_update_edit_state()
	if selected_tool_available and _is_tool_chooser(selected_group, selected_subtool):
		_open_tool_choice_dialog(selected_group)


func _is_tool_chooser(group_index: int, subtool_index: int) -> bool:
	return (
		(group_index == 3 and subtool_index == 1)
		or (group_index == 5 and subtool_index == 4)
	)


func _is_tool_variant(group_index: int, subtool_index: int) -> bool:
	return (
		(group_index == 3 and subtool_index >= 2)
		or (group_index == 5 and subtool_index >= 5)
	)


func _refresh_tool_availability() -> bool:
	if city == null or tool_selector == null:
		return false
	var changed := false
	var available_count := 0
	for item_index in tool_selector.item_count:
		var subtool_index := tool_selector.get_item_id(item_index)
		var available := ToolAvailability.is_available(
			city, selected_group, subtool_index
		)
		if tool_selector.is_item_disabled(item_index) == available:
			tool_selector.set_item_disabled(item_index, not available)
			changed = true
		if available:
			available_count += 1
	var selector_disabled := available_count == 0
	if tool_selector.disabled != selector_disabled:
		tool_selector.disabled = selector_disabled
		changed = true
	var current_available := ToolAvailability.is_available(
		city, selected_group, selected_subtool
	)
	return changed or current_available != selected_tool_available


func _update_edit_state() -> void:
	if map_view == null:
		return
	var tool_available := city != null and ToolAvailability.is_available(
		city, selected_group, selected_subtool
	)
	selected_tool_available = tool_available
	var is_zone_tool := Zones.supports_tool(selected_group, selected_subtool)
	var is_landscape_tool := Landscapes.supports_tool(selected_group, selected_subtool)
	var is_building_tool := Buildings.supports_tool(selected_group, selected_subtool)
	var is_network_tool := Networks.supports_tool(selected_group, selected_subtool)
	var is_hydro_tool := Hydro.supports_tool(selected_group, selected_subtool)
	var is_subway_to_rail_tool := SubwayToRail.supports_tool(selected_group, selected_subtool)
	var is_onramp_tool := Onramps.supports_tool(selected_group, selected_subtool)
	var is_tunnel_tool := Tunnels.supports_tool(selected_group, selected_subtool)
	var is_highway_tool := Highways.supports_tool(selected_group, selected_subtool)
	var is_demolish_tool := Demolish.supports_tool(selected_group, selected_subtool)
	var is_terrain_tool := TerrainTools.supports_tool(selected_group, selected_subtool)
	var is_dispatch_tool := Dispatch.supports_tool(selected_group, selected_subtool)
	var is_sign_tool := selected_group == 15
	var is_query_tool := selected_group == 16
	var is_center_tool := selected_group == 17
	var is_underground_network_tool := (
		(selected_group == 4 and selected_subtool == 0)
		or (selected_group == 7 and selected_subtool == 1)
	)
	map_view.set_edit_enabled(
		tool_available
			and (
				overlay_mode == "city"
				or (
					overlay_mode == "underground"
					and (is_underground_network_tool or is_demolish_tool)
				)
			)
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
			or is_demolish_tool
			or is_terrain_tool
			or is_dispatch_tool
			or is_sign_tool
			or is_query_tool
			or is_center_tool
		),
		(
			"rectangle"
			if is_zone_tool or is_demolish_tool
			else (
				"path"
				if is_landscape_tool or is_network_tool or is_highway_tool or is_terrain_tool
				else "point"
			)
		),
	)
	if city == null or status_label == null:
		return
	var tool := Tools.tool(selected_group, selected_subtool)
	status_label.remove_theme_color_override("font_color")
	if not tool_available:
		status_label.text = "%s is not available in this city." % tool.name
	elif _is_tool_chooser(selected_group, selected_subtool):
		status_label.text = "%s selected. Select an available type from the choice window." % tool.name
	elif is_zone_tool:
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
	elif is_demolish_tool:
		status_label.text = "Demolish selected. Drag a rectangle across eligible city tiles."
	elif is_terrain_tool:
		status_label.text = "%s selected. Click or drag across terrain." % tool.name
	elif is_dispatch_tool:
		var available := Dispatch.availability(city)
		var count := 0
		if available.ok:
			count = [available.police, available.fire, available.military][selected_subtool]
		status_label.text = "%s selected. Click dry, unlabeled terrain to deploy one of %d available units." % [tool.name, count]
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
	if not ToolAvailability.is_available(city, selected_group, selected_subtool):
		_show_error(
			"%s is not available in this city."
			% Tools.tool(selected_group, selected_subtool).name
		)
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
	if Dispatch.supports_tool(selected_group, selected_subtool):
		var cycles_before := dispatch_cycles.duplicate()
		var initialized_before := dispatch_initialized
		var dispatch := Dispatch.apply(
			city,
			selected_group,
			selected_subtool,
			finish,
			dispatch_cycles[selected_subtool],
			not dispatch_initialized
		)
		if not dispatch.ok:
			_show_error("Cannot dispatch unit: %s" % dispatch.error)
			return
		dispatch["dispatch_cycles_before"] = cycles_before
		dispatch["dispatch_initialized_before"] = initialized_before
		dispatch_initialized = true
		dispatch_cycles[selected_subtool] = int(dispatch.slot_index)
		dispatch["dispatch_cycles_after"] = dispatch_cycles.duplicate()
		last_edit_command = dispatch
		undo_button.disabled = false
		_refresh_map(false)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Deployed %s unit %d of %d." % [
			Tools.tool(selected_group, selected_subtool).name,
			dispatch.slot_index,
			dispatch.available,
		]
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
		_refresh_map(false)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "%s changed %d path tiles for $%s." % [
			Tools.tool(selected_group, selected_subtool).name,
			landscape.tile_indices.size(),
			_format_number(landscape.cost),
		]
		if landscape.skipped_insufficient > 0:
			status_label.text += " Funds were not sufficient for %d later path tiles." % landscape.skipped_insufficient
		return
	if Demolish.supports_tool(selected_group, selected_subtool):
		var demolition := Demolish.apply_path(
			city,
			selected_group,
			selected_subtool,
			path,
			tool_random,
			overlay_mode == "underground"
		)
		if not demolition.ok:
			_show_error("Cannot demolish: %s" % demolition.error)
			return
		last_edit_command = demolition
		undo_button.disabled = false
		_refresh_details()
		_refresh_map(false)
		_show_effect_events(demolition.effect_events, demolition.sound_events)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Applied %d demolition actions for $%s." % [
			demolition.action_count, _format_number(demolition.cost)
		]
		if demolition.skipped_specialized > 0:
			status_label.text += " %d specialized structures were not changed." % demolition.skipped_specialized
		if demolition.easter_events > 0:
			status_label.text += " A hidden tree event stopped demolition on %d tiles." % demolition.easter_events
		return
	if TerrainTools.supports_tool(selected_group, selected_subtool):
		var terrain_change := TerrainTools.apply_path(
			city, selected_group, selected_subtool, start, path, tool_random
		)
		if not terrain_change.ok:
			_show_error("Cannot change terrain: %s" % terrain_change.error)
			return
		last_edit_command = terrain_change
		undo_button.disabled = false
		_refresh_details()
		_refresh_map(false)
		_show_effect_events(terrain_change.effect_events, terrain_change.sound_events)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "%s applied %d actions for $%s." % [
			Tools.tool(selected_group, selected_subtool).name,
			terrain_change.action_count,
			_format_number(terrain_change.cost),
		]
		if terrain_change.skipped_conflicts > 0:
			status_label.text += " %d structure conflicts were not changed." % terrain_change.skipped_conflicts
		return
	if Networks.supports_tool(selected_group, selected_subtool):
		_apply_network_selection(start, finish)
		return
	if Hydro.supports_tool(selected_group, selected_subtool):
		var hydro := Hydro.apply(city, selected_group, selected_subtool, finish, tool_random)
		if not hydro.ok:
			_show_error("Cannot build hydroelectric power: %s" % hydro.error)
			return
		last_edit_command = hydro
		undo_button.disabled = false
		_refresh_details()
		_refresh_map(false)
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
		_refresh_map(false)
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
		_refresh_map(false)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built an on-ramp for $%s." % _format_number(onramp.cost)
		return
	if Tunnels.supports_tool(selected_group, selected_subtool):
		_apply_tunnel_selection(finish)
		return
	if Highways.supports_tool(selected_group, selected_subtool):
		_apply_highway_selection(start, finish)
		return
	if Buildings.supports_tool(selected_group, selected_subtool):
		var building_group := selected_group
		var building_subtool := selected_subtool
		var building_name: String = Tools.tool(
			building_group, building_subtool
		).name
		var building := Buildings.apply(
			city, building_group, building_subtool, finish, nuisance_random, tool_random
		)
		if not building.ok:
			_show_error(
				"Cannot build %s: %s"
				% [building_name, building.error]
			)
			return
		last_edit_command = building
		undo_button.disabled = false
		_refresh_details()
		_refresh_map(false)
		if building_group == 5 and building_subtool < 4:
			_choose_tool_group(17)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built %s for $%s." % [
			building_name,
			_format_number(building.cost),
		]
		if building.get("stadium_team_selection_required", false):
			_open_stadium_dialog(building)
			status_label.text += " Select a stadium team."
		return
	var command := Zones.apply_rectangle(city, selected_group, selected_subtool, start, finish)
	if not command.ok:
		_show_error("Cannot apply %s: %s" % [Tools.tool(selected_group, selected_subtool).name, command.error])
		return
	command["command_type"] = "zone"
	last_edit_command = command
	undo_button.disabled = false
	_refresh_details()
	_refresh_map(false)
	status_label.remove_theme_color_override("font_color")
	status_label.text = "%s changed %d tiles for $%s." % [
		Tools.tool(selected_group, selected_subtool).name,
		command.tile_indices.size(),
		_format_number(command.cost),
	]


func _apply_network_selection(
	start: Vector2i,
	finish: Vector2i,
	bridge_type := Networks.BRIDGE_UNSELECTED,
	group_index := -1,
	subtool_index := -1
) -> void:
	if group_index < 0:
		group_index = selected_group
	if subtool_index < 0:
		subtool_index = selected_subtool
	var tool_name: String = Tools.tool(group_index, subtool_index).name
	var network := Networks.apply(
		city, group_index, subtool_index, start, finish, bridge_type
	)
	if network.get("bridge_selection_required", false):
		_open_bridge_dialog(start, finish, group_index, subtool_index, network)
		return
	if network.get("cancelled", false):
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Bridge selection canceled. No action was taken."
		return
	if not network.get("ok", false):
		_show_error(
			"Cannot build %s: %s"
			% [tool_name, network.get("error", "unknown error")]
		)
		return
	last_edit_command = network
	undo_button.disabled = false
	_refresh_details()
	_refresh_map(false)
	status_label.remove_theme_color_override("font_color")
	var dry_count := int(network.get("dry_points", []).size())
	if network.get("bridge_built", false):
		if dry_count > 0:
			status_label.text = "Built %d %s tiles and a %s across %d water tiles for $%s." % [
				dry_count,
				tool_name,
				network.get("bridge_name", "bridge"),
				int(network.get("bridge_span_length", 0)),
				_format_number(int(network.get("cost", 0))),
			]
		else:
			status_label.text = "Built a %s across %d water tiles for $%s." % [
				network.get("bridge_name", "bridge"),
				int(network.get("bridge_span_length", 0)),
				_format_number(int(network.get("cost", 0))),
			]
	else:
		status_label.text = "Built %d %s tiles for $%s." % [
			dry_count, tool_name, _format_number(int(network.get("cost", 0)))
		]
		if network.get("bridge_cancelled", false):
			status_label.text += " Bridge selection was canceled."
		elif not String(network.get("bridge_error", "")).is_empty():
			status_label.text += " The bridge was not built: %s." % network.bridge_error
		elif network.get("stopped_early", false):
			status_label.text += " The route stopped at an obstruction."


func _open_tool_choice_dialog(group_index: int) -> void:
	if city == null or (group_index != 3 and group_index != 5):
		return
	var first_subtool := 2 if group_index == 3 else 5
	var final_subtool := 10 if group_index == 3 else 8
	var choices: Array[int] = []
	for subtool_index in range(first_subtool, final_subtool + 1):
		if ToolAvailability.is_available(city, group_index, subtool_index):
			choices.append(subtool_index)
	if choices.is_empty():
		_show_error("No building type is available for this chooser.")
		return
	pending_tool_choices = {
		"group_index": group_index,
		"subtools": choices,
	}
	tool_choice_dialog.title = (
		"Select Power Plant" if group_index == 3 else "Select Arcology"
	)
	tool_choice_dialog.dialog_text = (
		"Select an available power plant."
		if group_index == 3
		else "Select an available arcology."
	)
	for choice_index in tool_choice_buttons.size():
		var choice_button := tool_choice_buttons[choice_index]
		choice_button.visible = choice_index < choices.size()
		if not choice_button.visible:
			continue
		var tool := Tools.tool(group_index, choices[choice_index])
		choice_button.text = "%s\n$%s" % [
			tool.name,
			_format_number(int(tool.cost)),
		]
		choice_button.tooltip_text = "Select %s" % tool.name
	tool_choice_dialog.popup_centered()


func _choose_tool_variant(choice_index: int) -> void:
	if pending_tool_choices.is_empty():
		return
	var choices: Array = pending_tool_choices.get("subtools", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	selected_group = int(pending_tool_choices.group_index)
	selected_subtool = int(choices[choice_index])
	pending_tool_choices.clear()
	tool_choice_dialog.hide()
	_update_edit_state()


func _cancel_tool_choice() -> void:
	pending_tool_choices.clear()
	_update_edit_state()


func _open_stadium_dialog(command: Dictionary) -> void:
	var choices := Buildings.stadium_team_choices(city)
	if choices.is_empty():
		_show_error("Cannot read the available stadium teams.")
		return
	pending_stadium_command = command.duplicate(true)
	stadium_team_selector.clear()
	for team_index in choices:
		stadium_team_selector.add_item(
			Buildings.stadium_team_name(city, team_index), team_index
		)
	stadium_team_selector.select(0)
	_select_stadium_team(0)
	stadium_dialog.popup_centered()
	stadium_name_input.grab_focus()
	stadium_name_input.select_all()


func _select_stadium_team(item_index: int) -> void:
	if item_index < 0 or item_index >= stadium_team_selector.item_count:
		return
	var team_index := stadium_team_selector.get_item_id(item_index)
	stadium_name_input.text = Buildings.stadium_team_name(city, team_index)
	stadium_name_input.select_all()


func _confirm_stadium_team() -> void:
	if pending_stadium_command.is_empty():
		return
	var item_index := stadium_team_selector.selected
	if item_index < 0:
		_show_error("Select a stadium team.")
		call_deferred("_restore_stadium_dialog")
		return
	var team_index := stadium_team_selector.get_item_id(item_index)
	var result := Buildings.assign_stadium_team(
		city,
		pending_stadium_command,
		team_index,
		stadium_name_input.text,
	)
	if not result.ok:
		_show_error("Cannot assign stadium team: %s" % result.error)
		call_deferred("_restore_stadium_dialog")
		return
	last_edit_command = result.command
	pending_stadium_command.clear()
	_refresh_details()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Assigned %s to the new stadium." % result.team_name


func _cancel_stadium_team() -> void:
	pending_stadium_command.clear()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "The stadium was built without a team."


func _restore_stadium_dialog() -> void:
	if not pending_stadium_command.is_empty():
		stadium_dialog.popup_centered()


func _open_bridge_dialog(
	start: Vector2i,
	finish: Vector2i,
	group_index: int,
	subtool_index: int,
	result: Dictionary,
	request_type := "network"
) -> void:
	pending_bridge_request = {
		"start": start,
		"finish": finish,
		"group_index": group_index,
		"subtool_index": subtool_index,
		"request_type": request_type,
		"choices": result.get("bridge_choices", []),
		"dry_points": result.get(
			"dry_points", result.get("dry_sections", [])
		),
	}
	var span_units := (
		"2 by 2 water sections" if request_type == "highway" else "water tiles"
	)
	bridge_dialog.dialog_text = "Select a bridge for %d %s." % [
		int(result.get("bridge_span_length", 0)), span_units,
	]
	var choices: Array = pending_bridge_request.choices
	for choice_index in bridge_choice_buttons.size():
		var choice_button := bridge_choice_buttons[choice_index]
		choice_button.visible = choice_index < choices.size()
		if not choice_button.visible:
			continue
		var choice: Dictionary = choices[choice_index]
		var cost_unit := (
			"2 by 2 water section" if request_type == "highway" else "water tile"
		)
		choice_button.text = "%s\n$%s total\n$%s for each %s" % [
			choice.get("name", "Bridge"),
			_format_number(int(choice.get("cost", 0))),
			_format_number(int(choice.get("cost_per_tile", 0))),
			cost_unit,
		]
		choice_button.tooltip_text = "Build %s" % choice.get("name", "bridge")
	bridge_dialog.popup_centered()


func _choose_bridge(choice_index: int) -> void:
	if pending_bridge_request.is_empty():
		return
	var request := pending_bridge_request.duplicate(true)
	var choices: Array = request.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: Dictionary = choices[choice_index]
	pending_bridge_request.clear()
	bridge_dialog.hide()
	if request.get("request_type", "network") == "highway":
		selected_group = int(request.group_index)
		selected_subtool = int(request.subtool_index)
		_apply_highway_selection(
			request.start,
			request.finish,
			Highways.CONNECTION_UNSELECTED,
			int(choice.get("type", Highways.BRIDGE_UNSELECTED))
		)
		return
	_apply_network_selection(
		request.start,
		request.finish,
		int(choice.get("type", Networks.BRIDGE_UNSELECTED)),
		int(request.group_index),
		int(request.subtool_index)
	)


func _cancel_bridge() -> void:
	if pending_bridge_request.is_empty():
		return
	var request := pending_bridge_request.duplicate(true)
	pending_bridge_request.clear()
	if request.get("dry_points", []).is_empty():
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Bridge selection canceled. No action was taken."
		return
	if request.get("request_type", "network") == "highway":
		selected_group = int(request.group_index)
		selected_subtool = int(request.subtool_index)
		_apply_highway_selection(
			request.start,
			request.finish,
			Highways.CONNECTION_UNSELECTED,
			Highways.BRIDGE_CANCELLED
		)
		return
	_apply_network_selection(
		request.start,
		request.finish,
		Networks.BRIDGE_CANCELLED,
		int(request.group_index),
		int(request.subtool_index)
	)


func _apply_tunnel_selection(
	start: Vector2i,
	confirmation_choice := Tunnels.CONFIRMATION_UNSELECTED
) -> void:
	var tunnel := Tunnels.apply(
		city, selected_group, selected_subtool, start, confirmation_choice
	)
	if tunnel.get("confirmation_required", false):
		pending_tunnel_request = {
			"start": start,
			"group_index": selected_group,
			"subtool_index": selected_subtool,
		}
		tunnel_dialog.dialog_text = (
			"Engineers report that tunnel construction costs will be $%s.\n"
			+ "Do you wish to construct the tunnel?"
		) % _format_number(int(tunnel.cost))
		tunnel_dialog.popup_centered()
		return
	if tunnel.get("cancelled", false):
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Tunnel construction canceled. No action was taken."
		return
	if not tunnel.get("ok", false):
		_show_error("Cannot build tunnel: %s" % tunnel.get("error", "unknown error"))
		return
	last_edit_command = tunnel
	undo_button.disabled = false
	_refresh_details()
	_refresh_map(false)
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Built a %d-tile tunnel for $%s." % [
		tunnel.points.size(), _format_number(tunnel.cost)
	]


func _confirm_tunnel() -> void:
	_apply_pending_tunnel(Tunnels.CONFIRMATION_CONFIRMED)


func _cancel_tunnel() -> void:
	_apply_pending_tunnel(Tunnels.CONFIRMATION_CANCELLED)


func _apply_pending_tunnel(confirmation_choice: int) -> void:
	if pending_tunnel_request.is_empty():
		return
	var request := pending_tunnel_request.duplicate()
	pending_tunnel_request.clear()
	tunnel_dialog.hide()
	selected_group = int(request.group_index)
	selected_subtool = int(request.subtool_index)
	_apply_tunnel_selection(request.start, confirmation_choice)


func _apply_highway_selection(
	start: Vector2i,
	finish: Vector2i,
	connection_choice := Highways.CONNECTION_UNSELECTED,
	bridge_type := Highways.BRIDGE_UNSELECTED
) -> void:
	var highway := Highways.apply(
		city,
		selected_group,
		selected_subtool,
		start,
		finish,
		connection_choice,
		bridge_type
	)
	if highway.get("bridge_selection_required", false):
		_open_bridge_dialog(
			start,
			finish,
			selected_group,
			selected_subtool,
			highway,
			"highway"
		)
		return
	if highway.get("cancelled", false):
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Bridge selection canceled. No action was taken."
		return
	if highway.get("connection_selection_required", false):
		pending_highway_connection = {
			"start": start,
			"finish": finish,
			"group_index": selected_group,
			"subtool_index": selected_subtool,
		}
		highway_connection_dialog.dialog_text = (
			"Build a highway connection to a neighboring city for $%s?\n"
			+ "The %d-section highway costs $%s and remains if you cancel."
		) % [
			_format_number(int(highway.get("connection_cost", 0))),
			highway.get("sections", []).size(),
			_format_number(int(highway.get("route_cost", 0))),
		]
		highway_connection_dialog.popup_centered()
		return
	if not highway.get("ok", false):
		_show_error("Cannot build highway: %s" % highway.get("error", "unknown error"))
		return
	last_edit_command = highway
	undo_button.disabled = false
	_refresh_details()
	_refresh_map(false)
	status_label.remove_theme_color_override("font_color")
	if highway.get("bridge_built", false):
		if highway.sections.is_empty():
			status_label.text = "Built a %s across %d water sections for $%s." % [
				highway.get("bridge_name", "highway bridge"),
				int(highway.get("bridge_span_length", 0)),
				_format_number(int(highway.cost)),
			]
		else:
			status_label.text = "Built %d highway sections and a %s across %d water sections for $%s." % [
				highway.sections.size(),
				highway.get("bridge_name", "highway bridge"),
				int(highway.get("bridge_span_length", 0)),
				_format_number(int(highway.cost)),
			]
	elif highway.get("connection_built", false):
		status_label.text = "Built %d highway sections and a neighboring-city connection for $%s." % [
			highway.sections.size(), _format_number(int(highway.cost))
		]
	else:
		status_label.text = "Built %d highway sections for $%s." % [
			highway.sections.size(), _format_number(int(highway.cost))
		]
		if highway.get("connection_cancelled", false):
			status_label.text += " The neighbor connection was canceled."
		elif highway.get("bridge_cancelled", false):
			status_label.text += " The bridge selection was canceled."
		elif not String(highway.get("bridge_error", "")).is_empty():
			status_label.text += " The bridge was not built: %s." % highway.bridge_error
		elif not String(highway.get("connection_error", "")).is_empty():
			status_label.text += " The connection was not offered because funds are too low."
		elif highway.get("stopped_early", false):
			status_label.text += " The route stopped at an obstruction."


func _confirm_highway_connection() -> void:
	_apply_pending_highway_connection(Highways.CONNECTION_CONFIRMED)


func _cancel_highway_connection() -> void:
	_apply_pending_highway_connection(Highways.CONNECTION_CANCELLED)


func _apply_pending_highway_connection(connection_choice: int) -> void:
	if pending_highway_connection.is_empty():
		return
	var request := pending_highway_connection.duplicate()
	pending_highway_connection.clear()
	highway_connection_dialog.hide()
	selected_group = int(request.group_index)
	selected_subtool = int(request.subtool_index)
	_apply_highway_selection(request.start, request.finish, connection_choice)


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
	elif command_type == "demolish":
		result = Demolish.undo(city, last_edit_command, tool_random)
	elif command_type == "terrain":
		result = TerrainTools.undo(city, last_edit_command, tool_random)
	elif command_type == "dispatch":
		result = Dispatch.undo(city, last_edit_command)
	else:
		result = Zones.undo(city, last_edit_command)
	if not result.ok:
		_show_error("Cannot undo the last edit: %s" % result.error)
		return
	if command_type == "dispatch":
		dispatch_cycles = last_edit_command.get("dispatch_cycles_before", dispatch_cycles)
		dispatch_initialized = bool(
			last_edit_command.get("dispatch_initialized_before", dispatch_initialized)
		)
	last_edit_command = {}
	undo_button.disabled = true
	_refresh_details()
	_refresh_map(false)
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
	elif command_type == "demolish":
		status_label.text = "Restored %d demolished tiles and the previous funds value." % result.restored_tiles
	elif command_type == "terrain":
		status_label.text = "Restored %d terrain tiles and the previous funds value." % result.restored_tiles
	elif command_type == "dispatch":
		status_label.text = "Restored the previous dispatched unit."
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
	_refresh_map(false)
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Sign removed." if result.new_overlay == 0 else "Sign saved as label %d." % result.label_id


func _cancel_sign() -> void:
	pending_sign_tile = Vector2i(-1, -1)


func _open_query(point: Vector2i) -> void:
	var result := Queries.inspect(city, point)
	if not result.ok:
		_show_error("Cannot query tile: %s" % result.error)
		return
	if result.get("overlay_id", 0) == 111 and simulation_engine != null:
		var approval := simulation_engine.recalculate_mayor_house()
		if not approval.get("ok", false):
			_show_error("Cannot calculate mayor approval: %s" % approval.error)
			return
		_show_news_items(approval.news_items)
		result = Queries.inspect(city, point)
	query_dialog.dialog_text = Queries.format_text(result)
	query_dialog.popup_centered()


func _refresh_details() -> void:
	if city == null:
		return
	var demand := city.rci_demand()
	var weather_trend := city.document.misc_u32(RciAftermath.MISC_WEATHER_TREND) & 0xff
	var weather_name: String = (
		RciAftermath.WEATHER_NAMES[weather_trend]
		if weather_trend < RciAftermath.WEATHER_NAMES.size()
		else "Unknown"
	)
	title_stats_label.text = "%04d-%02d-%02d   $%s" % [
		city.current_year(),
		city.current_month(),
		city.current_day(),
		_format_number(city.funds()),
	]
	details_label.text = (
		"Mayor: %s\nPopulation: %s\nWeather: %s\n\nDemand\nResidential: %+d\nCommercial: %+d\nIndustrial: %+d"
		% [
			city.mayor_name() if not city.mayor_name().is_empty() else "Unknown",
			_format_number(city.population()),
			weather_name,
			demand.x,
			demand.y,
			demand.z,
		]
	)
	if _refresh_tool_availability():
		_update_edit_state()


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
