class_name CityApplication
extends Control


const NewCitySession = preload("res://src/model/new_city_terrain_session.gd")
const ScurkHistory = preload("res://src/tools/scurk/scurk_edit_history.gd")

# active city, document, and save state
var document_state := ActiveDocumentState.new()
# loaded assets
var asset_state := LoadedAssetState.new()
# active view settings
var view_state := ViewState.new()
# application preferences and asset dialogs
var preferences := AppPreferences.new()
var sc2x_conversion_dialog: ConfirmationDialog
var reference_import_dialog: FileDialog
var reference_import_error_dialog: AcceptDialog
var graphics_source_error_dialog: AcceptDialog
# original text resources and newspaper session
var original_text_resources := OriginalTextResources.new()
var newspaper_state := NewspaperSessionState.new()
# tool state
var tool_state := ToolState.new()
# simulation session state
var simulation_state := SimulationSessionState.new()
var audio_controller: Node
var edit_display_timings := {}
# static and dynamic render caches and jobs
var render_caches := RenderCaches.new()
var static_render_state := StaticRenderState.new()
var palette_clock := PaletteAnimationClock.new()

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
var tool_choice_dialog: ToolChoiceDialog
var stadium_dialog: StadiumTeamDialog
var city_png_export_dialog: CityPngExportDialog
var city_png_export_progress: ProgressOverlay
var network_connection_dialog: RouteConfirmationDialog
var highway_connection_dialog: RouteConfirmationDialog
var tunnel_dialog: RouteConfirmationDialog
var query_dialog: CityQueryDialog
var city_analysis_dialog: CityAnalysisDialog
var newspaper_dialog: NewspaperDialog
var building_objection_dialog: PictureNoticeDialog
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

	if asset_state.reference_root.is_empty():
		asset_state.reference_root = GameAssetSource.default_reference_root()

	settings.load_app_settings()
	assets.build_reference_import_dialogs()
	assets.initialize_runtime()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		city_files.request_city_exit("quit")
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		effects_audio.handle_application_focus_out()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		effects_audio.handle_application_focus_in()


func _exit_tree() -> void:
	if new_city_preview_job != null and new_city_preview_job.thread.is_started():
		new_city_preview_job.thread.wait_to_finish()
	new_city_preview_job = null
	map_render.close_region_cache()

	if simulation_state.frame_simulation != null:
		simulation_state.frame_simulation.close()

	simulation_state.frame_simulation = null
	static_render.stop_render_job()
	city_png_export.close()


func _process(delta: float) -> void:
	frame.process(delta)


func _input(event: InputEvent) -> void:
	camera_input.input(event)


func _unhandled_key_input(event: InputEvent) -> void:
	camera_input.unhandled_key_input(event)
