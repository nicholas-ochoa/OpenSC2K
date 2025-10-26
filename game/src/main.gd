extends Control

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const NewCity = preload("res://src/model/new_city_setup.gd")
const NewTerrain = preload("res://src/model/new_city_terrain.gd")
const ScenarioModel = preload("res://src/model/scenario_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const ScurkTileSet = preload("res://src/assets/scurk_mif.gd")
const ScurkCityOutput = preload("res://src/assets/scurk_city_output.gd")
const PeBitmap = preload("res://src/assets/pe_bitmap_resource.gd")
const PeString = preload("res://src/assets/pe_string_resource.gd")
const TextUsa = preload("res://src/assets/text_usa_resource.gd")
const DataUsa = preload("res://src/assets/data_usa_resource.gd")
const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const RenderJob = preload("res://src/view/city_render_job.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")
const MapControl = preload("res://src/view/city_map_control.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")
const GraphView = preload("res://src/view/city_graph_control.gd")
const PopulationView = preload("res://src/view/population_window_control.gd")
const IndustryView = preload("res://src/view/industry_window_control.gd")
const SimNationView = preload("res://src/view/simnation_window_control.gd")
const OrdinanceView = preload("res://src/view/ordinance_window_control.gd")
const CityMapView = preload("res://src/view/city_map_window_control.gd")
const RciStatusView = preload("res://src/view/rci_status_control.gd")
const Tools = preload("res://src/tools/tool_catalog.gd")
const ToolAvailability = preload("res://src/tools/tool_availability.gd")
const Zones = preload("res://src/tools/zone_command.gd")
const Signs = preload("res://src/tools/sign_command.gd")
const Queries = preload("res://src/tools/query_info.gd")
const QueryFacilityActions = preload("res://src/tools/query_actions.gd")
const CityQueryDialogView = preload("res://src/ui/city_query_dialog.gd")
const LibraryWindowLayout = preload("res://src/ui/library_window_layout.gd")
const NewspaperDialogView = preload("res://src/ui/newspaper_dialog.gd")
const MainMenuView = preload("res://src/ui/main_menu_control.gd")
const NewCityTerrainDialogView = preload("res://src/ui/new_city_terrain_dialog.gd")
const BudgetDialogView = preload("res://src/ui/budget_dialog.gd")
const ScurkEditorView = preload("res://src/ui/scurk_editor_control.gd")
const ScurkPlacePrintView = preload("res://src/ui/scurk_place_print_control.gd")
const ScurkPrintView = preload("res://src/ui/scurk_print_control.gd")
const Landscapes = preload("res://src/tools/landscape_command.gd")
const Random = preload("res://src/simulation/sim_random.gd")
const GameRandom = preload("res://src/simulation/game_lcg_random.gd")
const Buildings = preload("res://src/tools/building_command.gd")
const ToolSounds = preload("res://src/audio/tool_sound_rules.gd")
const WaveSounds = preload("res://src/audio/wave_sound_gate.gd")
const MovingThingAudio = preload("res://src/audio/moving_thing_audio.gd")
const Networks = preload("res://src/tools/network_command.gd")
const Hydro = preload("res://src/tools/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/onramp_command.gd")
const Tunnels = preload("res://src/tools/tunnel_command.gd")
const Highways = preload("res://src/tools/highway_command.gd")
const Demolish = preload("res://src/tools/demolish_command.gd")
const TerrainTools = preload("res://src/tools/terrain_command.gd")
const Dispatch = preload("res://src/tools/dispatch_command.gd")
const ScurkPlace = preload("res://src/tools/scurk_place_command.gd")
const CityRotation = preload("res://src/tools/city_rotation_command.gd")
const Simulation = preload("res://src/simulation/simulation_engine.gd")
const GameSpeed = preload("res://src/simulation/game_speed_controller.gd")
const DisasterStart = preload("res://src/simulation/disaster_start_phase.gd")
const Budget = preload("res://src/simulation/budget_phase.gd")
const Bonds = preload("res://src/simulation/bond_command.gd")
const RciAftermath = preload("res://src/simulation/rci_aftermath_phase.gd")
const NewsQueue = preload("res://src/simulation/news_queue.gd")
const Music = preload("res://src/audio/music_director.gd")
const MidiSynth = preload("res://src/audio/midi_synth_player.gd")
const DebugActions = preload("res://src/debug/city_debug_actions.gd")

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
	0x28: "Forest protest",
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

const SIMNATION_FORMAT_STRING_ID := 421
const NEIGHBOR_NAME_STRING_FIRST := 548
const NEIGHBOR_NAME_STRING_LAST := 583
const CITY_MAP_STRING_FIRST := 327
const CITY_MAP_STRING_LAST := 344

const MAP_DISPLAY_MODES := ["city", "underground"]
const LIBRARY_TEXT_IDS := [3000, 3001, 3002, 3003]
const NEWSPAPER_STRING_FIRST := 347
const NEWSPAPER_STRING_LAST := 391
const ACTIVE_DISASTER_RENDER_INTERVAL_MSEC := 1200
const STATUS_REPORT_ROTATION_SECONDS := 7.0
const STATIC_EDIT_PATCH_MAX_AREA_RATIO := 0.25
const SOUND_EFFECT_GROUP := &"open_sc2k_sound_effects"
const MENU_AUTO_BUDGET := 0x8004
const MENU_AUTO_GOTO := 0x8005
const MENU_SOUND_EFFECTS := 0x8006
const MENU_MUSIC := 0x8007
const MENU_NO_DISASTERS := 0x800e
const MENU_VIEW_CITY_MAP := 0x8100
const MENU_VIEW_BUILDINGS := 0x8101
const MENU_VIEW_NETWORKS := 0x8102
const MENU_VIEW_WATER := 0x8103
const MENU_VIEW_TREES := 0x8104
const MENU_VIEW_ZONES := 0x8105
const MENU_VIEW_SIGNS := 0x8106
const MENU_VIEW_PIPES := 0x8107
const MENU_SCURK_PLACE_PRINT := 0x8200
const FOREST_PROTEST_BITMAP_ID := 403
const FOREST_PROTEST_STRING_ID := 236
const BUILDING_OBJECTION_STRING_ID := 106
const INDUSTRY_STRING_FIRST := 422
const INDUSTRY_STRING_LAST := 432

var city: CityState
var current_document: Sc2File
var saved_city_snapshot := PackedByteArray()
var current_save_path := ""
var current_city_saved_once := false
var palette: Sc2Palette
var scenario_palette: Sc2Palette
var palette_index_encoding: Sc2Palette
var large_sprites: Sc2SpriteArchive
var small_medium_sprites: Sc2SpriteArchive
var base_large_sprites: Sc2SpriteArchive
var base_small_medium_sprites: Sc2SpriteArchive
var active_scurk_tile_set: ScurkMif
var active_scurk_name := ""
var active_scurk_path := ""
var overlay_mode := "city"
var surface_visibility := {
	"buildings": true,
	"networks": true,
	"water": true,
	"trees": true,
	"zones": true,
	"signs": true,
}
var show_underground_pipes := true
var app_music_volume := 0.8
var app_effects_volume := 0.8
var app_fullscreen := false
var reference_root := ""
var original_query_strings: Dictionary = {}
var forest_protest_text := "Citizens are protesting forest demolition."
var building_objection_text := "Residents objected to this facility site."
var forest_protest_image: Image
var library_texts: Dictionary = {}
var newspaper_data: DataUsaResource
var newspaper_session_seed := 0
var newspaper_session_state := PackedByteArray()
var selected_group := 9
var selected_subtool := 0
var selected_tool_available := false
var last_edit_command: Dictionary = {}
var pending_sign_tile := Vector2i(-1, -1)
var tool_random := Random.new(1)
var nuisance_random := GameRandom.new(Time.get_ticks_msec() | 1)
var music_director := Music.new()
var music_player: MidiSynthPlayer
var dummy_music_active := false
var application_has_focus := true
var tool_loop_player: AudioStreamPlayer
var wave_sound_gate := WaveSounds.new()
var wave_stream_cache: Dictionary = {}
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
var dynamic_occluder_cache: Dictionary = {}
var dynamic_visual_cache: Dictionary = {}
var dynamic_special_batch_cache: Dictionary = {}
var dynamic_sign_occluders: Array[Dictionary] = []
var dynamic_sign_occlusion_grid: Dictionary = {}
var static_render_thread: Thread
var static_render_job: CityRenderJob
var static_render_epoch := 0
var last_static_render_started_msec := -ACTIVE_DISASTER_RENDER_INTERVAL_MSEC
var pending_static_render := false
var palette_cycle_ticks := 0
var palette_cycle_texture: ImageTexture

var map_view: CityMapControl
var city_label: Label
var status_label: Label
var status_population_label: Label
var status_weather_label: Label
var status_rci_graph: RciStatusControl
var status_reports_label: Label
var status_speed_label: Label
var file_dialog: FileDialog
var save_dialog: FileDialog
var tile_set_dialog: FileDialog
var scurk_city_export_dialog: FileDialog
var scurk_print_pdf_dialog: FileDialog
var new_city_dialog: NewCityTerrainDialog
var new_city_preview_document: Sc2File
var new_city_preview_options: Dictionary = {}
var new_city_preview_process_start := 1
var new_city_preview_game_start := 1
var new_city_preview_process_cursor := 1
var new_city_preview_game_cursor := 1
var options_menu: MenuButton
var speed_menu: MenuButton
var view_menu: MenuButton
var view_menu_underground_items := false
var disasters_menu: MenuButton
var view_visibility_checks: Dictionary = {}
var view_layers_heading: Label
var active_tool_group_label: Label
var child_tool_scroll: ScrollContainer
var child_tool_grid: GridContainer
var child_tool_buttons: Dictionary = {}
var toolbar_art_source: Image
var undo_button: Button
var title_stats_label: Label
var title_money_label: Label
var fps_label: Label
var zoom_label: Label
var zoom_in_button: Button
var zoom_out_button: Button
var rotate_counter_clockwise_button: Button
var rotate_clockwise_button: Button
var toolbar_buttons: Array[Button] = []
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
var network_connection_dialog: ConfirmationDialog
var pending_network_connection: Dictionary = {}
var highway_connection_dialog: ConfirmationDialog
var pending_highway_connection: Dictionary = {}
var tunnel_dialog: ConfirmationDialog
var pending_tunnel_request: Dictionary = {}
var query_dialog: CityQueryDialog
var active_query_result: Dictionary = {}
var city_analysis_dialog: AcceptDialog
var city_analysis_table: Tree
var newspaper_dialog: NewspaperDialog
var forest_protest_dialog: AcceptDialog
var forest_protest_message: Label
var building_objection_dialog: AcceptDialog
var building_objection_message: Label
var pending_building_objection_group := -1
var pending_building_objection_subtool := -1
var library_windows: Array[PanelContainer] = []
var library_text_views: Array[TextEdit] = []
var graph_window: Window
var graph_control: CityGraphControl
var graph_series_buttons: Array[CheckBox] = []
var population_window: Window
var population_control: PopulationWindowControl
var population_mode_buttons: Array[CheckBox] = []
var industry_window: Window
var industry_control: Control
var industry_mode_buttons: Array[CheckBox] = []
var simnation_window: Window
var simnation_control: Control
var ordinance_window: Window
var ordinance_control: OrdinanceWindowControl
var city_map_window: Window
var city_map_control: CityMapWindowControl
var main_menu: MainMenuControl
var settings_dialog: ConfirmationDialog
var settings_music_slider: HSlider
var settings_effects_slider: HSlider
var settings_fullscreen_check: CheckBox
var scurk_editor: ScurkEditorControl
var scurk_place_print: ScurkPlacePrintControl
var scurk_print: ScurkPrintControl
var pending_scurk_print_options: Dictionary = {}
var scurk_place_undo_stack: Array[Dictionary] = []
var scurk_place_redo_stack: Array[Dictionary] = []
var about_dialog: AcceptDialog
var save_changes_dialog: ConfirmationDialog
var pending_city_exit_action := ""
var pending_city_exit_path := ""
var pending_city_exit_waiting_for_save := false
var budget_dialog: BudgetDialog
var game_over_dialog: AcceptDialog
var military_dialog: ConfirmationDialog
var scenario_dialog: AcceptDialog
var scenario_picture_view: TextureRect
var scenario_text_view: TextEdit
var fps_update_seconds := 0.0
var status_report_index := 0
var status_report_elapsed_seconds := 0.0


func _ready() -> void:
	get_tree().auto_accept_quit = false
	reference_root = ProjectSettings.globalize_path("res://../references").simplify_path()
	_load_app_settings()
	_load_wave_sound_cache()
	music_player = MidiSynth.new()
	music_player.track_finished.connect(_on_music_track_finished)
	add_child(music_player)
	music_player.set_volume_linear(app_music_volume)
	newspaper_session_seed = Time.get_ticks_msec() & 0xffff
	if newspaper_session_seed & 0x8000:
		newspaper_session_seed -= 0x10000
	tool_random = Random.new(newspaper_session_seed)
	newspaper_session_state.resize(NewsQueue.MISC_SIZE)
	newspaper_session_state.fill(0)
	NewsQueue.initialize_session(newspaper_session_state, tool_random)
	newspaper_data = DataUsa.load_path(
		reference_root.path_join("DATA/DATA_USA.DAT"),
		reference_root.path_join("DATA/DATA_USA.IDX"),
	)
	var string_resource_ids := Queries.resource_string_ids()
	string_resource_ids.append(FOREST_PROTEST_STRING_ID)
	string_resource_ids.append(BUILDING_OBJECTION_STRING_ID)
	for resource_id in range(INDUSTRY_STRING_FIRST, INDUSTRY_STRING_LAST + 1):
		string_resource_ids.append(resource_id)
	for resource_id in range(CITY_MAP_STRING_FIRST, CITY_MAP_STRING_LAST + 1):
		string_resource_ids.append(resource_id)
	string_resource_ids.append(SIMNATION_FORMAT_STRING_ID)
	for resource_id in range(NEIGHBOR_NAME_STRING_FIRST, NEIGHBOR_NAME_STRING_LAST + 1):
		string_resource_ids.append(resource_id)
	for resource_id in range(NEWSPAPER_STRING_FIRST, NEWSPAPER_STRING_LAST + 1):
		string_resource_ids.append(resource_id)
	var string_resources := PeString.load_ids(
		reference_root.path_join("SIMCITY.EXE"), string_resource_ids
	)
	if string_resources.ok:
		original_query_strings = string_resources.strings
		forest_protest_text = string_resources.strings.get(
			FOREST_PROTEST_STRING_ID, forest_protest_text
		)
		building_objection_text = string_resources.strings.get(
			BUILDING_OBJECTION_STRING_ID, building_objection_text
		)
	var library_resources := TextUsa.load_ids(
		reference_root.path_join("DATA/TEXT_USA.DAT"),
		reference_root.path_join("DATA/TEXT_USA.IDX"),
		PackedInt32Array(LIBRARY_TEXT_IDS),
	)
	if library_resources.ok:
		library_texts = library_resources.strings
	var toolbar_resource := PeBitmap.load_numeric(
		reference_root.path_join("SIMCITY.EXE"), 2
	)
	var loaded_forest_protest := Image.load_from_file(
		reference_root.path_join("BITMAPS/%d.BMP" % FOREST_PROTEST_BITMAP_ID)
	)
	if loaded_forest_protest != null and not loaded_forest_protest.is_empty():
		forest_protest_image = loaded_forest_protest
	var toolbar_art: Image = toolbar_resource.get("image") as Image if toolbar_resource.ok else null
	_build_interface(toolbar_art)
	palette = Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MSTR.BMP"))
	if not palette.is_valid():
		_show_error(palette.load_error)
		return
	scenario_palette = Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MAC.BMP"))
	if not scenario_palette.is_valid():
		_show_error(scenario_palette.load_error)
		return
	palette_index_encoding = Palette.index_encoding()
	_update_palette_cycle_texture()
	base_large_sprites = SpriteArchive.load_path(reference_root.path_join("DATA/LARGE.DAT"))
	if not base_large_sprites.is_valid():
		_show_error(base_large_sprites.parse_error)
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
	base_small_medium_sprites = SpriteArchive.combine([base_small_medium, special_sprites])
	large_sprites = base_large_sprites
	small_medium_sprites = base_small_medium_sprites
	_refresh_child_tool_icons()

	_show_main_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		_request_city_exit("quit")
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_handle_application_focus_out()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_handle_application_focus_in()


func _process(delta: float) -> void:
	wave_sound_gate.advance(delta * 1000.0)
	_update_fps(delta)
	_update_status_report_rotation(delta)
	_poll_static_render()
	_start_pending_static_render()
	if speed_controller == null or city == null:
		return
	simulation_engine.midi_playback_active = _music_playback_is_active()
	var interaction_suspended := (
		(map_view != null and (map_view.is_left_drag_active() or map_view.is_panning()))
		or budget_dialog.visible
		or bridge_dialog.visible
		or tool_choice_dialog.visible
		or stadium_dialog.visible
		or network_connection_dialog.visible
		or highway_connection_dialog.visible
		or tunnel_dialog.visible
		or (forest_protest_dialog != null and forest_protest_dialog.visible)
		or (building_objection_dialog != null and building_objection_dialog.visible)
		or (query_dialog != null and query_dialog.visible)
		or (ordinance_window != null and ordinance_window.visible)
		or (new_city_dialog != null and new_city_dialog.visible)
		or (scurk_editor != null and scurk_editor.visible)
		or (scurk_place_print != null and scurk_place_print.visible)
		or (scurk_print != null and scurk_print.visible)
		or (main_menu != null and main_menu.visible)
		or (save_dialog != null and save_dialog.visible)
		or (scurk_city_export_dialog != null and scurk_city_export_dialog.visible)
		or (scurk_print_pdf_dialog != null and scurk_print_pdf_dialog.visible)
		or (save_changes_dialog != null and save_changes_dialog.visible)
		or budget_dialog.bond_confirmation_visible()
		or military_dialog.visible
		or scenario_dialog.visible
		or game_over_active
	)
	var result := speed_controller.advance_time(
		delta * 1000.0,
		Time.get_ticks_msec(),
		interaction_suspended
	)
	if not result.ok:
		speed_controller.set_speed(GameSpeed.Speed.PAUSED)
		_sync_speed_ui()
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
	if scurk_editor != null and scurk_editor.visible:
		if scurk_editor.handle_shortcut(event):
			get_viewport().set_input_as_handled()
		return
	if scurk_place_print != null and scurk_place_print.visible:
		if event.keycode == KEY_ESCAPE:
			_close_scurk_place_print()
			get_viewport().set_input_as_handled()
		return
	if main_menu != null and main_menu.visible:
		if event.keycode == KEY_ESCAPE and city != null:
			_hide_main_menu()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE and query_dialog != null and query_dialog.visible:
		_close_query(false)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and new_city_dialog != null and new_city_dialog.visible:
		_cancel_new_city()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_PLUS or event.keycode == KEY_EQUAL:
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
		scurk_place_undo_stack.clear()
		scurk_place_redo_stack.clear()
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
	for track_id in result.get("music_track_requests", PackedInt32Array()):
		if city.music_enabled():
			_play_music_track(int(track_id))
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
	toolbar_art_source = toolbar_art
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
	menu_bar.custom_minimum_size = Vector2(0, 25)
	menu_bar.add_theme_stylebox_override("panel", _classic_box(Color("c0c0c0"), Color("ffffff"), 0))
	page.add_child(menu_bar)
	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 0)
	menu_bar.add_child(menu_row)
	_add_menu(menu_row, "File", [
		["New City...", 0], ["Open City...", 1], ["Save City As...", 2],
		["Load Tile Set...", 3], ["Restore Original Tile Set", 4],
		["SCURK Place & Print...", MENU_SCURK_PLACE_PRINT],
		["Main Menu", 5], ["Exit", 6],
	], _on_file_menu)
	speed_menu = _add_menu(menu_row, "Speed", [
		["Pause", 0], ["Turtle", 1], ["Llama", 2], ["Cheetah", 3],
		["African Swallow", 4],
	], _on_speed_menu)
	for speed_id in range(5):
		var speed_index := speed_menu.get_popup().get_item_index(speed_id)
		speed_menu.get_popup().set_item_as_checkable(speed_index, true)
	options_menu = _add_menu(menu_row, "Options", [
		["Auto-Budget", MENU_AUTO_BUDGET], ["Auto-Goto", MENU_AUTO_GOTO],
		["Sound Effects", MENU_SOUND_EFFECTS], ["Music", MENU_MUSIC],
	], _on_options_menu)
	for option_id in [MENU_AUTO_BUDGET, MENU_AUTO_GOTO, MENU_SOUND_EFFECTS, MENU_MUSIC]:
		var option_index := options_menu.get_popup().get_item_index(option_id)
		options_menu.get_popup().set_item_as_checkable(option_index, true)
	options_menu.disabled = true
	view_menu = _add_menu(menu_row, "View", [
		["City View", 0], ["Underground View", 1],
		["City Map...", MENU_VIEW_CITY_MAP],
	], _on_view_menu)
	view_menu.get_popup().add_separator()
	for view_item in [
		["Show Buildings", MENU_VIEW_BUILDINGS],
		["Show Networks", MENU_VIEW_NETWORKS],
		["Show Water", MENU_VIEW_WATER],
		["Show Trees", MENU_VIEW_TREES],
		["Show Zones", MENU_VIEW_ZONES],
		["Show Signs", MENU_VIEW_SIGNS],
	]:
		view_menu.get_popup().add_check_item(view_item[0], view_item[1])
	disasters_menu = _add_menu(menu_row, "Disasters", [
		["Fire", 1], ["Flood", 2], ["Riot", 3], ["Toxic Spill", 4],
		["Air Crash", 5], ["Earthquake", 6], ["Tornado", 7], ["Monster", 8],
		["Meltdown", 9], ["Microwave", 10], ["Volcano", 11], ["Firestorm", 12],
		["Mass Riots", 13], ["Mass Floods", 14], ["Pollution", 15],
		["Hurricane", 16], ["Helicopter Crash", 17], ["Plane Crash", 18],
	], _on_disaster_menu)
	disasters_menu.get_popup().add_separator()
	disasters_menu.get_popup().add_check_item("No Disasters", MENU_NO_DISASTERS)
	var implemented_disasters := {
		1: true, 2: true, 3: true, 4: true, 5: true, 6: true, 7: true, 8: true,
		9: true, 10: true, 11: true, 12: true, 13: true, 14: true, 15: true,
		16: true, 17: true, 18: true,
	}
	for item_index in disasters_menu.get_popup().item_count:
		var disaster_id := disasters_menu.get_popup().get_item_id(item_index)
		if disaster_id > 0 and disaster_id != MENU_NO_DISASTERS:
			disasters_menu.get_popup().set_item_disabled(
				item_index, not implemented_disasters.has(disaster_id)
			)
	disasters_menu.tooltip_text = (
		"Air Crash and Helicopter Crash do nothing when selected, as in the original Windows game."
	)
	_add_menu(menu_row, "Windows", [
		["Budget", 0], ["Ordinances", 1], ["Population", 2],
		["City Industry", 3], ["Graphs", 4], ["Neighbors", 5],
		["City Map", 6],
	], _on_windows_menu)
	_add_menu(menu_row, "Newspaper", [["Show Latest Reports", 0]], _on_newspaper_menu)
	_add_menu(menu_row, "Help", [["City Window Help", 0]], _on_help_menu)
	var menu_spacer := Control.new()
	menu_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_row.add_child(menu_spacer)
	menu_row.add_child(VSeparator.new())
	var city_field := MarginContainer.new()
	city_field.name = "CityNameField"
	city_field.custom_minimum_size = Vector2(174, 0)
	city_field.add_theme_constant_override("margin_left", 9)
	city_field.add_theme_constant_override("margin_right", 4)
	menu_row.add_child(city_field)
	city_label = Label.new()
	city_label.text = "No city loaded"
	city_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	city_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	city_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	city_label.tooltip_text = city_label.text
	city_field.add_child(city_label)
	menu_row.add_child(VSeparator.new())
	status_population_label = _status_metric_label("Population: --", 148)
	status_population_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu_row.add_child(status_population_label)
	menu_row.add_child(VSeparator.new())
	title_stats_label = Label.new()
	title_stats_label.text = "--/--/----"
	title_stats_label.custom_minimum_size = Vector2(92, 0)
	title_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_stats_label.tooltip_text = "Current city date"
	menu_row.add_child(title_stats_label)
	menu_row.add_child(VSeparator.new())
	title_money_label = Label.new()
	title_money_label.text = "$--"
	title_money_label.custom_minimum_size = Vector2(92, 0)
	title_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_money_label.tooltip_text = "Current city funds"
	menu_row.add_child(title_money_label)
	menu_row.add_child(VSeparator.new())
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.custom_minimum_size = Vector2(72, 0)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fps_label.tooltip_text = "Current rendered frames per second"
	menu_row.add_child(fps_label)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	page.add_child(content)

	var toolbar_panel := PanelContainer.new()
	toolbar_panel.custom_minimum_size = Vector2(195, 0)
	toolbar_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toolbar_panel.add_theme_stylebox_override("panel", _classic_box(Color("c0c0c0"), Color("808080"), 2))
	content.add_child(toolbar_panel)
	var toolbar_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		toolbar_margin.add_theme_constant_override("margin_" + side, 6)
	toolbar_panel.add_child(toolbar_margin)
	var toolbar := VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	toolbar_margin.add_child(toolbar)
	var toolbar_title := Label.new()
	toolbar_title.text = "City Toolbar"
	toolbar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar_title.add_theme_color_override("font_color", Color("000080"))
	toolbar_title.add_theme_font_size_override("font_size", 14)
	toolbar.add_child(toolbar_title)

	var tool_grid := GridContainer.new()
	tool_grid.columns = 3
	tool_grid.add_theme_constant_override("h_separation", 3)
	tool_grid.add_theme_constant_override("v_separation", 3)
	tool_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toolbar.add_child(tool_grid)
	var tool_button_group := ButtonGroup.new()
	for group_index in range(15):
		_add_toolbar_group_button(
			tool_grid, tool_button_group, toolbar_art, group_index
		)

	var special_separator := HSeparator.new()
	toolbar.add_child(special_separator)
	var special_tool_grid := GridContainer.new()
	special_tool_grid.columns = 3
	special_tool_grid.add_theme_constant_override("h_separation", 3)
	special_tool_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toolbar.add_child(special_tool_grid)
	for group_index in range(15, Tools.GROUPS.size()):
		_add_toolbar_group_button(
			special_tool_grid, tool_button_group, toolbar_art, group_index
		)

	var camera_separator := HSeparator.new()
	toolbar.add_child(camera_separator)

	var camera_row := HBoxContainer.new()
	camera_row.alignment = BoxContainer.ALIGNMENT_CENTER
	camera_row.add_theme_constant_override("separation", 3)
	toolbar.add_child(camera_row)
	var rotate_label := Label.new()
	rotate_label.text = "Rotate"
	rotate_label.custom_minimum_size = Vector2(48, 0)
	camera_row.add_child(rotate_label)
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

	var zoom_row := HBoxContainer.new()
	zoom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	zoom_row.add_theme_constant_override("separation", 3)
	toolbar.add_child(zoom_row)
	var zoom_heading := Label.new()
	zoom_heading.text = "Zoom"
	zoom_heading.custom_minimum_size = Vector2(48, 0)
	zoom_row.add_child(zoom_heading)
	zoom_out_button = _icon_button(toolbar_art, Rect2i(462, 0, 23, 23), "Zoom Out")
	zoom_out_button.pressed.connect(_zoom_out)
	zoom_row.add_child(zoom_out_button)
	zoom_in_button = _icon_button(toolbar_art, Rect2i(486, 0, 23, 23), "Zoom In")
	zoom_in_button.pressed.connect(_zoom_in)
	zoom_row.add_child(zoom_in_button)
	zoom_label = Label.new()
	zoom_label.text = "100%"
	zoom_label.custom_minimum_size = Vector2(38, 0)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_row.add_child(zoom_label)

	active_tool_group_label = Label.new()
	active_tool_group_label.text = "Selected Group"
	active_tool_group_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_tool_group_label.add_theme_color_override("font_color", Color("000080"))
	active_tool_group_label.add_theme_font_size_override("font_size", 13)
	toolbar.add_child(active_tool_group_label)
	child_tool_scroll = ScrollContainer.new()
	child_tool_scroll.custom_minimum_size = Vector2(0, 96)
	child_tool_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child_tool_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child_tool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	toolbar.add_child(child_tool_scroll)
	child_tool_grid = GridContainer.new()
	child_tool_grid.columns = 1
	child_tool_grid.add_theme_constant_override("h_separation", 3)
	child_tool_grid.add_theme_constant_override("v_separation", 3)
	child_tool_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child_tool_scroll.add_child(child_tool_grid)
	undo_button = Button.new()
	undo_button.text = "Undo Last Edit"
	undo_button.disabled = true
	undo_button.pressed.connect(_undo_last_edit)
	toolbar.add_child(undo_button)

	var view_separator := HSeparator.new()
	toolbar.add_child(view_separator)
	var view_heading := Label.new()
	view_heading.text = "City View"
	view_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_heading.add_theme_color_override("font_color", Color("000080"))
	toolbar.add_child(view_heading)
	var view_grid := GridContainer.new()
	view_grid.columns = 2
	view_grid.add_theme_constant_override("h_separation", 4)
	view_grid.add_theme_constant_override("v_separation", 4)
	toolbar.add_child(view_grid)
	for mode in MAP_DISPLAY_MODES:
		var button := Button.new()
		button.text = mode.capitalize()
		button.tooltip_text = "Show the %s isometric view." % mode
		button.pressed.connect(_set_overlay.bind(mode))
		view_grid.add_child(button)
	var city_map_button := Button.new()
	city_map_button.text = "City Map..."
	city_map_button.tooltip_text = "Open the tabbed two-dimensional city maps."
	city_map_button.pressed.connect(_open_city_map_window)
	view_grid.add_child(city_map_button)

	view_layers_heading = Label.new()
	view_layers_heading.text = "Visible Layers"
	view_layers_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_layers_heading.add_theme_color_override("font_color", Color("000080"))
	toolbar.add_child(view_layers_heading)
	var layers_grid := GridContainer.new()
	layers_grid.columns = 2
	layers_grid.add_theme_constant_override("h_separation", 4)
	layers_grid.add_theme_constant_override("v_separation", 2)
	toolbar.add_child(layers_grid)
	for layer in [
		["Buildings", "buildings"], ["Networks", "networks"],
		["Water", "water"], ["Trees", "trees"],
		["Zones", "zones"], ["Signs", "signs"],
	]:
		var check := CheckBox.new()
		check.text = layer[0]
		check.tooltip_text = "Show or hide %s in the city view." % str(layer[0]).to_lower()
		check.button_pressed = true
		check.toggled.connect(_set_surface_visibility.bind(layer[1]))
		view_visibility_checks[layer[1]] = check
		layers_grid.add_child(check)
	var pipes_check := CheckBox.new()
	pipes_check.text = "Pipes"
	pipes_check.tooltip_text = "Show or hide pipes in the underground view."
	pipes_check.button_pressed = true
	pipes_check.toggled.connect(_set_underground_pipes_visible)
	view_visibility_checks["pipes"] = pipes_check
	layers_grid.add_child(pipes_check)

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
	map_view.selection_changed.connect(_on_map_selection_changed)
	map_view.selection_started.connect(_on_map_selection_started)
	map_view.selection_finished.connect(_on_map_selection_finished)
	map_view.selection_canceled.connect(_on_map_selection_canceled)
	map_view.query_requested.connect(_open_query)
	map_view.zoom_changed.connect(_on_city_zoom_changed)
	map_view.viewport_changed.connect(_refresh_city_map_viewport)
	map_panel.add_child(map_view)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(0, 31)
	status_panel.add_theme_stylebox_override("panel", _classic_box(Color("c0c0c0"), Color("808080"), 2))
	page.add_child(status_panel)
	var status_metrics := HBoxContainer.new()
	status_metrics.add_theme_constant_override("separation", 8)
	status_panel.add_child(status_metrics)
	status_label = Label.new()
	status_label.text = "Ready."
	status_label.custom_minimum_size = Vector2(150, 22)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.add_theme_color_override("font_color", Color("202020"))
	status_label.set_meta("always_status_tooltip", true)
	status_metrics.add_child(status_label)
	status_metrics.add_child(VSeparator.new())
	status_weather_label = _status_metric_label("Weather: --", 120)
	status_weather_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	status_metrics.add_child(status_weather_label)
	status_metrics.add_child(VSeparator.new())
	status_rci_graph = RciStatusView.new()
	status_metrics.add_child(status_rci_graph)
	status_metrics.add_child(VSeparator.new())
	status_reports_label = _status_metric_label("News: None", 180, true)
	status_reports_label.set_meta("always_status_tooltip", true)
	status_metrics.add_child(status_reports_label)
	status_metrics.add_child(VSeparator.new())
	status_speed_label = _status_metric_label("Speed: --", 122)
	status_metrics.add_child(status_speed_label)
	_sync_speed_ui()

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
	save_dialog.file_selected.connect(_on_save_path_selected)
	save_dialog.canceled.connect(_on_save_dialog_canceled)
	add_child(save_dialog)

	tile_set_dialog = FileDialog.new()
	tile_set_dialog.access = FileDialog.ACCESS_FILESYSTEM
	tile_set_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	tile_set_dialog.add_filter("*.MIF, *.mif", "SCURK tile sets")
	tile_set_dialog.file_selected.connect(_load_tile_set)
	add_child(tile_set_dialog)

	scurk_city_export_dialog = FileDialog.new()
	scurk_city_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	scurk_city_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	scurk_city_export_dialog.add_filter("*.BMP, *.bmp", "Windows indexed bitmap")
	scurk_city_export_dialog.file_selected.connect(_export_scurk_city_bmp)
	add_child(scurk_city_export_dialog)

	scurk_print_pdf_dialog = FileDialog.new()
	scurk_print_pdf_dialog.access = FileDialog.ACCESS_FILESYSTEM
	scurk_print_pdf_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	scurk_print_pdf_dialog.add_filter("*.PDF, *.pdf", "Printable PDF")
	scurk_print_pdf_dialog.file_selected.connect(_save_scurk_city_pdf)
	add_child(scurk_print_pdf_dialog)

	new_city_dialog = NewCityTerrainDialogView.new()
	new_city_dialog.cancel_requested.connect(_cancel_new_city)
	new_city_dialog.build_requested.connect(_create_new_city)
	new_city_dialog.preview_requested.connect(_schedule_new_city_preview)
	new_city_dialog.terrain_regeneration_requested.connect(_make_new_city_preview)
	add_child(new_city_dialog)

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

	network_connection_dialog = ConfirmationDialog.new()
	network_connection_dialog.title = "Neighbor Connection"
	network_connection_dialog.dialog_text = (
		"Build a road connection to a neighboring city for $1,000?"
	)
	network_connection_dialog.min_size = Vector2i(520, 210)
	network_connection_dialog.exclusive = true
	network_connection_dialog.get_ok_button().text = "Build Connection"
	network_connection_dialog.get_cancel_button().text = "Keep Route"
	network_connection_dialog.confirmed.connect(_confirm_network_connection)
	network_connection_dialog.canceled.connect(_cancel_network_connection)
	add_child(network_connection_dialog)

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

	query_dialog = CityQueryDialogView.new()
	query_dialog.close_requested.connect(_close_query)
	query_dialog.action_requested.connect(_run_query_action)
	add_child(query_dialog)
	_build_graph_window()
	_build_population_window()
	_build_industry_window()
	_build_simnation_window()
	_build_city_map_window()
	_build_ordinance_window()
	city_analysis_dialog = AcceptDialog.new()
	city_analysis_dialog.title = "City Analysis"
	city_analysis_dialog.min_size = Vector2i(600, 480)
	city_analysis_table = Tree.new()
	city_analysis_table.custom_minimum_size = Vector2i(540, 360)
	city_analysis_table.columns = 3
	city_analysis_table.column_titles_visible = true
	city_analysis_table.hide_root = true
	city_analysis_table.set_column_title(0, "LAND USE")
	city_analysis_table.set_column_title(1, "ACRES")
	city_analysis_table.set_column_title(2, "% of CITY")
	city_analysis_table.set_column_expand(0, true)
	city_analysis_table.set_column_expand(1, false)
	city_analysis_table.set_column_expand(2, false)
	city_analysis_table.set_column_custom_minimum_width(1, 100)
	city_analysis_table.set_column_custom_minimum_width(2, 100)
	city_analysis_dialog.get_label().visible = false
	var analysis_content := city_analysis_dialog.get_label().get_parent()
	analysis_content.add_child(city_analysis_table)
	analysis_content.move_child(city_analysis_table, 0)
	add_child(city_analysis_dialog)
	newspaper_dialog = NewspaperDialogView.new()
	add_child(newspaper_dialog)
	var forest_notice := _create_picture_notice(
		"ForestProtestDialog",
		"Forest Protest",
		"ForestProtestImage",
		"ForestProtestMessage",
		forest_protest_text,
	)
	forest_protest_dialog = forest_notice.dialog
	forest_protest_message = forest_notice.message
	var objection_notice := _create_picture_notice(
		"BuildingObjectionDialog",
		"Citizen Objection",
		"BuildingObjectionImage",
		"BuildingObjectionMessage",
		building_objection_text,
	)
	building_objection_dialog = objection_notice.dialog
	building_objection_message = objection_notice.message
	building_objection_dialog.confirmed.connect(_on_building_objection_closed)
	building_objection_dialog.canceled.connect(_on_building_objection_closed)
	for index in LIBRARY_TEXT_IDS.size():
		var library_window := PanelContainer.new()
		library_window.name = "LibraryText%d" % LIBRARY_TEXT_IDS[index]
		library_window.visible = false
		library_window.mouse_filter = Control.MOUSE_FILTER_STOP
		library_window.add_theme_stylebox_override(
			"panel", _classic_box(Color("c0c0c0"), Color("404040"), 2)
		)
		library_window.gui_input.connect(
			_on_library_window_input.bind(library_window)
		)
		var library_margin := MarginContainer.new()
		for side in ["left", "top", "right", "bottom"]:
			library_margin.add_theme_constant_override("margin_" + side, 8)
		library_window.add_child(library_margin)
		var library_column := VBoxContainer.new()
		library_column.add_theme_constant_override("separation", 8)
		library_margin.add_child(library_column)
		var library_text_view := TextEdit.new()
		library_text_view.editable = false
		library_text_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		library_text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		library_text_view.add_theme_color_override("font_color", Color("101010"))
		library_text_view.add_theme_color_override(
			"font_readonly_color", Color("101010")
		)
		for state in ["normal", "focus", "read_only"]:
			library_text_view.add_theme_stylebox_override(
				state, _classic_box(Color("ffffff"), Color("808080"), 1)
			)
		library_text_view.gui_input.connect(
			_on_library_window_input.bind(library_window)
		)
		library_column.add_child(library_text_view)
		var library_button_row := HBoxContainer.new()
		library_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
		library_column.add_child(library_button_row)
		var library_ok_button := Button.new()
		library_ok_button.text = "OK"
		library_ok_button.pressed.connect(library_window.hide)
		library_button_row.add_child(library_ok_button)
		add_child(library_window)
		library_windows.append(library_window)
		library_text_views.append(library_text_view)
	game_over_dialog = AcceptDialog.new()
	game_over_dialog.min_size = Vector2i(460, 220)
	add_child(game_over_dialog)
	scenario_dialog = AcceptDialog.new()
	scenario_dialog.title = "Scenario"
	scenario_dialog.min_size = Vector2i(760, 520)
	scenario_dialog.exclusive = true
	scenario_dialog.get_ok_button().text = "Begin Scenario"
	scenario_dialog.confirmed.connect(_begin_scenario)
	scenario_dialog.get_label().visible = false
	var scenario_content := HBoxContainer.new()
	scenario_content.custom_minimum_size = Vector2(700, 400)
	scenario_content.add_theme_constant_override("separation", 16)
	var picture_frame := PanelContainer.new()
	picture_frame.custom_minimum_size = Vector2(276, 276)
	picture_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picture_frame.add_theme_stylebox_override(
		"panel", _classic_box(Color("ffffff"), Color("808080"), 2)
	)
	scenario_content.add_child(picture_frame)
	scenario_picture_view = TextureRect.new()
	scenario_picture_view.custom_minimum_size = Vector2(260, 260)
	scenario_picture_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scenario_picture_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scenario_picture_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture_frame.add_child(scenario_picture_view)
	scenario_text_view = TextEdit.new()
	scenario_text_view.editable = false
	scenario_text_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	scenario_text_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scenario_text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scenario_text_view.add_theme_color_override("font_color", Color("101010"))
	scenario_text_view.add_theme_color_override("font_readonly_color", Color("101010"))
	for state in ["normal", "focus", "read_only"]:
		scenario_text_view.add_theme_stylebox_override(
			state, _classic_box(Color("ffffff"), Color("808080"), 1)
		)
	scenario_content.add_child(scenario_text_view)
	var scenario_content_parent := scenario_dialog.get_label().get_parent()
	scenario_content_parent.add_child(scenario_content)
	scenario_content_parent.move_child(scenario_content, 0)
	add_child(scenario_dialog)
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

	budget_dialog = BudgetDialogView.new()
	budget_dialog.apply_requested.connect(_commit_budget)
	budget_dialog.cancel_requested.connect(_cancel_budget)
	budget_dialog.issue_bond_requested.connect(_request_issue_bond)
	budget_dialog.repay_bond_requested.connect(_request_repay_bond)
	budget_dialog.bond_confirmation_resolved.connect(_resolve_bond_action)
	add_child(budget_dialog)

	_select_tool_group(selected_group)
	_update_zoom_controls(map_view.zoom_percent())
	_build_main_menu()


func _build_main_menu() -> void:
	main_menu = MainMenuView.new()
	main_menu.z_index = 850
	main_menu.visible = false
	main_menu.continue_requested.connect(_hide_main_menu)
	main_menu.new_city_requested.connect(_open_new_city_dialog)
	main_menu.open_city_requested.connect(_open_city_dialog)
	main_menu.scenario_requested.connect(_open_scenario_dialog)
	main_menu.settings_requested.connect(_open_settings_dialog)
	main_menu.scurk_requested.connect(_open_scurk_dialog)
	main_menu.scurk_place_requested.connect(_open_scurk_place_print)
	main_menu.about_requested.connect(_open_about_dialog)
	main_menu.exit_requested.connect(_request_city_exit.bind("quit"))
	add_child(main_menu)

	settings_dialog = ConfirmationDialog.new()
	settings_dialog.title = "OpenSC2K Settings"
	settings_dialog.min_size = Vector2i(520, 330)
	settings_dialog.exclusive = true
	settings_dialog.get_ok_button().text = "Apply"
	settings_dialog.confirmed.connect(_apply_settings)
	settings_dialog.get_label().visible = false
	var settings_grid := GridContainer.new()
	settings_grid.columns = 2
	settings_grid.custom_minimum_size = Vector2(460, 210)
	settings_grid.add_theme_constant_override("h_separation", 14)
	settings_grid.add_theme_constant_override("v_separation", 14)
	for label_text in ["Music Volume", "Sound Effects Volume"]:
		var label := Label.new()
		label.text = label_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		settings_grid.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(250, 32)
		settings_grid.add_child(slider)
		if label_text == "Music Volume":
			settings_music_slider = slider
		else:
			settings_effects_slider = slider
	var display_label := Label.new()
	display_label.text = "Display"
	display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	settings_grid.add_child(display_label)
	settings_fullscreen_check = CheckBox.new()
	settings_fullscreen_check.text = "Fullscreen"
	settings_grid.add_child(settings_fullscreen_check)
	var settings_parent := settings_dialog.get_label().get_parent()
	settings_parent.add_child(settings_grid)
	settings_parent.move_child(settings_grid, 0)
	add_child(settings_dialog)

	scurk_editor = ScurkEditorView.new()
	scurk_editor.z_index = 940
	scurk_editor.tile_set_applied.connect(_apply_scurk_tile_set)
	scurk_editor.place_print_requested.connect(_open_scurk_place_print)
	add_child(scurk_editor)

	scurk_place_print = ScurkPlacePrintView.new()
	scurk_place_print.tile_selected.connect(_select_scurk_place_tile)
	scurk_place_print.edit_tool_selected.connect(_select_scurk_edit_tool)
	scurk_place_print.export_bmp_requested.connect(_open_scurk_city_export)
	scurk_place_print.print_city_requested.connect(_open_scurk_print_dialog)
	scurk_place_print.undo_requested.connect(_undo_scurk_place)
	scurk_place_print.redo_requested.connect(_redo_scurk_place)
	scurk_place_print.close_requested.connect(_close_scurk_place_print)
	add_child(scurk_place_print)

	scurk_print = ScurkPrintView.new()
	scurk_print.preview_options_changed.connect(_refresh_scurk_print_preview)
	scurk_print.save_pdf_requested.connect(_open_scurk_print_pdf_dialog)
	add_child(scurk_print)

	about_dialog = AcceptDialog.new()
	about_dialog.title = "About OpenSC2K"
	about_dialog.dialog_text = (
		"OpenSC2K is an open-source reimplementation of SimCity 2000 for Windows 95.\n\n"
		+ "It reads the original SC2 and SCN city formats. Original game data stays external to this project."
	)
	about_dialog.min_size = Vector2i(560, 250)
	about_dialog.exclusive = true
	add_child(about_dialog)

	save_changes_dialog = ConfirmationDialog.new()
	save_changes_dialog.title = "Save Changes"
	save_changes_dialog.min_size = Vector2i(480, 190)
	save_changes_dialog.exclusive = true
	save_changes_dialog.get_ok_button().text = "Save"
	save_changes_dialog.get_cancel_button().text = "Cancel"
	save_changes_dialog.add_button("Don't Save", true, "discard")
	save_changes_dialog.confirmed.connect(_save_pending_city_exit)
	save_changes_dialog.canceled.connect(_cancel_pending_city_exit)
	save_changes_dialog.custom_action.connect(_on_save_changes_action)
	add_child(save_changes_dialog)


func _show_main_menu() -> void:
	if main_menu == null:
		return
	if scurk_place_print != null and scurk_place_print.visible:
		scurk_place_print.hide()
		_update_edit_state()
	if scurk_print != null:
		scurk_print.hide()
	main_menu.show_menu(city != null)
	status_label.text = "Main menu."


func _hide_main_menu() -> void:
	if main_menu != null:
		main_menu.hide()
	if city != null:
		status_label.text = "City ready."


func _open_settings_dialog() -> void:
	settings_music_slider.value = app_music_volume * 100.0
	settings_effects_slider.value = app_effects_volume * 100.0
	settings_fullscreen_check.button_pressed = app_fullscreen
	settings_dialog.popup_centered()


func _apply_settings() -> void:
	app_music_volume = float(settings_music_slider.value) / 100.0
	app_effects_volume = float(settings_effects_slider.value) / 100.0
	app_fullscreen = settings_fullscreen_check.button_pressed
	if music_player != null:
		music_player.set_volume_linear(app_music_volume)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if app_fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", app_music_volume)
	config.set_value("audio", "effects_volume", app_effects_volume)
	config.set_value("display", "fullscreen", app_fullscreen)
	var error := config.save("user://settings.cfg")
	status_label.text = (
		"Settings saved."
		if error == OK
		else "Settings applied, but the settings file could not be saved."
	)


func _load_app_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		app_music_volume = clampf(
			float(config.get_value("audio", "music_volume", app_music_volume)), 0.0, 1.0
		)
		app_effects_volume = clampf(
			float(config.get_value("audio", "effects_volume", app_effects_volume)), 0.0, 1.0
		)
		app_fullscreen = bool(config.get_value("display", "fullscreen", app_fullscreen))
	if app_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _open_scurk_dialog() -> void:
	if (
		palette == null
		or not palette.is_valid()
		or base_large_sprites == null
		or base_small_medium_sprites == null
	):
		_show_error("The original SCURK graphics are not loaded.")
		return
	scurk_editor.configure(
		palette, base_large_sprites, base_small_medium_sprites, reference_root
	)
	var initial_path := (
		active_scurk_path
		if not active_scurk_path.is_empty()
		else reference_root.path_join("SCURKART/ORIGINAL.MIF")
	)
	if (
		scurk_editor.tile_set != null
		and not scurk_editor.dirty
		and not active_scurk_path.is_empty()
		and scurk_editor.source_path != active_scurk_path
	):
		var switched := scurk_editor.load_path(active_scurk_path)
		if not switched.ok:
			_show_error(switched.error)
			return
	var opened := scurk_editor.show_editor(initial_path)
	if not opened.ok:
		_show_error(opened.error)


func _open_scurk_place_print() -> void:
	if city == null:
		_show_error("Load or create a city before you open SCURK Place & Print.")
		return
	if (
		palette == null
		or not palette.is_valid()
		or large_sprites == null
		or not large_sprites.is_valid()
		or scurk_place_print == null
	):
		_show_error("The SCURK Place & Print graphics are not available.")
		return
	_hide_main_menu()
	if scurk_editor != null and scurk_editor.visible:
		scurk_editor.hide()
	if overlay_mode != "city":
		_set_overlay("city")
	var names := (
		active_scurk_tile_set.names
		if active_scurk_tile_set != null
		else {}
	)
	scurk_place_print.configure(palette, large_sprites, names)
	if not last_edit_command.get("scurk_place_history", false):
		scurk_place_undo_stack.clear()
		scurk_place_redo_stack.clear()
	scurk_place_print.set_history_enabled(
		not scurk_place_undo_stack.is_empty(), not scurk_place_redo_stack.is_empty()
	)
	scurk_place_print.set_export_enabled(map_view.zoom_percent() <= 25)
	if not scurk_place_print.show_workspace():
		_show_error("Cannot open SCURK Place & Print.")
		return
	_select_scurk_place_tile(scurk_place_print.selected_tile_id)


func _close_scurk_place_print() -> void:
	if scurk_place_print != null:
		scurk_place_print.hide()
	if scurk_print != null:
		scurk_print.hide()
	_update_edit_state()
	if city != null:
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Closed SCURK Place & Print."


func _open_scurk_city_export() -> void:
	if city == null or scurk_place_print == null or not scurk_place_print.visible:
		return
	if map_view.zoom_percent() > 25:
		_show_error("Zoom out to 25% before you export a Place & Print city.")
		return
	var output_directory := ProjectSettings.globalize_path("user://scurk_exports")
	DirAccess.make_dir_recursive_absolute(output_directory)
	scurk_city_export_dialog.current_dir = output_directory
	var output_name := city.city_name().validate_filename()
	if output_name.is_empty():
		output_name = "CITY"
	scurk_city_export_dialog.current_file = output_name + "_SMALL.BMP"
	scurk_city_export_dialog.popup_centered_ratio(0.75)


func _export_scurk_city_bmp(path: String) -> void:
	if city == null:
		return
	var output_path := ProjectSettings.globalize_path(path).simplify_path()
	if output_path.get_extension().to_lower() != "bmp":
		output_path += ".BMP"
	if output_path == reference_root or output_path.begins_with(reference_root + "/"):
		_show_error("Choose a location outside the read-only references directory.")
		return
	var options := _current_scurk_output_options()
	options["color"] = true
	var result := ScurkCityOutput.save_small_bmp(
		output_path,
		city,
		palette_index_encoding,
		palette,
		_sprite_archive_for_view(IsometricRenderer.VIEW_SMALL),
		options
	)
	if not result.ok:
		_show_error("Cannot export the Place & Print city: %s" % result.error)
		return
	var message := "Exported the small Place & Print city to %s." % output_path
	scurk_place_print.set_status(message)
	status_label.remove_theme_color_override("font_color")
	status_label.text = message


func _open_scurk_print_dialog() -> void:
	if city == null or scurk_print == null:
		return
	scurk_print.configure(
		city.city_name(), overlay_mode, surface_visibility, show_underground_pipes
	)
	scurk_print.show_workspace()


func _refresh_scurk_print_preview(options: Dictionary) -> void:
	if city == null or scurk_print == null:
		return
	var result := ScurkCityOutput.render(
		city,
		palette,
		_sprite_archive_for_view(IsometricRenderer.VIEW_SMALL),
		IsometricRenderer.VIEW_SMALL,
		options
	)
	if not result.ok:
		scurk_print.set_status("Cannot prepare the print preview: %s" % result.error)
		return
	scurk_print.set_preview_image(result.image)


func _open_scurk_print_pdf_dialog(options: Dictionary) -> void:
	if city == null:
		return
	pending_scurk_print_options = options.duplicate(true)
	var output_directory := ProjectSettings.globalize_path("user://scurk_prints")
	DirAccess.make_dir_recursive_absolute(output_directory)
	scurk_print_pdf_dialog.current_dir = output_directory
	var output_name := city.city_name().validate_filename()
	if output_name.is_empty():
		output_name = "CITY"
	scurk_print_pdf_dialog.current_file = "%s_%dx.PDF" % [
		output_name, int(options.get("magnification", 1)),
	]
	scurk_print_pdf_dialog.popup_centered_ratio(0.75)


func _save_scurk_city_pdf(path: String) -> void:
	if city == null or pending_scurk_print_options.is_empty():
		return
	var output_path := ProjectSettings.globalize_path(path).simplify_path()
	if output_path.get_extension().to_lower() != "pdf":
		output_path += ".PDF"
	if output_path == reference_root or output_path.begins_with(reference_root + "/"):
		_show_error("Choose a location outside the read-only references directory.")
		return
	var magnification := int(pending_scurk_print_options.get("magnification", 1))
	var grid := ScurkCityOutput.page_grid(magnification)
	if grid.is_empty():
		_show_error("The selected print magnification is invalid.")
		return
	var result := ScurkCityOutput.save_pdf(
		output_path,
		city,
		palette,
		_sprite_archive_for_view(int(grid.view_size)),
		pending_scurk_print_options
	)
	if not result.ok:
		_show_error("Cannot write the printable city: %s" % result.error)
		return
	var message := "Wrote %d printable city pages to %s." % [
		int(result.page_count), output_path,
	]
	scurk_print.set_status(message)
	scurk_place_print.set_status(message)
	status_label.remove_theme_color_override("font_color")
	status_label.text = message
	pending_scurk_print_options.clear()


func _current_scurk_output_options() -> Dictionary:
	return {
		"view": overlay_mode,
		"color": true,
		"surface_visibility": surface_visibility.duplicate(),
		"show_pipes": show_underground_pipes,
	}


func _select_scurk_place_tile(tile_id: int) -> void:
	if scurk_place_print == null or not scurk_place_print.visible:
		return
	if not ScurkPlace.is_placeable_tile(tile_id):
		map_view.set_edit_enabled(false)
		return
	_update_edit_state()


func _select_scurk_edit_tool(
	group_index: int, subtool_index: int, _zone_type: int
) -> void:
	if scurk_place_print == null or not scurk_place_print.visible:
		return
	selected_group = group_index
	selected_subtool = subtool_index
	var tool := scurk_place_print.selected_edit_tool()
	var required_view := String(tool.get("view", "either"))
	if required_view == "city" and overlay_mode != "city":
		_set_overlay("city")
	elif required_view == "underground" and overlay_mode != "underground":
		_set_overlay("underground")
	_update_edit_state()


func _record_edit_command(
	command: Dictionary, scurk_history := false, scurk_name := ""
) -> void:
	if scurk_history:
		command["scurk_place_history"] = true
		command["scurk_tool_name"] = scurk_name
		scurk_place_undo_stack.append(command)
		scurk_place_redo_stack.clear()
		if scurk_place_print != null:
			scurk_place_print.set_history_enabled(true, false)
	last_edit_command = command
	undo_button.disabled = false


func _apply_scurk_place_selection(point: Vector2i) -> void:
	if city == null or scurk_place_print == null:
		return
	var tile_id := scurk_place_print.selected_tile_id
	var result := ScurkPlace.apply(
		city,
		tile_id,
		point,
		tool_random,
		scurk_place_print.selected_zone_id()
	)
	if not result.get("ok", false):
		_show_error("Cannot place the SCURK object: %s" % result.error)
		return
	_record_edit_command(result, true, "Object Placement")
	_refresh_details()
	_refresh_after_city_edit(result)
	var area := int(result.get("area", 1))
	var message := "Placed SCURK tile %d at %d, %d (%d by %d)." % [
		tile_id, point.x, point.y, area, area,
	]
	scurk_place_print.set_status(message)
	status_label.remove_theme_color_override("font_color")
	status_label.text = message


func _undo_scurk_place() -> void:
	if city == null or scurk_place_undo_stack.is_empty():
		return
	var command: Dictionary = scurk_place_undo_stack[-1]
	var result := ScurkPlace.undo(city, command, tool_random)
	if not result.get("ok", false):
		_show_error("Cannot undo SCURK placement: %s" % result.error)
		return
	scurk_place_undo_stack.pop_back()
	scurk_place_redo_stack.append(command)
	last_edit_command = (
		scurk_place_undo_stack[-1]
		if not scurk_place_undo_stack.is_empty()
		else {}
	)
	undo_button.disabled = last_edit_command.is_empty()
	scurk_place_print.set_history_enabled(
		not scurk_place_undo_stack.is_empty(), not scurk_place_redo_stack.is_empty()
	)
	_refresh_details()
	_refresh_after_city_edit(command)
	var command_name := String(command.get("scurk_tool_name", "edit"))
	var message := "Undid SCURK %s across %d tiles." % [
		command_name, result.restored_tiles,
	]
	scurk_place_print.set_status(message)
	status_label.remove_theme_color_override("font_color")
	status_label.text = message


func _redo_scurk_place() -> void:
	if city == null or scurk_place_redo_stack.is_empty():
		return
	var command: Dictionary = scurk_place_redo_stack[-1]
	var result := ScurkPlace.redo(city, command, tool_random)
	if not result.get("ok", false):
		_show_error("Cannot redo SCURK placement: %s" % result.error)
		return
	scurk_place_redo_stack.pop_back()
	scurk_place_undo_stack.append(command)
	last_edit_command = command
	undo_button.disabled = false
	scurk_place_print.set_history_enabled(
		not scurk_place_undo_stack.is_empty(), not scurk_place_redo_stack.is_empty()
	)
	_refresh_details()
	_refresh_after_city_edit(command)
	var command_name := String(command.get("scurk_tool_name", "edit"))
	var message := "Redid SCURK %s across %d tiles." % [
		command_name, result.restored_tiles,
	]
	scurk_place_print.set_status(message)
	status_label.remove_theme_color_override("font_color")
	status_label.text = message


func _open_about_dialog() -> void:
	about_dialog.popup_centered()


func _create_picture_notice(
	dialog_name: String,
	dialog_title: String,
	image_name: String,
	message_name: String,
	message_text: String
) -> Dictionary:
	var dialog := AcceptDialog.new()
	dialog.name = dialog_name
	dialog.title = dialog_title
	dialog.min_size = Vector2i(520, 230)
	dialog.exclusive = true
	dialog.get_ok_button().text = "OK"
	dialog.get_label().visible = false
	var layout := HBoxContainer.new()
	layout.custom_minimum_size = Vector2(470, 130)
	layout.add_theme_constant_override("separation", 14)
	var picture_frame := PanelContainer.new()
	picture_frame.custom_minimum_size = Vector2(171, 116)
	picture_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picture_frame.add_theme_stylebox_override(
		"panel", _classic_box(Color("ffffff"), Color("808080"), 2)
	)
	layout.add_child(picture_frame)
	var picture := TextureRect.new()
	picture.name = image_name
	picture.custom_minimum_size = Vector2(155, 100)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if forest_protest_image != null:
		picture.texture = ImageTexture.create_from_image(forest_protest_image)
	picture_frame.add_child(picture)
	var message := Label.new()
	message.name = message_name
	message.text = message_text.replace("\r\n", "\n").replace("\r", "\n")
	message.custom_minimum_size = Vector2(280, 100)
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layout.add_child(message)
	var content := dialog.get_label().get_parent()
	content.add_child(layout)
	content.move_child(layout, 0)
	add_child(dialog)
	return {"dialog": dialog, "message": message}


func _create_classic_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 13
	result.set_color("font_color", "Label", Color("101010"))
	result.set_color("font_color", "Button", Color("101010"))
	result.set_color("font_hover_color", "Button", Color("101010"))
	result.set_color("font_pressed_color", "Button", Color("101010"))
	result.set_color("font_focus_color", "Button", Color("101010"))
	result.set_color("font_color", "OptionButton", Color("101010"))
	result.set_stylebox("normal", "Button", _classic_box(Color("c0c0c0"), Color("ffffff"), 2))
	result.set_stylebox("hover", "Button", _classic_box(Color("d0d0d0"), Color("ffffff"), 2))
	result.set_stylebox("pressed", "Button", _classic_box(Color("a0a0a0"), Color("404040"), 2))
	result.set_stylebox("focus", "Button", _classic_box(Color("c0c0c0"), Color("000000"), 1))
	result.set_stylebox("normal", "OptionButton", _classic_box(Color("ffffff"), Color("808080"), 2))
	result.set_stylebox("hover", "OptionButton", _classic_box(Color("ffffff"), Color("000080"), 2))
	result.set_stylebox("pressed", "OptionButton", _classic_box(Color("e0e0e0"), Color("404040"), 2))
	result.set_stylebox("normal", "PanelContainer", _classic_box(Color("c0c0c0"), Color("808080"), 1))
	var tooltip_box := _classic_box(Color(0.0, 0.0, 0.0, 0.82), Color(1.0, 1.0, 1.0, 0.45), 1)
	tooltip_box.content_margin_left = 7
	tooltip_box.content_margin_top = 5
	tooltip_box.content_margin_right = 7
	tooltip_box.content_margin_bottom = 5
	result.set_stylebox("panel", "TooltipPanel", tooltip_box)
	result.set_color("font_color", "TooltipLabel", Color.WHITE)
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


func _status_metric_label(text_value: String, minimum_width: int, expand := false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(minimum_width, 20)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _build_graph_window() -> void:
	graph_window = Window.new()
	graph_window.name = "GraphWindow"
	graph_window.title = "Graph Window"
	graph_window.size = Vector2i(860, 560)
	graph_window.min_size = Vector2i(700, 480)
	graph_window.transient = true
	graph_window.exclusive = false
	graph_window.visible = false
	graph_window.close_requested.connect(graph_window.hide)
	add_child(graph_window)

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel", _classic_box(Color("c0c0c0"), Color("808080"), 2)
	)
	graph_window.add_child(background)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	background.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var graph_frame := PanelContainer.new()
	graph_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_frame.add_theme_stylebox_override(
		"panel", _classic_box(Color("ffffff"), Color("404040"), 1)
	)
	column.add_child(graph_frame)
	graph_control = GraphView.new()
	graph_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_frame.add_child(graph_control)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	column.add_child(controls)
	var series_grid := GridContainer.new()
	series_grid.columns = 4
	series_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	series_grid.add_theme_constant_override("h_separation", 8)
	series_grid.add_theme_constant_override("v_separation", 2)
	controls.add_child(series_grid)
	for series in CityGraphControl.SERIES_COUNT:
		var check := CheckBox.new()
		check.text = CityGraphControl.SERIES_NAMES[series]
		check.tooltip_text = "%s graph (%s)" % [
			CityGraphControl.SERIES_NAMES[series],
			CityGraphControl.SERIES_MARKERS[series],
		]
		check.custom_minimum_size = Vector2(132, 24)
		check.button_pressed = bool(
			CityGraphControl.DEFAULT_SELECTED_MASK & (1 << series)
		)
		check.toggled.connect(_on_graph_series_toggled.bind(series))
		series_grid.add_child(check)
		graph_series_buttons.append(check)

	var scale_column := VBoxContainer.new()
	scale_column.custom_minimum_size = Vector2(110, 0)
	controls.add_child(scale_column)
	var scale_heading := Label.new()
	scale_heading.text = "Time Scale"
	scale_heading.add_theme_color_override("font_color", Color("000080"))
	scale_column.add_child(scale_heading)
	var scale_group := ButtonGroup.new()
	for entry in [["1 Year", 0], ["10 Years", 1], ["100 Yrs", 2]]:
		var radio := CheckBox.new()
		radio.text = entry[0]
		radio.button_group = scale_group
		radio.button_pressed = entry[1] == 0
		radio.pressed.connect(_on_graph_time_scale.bind(entry[1]))
		scale_column.add_child(radio)


func _build_population_window() -> void:
	population_window = Window.new()
	population_window.name = "PopulationWindow"
	population_window.title = "Population"
	population_window.size = Vector2i(700, 450)
	population_window.min_size = Vector2i(560, 380)
	population_window.transient = true
	population_window.exclusive = false
	population_window.visible = false
	population_window.close_requested.connect(population_window.hide)
	add_child(population_window)

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel", _classic_box(Color("c0c0c0"), Color("808080"), 2)
	)
	population_window.add_child(background)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	background.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var chart_frame := PanelContainer.new()
	chart_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_frame.add_theme_stylebox_override(
		"panel", _classic_box(Color("ffffff"), Color("404040"), 1)
	)
	column.add_child(chart_frame)
	population_control = PopulationView.new()
	population_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	population_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_frame.add_child(population_control)

	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 0)
	column.add_child(mode_row)
	var mode_group := ButtonGroup.new()
	for entry in [
		["Population", PopulationWindowControl.Mode.POPULATION],
		["Health", PopulationWindowControl.Mode.HEALTH],
		["Education", PopulationWindowControl.Mode.EDUCATION],
	]:
		var radio := CheckBox.new()
		radio.text = entry[0]
		radio.button_group = mode_group
		radio.button_pressed = entry[1] == PopulationWindowControl.Mode.POPULATION
		radio.custom_minimum_size = Vector2(120, 28)
		radio.pressed.connect(_on_population_mode_selected.bind(entry[1]))
		mode_row.add_child(radio)
		population_mode_buttons.append(radio)


func _build_industry_window() -> void:
	industry_window = Window.new()
	industry_window.name = "IndustryWindow"
	industry_window.title = "City Industry"
	industry_window.size = Vector2i(700, 450)
	industry_window.min_size = Vector2i(600, 390)
	industry_window.transient = true
	industry_window.exclusive = false
	industry_window.visible = false
	industry_window.close_requested.connect(industry_window.hide)
	add_child(industry_window)

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel", _classic_box(Color("c0c0c0"), Color("808080"), 2)
	)
	industry_window.add_child(background)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	background.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var chart_frame := PanelContainer.new()
	chart_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_frame.add_theme_stylebox_override(
		"panel", _classic_box(Color("c0c0c0"), Color("404040"), 1)
	)
	column.add_child(chart_frame)
	industry_control = IndustryView.new()
	industry_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	industry_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	industry_control.tax_rates_changed.connect(_on_industry_tax_rates_changed)
	chart_frame.add_child(industry_control)

	var names := PackedStringArray()
	for index in IndustryView.INDUSTRY_COUNT:
		var fallback: String = IndustryView.DEFAULT_NAMES[index]
		names.append(str(original_query_strings.get(INDUSTRY_STRING_FIRST + index, fallback)))
	industry_control.set_industry_names(names)
	var icons := PeBitmap.load_numeric(reference_root.path_join("SIMCITY.EXE"), 178)
	if icons.get("ok", false):
		industry_control.set_icon_strip(icons.image)

	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 0)
	column.add_child(mode_row)
	var mode_group := ButtonGroup.new()
	for entry in [
		["Ratios", IndustryView.Mode.RATIOS],
		["Tax Rates", IndustryView.Mode.TAX_RATES],
		["Demand", IndustryView.Mode.DEMAND],
	]:
		var radio := CheckBox.new()
		radio.text = entry[0]
		radio.button_group = mode_group
		radio.button_pressed = entry[1] == IndustryView.Mode.RATIOS
		radio.custom_minimum_size = Vector2(120, 28)
		radio.pressed.connect(_on_industry_mode_selected.bind(entry[1]))
		mode_row.add_child(radio)
		industry_mode_buttons.append(radio)


func _build_simnation_window() -> void:
	simnation_window = Window.new()
	simnation_window.name = "SimNationWindow"
	simnation_window.title = "SimNation"
	simnation_window.size = Vector2i(612, 480)
	simnation_window.min_size = Vector2i(408, 320)
	simnation_window.transient = true
	simnation_window.exclusive = false
	simnation_window.visible = false
	simnation_window.close_requested.connect(simnation_window.hide)
	add_child(simnation_window)

	simnation_control = SimNationView.new()
	simnation_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	simnation_window.add_child(simnation_control)
	var sprite_sheet := Image.load_from_file(
		reference_root.path_join("BITMAPS/NEIGHBOR.BMP")
	)
	simnation_control.set_sprite_sheet(sprite_sheet)
	simnation_control.set_national_format(str(original_query_strings.get(
		SIMNATION_FORMAT_STRING_ID, SimNationView.DEFAULT_NATIONAL_FORMAT
	)))


func _build_city_map_window() -> void:
	city_map_window = Window.new()
	city_map_window.name = "CityMapWindow"
	city_map_window.title = "City Map"
	city_map_window.size = Vector2i(480, 680)
	city_map_window.min_size = Vector2i(420, 620)
	city_map_window.transient = true
	city_map_window.exclusive = false
	city_map_window.visible = false
	city_map_window.close_requested.connect(_close_city_map_window)
	add_child(city_map_window)

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel", _classic_box(Color("c0c0c0"), Color("808080"), 2)
	)
	city_map_window.add_child(background)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	background.add_child(margin)
	city_map_control = CityMapView.new()
	city_map_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_map_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	city_map_control.mode_changed.connect(_on_city_map_mode_changed)
	city_map_control.center_requested.connect(_on_city_map_center_requested)
	margin.add_child(city_map_control)
	var icons := PeBitmap.load_numeric(reference_root.path_join("SIMCITY.EXE"), 247)
	city_map_control.set_resources(
		icons.image if icons.get("ok", false) else null,
		original_query_strings,
	)


func _build_ordinance_window() -> void:
	ordinance_window = Window.new()
	ordinance_window.name = "OrdinanceWindow"
	ordinance_window.title = "Ordinances"
	ordinance_window.size = Vector2i(800, 640)
	ordinance_window.min_size = Vector2i(720, 580)
	ordinance_window.transient = true
	ordinance_window.exclusive = true
	ordinance_window.visible = false
	ordinance_window.close_requested.connect(ordinance_window.hide)
	add_child(ordinance_window)

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel", _classic_box(Color("c0c0c0"), Color("808080"), 2)
	)
	ordinance_window.add_child(background)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	background.add_child(margin)
	ordinance_control = OrdinanceView.new()
	ordinance_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ordinance_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ordinance_control.ordinances_changed.connect(_on_ordinances_changed)
	ordinance_control.update_failed.connect(_show_error)
	ordinance_control.close_requested.connect(ordinance_window.hide)
	margin.add_child(ordinance_control)


func _add_menu(parent: Control, label: String, items: Array, callback: Callable) -> MenuButton:
	var menu := MenuButton.new()
	menu.text = label
	menu.flat = true
	menu.custom_minimum_size = Vector2(0, 23)
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


func _add_toolbar_group_button(
	parent: Control,
	button_group: ButtonGroup,
	toolbar_art: Image,
	group_index: int
) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(46, 30)
	button.toggle_mode = true
	button.button_group = button_group
	button.tooltip_text = Tools.GROUPS[group_index].name
	button.icon = _toolbar_group_icon(toolbar_art, group_index)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.text = str(group_index + 1) if button.icon == null else ""
	button.pressed.connect(_choose_tool_group.bind(group_index))
	parent.add_child(button)
	toolbar_buttons.append(button)


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
	button.custom_minimum_size = Vector2(36, 30)
	button.icon = _toolbar_icon(toolbar_art, region)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.text = tooltip.left(1) if button.icon == null else ""
	button.tooltip_text = tooltip
	return button


func _choose_tool_group(group_index: int) -> void:
	_select_tool_group(group_index)


func _tool_button_icon(group_index: int, subtool_index: int) -> Texture2D:
	if palette == null or large_sprites == null or not large_sprites.is_valid():
		return _toolbar_group_icon(toolbar_art_source, group_index)
	var tile_id := Buildings.tile_for_tool(group_index, subtool_index)
	var sprite_id := 1000 + tile_id if tile_id > 0 else -1
	if sprite_id < 0:
		var table_index := group_index * Tools.MAX_SLOTS_PER_GROUP + subtool_index
		const REPRESENTATIVE_SPRITES := {
			12: 1006, 13: 1270, 36: 1014, 39: 1198, 48: 1334,
			72: 1029, 73: 1093, 74: 1073, 75: 1107,
			84: 1044, 85: 1319,
			96: 1299, 97: 1298,
			108: 1291, 109: 1292,
			120: 1293, 121: 1294,
			132: 1295, 133: 1296,
		}
		sprite_id = int(REPRESENTATIVE_SPRITES.get(table_index, -1))
	if sprite_id < 0:
		return _toolbar_group_icon(toolbar_art_source, group_index)
	var entry := large_sprites.find_sprite(sprite_id)
	if entry == null:
		return _toolbar_group_icon(toolbar_art_source, group_index)
	var rendered := entry.create_image(palette)
	if not rendered.get("ok", false):
		return _toolbar_group_icon(toolbar_art_source, group_index)
	var image: Image = rendered.image.duplicate()
	var scale := minf(1.0, minf(30.0 / image.get_width(), 28.0 / image.get_height()))
	if scale < 1.0:
		image.resize(
			maxi(1, roundi(image.get_width() * scale)),
			maxi(1, roundi(image.get_height() * scale)),
			Image.INTERPOLATE_NEAREST,
		)
	return ImageTexture.create_from_image(image)


func _refresh_child_tool_icons() -> void:
	for subtool_index in child_tool_buttons:
		var button: Button = child_tool_buttons[subtool_index]
		button.icon = _tool_button_icon(selected_group, int(subtool_index))


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
	if scurk_place_print != null:
		scurk_place_print.set_export_enabled(percent <= 25)


func _update_fps(delta: float) -> void:
	fps_update_seconds += delta
	if fps_label == null or fps_update_seconds < 0.25:
		return
	fps_update_seconds = fmod(fps_update_seconds, 0.25)
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_refresh_status_tooltips()


func _on_city_zoom_changed(percent: int) -> void:
	_update_zoom_controls(percent)
	if city != null and overlay_mode in ["city", "underground"]:
		_refresh_map(false)


func _on_map_selection_canceled() -> void:
	if status_label == null:
		return
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Selection canceled. No action was taken."


func _on_map_selection_started() -> void:
	if selected_group != 0:
		return
	if scurk_place_print != null and scurk_place_print.visible:
		return
	_start_tool_loop_sound(508)


func _on_map_selection_finished() -> void:
	_stop_tool_loop_sound()


func _on_map_selection_changed(
	start: Vector2i,
	finish: Vector2i,
	_path: Array[Vector2i],
	dragged: bool
) -> void:
	if scurk_place_print != null and scurk_place_print.visible:
		if scurk_place_print.is_object_mode():
			map_view.clear_selection_price()
			return
		var scurk_tool := scurk_place_print.selected_edit_tool()
		var zone_type := int(scurk_tool.get("zone", -1))
		if zone_type < 0:
			map_view.clear_selection_price()
			return
		var scurk_preview := Zones.preview_rectangle(
			city,
			int(scurk_tool.group),
			int(scurk_tool.subtool),
			start,
			finish,
			dragged,
			true,
			zone_type
		)
		if not scurk_preview.get("ok", false):
			map_view.clear_selection_price()
			return
		map_view.set_selection_price(0, true)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "%s preview: %d tiles; free in SCURK." % [
			scurk_tool.name, int(scurk_preview.changed_tiles),
		]
		return
	if city == null or not Zones.supports_tool(selected_group, selected_subtool):
		map_view.clear_selection_price()
		return
	var preview := Zones.preview_rectangle(
		city, selected_group, selected_subtool, start, finish, dragged
	)
	if not preview.get("ok", false):
		map_view.clear_selection_price()
		status_label.add_theme_color_override("font_color", Color("b00000"))
		status_label.text = "Cannot start zone selection: %s" % preview.error
		return
	var cost := int(preview.cost)
	var affordable := bool(preview.affordable)
	map_view.set_selection_price(cost, affordable)
	status_label.remove_theme_color_override("font_color")
	status_label.text = "%s preview: %d charged %s for $%s." % [
		Tools.tool(selected_group, selected_subtool).name,
		int(preview.charged_tiles),
		"tile" if int(preview.charged_tiles) == 1 else "tiles",
		_format_number(cost),
	]
	if not affordable:
		status_label.add_theme_color_override("font_color", Color("b00000"))
		status_label.text += " Funds are not sufficient."


func _on_file_menu(id: int) -> void:
	match id:
		0: _open_new_city_dialog()
		1: _open_city_dialog()
		2: _open_save_dialog()
		3: _open_tile_set_dialog()
		4: _restore_original_tile_set()
		MENU_SCURK_PLACE_PRINT: _open_scurk_place_print()
		5: _show_main_menu()
		6: _request_city_exit("quit")


func _on_speed_menu(id: int) -> void:
	if speed_controller == null:
		return
	if id < 0 or id > 4:
		return
	_select_speed(id + GameSpeed.Speed.PAUSED)


func _on_options_menu(id: int) -> void:
	if city == null:
		_show_error("Load a city before you change its options.")
		return
	var enabled := false
	var stored := false
	var option_name := ""
	match id:
		MENU_AUTO_BUDGET:
			enabled = not city.auto_budget_enabled()
			stored = city.set_auto_budget_enabled(enabled)
			option_name = "Auto-Budget"
		MENU_AUTO_GOTO:
			enabled = not city.auto_goto_enabled()
			stored = city.set_auto_goto_enabled(enabled)
			option_name = "Auto-Goto"
		MENU_SOUND_EFFECTS:
			enabled = not city.sound_enabled()
			stored = city.set_sound_enabled(enabled)
			option_name = "Sound Effects"
		MENU_MUSIC:
			enabled = not city.music_enabled()
			stored = city.set_music_enabled(enabled)
			option_name = "Music"
		_:
			return
	if not stored:
		_show_error("Cannot update the %s option." % option_name)
		return
	_sync_city_option_menus()
	if id == MENU_SOUND_EFFECTS and not enabled:
		_stop_sound_effects()
	if id == MENU_MUSIC:
		if enabled:
			_play_music_track(music_director.next_general_track())
		else:
			_stop_music()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "%s %s." % [option_name, "enabled" if enabled else "disabled"]


func _on_view_menu(id: int) -> void:
	if id >= 0 and id < MAP_DISPLAY_MODES.size():
		_set_overlay(MAP_DISPLAY_MODES[id])
		return
	match id:
		MENU_VIEW_CITY_MAP:
			_open_city_map_window()
		MENU_VIEW_BUILDINGS:
			_set_surface_visibility(not bool(surface_visibility.buildings), "buildings")
		MENU_VIEW_NETWORKS:
			_set_surface_visibility(not bool(surface_visibility.networks), "networks")
		MENU_VIEW_WATER:
			_set_surface_visibility(not bool(surface_visibility.water), "water")
		MENU_VIEW_TREES:
			_set_surface_visibility(not bool(surface_visibility.trees), "trees")
		MENU_VIEW_ZONES:
			_set_surface_visibility(not bool(surface_visibility.zones), "zones")
		MENU_VIEW_SIGNS:
			_set_surface_visibility(not bool(surface_visibility.signs), "signs")
		MENU_VIEW_PIPES:
			_set_underground_pipes_visible(not show_underground_pipes)


func _sync_city_option_menus() -> void:
	if options_menu == null or disasters_menu == null:
		return
	var has_city := city != null
	options_menu.disabled = not has_city
	if view_menu != null:
		view_menu.disabled = not has_city
	var option_states := {
		MENU_AUTO_BUDGET: has_city and city.auto_budget_enabled(),
		MENU_AUTO_GOTO: has_city and city.auto_goto_enabled(),
		MENU_SOUND_EFFECTS: has_city and city.sound_enabled(),
		MENU_MUSIC: has_city and city.music_enabled(),
	}
	for option_id in option_states:
		var option_index := options_menu.get_popup().get_item_index(option_id)
		if option_index >= 0:
			options_menu.get_popup().set_item_checked(
				option_index, bool(option_states[option_id])
			)
	var no_disasters_index := disasters_menu.get_popup().get_item_index(MENU_NO_DISASTERS)
	if no_disasters_index >= 0:
		disasters_menu.get_popup().set_item_disabled(no_disasters_index, not has_city)
		disasters_menu.get_popup().set_item_checked(
			no_disasters_index, has_city and city.no_disasters_enabled()
		)
	_sync_view_controls()


func _sync_view_controls() -> void:
	var underground_active := overlay_mode == "underground"
	if view_menu != null and view_menu_underground_items != underground_active:
		_rebuild_view_layer_menu(underground_active)
	var states := {
		MENU_VIEW_BUILDINGS: bool(surface_visibility.buildings),
		MENU_VIEW_NETWORKS: bool(surface_visibility.networks),
		MENU_VIEW_WATER: bool(surface_visibility.water),
		MENU_VIEW_TREES: bool(surface_visibility.trees),
		MENU_VIEW_ZONES: bool(surface_visibility.zones),
		MENU_VIEW_SIGNS: bool(surface_visibility.signs),
		MENU_VIEW_PIPES: show_underground_pipes,
	}
	if view_menu != null:
		for menu_id in states:
			var item_index := view_menu.get_popup().get_item_index(menu_id)
			if item_index >= 0:
				view_menu.get_popup().set_item_checked(item_index, bool(states[menu_id]))
	if view_layers_heading != null:
		view_layers_heading.text = (
			"Underground Layer" if underground_active else "Visible Layers"
		)
	for key in view_visibility_checks:
		var check: CheckBox = view_visibility_checks[key]
		check.visible = underground_active if key == "pipes" else not underground_active
		var enabled := (
			show_underground_pipes
			if key == "pipes"
			else bool(surface_visibility.get(key, true))
		)
		check.set_pressed_no_signal(enabled)


func _rebuild_view_layer_menu(underground_active: bool) -> void:
	var popup := view_menu.get_popup()
	while popup.item_count > 4:
		popup.remove_item(popup.item_count - 1)
	if underground_active:
		popup.add_check_item("Show Underground Pipes", MENU_VIEW_PIPES)
	else:
		for view_item in [
			["Show Buildings", MENU_VIEW_BUILDINGS],
			["Show Networks", MENU_VIEW_NETWORKS],
			["Show Water", MENU_VIEW_WATER],
			["Show Trees", MENU_VIEW_TREES],
			["Show Zones", MENU_VIEW_ZONES],
			["Show Signs", MENU_VIEW_SIGNS],
		]:
			popup.add_check_item(view_item[0], view_item[1])
	view_menu_underground_items = underground_active


func _on_disaster_menu(id: int) -> void:
	if city == null or simulation_engine == null:
		_show_error("Load a city before you start a disaster.")
		return
	if id == MENU_NO_DISASTERS:
		var enabled := not city.no_disasters_enabled()
		if not city.set_no_disasters_enabled(enabled):
			_show_error("Cannot update the No Disasters option.")
			return
		_sync_city_option_menus()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "No Disasters %s." % ("enabled" if enabled else "disabled")
		return
	var result := _start_disaster_at_view_center(id)
	if not result.get("ok", false):
		_show_error("Cannot start the disaster: %s" % result.get("error", "unknown error"))


func _start_disaster_at_view_center(id: int) -> Dictionary:
	if city == null or simulation_engine == null:
		return {"ok": false, "error": "no city is loaded"}
	var point := map_view.center_tile() if map_view != null else Vector2i(64, 64)
	if point.x < 0:
		point = Vector2i(64, 64)
	var result := simulation_engine.start_disaster(id, point)
	if not result.get("ok", false):
		return result
	if not result.get("started", false):
		return {"ok": false, "error": "the selected disaster could not start"}
	if city.music_enabled():
		_play_music_track(Music.DISASTER_TRACK)
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
	var disaster_name := _disaster_name(id)
	status_label.remove_theme_color_override("font_color")
	status_label.text = "%s started." % disaster_name
	result["name"] = disaster_name
	return result


func _disaster_name(id: int) -> String:
	return str({
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
	}.get(id, "None" if id == DisasterStart.DISASTER_NONE else "Disaster"))


func _on_windows_menu(id: int) -> void:
	if id == 0:
		_open_manual_budget()
	elif id == 1:
		_open_ordinance_window()
	elif id == 2:
		_open_population_window()
	elif id == 3:
		_open_industry_window()
	elif id == 4:
		_open_graph_window()
	elif id == 5:
		_open_simnation_window()
	elif id == 6:
		_open_city_map_window()


func _open_ordinance_window() -> void:
	if city == null or ordinance_window == null or ordinance_control == null:
		return
	var result := ordinance_control.set_city(city)
	if not result.get("ok", false):
		_show_error("Cannot open ordinances: %s" % result.get("error", "invalid data"))
		return
	ordinance_window.popup_centered(Vector2i(800, 640))


func _on_ordinances_changed() -> void:
	_refresh_details()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Ordinance selection saved."


func _open_graph_window() -> void:
	if city == null or graph_window == null or graph_control == null:
		return
	graph_control.set_city(city)
	if graph_window.visible:
		graph_window.move_to_foreground()
	else:
		graph_window.popup_centered(Vector2i(860, 560))


func _on_graph_series_toggled(enabled: bool, series: int) -> void:
	if graph_control != null:
		graph_control.set_series_enabled(series, enabled)


func _on_graph_time_scale(scale: int) -> void:
	if graph_control != null:
		graph_control.set_time_scale(scale)


func _open_population_window() -> void:
	if city == null or population_window == null or population_control == null:
		return
	population_control.set_city(city)
	if population_window.visible:
		population_window.move_to_foreground()
	else:
		population_window.popup_centered(Vector2i(700, 450))


func _on_population_mode_selected(mode: int) -> void:
	if population_control != null:
		population_control.set_mode(mode)


func _open_industry_window() -> void:
	if city == null or industry_window == null or industry_control == null:
		return
	industry_control.set_city(city)
	if industry_window.visible:
		industry_window.move_to_foreground()
	else:
		industry_window.popup_centered(Vector2i(700, 450))


func _on_industry_mode_selected(mode: int) -> void:
	if industry_control != null:
		industry_control.set_mode(mode)


func _on_industry_tax_rates_changed() -> void:
	_refresh_details()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Industry tax rates saved."


func _open_simnation_window() -> void:
	if city == null or simnation_window == null or simnation_control == null:
		return
	var data := SimNationView.snapshot(city)
	var names := {}
	if data.get("ok", false):
		for neighbor in data.neighbors:
			var name_index := int(neighbor.name_index)
			if name_index <= 0:
				continue
			var resource_id := SimNationView.NEIGHBOR_NAME_STRING_BASE + name_index
			names[name_index] = str(original_query_strings.get(
				resource_id, "City %d" % name_index
			))
	simnation_control.set_neighbor_names(names)
	simnation_control.set_city(city)
	if simnation_window.visible:
		simnation_window.move_to_foreground()
	else:
		simnation_window.popup_centered(Vector2i(612, 480))


func _open_city_map_window() -> void:
	if city == null or city_map_window == null or city_map_control == null:
		return
	if city_map_window.visible:
		_close_city_map_window()
		return
	city_map_control.set_city(city, palette)
	city_map_control.refresh_viewport(_city_map_viewport_outline())
	city_map_window.popup_centered(Vector2i(480, 680))


func _close_city_map_window() -> void:
	if city_map_window != null:
		city_map_window.hide()


func _on_city_map_mode_changed(mode: String) -> void:
	status_label.remove_theme_color_override("font_color")
	status_label.text = "City Map: %s" % CityMapView.MODE_NAMES.get(mode, mode)


func _on_city_map_center_requested(point: Vector2i) -> void:
	map_view.center_on_tile(point)
	status_label.remove_theme_color_override("font_color")
	status_label.text = "City view centered at %d, %d." % [point.x, point.y]


func _city_map_viewport_outline() -> PackedVector2Array:
	if map_view == null or overlay_mode not in ["city", "underground"]:
		return PackedVector2Array()
	return map_view.visible_tile_outline()


func _refresh_city_map_viewport() -> void:
	if city_map_control != null and city_map_window != null and city_map_window.visible:
		city_map_control.refresh_viewport(_city_map_viewport_outline())


func _on_newspaper_menu(_id: int) -> void:
	if city == null or current_document == null:
		return
	if city.music_enabled() and simulation_engine != null:
		_play_music_track(Music.newspaper_track(simulation_engine.lfsr_random))
	newspaper_dialog.open_reports(
		city,
		current_document,
		newspaper_data,
		original_query_strings,
		NEWS_NAMES,
		newspaper_session_seed,
	)


func _on_help_menu(_id: int) -> void:
	status_label.text = "Select a tool, then use the city view. Use the wheel to zoom. Use the right or middle mouse button to pan."


func _open_new_city_dialog() -> void:
	if new_city_dialog == null:
		return
	new_city_dialog.preview_timer.stop()
	new_city_preview_document = null
	new_city_preview_options.clear()
	new_city_preview_process_cursor = tool_random.state
	new_city_preview_game_cursor = nuisance_random.state
	new_city_preview_process_start = new_city_preview_process_cursor
	new_city_preview_game_start = new_city_preview_game_cursor
	new_city_dialog.city_name_input.text = "New City"
	new_city_dialog.mayor_name_input.text = (
		city.mayor_name() if city != null and not city.mayor_name().is_empty() else "Mayor"
	)
	new_city_dialog.difficulty_input.select(0)
	new_city_dialog.year_input.select(0)
	new_city_dialog.ocean_input.button_pressed = NewTerrain.DEFAULT_OCEAN
	new_city_dialog.river_input.button_pressed = NewTerrain.DEFAULT_RIVER
	new_city_dialog.hills_input.value = NewTerrain.DEFAULT_HILLS
	new_city_dialog.water_input.value = NewTerrain.DEFAULT_WATER
	new_city_dialog.trees_input.value = NewTerrain.DEFAULT_TREES
	_update_new_city_slider_labels()
	new_city_dialog.show()
	_generate_new_city_preview(false)
	new_city_dialog.city_name_input.grab_focus()
	new_city_dialog.city_name_input.select_all()


func _schedule_new_city_preview(_value: Variant = null) -> void:
	_update_new_city_slider_labels()
	if new_city_dialog != null and new_city_dialog.visible:
		new_city_dialog.preview_timer.start()


func _update_new_city_slider_labels() -> void:
	if new_city_dialog == null or new_city_dialog.hills_input == null:
		return
	new_city_dialog.hills_value.text = str(roundi(new_city_dialog.hills_input.value))
	new_city_dialog.water_value.text = str(roundi(new_city_dialog.water_input.value))
	new_city_dialog.trees_value.text = str(roundi(new_city_dialog.trees_input.value))


func _new_city_terrain_options() -> Dictionary:
	return {
		"ocean": new_city_dialog.ocean_input.button_pressed,
		"river": new_city_dialog.river_input.button_pressed,
		"hills": roundi(new_city_dialog.hills_input.value),
		"water": roundi(new_city_dialog.water_input.value),
		"trees": roundi(new_city_dialog.trees_input.value),
	}


func _refresh_new_city_preview() -> void:
	_generate_new_city_preview(false)


func _make_new_city_preview() -> void:
	new_city_dialog.preview_timer.stop()
	_generate_new_city_preview(true)


func _generate_new_city_preview(advance_seed: bool) -> bool:
	if palette == null or not palette.is_valid():
		new_city_dialog.preview_status.text = "Terrain preview is not available."
		return false
	var template_path := reference_root.path_join("DEFAULT.SC2")
	var document := Sc2Document.load_path(template_path)
	if not document.is_valid():
		new_city_dialog.preview_status.text = "Cannot load the default city."
		return false
	if advance_seed or new_city_preview_document == null:
		new_city_preview_process_start = new_city_preview_process_cursor
		new_city_preview_game_start = new_city_preview_game_cursor
	var preview_process := Random.new(new_city_preview_process_start)
	var preview_game := GameRandom.new(new_city_preview_game_start)
	var options := _new_city_terrain_options()
	var generated := NewTerrain.generate(
		document,
		bool(options.ocean),
		bool(options.river),
		int(options.hills),
		int(options.water),
		int(options.trees),
		preview_process,
		preview_game,
	)
	if not generated.ok:
		new_city_dialog.preview_status.text = "Cannot generate terrain: %s" % generated.error
		return false
	var preview_city := CityModel.from_document(document)
	if not preview_city.is_valid():
		new_city_dialog.preview_status.text = "Cannot display the generated terrain."
		return false
	new_city_preview_document = document
	new_city_preview_options = options.duplicate(true)
	new_city_preview_process_cursor = preview_process.state
	new_city_preview_game_cursor = preview_game.state
	var image := Minimap.create_image(preview_city, palette, "structures")
	new_city_dialog.preview_view.texture = ImageTexture.create_from_image(image)
	new_city_dialog.preview_status.text = (
		"Water: %s tiles   Trees: %s tiles   Height: %s–%s"
		% [
			_format_number(int(generated.water_tiles)),
			_format_number(int(generated.tree_tiles)),
			int(generated.minimum_altitude),
			int(generated.maximum_altitude),
		]
	)
	return true


func _cancel_new_city() -> void:
	new_city_dialog.preview_timer.stop()
	new_city_dialog.hide()
	new_city_preview_document = null
	new_city_preview_options.clear()
	new_city_dialog.preview_view.texture = null


func _create_new_city() -> void:
	_request_city_exit("create_new_city")


func _create_new_city_unchecked() -> void:
	new_city_dialog.preview_timer.stop()
	var terrain_options := _new_city_terrain_options()
	if (
		new_city_preview_document == null
		or new_city_preview_options != terrain_options
	):
		if not _generate_new_city_preview(false):
			_show_error("Cannot prepare the selected terrain.")
			return
	var template_path := reference_root.path_join("DEFAULT.SC2")
	var template := Sc2Document.load_path(template_path)
	if not template.is_valid():
		_show_error("Cannot load the default city: %s" % template.parse_error)
		return
	var difficulty := new_city_dialog.difficulty_input.get_selected_id()
	var starting_year := new_city_dialog.year_input.get_selected_id()
	var new_process_random := Random.new(new_city_preview_process_start)
	var new_game_random := GameRandom.new(new_city_preview_game_start)
	var result := NewCity.create(
		template,
		new_city_dialog.city_name_input.text,
		new_city_dialog.mayor_name_input.text,
		difficulty,
		starting_year,
		new_process_random,
		new_game_random,
		terrain_options,
		newspaper_session_state,
	)
	if not result.ok:
		_show_error("Cannot create a new city: %s" % result.error)
		return
	tool_random.state = new_process_random.state
	nuisance_random.state = new_game_random.state
	var document: Sc2File = result.document
	_activate_document(
		document,
		null,
		"Created %s in %d on %s difficulty with generated terrain. Map view: %s."
		% [
			document.city_name(),
			starting_year,
			_difficulty_name(difficulty),
			overlay_mode.capitalize(),
		],
	)


func _difficulty_name(difficulty: int) -> String:
	match difficulty:
		1:
			return "Easy"
		2:
			return "Medium"
		3:
			return "Hard"
		_:
			return "Unknown"


func _open_city_dialog() -> void:
	var city_directory := ProjectSettings.globalize_path("res://../references/CITIES")
	if DirAccess.dir_exists_absolute(city_directory):
		file_dialog.current_dir = city_directory
	file_dialog.popup_centered_ratio(0.8)


func _open_scenario_dialog() -> void:
	var scenario_directory := ProjectSettings.globalize_path("res://../references/SCENARIO")
	if DirAccess.dir_exists_absolute(scenario_directory):
		file_dialog.current_dir = scenario_directory
	file_dialog.popup_centered_ratio(0.8)


func _open_save_dialog() -> void:
	if current_document == null:
		return
	var save_directory := ProjectSettings.globalize_path("user://cities")
	DirAccess.make_dir_recursive_absolute(save_directory)
	save_dialog.current_dir = save_directory
	var save_name := current_document.source_path.get_file().get_basename()
	if save_name.is_empty() and city != null:
		save_name = city.city_name().validate_filename()
	if save_name.is_empty():
		save_name = "New City"
	save_dialog.current_file = save_name + ".SC2"
	save_dialog.popup_centered_ratio(0.8)


func _open_tile_set_dialog() -> void:
	var tile_set_directory := ProjectSettings.globalize_path("res://../references/SCURKART")
	if DirAccess.dir_exists_absolute(tile_set_directory):
		tile_set_dialog.current_dir = tile_set_directory
	tile_set_dialog.popup_centered_ratio(0.8)


func _load_tile_set(path: String) -> void:
	if base_large_sprites == null or base_small_medium_sprites == null:
		_show_error("Original sprite data is not loaded.")
		return
	var tile_set := ScurkTileSet.load_path(path)
	if not tile_set.is_valid():
		_show_error("Cannot load tile set: %s" % tile_set.parse_error)
		return
	_apply_scurk_tile_set(tile_set, path.get_file(), path)


func _apply_scurk_tile_set(
	tile_set: ScurkMif, display_name: String, path: String
) -> void:
	if base_large_sprites == null or base_small_medium_sprites == null:
		_show_error("Original sprite data is not loaded.")
		return
	if tile_set == null or not tile_set.is_valid():
		_show_error("Cannot apply an invalid SCURK tile set.")
		return
	var new_large := SpriteArchive.combine([base_large_sprites, tile_set.overrides])
	var new_small_medium := SpriteArchive.combine([
		base_small_medium_sprites, tile_set.overrides,
	])
	if not new_large.is_valid() or not new_small_medium.is_valid():
		_show_error("Cannot combine the tile set with the original sprite data.")
		return
	active_scurk_tile_set = tile_set
	active_scurk_name = display_name
	active_scurk_path = ProjectSettings.globalize_path(path).simplify_path() if not path.is_empty() else ""
	large_sprites = new_large
	small_medium_sprites = new_small_medium
	if scurk_place_print != null and scurk_place_print.visible:
		scurk_place_print.configure(palette, large_sprites, tile_set.names)
	_invalidate_sprite_art()
	if city != null:
		_refresh_map()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Loaded tile set %s: %d graphic replacements and %d names." % [
		active_scurk_name, tile_set.overrides.entries.size(), tile_set.names.size(),
	]


func _restore_original_tile_set() -> void:
	if base_large_sprites == null or base_small_medium_sprites == null:
		return
	active_scurk_tile_set = null
	active_scurk_name = ""
	active_scurk_path = ""
	large_sprites = base_large_sprites
	small_medium_sprites = base_small_medium_sprites
	if scurk_place_print != null and scurk_place_print.visible:
		scurk_place_print.configure(palette, large_sprites)
	_invalidate_sprite_art()
	if city != null:
		_refresh_map()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Restored the original tile set."


func _invalidate_sprite_art() -> void:
	static_render_epoch += 1
	static_city_image = null
	static_occlusion_commands.clear()
	static_occlusion_grid.clear()
	static_visual_signature = []
	static_render_mode = ""
	static_display_city = null
	static_view_cache.clear()
	pending_static_render = false
	dynamic_sprite_cache.clear()
	dynamic_foreground_cache.clear()
	dynamic_occluder_cache.clear()
	dynamic_visual_cache.clear()
	dynamic_special_batch_cache.clear()
	dynamic_sign_occluders.clear()
	dynamic_sign_occlusion_grid.clear()


func _open_manual_budget() -> void:
	if city == null:
		return
	_open_budget_dialog(Budget.funding_values(city), false)


func _open_budget_dialog(values: PackedInt32Array, annual: bool) -> void:
	if city == null or values.size() != Budget.BUDGET_COUNT:
		_show_error("Cannot open the budget because its saved values are invalid.")
		return
	if city.music_enabled() and simulation_engine != null:
		_play_music_track(Music.budget_track(simulation_engine.lfsr_random))
	annual_budget_pending = annual
	budget_dialog.open_budget(
		values,
		annual,
		city.document.misc_u32(Budget.MISC_AUTO_BUDGET) != 0,
	)
	_update_bond_controls()


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
			budget_dialog.open_bond_confirmation("issue", int(result.rate))
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
			budget_dialog.open_bond_confirmation("repay", int(result.rate))
		"insufficient_funds":
			_show_error("You Need $10,000 Cash\nto Repay an Outstanding Bond.")
		"no_bonds":
			_show_error("There are no outstanding bonds to repay.")
		_:
			_show_error("The bond could not be repaid.")


func _resolve_bond_action(action: String, confirmed: bool) -> void:
	if city == null or action.is_empty():
		return
	var confirmation := (
		Bonds.CONFIRMATION_CONFIRMED
		if confirmed
		else Bonds.CONFIRMATION_CANCELLED
	)
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
	if city == null or budget_dialog == null:
		return
	var bond_count := city.document.misc_u32(Bonds.MISC_BONDS)
	var funds := city.funds()
	var average_fixed := city.document.misc_i32(
		Budget.MISC_BUDGETS
		+ Budget.BUDGET_BONDS * Budget.BUDGET_RECORD_SIZE
		+ Budget.BUDGET_FUNDING
	)
	var oldest := city.document.misc_u32(Bonds.MISC_BOND_RATES) & 0xffff
	budget_dialog.set_bond_state(bond_count, funds, average_fixed, oldest)


func _commit_budget() -> void:
	if city == null:
		return
	var values := budget_dialog.funding_values()
	var auto_budget := budget_dialog.auto_budget_enabled()
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


func _open_scenario_intro(scenario: ScenarioState) -> void:
	var rendered_picture := scenario.picture_image(scenario_palette)
	if rendered_picture.ok:
		scenario_picture_view.texture = ImageTexture.create_from_image(rendered_picture.image)
	else:
		scenario_picture_view.texture = null
	var description := scenario.opening_description()
	description = description.replace("\r\n", "\n").replace("\r", "\n")
	scenario_text_view.text = description
	scenario_text_view.scroll_vertical = 0
	var name := city.city_name()
	if name.is_empty():
		name = current_document.source_path.get_file().get_basename()
	scenario_dialog.title = "Scenario: %s" % name
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Review the scenario briefing before the simulation starts."
	scenario_dialog.popup_centered()


func _begin_scenario() -> void:
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Scenario started."


func _city_has_unsaved_changes() -> bool:
	if current_document == null or city == null:
		return false
	if not current_city_saved_once:
		return true
	var serialized := current_document.serialize()
	return not serialized.ok or serialized.data != saved_city_snapshot


func _request_city_exit(action: String, path := "") -> void:
	if not _city_has_unsaved_changes():
		_perform_city_exit(action, path)
		return
	pending_city_exit_action = action
	pending_city_exit_path = path
	pending_city_exit_waiting_for_save = false
	var display_name := city.city_name()
	if display_name.is_empty():
		display_name = "this city"
	save_changes_dialog.dialog_text = "Save changes to %s before you continue?" % display_name
	save_changes_dialog.popup_centered()


func _perform_city_exit(action: String, path := "") -> void:
	match action:
		"create_new_city":
			_create_new_city_unchecked()
		"load_city":
			_load_city_unchecked(path)
		"quit":
			get_tree().quit()


func _save_pending_city_exit() -> void:
	if pending_city_exit_action.is_empty():
		return
	if current_save_path.is_empty():
		pending_city_exit_waiting_for_save = true
		_open_save_dialog()
		return
	if _save_copy(current_save_path):
		_continue_pending_city_exit()


func _on_save_changes_action(action: StringName) -> void:
	if action != &"discard":
		return
	save_changes_dialog.hide()
	_continue_pending_city_exit()


func _cancel_pending_city_exit() -> void:
	pending_city_exit_action = ""
	pending_city_exit_path = ""
	pending_city_exit_waiting_for_save = false


func _continue_pending_city_exit() -> void:
	var action := pending_city_exit_action
	var path := pending_city_exit_path
	_cancel_pending_city_exit()
	_perform_city_exit(action, path)


func _load_city(path: String) -> void:
	_request_city_exit("load_city", path)


func _load_city_unchecked(path: String) -> void:
	var document := Sc2Document.load_path(path)
	if not document.is_valid():
		_show_error(document.parse_error)
		return
	var loaded_scenario: ScenarioState
	if document.find_chunk("SCEN") != null:
		loaded_scenario = ScenarioModel.from_document(document)
		if not loaded_scenario.is_valid():
			_show_error(loaded_scenario.load_error)
			return
	_activate_document(
		document,
		loaded_scenario,
		"Loaded %s. Map view: %s."
		% [path.get_file(), overlay_mode.capitalize()],
	)


func _activate_document(
	document: Sc2File, loaded_scenario: ScenarioState = null, status_text := ""
) -> bool:
	var loaded_city := CityModel.from_document(document)
	if not loaded_city.is_valid():
		_show_error(loaded_city.load_error)
		return false
	var music_was_active := _music_playback_is_active()

	budget_dialog.reset_dialogs()
	if game_over_dialog.visible:
		game_over_dialog.hide()
	if scenario_dialog.visible:
		scenario_dialog.hide()
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
	pending_network_connection.clear()
	if network_connection_dialog.visible:
		network_connection_dialog.hide()
	pending_highway_connection.clear()
	if highway_connection_dialog.visible:
		highway_connection_dialog.hide()
	pending_tunnel_request.clear()
	if tunnel_dialog.visible:
		tunnel_dialog.hide()
	if forest_protest_dialog != null and forest_protest_dialog.visible:
		forest_protest_dialog.hide()
	if building_objection_dialog != null and building_objection_dialog.visible:
		building_objection_dialog.hide()
	pending_building_objection_group = -1
	pending_building_objection_subtool = -1
	if new_city_dialog != null and new_city_dialog.visible:
		new_city_dialog.hide()
	if scurk_place_print != null and scurk_place_print.visible:
		scurk_place_print.hide()
	if scurk_print != null:
		scurk_print.hide()
	pending_scurk_print_options.clear()
	scurk_place_undo_stack.clear()
	scurk_place_redo_stack.clear()
	annual_budget_pending = false
	game_over_active = false
	city = loaded_city
	current_document = document
	var initial_serialized := current_document.serialize()
	saved_city_snapshot = (
		initial_serialized.data.duplicate() if initial_serialized.ok else PackedByteArray()
	)
	current_city_saved_once = not current_document.source_path.is_empty()
	var source_path := current_document.source_path.simplify_path()
	current_save_path = (
		source_path
		if (
			not source_path.is_empty()
			and source_path != reference_root
			and not source_path.begins_with(reference_root + "/")
		)
		else ""
	)
	_hide_main_menu()
	static_render_epoch += 1
	static_city_image = null
	static_occlusion_commands.clear()
	static_occlusion_grid.clear()
	static_visual_signature = []
	static_render_mode = ""
	static_display_city = null
	static_view_cache.clear()
	pending_static_render = false
	palette_cycle_ticks = 0
	_update_palette_cycle_texture()
	dynamic_sprite_cache.clear()
	dynamic_foreground_cache.clear()
	dynamic_occluder_cache.clear()
	dynamic_visual_cache.clear()
	dynamic_special_batch_cache.clear()
	dynamic_sign_occluders.clear()
	dynamic_sign_occlusion_grid.clear()
	var process_seed := tool_random.state
	var game_seed := nuisance_random.state
	var lfsr_seed := (
		simulation_engine.lfsr_random.state
		if simulation_engine != null
		else (Time.get_ticks_msec() & 0xffff) | 1
	)
	simulation_engine = Simulation.new(city, process_seed, lfsr_seed, game_seed)
	speed_controller = GameSpeed.new(simulation_engine)
	_sync_speed_ui()
	tool_random = simulation_engine.random
	nuisance_random = simulation_engine.game_random
	simulation_map_dirty = false
	recent_news.clear()
	_refresh_saved_news_summary()
	last_edit_command = {}
	dispatch_cycles = PackedInt32Array([0, 0, 0])
	dispatch_initialized = false
	undo_button.disabled = true
	_update_zoom_controls(map_view.zoom_percent())
	var display_name := city.city_name()
	if display_name.is_empty():
		display_name = document.source_path.get_file().get_basename()
	if display_name.is_empty():
		display_name = "New City"
	city_label.text = display_name
	city_label.tooltip_text = display_name
	_refresh_details()
	status_label.remove_theme_color_override("font_color")
	status_label.text = status_text if not status_text.is_empty() else "City ready."
	_refresh_map()
	_update_edit_state()
	if not city.music_enabled():
		_stop_music()
	elif music_was_active:
		simulation_engine.midi_playback_active = true
	else:
		_play_music_track(music_director.next_general_track())
	if loaded_scenario != null:
		_open_scenario_intro(loaded_scenario)
	return true


func _play_music_track(track_id: int) -> bool:
	if (
		music_player == null
		or track_id < Music.FIRST_TRACK_ID
		or track_id >= Music.FIRST_TRACK_ID + Music.TRACK_COUNT
	):
		return false
	if AudioServer.get_driver_name() == "Dummy":
		dummy_music_active = true
		if simulation_engine != null:
			simulation_engine.midi_playback_active = true
		return true
	dummy_music_active = false
	var result := music_player.play_path(
		reference_root.path_join("SOUNDS/%d.MID" % track_id), track_id
	)
	if not result.ok:
		if simulation_engine != null:
			simulation_engine.midi_playback_active = false
		push_warning("Cannot play MIDI track %d: %s" % [track_id, result.error])
		return false
	if simulation_engine != null:
		simulation_engine.midi_playback_active = true
	return true


func _on_music_track_finished(_track_id: int) -> void:
	dummy_music_active = false
	if simulation_engine != null:
		simulation_engine.midi_playback_active = false


func _music_playback_is_active() -> bool:
	if city == null or not city.music_enabled():
		return false
	if AudioServer.get_driver_name() == "Dummy":
		return dummy_music_active
	return music_player != null and music_player.is_track_active()


func _handle_application_focus_out() -> void:
	application_has_focus = false
	_stop_music()
	_stop_sound_effects()


func _handle_application_focus_in() -> void:
	var regained_focus := not application_has_focus
	application_has_focus = true
	if not regained_focus or city == null or not city.music_enabled():
		return
	if not _music_playback_is_active():
		_play_music_track(music_director.next_general_track())


func _stop_music() -> void:
	dummy_music_active = false
	if music_player != null:
		music_player.stop()
	if simulation_engine != null:
		simulation_engine.midi_playback_active = false


func _stop_sound_effects() -> void:
	wave_sound_gate.stop()
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(SOUND_EFFECT_GROUP):
		var player := node as AudioStreamPlayer
		if player == null:
			continue
		player.stop()
		player.queue_free()
	tool_loop_player = null


func _load_wave_sound_cache() -> void:
	wave_stream_cache.clear()
	for sound_id in range(WaveSounds.SOUND_FIRST, WaveSounds.SOUND_LAST + 1):
		var sound_path := reference_root.path_join("SOUNDS/%d.WAV" % sound_id)
		if not FileAccess.file_exists(sound_path):
			continue
		var stream := AudioStreamWAV.load_from_file(sound_path)
		if stream != null:
			wave_stream_cache[sound_id] = stream


func _on_save_path_selected(path: String) -> void:
	var saved := _save_copy(path)
	if saved and pending_city_exit_waiting_for_save:
		_continue_pending_city_exit()


func _on_save_dialog_canceled() -> void:
	if pending_city_exit_waiting_for_save:
		_cancel_pending_city_exit()


func _save_copy(path: String) -> bool:
	if current_document == null:
		_show_error("No city is loaded.")
		return false
	var output_path := path
	if output_path.get_extension().is_empty():
		output_path += ".SC2"
	output_path = output_path.simplify_path()
	if output_path == reference_root or output_path.begins_with(reference_root + "/"):
		_show_error("Choose a location outside the read-only references directory.")
		return false

	var serialized := current_document.serialize()
	if not serialized.ok:
		_show_error(serialized.error)
		return false
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		_show_error("Cannot open save output: %s" % error_string(FileAccess.get_open_error()))
		return false
	output.store_buffer(serialized.data)
	output.flush()
	var write_error := output.get_error()
	output.close()
	if write_error != OK:
		_show_error("Cannot write save output: %s" % error_string(write_error))
		return false
	current_document.source_path = output_path
	current_save_path = output_path
	current_city_saved_once = true
	saved_city_snapshot = serialized.data.duplicate()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Saved city copy: %s" % output_path
	return true


func _set_overlay(mode: String) -> void:
	if not MAP_DISPLAY_MODES.has(mode):
		return
	overlay_mode = mode
	_sync_view_controls()
	_update_edit_state()
	if city != null:
		status_label.text = "Map view: %s" % overlay_mode.capitalize()
		_refresh_map(false)


func _set_surface_visibility(enabled: bool, layer: String) -> void:
	if not surface_visibility.has(layer) or bool(surface_visibility[layer]) == enabled:
		return
	surface_visibility[layer] = enabled
	_invalidate_view_render()
	_sync_view_controls()
	if city != null and overlay_mode == "city":
		_refresh_map(false)
	status_label.text = "%s %s." % [
		layer.capitalize(), "shown" if enabled else "hidden",
	]


func _set_underground_pipes_visible(enabled: bool) -> void:
	if show_underground_pipes == enabled:
		return
	show_underground_pipes = enabled
	_invalidate_view_render()
	_sync_view_controls()
	if city != null and overlay_mode == "underground":
		_refresh_map(false)
	status_label.text = "Underground pipes %s." % ("shown" if enabled else "hidden")


func _invalidate_view_render() -> void:
	static_render_epoch += 1
	static_visual_signature.clear()
	static_render_mode = ""
	static_view_cache.clear()
	static_occlusion_commands.clear()
	static_occlusion_grid.clear()
	dynamic_occluder_cache.clear()
	dynamic_sign_occluders.clear()
	dynamic_sign_occlusion_grid.clear()


func _select_speed(speed_value: int) -> void:
	if speed_controller == null:
		return
	if not speed_controller.set_speed(speed_value):
		_show_error("Cannot change the simulation speed.")
		return
	_sync_speed_ui()
	status_label.remove_theme_color_override("font_color")
	status_label.text = "%s speed selected." % speed_controller.speed_name()


func _sync_speed_ui() -> void:
	var selected_speed := (
		speed_controller.speed if speed_controller != null else GameSpeed.Speed.PAUSED
	)
	if speed_menu != null:
		var popup := speed_menu.get_popup()
		for speed_id in range(5):
			var item_index := popup.get_item_index(speed_id)
			popup.set_item_checked(
				item_index, speed_controller != null and speed_id + 1 == selected_speed
			)
	if status_speed_label != null:
		var speed_name := speed_controller.speed_name() if speed_controller != null else "--"
		status_speed_label.text = "Speed: %s" % speed_name
		status_speed_label.set_meta(
			"status_tooltip_text", "Current simulation speed: %s." % speed_name
		)
		_sync_overflow_tooltip(status_speed_label)


func _refresh_after_city_edit(command: Dictionary) -> void:
	if not _apply_static_edit_patch(command):
		_refresh_map(false)


func _apply_static_edit_patch(command: Dictionary) -> bool:
	if (
		overlay_mode != "city"
		or city == null
		or palette_index_encoding == null
		or static_city_image == null
		or static_city_image.is_empty()
		or static_render_mode != "city"
		or static_display_city == null
		or static_render_thread != null
	):
		return false
	var dirty_indices := _edit_dirty_indices(command)
	if dirty_indices.is_empty():
		return false
	var view_size := _city_view_size()
	var sprite_archive := _sprite_archive_for_view(view_size)
	var dirty_rect := IsometricRenderer.dirty_screen_rect(
		dirty_indices, sprite_archive, view_size
	)
	var full_area := IsometricRenderer.output_size_for_view(view_size).x * (
		IsometricRenderer.output_size_for_view(view_size).y
	)
	if (
		dirty_rect.get_area() <= 0
		or float(dirty_rect.get_area()) / float(full_area)
			> STATIC_EDIT_PATCH_MAX_AREA_RATIO
	):
		return false
	var display_city := ViewFilter.surface_copy(city, surface_visibility)
	if display_city == null or not display_city.is_valid():
		return false
	var patched := IsometricRenderer.patch_static_image(
		static_city_image,
		display_city,
		palette_index_encoding,
		sprite_archive,
		dirty_indices,
		view_size,
		int(Time.get_ticks_msec() / 100)
	)
	if not patched.get("ok", false):
		return false
	static_render_epoch += 1
	static_city_image = patched.image
	static_display_city = display_city
	static_visual_signature = _static_signature_for_mode("city", view_size)
	static_render_mode = "city"
	pending_static_render = false
	_set_static_occlusion_commands(
		IsometricRenderer.patch_static_occlusion_commands(
			static_occlusion_commands,
			display_city,
			sprite_archive,
			dirty_indices,
			view_size
		),
		view_size
	)
	static_view_cache["city"] = {
		"image": static_city_image,
		"occlusion_commands": static_occlusion_commands,
		"signature": static_visual_signature,
		"display_city": static_display_city,
		"view_size": view_size,
	}
	var texture := ImageTexture.create_from_image(static_city_image)
	map_view.set_city_view(static_display_city, texture, texture, true)
	_refresh_moving_things(view_size)
	return true


static func _edit_dirty_indices(command: Dictionary) -> PackedInt32Array:
	var seen := {}
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT"]:
		if not old_payloads.has(chunk_id) or not new_payloads.has(chunk_id):
			continue
		var old_bytes: PackedByteArray = old_payloads[chunk_id]
		var new_bytes: PackedByteArray = new_payloads[chunk_id]
		var stride := 2 if chunk_id == "ALTM" else 1
		if (
			old_bytes.size() != CityState.TILE_COUNT * stride
			or new_bytes.size() != old_bytes.size()
		):
			continue
		for index in CityState.TILE_COUNT:
			var offset := index * stride
			var changed := old_bytes[offset] != new_bytes[offset]
			if stride == 2:
				changed = changed or old_bytes[offset + 1] != new_bytes[offset + 1]
			if changed:
				seen[index] = true
	if command.has("old_text") and command.has("new_text"):
		var old_text: PackedByteArray = command.old_text
		var new_text: PackedByteArray = command.new_text
		if (
			old_text.size() == CityState.TILE_COUNT
			and new_text.size() == CityState.TILE_COUNT
		):
			for index in CityState.TILE_COUNT:
				if old_text[index] != new_text[index]:
					seen[index] = true
	var tile_indices: PackedInt32Array = command.get(
		"tile_indices", PackedInt32Array()
	)
	for index in tile_indices:
		if index >= 0 and index < CityState.TILE_COUNT:
			seen[index] = true
	for point_value in command.get("points", []):
		var point: Vector2i = point_value
		var index := point.x * CityState.MAP_SIZE + point.y
		if point.x >= 0 and point.x < CityState.MAP_SIZE and point.y >= 0 and point.y < CityState.MAP_SIZE:
			seen[index] = true
	for point_key in ["point", "target"]:
		if command.has(point_key):
			var point: Vector2i = command[point_key]
			if point.x >= 0 and point.x < CityState.MAP_SIZE and point.y >= 0 and point.y < CityState.MAP_SIZE:
				seen[point.x * CityState.MAP_SIZE + point.y] = true
	if command.has("tile_index"):
		var tile_index := int(command.tile_index)
		if tile_index >= 0 and tile_index < CityState.TILE_COUNT:
			seen[tile_index] = true
	if command.has("site"):
		var site: Rect2i = command.site
		for x in range(site.position.x, site.end.x):
			for y in range(site.position.y, site.end.y):
				if x >= 0 and x < CityState.MAP_SIZE and y >= 0 and y < CityState.MAP_SIZE:
					seen[x * CityState.MAP_SIZE + y] = true
	var sorted_indices: Array = seen.keys()
	sorted_indices.sort()
	var result := PackedInt32Array()
	for index in sorted_indices:
		result.append(int(index))
	return result


func _refresh_map(force := true) -> void:
	if city == null or palette == null:
		return
	map_view.set_signs_visible(
		overlay_mode == "city" and bool(surface_visibility.signs)
	)
	var image: Image
	if overlay_mode == "city" or overlay_mode == "underground":
		if force:
			pending_static_render = false
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
				dynamic_sign_occluders.clear()
				dynamic_sign_occlusion_grid.clear()
				map_view.set_dynamic_sprites([])
				_refresh_sign_occlusion(view_size)
			return
		if (
			not force
			and static_city_image != null
			and static_render_mode == overlay_mode
			and current_signature == static_visual_signature
		):
			if overlay_mode == "city":
				_refresh_moving_things(view_size)
			else:
				dynamic_sign_occluders.clear()
				dynamic_sign_occlusion_grid.clear()
				map_view.set_dynamic_sprites([])
				_refresh_sign_occlusion(view_size)
			return
		if not force:
			_request_static_render(current_signature, view_size, sprite_archive, overlay_mode)
			if overlay_mode == "city":
				_refresh_moving_things(view_size)
			else:
				dynamic_sign_occluders.clear()
				dynamic_sign_occlusion_grid.clear()
				map_view.set_dynamic_sprites([])
				_refresh_sign_occlusion(view_size)
			return
		static_render_epoch += 1
		var display_city := (
			city
			if overlay_mode == "underground"
			else ViewFilter.surface_copy(city, surface_visibility)
		)
		var indexed: Dictionary
		if overlay_mode == "underground":
			indexed = UndergroundView.create_image(
				display_city, palette_index_encoding, sprite_archive, view_size, true,
				show_underground_pipes
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
		pending_static_render = false
		image = Minimap.create_image(city, palette, overlay_mode)
		image.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
		static_city_image = null
		static_occlusion_commands.clear()
		static_occlusion_grid.clear()
		static_visual_signature = []
		dynamic_sign_occluders.clear()
		dynamic_sign_occlusion_grid.clear()
		map_view.set_dynamic_sprites([])
	var texture := ImageTexture.create_from_image(image)
	map_view.set_city_view(
		static_display_city if overlay_mode in ["city", "underground"] else city,
		texture, texture if overlay_mode in ["city", "underground"] else null,
		overlay_mode in ["city", "underground"]
	)
	if overlay_mode == "city":
		_refresh_moving_things(_city_view_size())
	else:
		_refresh_sign_occlusion(_city_view_size())


func _request_static_render(
	signature: Array, view_size: int, sprite_archive: Sc2SpriteArchive, render_mode := "city"
) -> void:
	if static_render_thread != null:
		return
	var now_msec := Time.get_ticks_msec()
	if (
		simulation_engine != null
		and simulation_engine.active_disaster_type != 0
		and now_msec - last_static_render_started_msec
			< ACTIVE_DISASTER_RENDER_INTERVAL_MSEC
	):
		pending_static_render = true
		return
	pending_static_render = false
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
	static_render_job.surface_visibility = surface_visibility.duplicate()
	static_render_job.show_underground_pipes = show_underground_pipes
	static_render_thread = Thread.new()
	var start_error := static_render_thread.start(
		static_render_job.run, Thread.PRIORITY_LOW
	)
	if start_error != OK:
		static_render_thread = null
		static_render_job = null
		_show_error("Cannot start the city renderer: %s" % error_string(start_error))
	else:
		last_static_render_started_msec = now_msec


func _start_pending_static_render() -> void:
	if (
		not pending_static_render
		or static_render_thread != null
		or city == null
		or overlay_mode not in ["city", "underground"]
	):
		return
	var view_size := _city_view_size()
	_request_static_render(
		_static_signature_for_mode(overlay_mode, view_size),
		view_size,
		_sprite_archive_for_view(view_size),
		overlay_mode,
	)


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
		dynamic_sign_occluders.clear()
		dynamic_sign_occlusion_grid.clear()
		map_view.set_dynamic_sprites([])
		_refresh_sign_occlusion(int(rendered.view_size))
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
		return UndergroundView.visual_signature(
			city, view_size, show_underground_pipes
		)
	var result := IsometricRenderer.static_visual_signature(city, view_size)
	result.append_array([
		bool(surface_visibility.buildings),
		bool(surface_visibility.networks),
		bool(surface_visibility.water),
		bool(surface_visibility.trees),
		bool(surface_visibility.zones),
	])
	return result


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
		dynamic_sign_occluders.clear()
		dynamic_sign_occlusion_grid.clear()
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
		var visual_cache_key := ""
		if command.has("overlay"):
			var command_position := Vector2i(command.position) * divisor
			visual_cache_key = "%d:%d:%d:%d:%d:%d" % [
				int(command.sprite_id), int(command.flip), command_position.x,
				command_position.y, int(command.depth_order), view_size,
			]
			if dynamic_visual_cache.has(visual_cache_key):
				visuals.append(dynamic_visual_cache[visual_cache_key])
				continue
		var resource := _dynamic_sprite_resource(
			sprite_archive, command.sprite_id, command.flip, divisor
		)
		if resource.is_empty():
			continue
		var position := Vector2i(command.position) * divisor
		var texture: Texture2D = resource.texture
		var index_texture: Texture2D = resource.index_texture
		var visual_image: Image = resource.image
		var occluder_mask := _dynamic_occluder_image(
			sprite_archive, divisor, position, resource.image.get_size(),
			int(command.get("depth_order", -1)), bool(command.get("train", false))
		)
		if command.shadow:
			var shadow_image := _dynamic_shadow_image(resource.image, position, occluder_mask)
			if shadow_image == null:
				continue
			visual_image = shadow_image
			texture = ImageTexture.create_from_image(shadow_image)
			index_texture = null
		else:
			var occluded := IsometricRenderer.occlude_dynamic_with_mask(
				resource.image, occluder_mask, position, static_city_image,
				command.get("same_tile_foreground_indices", PackedInt32Array())
			)
			if int(occluded.occluded_pixels) > 0:
				visual_image = occluded.image
				texture = ImageTexture.create_from_image(occluded.image)
				index_texture = texture
		var visual := {
			"texture": texture,
			"index_texture": index_texture,
			"palette_lookup_all": true,
			"position": Vector2(position),
			"size": Vector2(resource.image.get_size()),
			"image": visual_image,
			"special_overlay": command.has("overlay"),
			"batch_cache_key": visual_cache_key,
			"depth_order": int(command.get("depth_order", -1)),
			"shadow": bool(command.get("shadow", false)),
		}
		visuals.append(visual)
		if not visual_cache_key.is_empty():
			dynamic_visual_cache[visual_cache_key] = visual
	dynamic_sign_occluders = visuals.duplicate()
	dynamic_sign_occlusion_grid = IsometricRenderer.build_occlusion_grid(
		dynamic_sign_occluders, 1
	)
	if dynamic_special_batch_cache.size() > 128:
		dynamic_special_batch_cache.clear()
	var batched_visuals := DynamicSpriteCanvas.batch_special_visuals(
		visuals, dynamic_special_batch_cache
	)
	map_view.set_dynamic_sprites(batched_visuals)
	_refresh_sign_occlusion(view_size)


func _refresh_sign_occlusion(view_size: int) -> void:
	if (
		overlay_mode != "city"
		or not bool(surface_visibility.signs)
		or city == null
		or map_view == null
		or static_city_image == null
		or static_occlusion_commands.is_empty()
	):
		if map_view != null:
			map_view.set_sign_occlusion_visuals({})
		return
	var entries := map_view.sign_source_entries()
	if entries.is_empty():
		map_view.set_sign_occlusion_visuals({})
		return
	var sprite_archive := _sprite_archive_for_view(view_size)
	var configuration := IsometricRenderer.view_configuration(view_size)
	var divisor := int(configuration.divisor)
	if static_occlusion_grid.is_empty():
		static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
			static_occlusion_commands, divisor
		)
	var color_indices := palette.animation_index_map(palette_cycle_ticks)
	var image_bounds := Rect2i(Vector2i.ZERO, static_city_image.get_size())
	var visuals := {}
	for entry in entries:
		var source_bounds: Rect2i = entry.bounds
		var bounds := source_bounds.intersection(image_bounds)
		if bounds.get_area() <= 0:
			continue
		var foreground := Image.create(
			bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8
		)
		foreground.fill(Color.TRANSPARENT)
		var copied_pixels := 0
		var candidate_indices := IsometricRenderer.occlusion_candidate_indices(
			static_occlusion_grid, bounds
		)
		for command_index in candidate_indices:
			var command := static_occlusion_commands[command_index]
			if int(command.depth_order) <= int(entry.draw_order):
				continue
			var command_position := Vector2i(command.position) * divisor
			var command_size := Vector2i(command.size) * divisor
			var overlap := bounds.intersection(Rect2i(command_position, command_size))
			if overlap.get_area() <= 0:
				continue
			var resource := _dynamic_sprite_resource(
				sprite_archive, int(command.sprite_id), bool(command.flip), divisor
			)
			if resource.is_empty():
				continue
			var mask: Image = resource.image
			for map_y in range(overlap.position.y, overlap.end.y):
				var mask_y := map_y - command_position.y
				for map_x in range(overlap.position.x, overlap.end.x):
					var mask_x := map_x - command_position.x
					if mask.get_pixel(mask_x, mask_y).a == 0.0:
						continue
					var encoded := static_city_image.get_pixel(map_x, map_y)
					var palette_index := roundi(encoded.r * 255.0)
					var display_index := int(color_indices[palette_index])
					foreground.set_pixel(
						map_x - bounds.position.x, map_y - bounds.position.y,
						palette.color(display_index),
					)
					copied_pixels += 1
		var moving_candidates: Array[Dictionary] = []
		for moving_index in IsometricRenderer.occlusion_candidate_indices(
			dynamic_sign_occlusion_grid, bounds
		):
			moving_candidates.append(dynamic_sign_occluders[moving_index])
		for visual in MapControl.later_sign_occluder_visuals(
			moving_candidates, bounds, int(entry.draw_order)
		):
			var moving_image: Image = visual.get("image") as Image
			if moving_image == null:
				continue
			var moving_position := Vector2i(visual.get("position", Vector2.ZERO))
			var overlap := bounds.intersection(
				Rect2i(moving_position, moving_image.get_size())
			)
			for map_y in range(overlap.position.y, overlap.end.y):
				var moving_y := map_y - moving_position.y
				for map_x in range(overlap.position.x, overlap.end.x):
					var moving_x := map_x - moving_position.x
					var encoded := moving_image.get_pixel(moving_x, moving_y)
					if encoded.a == 0.0:
						continue
					var palette_index := roundi(encoded.r * 255.0)
					var display_index := int(color_indices[palette_index])
					foreground.set_pixel(
						map_x - bounds.position.x, map_y - bounds.position.y,
						palette.color(display_index),
					)
					copied_pixels += 1
		if copied_pixels == 0:
			continue
		var texture := ImageTexture.create_from_image(foreground)
		visuals[int(entry.key)] = {
			"texture": texture,
			"position": Vector2(bounds.position),
			"size": Vector2(bounds.size),
		}
	map_view.set_sign_occlusion_visuals(visuals)


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
	var cache_key := "%d:%d:%d:%d:%d:%d:%d" % [
		position.x, position.y, size.x, size.y, draw_order, int(is_train),
		static_render_epoch,
	]
	if dynamic_occluder_cache.has(cache_key):
		return dynamic_occluder_cache[cache_key] as Image
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
	dynamic_occluder_cache[cache_key] = mask
	return mask


func _set_static_occlusion_commands(commands: Array, view_size: int) -> void:
	static_occlusion_commands.assign(commands)
	dynamic_occluder_cache.clear()
	dynamic_visual_cache.clear()
	dynamic_special_batch_cache.clear()
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
	_play_sound_events(sound_events)


func _play_sound_events(sound_events: Array) -> void:
	if city == null or not city.sound_enabled():
		return
	for sound_event in sound_events:
		var sound_id := MovingThingAudio.event_sound_id(
			sound_event, overlay_mode, _city_view_size()
		)
		if sound_id < 0:
			continue
		var stream := wave_stream_cache.get(sound_id) as AudioStreamWAV
		if stream == null:
			continue
		if not wave_sound_gate.request(sound_id):
			continue
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_linear = app_effects_volume
		player.finished.connect(player.queue_free)
		add_child(player)
		player.add_to_group(SOUND_EFFECT_GROUP)
		player.play()


func _play_tool_success_sound(
	group_index: int, subtool_index: int, free_mode := false
) -> void:
	if free_mode:
		return
	_play_sound_events(ToolSounds.success_events(group_index, subtool_index))


func _play_tool_failure_sound(
	group_index: int,
	subtool_index: int,
	error := "",
	free_mode := false
) -> void:
	if free_mode:
		return
	_play_sound_events(
		ToolSounds.failure_events(group_index, subtool_index, str(error))
	)


func _start_tool_loop_sound(sound_id: int) -> void:
	_stop_tool_loop_sound()
	if city == null or not city.sound_enabled():
		return
	var cached_stream := wave_stream_cache.get(sound_id) as AudioStreamWAV
	if cached_stream == null:
		return
	var stream := cached_stream.duplicate() as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = maxi(1, roundi(stream.get_length() * stream.mix_rate))
	tool_loop_player = AudioStreamPlayer.new()
	tool_loop_player.stream = stream
	tool_loop_player.volume_linear = app_effects_volume
	add_child(tool_loop_player)
	tool_loop_player.add_to_group(SOUND_EFFECT_GROUP)
	tool_loop_player.play()


func _stop_tool_loop_sound() -> void:
	if not is_instance_valid(tool_loop_player):
		tool_loop_player = null
		return
	tool_loop_player.stop()
	tool_loop_player.queue_free()
	tool_loop_player = null


func _show_news_items(news_items: Array) -> void:
	for item in news_items:
		var news_type := int(item.get("type", 0))
		var name: String = NEWS_NAMES.get(news_type, "City report")
		recent_news.insert(0, name)
	while recent_news.size() > 3:
		recent_news.remove_at(recent_news.size() - 1)
	status_report_index = 0
	status_report_elapsed_seconds = 0.0
	_refresh_status_summary()


func _show_forest_protest() -> void:
	if forest_protest_dialog == null:
		return
	forest_protest_message.text = forest_protest_text
	forest_protest_dialog.popup_centered()


func _show_building_objection() -> void:
	if building_objection_dialog == null:
		return
	building_objection_message.text = building_objection_text.replace(
		"\r\n", "\n"
	).replace("\r", "\n")
	building_objection_dialog.popup_centered()


func _on_building_objection_closed() -> void:
	if pending_building_objection_group < 0:
		return
	_play_tool_failure_sound(
		pending_building_objection_group,
		pending_building_objection_subtool,
	)
	pending_building_objection_group = -1
	pending_building_objection_subtool = -1


func _refresh_saved_news_summary() -> void:
	if city == null or current_document == null:
		recent_news.clear()
		status_report_index = 0
		status_report_elapsed_seconds = 0.0
		_refresh_status_summary()
		return
	var misc_chunk := current_document.find_chunk("MISC")
	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		recent_news = PackedStringArray(["Unavailable"])
		status_report_index = 0
		status_report_elapsed_seconds = 0.0
		_refresh_status_summary()
		return
	var reports := PackedStringArray()
	for slot in NewsQueue.QUEUE_COUNT:
		var record := NewsQueue.story_record(misc_chunk.decoded_payload, slot)
		if record.is_empty() or int(record.priority) <= 0:
			continue
		var story_type := int(record.type)
		reports.append(str(NEWS_NAMES.get(story_type, "City report")))
		if reports.size() == 3:
			break
	recent_news = reports
	status_report_index = 0
	status_report_elapsed_seconds = 0.0
	_refresh_status_summary()


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
	if index < 0 or index >= Tools.GROUPS.size():
		return
	selected_group = index
	for button_index in toolbar_buttons.size():
		toolbar_buttons[button_index].button_pressed = button_index == selected_group
	if selected_group == Dispatch.GROUP_DISPATCH:
		dispatch_cycles = PackedInt32Array([0, 0, 0])
		dispatch_initialized = false
	var group := Tools.group(selected_group)
	for child in child_tool_grid.get_children():
		child_tool_grid.remove_child(child)
		child.queue_free()
	child_tool_buttons.clear()
	var show_child_palette := selected_group < 15
	active_tool_group_label.visible = show_child_palette
	child_tool_scroll.visible = show_child_palette
	if not show_child_palette:
		selected_subtool = 0
		_update_edit_state()
		return
	active_tool_group_label.text = str(group.name)
	var child_button_group := ButtonGroup.new()
	var first_available_subtool := -1
	for subtool_index in group.tools.size():
		if selected_group == 3 and subtool_index == 1:
			continue
		if _is_tool_variant(selected_group, subtool_index):
			continue
		var tool := Tools.tool(selected_group, subtool_index)
		var price := "Free" if tool.cost == 0 else "$%s" % _format_number(tool.cost)
		var button := Button.new()
		button.custom_minimum_size = Vector2(175, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = child_button_group
		button.text = "%s\n%s" % [tool.name, price]
		button.clip_text = true
		button.icon = _tool_button_icon(selected_group, subtool_index)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.pressed.connect(_select_subtool.bind(subtool_index))
		var available := city == null or ToolAvailability.is_available(
			city, selected_group, subtool_index
		)
		button.disabled = not available
		button.tooltip_text = _tool_button_tooltip(
			selected_group, subtool_index, available
		)
		child_tool_grid.add_child(button)
		child_tool_buttons[subtool_index] = button
		if available and first_available_subtool < 0:
			first_available_subtool = subtool_index
	selected_subtool = maxi(0, first_available_subtool)
	_sync_child_tool_selection()
	_update_edit_state()


func _select_subtool(index: int) -> void:
	selected_subtool = index
	_sync_child_tool_selection()
	_update_edit_state()
	if selected_tool_available and _is_tool_chooser(selected_group, selected_subtool):
		_open_tool_choice_dialog(selected_group)


func _is_tool_chooser(group_index: int, subtool_index: int) -> bool:
	return group_index == 5 and subtool_index == 4


func _is_tool_variant(group_index: int, subtool_index: int) -> bool:
	return group_index == 5 and subtool_index >= 5


func _sync_child_tool_selection() -> void:
	var displayed_subtool := selected_subtool
	if selected_group == 5 and selected_subtool >= 5:
		displayed_subtool = 4
	for subtool_index in child_tool_buttons:
		var button: Button = child_tool_buttons[subtool_index]
		button.button_pressed = int(subtool_index) == displayed_subtool


func _tool_button_tooltip(
	group_index: int, subtool_index: int, available: bool
) -> String:
	var tool := Tools.tool(group_index, subtool_index)
	if tool.is_empty():
		return ""
	var price := "Free" if int(tool.cost) == 0 else "$%s" % _format_number(tool.cost)
	var lines := PackedStringArray([
		str(tool.name),
		"Cost: %s" % price,
	])
	if int(tool.area) > 0:
		lines.append("Footprint: %d x %d tiles" % [tool.area, tool.area])
	if group_index == 3 and subtool_index >= 2:
		var details := Tools.power_plant_details(subtool_index)
		if not details.is_empty():
			lines.append("Nominal output: %d MW" % details.output_mw)
			lines.append("Grid capacity: %s" % details.grid_capacity)
			lines.append("Pollution factor: %d" % details.pollution)
			lines.append("Service life: %s" % details.service_life)
			lines.append(str(details.note))
	if not available:
		lines.append("Status: Not available in this city.")
	return "\n".join(lines)


func _refresh_tool_availability() -> bool:
	if city == null or child_tool_grid == null:
		return false
	var changed := false
	for subtool_index in child_tool_buttons:
		var available := ToolAvailability.is_available(
			city, selected_group, int(subtool_index)
		)
		var button: Button = child_tool_buttons[subtool_index]
		if button.disabled == available:
			button.disabled = not available
			changed = true
		button.tooltip_text = _tool_button_tooltip(
			selected_group, int(subtool_index), available
		)
	var current_available := ToolAvailability.is_available(
		city, selected_group, selected_subtool
	)
	return changed or current_available != selected_tool_available


func _update_edit_state() -> void:
	if map_view == null:
		return
	if scurk_place_print != null and scurk_place_print.visible:
		if scurk_place_print.is_object_mode():
			var tile_id := scurk_place_print.selected_tile_id
			var area := Demolish.structure_area(tile_id)
			var can_place := (
				city != null
				and overlay_mode == "city"
				and ScurkPlace.is_placeable_tile(tile_id)
			)
			map_view.set_edit_enabled(can_place, "point", area, false)
			_refresh_status_summary()
			if status_label != null:
				status_label.remove_theme_color_override("font_color")
				var scurk_detail := (
					"SCURK tile %d selected. Click its anchor tile to place a %d by %d object."
					% [tile_id, area, area]
					if can_place
					else "Select a SCURK object to place."
				)
				status_label.text = (
					"SCURK Tile %d" % tile_id if can_place else "SCURK Place"
				)
				status_label.set_meta("status_tooltip_text", scurk_detail)
				_sync_overflow_tooltip(status_label)
			return
		var scurk_tool := scurk_place_print.selected_edit_tool()
		var can_edit := city != null and not scurk_tool.is_empty()
		var scurk_group := int(scurk_tool.get("group", -1))
		var scurk_subtool := int(scurk_tool.get("subtool", -1))
		var scurk_zone := int(scurk_tool.get("zone", -1))
		var is_scurk_zone := scurk_zone >= 0
		var is_scurk_demolish := Demolish.supports_tool(
			scurk_group, scurk_subtool
		)
		var is_scurk_landscape := Landscapes.supports_tool(
			scurk_group, scurk_subtool
		)
		var is_scurk_network := Networks.supports_tool(
			scurk_group, scurk_subtool
		)
		var is_scurk_highway := Highways.supports_tool(
			scurk_group, scurk_subtool
		)
		var is_scurk_terrain := TerrainTools.supports_tool(
			scurk_group, scurk_subtool
		)
		var selection := "point"
		if is_scurk_zone or is_scurk_demolish:
			selection = "rectangle"
		elif is_scurk_landscape or is_scurk_network or is_scurk_highway or is_scurk_terrain:
			selection = "path"
		map_view.set_edit_enabled(can_edit, selection, 1, is_scurk_landscape)
		_refresh_status_summary()
		if status_label != null:
			status_label.remove_theme_color_override("font_color")
			var tool_name := String(scurk_tool.get("name", "Edit Tool"))
			status_label.text = "SCURK %s" % tool_name
			status_label.set_meta(
				"status_tooltip_text",
				"%s is active in Place & Print. Click or drag on the city. City funds and development gates do not apply."
				% tool_name
			)
			_sync_overflow_tooltip(status_label)
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
	var point_footprint_area := (
		int(Tools.tool(selected_group, selected_subtool).get("area", 1))
		if is_building_tool else 1
	)
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
		point_footprint_area,
		is_landscape_tool,
	)
	_refresh_status_summary()
	if city == null or status_label == null:
		return
	var tool := Tools.tool(selected_group, selected_subtool)
	status_label.remove_theme_color_override("font_color")
	var tool_status_detail := ""
	if not tool_available:
		tool_status_detail = "%s is not available in this city." % tool.name
	elif _is_tool_chooser(selected_group, selected_subtool):
		tool_status_detail = "%s selected. Select an available type from the choice window." % tool.name
	elif is_zone_tool:
		tool_status_detail = "%s selected. Drag on the city map to zone. Use the mouse wheel to zoom and the right or middle button to pan." % tool.name
	elif is_landscape_tool:
		tool_status_detail = "%s selected. Click or drag across eligible city tiles. Hold Shift to Query." % tool.name
	elif is_building_tool:
		tool_status_detail = "%s selected. Click a clear city site to build it." % tool.name
	elif is_network_tool:
		tool_status_detail = "%s selected. Drag between city tiles to build a route." % tool.name
	elif is_hydro_tool:
		tool_status_detail = "Hydroelectric Power Plant selected. Click an unused waterfall tile."
	elif is_subway_to_rail_tool:
		tool_status_detail = "Subway-to-Rail Connection selected. Click beside a rail or subway."
	elif is_onramp_tool:
		tool_status_detail = "On-ramp selected. Click on clear terrain between a highway and a perpendicular road."
	elif is_tunnel_tool:
		tool_status_detail = "Tunnel selected. Click a cardinal slope that faces through a hill."
	elif is_highway_tool:
		tool_status_detail = "Highway selected. Drag between city tiles to build a two-tile-wide route."
	elif is_demolish_tool:
		tool_status_detail = "Demolish selected. Drag a rectangle across eligible city tiles."
	elif is_terrain_tool:
		tool_status_detail = "%s selected. Click or drag across terrain." % tool.name
	elif is_dispatch_tool:
		var available := Dispatch.availability(city)
		var count := 0
		if available.ok:
			count = [available.police, available.fire, available.military][selected_subtool]
		tool_status_detail = "%s selected. Click dry, unlabeled terrain to deploy one of %d available units." % [tool.name, count]
	elif is_sign_tool:
		tool_status_detail = "Place Sign selected. Click a city tile to add, edit, or remove a user sign."
	elif is_query_tool:
		tool_status_detail = "Query selected. Click a city tile to inspect it."
	elif is_center_tool:
		tool_status_detail = "Center View selected. Click a city tile to center the map on it."
	else:
		tool_status_detail = "%s is in the original tool catalog. Its command is not implemented yet." % tool.name
	status_label.text = str(tool.name)
	status_label.set_meta("status_tooltip_text", tool_status_detail)
	_sync_overflow_tooltip(status_label)


func _apply_map_selection(
	start: Vector2i,
	finish: Vector2i,
	path: Array[Vector2i],
	dragged: bool
) -> void:
	if city == null:
		return
	var scurk_tool_mode := (
		scurk_place_print != null
		and scurk_place_print.visible
		and not scurk_place_print.is_object_mode()
	)
	var scurk_tool := (
		scurk_place_print.selected_edit_tool() if scurk_tool_mode else {}
	)
	if scurk_place_print != null and scurk_place_print.visible:
		if scurk_place_print.is_object_mode():
			_apply_scurk_place_selection(finish)
			return
		if scurk_tool.is_empty():
			return
		selected_group = int(scurk_tool.group)
		selected_subtool = int(scurk_tool.subtool)
	if not scurk_tool_mode and not ToolAvailability.is_available(
		city, selected_group, selected_subtool
	):
		_show_error(
			"%s is not available in this city."
			% Tools.tool(selected_group, selected_subtool).name
		)
		return
	if selected_group == 17:
		if map_view.center_on_tile(finish):
			_play_tool_success_sound(17, 0)
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
		_refresh_after_city_edit(dispatch)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Deployed %s unit %d of %d." % [
			Tools.tool(selected_group, selected_subtool).name,
			dispatch.slot_index,
			dispatch.available,
		]
		return
	if Landscapes.supports_tool(selected_group, selected_subtool):
		var landscape := Landscapes.apply_path(
			city,
			selected_group,
			selected_subtool,
			path,
			tool_random,
			scurk_tool_mode
		)
		if not landscape.ok:
			_play_tool_failure_sound(
				selected_group, selected_subtool, str(landscape.error), scurk_tool_mode
			)
			_show_error(
				"Cannot apply %s: %s"
				% [Tools.tool(selected_group, selected_subtool).name, landscape.error]
			)
			return
		_record_edit_command(
			landscape, scurk_tool_mode, String(scurk_tool.get("name", ""))
		)
		_refresh_details()
		_refresh_after_city_edit(landscape)
		_play_tool_success_sound(selected_group, selected_subtool, scurk_tool_mode)
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
			overlay_mode == "underground",
			scurk_tool_mode
		)
		if not demolition.ok:
			_show_error("Cannot demolish: %s" % demolition.error)
			return
		_record_edit_command(
			demolition, scurk_tool_mode, String(scurk_tool.get("name", ""))
		)
		_refresh_details()
		_refresh_after_city_edit(demolition)
		if not scurk_tool_mode:
			_show_effect_events(demolition.effect_events, demolition.sound_events)
		if demolition.easter_events > 0:
			_refresh_saved_news_summary()
			_show_forest_protest()
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Applied %d demolition actions for $%s." % [
			demolition.action_count, _format_number(demolition.cost)
		]
		if demolition.skipped_specialized > 0:
			status_label.text += " %d specialized structures were not changed." % demolition.skipped_specialized
		if demolition.easter_events > 0:
			status_label.text += " A forest protest kept %d %s." % [
				demolition.easter_events,
				"tree" if demolition.easter_events == 1 else "trees",
			]
		return
	if TerrainTools.supports_tool(selected_group, selected_subtool):
		var terrain_change := TerrainTools.apply_path(
			city,
			selected_group,
			selected_subtool,
			start,
			path,
			tool_random,
			scurk_tool_mode
		)
		if not terrain_change.ok:
			_show_error("Cannot change terrain: %s" % terrain_change.error)
			return
		_record_edit_command(
			terrain_change, scurk_tool_mode, String(scurk_tool.get("name", ""))
		)
		_refresh_details()
		_refresh_after_city_edit(terrain_change)
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
		_apply_network_selection(
			start,
			finish,
			Networks.BRIDGE_UNSELECTED,
			selected_group,
			selected_subtool,
			Networks.CONNECTION_UNSELECTED,
			scurk_tool_mode
		)
		return
	if Hydro.supports_tool(selected_group, selected_subtool):
		var hydro := Hydro.apply(city, selected_group, selected_subtool, finish, tool_random)
		if not hydro.ok:
			_play_tool_failure_sound(
				selected_group, selected_subtool, str(hydro.error), scurk_tool_mode
			)
			_show_error("Cannot build hydroelectric power: %s" % hydro.error)
			return
		last_edit_command = hydro
		undo_button.disabled = false
		_refresh_details()
		_refresh_after_city_edit(hydro)
		_play_tool_success_sound(selected_group, selected_subtool, scurk_tool_mode)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built hydroelectric power for $%s." % _format_number(hydro.cost)
		return
	if SubwayToRail.supports_tool(selected_group, selected_subtool):
		var connection := SubwayToRail.apply(city, selected_group, selected_subtool, finish)
		if not connection.ok:
			_play_tool_failure_sound(
				selected_group, selected_subtool, str(connection.error), scurk_tool_mode
			)
			_show_error("Cannot build subway-to-rail connection: %s" % connection.error)
			return
		_record_edit_command(
			connection, scurk_tool_mode, String(scurk_tool.get("name", ""))
		)
		_refresh_after_city_edit(connection)
		_play_tool_success_sound(selected_group, selected_subtool, scurk_tool_mode)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built a subway-to-rail connection at no charge. Listed cost: $%s." % _format_number(connection.listed_cost)
		return
	if Onramps.supports_tool(selected_group, selected_subtool):
		var onramp := Onramps.apply(
			city, selected_group, selected_subtool, finish, scurk_tool_mode
		)
		if not onramp.ok:
			_play_tool_failure_sound(
				selected_group, selected_subtool, str(onramp.error), scurk_tool_mode
			)
			_show_error("Cannot build on-ramp: %s" % onramp.error)
			return
		_record_edit_command(
			onramp, scurk_tool_mode, String(scurk_tool.get("name", ""))
		)
		_refresh_details()
		_refresh_after_city_edit(onramp)
		_play_tool_success_sound(selected_group, selected_subtool, scurk_tool_mode)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built an on-ramp for $%s." % _format_number(onramp.cost)
		return
	if Tunnels.supports_tool(selected_group, selected_subtool):
		_apply_tunnel_selection(finish, Tunnels.CONFIRMATION_UNSELECTED, scurk_tool_mode)
		return
	if Highways.supports_tool(selected_group, selected_subtool):
		_apply_highway_selection(
			start,
			finish,
			Highways.CONNECTION_UNSELECTED,
			Highways.BRIDGE_UNSELECTED,
			scurk_tool_mode
		)
		return
	if Buildings.supports_tool(selected_group, selected_subtool):
		var building_group := selected_group
		var building_subtool := selected_subtool
		var building_name: String = Tools.tool(
			building_group, building_subtool
		).name
		var building := Buildings.apply(
			city,
			building_group,
			building_subtool,
			finish,
			simulation_engine.lfsr_random,
			tool_random
		)
		if not building.ok:
			# A failed placement can still advance the LFSR. Clear undo in that case.
			if building.get("lfsr_advanced", false):
				last_edit_command = {}
				undo_button.disabled = true
			if building.get("resident_objection", false):
				_play_sound_events(building.get("sound_events", []))
				pending_building_objection_group = building_group
				pending_building_objection_subtool = building_subtool
				_show_building_objection()
				status_label.remove_theme_color_override("font_color")
				status_label.text = "%s placement was rejected by nearby residents." % building_name
				return
			_show_error(
				"Cannot build %s: %s"
				% [building_name, building.error]
			)
			_play_tool_failure_sound(
				building_group, building_subtool, str(building.error), scurk_tool_mode
			)
			return
		last_edit_command = building
		undo_button.disabled = false
		_refresh_details()
		_refresh_after_city_edit(building)
		if building_group == 5 and building_subtool < 4:
			_choose_tool_group(17)
		var stadium_team_pending := bool(
			building.get("stadium_team_selection_required", false)
		)
		if building_group == 14 and city.music_enabled() and not stadium_team_pending:
			_play_music_track(Music.RECREATION_TRACK)
		if not stadium_team_pending:
			_play_tool_success_sound(
				building_group, building_subtool, scurk_tool_mode
			)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Built %s for $%s." % [
			building_name,
			_format_number(building.cost),
		]
		if stadium_team_pending:
			_open_stadium_dialog(building)
			status_label.text += " Select a stadium team."
		return
	var command := Zones.apply_rectangle(
		city,
		selected_group,
		selected_subtool,
		start,
		finish,
		dragged,
		scurk_tool_mode,
		int(scurk_tool.get("zone", -1))
	)
	if not command.ok:
		_play_tool_failure_sound(
			selected_group, selected_subtool, str(command.error), scurk_tool_mode
		)
		_show_error("Cannot apply %s: %s" % [Tools.tool(selected_group, selected_subtool).name, command.error])
		return
	_record_edit_command(
		command, scurk_tool_mode, String(scurk_tool.get("name", ""))
	)
	_refresh_details()
	_refresh_after_city_edit(command)
	_play_tool_success_sound(selected_group, selected_subtool, scurk_tool_mode)
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
	subtool_index := -1,
	connection_choice := Networks.CONNECTION_UNSELECTED,
	free_mode := false
) -> void:
	if group_index < 0:
		group_index = selected_group
	if subtool_index < 0:
		subtool_index = selected_subtool
	var tool_name: String = Tools.tool(group_index, subtool_index).name
	var network := Networks.apply(
		city,
		group_index,
		subtool_index,
		start,
		finish,
		bridge_type,
		connection_choice,
		free_mode
	)
	if network.get("bridge_selection_required", false):
		_open_bridge_dialog(
			start,
			finish,
			group_index,
			subtool_index,
			network,
			"network",
			free_mode
		)
		return
	if network.get("cancelled", false):
		_play_tool_failure_sound(group_index, subtool_index, "cancelled", free_mode)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Bridge selection canceled. No action was taken."
		return
	if network.get("connection_selection_required", false):
		pending_network_connection = {
			"start": start,
			"finish": finish,
			"group_index": group_index,
			"subtool_index": subtool_index,
			"bridge_type": bridge_type,
			"free_mode": free_mode,
		}
		network_connection_dialog.dialog_text = (
			(
				"Build a %s connection to a neighboring city?\n"
				+ "The route and connection are free in Place & Print."
			) % tool_name.to_lower()
			if free_mode
			else (
				"Build a %s connection to a neighboring city for $%s?\n"
				+ "The %d-tile route costs $%s and remains if you cancel."
			) % [
				tool_name.to_lower(),
				_format_number(int(network.get("connection_cost", 0))),
				network.get("dry_points", []).size(),
				_format_number(int(network.get("dry_cost", 0))),
			]
		)
		network_connection_dialog.get_cancel_button().text = "Keep %s" % tool_name
		network_connection_dialog.popup_centered()
		return
	if not network.get("ok", false):
		_play_tool_failure_sound(
			group_index,
			subtool_index,
			str(network.get("error", "unknown error")),
			free_mode,
		)
		_show_error(
			"Cannot build %s: %s"
			% [tool_name, network.get("error", "unknown error")]
		)
		return
	_record_edit_command(network, free_mode, tool_name)
	_refresh_details()
	_refresh_after_city_edit(network)
	_play_tool_success_sound(group_index, subtool_index, free_mode)
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
	elif network.get("connection_built", false):
		status_label.text = "Built %d %s tiles and a neighboring-city connection for $%s." % [
			dry_count,
			tool_name,
			_format_number(int(network.get("cost", 0))),
		]
	else:
		status_label.text = "Built %d %s tiles for $%s." % [
			dry_count, tool_name, _format_number(int(network.get("cost", 0)))
		]
		if network.get("bridge_cancelled", false):
			status_label.text += " Bridge selection was canceled."
		elif network.get("connection_cancelled", false):
			status_label.text += " The neighbor connection was canceled."
		elif not String(network.get("bridge_error", "")).is_empty():
			status_label.text += " The bridge was not built: %s." % network.bridge_error
		elif not String(network.get("connection_error", "")).is_empty():
			status_label.text += " The connection was not offered because funds are too low."
		elif network.get("stopped_early", false):
			status_label.text += " The route stopped at an obstruction."


func _confirm_network_connection() -> void:
	_apply_pending_network_connection(Networks.CONNECTION_CONFIRMED)


func _cancel_network_connection() -> void:
	_apply_pending_network_connection(Networks.CONNECTION_CANCELLED)


func _apply_pending_network_connection(connection_choice: int) -> void:
	if pending_network_connection.is_empty():
		return
	var request := pending_network_connection.duplicate()
	pending_network_connection.clear()
	network_connection_dialog.hide()
	selected_group = int(request.group_index)
	selected_subtool = int(request.subtool_index)
	_apply_network_selection(
		request.start,
		request.finish,
		int(request.bridge_type),
		int(request.group_index),
		int(request.subtool_index),
		connection_choice,
		bool(request.get("free_mode", false))
	)


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
	_play_tool_success_sound(14, 3)
	if city.music_enabled():
		_play_music_track(Music.RECREATION_TRACK)
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Assigned %s to the new stadium." % result.team_name


func _cancel_stadium_team() -> void:
	pending_stadium_command.clear()
	_play_tool_success_sound(14, 3)
	if city != null and city.music_enabled():
		_play_music_track(Music.RECREATION_TRACK)
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
	request_type := "network",
	free_mode := false
) -> void:
	pending_bridge_request = {
		"start": start,
		"finish": finish,
		"group_index": group_index,
		"subtool_index": subtool_index,
		"request_type": request_type,
		"free_mode": free_mode,
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
		choice_button.text = (
			"%s\nFree in Place & Print" % choice.get("name", "Bridge")
			if free_mode
			else "%s\n$%s total\n$%s for each %s" % [
				choice.get("name", "Bridge"),
				_format_number(int(choice.get("cost", 0))),
				_format_number(int(choice.get("cost_per_tile", 0))),
				cost_unit,
			]
		)
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
			int(choice.get("type", Highways.BRIDGE_UNSELECTED)),
			bool(request.get("free_mode", false))
		)
		return
	_apply_network_selection(
		request.start,
		request.finish,
		int(choice.get("type", Networks.BRIDGE_UNSELECTED)),
		int(request.group_index),
		int(request.subtool_index),
		Networks.CONNECTION_UNSELECTED,
		bool(request.get("free_mode", false))
	)


func _cancel_bridge() -> void:
	if pending_bridge_request.is_empty():
		return
	var request := pending_bridge_request.duplicate(true)
	pending_bridge_request.clear()
	if request.get("dry_points", []).is_empty():
		_play_tool_failure_sound(
			int(request.group_index),
			int(request.subtool_index),
			"cancelled",
			bool(request.get("free_mode", false)),
		)
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
			Highways.BRIDGE_CANCELLED,
			bool(request.get("free_mode", false))
		)
		return
	_apply_network_selection(
		request.start,
		request.finish,
		Networks.BRIDGE_CANCELLED,
		int(request.group_index),
		int(request.subtool_index),
		Networks.CONNECTION_UNSELECTED,
		bool(request.get("free_mode", false))
	)


func _apply_tunnel_selection(
	start: Vector2i,
	confirmation_choice := Tunnels.CONFIRMATION_UNSELECTED,
	free_mode := false
) -> void:
	var tunnel := Tunnels.apply(
		city,
		selected_group,
		selected_subtool,
		start,
		confirmation_choice,
		free_mode
	)
	if tunnel.get("confirmation_required", false):
		if free_mode:
			_apply_tunnel_selection(
				start, Tunnels.CONFIRMATION_CONFIRMED, true
			)
			return
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
		_play_tool_failure_sound(
			selected_group, selected_subtool, "cancelled", free_mode
		)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Tunnel construction canceled. No action was taken."
		return
	if not tunnel.get("ok", false):
		_play_tool_failure_sound(
			selected_group,
			selected_subtool,
			str(tunnel.get("error", "unknown error")),
			free_mode,
		)
		_show_error("Cannot build tunnel: %s" % tunnel.get("error", "unknown error"))
		return
	_record_edit_command(
		tunnel,
		free_mode,
		String(
			scurk_place_print.selected_edit_tool().get("name", "Tunnel")
			if free_mode and scurk_place_print != null
			else "Tunnel"
		)
	)
	_refresh_details()
	_refresh_after_city_edit(tunnel)
	_play_tool_success_sound(selected_group, selected_subtool, free_mode)
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
	bridge_type := Highways.BRIDGE_UNSELECTED,
	free_mode := false
) -> void:
	var highway := Highways.apply(
		city,
		selected_group,
		selected_subtool,
		start,
		finish,
		connection_choice,
		bridge_type,
		free_mode
	)
	if highway.get("bridge_selection_required", false):
		_open_bridge_dialog(
			start,
			finish,
			selected_group,
			selected_subtool,
			highway,
			"highway",
			free_mode
		)
		return
	if highway.get("cancelled", false):
		_play_tool_failure_sound(
			selected_group, selected_subtool, "cancelled", free_mode
		)
		status_label.remove_theme_color_override("font_color")
		status_label.text = "Bridge selection canceled. No action was taken."
		return
	if highway.get("connection_selection_required", false):
		pending_highway_connection = {
			"start": start,
			"finish": finish,
			"group_index": selected_group,
			"subtool_index": selected_subtool,
			"free_mode": free_mode,
		}
		highway_connection_dialog.dialog_text = (
			(
				"Build a highway connection to a neighboring city?\n"
				+ "The highway and connection are free in Place & Print."
			)
			if free_mode
			else (
				"Build a highway connection to a neighboring city for $%s?\n"
				+ "The %d-section highway costs $%s and remains if you cancel."
			) % [
				_format_number(int(highway.get("connection_cost", 0))),
				highway.get("sections", []).size(),
				_format_number(int(highway.get("route_cost", 0))),
			]
		)
		highway_connection_dialog.popup_centered()
		return
	if not highway.get("ok", false):
		_play_tool_failure_sound(
			selected_group,
			selected_subtool,
			str(highway.get("error", "unknown error")),
			free_mode,
		)
		_show_error("Cannot build highway: %s" % highway.get("error", "unknown error"))
		return
	_record_edit_command(highway, free_mode, "Highway")
	_refresh_details()
	_refresh_after_city_edit(highway)
	_play_tool_success_sound(selected_group, selected_subtool, free_mode)
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
	_apply_highway_selection(
		request.start,
		request.finish,
		connection_choice,
		Highways.BRIDGE_UNSELECTED,
		bool(request.get("free_mode", false))
	)


func _undo_last_edit() -> void:
	if city == null or last_edit_command.is_empty():
		return
	var undone_command := last_edit_command
	var command_type: String = last_edit_command.get("command_type", "")
	if last_edit_command.get("scurk_place_history", false):
		_undo_scurk_place()
		return
	var undo_forest_protest := (
		command_type == "demolish"
		and int(last_edit_command.get("easter_events", 0)) > 0
	)
	var result: Dictionary
	if command_type == "sign":
		result = Signs.undo(city, last_edit_command)
	elif command_type == "landscape":
		result = Landscapes.undo(city, last_edit_command, tool_random)
	elif command_type == "building":
		result = Buildings.undo(
			city, last_edit_command, simulation_engine.lfsr_random, tool_random
		)
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
	_refresh_after_city_edit(undone_command)
	if undo_forest_protest:
		_refresh_saved_news_summary()
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
	_refresh_after_city_edit(result)
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Sign removed." if result.new_overlay == 0 else "Sign saved as label %d." % result.label_id


func _cancel_sign() -> void:
	pending_sign_tile = Vector2i(-1, -1)


func _open_query(point: Vector2i) -> void:
	var result := Queries.inspect(city, point, original_query_strings)
	if not result.ok:
		_show_error("Cannot query tile: %s" % result.error)
		return
	if result.get("overlay_id", 0) == 111 and simulation_engine != null:
		var approval := simulation_engine.recalculate_mayor_house()
		if not approval.get("ok", false):
			_show_error("Cannot calculate mayor approval: %s" % approval.error)
			return
		_show_news_items(approval.news_items)
		result = Queries.inspect(city, point, original_query_strings)
	if (
		result.get("kind", "") == "general"
		and active_scurk_tile_set != null
		and active_scurk_tile_set.names.has(int(result.get("tile_id", -1)))
	):
		result.title = active_scurk_tile_set.names[int(result.tile_id)]
	active_query_result = result
	var is_specific: bool = result.kind == "specific"
	var action := str(result.get("action", ""))
	var action_text := ""
	if not action.is_empty():
		var action_resource_id := int(result.get("action_resource_id", -1))
		var fallback := "Analyze" if action == "city_analysis" else "Ruminate"
		action_text = str(original_query_strings.get(action_resource_id, fallback))
	var sprite_id := int(result.get("sprite_id", -1))
	var tile_caption := (
		"Tile %d  •  Sprite %d" % [result.tile_id, sprite_id]
		if sprite_id >= 0 else "Image unavailable"
	)
	var things: Array = result.get("things", [])
	var thing_texture: Texture2D
	var thing_caption := ""
	if not things.is_empty():
		var thing: Dictionary = things[0]
		var thing_sprite_id := int(thing.get("sprite_id", -1))
		thing_texture = _query_sprite_texture(
			thing_sprite_id, bool(thing.get("sprite_flip", false)), 2
		)
		thing_caption = (
			"XTHG %d  •  %s  •  Sprite %d"
			% [thing.record, thing.type_name, thing_sprite_id]
		)
	query_dialog.show_query(
		str(result.title),
		str(result.title) if is_specific else "",
		is_specific,
		Queries.format_text(result),
		action_text,
		_query_sprite_texture(sprite_id, false, 2),
		tile_caption,
		thing_texture,
		thing_caption,
	)
	_play_sound_events(result.get("sound_events", []))


func _query_sprite_texture(sprite_id: int, flip := false, scale := 2) -> Texture2D:
	if sprite_id < 0 or palette == null:
		return null
	var archive: Sc2SpriteArchive = (
		large_sprites if sprite_id >= 1000 else small_medium_sprites
	)
	if archive == null or not archive.is_valid():
		return null
	var entry := archive.find_sprite(sprite_id)
	if entry == null:
		return null
	var image_result := entry.create_image(palette)
	if not image_result.get("ok", false):
		return null
	var image: Image = image_result.image.duplicate()
	if flip:
		image.flip_x()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _close_query(commit_rename := false) -> bool:
	if query_dialog == null or not query_dialog.visible:
		return true
	if (
		commit_rename
		and query_dialog.rename_is_enabled()
		and active_query_result.get("kind", "") == "specific"
	):
		var renamed := QueryFacilityActions.rename_facility(
			city, active_query_result, query_dialog.facility_name()
		)
		if not renamed.ok:
			_show_error("Cannot rename facility: %s" % renamed.error)
			return false
		active_query_result["title"] = renamed.new_value
	query_dialog.close_query()
	return true


func _run_query_action() -> void:
	if city == null:
		return
	if not _close_query(true):
		return
	match str(active_query_result.get("action", "")):
		"city_analysis":
			var analysis := QueryFacilityActions.city_analysis(
				city, original_query_strings
			)
			if not analysis.ok:
				_show_error("Cannot analyze city: %s" % analysis.error)
				return
			city_analysis_table.clear()
			var root := city_analysis_table.create_item()
			for category in analysis.categories:
				var item := city_analysis_table.create_item(root)
				item.set_text(0, str(category.name))
				item.set_text(1, str(category.acres))
				item.set_text(2, "%d%%" % category.percent)
				item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
				item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
			city_analysis_dialog.popup_centered()
		"library_ruminate":
			if library_texts.size() != LIBRARY_TEXT_IDS.size():
				_show_error("The Library text resources are missing or invalid.")
				return
			var window_rects := LibraryWindowLayout.rects(
				Vector2i(get_viewport_rect().size), LIBRARY_TEXT_IDS.size()
			)
			for index in LIBRARY_TEXT_IDS.size():
				var resource_id: int = LIBRARY_TEXT_IDS[index]
				library_text_views[index].text = (
					str(library_texts[resource_id])
					.replace("\r\n", "\n")
					.replace("\r", "\n")
				)
				library_text_views[index].scroll_vertical = 0
				library_windows[index].position = window_rects[index].position
				library_windows[index].size = window_rects[index].size
				_bring_library_window_to_front(library_windows[index])
				library_windows[index].show()


func _on_library_window_input(event: InputEvent, window: PanelContainer) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_bring_library_window_to_front(window)


func _bring_library_window_to_front(window: PanelContainer) -> void:
	for other in library_windows:
		if other != window and other.z_index > 1000:
			other.z_index -= 1
	window.z_index = 1000 + library_windows.size()


func _refresh_details() -> void:
	if city == null:
		return
	_sync_city_option_menus()
	if graph_control != null and graph_window != null and graph_window.visible:
		graph_control.set_city(city)
	if (
		population_control != null
		and population_window != null
		and population_window.visible
	):
		population_control.set_city(city)
	if industry_control != null and industry_window != null and industry_window.visible:
		industry_control.set_city(city)
	if simnation_control != null and simnation_window != null and simnation_window.visible:
		simnation_control.set_city(city)
	if ordinance_control != null and ordinance_window != null and ordinance_window.visible:
		ordinance_control.refresh()
	if city_map_control != null and city_map_window != null and city_map_window.visible:
		city_map_control.set_city(city, palette)
		city_map_control.refresh_viewport(_city_map_viewport_outline())
	var demand := city.rci_demand()
	var weather_trend := city.document.misc_u32(RciAftermath.MISC_WEATHER_TREND) & 0xff
	var weather_name: String = (
		RciAftermath.WEATHER_NAMES[weather_trend]
		if weather_trend < RciAftermath.WEATHER_NAMES.size()
		else "Unknown"
	)
	title_stats_label.text = "%02d/%02d/%04d" % [
		city.current_month(),
		city.current_day(),
		city.current_year(),
	]
	title_money_label.text = "$%s" % _format_number(city.funds())
	title_stats_label.tooltip_text = "Current city date: %s" % title_stats_label.text
	title_money_label.tooltip_text = "Current city funds: %s" % title_money_label.text
	_refresh_status_summary(demand, weather_name)
	if _refresh_tool_availability():
		_update_edit_state()


func _refresh_status_summary(
	demand := Vector3i(0, 0, 0), weather_name := ""
) -> void:
	if (
		status_population_label == null
		or status_weather_label == null
		or status_rci_graph == null
		or status_reports_label == null
		or status_speed_label == null
	):
		return
	if city == null:
		status_population_label.text = "Population: --"
		status_population_label.set_meta(
			"status_tooltip_text", "Current city population is not available."
		)
		status_weather_label.text = "Weather: --"
		status_rci_graph.clear_demand()
	else:
		if weather_name.is_empty():
			var weather_trend := city.document.misc_u32(
				RciAftermath.MISC_WEATHER_TREND
			) & 0xff
			weather_name = (
				RciAftermath.WEATHER_NAMES[weather_trend]
				if weather_trend < RciAftermath.WEATHER_NAMES.size()
				else "Unknown"
			)
			demand = city.rci_demand()
		status_population_label.text = "Population: %s" % _format_number(city.population())
		status_population_label.set_meta(
			"status_tooltip_text",
			"Current city population: %s" % _format_number(city.population()),
		)
		status_weather_label.text = "Weather: %s" % weather_name
		status_rci_graph.set_demand(demand)
	_refresh_status_report_text()
	_sync_speed_ui()
	_refresh_status_tooltips()


func _update_status_report_rotation(delta: float) -> void:
	if status_reports_label == null or delta <= 0.0 or recent_news.size() < 2:
		return
	status_report_elapsed_seconds += delta
	if status_report_elapsed_seconds < STATUS_REPORT_ROTATION_SECONDS:
		return
	var steps := floori(
		status_report_elapsed_seconds / STATUS_REPORT_ROTATION_SECONDS
	)
	status_report_elapsed_seconds = fmod(
		status_report_elapsed_seconds, STATUS_REPORT_ROTATION_SECONDS
	)
	status_report_index = posmod(status_report_index + steps, recent_news.size())
	_refresh_status_report_text()
	_sync_overflow_tooltip(status_reports_label)


func _refresh_status_report_text() -> void:
	if status_reports_label == null:
		return
	var current_report := "None"
	if not recent_news.is_empty():
		status_report_index = posmod(status_report_index, recent_news.size())
		current_report = recent_news[status_report_index]
	else:
		status_report_index = 0
		status_report_elapsed_seconds = 0.0
	status_reports_label.text = "News: %s" % current_report
	status_reports_label.set_meta(
		"status_tooltip_text",
		(
			"Recent city reports. These are the newest saved newspaper records.\n%s"
			% ("No reports." if recent_news.is_empty() else "\n".join(recent_news))
		),
	)


func _refresh_status_tooltips() -> void:
	_sync_overflow_tooltip(status_label)
	_sync_overflow_tooltip(status_population_label)
	_sync_overflow_tooltip(status_weather_label)
	_sync_overflow_tooltip(status_reports_label)
	_sync_overflow_tooltip(status_speed_label)


func _sync_overflow_tooltip(label: Label) -> void:
	if label == null:
		return
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	if (
		bool(label.get_meta("always_status_tooltip", false))
		or text_width > maxf(0.0, label.size.x - 4.0)
	):
		label.tooltip_text = str(label.get_meta("status_tooltip_text", label.text))
	else:
		label.tooltip_text = ""


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("ff877d"))


func _debug_metrics() -> Dictionary:
	var result := {
		"city_name": "None",
		"date": "--",
		"population": "--",
		"funds": "--",
		"speed": speed_controller.speed_name() if speed_controller != null else "--",
		"speed_id": speed_controller.speed if speed_controller != null else 1,
		"speed_accumulator_msec": (
			speed_controller.accumulator_msec if speed_controller != null else 0.0
		),
		"tool": "--",
		"view": overlay_mode,
		"unsaved": _city_has_unsaved_changes(),
		"static_render": "running" if static_render_thread != null else "idle",
		"render_pending": pending_static_render,
		"static_cache": static_view_cache.size(),
		"dynamic_cache": dynamic_visual_cache.size(),
		"foreground_cache": dynamic_foreground_cache.size(),
		"active_disaster": (
			_disaster_name(simulation_engine.active_disaster_type)
			if simulation_engine != null
			else "None"
		),
		"active_disaster_id": (
			simulation_engine.active_disaster_type if simulation_engine != null else 0
		),
		"no_disasters": city != null and city.no_disasters_enabled(),
		"wave_sound_id": wave_sound_gate.current_sound_id,
		"wave_sound_ticks": wave_sound_gate.remaining_ticks,
		"wave_sound_accepted": wave_sound_gate.accepted_count,
		"wave_sound_suppressed": wave_sound_gate.suppressed_count,
		"wave_stream_cache": wave_stream_cache.size(),
	}
	if map_view != null:
		result.merge(map_view.debug_metrics(), true)
	if city != null:
		result.city_name = city.city_name()
		result.date = "%02d/%02d/%04d" % [
			city.current_month(), city.current_day(), city.current_year(),
		]
		result.population = _format_number(city.population())
		result.funds = "$%s" % _format_number(city.funds())
		result.tool = str(Tools.tool(selected_group, selected_subtool).name)
	return result


func _debug_center_map() -> void:
	if map_view != null and city != null:
		map_view.center_on_tile(Vector2i(CityState.MAP_SIZE / 2, CityState.MAP_SIZE / 2))


func _debug_full_redraw() -> void:
	if city == null:
		return
	_invalidate_view_render()
	_refresh_map(true)


func _debug_clear_render_caches() -> void:
	static_view_cache.clear()
	dynamic_sprite_cache.clear()
	dynamic_foreground_cache.clear()
	dynamic_occluder_cache.clear()
	dynamic_visual_cache.clear()
	dynamic_special_batch_cache.clear()
	_debug_full_redraw()


func _debug_add_funds(amount: int) -> Dictionary:
	var result := DebugActions.add_funds(city, amount)
	if not result.ok:
		return {"ok": false, "message": result.error}
	_refresh_details()
	return {
		"ok": true,
		"message": "Added $%s. Funds are now $%s."
		% [_format_number(amount), _format_number(int(result.new_funds))],
	}


func _debug_unlock_everything() -> Dictionary:
	var result := DebugActions.unlock_everything(city, current_document)
	if not result.ok:
		return {"ok": false, "message": result.error}
	_refresh_child_tool_icons()
	_refresh_tool_availability()
	_update_edit_state()
	_refresh_details()
	return {
		"ok": true,
		"message": "Unlocked all inventions, rewards, arcologies, and power plants.",
	}


func _debug_set_no_disasters(enabled: bool) -> Dictionary:
	var result := DebugActions.set_no_disasters(city, enabled)
	if not result.ok:
		return {"ok": false, "message": result.error}
	_sync_city_option_menus()
	_refresh_details()
	return {
		"ok": true,
		"message": "Random disasters are %s." % ("disabled" if enabled else "enabled"),
	}


func _debug_start_disaster(disaster_type: int) -> Dictionary:
	if disaster_type < DisasterStart.DISASTER_FIRE or disaster_type > DisasterStart.DISASTER_PLANE_CRASH:
		return {"ok": false, "message": "The disaster selection is not valid."}
	var result := _start_disaster_at_view_center(disaster_type)
	if not result.get("ok", false):
		return {
			"ok": false,
			"message": "The %s could not start: %s"
			% [_disaster_name(disaster_type), result.get("error", "unknown error")],
		}
	return {
		"ok": true,
		"message": "%s started at the current view center." % _disaster_name(disaster_type),
	}


func _debug_end_disaster() -> Dictionary:
	var result := DebugActions.end_disaster(city, current_document, simulation_engine)
	if not result.ok:
		return {"ok": false, "message": result.error}
	last_edit_command = {}
	undo_button.disabled = true
	simulation_map_dirty = false
	_refresh_map(false)
	_refresh_moving_things()
	_refresh_details()
	return {
		"ok": true,
		"message": "Ended %s and cleared %d marker(s) and %d object(s)."
		% [
			(
				_disaster_name(int(result.active_type))
				if int(result.active_type) != 0
				else "the disaster"
			),
			int(result.cleared_markers),
			int(result.cleared_objects),
		],
	}


func _debug_dispatch_maxis_man() -> Dictionary:
	var center := map_view.center_tile() if map_view != null else Vector2i(64, 64)
	var result := DebugActions.dispatch_maxis_man(city, current_document, center)
	if not result.ok:
		return {"ok": false, "message": result.error}
	_refresh_moving_things()
	return {
		"ok": true,
		"message": "Maxis Man was dispatched from %s toward %s."
		% [str(result.start), str(result.target)],
	}


func _format_number(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var output := ""
	while digits.length() > 3:
		output = "," + digits.right(3) + output
		digits = digits.left(digits.length() - 3)
	output = digits + output
	return "-" + output if negative else output
