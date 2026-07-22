class_name CityApplication
extends Control


const NewCitySession = preload("res://src/model/new_city_terrain_session.gd")
const SettingsStore = preload("res://src/ui/settings/app_settings_store.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")
const ScurkHistory = preload("res://src/tools/scurk/scurk_edit_history.gd")

# active document and save state
var city: CityState
var current_document: Sc2File
var saved_city_snapshot := PackedByteArray()
var current_save_path := ""
var current_city_saved_once := false
# loaded graphics and active view
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
# display layer for vehicles. hidden vehicles also make no sound and cannot crash
var show_vehicles := true
var show_underground_water_mains := true
var show_underground_pipes := true
var show_underground_subways := true
# application preferences and asset source
var app_soundtrack_folder := ""
var app_toolbar_sounds := true
var app_sound_pack_folder := ""
var app_music_pack_folder := ""
var app_city_renderer := "gpu"
var app_ui_theme := "light"
var app_translucent_menus := true
var app_dark_underground := false
var app_default_mayor_name := "Mayor"
var app_overview_graphics := 0
var app_moving_frame_rate := SettingsStore.DEFAULT_MOVING_FRAME_RATE
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
# original text resources and newspaper session
var original_query_strings: Dictionary = {}
var building_objection_text := "Residents objected to this facility site."
var library_texts: Dictionary = {}
var newspaper_data: DataUsaResource
var newspaper_session_seed := 0
var newspaper_session_state := PackedByteArray()
# tool and simulation state
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
# static and dynamic render caches and jobs
var render_caches := RenderCaches.new()
var static_render_state := StaticRenderState.new()
var toolbar_animation_palette: Sc2Palette
var palette_cycle_ticks := 0
var palette_elapsed_msec := 0.0
var palette_cycle_texture: ImageTexture

# scene controls and pending ui workflows
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
var new_city_preview_job: NewCityPreviewJob
var new_city_return_to_main_menu := false
var landscape_brush_command: Dictionary = {}
var level_brush_altitude := -1
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
var city_png_export_dialog: CityPngExportDialog
var city_png_export_progress: ProgressOverlay
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

# shared state for the controllers; rules and scene ownership stay elsewhere
var assets: ApplicationAssets = ApplicationAssets.new(self)
var interface: ApplicationInterface = ApplicationInterface.new(self)
var settings: ApplicationSettings = ApplicationSettings.new(self)
var scurk_workspace: ApplicationScurkWorkspace = ApplicationScurkWorkspace.new(self)
var scurk_output: ApplicationScurkOutput = ApplicationScurkOutput.new(self)
var city_png_export: ApplicationCityPngExport = ApplicationCityPngExport.new(self)
var camera_input: ApplicationCameraInput = ApplicationCameraInput.new(self)
var menus: ApplicationMenus = ApplicationMenus.new(self)
var reports: ApplicationReports = ApplicationReports.new(self)
var new_city: ApplicationNewCity = ApplicationNewCity.new(self)
var city_files: ApplicationCityFiles = ApplicationCityFiles.new(self)
var city_session: ApplicationCitySession = ApplicationCitySession.new(self)
var budget: ApplicationBudget = ApplicationBudget.new(self)
var frame: ApplicationFrame = ApplicationFrame.new(self)
var static_render: ApplicationStaticRender = ApplicationStaticRender.new(self)
var map_render: ApplicationMapRender = ApplicationMapRender.new(self)
var moving_sprites: ApplicationMovingSprites = ApplicationMovingSprites.new(self)
var effects_audio: ApplicationEffectsAudio = ApplicationEffectsAudio.new(self)
var current_tool: ApplicationCurrentTool = ApplicationCurrentTool.new(self)
var city_edits: ApplicationCityEdits = ApplicationCityEdits.new(self)
var network_edits: ApplicationNetworkEdits = ApplicationNetworkEdits.new(self)
var query_choices: ApplicationQueryChoices = ApplicationQueryChoices.new(self)
var route_edits: ApplicationRouteEdits = ApplicationRouteEdits.new(self)
var debug: ApplicationDebug = ApplicationDebug.new(self)


func _ready() -> void:
	add_child(preload("res://src/ui/shared/file_dialog_history.gd").new())
	get_tree().auto_accept_quit = false

	if reference_root.is_empty():
		reference_root = GameAssetSource.default_reference_root()

	settings._load_app_settings()
	assets._build_reference_import_dialogs()
	assets._initialize_runtime()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		city_files._request_city_exit("quit")
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		effects_audio._handle_application_focus_out()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		effects_audio._handle_application_focus_in()


func _exit_tree() -> void:
	if new_city_preview_job != null and new_city_preview_job.thread.is_started():
		new_city_preview_job.thread.wait_to_finish()
	new_city_preview_job = null
	map_render._close_region_cache()

	if frame_simulation != null:
		frame_simulation.close()

	frame_simulation = null
	static_render._stop_render_job()
	city_png_export._close()


func _process(delta: float) -> void:
	frame._process(delta)


func _input(event: InputEvent) -> void:
	camera_input._input(event)


func _unhandled_key_input(event: InputEvent) -> void:
	camera_input._unhandled_key_input(event)
