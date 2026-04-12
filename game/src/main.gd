extends Control

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityFiles = preload("res://src/formats/city_file_store.gd")
const CityModel = preload("res://src/model/city_state.gd")
const NewTerrain = preload("res://src/model/new_city_terrain.gd")
const NewCitySession = preload("res://src/model/new_city_terrain_session.gd")
const ScenarioModel = preload("res://src/model/scenario_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const OriginalInstaller = preload("res://src/assets/original_game_installer.gd")
const ScurkTileSet = preload("res://src/assets/scurk_mif.gd")
const ScurkCityOutput = preload("res://src/assets/scurk_city_output.gd")
const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const RenderJob = preload("res://src/view/city_render_job.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")
const MapControl = preload("res://src/view/city_map_control.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")
const CityMapView = preload("res://src/view/city_map_window_control.gd")
const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const ToolState = preload("res://src/tools/shared/tool_edit_state.gd")
const SimpleEdits = preload("res://src/tools/shared/simple_edit_flow.gd")
const Zones = preload("res://src/tools/city/zone_command.gd")
const Signs = preload("res://src/tools/city/sign_command.gd")
const Queries = preload("res://src/tools/city/query_info.gd")
const QueryFacilityActions = preload("res://src/tools/city/query_actions.gd")
const SettingsStore = preload("res://src/ui/settings/app_settings_store.gd")
const LibraryRuminateWindowsView = preload("res://src/ui/city_windows/library_ruminate_windows.gd")
const DisplayNumbers = preload("res://src/ui/shared/display_number_format.gd")
const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")
const CityMenuBarView = preload("res://src/ui/shell/city_menu_bar.gd")
const CityWorkspaceView = preload("res://src/ui/shell/city_workspace.tscn")
const CityDialogsView = preload("res://src/ui/shell/city_dialog_registry.gd")
const MainOverlaysView = preload("res://src/ui/shell/main_overlay_registry.gd")
const Landscapes = preload("res://src/tools/landscape/landscape_command.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const ToolSounds = preload("res://src/audio/tool_sound_rules.gd")
const CityAudio = preload("res://src/audio/city_audio_controller.gd")
const Networks = preload("res://src/tools/city/network_command.gd")
const Hydro = preload("res://src/tools/city/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/city/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/city/onramp_command.gd")
const Tunnels = preload("res://src/tools/city/tunnel_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")
const Dispatch = preload("res://src/tools/city/dispatch_command.gd")
const ScurkPlace = preload("res://src/tools/scurk/scurk_place_command.gd")
const ScurkHistory = preload("res://src/tools/scurk/scurk_edit_history.gd")
const CityRotation = preload("res://src/tools/city/city_rotation_command.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const Bonds = preload("res://src/simulation/economy/bond_command.gd")
const RciAftermath = preload("res://src/simulation/growth/rci_aftermath_phase.gd")
const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const Music = preload("res://src/audio/music_director.gd")
const DebugOverlayView = preload("res://src/debug/debug_overlay.tscn")
const DebugActions = preload("res://src/debug/city_debug_actions.gd")

const MAP_DISPLAY_MODES := ["city", "underground", "land_value", "pollution", "crime", "water", "power", "height"]
const ACTIVE_DISASTER_RENDER_INTERVAL_MSEC := 1200
const STATIC_EDIT_PATCH_MAX_AREA_RATIO := 0.25
const MENU_AUTO_BUDGET := CityMenuBarView.MENU_AUTO_BUDGET
const MENU_AUTO_GOTO := CityMenuBarView.MENU_AUTO_GOTO
const MENU_SOUND_EFFECTS := CityMenuBarView.MENU_SOUND_EFFECTS
const MENU_MUSIC := CityMenuBarView.MENU_MUSIC
const MENU_NO_DISASTERS := CityMenuBarView.MENU_NO_DISASTERS
const MENU_VIEW_CITY_MAP := CityMenuBarView.MENU_VIEW_CITY_MAP
const MENU_VIEW_BUILDINGS := CityMenuBarView.MENU_VIEW_BUILDINGS
const MENU_VIEW_NETWORKS := CityMenuBarView.MENU_VIEW_NETWORKS
const MENU_VIEW_WATER := CityMenuBarView.MENU_VIEW_WATER
const MENU_VIEW_TREES := CityMenuBarView.MENU_VIEW_TREES
const MENU_VIEW_ZONES := CityMenuBarView.MENU_VIEW_ZONES
const MENU_VIEW_SIGNS := CityMenuBarView.MENU_VIEW_SIGNS
const MENU_VIEW_PIPES := CityMenuBarView.MENU_VIEW_PIPES
const MENU_SCURK_PLACE_PRINT := CityMenuBarView.MENU_SCURK_PLACE_PRINT

var city: CityState
var current_document: Sc2File
var saved_city_snapshot := PackedByteArray()
var current_save_path := ""
var current_city_saved_once := false
var palette: Sc2Palette
var scenario_palette: Sc2Palette
var scenario_graphics: ScenarioGraphics
var scurk_graphics: ScurkGraphics
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
var show_underground_subways := true
var app_soundtrack_folder := ""
var app_toolbar_sounds := true
var app_sound_pack_folder := ""
var app_music_pack_folder := ""
var app_city_renderer := "gpu"
var app_ui_theme := "light"
var app_dark_underground := false
var app_default_mayor_name := "Mayor"
var app_overview_graphics := 0
var app_zoom_graphics: Array[int] = SettingsStore.normalize_zoom_graphics(SettingsStore.DEFAULT_ZOOM_GRAPHICS)
var app_background_audio := false
var app_shuffle_music := false
var app_original_compatibility := false
var app_warn_sc2x_conversion := true
var sc2x_conversion_dialog: ConfirmationDialog
var pending_sc2x_document: Sc2File
var app_settings_path := SettingsStore.SETTINGS_PATH
var app_music_volume := 0.8
var app_effects_volume := 0.8
var app_fullscreen := false
var app_graphics_source := "auto"
var app_graphics_folder := ""
var asset_source: GameAssetSource
var reference_root := ""
var runtime_initialized := false
var assets_ready := false
var reference_import_dialog: FileDialog
var reference_import_error_dialog: AcceptDialog
var graphics_source_error_dialog: AcceptDialog
var original_query_strings: Dictionary = {}
var forest_protest_text := "Citizens are protesting forest demolition."
var building_objection_text := "Residents objected to this facility site."
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
var audio_controller: Node
var dispatch_cycles := PackedInt32Array([0, 0, 0])
var dispatch_initialized := false
var simulation_engine: SimulationEngine
var speed_controller: GameSpeedController
var frame_simulation: FrameSimulationRunner
var simulation_map_dirty := false
var annual_budget_pending := false
var military_proposal_pending := false
var game_over_active := false
var edit_display_timings := {}
var region_cache: CityRegionCache
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
var dynamic_command_cache := CityDynamicCommandCache.new()
var foreground_view_rect := Rect2()
var foreground_complete := false
var sign_foreground_cache: Dictionary = {}
var dynamic_special_batch_cache: Dictionary = {}
var dynamic_sign_occluders: Array[Dictionary] = []
var dynamic_sign_occlusion_grid: Dictionary = {}
var static_render_thread: Thread
var static_render_job: CityRenderJob
var static_render_epoch := 0
var last_static_render_started_msec := -ACTIVE_DISASTER_RENDER_INTERVAL_MSEC
var pending_static_render := false
var toolbar_animation_palette: Sc2Palette
var palette_cycle_ticks := 0
var palette_elapsed_msec := 0.0
var palette_cycle_texture: ImageTexture

var map_view: CityMapControl
var city_workspace: CityWorkspace
var city_menu_bar: CityMenuBar
var status_label: Label
var network_preview: NetworkPlacementPreview
var city_status_bar: CityStatusBar
var city_dialogs: CityDialogRegistry
var main_overlays: MainOverlayRegistry
var file_dialog: FileDialog
var save_dialog: FileDialog
var tile_set_dialog: FileDialog
var scurk_city_export_dialog: FileDialog
var scurk_print_pdf_dialog: FileDialog
var new_city_dialog: NewCityTerrainDialog
var new_city_session := NewCitySession.new()
var new_city_return_to_main_menu := false
var landscape_editor := false
var terrain_stretch := TerrainStretchSession.new()
var founding_newspaper_pending := false
var options_menu: MenuButton
var speed_menu: MenuButton
var view_menu: MenuButton
var view_menu_underground_items := false
var disasters_menu: MenuButton
var view_visibility_checks: Dictionary = {}
var view_layers_heading: Label
var city_toolbar: CityToolbar
var zoom_in_button: Button
var zoom_out_button: Button
var rotate_counter_clockwise_button: Button
var rotate_clockwise_button: Button
var sign_dialog: CitySignDialog
var bridge_dialog: BridgeSelectionDialog
var pending_bridge_request: Dictionary = {}
var tool_choice_dialog: ToolChoiceDialog
var pending_tool_choices: Dictionary = {}
var stadium_dialog: StadiumTeamDialog
var pending_stadium_command: Dictionary = {}
var network_connection_dialog: RouteConfirmationDialog
var pending_network_connection: Dictionary = {}
var highway_connection_dialog: RouteConfirmationDialog
var pending_highway_connection: Dictionary = {}
var tunnel_dialog: RouteConfirmationDialog
var pending_tunnel_request: Dictionary = {}
var camera_tap := Vector2.ZERO
var camera_motion := preload("res://src/view/city_camera_motion.gd").new()
var query_dialog: CityQueryDialog
var active_query_result: Dictionary = {}
var city_analysis_dialog: CityAnalysisDialog
var newspaper_dialog: NewspaperDialog
var forest_protest_dialog: PictureNoticeDialog
var building_objection_dialog: PictureNoticeDialog
var pending_building_objection_group := -1
var pending_building_objection_subtool := -1
var library_ruminate_windows: LibraryRuminateWindows
var graph_window
var population_window
var industry_window
var simnation_window
var ordinance_window
var city_map_window
var main_menu: MainMenuControl
var settings_dialog
var scurk_editor: ScurkEditorControl
var desktop_presentation: CityDesktopPresentation
var scurk_place_print: ScurkPlacePrintControl
var scurk_print: ScurkPrintControl
var pending_scurk_print_options: Dictionary = {}
var scurk_edit_history := ScurkHistory.new()
var about_dialog: AboutDialog
var save_changes_dialog: SaveChangesDialog
var pending_city_exit_action := ""
var pending_city_exit_path := ""
var pending_city_exit_waiting_for_save := false
var budget_dialog: BudgetDialog
var game_over_dialog: AcceptDialog
var military_dialog: ConfirmationDialog
var scenario_dialog: ScenarioIntroDialog
var fps_update_seconds := 0.0
var simulation_timings := SimulationTimingHistory.new()
var debug_overlay: CityDebugOverlay


func _ready() -> void:
	add_child(preload("res://src/ui/shared/file_dialog_history.gd").new())
	get_tree().auto_accept_quit = false

	if reference_root.is_empty():
		reference_root = GameAssetSource.default_reference_root()

	_load_app_settings()
	_build_reference_import_dialogs()
	_initialize_runtime()


func _initialize_runtime() -> void:
	if runtime_initialized:
		return

	var mode := OS.get_environment("OPENSC2K_ASSET_SOURCE")

	if mode.is_empty():
		mode = app_graphics_source

	asset_source = GameAssetSource.load_source(
		reference_root, mode, app_graphics_folder, OS.get_environment("OPENSC2K_GRAPHICS_PACK")
	)
	assets_ready = asset_source.error.is_empty()

	if assets_ready:
		reference_root = asset_source.reference_root
	else:
		asset_source.assets = OriginalGameAssets.new()
		asset_source.use_original_data = false

	runtime_initialized = true
	new_city_session.independent_template = not asset_source.use_original_data
	audio_controller = CityAudio.new()
	audio_controller.startup_theme_pending = true
	audio_controller.background_audio = app_background_audio
	audio_controller.set_shuffle_music(app_shuffle_music)
	audio_controller.music_activity_changed.connect(_on_music_activity_changed)
	audio_controller.music_notice.connect(func(message: String) -> void:
		if city_status_bar != null:
			city_status_bar.show_music_notice(message)
	)
	add_child(audio_controller)
	audio_controller.setup(
		reference_root, app_music_volume, app_effects_volume, asset_source.use_original_data
	)

	if assets_ready:
		audio_controller.set_media_packs(app_sound_pack_folder, app_music_pack_folder)
		audio_controller.set_soundtrack_folder(app_soundtrack_folder)

	newspaper_session_seed = Time.get_ticks_msec() & 0xffff

	if newspaper_session_seed & 0x8000:
		newspaper_session_seed -= 0x10000

	tool_random = Random.new(newspaper_session_seed)
	newspaper_session_state.resize(NewsQueue.MISC_SIZE)
	newspaper_session_state.fill(0)
	NewsQueue.initialize_session(newspaper_session_state, tool_random)
	var original_assets := asset_source.assets
	newspaper_data = original_assets.newspaper_data
	original_query_strings = original_assets.strings
	forest_protest_text = original_assets.forest_protest_text
	building_objection_text = original_assets.building_objection_text
	library_texts = original_assets.library_texts
	scurk_graphics = original_assets.scurk_graphics
	_build_interface(original_assets)
	_apply_compatibility_controls()
	desktop_presentation = CityDesktopPresentation.new()
	desktop_presentation.map_view = map_view
	desktop_presentation.editor = scurk_editor
	desktop_presentation.place_print = scurk_place_print
	desktop_presentation.print_dialog = scurk_print
	add_child(desktop_presentation)
	desktop_presentation.set_graphics(original_assets.desktop_graphics)
	debug_overlay = DebugOverlayView.instantiate()
	debug_overlay.setup(self)
	add_child(debug_overlay)

	if not original_assets.error.is_empty():
		_show_error(original_assets.error)

		return

	palette = original_assets.palette
	scenario_palette = original_assets.scenario_palette
	scenario_graphics = original_assets.scenario_graphics
	palette_index_encoding = Palette.index_encoding()
	_update_palette_cycle_texture()
	base_large_sprites = original_assets.large_sprites
	base_small_medium_sprites = original_assets.small_medium_sprites
	large_sprites = base_large_sprites
	small_medium_sprites = base_small_medium_sprites
	_refresh_child_tool_icons()

	_show_main_menu()



func _build_reference_import_dialogs() -> void:
	graphics_source_error_dialog = AcceptDialog.new()
	graphics_source_error_dialog.title = "Graphics source"
	graphics_source_error_dialog.exclusive = true
	add_child(graphics_source_error_dialog)
	reference_import_dialog = FileDialog.new()
	reference_import_dialog.title = "Select the original SimCity 2000 SIMCITY.EXE"
	reference_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	reference_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	reference_import_dialog.filters = PackedStringArray([
		"*.EXE,*.exe ; SimCity 2000 executable",
	])
	reference_import_dialog.exclusive = true
	reference_import_dialog.file_selected.connect(_import_original_game)
	reference_import_dialog.canceled.connect(_on_reference_import_canceled)
	add_child(reference_import_dialog)

	reference_import_error_dialog = AcceptDialog.new()
	reference_import_error_dialog.title = "Cannot import SimCity 2000"
	reference_import_error_dialog.exclusive = true
	reference_import_error_dialog.confirmed.connect(_show_reference_import_dialog)
	add_child(reference_import_error_dialog)

	for dialog in [graphics_source_error_dialog, reference_import_dialog, reference_import_error_dialog]:
		dialog.theme = AppUiTheme.file_dialog() if dialog is FileDialog else ClassicUiStyle.create_dialog_theme()


func _show_graphics_source_error(message: String) -> void:
	graphics_source_error_dialog.dialog_text = message
	graphics_source_error_dialog.call_deferred("popup_centered", Vector2i(620, 220))


func _show_reference_import_dialog() -> void:
	if reference_import_dialog == null:
		return

	reference_import_dialog.popup_centered_ratio(0.8)


func _on_reference_import_canceled() -> void:
	if settings_dialog != null:
		_open_import_settings()


func _show_reference_import_error(message: String) -> void:
	if reference_import_error_dialog == null:
		return

	reference_import_error_dialog.dialog_text = message
	reference_import_error_dialog.popup_centered(Vector2i(640, 260))


func _import_original_game(executable_path: String) -> void:
	var install_result := OriginalPackImporter.import_executable(
		executable_path, ProjectSettings.globalize_path("user://packs"), ProjectSettings.globalize_path("user://")
	)

	if not install_result.ok:
		_show_reference_import_error(install_result.error)

		return

	var selected := GameAssetSource.load_source(install_result.root, "folder", install_result.graphics)

	if not selected.error.is_empty():
		_show_reference_import_error(selected.error)

		return

	reference_import_dialog.hide()
	reference_import_error_dialog.hide()
	app_graphics_source = "folder"
	app_graphics_folder = install_result.graphics
	app_sound_pack_folder = install_result.sound
	app_music_pack_folder = install_result.music
	app_soundtrack_folder = ""
	_apply_graphics_source(selected)
	audio_controller.set_media_packs(app_sound_pack_folder, app_music_pack_folder)
	audio_controller.set_soundtrack_folder("")
	var saved := SettingsStore.save_values(
		app_music_volume, app_effects_volume, app_fullscreen,
		app_settings_path, app_graphics_source, app_graphics_folder, app_soundtrack_folder, app_city_renderer, app_background_audio, app_zoom_graphics, app_toolbar_sounds, app_sound_pack_folder, app_music_pack_folder, app_shuffle_music, app_original_compatibility, app_warn_sc2x_conversion, app_default_mayor_name, app_overview_graphics, app_ui_theme, app_dark_underground,
	)
	_open_import_settings()
	status_label.text = "Packs active. Imported %d cities and %d scenarios." % [install_result.cities, install_result.scenarios]

	if saved != OK:
		_show_error("Packs imported, but their preferences could not be saved.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		_request_city_exit("quit")
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_handle_application_focus_out()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_handle_application_focus_in()


func _process(delta: float) -> void:
	_update_network_preview()
	_update_keyboard_camera(delta)

	if audio_controller != null:
		audio_controller.set_menu_music(
			assets_ready and main_menu != null and main_menu.visible and app_music_volume > 0.0
			and (city == null or city.music_enabled())
		)
		audio_controller.advance(delta * 1000.0)

	_update_fps(delta)

	if city_status_bar != null:
		city_status_bar.update_report_rotation(delta)

	_poll_static_render()
	_start_pending_static_render()

	if speed_controller == null or city == null:
		return

	simulation_engine.midi_playback_active = _music_playback_is_active()
	var interaction_suspended: bool = (
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
		or (sc2x_conversion_dialog != null and sc2x_conversion_dialog.visible)
		or (settings_dialog != null and settings_dialog.visible)
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
		or landscape_editor
		or founding_newspaper_pending
	)
	var result: Dictionary

	if frame_simulation != null:
		frame_simulation.budget_usec = FrameSimulationRunner.budget_for_frame(delta)
		result = frame_simulation.advance_time(delta * 1000.0, Time.get_ticks_msec(), interaction_suspended)
	else:
		result = speed_controller.advance_time(delta * 1000.0, Time.get_ticks_msec(), interaction_suspended)

	if not result.ok:
		speed_controller.set_speed(GameSpeed.Speed.PAUSED)
		_sync_speed_ui()
		_show_error("Simulation stopped: %s" % result.error)

		return

	_advance_palette_animation(delta, interaction_suspended)

	_consume_simulation_result(result)


func _advance_palette_animation(delta: float, suspended: bool) -> void:
	# Keep palette animation running while the simulation worker is busy.
	if suspended or speed_controller.speed == GameSpeed.Speed.PAUSED:
		return

	palette_elapsed_msec += maxf(delta, 0.0) * 1000.0
	var ticks := int(palette_elapsed_msec / GameSpeedController.BASE_TICK_MSEC)

	if ticks > 0:
		palette_elapsed_msec -= ticks * GameSpeedController.BASE_TICK_MSEC
		palette_cycle_ticks += ticks
		_update_palette_cycle_texture()


func _camera_keys_allowed() -> bool:
	if city == null or map_view == null or not map_view.is_visible_in_tree() or not DisplayServer.window_is_focused():
		return false

	var focus := get_viewport().gui_get_focus_owner()

	if focus is LineEdit or focus is TextEdit:
		return false

	for overlay in [main_menu, new_city_dialog, query_dialog, scurk_editor, scurk_place_print, scurk_print, settings_dialog, save_changes_dialog]:
		if overlay != null and overlay.visible:
			return false

	if city_dialogs != null:
		for dialog in city_dialogs.find_children("*", "Window", true, false):
			if dialog is Window and dialog.visible:
				return false

			if dialog is Control and dialog.visible and dialog.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				return false

	for window in get_viewport().get_embedded_subwindows():
		if window.visible:
			return false

	return true


func _update_keyboard_camera(delta: float) -> void:
	var enabled := _camera_keys_allowed()
	var direction := Vector2.ZERO
	enabled = enabled and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META) and not Input.is_key_pressed(KEY_ALT)

	if enabled:
		direction = camera_motion.held_direction()

	if direction.is_zero_approx():
		direction = camera_tap

	camera_tap = Vector2.ZERO

	if map_view != null:
		map_view.pan_screen(camera_motion.step(direction, delta, enabled and not map_view.is_panning() and not map_view.is_left_drag_active()))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and audio_controller != null:
		if audio_controller.handle_media_key(event.keycode):
			get_viewport().set_input_as_handled()

			return

	# A focused control can consume the release event. Stop camera movement anyway.
	if event is InputEventKey and not event.pressed:
		camera_motion.release(event.physical_keycode)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or map_view == null:
		return

	if _camera_keys_allowed() and not event.is_command_or_control_pressed() and not event.alt_pressed:
		var directions := {KEY_W: Vector2.UP, KEY_A: Vector2.LEFT, KEY_S: Vector2.DOWN, KEY_D: Vector2.RIGHT}

		if directions.has(event.physical_keycode):
			camera_motion.press(event.physical_keycode)
			camera_tap += directions[event.physical_keycode]
			get_viewport().set_input_as_handled()

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
	elif event.keycode == KEY_Z and event.is_command_or_control_pressed():
		_undo_last_edit()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and map_view != null and (map_view.trip_reach != null or map_view.service_query != null):
		map_view.clear_trip_reach()
		map_view.clear_service_query()
		get_viewport().set_input_as_handled()
	elif _camera_keys_allowed() and not event.is_command_or_control_pressed() and not event.alt_pressed and (event.keycode == KEY_PLUS or event.keycode == KEY_EQUAL or event.physical_keycode == KEY_E):
		if map_view.zoom_in():
			get_viewport().set_input_as_handled()
	elif _camera_keys_allowed() and not event.is_command_or_control_pressed() and not event.alt_pressed and (event.keycode == KEY_MINUS or event.physical_keycode == KEY_Q):
		if map_view.zoom_out():
			get_viewport().set_input_as_handled()


func _consume_simulation_result(result: Dictionary) -> void:
	simulation_timings.consume(result)
	var refresh_started := Time.get_ticks_usec()
	var ran_days: bool = not result.day_results.is_empty()
	var changed_disaster_map := false

	for disaster in result.disaster_results:
		if disaster.get("map_changed", false):
			changed_disaster_map = true
			break

	var moved_things := _moving_things_are_active(result.moving_results)

	if ran_days or moved_things or changed_disaster_map:
		last_edit_command = {}
		scurk_edit_history.clear()
		# sc2x data-map updates do not change the surface or underground artwork
		var data_maps_only: bool = (city.document.full_resolution_maps() and result.day_results.size() == 1
			and int(result.day_results[0].get("day", -1)) % 25 == 2
			and result.day_results[0].get("phase_results", {}).keys() == ["pollution_terrain_land_value"]
			and result.effect_events.is_empty() and result.view_center_requests.is_empty()
			and overlay_mode in ["city", "underground"])

		if moved_things or changed_disaster_map or not data_maps_only:
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

	if ran_days or map_refresh_requested:
		simulation_timings.record_step("Main thread / simulation display refresh", Time.get_ticks_usec() - refresh_started)

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


func _build_interface(original_assets: OriginalGameAssets) -> void:
	theme = ClassicStyle.create_theme()
	city_workspace = CityWorkspaceView.instantiate() as CityWorkspace
	city_workspace.toolbar_art = original_assets.toolbar_art
	add_child(city_workspace)

	city_menu_bar = city_workspace.menu_bar
	city_menu_bar.file_menu_requested.connect(_on_file_menu)
	city_menu_bar.speed_menu_requested.connect(_on_speed_menu)
	city_menu_bar.options_menu_requested.connect(_on_options_menu)
	city_menu_bar.view_menu_requested.connect(_on_view_menu)
	city_menu_bar.disaster_menu_requested.connect(_on_disaster_menu)
	city_menu_bar.windows_menu_requested.connect(_on_windows_menu)
	city_menu_bar.newspaper_menu_requested.connect(_on_newspaper_menu)
	city_menu_bar.help_menu_requested.connect(_on_help_menu)
	speed_menu = city_menu_bar.speed_menu
	options_menu = city_menu_bar.options_menu
	view_menu = city_menu_bar.view_menu
	disasters_menu = city_menu_bar.disasters_menu

	city_toolbar = city_workspace.toolbar
	city_toolbar.button_clicked.connect(func() -> void:
		if app_toolbar_sounds:
			audio_controller.play_toolbar_click(city == null or city.sound_enabled())
	)
	city_toolbar.group_requested.connect(_choose_tool_group)
	city_toolbar.subtool_requested.connect(_select_subtool)
	city_toolbar.rotate_requested.connect(_rotate_city)
	city_toolbar.zoom_out_requested.connect(_zoom_out)
	city_toolbar.zoom_in_requested.connect(_zoom_in)
	city_toolbar.overlay_requested.connect(_set_overlay)
	city_toolbar.surface_visibility_requested.connect(_set_surface_visibility)
	city_toolbar.underground_pipes_visibility_requested.connect(
		_set_underground_pipes_visible
	)
	city_toolbar.underground_subways_visibility_requested.connect(_set_underground_subways_visible)
	rotate_counter_clockwise_button = city_toolbar.rotate_counter_clockwise_button
	rotate_clockwise_button = city_toolbar.rotate_clockwise_button
	zoom_out_button = city_toolbar.zoom_out_button
	zoom_in_button = city_toolbar.zoom_in_button
	view_layers_heading = city_toolbar.view_layers_heading
	view_visibility_checks = city_toolbar.view_visibility_checks

	map_view = city_workspace.map_view
	map_view.selection_completed.connect(_apply_map_selection)
	map_view.selection_changed.connect(_on_map_selection_changed)
	network_preview = NetworkPlacementPreview.new()
	network_preview.map_view = map_view
	network_preview.z_index = 80
	network_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_view.add_child(network_preview)
	map_view.selection_finished.connect(network_preview.clear)
	map_view.selection_canceled.connect(network_preview.clear)
	map_view.selection_started.connect(_on_map_selection_started)
	map_view.stretch_changed.connect(_on_terrain_stretch_changed)
	map_view.selection_finished.connect(_on_map_selection_finished)
	map_view.selection_canceled.connect(_on_map_selection_canceled)
	map_view.query_requested.connect(_open_query)
	map_view.center_requested.connect(_center_map_on_tile)
	map_view.zoom_changed.connect(_on_city_zoom_changed)
	map_view.viewport_changed.connect(_refresh_city_map_viewport)
	city_status_bar = city_workspace.status_bar
	status_label = city_status_bar.message_label
	_sync_speed_ui()

	city_dialogs = CityDialogsView.new(original_assets)
	city_dialogs.name = "CityDialogs"
	add_child(city_dialogs)

	file_dialog = city_dialogs.city_open_dialog
	file_dialog.file_selected.connect(_load_city)
	save_dialog = city_dialogs.city_save_dialog
	save_dialog.file_selected.connect(_on_save_path_selected)
	save_dialog.canceled.connect(_on_save_dialog_canceled)
	tile_set_dialog = city_dialogs.tile_set_dialog
	tile_set_dialog.file_selected.connect(_load_tile_set)


	city_toolbar.start_city_requested.connect(_start_city)
	new_city_dialog = city_dialogs.new_city_dialog
	new_city_dialog.cancel_requested.connect(_cancel_new_city)
	new_city_dialog.build_requested.connect(_create_new_city)
	new_city_dialog.preview_requested.connect(_schedule_new_city_preview)
	new_city_dialog.preview_timer.timeout.connect(_refresh_new_city_preview)
	new_city_dialog.terrain_regeneration_requested.connect(_make_new_city_preview)
	sign_dialog = city_dialogs.sign_dialog
	sign_dialog.confirmed.connect(_commit_sign)
	sign_dialog.canceled.connect(_cancel_sign)
	bridge_dialog = city_dialogs.bridge_dialog
	bridge_dialog.choice_requested.connect(_choose_bridge)
	bridge_dialog.canceled.connect(_cancel_bridge)
	tool_choice_dialog = city_dialogs.tool_choice_dialog
	tool_choice_dialog.choice_requested.connect(_choose_tool_variant)
	tool_choice_dialog.canceled.connect(_cancel_tool_choice)
	stadium_dialog = city_dialogs.stadium_dialog
	stadium_dialog.confirmed.connect(_confirm_stadium_team)
	stadium_dialog.canceled.connect(_cancel_stadium_team)
	network_connection_dialog = city_dialogs.network_connection_dialog
	network_connection_dialog.confirmed.connect(_confirm_network_connection)
	network_connection_dialog.canceled.connect(_cancel_network_connection)
	highway_connection_dialog = city_dialogs.highway_connection_dialog
	highway_connection_dialog.confirmed.connect(_confirm_highway_connection)
	highway_connection_dialog.canceled.connect(_cancel_highway_connection)
	tunnel_dialog = city_dialogs.tunnel_dialog
	tunnel_dialog.confirmed.connect(_confirm_tunnel)
	tunnel_dialog.canceled.connect(_cancel_tunnel)
	query_dialog = city_dialogs.query_dialog
	query_dialog.close_requested.connect(_close_query)
	query_dialog.action_requested.connect(_run_query_action)
	graph_window = city_dialogs.graph_window
	population_window = city_dialogs.population_window
	industry_window = city_dialogs.industry_window
	industry_window.tax_rates_changed.connect(_on_industry_tax_rates_changed)
	simnation_window = city_dialogs.simnation_window
	city_map_window = city_dialogs.city_map_window
	city_map_window.mode_changed.connect(_on_city_map_mode_changed)
	city_map_window.center_requested.connect(_on_city_map_center_requested)
	ordinance_window = city_dialogs.ordinance_window
	ordinance_window.ordinances_changed.connect(_on_ordinances_changed)
	ordinance_window.update_failed.connect(_show_error)
	city_analysis_dialog = city_dialogs.analysis_dialog
	newspaper_dialog = city_dialogs.newspaper_dialog
	newspaper_dialog.visibility_changed.connect(_on_founding_newspaper_visibility_changed)
	forest_protest_dialog = city_dialogs.forest_protest_dialog
	building_objection_dialog = city_dialogs.building_objection_dialog
	building_objection_dialog.confirmed.connect(_on_building_objection_closed)
	building_objection_dialog.canceled.connect(_on_building_objection_closed)
	library_ruminate_windows = city_dialogs.library_windows
	game_over_dialog = city_dialogs.game_over_dialog
	scenario_dialog = city_dialogs.scenario_dialog
	scenario_dialog.confirmed.connect(_begin_scenario)
	military_dialog = city_dialogs.military_dialog
	military_dialog.confirmed.connect(_accept_military_proposal)
	military_dialog.canceled.connect(_decline_military_proposal)
	budget_dialog = city_dialogs.budget_dialog
	budget_dialog.apply_requested.connect(_commit_budget)
	budget_dialog.cancel_requested.connect(_cancel_budget)
	budget_dialog.issue_bond_requested.connect(_request_issue_bond)
	budget_dialog.repay_bond_requested.connect(_request_repay_bond)
	budget_dialog.bond_confirmation_resolved.connect(_resolve_bond_action)

	_select_tool_group(selected_group)
	_update_zoom_controls(map_view.zoom_percent())
	_build_main_menu()
	about_dialog.set_control_graphics(original_assets.city_ui_graphics)


func _build_main_menu() -> void:
	main_overlays = MainOverlaysView.new()
	main_overlays.name = "ApplicationOverlays"
	add_child(main_overlays)
	main_menu = main_overlays.main_menu
	main_menu.continue_requested.connect(_hide_main_menu)
	main_menu.new_city_requested.connect(_open_new_city_dialog)
	main_menu.open_city_requested.connect(_open_city_dialog)
	main_menu.scenario_requested.connect(_open_scenario_dialog)
	main_menu.settings_requested.connect(_open_settings_dialog)
	main_menu.import_assets_requested.connect(_open_import_settings)
	main_menu.scurk_requested.connect(_open_scurk_dialog)
	main_menu.scurk_place_requested.connect(_open_scurk_place_print)
	main_menu.about_requested.connect(_open_about_dialog)
	main_menu.exit_requested.connect(_request_city_exit.bind("quit"))

	settings_dialog = main_overlays.settings_dialog
	settings_dialog.confirmed.connect(_apply_settings)
	settings_dialog.import_original_requested.connect(_show_reference_import_dialog)

	about_dialog = main_overlays.about_dialog

	save_changes_dialog = main_overlays.save_changes_dialog
	save_changes_dialog.confirmed.connect(_save_pending_city_exit)
	save_changes_dialog.canceled.connect(_cancel_pending_city_exit)
	save_changes_dialog.custom_action.connect(_on_save_changes_action)


func _ensure_scurk_editor() -> void:
	if scurk_editor != null:
		return

	scurk_editor = main_overlays.ensure_scurk_editor()
	scurk_editor.tile_set_applied.connect(_apply_scurk_tile_set)
	scurk_editor.place_print_requested.connect(_open_scurk_place_print)
	desktop_presentation.editor = scurk_editor


func _ensure_scurk_place_print() -> void:
	if scurk_place_print != null:
		return

	scurk_place_print = main_overlays.ensure_scurk_place_print()
	scurk_place_print.tile_selected.connect(_select_scurk_place_tile)
	scurk_place_print.edit_tool_selected.connect(_select_scurk_edit_tool)
	scurk_place_print.export_bmp_requested.connect(_open_scurk_city_export)
	scurk_place_print.print_city_requested.connect(_open_scurk_print_dialog)
	scurk_place_print.undo_requested.connect(_undo_scurk_place)
	scurk_place_print.redo_requested.connect(_redo_scurk_place)
	scurk_place_print.close_requested.connect(_close_scurk_place_print)
	desktop_presentation.place_print = scurk_place_print
	scurk_city_export_dialog = preload("res://src/ui/shared/file_dialog_factory.gd").city_bitmap_save()
	scurk_place_print.add_child(scurk_city_export_dialog)
	scurk_city_export_dialog.file_selected.connect(_export_scurk_city_bmp)


func _ensure_scurk_print() -> void:
	if scurk_print != null:
		return

	scurk_print = main_overlays.ensure_scurk_print()
	scurk_print.preview_options_changed.connect(_refresh_scurk_print_preview)
	scurk_print.save_pdf_requested.connect(_open_scurk_print_pdf_dialog)
	desktop_presentation.print_dialog = scurk_print
	scurk_print_pdf_dialog = preload("res://src/ui/shared/file_dialog_factory.gd").city_pdf_save()
	scurk_print.add_child(scurk_print_pdf_dialog)
	scurk_print_pdf_dialog.file_selected.connect(_save_scurk_city_pdf)


func _sync_asset_menu_actions() -> void:
	var popup := city_menu_bar.file_menu.get_popup()

	for index in popup.item_count:
		if popup.get_item_id(index) not in [5, 6] and not popup.is_item_separator(index):
			popup.set_item_disabled(index, not assets_ready)


func _show_main_menu() -> void:
	if main_menu == null:
		return

	if scurk_place_print != null and scurk_place_print.visible:
		scurk_place_print.hide()
		_update_edit_state()

	if scurk_print != null:
		scurk_print.hide()

	_sync_asset_menu_actions()
	main_menu.set_assets_ready(assets_ready)

	if assets_ready:
		main_menu.city_background.configure(reference_root, palette, large_sprites)

	main_menu.show_menu(city != null)
	status_label.text = "Main menu."


func _hide_main_menu() -> void:
	if audio_controller != null and audio_controller.menu_music:
		audio_controller.set_menu_music(false)

		if city != null and city.music_enabled():
			_play_music_track(audio_controller.music_director.next_general_track())

	if main_menu != null:
		main_menu.hide()

	if city != null:
		status_label.text = "City ready."


func _set_city_renderer(value: String) -> void:
	var selected := SettingsStore.normalize_renderer(value)

	if selected == app_city_renderer:
		return

	app_city_renderer = selected
	_close_region_cache()

	if static_render_thread != null and static_render_thread.is_started():
		static_render_thread.wait_to_finish()

	static_render_thread = null
	static_render_job = null
	pending_static_render = false
	static_view_cache.clear()
	dynamic_visual_cache.clear()
	sign_foreground_cache.clear()
	_sync_city_option_menus()
	_refresh_map()


func _open_import_settings() -> void:
	_open_settings_dialog()
	settings_dialog.tabs.current_tab = 3


func _open_settings_dialog() -> void:
	settings_dialog.dark_underground_check.button_pressed = app_dark_underground
	settings_dialog.theme_selector.select(1 if app_ui_theme == "dark" else 0)
	settings_dialog.default_mayor_edit.text = app_default_mayor_name
	settings_dialog.overview_graphics_selector.select(app_overview_graphics)
	settings_dialog.original_compatibility_check.button_pressed = app_original_compatibility
	settings_dialog.original_compatibility_check.disabled = current_document != null and current_document.is_extended()
	settings_dialog.original_compatibility_check.tooltip_text = "SC2X cities cannot return to original compatibility." if settings_dialog.original_compatibility_check.disabled else ""
	settings_dialog.warn_sc2x_conversion_check.button_pressed = app_warn_sc2x_conversion
	settings_dialog.shuffle_music_check.button_pressed = app_shuffle_music
	settings_dialog.toolbar_sounds_check.button_pressed = app_toolbar_sounds
	settings_dialog.sound_pack_edit.text = AppSettingsDialog.pack_file_path(app_sound_pack_folder)
	settings_dialog.music_pack_edit.text = AppSettingsDialog.pack_file_path(app_music_pack_folder)
	settings_dialog.show_values(
		app_music_volume, app_effects_volume, app_fullscreen,
		app_graphics_source, app_graphics_folder, app_city_renderer, app_background_audio, app_zoom_graphics,
	)
	_refresh_settings_pack_names()


func _refresh_settings_pack_names() -> void:
	if settings_dialog == null:
		return

	settings_dialog.set_loaded_pack("graphics", asset_source.graphics_name if assets_ready else "",
		app_graphics_folder if app_graphics_source == "folder" else "")

	if audio_controller != null:
		settings_dialog.set_loaded_pack("sound", audio_controller.sound_pack.pack_name, app_sound_pack_folder)
		settings_dialog.set_loaded_pack("music", audio_controller.music_pack.pack_name, app_music_pack_folder)


func _apply_settings() -> void:
	var values: Dictionary = settings_dialog.selected_values()

	if bool(values.original_compatibility) and current_document != null and current_document.is_extended():
		settings_dialog.show_compatibility_error("This city is SC2X and cannot return to original compatibility. Save it, then open a different original SC2 city or restart the app before enabling compatibility.")

		return

	var pack_error: String = CityAudioController.validate_media_packs(values.sound_pack_folder, values.music_pack_folder)

	if not pack_error.is_empty():
		settings_dialog.show_pack_error(pack_error)

		return

	var changed_source: bool = values.graphics_source != app_graphics_source or values.graphics_folder != app_graphics_folder
	var media_packs_changed: bool = values.sound_pack_folder != app_sound_pack_folder or values.music_pack_folder != app_music_pack_folder or (not assets_ready and changed_source)
	var selected: GameAssetSource

	if changed_source:
		selected = GameAssetSource.load_source(reference_root, values.graphics_source, values.graphics_folder)

		if not selected.error.is_empty():
			_show_graphics_source_error(selected.error)

			return

	if changed_source:
		_apply_graphics_source(selected)

	app_original_compatibility = bool(values.original_compatibility)
	app_warn_sc2x_conversion = bool(values.warn_sc2x_conversion)
	_apply_compatibility_controls()
	app_graphics_source = values.graphics_source
	app_graphics_folder = values.graphics_folder
	_set_city_renderer(str(values.city_renderer))
	app_dark_underground = bool(values.dark_underground)
	_sync_map_style()
	app_ui_theme = str(values.ui_theme)
	AppUiTheme.select(app_ui_theme)
	app_default_mayor_name = str(values.default_mayor_name)

	if app_default_mayor_name.is_empty():
		app_default_mayor_name = "Mayor"

	var overview_changed := app_overview_graphics != int(values.overview_graphics)
	app_overview_graphics = int(values.overview_graphics)
	_set_graphics_preferences(values.zoom_graphics)

	if overview_changed:
		_close_region_cache()
		dynamic_visual_cache.clear()
		sign_foreground_cache.clear()
		_refresh_map()

	app_toolbar_sounds = bool(values.toolbar_sounds)
	app_sound_pack_folder = str(values.sound_pack_folder)
	app_music_pack_folder = str(values.music_pack_folder)

	if assets_ready and audio_controller != null and media_packs_changed:
		audio_controller.set_media_packs(app_sound_pack_folder, app_music_pack_folder)

	app_shuffle_music = bool(values.shuffle_music)
	audio_controller.set_shuffle_music(app_shuffle_music)
	app_background_audio = bool(values.background_audio)
	app_soundtrack_folder = ""
	app_music_volume = float(values.music_volume)
	app_effects_volume = float(values.effects_volume)
	var fullscreen_changed := app_fullscreen != bool(values.fullscreen)
	app_fullscreen = bool(values.fullscreen)

	if audio_controller != null:
		audio_controller.set_background_audio(app_background_audio)
		audio_controller.set_volumes(app_music_volume, app_effects_volume)
		audio_controller.set_soundtrack_folder(app_soundtrack_folder, (main_menu != null and main_menu.visible) or (city != null and city.music_enabled()))

	if fullscreen_changed:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if app_fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED
		)

	var error := SettingsStore.save_values(
		app_music_volume, app_effects_volume, app_fullscreen,
		app_settings_path, app_graphics_source, app_graphics_folder, app_soundtrack_folder, app_city_renderer, app_background_audio, app_zoom_graphics, app_toolbar_sounds, app_sound_pack_folder, app_music_pack_folder, app_shuffle_music, app_original_compatibility, app_warn_sc2x_conversion, app_default_mayor_name, app_overview_graphics, app_ui_theme, app_dark_underground,
	)
	status_label.text = (
		"Settings saved."
		if error == OK
		else "Settings applied, but the settings file could not be saved."
	)
	_refresh_settings_pack_names()


func _apply_graphics_source(selected: GameAssetSource) -> void:
	# wait for workers using the old archives
	_close_region_cache()

	if static_render_thread != null and static_render_thread.is_started():
		static_render_thread.wait_to_finish()

	static_render_thread = null
	static_render_job = null
	asset_source = selected
	assets_ready = true
	reference_root = selected.reference_root
	new_city_session.independent_template = false
	audio_controller.reference_root = reference_root
	audio_controller.original_media_enabled = true
	var assets := selected.assets
	newspaper_data = assets.newspaper_data
	original_query_strings = assets.strings
	forest_protest_text = assets.forest_protest_text
	building_objection_text = assets.building_objection_text
	library_texts = assets.library_texts
	palette = assets.palette
	scenario_palette = assets.scenario_palette
	scenario_graphics = assets.scenario_graphics
	scurk_graphics = assets.scurk_graphics
	base_large_sprites = assets.large_sprites
	base_small_medium_sprites = assets.small_medium_sprites
	large_sprites = base_large_sprites
	small_medium_sprites = base_small_medium_sprites

	if active_scurk_tile_set != null:
		large_sprites = SpriteArchive.combine([base_large_sprites, active_scurk_tile_set.overrides])
		small_medium_sprites = SpriteArchive.combine([base_small_medium_sprites, active_scurk_tile_set.overrides])

	_invalidate_sprite_art()
	_update_palette_cycle_texture()
	city_toolbar.replace_artwork(assets.toolbar_art)
	_refresh_child_tool_icons()
	about_dialog.set_control_graphics(assets.city_ui_graphics)
	new_city_dialog.set_control_graphics(assets.city_ui_graphics)
	newspaper_dialog.set_control_graphics(assets.city_ui_graphics)
	desktop_presentation.set_graphics(assets.desktop_graphics)
	city_dialogs.original_assets = assets
	industry_window.industry_control.set_icon_strip(assets.industry_icons)
	simnation_window.simnation_control.set_sprite_sheet(assets.simnation_sprites)
	city_map_window.set_resources(assets.city_map_icons, assets.strings)
	forest_protest_dialog.set_picture(assets.forest_protest_image)
	building_objection_dialog.set_picture(assets.forest_protest_image)
	if scurk_editor != null:
		scurk_editor.configure(palette, base_large_sprites, base_small_medium_sprites, reference_root, scurk_graphics)

	if scurk_place_print != null and scurk_place_print.visible:
		scurk_place_print.configure(palette, large_sprites, active_scurk_tile_set.names if active_scurk_tile_set != null else {}, scurk_graphics)

	_sync_asset_menu_actions()
	main_menu.set_assets_ready(true)
	main_menu.city_background.replace_graphics(palette, large_sprites)

	if main_menu.visible:
		main_menu.city_background.configure(reference_root, palette, large_sprites)

	_refresh_map(false)


func _load_app_settings() -> void:
	var values := SettingsStore.load_values(
		app_settings_path,
		app_music_volume,
		app_effects_volume,
		app_fullscreen,
	)
	app_toolbar_sounds = bool(values.toolbar_sounds)
	app_sound_pack_folder = str(values.sound_pack_folder)
	app_music_pack_folder = str(values.music_pack_folder)
	app_dark_underground = bool(values.dark_underground)
	_sync_map_style()
	app_ui_theme = str(values.ui_theme)
	AppUiTheme.select(app_ui_theme)
	app_default_mayor_name = str(values.default_mayor_name)
	app_overview_graphics = int(values.overview_graphics)
	app_zoom_graphics = values.zoom_graphics
	app_background_audio = values.background_audio
	app_original_compatibility = bool(values.original_compatibility)
	app_warn_sc2x_conversion = bool(values.warn_sc2x_conversion)
	app_shuffle_music = values.shuffle_music
	app_city_renderer = values.city_renderer
	app_soundtrack_folder = values.soundtrack_folder
	app_music_volume = values.music_volume
	app_effects_volume = values.effects_volume
	app_fullscreen = values.fullscreen
	app_graphics_source = values.graphics_source
	app_graphics_folder = values.graphics_folder

	if app_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _open_scurk_dialog() -> void:
	if not assets_ready:
		return

	if (
		palette == null
		or not palette.is_valid()
		or base_large_sprites == null
		or base_small_medium_sprites == null
	):
		_show_error("The SCURK graphics are not loaded.")

		return

	_ensure_scurk_editor()
	scurk_editor.configure(
		palette, base_large_sprites, base_small_medium_sprites, reference_root, scurk_graphics
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

	if scurk_editor.tile_set == null and active_scurk_path.is_empty() and asset_source.uses_graphics_pack:
		var created := ScurkMif.from_archives([base_large_sprites, base_small_medium_sprites])
		var loaded := scurk_editor.load_tile_set(created)

		if not loaded.ok:
			_show_error(loaded.error)

			return

	var opened := scurk_editor.show_editor(initial_path)

	if not opened.ok:
		_show_error(opened.error)


func _open_scurk_place_print() -> void:
	if not assets_ready:
		return

	if landscape_editor:
		return

	if city == null:
		_show_error("Load or create a city before you open SCURK Place & Print.")

		return

	if (
		palette == null
		or not palette.is_valid()
		or large_sprites == null
		or not large_sprites.is_valid()
	):
		_show_error("The SCURK Place & Print graphics are not available.")

		return

	_ensure_scurk_place_print()
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
	scurk_place_print.configure(palette, large_sprites, names, scurk_graphics)

	if not last_edit_command.get("scurk_place_history", false):
		scurk_edit_history.clear()

	scurk_place_print.set_history_enabled(
		scurk_edit_history.can_undo(), scurk_edit_history.can_redo()
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
		status_label.theme_type_variation = ""
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
		_show_error("Choose a location outside the read-only original support-data directory.")

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
	status_label.theme_type_variation = ""
	status_label.text = message


func _open_scurk_print_dialog() -> void:
	if city == null:
		return

	_ensure_scurk_place_print()
	_ensure_scurk_print()

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
		_show_error("Choose a location outside the read-only original support-data directory.")

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
	status_label.theme_type_variation = ""
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

	if overlay_mode != "city":
		_set_overlay("city")

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
		scurk_edit_history.record(command, scurk_name)

		if scurk_place_print != null:
			scurk_place_print.set_history_enabled(true, false)

	last_edit_command = command


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
	status_label.theme_type_variation = ""
	status_label.text = message


func _undo_scurk_place() -> void:
	if city == null or not scurk_edit_history.can_undo():
		return

	var result := scurk_edit_history.undo(city, tool_random)

	if not result.get("ok", false):
		_show_error("Cannot undo SCURK placement: %s" % result.error)

		return

	var command: Dictionary = result.command
	last_edit_command = result.current_command
	scurk_place_print.set_history_enabled(
		scurk_edit_history.can_undo(), scurk_edit_history.can_redo()
	)
	_refresh_details()
	_refresh_after_city_edit(command)
	var command_name := String(command.get("scurk_tool_name", "edit"))
	var message := "Undid SCURK %s across %d tiles." % [
		command_name, result.restored_tiles,
	]
	scurk_place_print.set_status(message)
	status_label.theme_type_variation = ""
	status_label.text = message


func _redo_scurk_place() -> void:
	if city == null or not scurk_edit_history.can_redo():
		return

	var result := scurk_edit_history.redo(city, tool_random)

	if not result.get("ok", false):
		_show_error("Cannot redo SCURK placement: %s" % result.error)

		return

	var command: Dictionary = result.command
	last_edit_command = command
	scurk_place_print.set_history_enabled(
		scurk_edit_history.can_undo(), scurk_edit_history.can_redo()
	)
	_refresh_details()
	_refresh_after_city_edit(command)
	var command_name := String(command.get("scurk_tool_name", "edit"))
	var message := "Redid SCURK %s across %d tiles." % [
		command_name, result.restored_tiles,
	]
	scurk_place_print.set_status(message)
	status_label.theme_type_variation = ""
	status_label.text = message


func _open_about_dialog() -> void:
	about_dialog.popup_centered()


func _choose_tool_group(group_index: int) -> void:
	_select_tool_group(group_index)


func _tool_button_icon(group_index: int, subtool_index: int) -> Texture2D:
	if group_index == 0 and subtool_index in [1, 2, 3]:
		return TerrainToolIcons.terrain_action(
			asset_source.assets.city_ui_graphics, ["", "level", "raise", "lower"][subtool_index]
		)

	if group_index == 0 and subtool_index in [5, 6, 7]:
		return TerrainToolIcons.terrain_action(asset_source.assets.city_ui_graphics, ["stretch", "sea_raise", "sea_lower"][subtool_index - 5])

	if palette == null or large_sprites == null or not large_sprites.is_valid():
		return city_toolbar.group_icon(group_index) if city_toolbar != null else null

	var tile_id := Buildings.tile_for_tool(group_index, subtool_index)
	var sprite_id := 1000 + tile_id if tile_id > 0 else -1

	if sprite_id < 0:
		var table_index := group_index * Tools.MAX_SLOTS_PER_GROUP + subtool_index
		const REPRESENTATIVE_SPRITES := {
			5: 1257, 6: 1270, 7: 1270,
			12: 1012, 13: 1270, 14: 1270, 15: 1012, 36: 1014, 39: 1198, 48: 1334,
			72: 1029, 73: 1073, 74: 1063, 75: 1093,
			84: 1044, 85: 1319, 88: 1108,
			96: 1299, 97: 1298,
			108: 1291, 109: 1292,
			120: 1293, 121: 1294,
			132: 1295, 133: 1296,
		}
		sprite_id = int(REPRESENTATIVE_SPRITES.get(table_index, -1))

	if sprite_id < 0:
		return city_toolbar.group_icon(group_index) if city_toolbar != null else null

	var entry := large_sprites.find_sprite(sprite_id)

	if entry == null:
		return city_toolbar.group_icon(group_index) if city_toolbar != null else null

	var rendered := entry.create_image(toolbar_animation_palette if toolbar_animation_palette != null else palette)

	if not rendered.get("ok", false):
		return city_toolbar.group_icon(group_index) if city_toolbar != null else null

	var image: Image = rendered.image.duplicate()

	if group_index == 6 and subtool_index == 1:
		var section := Image.create(image.get_width() + 32, image.get_height() + 16, false, Image.FORMAT_RGBA8)
		section.fill(Color.TRANSPARENT)

		for offset in [Vector2i(16, 0), Vector2i(0, 8), Vector2i(32, 8), Vector2i(16, 16)]:
			section.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), offset)

		image = section

	var scale := minf(1.0, minf(48.0 / image.get_width(), 44.0 / image.get_height()))

	if scale < 1.0:
		image.resize(
			maxi(1, roundi(image.get_width() * scale)),
			maxi(1, roundi(image.get_height() * scale)),
			Image.INTERPOLATE_NEAREST,
		)

	return ImageTexture.create_from_image(image)


func _refresh_child_tool_icons() -> void:
	if city_toolbar != null:
		city_toolbar.refresh_child_tool_icons(selected_group, _tool_button_icon)


func _zoom_in() -> void:
	map_view.zoom_in()


func _zoom_out() -> void:
	map_view.zoom_out()


func _rotate_city(counter_clockwise: bool) -> void:
	var map_edge: int = city.map_size if city != null else 128

	if city == null:
		_show_error("No city is loaded.")

		return

	var old_center := Vector2i(-1, -1)

	if overlay_mode in MAP_DISPLAY_MODES:
		old_center = map_view.center_tile()

	var new_center := CityRotation.rotate_point(
		old_center, map_edge, counter_clockwise
	)
	var result := CityRotation.apply(city, counter_clockwise)

	if not result.ok:
		_show_error("Cannot rotate city: %s" % result.error)

		return

	if simulation_engine != null:
		simulation_engine.rotate_runtime_coordinates(counter_clockwise)

	last_edit_command = {}
	map_view.clear_trip_reach()
	map_view.clear_service_query()
	map_view.show_transient_effects([])
	_refresh_map()

	if new_center.x >= 0:
		map_view.center_on_tile(new_center)

	status_label.theme_type_variation = ""
	status_label.text = "Rotated %s. Compass: %d." % [
		"counter-clockwise" if counter_clockwise else "clockwise",
		result.new_compass,
	]


func _update_zoom_controls(percent: int) -> void:
	if city_workspace != null and city_workspace.status_bar != null:
		city_workspace.status_bar.set_zoom(percent)

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

	if city_menu_bar == null or fps_update_seconds < 0.25:
		return

	fps_update_seconds = fmod(fps_update_seconds, 0.25)
	city_menu_bar.set_fps(Engine.get_frames_per_second())

	if city_status_bar != null:
		city_status_bar.refresh_tooltips()


func _on_city_zoom_changed(percent: int) -> void:
	_update_zoom_controls(percent)

	if city != null and overlay_mode in ["city", "underground"]:
		_refresh_map(false)


func _on_map_selection_canceled() -> void:
	if terrain_stretch.active:
		_refresh_terrain_stretch(0)
		terrain_stretch.finish()

	if status_label == null:
		return

	status_label.theme_type_variation = ""
	status_label.text = "Forest brush stopped. Use Undo to remove its last placement." if map_view.continuous_placement else "Selection canceled. No action was taken."


func _on_map_selection_started() -> void:
	if landscape_editor and selected_group == 0 and selected_subtool == 5:
		terrain_stretch.begin(map_view.selection_start)

	if selected_group != 0:
		return

	if scurk_place_print != null and scurk_place_print.visible:
		return

	_start_tool_loop_sound(508)


func _on_map_selection_finished() -> void:
	if terrain_stretch.active:
		_refresh_terrain_stretch(0)
		terrain_stretch.finish()

	_stop_tool_loop_sound()


func _on_terrain_stretch_changed(levels: int, deferred: bool) -> void:
	if terrain_stretch.active:
		_refresh_terrain_stretch(0 if deferred else levels)


func _refresh_terrain_stretch(levels: int) -> void:
	var update := terrain_stretch.update(city, tool_random, levels)

	if update.get("ok", false):
		_refresh_after_city_edit(update)

		if levels != 0 and not is_instance_valid(audio_controller.tool_loop_player):
			_play_sound_events([ToolSounds.SOUND_TRACTOR])


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
		status_label.theme_type_variation = ""
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
		status_label.theme_type_variation = "ErrorLabel"
		status_label.text = "Cannot start zone selection: %s" % preview.error

		return

	var cost := int(preview.cost)
	var affordable := bool(preview.affordable)
	map_view.set_selection_price(cost, affordable)
	status_label.theme_type_variation = ""
	status_label.text = "%s preview: %d charged %s for $%s." % [
		Tools.tool(selected_group, selected_subtool).name,
		int(preview.charged_tiles),
		"tile" if int(preview.charged_tiles) == 1 else "tiles",
		_format_number(cost),
	]

	if not affordable:
		status_label.theme_type_variation = "ErrorLabel"
		status_label.text += " Funds are not sufficient."


func _on_file_menu(id: int) -> void:
	if not assets_ready and id not in [5, 6]:
		return

	match id:
		0:
			_open_new_city_dialog()
		1:
			_open_city_dialog()
		2:
			_open_save_dialog()
		CityMenuBar.MENU_SAVE_CITY:
			_save_city()
		3:
			_open_tile_set_dialog()
		4:
			_restore_original_tile_set()
		MENU_SCURK_PLACE_PRINT:
			_open_scurk_place_print()
		5:
			_request_main_menu()
		6:
			_request_city_exit("quit")


func _on_speed_menu(id: int) -> void:
	if speed_controller == null:
		return

	if id < 0 or id > 4:
		return

	_select_speed(id + GameSpeed.Speed.PAUSED)


func _on_options_menu(id: int) -> void:
	if id == CityMenuBar.MENU_UPGRADE_SC2X:
		_upgrade_city_to_sc2x()

		return

	if id == CityMenuBar.MENU_SETTINGS:
		_open_settings_dialog()

		return

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
			_play_music_track(audio_controller.music_director.next_general_track())
		else:
			_stop_music()

	status_label.theme_type_variation = ""
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

	_sync_upgrade_city_option()
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
	if view_menu != null:
		for index in MAP_DISPLAY_MODES.size():
			view_menu.get_popup().set_item_checked(index, MAP_DISPLAY_MODES[index] == overlay_mode)

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
				view_menu.get_popup().set_item_disabled(item_index, CityDataView.MODES.has(overlay_mode))

	if city_toolbar != null:
		city_toolbar.sync_view_mode(overlay_mode)

	for key in view_visibility_checks:
		var check: CheckBox = view_visibility_checks[key]
		check.visible = (underground_active if key in ["pipes", "subways"] else not underground_active) and not CityDataView.MODES.has(overlay_mode)
		var enabled := (
			show_underground_pipes
			if key == "pipes"
			else (show_underground_subways if key == "subways" else bool(surface_visibility.get(key, true)))
		)
		check.set_pressed_no_signal(enabled)


func _rebuild_view_layer_menu(underground_active: bool) -> void:
	var popup := view_menu.get_popup()

	while popup.item_count > MAP_DISPLAY_MODES.size() + 2:
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
	if landscape_editor:
		return

	if city == null or simulation_engine == null:
		_show_error("Load a city before you start a disaster.")

		return

	if id == MENU_NO_DISASTERS:
		var enabled := not city.no_disasters_enabled()

		if not city.set_no_disasters_enabled(enabled):
			_show_error("Cannot update the No Disasters option.")

			return

		_sync_city_option_menus()
		status_label.theme_type_variation = ""
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
	simulation_map_dirty = false
	_refresh_map(false)

	for requested_point in result.get("view_center_requests", []):
		map_view.center_on_tile(requested_point)

	_show_effect_events(
		result.get("effect_events", []), result.get("sound_events", [])
	)
	_show_news_items(result.get("news_items", []))
	var disaster_name := CityMenuBar.disaster_name(id)
	status_label.theme_type_variation = ""
	status_label.text = "%s started." % disaster_name
	result["name"] = disaster_name

	return result


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
	elif id == 7:
		debug_overlay.toggle()


func _open_ordinance_window() -> void:
	if city == null or ordinance_window == null:
		return

	var result: Dictionary = ordinance_window.open_city(city)

	if not result.get("ok", false):
		_show_error("Cannot open ordinances: %s" % result.get("error", "invalid data"))


func _on_ordinances_changed() -> void:
	_refresh_details()
	status_label.theme_type_variation = ""
	status_label.text = "Ordinance selection saved."


func _open_graph_window() -> void:
	if city == null or graph_window == null:
		return

	graph_window.show_city(city)


func _open_population_window() -> void:
	if city == null or population_window == null:
		return

	population_window.show_city(city)


func _open_industry_window() -> void:
	if city == null or industry_window == null:
		return

	industry_window.show_city(city)


func _on_industry_tax_rates_changed() -> void:
	_refresh_details()
	status_label.theme_type_variation = ""
	status_label.text = "Industry tax rates saved."


func _open_simnation_window() -> void:
	if city == null or simnation_window == null:
		return

	simnation_window.show_city(city)


func _open_city_map_window() -> void:
	if city == null or city_map_window == null:
		return

	city_map_window.toggle_city(city, palette, _city_map_viewport_outline())


func _on_city_map_mode_changed(mode: String) -> void:
	status_label.theme_type_variation = ""
	status_label.text = "City Map: %s" % CityMapView.MODE_NAMES.get(mode, mode)


func _on_city_map_center_requested(point: Vector2i) -> void:
	map_view.center_on_tile(point)
	status_label.theme_type_variation = ""
	status_label.text = "City view centered at %d, %d." % [point.x, point.y]


func _city_map_viewport_outline() -> PackedVector2Array:
	if map_view == null or overlay_mode not in MAP_DISPLAY_MODES:
		return PackedVector2Array()

	return map_view.visible_tile_outline()


func _refresh_city_map_viewport() -> void:
	if city_map_window != null:
		city_map_window.refresh_viewport(_city_map_viewport_outline())


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
		CityStatusBar.NEWS_NAMES,
		newspaper_session_seed,
	)


func _on_help_menu(_id: int) -> void:
	_open_about_dialog()


func _open_new_city_dialog() -> void:
	if not assets_ready:
		return

	if new_city_dialog == null:
		return

	new_city_return_to_main_menu = main_menu != null and main_menu.visible

	if new_city_return_to_main_menu:
		main_menu.hide()

	new_city_dialog.preview_timer.stop()
	new_city_session.begin(tool_random.state, nuisance_random.state)
	new_city_dialog.city_name_input.text = "New City"
	new_city_dialog.mayor_name_input.text = app_default_mayor_name
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
	return OriginalCompatibility.terrain_options({
		"size": new_city_dialog.size_input.get_selected_id(),
		"native_maps": new_city_dialog.native_maps_input.button_pressed,
		"ocean": new_city_dialog.ocean_input.button_pressed,
		"river": new_city_dialog.river_input.button_pressed,
		"hills": roundi(new_city_dialog.hills_input.value),
		"water": roundi(new_city_dialog.water_input.value),
		"trees": roundi(new_city_dialog.trees_input.value),
	}, app_original_compatibility)


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
	var options := _new_city_terrain_options()
	var generated := new_city_session.generate_preview(
		template_path, options, advance_seed
	)

	if not generated.ok:
		if generated.stage == "template":
			new_city_dialog.preview_status.text = "Cannot load the default city."
		elif generated.stage == "city":
			new_city_dialog.preview_status.text = "Cannot display the generated terrain."
		else:
			new_city_dialog.preview_status.text = (
				"Cannot generate terrain: %s" % generated.error
			)

		return false

	var preview_city: CityState = generated.city
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
	new_city_session.clear()
	new_city_dialog.preview_view.texture = null
	var return_to_main_menu := new_city_return_to_main_menu
	new_city_return_to_main_menu = false

	if return_to_main_menu:
		_show_main_menu()


func _create_new_city() -> void:
	_request_city_exit("create_new_city")


func _create_new_city_unchecked() -> void:
	new_city_dialog.preview_timer.stop()
	var terrain_options := _new_city_terrain_options()

	if not new_city_session.matches(terrain_options):
		if not _generate_new_city_preview(false):
			_show_error("Cannot prepare the selected terrain.")

			return

	var template_path := reference_root.path_join("DEFAULT.SC2")
	var difficulty := new_city_dialog.difficulty_input.get_selected_id()
	var starting_year := new_city_dialog.year_input.get_selected_id()
	var result := new_city_session.create_city(
		template_path,
		new_city_dialog.city_name_input.text,
		new_city_dialog.mayor_name_input.text,
		difficulty,
		starting_year,
		terrain_options,
		newspaper_session_state,
	)

	if not result.ok:
		if result.stage == "template":
			_show_error("Cannot load the default city: %s" % result.error)
		else:
			_show_error("Cannot create a new city: %s" % result.error)

		return

	tool_random.state = int(result.process_state)
	nuisance_random.state = int(result.game_state)
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

	_enter_landscape_editor()


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
	if not assets_ready:
		return

	var city_directory := ProjectSettings.globalize_path("user://cities")

	if DirAccess.dir_exists_absolute(city_directory):
		file_dialog.current_dir = city_directory

	file_dialog.popup_centered_ratio(0.8)


func _open_scenario_dialog() -> void:
	if not assets_ready:
		return

	var scenario_directory := ProjectSettings.globalize_path("user://scenarios")

	if DirAccess.dir_exists_absolute(scenario_directory):
		file_dialog.current_dir = scenario_directory

	file_dialog.popup_centered_ratio(0.8)


func _save_city() -> void:
	if current_document == null:
		return

	if current_save_path.is_empty():
		_open_save_dialog()
	else:
		_save_copy(current_save_path)


func _can_upgrade_city_to_sc2x() -> bool:
	if app_original_compatibility or landscape_editor or city == null or current_document == null or simulation_engine == null:
		return false

	if current_document.is_extended() or current_document.full_resolution_maps():
		return false

	var path := current_save_path if not current_save_path.is_empty() else current_document.source_path

	return path.get_extension().to_lower() == "sc2"


func _sync_upgrade_city_option() -> void:
	if options_menu == null:
		return

	var popup := options_menu.get_popup()
	var index := popup.get_item_index(CityMenuBar.MENU_UPGRADE_SC2X)
	var available := _can_upgrade_city_to_sc2x()

	if available and index < 0:
		popup.add_item("Upgrade City to SC2X...", CityMenuBar.MENU_UPGRADE_SC2X)
	elif not available and index >= 0:
		popup.remove_item(index)


func _upgrade_city_to_sc2x(confirmed := false) -> void:
	if not _can_upgrade_city_to_sc2x():
		return

	if not current_document.is_extended() and app_warn_sc2x_conversion and not confirmed:
		if sc2x_conversion_dialog == null:
			sc2x_conversion_dialog = ConfirmationDialog.new()
			sc2x_conversion_dialog.title = "Upgrade city to SC2X?"
			sc2x_conversion_dialog.dialog_text = "This permanently converts this city to SC2X.\nIt cannot return to SC2 or use original compatibility.\nThe original SimCity 2000 cannot open SC2X files.\n\nSave a separate SC2X copy. Your existing SC2 file stays unchanged."
			sc2x_conversion_dialog.get_ok_button().text = "Upgrade to SC2X"
			sc2x_conversion_dialog.exclusive = true
			sc2x_conversion_dialog.theme = ClassicUiStyle.create_dialog_theme()
			add_child(sc2x_conversion_dialog)
			sc2x_conversion_dialog.confirmed.connect(_confirm_sc2x_conversion)
			sc2x_conversion_dialog.canceled.connect(func() -> void:
				pending_sc2x_document = null)

		pending_sc2x_document = current_document
		sc2x_conversion_dialog.popup_centered()

		return

	if frame_simulation != null:
		frame_simulation.close()
		frame_simulation = null

	var enabled := current_document.enable_full_resolution_maps()

	if speed_controller != null and current_document.is_extended():
		frame_simulation = FrameSimulationRunner.new(speed_controller)

	if not enabled:
		_show_error("Cannot enable per-tile data maps: city data is incomplete.")

		return

	simulation_timings.clear()
	last_edit_command.clear()
	scurk_edit_history.clear()
	current_save_path = ""
	_invalidate_view_render()
	_refresh_map(false)
	_sync_upgrade_city_option()
	status_label.text = "City upgraded to SC2X. Save a separate copy; the original game cannot open it."
	_open_save_dialog()


func _confirm_sc2x_conversion() -> void:
	var expected := pending_sc2x_document
	pending_sc2x_document = null

	if expected != null and current_document == expected:
		_upgrade_city_to_sc2x(true)


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

	save_dialog.filters = PackedStringArray(["*.sc2x ; Extended cities"] if current_document.is_extended() else ["*.SC2, *.sc2 ; SimCity 2000 cities"])
	save_dialog.current_file = save_name + (".sc2x" if current_document.is_extended() else ".SC2")
	save_dialog.popup_centered_ratio(0.8)


func _open_tile_set_dialog() -> void:
	var tile_set_directory := reference_root.path_join("SCURKART")

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
		scurk_place_print.configure(palette, large_sprites, tile_set.names, scurk_graphics)

	_invalidate_sprite_art()

	if city != null:
		_refresh_map()

	status_label.theme_type_variation = ""
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
		scurk_place_print.configure(palette, large_sprites, {}, scurk_graphics)

	_invalidate_sprite_art()

	if city != null:
		_refresh_map()

	status_label.theme_type_variation = ""
	status_label.text = "Restored the original tile set."


func _invalidate_sprite_art() -> void:
	_close_region_cache()
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
	sign_foreground_cache.clear()
	dynamic_special_batch_cache.clear()
	dynamic_sign_occluders.clear()
	dynamic_sign_occlusion_grid.clear()


func _open_manual_budget() -> void:
	if landscape_editor:
		return

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
	status_label.theme_type_variation = ""

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
		status_label.theme_type_variation = ""
		status_label.text = "Annual budget applied. The simulation can continue."

		return

	var stored := Budget.set_funding(city, values, auto_budget)

	if not stored.ok:
		_show_error("Cannot save the budget: %s" % stored.error)

		return

	status_label.theme_type_variation = ""
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
	status_label.theme_type_variation = ""
	var proposal: Dictionary = result.day_results[0].phase_results.military_proposal

	if int(proposal.base_type) in [2, 3, 4, 5]:
		_play_sound_events(ToolSounds.zone_success_events(7))

	match int(proposal.base_type):
		2:
			status_label.text = "The Army base site is reserved."
		3:
			status_label.text = "The Air Force base site is reserved."
		4:
			status_label.text = "The Navy base site is reserved."
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
	var rendered_picture := ScenarioGraphics.render(scenario, scenario_palette, scenario_graphics)
	var picture: Image = rendered_picture.image if rendered_picture.ok else null
	var name := city.city_name()

	if name.is_empty():
		name = current_document.source_path.get_file().get_basename()

	status_label.theme_type_variation = ""
	status_label.text = "Review the scenario briefing before the simulation starts."
	scenario_dialog.show_briefing(name, picture, scenario.opening_description())


func _begin_scenario() -> void:
	status_label.theme_type_variation = ""
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

	save_changes_dialog.show_city(display_name)


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
	if not assets_ready:
		return

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
	var disable_compatibility := app_original_compatibility and document != null and document.is_extended()
	var compatibility_error := OriginalCompatibility.document_error(document, app_original_compatibility and not disable_compatibility)

	if not compatibility_error.is_empty():
		_show_error(compatibility_error)

		return false

	map_view.clear_trip_reach()
	map_view.clear_service_query()
	var loaded_city := CityModel.from_document(document)

	if not loaded_city.is_valid():
		_show_error(loaded_city.load_error)

		return false

	if disable_compatibility:
		app_original_compatibility = false
		_apply_compatibility_controls()
		var settings_error := SettingsStore.save_original_compatibility(false, app_settings_path)
		status_text += " Original compatibility turned off to open this SC2X city."

		if settings_error != OK:
			status_text += " The preference could not be saved."

	founding_newspaper_pending = false
	landscape_editor = false
	city_toolbar.set_landscape_editor(false)
	city_menu_bar.disasters_menu.disabled = false
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

	new_city_return_to_main_menu = false

	if scurk_place_print != null and scurk_place_print.visible:
		scurk_place_print.hide()

	if scurk_print != null:
		scurk_print.hide()

	pending_scurk_print_options.clear()
	scurk_edit_history.clear()
	annual_budget_pending = false
	game_over_active = false
	city = loaded_city
	map_view.pending_loaded_center = Vector2i(-1, -1)

	if not document.source_path.is_empty():
		map_view.pending_loaded_center = Vector2i(clampi(document.misc_u32(0x1018), 0, city.map_size - 1), clampi(document.misc_u32(0x101c), 0, city.map_size - 1))

	_select_tool_group(17)
	overlay_mode = "city"
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
			and not CityFiles.is_reference_path(source_path, reference_root)
		)
		else ""
	)
	_hide_main_menu()
	_close_region_cache()
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
	palette_elapsed_msec = 0.0
	_update_palette_cycle_texture()
	dynamic_sprite_cache.clear()
	dynamic_foreground_cache.clear()
	dynamic_occluder_cache.clear()
	dynamic_visual_cache.clear()
	sign_foreground_cache.clear()
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

	if frame_simulation != null:
		frame_simulation.close()

	frame_simulation = null
	simulation_timings.clear()
	simulation_engine = Simulation.new(city, process_seed, lfsr_seed, game_seed)
	speed_controller = GameSpeed.new(simulation_engine)
	speed_controller.original_compatibility = app_original_compatibility

	if current_document.is_extended():
		frame_simulation = FrameSimulationRunner.new(speed_controller)

	_sync_speed_ui()
	tool_random = simulation_engine.random
	nuisance_random = simulation_engine.game_random
	simulation_map_dirty = false
	_refresh_saved_news_summary()
	last_edit_command = {}
	dispatch_cycles = PackedInt32Array([0, 0, 0])
	dispatch_initialized = false
	_update_zoom_controls(map_view.zoom_percent())
	var display_name := city.city_name()

	if display_name.is_empty():
		display_name = document.source_path.get_file().get_basename()

	if display_name.is_empty():
		display_name = "New City"

	city_menu_bar.set_city_name(display_name)
	_refresh_details()
	status_label.theme_type_variation = ""
	status_label.text = status_text if not status_text.is_empty() else "City ready."
	_refresh_map()
	_update_edit_state()

	if not city.music_enabled():
		_stop_music()
	elif music_was_active:
		simulation_engine.midi_playback_active = true
	else:
		_play_music_track(audio_controller.music_director.next_general_track())

	if loaded_scenario != null:
		_open_scenario_intro(loaded_scenario)

	if disable_compatibility:
		status_label.text = status_text

	return true


func _play_music_track(track_id: int) -> bool:
	return audio_controller != null and audio_controller.play_music_track(track_id)


func _on_music_activity_changed(active: bool) -> void:
	if simulation_engine != null:
		simulation_engine.midi_playback_active = active


func _music_playback_is_active() -> bool:
	return (
		city != null
		and city.music_enabled()
		and audio_controller != null
		and audio_controller.music_playback_is_active()
	)


func _handle_application_focus_out() -> void:
	if audio_controller != null:
		audio_controller.handle_application_focus_out()


func _handle_application_focus_in() -> void:
	if audio_controller != null:
		audio_controller.handle_application_focus_in(
			(assets_ready and main_menu != null and main_menu.visible and app_music_volume > 0.0
			and (city == null or city.music_enabled()))
			or (city != null and city.music_enabled())
		)


func _stop_music() -> void:
	if audio_controller != null:
		audio_controller.stop_music()


func _stop_sound_effects() -> void:
	if audio_controller != null:
		audio_controller.stop_sound_effects()


func _on_save_path_selected(path: String) -> void:
	var saved := _save_copy(path)

	if saved and pending_city_exit_waiting_for_save:
		_continue_pending_city_exit()


func _on_save_dialog_canceled() -> void:
	if pending_city_exit_waiting_for_save:
		_cancel_pending_city_exit()


func _save_copy(path: String) -> bool:
	var result := CityFiles.save_copy(current_document, path, reference_root, app_original_compatibility)

	if not result.ok:
		_show_error(result.error)

		return false

	var output_path: String = result.path
	current_document.source_path = output_path
	current_save_path = output_path
	current_city_saved_once = true
	saved_city_snapshot = result.data.duplicate()
	status_label.theme_type_variation = ""
	status_label.text = "Saved city: %s" % output_path
	_sync_upgrade_city_option()

	return true


func _sync_map_style() -> void:
	# use the published texture until the mode change finishes
	if map_view != null:
		map_view.dark_underground = app_dark_underground and static_render_mode == "underground" and map_view.base_palette_lookup_all


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
	status_label.theme_type_variation = ""
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

	if city_status_bar != null:
		var speed_name := speed_controller.speed_name() if speed_controller != null else "--"
		city_status_bar.set_speed(speed_name)


func _refresh_after_city_edit(command: Dictionary) -> void:
	_refresh_scurk_artwork()

	if command.get("command_type", "") == "scurk_artwork":
		return

	if not _apply_static_edit_patch(command):
		_refresh_map(false)


func _apply_static_edit_patch(command: Dictionary) -> bool:
	if region_cache != null:
		var indices := _edit_dirty_indices(command, city.map_size)

		if indices.is_empty():
			return false

		var dirty := IsometricRenderer.dirty_screen_rect(indices, _sprite_archive_for_view(_city_view_size()), _city_view_size(), Vector2i.ZERO, city.map_size)
		_refresh_region_map(false, dirty)

		return true

	var map_edge: int = city.map_size if city != null else 128

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

	var profile_start := Time.get_ticks_usec()
	var dirty_indices := _edit_dirty_indices(command, map_edge)

	if dirty_indices.is_empty():
		return false

	var view_size := _city_view_size()
	var sprite_archive := _sprite_archive_for_view(view_size)
	var dirty_rect := IsometricRenderer.dirty_screen_rect(
		dirty_indices, sprite_archive, view_size, Vector2i.ZERO, map_edge
	)
	var full_area := IsometricRenderer.output_size_for_view(view_size, map_edge).x * (
		IsometricRenderer.output_size_for_view(view_size, map_edge).y
	)

	if (
		dirty_rect.get_area() <= 0
		or float(dirty_rect.get_area()) / float(full_area)
			> STATIC_EDIT_PATCH_MAX_AREA_RATIO
	):
		return false

	edit_display_timings = {"dirty_ms": (Time.get_ticks_usec() - profile_start) / 1000.0}
	profile_start = Time.get_ticks_usec()
	var display_city := ViewFilter.surface_copy(city, surface_visibility)

	if display_city == null or not display_city.is_valid():
		return false

	edit_display_timings.copy_ms = (Time.get_ticks_usec() - profile_start) / 1000.0
	profile_start = Time.get_ticks_usec()
	var patched := IsometricRenderer.patch_static_image(
		static_city_image,
		display_city,
		palette_index_encoding,
		sprite_archive,
		dirty_indices,
		view_size,
		int(IntegerMath.div_trunc(Time.get_ticks_msec(), 100)),
		false
	)

	if not patched.get("ok", false):
		return false

	edit_display_timings.patch_ms = (Time.get_ticks_usec() - profile_start) / 1000.0
	profile_start = Time.get_ticks_usec()
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
	edit_display_timings.occlusion_ms = (Time.get_ticks_usec() - profile_start) / 1000.0
	profile_start = Time.get_ticks_usec()
	var texture := CityMapTexture.update_region(map_view.city_texture, static_city_image, patched.output_rect)
	map_view.set_city_view(static_display_city, texture, texture, true)
	_sync_map_style()
	_refresh_moving_things(view_size)
	edit_display_timings.upload_ms = (Time.get_ticks_usec() - profile_start) / 1000.0

	return true


static func _collect_changed_tiles(before: PackedByteArray, after: PackedByteArray, stride: int, seen: Dictionary, plane_cells := 0) -> void:
	# skip unchanged byte blocks
	# changed blocks still need tile checks, including remote power/water changes
	if before == after:
		return

	var block_bytes := 256 * stride

	for start in range(0, before.size(), block_bytes):
		var end := mini(start + block_bytes, before.size())

		if before.slice(start, end) == after.slice(start, end):
			continue

		for offset in range(start, end, stride):
			if before[offset] != after[offset] or (stride == 2 and before[offset + 1] != after[offset + 1]):
				var index := int(IntegerMath.div_trunc(offset, stride))
				seen[index % plane_cells if plane_cells > 0 else index] = true


static func _edit_dirty_indices(command: Dictionary, map_edge: int = 128) -> PackedInt32Array:
	var seen := {}
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT"]:
		if not old_payloads.has(chunk_id) or not new_payloads.has(chunk_id):
			continue

		var old_bytes: PackedByteArray = old_payloads[chunk_id]
		var new_bytes: PackedByteArray = new_payloads[chunk_id]
		var stride := 2 if chunk_id == "ALTM" or (chunk_id == "XTXT" and map_edge > 128) else 1

		if (
			old_bytes.size() != (map_edge * map_edge) * stride
			or new_bytes.size() != old_bytes.size()
		):
			continue

		_collect_changed_tiles(old_bytes, new_bytes, 1 if chunk_id == "XTXT" else stride, seen, map_edge * map_edge if chunk_id == "XTXT" else 0)

	if command.has("old_text") and command.has("new_text"):
		var old_text: PackedByteArray = command.old_text
		var new_text: PackedByteArray = command.new_text

		if (
			OverlayData.count(old_text) == (map_edge * map_edge)
			and OverlayData.count(new_text) == (map_edge * map_edge)
		):
			_collect_changed_tiles(old_text, new_text, 1, seen, map_edge * map_edge)

	var tile_indices: PackedInt32Array = command.get(
		"tile_indices", PackedInt32Array()
	)

	for index in tile_indices:
		if index >= 0 and index < (map_edge * map_edge):
			seen[index] = true

	for point_value in command.get("points", []):
		var point: Vector2i = point_value
		var index := point.x * map_edge + point.y

		if point.x >= 0 and point.x < map_edge and point.y >= 0 and point.y < map_edge:
			seen[index] = true

	for point_key in ["point", "target"]:
		if command.has(point_key):
			var point: Vector2i = command[point_key]

			if point.x >= 0 and point.x < map_edge and point.y >= 0 and point.y < map_edge:
				seen[point.x * map_edge + point.y] = true

	if command.has("tile_index"):
		var tile_index := int(command.tile_index)

		if tile_index >= 0 and tile_index < (map_edge * map_edge):
			seen[tile_index] = true

	if command.has("site"):
		var site: Rect2i = command.site

		for x in range(site.position.x, site.end.x):
			for y in range(site.position.y, site.end.y):
				if x >= 0 and x < map_edge and y >= 0 and y < map_edge:
					seen[x * map_edge + y] = true

	var sorted_indices: Array = seen.keys()
	sorted_indices.sort()
	var result := PackedInt32Array()

	for index in sorted_indices:
		result.append(int(index))

	return result


func _refresh_map(force := true) -> void:
	if city == null or palette == null:
		return

	map_view.trip_query_underground = overlay_mode == "underground"
	map_view.set_signs_visible(
		overlay_mode == "city" and bool(surface_visibility.signs)
	)

	if CityDataView.MODES.has(overlay_mode):
		_close_region_cache()
		pending_static_render = false
		map_view.set_dynamic_sprites([])
		map_view.show_transient_effects([])
		map_view.set_data_view(city, overlay_mode)

		return

	map_view.clear_data_view()

	if (city.map_size > 128 or CityRegionCache.gpu_supported(app_city_renderer)) and overlay_mode in ["city", "underground"]:
		_refresh_region_map(force)

		return

	_close_region_cache()
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
			var cached_texture := CityMapTexture.create(static_city_image)
			map_view.set_city_view(
				static_display_city, cached_texture, cached_texture, true
			)
			_sync_map_style()

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
				show_underground_pipes, show_underground_subways
			)
		else:
			indexed = IsometricRenderer.create_image(
				display_city, palette_index_encoding, sprite_archive, view_size,
				int(IntegerMath.div_trunc(Time.get_ticks_msec(), 100)), false, true, true, false
			)

		if not indexed.ok:
			_show_error(indexed.error)

			return

		image = indexed.image

		if view_size != IsometricRenderer.VIEW_LARGE:
			image.resize(
				IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, city.map_size).x,
				IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, city.map_size).y,
				Image.INTERPOLATE_NEAREST,
			)

		static_city_image = image
		var occlusion_commands: Array[Dictionary] = []

		if overlay_mode == "city":
			occlusion_commands = IsometricRenderer.static_occlusion_commands(
				display_city, sprite_archive, view_size
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

	var texture := CityMapTexture.create(image)
	map_view.set_city_view(
		static_display_city if overlay_mode in ["city", "underground"] else city,
		texture, texture if overlay_mode in ["city", "underground"] else null,
		overlay_mode in ["city", "underground"]
	)
	_sync_map_style()

	if overlay_mode == "city":
		_refresh_moving_things(_city_view_size())
	else:
		_refresh_sign_occlusion(_city_view_size())


func _close_region_cache() -> void:
	_clear_dynamic_composition_cache()
	foreground_complete = false

	if region_cache != null:
		region_cache.close()

	region_cache = null


func _refresh_region_map(force: bool, dirty := Rect2i()) -> void:
	if region_cache == null:
		region_cache = CityRegionCache.new()
		region_cache.gpu_enabled = CityRegionCache.gpu_supported(app_city_renderer)

	static_city_image = null
	static_view_cache.clear()
	static_occlusion_commands.clear()
	static_occlusion_grid.clear()
	pending_static_render = false
	var view_size := _city_view_size()
	var sprites := _sprite_archive_for_view(view_size)
	var signature := _static_signature_for_mode(overlay_mode, view_size)
	signature.append(sprites.get_instance_id())

	if force:
		region_cache.signature = []

	region_cache.configure(city, palette_index_encoding, sprites, signature, view_size,
		overlay_mode, surface_visibility, show_underground_pipes, show_underground_subways, dirty)

	if overlay_mode == "city":
		var labels := city.document.find_chunk("XLAB")
		# reuse the altitude and sign/dispatch hashes already computed for this snapshot
		region_cache.sign_layout_token = [city.map_size, signature[1], signature[2], signature[3], signature[9], hash(labels.decoded_payload) if labels != null else 0]
	else:
		region_cache.sign_layout_token = []

	static_visual_signature = signature
	static_render_mode = overlay_mode
	static_display_city = region_cache.display_city
	var texture := region_cache.texture()
	map_view.set_city_view(static_display_city, texture, texture, true, true, region_cache.sign_layout_token)
	_sync_map_style()
	region_cache.set_sign_requests(map_view.sign_source_entries())
	region_cache.update_viewport(map_view.visible_source_rect())

	if overlay_mode == "city":
		_refresh_moving_things(view_size)
	else:
		map_view.set_dynamic_sprites([])
		map_view.set_sign_occlusion_visuals({})


func _poll_region_cache() -> void:
	if region_cache == null or city == null:
		return

	region_cache.update_viewport(map_view.visible_source_rect())

	if not region_cache.tick():
		return

	if not region_cache.last_error.is_empty():
		_show_error(region_cache.last_error)

		return

	static_display_city = region_cache.display_city
	dynamic_occluder_cache.clear()
	var foreground_changed := _invalidate_region_foregrounds(region_cache.foreground_changes)
	var texture := region_cache.texture()
	map_view.set_city_view(static_display_city, texture, texture, true, true, region_cache.sign_layout_token)
	_sync_map_style()

	if overlay_mode == "city":
		if foreground_changed or not foreground_complete or foreground_view_rect != map_view.visible_source_rect():
			_refresh_moving_things(region_cache.view_size)
	else:
		map_view.set_dynamic_sprites([])


func _invalidate_region_foregrounds(changes: Array[Rect2i]) -> bool:
	var invalidated := false

	for key in dynamic_visual_cache.keys():
		var visual: Dictionary = dynamic_visual_cache[key]

		if visual.is_empty():
			dynamic_visual_cache.erase(key)
			continue

		var bounds := Rect2i(Vector2i(visual.position), Vector2i(visual.size))

		for changed in changes:
			if bounds.intersects(changed):
				dynamic_visual_cache.erase(key)
				invalidated = true
				break

	for key in sign_foreground_cache.keys():
		var bounds: Rect2i = sign_foreground_cache[key].signature[1]

		for changed in changes:
			if bounds.intersects(changed):
				sign_foreground_cache.erase(key)
				invalidated = true
				break

	return invalidated


func _static_image_size() -> Vector2i:
	return region_cache.native_size * region_cache.divisor if region_cache != null else (static_city_image.get_size() if static_city_image != null else Vector2i.ZERO)


func _static_pixel(x: int, y: int) -> Color:
	return region_cache.pixel(Vector2i(x, y)) if region_cache != null else static_city_image.get_pixel(x, y)


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

	snapshot.visible_altitude_levels = city.visible_altitude_levels
	static_render_job = RenderJob.new()
	static_render_job.city_snapshot = snapshot
	static_render_job.index_palette = palette_index_encoding
	static_render_job.sprites = sprite_archive
	static_render_job.view_size = view_size
	static_render_job.animation_phase = int(IntegerMath.div_trunc(Time.get_ticks_msec(), 100))
	static_render_job.signature = signature.duplicate()
	static_render_job.epoch = static_render_epoch
	static_render_job.render_mode = render_mode
	static_render_job.surface_visibility = surface_visibility.duplicate()
	static_render_job.show_underground_subways = show_underground_subways
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
	_poll_region_cache()

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
	var texture := CityMapTexture.create(static_city_image)
	map_view.set_city_view(
		static_display_city, texture, texture, true
	)
	_sync_map_style()

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
			city, view_size, show_underground_pipes, show_underground_subways
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
	_close_region_cache()

	if frame_simulation != null:
		frame_simulation.close()

	frame_simulation = null

	if static_render_thread != null and static_render_thread.is_started():
		static_render_thread.wait_to_finish()

	static_render_thread = null
	static_render_job = null


func _update_palette_cycle_texture() -> void:
	if palette == null or not palette.is_valid():
		return

	toolbar_animation_palette = Sc2Palette.new()

	for color_index in palette.animation_index_map(palette_cycle_ticks):
		toolbar_animation_palette.colors.append(palette.colors[color_index])

	_refresh_child_tool_icons()
	var image := palette.animation_image(palette_cycle_ticks)

	if palette_cycle_texture == null:
		palette_cycle_texture = ImageTexture.create_from_image(image)
	else:
		palette_cycle_texture.update(image)

	if map_view != null:
		map_view.set_animated_palette(palette_cycle_texture)


func _city_graphics_size() -> int:
	return SettingsStore.graphics_size_at_zoom(app_zoom_graphics, map_view.zoom_percent(), app_overview_graphics)


func _city_view_size() -> int:
	return mini(_city_graphics_size(), IsometricRenderer.VIEW_LARGE)


func _sprite_archive_for_view(view_size: int) -> Sc2SpriteArchive:
	return small_medium_sprites if view_size < IsometricRenderer.VIEW_LARGE else large_sprites


func _refresh_moving_things(view_size := -1) -> void:
	if city == null or palette == null or map_view == null or overlay_mode != "city":
		dynamic_sign_occluders.clear()
		dynamic_sign_occlusion_grid.clear()

		if map_view != null:
			map_view.set_dynamic_sprites([])

		return

	if region_cache != null and region_cache.gpu_enabled and not region_cache.covered():
		foreground_complete = false
		map_view.set_dynamic_sprites([])
		map_view.set_sign_occlusion_visuals({})

		return

	if dynamic_visual_cache.size() > 4096:
		dynamic_visual_cache.clear()

	if view_size < 0:
		view_size = _city_view_size()

	var sprite_archive := _sprite_archive_for_view(view_size)
	var configuration := IsometricRenderer.view_configuration(view_size)
	var divisor := int(configuration.divisor)
	var factor := 1
	var commands := dynamic_command_cache.get_commands(
		city, sprite_archive, view_size, int(IntegerMath.div_trunc(Time.get_ticks_msec(), 100))
	)
	var visuals: Array[Dictionary] = []

	for command in commands:
		if region_cache != null and not Rect2(Vector2(command.position) * divisor, Vector2(command.get("size", Vector2i(256, 256))) * divisor).intersects(map_view.visible_source_rect().grow(256 * divisor)):
			continue

		var visual_cache_key := var_to_str([view_size, factor, command])

		if dynamic_visual_cache.has(visual_cache_key):
			var cached: Dictionary = dynamic_visual_cache[visual_cache_key]

			if not cached.is_empty() and not bool(cached.get("hidden", false)):
				visuals.append(cached)

			continue

		var resource := _dynamic_sprite_resource(
			sprite_archive, command.sprite_id, command.flip, divisor, factor
		)

		if resource.is_empty():
			continue

		var position := Vector2i(command.position) * divisor
		var texture: Texture2D = resource.texture
		var index_texture: Texture2D = resource.index_texture
		var visual_image: Image = resource.image
		var occluder_mask: Image

		if bool(command.get("static_occlusion", true)):
			occluder_mask = _dynamic_occluder_image(
				sprite_archive, divisor, position, resource.native_size,
				int(command.get("depth_order", -1)), bool(command.get("train", false)), factor
			)

		if command.shadow:
			var shadow_image := _dynamic_shadow_image(resource.image, position, occluder_mask, factor)

			if shadow_image == null:
				dynamic_visual_cache[visual_cache_key] = {"hidden": true, "position": Vector2(position), "size": Vector2(resource.native_size)}
				continue

			visual_image = shadow_image
			texture = ImageTexture.create_from_image(shadow_image)
			index_texture = null
		else:
			var foreground_indices: PackedInt32Array = command.get("same_tile_foreground_indices", PackedInt32Array())
			var index_reader := Callable()

			if region_cache != null and not foreground_indices.is_empty():
				var sampled := region_cache.image_region(Rect2i(position, resource.native_size), factor)
				index_reader = func(x: int, y: int) -> Color:
					return sampled.get_pixel(x - position.x * factor, y - position.y * factor)

			var occluded := IsometricRenderer.occlude_dynamic_with_mask(
				resource.image, occluder_mask, position * factor, static_city_image,
				foreground_indices, index_reader
			)

			if int(occluded.occluded_pixels) > 0:
				visual_image = occluded.image
				texture = ImageTexture.create_from_image(occluded.image)
				index_texture = texture

		var visual := {
			"texture": texture,
			"index_texture": index_texture,
			"palette_lookup_all": true,
			"texture_factor": factor,
			"position": Vector2(position),
			"size": Vector2(resource.native_size),
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
	foreground_view_rect = map_view.visible_source_rect()
	foreground_complete = true


func _refresh_sign_occlusion(view_size: int) -> void:
	if (
		overlay_mode != "city"
		or not bool(surface_visibility.signs)
		or city == null
		or map_view == null
		or (static_city_image == null and region_cache == null)
		or (static_occlusion_commands.is_empty() and region_cache == null)
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
	var factor := 1

	if static_occlusion_grid.is_empty() and region_cache == null:
		static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
			static_occlusion_commands, divisor
		)

	var color_indices := palette.animation_index_map(palette_cycle_ticks)
	var gpu_palette := region_cache != null and region_cache.gpu_enabled
	var image_bounds := Rect2i(Vector2i.ZERO, _static_image_size())
	var visuals := {}

	for entry in entries:
		var source_bounds: Rect2i = entry.bounds

		if region_cache != null and not Rect2(source_bounds).intersects(map_view.visible_source_rect().grow(128)):
			continue

		var bounds := source_bounds.intersection(image_bounds)

		if bounds.get_area() <= 0:
			continue

		var moving_candidates: Array[Dictionary] = []

		for moving_index in IsometricRenderer.occlusion_candidate_indices(dynamic_sign_occlusion_grid, bounds):
			moving_candidates.append(dynamic_sign_occluders[moving_index])

		var signature := [view_size, bounds, int(entry.draw_order), moving_candidates]
		var key := int(entry.key)

		if sign_foreground_cache.has(key) and sign_foreground_cache[key].signature == signature:
			var cached: Dictionary = sign_foreground_cache[key]

			if cached.indices != null:
				var palette_signature := 0 if gpu_palette else _sign_palette_signature(cached.used_indices, color_indices)

				if not gpu_palette and int(cached.palette_signature) != palette_signature:
					cached.visual.texture = ImageTexture.create_from_image(_sign_palette_image(cached.indices, color_indices))
					cached.palette_signature = palette_signature

				visuals[key] = cached.visual

			continue

		var foreground: Image = region_cache.sign_foreground(key, bounds, int(entry.draw_order), factor) if gpu_palette else null

		if foreground == null:
			var masks: Array[Dictionary] = []

			for command in _static_occlusion_candidates(bounds):
				if int(command.depth_order) <= int(entry.draw_order):
					continue

				var position := Vector2i(command.position) * divisor

				if not bounds.intersects(Rect2i(position, Vector2i(command.size) * divisor)):
					continue

				var resource := _dynamic_sprite_resource(sprite_archive, int(command.sprite_id), bool(command.flip), divisor, factor)

				if not resource.is_empty():
					masks.append({"image": resource.image, "position": position * factor})

			var sampled: Image = region_cache.image_region(bounds, factor) if region_cache != null else static_city_image.get_region(bounds)
			foreground = CitySignForeground.static_pixels(sampled, masks, Rect2i(bounds.position * factor, bounds.size * factor))

		for visual in MapControl.later_sign_occluder_visuals(moving_candidates, bounds, int(entry.draw_order)):
			var moving_image: Image = visual.get("image") as Image

			if moving_image != null:
				CitySignForeground.add_moving(foreground, moving_image, Vector2i(visual.position) * factor, Rect2i(bounds.position * factor, bounds.size * factor))

		var used_indices := {} if gpu_palette else CitySignForeground.used_indices(foreground)
		var empty_foreground := foreground.is_invisible() if gpu_palette else used_indices.is_empty()

		if empty_foreground:
			sign_foreground_cache[key] = {"signature": signature, "indices": null}
			continue

		var texture: Texture2D
		var previous: Dictionary = map_view.sign_occlusion_visuals.get(key, {})

		if gpu_palette and bool(previous.get("indexed", false)) and previous.has("indices") and previous.indices.get_size() == foreground.get_size() and previous.indices.get_data() == foreground.get_data():
			foreground = previous.indices
			texture = previous.texture
		else:
			texture = ImageTexture.create_from_image(foreground if gpu_palette else _sign_palette_image(foreground, color_indices))

		visuals[int(entry.key)] = {
			"indexed": gpu_palette,
			"indices": foreground if gpu_palette else null,
			"texture": texture,
			"position": Vector2(bounds.position),
			"size": Vector2(bounds.size),
		}
		sign_foreground_cache[key] = {"signature": signature, "indices": foreground, "palette_signature": 0 if gpu_palette else _sign_palette_signature(used_indices, color_indices), "used_indices": used_indices, "visual": visuals[key]}

	map_view.set_sign_occlusion_visuals(visuals)


func _static_occlusion_candidates(bounds: Rect2i) -> Array[Dictionary]:
	if region_cache != null:
		return region_cache.occlusion_candidates(bounds)

	var result: Array[Dictionary] = []

	for index in IsometricRenderer.occlusion_candidate_indices(static_occlusion_grid, bounds):
		result.append(static_occlusion_commands[index])

	return result


func _dynamic_occluder_image(
	sprite_archive: Sc2SpriteArchive,
	divisor: int,
	position: Vector2i,
	size: Vector2i,
	draw_order: int,
	is_train := false, texture_factor := 1
) -> Image:
	if draw_order < 0 or (static_occlusion_commands.is_empty() and region_cache == null):
		return null

	var cache_key := "%d:%d:%d:%d:%d:%d:%d:%d" % [
		position.x, position.y, size.x, size.y, draw_order, int(is_train),
		static_render_epoch, texture_factor,
	]

	if dynamic_occluder_cache.has(cache_key):
		return dynamic_occluder_cache[cache_key] as Image

	var bounds := Rect2i(position, size)

	if static_occlusion_grid.is_empty() and region_cache == null:
		static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
			static_occlusion_commands, divisor
		)

	var mask: Image

	# Bounding boxes include transparent pixels. Combine all later silhouettes
	# to find the foreground that actually covers the sprite.
	for command in _static_occlusion_candidates(bounds):
		if is_train and bool(command.get("train_ignore", false)):
			continue

		var later_static := int(command.depth_order) > draw_order
		var train_foreground := (
			is_train and (command.has("train_foreground_reference_sprite_id") or command.has("train_deck_thickness"))
			and (not (bool(command.get("train_foreground_requires_depth", false)) or command.has("train_deck_thickness"))
				or int(command.depth_order) >= draw_order)
		)
		var use_later_static := (
			later_static and not train_foreground
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
			sprite_archive, int(command.sprite_id), bool(command.flip), divisor, texture_factor
		)

		if resource.is_empty():
			continue

		var occluder_image: Image = resource.image

		if train_foreground:
			occluder_image = _dynamic_train_foreground_image(
				sprite_archive, command, divisor, resource.image, texture_factor
			)

		if mask == null:
			mask = Image.create(size.x * texture_factor, size.y * texture_factor, false, Image.FORMAT_RGBA8)
			mask.fill(Color.TRANSPARENT)

		mask.blend_rect(
			occluder_image,
			Rect2i((overlap.position - occluder_position) * texture_factor, overlap.size * texture_factor),
			(overlap.position - position) * texture_factor,
		)

	dynamic_occluder_cache[cache_key] = mask

	return mask


func _set_static_occlusion_commands(commands: Array, view_size: int) -> void:
	static_occlusion_commands.assign(commands)
	dynamic_occluder_cache.clear()
	dynamic_visual_cache.clear()
	sign_foreground_cache.clear()
	dynamic_special_batch_cache.clear()
	var divisor := int(IsometricRenderer.view_configuration(view_size).divisor)
	static_occlusion_grid = IsometricRenderer.build_occlusion_grid(
		static_occlusion_commands, divisor
	)


func _dynamic_train_foreground_image(
	sprite_archive: Sc2SpriteArchive,
	command: Dictionary,
	divisor: int,
	surface: Image, texture_factor := 1
) -> Image:
	if command.has("train_deck_thickness"):
		var deck_key := "deck:%d:%d:%d:%d" % [int(command.sprite_id), int(command.flip), divisor, texture_factor]

		if dynamic_foreground_cache.has(deck_key):
			return dynamic_foreground_cache[deck_key]

		var deck_surface := surface

		# a highway/power crossing uses the wire-free highway as its mask
		if command.has("train_deck_reference_sprite_id"):
			var background := _dynamic_sprite_resource(sprite_archive, int(command.train_deck_reference_sprite_id), bool(command.flip), divisor, texture_factor)

			if not background.is_empty():
				deck_surface = Image.create(surface.get_width(), surface.get_height(), false, Image.FORMAT_RGBA8)
				deck_surface.blit_rect(background.image, Rect2i(Vector2i.ZERO, background.image.get_size()), Vector2i(0, surface.get_height() - background.image.get_height()))

		var deck := IsometricRenderer.highway_train_deck_mask(deck_surface, int(command.train_deck_thickness) * divisor * texture_factor)
		dynamic_foreground_cache[deck_key] = deck

		return deck

	var reference_sprite_id := int(command.train_foreground_reference_sprite_id)

	if reference_sprite_id < 0:
		return surface

	var key := "%d:%d:%d:%d:%d" % [
		int(command.sprite_id), int(command.flip), divisor, reference_sprite_id, texture_factor,
	]

	if dynamic_foreground_cache.has(key):
		return dynamic_foreground_cache[key]

	var reference := _dynamic_sprite_resource(
		sprite_archive, reference_sprite_id, bool(command.flip), divisor, texture_factor
	)

	if reference.is_empty():
		return surface

	var foreground := IsometricRenderer.foreground_difference_mask(
		surface, reference.image
	)
	dynamic_foreground_cache[key] = foreground

	return foreground


func _dynamic_sprite_resource(
	sprite_archive: Sc2SpriteArchive, sprite_id: int, flip: bool, divisor: int, texture_factor := 1
) -> Dictionary:
	var key := "%d:%d:%d:%d:%d" % [sprite_id, int(flip), divisor, texture_factor, sprite_archive.get_instance_id()]

	if dynamic_sprite_cache.has(key):
		return dynamic_sprite_cache[key]

	var entry := sprite_archive.find_sprite(sprite_id)

	if entry == null:
		return {}

	var native_size := Vector2i(entry.width, entry.height) * divisor
	var indexed := entry.create_image(palette_index_encoding)

	if not indexed.ok:
		return {}

	var image: Image = indexed.image

	if flip or divisor > 1 or image.get_size() != native_size * texture_factor:
		image = image.duplicate()

	if flip:
		image.flip_x()

	if image.get_size() != native_size * texture_factor:
		image.resize(
			native_size.x * texture_factor,
			native_size.y * texture_factor,
			Image.INTERPOLATE_NEAREST
		)

	var texture := ImageTexture.create_from_image(image)
	var resource := {
		"image": image,
		"native_size": native_size,
		"texture": texture,
		"index_texture": texture,
	}
	dynamic_sprite_cache[key] = resource

	return resource


func _dynamic_shadow_image(
	mask: Image, position: Vector2i, occluder_mask: Image = null, texture_factor := 1
) -> Image:
	if static_city_image == null and region_cache == null:
		return null

	var shadow := Image.create(
		mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8
	)
	shadow.fill(Color.TRANSPARENT)
	var changed_pixels := 0
	@warning_ignore("integer_division")
	var sampled: Image = region_cache.image_region(Rect2i(position, mask.get_size() / texture_factor), texture_factor) if region_cache != null else null

	for source_y in mask.get_height():
		var output_y := position.y + int(IntegerMath.div_trunc(source_y, texture_factor))

		if output_y < 0 or output_y >= _static_image_size().y:
			continue

		for source_x in mask.get_width():
			if mask.get_pixel(source_x, source_y).a == 0.0:
				continue

			if (
				occluder_mask != null
				and occluder_mask.get_pixel(source_x, source_y).a > 0.0
			):
				continue

			var output_x := position.x + int(IntegerMath.div_trunc(source_x, texture_factor))

			if output_x < 0 or output_x >= _static_image_size().x:
				continue

			var current: Color = sampled.get_pixel(source_x, source_y) if sampled != null else static_city_image.get_pixel(output_x, output_y)
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

	effect_events = _parallel_dust_events(effect_events)
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
	if city == null or audio_controller == null:
		return

	audio_controller.play_sound_events(
		sound_events, city.sound_enabled(), overlay_mode, _city_view_size()
	)


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
	if audio_controller != null:
		audio_controller.start_tool_loop_sound(
			sound_id, city != null and city.sound_enabled()
		)


func _stop_tool_loop_sound() -> void:
	if audio_controller != null:
		audio_controller.stop_tool_loop_sound()


func _show_news_items(news_items: Array) -> void:
	if city_status_bar != null:
		city_status_bar.prepend_news_items(news_items)

	_refresh_status_summary()


func _show_forest_protest() -> void:
	if forest_protest_dialog == null:
		return

	forest_protest_dialog.show_message(forest_protest_text)


func _show_building_objection() -> void:
	if building_objection_dialog == null:
		return

	building_objection_dialog.show_message(building_objection_text, true)


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
		if city_status_bar != null:
			city_status_bar.set_reports(PackedStringArray())

		_refresh_status_summary()

		return

	var misc_chunk := current_document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		if city_status_bar != null:
			city_status_bar.set_reports(PackedStringArray(["Unavailable"]))

		_refresh_status_summary()

		return

	var reports := PackedStringArray()

	for slot in NewsQueue.QUEUE_COUNT:
		var record := NewsQueue.story_record(misc_chunk.decoded_payload, slot)

		if record.is_empty() or int(record.priority) <= 0:
			continue

		var story_type := int(record.type)
		reports.append(CityStatusBar.report_name(story_type))

		if reports.size() == 3:
			break

	if city_status_bar != null:
		city_status_bar.set_reports(reports)

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
	status_label.theme_type_variation = "WarningLabel"
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
	if terrain_stretch.active:
		map_view.cancel_active_selection()

	if landscape_editor and index not in [0, 1, 16, 17]:
		return

	if index < 0 or index >= Tools.GROUPS.size():
		return

	selected_group = index

	if selected_group == Dispatch.GROUP_DISPATCH:
		dispatch_cycles = PackedInt32Array([0, 0, 0])
		dispatch_initialized = false

	selected_subtool = city_toolbar.show_tool_group(
		selected_group, city, _tool_button_icon
	)
	_auto_select_underground()
	_sync_child_tool_selection()
	_update_edit_state()


func _auto_select_underground() -> void:
	# query, camera and bulldozer work in both views
	if selected_group in [16, 17] or (overlay_mode in ["city", "underground"] and Demolish.supports_tool(selected_group, selected_subtool)):
		return

	if city == null:
		return

	var underground_tool := (selected_group == 4 and selected_subtool == 0) or (selected_group == 7 and selected_subtool == 1)
	var target := "underground" if underground_tool else "city"

	if overlay_mode != target:
		_set_overlay(target)


func _select_subtool(index: int) -> void:
	if terrain_stretch.active:
		map_view.cancel_active_selection()

	if not landscape_editor and LandscapeEditorCommand.supports_tool(selected_group, index) and not (selected_group == 1 and index == 3):
		return

	if landscape_editor and (selected_group not in [0, 1, 16, 17] or (selected_group == 0 and index == 4)):
		return

	if selected_group == 2 and index == 3:
		var recalled := Dispatch.recall_all(city)

		if recalled.ok:
			recalled["dispatch_cycles_before"] = dispatch_cycles.duplicate()
			recalled["dispatch_initialized_before"] = dispatch_initialized
			last_edit_command = recalled
			dispatch_cycles = PackedInt32Array([0, 0, 0])
			dispatch_initialized = false
			_refresh_after_city_edit(recalled)
			status_label.text = "All emergency services recalled."

		_sync_child_tool_selection()

		return

	selected_subtool = index
	_auto_select_underground()
	_sync_child_tool_selection()
	_update_edit_state()

	if landscape_editor and selected_group == 0 and index in [6, 7]:
		_apply_map_selection(Vector2i.ZERO, Vector2i.ZERO, [Vector2i.ZERO], false)

	if selected_tool_available and ToolState.is_tool_chooser(selected_group, selected_subtool):
		_open_tool_choice_dialog(selected_group)


func _sync_child_tool_selection() -> void:
	if city_toolbar != null:
		city_toolbar.sync_child_tool_selection(selected_group, selected_subtool)


func _refresh_tool_availability() -> bool:
	if city == null or city_toolbar == null:
		return false

	return city_toolbar.refresh_tool_availability(
		city, selected_group, selected_subtool, selected_tool_available
	)


func _update_edit_state() -> void:
	if map_view == null:
		return

	var state: Dictionary
	_refresh_scurk_artwork()
	map_view.desktop_cursor_app = "city"
	map_view.desktop_cursor_role = DesktopCursorRules.city_tool(selected_group, selected_subtool)

	if scurk_place_print != null and scurk_place_print.visible:
		map_view.desktop_cursor_app = "scurk"

		if scurk_place_print.is_object_mode():
			map_view.desktop_cursor_role = 9
			state = ToolState.scurk_object(
				city, overlay_mode, scurk_place_print.selected_tile_id
			)
		else:
			var cursor_tool := scurk_place_print.selected_edit_tool()
			map_view.desktop_cursor_role = DesktopCursorRules.city_tool(cursor_tool.group, cursor_tool.subtool)
			state = ToolState.scurk_tool(
				city, scurk_place_print.selected_edit_tool()
			)
	else:
		state = ToolState.normal(
			city, overlay_mode, selected_group, selected_subtool
		)
		selected_tool_available = bool(state.available)

	map_view.shift_rectangle_enabled = (bool(state.landscape) and selected_subtool != 3) or (landscape_editor and selected_group == 0 and selected_subtool in [1, 2, 3])
	map_view.continuous_placement = selected_group == 1 and selected_subtool == 3
	map_view.shift_line_enabled = selected_group == 1 and selected_subtool in [0, 1]

	if map_view.shift_line_enabled:
		state.selection = "rectangle"
		map_view.shift_rectangle_enabled = false

	map_view.placement_validator = _placement_preview_valid

	if landscape_editor and LandscapeEditorCommand.supports_tool(selected_group, selected_subtool):
		state.enabled = true
		state.available = true
		selected_tool_available = true
		state.selection = "point"
		state.area = 7 if selected_group == 1 and selected_subtool == 3 else 1
		state.status_text = str(Tools.tool(selected_group, selected_subtool).name)
		state.status_detail = "Drag up or down to stretch terrain live. Hold Shift to apply on release." if selected_group == 0 and selected_subtool == 5 else "Free landscape editor tool."

	map_view.stretch_terrain = landscape_editor and selected_group == 0 and selected_subtool == 5
	map_view.placement_error_provider = _placement_preview_error
	map_view.show_selection_preview = selected_group != 17
	map_view.terrain_diamond_preview = selected_group == 0 and selected_subtool in [2, 3, 5]
	map_view.highway_preview = selected_group == 6 and selected_subtool == 1
	map_view.query_footprint_preview = selected_group == 16
	if selected_group != 16 or selected_subtool != 1:
		map_view.clear_trip_reach()
	if selected_group != 16 or selected_subtool != 2:
		map_view.clear_service_query()
	map_view.query_city = city
	map_view.set_edit_enabled(
		bool(state.enabled),
		str(state.selection),
		int(state.area),
		bool(state.landscape),
	)
	_refresh_status_summary()

	if status_label == null or not bool(state.show_status):
		return

	status_label.theme_type_variation = ""
	status_label.text = str(state.status_text)
	status_label.set_meta("status_tooltip_text", str(state.status_detail))
	city_status_bar.refresh_message_tooltip()


func _apply_map_selection(
	start: Vector2i,
	finish: Vector2i,
	path: Array[Vector2i],
	dragged: bool
) -> void:
	if city == null:
		return

	if landscape_editor and (selected_group not in [0, 1, 16, 17] or (selected_group == 0 and selected_subtool == 4)):
		_show_error("Select Start City before building structures.")

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

	if not scurk_tool_mode and not landscape_editor and not ToolAvailability.is_available(
		city, selected_group, selected_subtool
	):
		_show_error(
			"%s is not available in this city."
			% Tools.tool(selected_group, selected_subtool).name
		)

		return

	if selected_group == 17:
		_center_map_on_tile(finish)

		return

	if selected_group == 16:
		if selected_subtool == 1:
			map_view.show_trip_reach(city, finish)
		elif selected_subtool == 2:
			var result := map_view.show_service_query(city, finish, map_view._shift_pressed)
			if not result.ok:
				_show_error(str(result.error))
		else:
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
		_refresh_after_city_edit(dispatch)
		_play_tool_success_sound(selected_group, selected_subtool)
		status_label.theme_type_variation = ""
		status_label.text = "Deployed %s unit %d of %d." % [
			Tools.tool(selected_group, selected_subtool).name,
			dispatch.slot_index,
			dispatch.available,
		]

		return

	if LandscapeEditorCommand.supports_tool(selected_group, selected_subtool) and landscape_editor and not (selected_group == 1 and selected_subtool == 3):
		var levels := map_view.stretch_height_delta if dragged else 1

		if terrain_stretch.active:
			_refresh_terrain_stretch(levels)
			var committed := terrain_stretch.finish()

			if not committed.is_empty():
				_stop_tool_loop_sound()
				_play_sound_events([ToolSounds.SOUND_TRACTOR])
				_record_edit_command(committed)
				_refresh_details()

			status_label.text = "Stretch Terrain applied for $0."

			return

		var command := LandscapeEditorCommand.apply(city, selected_group, selected_subtool, start, tool_random, levels)
		_finish_simple_edit(SimpleEdits._result("terrain", command, selected_group, selected_subtool, true), false, {})

		return

	var simple_edit := SimpleEdits.apply_supported(
		city,
		selected_group,
		selected_subtool,
		start,
		finish,
		path,
		tool_random,
		overlay_mode == "underground",
		scurk_tool_mode or landscape_editor
	)

	if simple_edit.handled:
		_finish_simple_edit(simple_edit, scurk_tool_mode, scurk_tool)

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

			if building.get("resident_objection", false):
				_play_sound_events(building.get("sound_events", []))
				pending_building_objection_group = building_group
				pending_building_objection_subtool = building_subtool
				_show_building_objection()
				status_label.theme_type_variation = ""
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
		var stadium_team_pending := bool(
			building.get("stadium_team_selection_required", false)
		)

		if not stadium_team_pending:
			_play_tool_success_sound(building_group, building_subtool, scurk_tool_mode)

		_refresh_details()
		_refresh_after_city_edit(building)

		if building_group == 5 and building_subtool < 4:
			_choose_tool_group(17)

		if building_group == 14 and city.music_enabled() and not stadium_team_pending:
			_play_music_track(Music.RECREATION_TRACK)

		status_label.theme_type_variation = ""
		status_label.text = "Built %s for $%s." % [
			building_name,
			_format_number(building.cost),
		]

		if stadium_team_pending:
			_open_stadium_dialog(building)
			status_label.text += " Select a stadium team."

		return

	var zone_edit := SimpleEdits.apply_zone(
		city,
		selected_group,
		selected_subtool,
		start,
		finish,
		dragged,
		scurk_tool_mode,
		int(scurk_tool.get("zone", -1))
	)
	_finish_simple_edit(zone_edit, scurk_tool_mode, scurk_tool)


func _finish_simple_edit(
	edit: Dictionary, scurk_tool_mode: bool, scurk_tool: Dictionary
) -> void:
	var command: Dictionary = edit.command

	if not command.ok:
		if edit.play_failure_sound:
			_play_tool_failure_sound(
				selected_group, selected_subtool, str(command.error), scurk_tool_mode
			)

		_show_error(str(edit.message))

		return

	if edit.record_command:
		_record_edit_command(
			command, scurk_tool_mode, String(scurk_tool.get("name", ""))
		)
	else:
		last_edit_command = command

	if edit.refresh_details:
		_refresh_details()

	_refresh_after_city_edit(command)

	if edit.show_effects:
		_show_effect_events(
			command.get("effect_events", []), command.get("sound_events", [])
		)

	if selected_group == 0 and selected_subtool in [1, 2, 3, 5, 6, 7] and not command.get("changed_ids", []).is_empty():
		_stop_tool_loop_sound()
		_play_sound_events([ToolSounds.SOUND_TRACTOR])

	if edit.show_forest_protest:
		_refresh_saved_news_summary()
		_show_forest_protest()

	if command.get("command_type", "") == "zone":
		_play_sound_events(ToolSounds.zone_success_events(int(command.zone_type)))
	elif edit.play_success_sound:
		_play_tool_success_sound(selected_group, selected_subtool, scurk_tool_mode)

	status_label.theme_type_variation = ""
	status_label.text = str(edit.message)


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
		status_label.theme_type_variation = ""
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
		var message := (
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
		network_connection_dialog.show_message(message, "Keep %s" % tool_name)

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
	status_label.theme_type_variation = ""
	var dry_count := int(network.get("dry_points", []).size())

	if int(network.get("bridge_count", 0)) > 1:
		status_label.text = "Built %d %s tiles and %d bridges for $%s." % [dry_count, tool_name, network.bridge_count, _format_number(int(network.cost))]
	elif network.get("bridge_built", false):
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

	if not String(network.get("continuation_error", "")).is_empty():
		status_label.text += " Route stopped: %s." % network.continuation_error
	elif network.get("bridge_built", false) and network.get("stopped_early", false):
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
	var title_text := (
		"Select Power Plant" if group_index == 3 else "Select Arcology"
	)
	var prompt_text := (
		"Select an available power plant."
		if group_index == 3
		else "Select an available arcology."
	)
	var available_tools: Array[Dictionary] = []

	for subtool_index in choices:
		available_tools.append(Tools.tool(group_index, subtool_index))

	tool_choice_dialog.show_tools(title_text, prompt_text, available_tools)


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
	var teams: Array[Dictionary] = []

	for team_index in choices:
		teams.append({
			"id": team_index,
			"name": Buildings.stadium_team_name(city, team_index),
		})

	stadium_dialog.show_teams(teams)


func _confirm_stadium_team() -> void:
	if pending_stadium_command.is_empty():
		return

	var team_index := stadium_dialog.selected_team_id()

	if team_index < 0:
		_show_error("Select a stadium team.")
		call_deferred("_restore_stadium_dialog")

		return

	var result := Buildings.assign_stadium_team(
		city,
		pending_stadium_command,
		team_index,
		stadium_dialog.entered_name(),
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

	status_label.theme_type_variation = ""
	status_label.text = "Assigned %s to the new stadium." % result.team_name


func _cancel_stadium_team() -> void:
	pending_stadium_command.clear()
	_play_tool_success_sound(14, 3)

	if city != null and city.music_enabled():
		_play_music_track(Music.RECREATION_TRACK)

	status_label.theme_type_variation = ""
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
	var choices: Array = pending_bridge_request.choices
	bridge_dialog.preview_palette = palette
	bridge_dialog.preview_sprites = large_sprites
	bridge_dialog.show_choices(
		int(result.get("bridge_span_length", 0)),
		request_type,
		choices,
		free_mode,
	)


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
		status_label.theme_type_variation = ""
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
		var message := (
			"Engineers report that tunnel construction costs will be $%s.\n"
			+ "Do you wish to construct the tunnel?"
		) % _format_number(int(tunnel.cost))
		tunnel_dialog.show_message(message)

		return

	if tunnel.get("cancelled", false):
		_play_tool_failure_sound(
			selected_group, selected_subtool, "cancelled", free_mode
		)
		status_label.theme_type_variation = ""
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
	status_label.theme_type_variation = ""
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
		status_label.theme_type_variation = ""
		status_label.text = "Bridge selection canceled. No action was taken."

		return

	if highway.get("connection_selection_required", false):
		pending_highway_connection = {
			"start": start,
			"finish": finish,
			"group_index": selected_group,
			"subtool_index": selected_subtool,
			"free_mode": free_mode,
			"bridge_type": bridge_type,
		}
		var message := (
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
		highway_connection_dialog.show_message(message)

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
	status_label.theme_type_variation = ""

	if int(highway.get("bridge_count", 0)) > 1:
		status_label.text = "Built %d highway sections and %d bridges for $%s." % [highway.sections.size(), highway.bridge_count, _format_number(int(highway.cost))]
	elif highway.get("bridge_built", false):
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

	if not String(highway.get("continuation_error", "")).is_empty():
		status_label.text += " Route stopped: %s." % highway.continuation_error
	elif highway.get("bridge_built", false) and highway.get("stopped_early", false):
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
		int(request.get("bridge_type", Highways.BRIDGE_UNSELECTED)),
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
	_refresh_details()
	_refresh_after_city_edit(undone_command)

	if undo_forest_protest:
		_refresh_saved_news_summary()

	status_label.theme_type_variation = ""

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

	if overlay != 0 and not OverlayData.is_sign(overlay):
		_show_error("This tile has a protected simulation label.")

		return

	pending_sign_tile = point
	sign_dialog.show_text(city.label(overlay) if overlay > 0 else "")


func _commit_sign() -> void:
	if city == null or pending_sign_tile.x < 0:
		return

	var result := Signs.set_sign(city, pending_sign_tile, sign_dialog.entered_text())
	pending_sign_tile = Vector2i(-1, -1)

	if not result.ok:
		_show_error("Cannot change sign: %s" % result.error)

		return

	last_edit_command = result
	_refresh_after_city_edit(result)
	status_label.theme_type_variation = ""
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

	var neighborhood := QueryNeighborhood.render(city, point, palette_index_encoding, large_sprites)
	query_dialog.show_query(
		str(result.title),
		str(result.title) if is_specific else "",
		is_specific,
		Queries.format_text(result),
		action_text,
		result,
		ImageTexture.create_from_image(neighborhood) if neighborhood != null else null,
		palette,
		palette_cycle_ticks,
	)
	_play_sound_events(result.get("sound_events", []))


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

			city_analysis_dialog.show_categories(analysis.categories)
		"library_ruminate":
			if (
				library_texts.size()
				!= LibraryRuminateWindowsView.TEXT_RESOURCE_IDS.size()
			):
				_show_error("The Library text resources are missing or invalid.")

				return

			library_ruminate_windows.show_texts(
				library_texts, Vector2i(get_viewport_rect().size)
			)


func _refresh_details() -> void:
	if city == null:
		return

	_sync_city_option_menus()

	if graph_window != null:
		graph_window.refresh_city(city)

	if population_window != null:
		population_window.refresh_city(city)

	if industry_window != null:
		industry_window.refresh_city(city)

	if simnation_window != null:
		simnation_window.refresh_city(city)

	if ordinance_window != null:
		ordinance_window.refresh_city()

	if city_map_window != null:
		city_map_window.refresh_city(city, palette, _city_map_viewport_outline())

	var demand := city.rci_demand()
	var weather_trend := city.document.misc_u32(RciAftermath.MISC_WEATHER_TREND) & 0xff
	var weather_name: String = (
		RciAftermath.WEATHER_NAMES[weather_trend]
		if weather_trend < RciAftermath.WEATHER_NAMES.size()
		else "Unknown"
	)
	var display_date := "%02d/%02d/%04d" % [
		city.current_month(),
		city.current_day(),
		city.current_year(),
	]
	city_menu_bar.set_date(display_date)
	city_menu_bar.set_money("$%s" % _format_number(city.funds()))
	_refresh_status_summary(demand, weather_name)

	if _refresh_tool_availability():
		_update_edit_state()


func _refresh_status_summary(
	demand := Vector3i(0, 0, 0), weather_name := ""
) -> void:
	if city_menu_bar == null or city_status_bar == null:
		return

	if city == null:
		city_menu_bar.set_population("--", false)
		city_status_bar.clear_environment()
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

		city_menu_bar.set_population(_format_number(city.population()))
		city_status_bar.set_environment(demand, weather_name)

	_sync_speed_ui()
	city_status_bar.refresh_tooltips()


func _center_map_on_tile(point: Vector2i) -> void:
	if map_view.center_on_tile(point):
		_play_tool_success_sound(17, 0)
		status_label.theme_type_variation = ""
		status_label.text = "Centered the map on tile %d, %d." % [point.x, point.y]


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.theme_type_variation = "ErrorLabel"


func _debug_metrics() -> Dictionary:
	var result := {
		"simulation_slices": frame_simulation.metrics() if frame_simulation != null else {},
		"render_regions": region_cache.metrics() if region_cache != null else {},
		"visible_altitude_levels": city.visible_altitude_levels if city != null else 32,
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
		"static_render": "running" if static_render_thread != null else "idle",
		"render_pending": pending_static_render,
		"static_cache": static_view_cache.size(),
		"dynamic_cache": dynamic_visual_cache.size(),
		"foreground_cache": dynamic_foreground_cache.size(),
		"active_disaster": (
			CityMenuBar.disaster_name(simulation_engine.active_disaster_type)
			if simulation_engine != null
			else "None"
		),
		"active_disaster_id": (
			simulation_engine.active_disaster_type if simulation_engine != null else 0
		),
		"no_disasters": city != null and city.no_disasters_enabled(),
	}

	if audio_controller != null:
		result.merge(audio_controller.debug_metrics(), true)

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
	var map_edge: int = city.map_size if city != null else 128

	if map_view != null and city != null:
		map_view.center_on_tile(Vector2i(IntegerMath.div_trunc(map_edge, 2), IntegerMath.div_trunc(map_edge, 2)))


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
	sign_foreground_cache.clear()
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
			% [CityMenuBar.disaster_name(disaster_type), result.get("error", "unknown error")],
		}

	return {
		"ok": true,
		"message": "%s started at the current view center."
		% CityMenuBar.disaster_name(disaster_type),
	}


func _debug_end_disaster() -> Dictionary:
	var result := DebugActions.end_disaster(city, current_document, simulation_engine)

	if not result.ok:
		return {"ok": false, "message": result.error}

	last_edit_command = {}
	simulation_map_dirty = false
	_refresh_map(false)
	_refresh_moving_things()
	_refresh_details()

	return {
		"ok": true,
		"message": "Ended %s and cleared %d marker(s) and %d object(s)."
		% [
			(
				CityMenuBar.disaster_name(int(result.active_type))
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
	return DisplayNumbers.format(value)


func _placement_preview_valid(point: Vector2i) -> bool:
	return _placement_preview_error(point).is_empty()


func _placement_preview_error(point: Vector2i) -> String:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or city.index_of(point.x, point.y) < 0:
		return "Select a tile inside the map."

	if scurk_place_print != null and scurk_place_print.visible and scurk_place_print.is_object_mode():
		var tile_id := scurk_place_print.selected_tile_id
		var site := ScurkPlace.footprint(tile_id, point)

		if site.size.x == 0 or not Rect2i(0, 0, map_edge, map_edge).encloses(site):
			return "The object footprint extends outside the map."

		return "" if tile_id > 255 else String(ScurkPlace._check_site(city.buildings, city.terrain, city.tile_flags, site, tile_id, map_edge).get("error", ""))

	if Buildings.supports_tool(selected_group, selected_subtool):
		return Buildings.preview_error(city, selected_group, selected_subtool, point)

	if Hydro.supports_tool(selected_group, selected_subtool):
		var index := city.index_of(point.x, point.y)

		if city.funds() < int(Tools.tool(selected_group, selected_subtool).cost):
			return "Insufficient funds."

		if city.buildings[index] != 0:
			return "Clear the existing structure first."

		return "" if city.terrain[index] in [0x2e, 0x3e] else "Hydroelectric power requires a waterfall tile."

	if Onramps.supports_tool(selected_group, selected_subtool):
		return String(Onramps.apply(city, selected_group, selected_subtool, point, false, true).get("error", ""))

	if SubwayToRail.supports_tool(selected_group, selected_subtool):
		return String(SubwayToRail.apply(city, selected_group, selected_subtool, point, true).get("error", ""))

	if Tunnels.supports_tool(selected_group, selected_subtool):
		var proposal := Tunnels.apply(city, selected_group, selected_subtool, point)

		if not proposal.get("confirmation_required", false):
			return String(proposal.get("error", "A tunnel requires a suitable hillside and exit."))

		return "" if city.funds() >= int(proposal.get("cost", 0)) else "Insufficient funds for this tunnel."

	if Highways.supports_tool(selected_group, selected_subtool):
		return Highways.preview_error(city, point)

	return ""


func _set_underground_subways_visible(enabled: bool) -> void:
	if show_underground_subways == enabled:
		return

	show_underground_subways = enabled
	_invalidate_view_render()
	_sync_view_controls()

	if city != null and overlay_mode == "underground":
		_refresh_map(false)

	status_label.text = "Underground subways %s." % ("shown" if enabled else "hidden")


static func _parallel_dust_events(events: Array) -> Array:
	var groups := {}

	for event in events:
		if event.has("point") and event.get("type", "") != "earthquake":
			var key: Vector2i = event.point

			if not groups.has(key):
				groups[key] = []

			groups[key].append(event)

	if groups.size() < 2:
		return events

	var order := groups.keys()
	order.shuffle() # presentation randomness does not consume simulation random state
	var starts := {}

	for index in order.size():
		var first := 2147483647

		for event in groups[order[index]]:
			first = mini(first, int(event.get("frame", 0)))

		starts[order[index]] = {"first": first, "start": index % 5}

	var result: Array = []

	for source in events:
		var event: Dictionary = source.duplicate()

		if event.has("point") and starts.has(event.point):
			var timing: Dictionary = starts[event.point]
			event.frame = int(event.get("frame", 0)) - int(timing.first) + int(timing.start)

		result.append(event)

	return result


func _request_main_menu() -> void:
	var prompt := ConfirmationDialog.new()
	prompt.title = "Return to Main Menu"
	prompt.dialog_text = "Return to the main menu? You can use Continue City to resume this city."
	prompt.theme = AppUiTheme.current()
	prompt.min_size = Vector2i(480, 180)
	add_child(prompt)
	prompt.confirmed.connect(func() -> void:
		_show_main_menu()
		prompt.queue_free())
	prompt.canceled.connect(prompt.queue_free)
	prompt.popup_centered()


func _refresh_scurk_artwork() -> void:
	if map_view == null:
		return

	map_view.scurk_stamp_visuals.clear()

	if city != null and scurk_place_print != null and scurk_place_print.visible and overlay_mode == "city":
		for stamp in city.scurk_artwork_stamps:
			var entry = large_sprites.find_sprite(1000 + int(stamp.tile_id))

			if entry == null:
				continue

			var rendered: Dictionary = entry.create_image(palette)

			if not rendered.ok:
				continue

			var texture := ImageTexture.create_from_image(rendered.image)
			var anchor: Vector2 = CityIsometricRenderer.tile_polygon(city, stamp.point.x, stamp.point.y)[2]
			map_view.scurk_stamp_visuals.append({"texture": texture, "position": anchor - Vector2(texture.get_width() / 2.0, texture.get_height() - 1)})

	map_view.queue_redraw()


func _enter_landscape_editor() -> void:
	landscape_editor = true
	_select_speed(GameSpeed.Speed.PAUSED)
	city_toolbar.set_landscape_editor(true)
	city_menu_bar.disasters_menu.disabled = true
	_set_overlay("city")
	_select_tool_group(0)
	_select_subtool(2)
	status_label.text = "Landscape editor: terrain changes are free. Select Start City when ready."


func _start_city() -> void:
	if not landscape_editor or city == null:
		return

	landscape_editor = false
	city_toolbar.set_landscape_editor(false)
	city_menu_bar.disasters_menu.disabled = false
	last_edit_command.clear()
	_select_tool_group(9)
	_select_speed(GameSpeed.Speed.TURTLE)
	status_label.text = "City started. Build zones, roads, and services."
	_play_sound_events([513])
	founding_newspaper_pending = true
	_on_newspaper_menu(0)


func _on_founding_newspaper_visibility_changed() -> void:
	if not founding_newspaper_pending or newspaper_dialog.visible:
		return

	founding_newspaper_pending = false

	if city != null and city.music_enabled():
		audio_controller.music_director.general_track_index = 0
		_play_music_track(audio_controller.music_director.next_general_track())



func _debug_set_visible_altitude_levels(levels: int) -> void:
	if city == null:
		return

	levels = clampi(levels, 1, 32)

	if city.visible_altitude_levels == levels:
		return

	city.visible_altitude_levels = levels

	if map_view.city != null:
		map_view.city.visible_altitude_levels = levels

	map_view._invalidate_sign_entries()
	_invalidate_view_render()
	_refresh_map(false)


func _sign_palette_signature(used: Dictionary, mapping: PackedInt32Array) -> int:
	var colors := PackedInt32Array()

	for index in used:
		colors.append(mapping[index])

	return hash(colors)


func _sign_palette_image(indexed: Image, mapping: PackedInt32Array) -> Image:
	var bytes := indexed.get_data()

	for offset in range(0, bytes.size(), 4):
		if bytes[offset + 3] == 0:
			continue

		var color := palette.color(mapping[bytes[offset]])
		bytes[offset] = color.r8
		bytes[offset + 1] = color.g8
		bytes[offset + 2] = color.b8

	return Image.create_from_data(indexed.get_width(), indexed.get_height(), false, Image.FORMAT_RGBA8, bytes)


func _update_network_preview() -> void:
	if network_preview == null:
		return

	if city == null or not _camera_keys_allowed() or not map_view.edit_enabled or map_view.is_panning() or not NetworkPlacementPreview.supports_tool(selected_group, selected_subtool):
		network_preview.clear()

		return

	# hover highlights the tile; artwork needs a pressed selection
	var start := map_view.selection_start
	var finish := map_view.selection_end

	if start.x < 0 or finish.x < 0:
		network_preview.clear()

		return

	var view := _city_view_size()
	var sprites := large_sprites if view == IsometricRenderer.VIEW_LARGE else small_medium_sprites

	if sprites != null and palette != null:
		network_preview.request(city, selected_group, selected_subtool, start, finish, view, palette, sprites, overlay_mode == "underground")


func _clear_dynamic_composition_cache() -> void:
	dynamic_sprite_cache.clear()
	dynamic_foreground_cache.clear()
	dynamic_occluder_cache.clear()
	dynamic_visual_cache.clear()
	dynamic_special_batch_cache.clear()
	sign_foreground_cache.clear()


func _set_graphics_preferences(zoom_graphics: Array) -> void:
	var sizes := SettingsStore.normalize_zoom_graphics(zoom_graphics)

	if app_zoom_graphics == sizes:
		return

	app_zoom_graphics = sizes
	_close_region_cache()
	dynamic_visual_cache.clear()
	sign_foreground_cache.clear()
	_refresh_map()


func _apply_compatibility_controls() -> void:
	if speed_controller != null:
		speed_controller.original_compatibility = app_original_compatibility
		speed_controller.fire_elapsed_msec = 0.0

	if new_city_dialog != null:
		for index in new_city_dialog.size_input.item_count:
			new_city_dialog.size_input.set_item_disabled(index, app_original_compatibility and new_city_dialog.size_input.get_item_id(index) != 128)

		new_city_dialog.native_maps_input.disabled = app_original_compatibility

		if app_original_compatibility:
			new_city_dialog.size_input.select(0)
			new_city_dialog.native_maps_input.set_pressed_no_signal(false)

	_sync_upgrade_city_option()
