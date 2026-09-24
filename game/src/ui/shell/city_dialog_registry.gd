class_name CityDialogRegistry
extends Control

# Scene dialogs stay visible in the editor and hide themselves in _ready().
const FileDialogs = preload("res://src/ui/shared/file_dialog_factory.gd")
const NewCityDialogView = preload("res://src/ui/startup/new_city_terrain_dialog.tscn")
const SignDialogView = preload("res://src/ui/tools/city_sign_dialog.tscn")
const BridgeDialogView = preload("res://src/ui/tools/bridge_selection_dialog.tscn")
const ToolChoiceDialogView = preload("res://src/ui/tools/tool_choice_dialog.tscn")
const StadiumDialogView = preload("res://src/ui/tools/stadium_team_dialog.tscn")
const PngExportDialogView = preload("res://src/ui/shell/city_png_export_dialog.tscn")
const ProgressOverlayView = preload("res://src/ui/shared/progress_overlay.tscn")
const RouteDialogView = preload("res://src/ui/tools/route_confirmation_dialog.gd")
const QueryDialogView = preload("res://src/ui/tools/city_query_dialog.tscn")
const GraphWindowView = preload("res://src/ui/city_windows/city_graph_window.tscn")
const PopulationWindowView = preload("res://src/ui/city_windows/city_population_window.tscn")
const IndustryWindowView = preload("res://src/ui/city_windows/city_industry_window.tscn")
const SimNationWindowView = preload("res://src/ui/city_windows/city_simnation_window.tscn")
const CityMapWindowView = preload("res://src/ui/city_windows/city_map_window.tscn")
const OrdinanceWindowView = preload("res://src/ui/city_windows/city_ordinance_window.tscn")
const AnalysisDialogView = preload("res://src/ui/city_windows/city_analysis_dialog.tscn")
const NewspaperDialogView = preload("res://src/ui/newspaper/newspaper_dialog.gd")
const PictureDialogView = preload("res://src/ui/shared/picture_notice_dialog.tscn")
const LibraryWindowsView = preload("res://src/ui/city_windows/library_ruminate_windows.gd")
const ScenarioDialogView = preload("res://src/ui/startup/scenario_intro_dialog.tscn")
const BudgetDialogView = preload("res://src/ui/city_windows/budget_dialog.tscn")

# whether a visible window suspends the simulation. each registered window
# declares one value. statistics windows are modeless, as in the original game
enum Modality { BLOCKING, MODELESS }

var dialog_groups: Dictionary = {}
var blocking_windows: Array[Node] = []
var modeless_windows: Array[Node] = []

var original_assets: OriginalGameAssets
var city_open_dialog: FileDialog
var city_save_dialog: FileDialog
var tile_set_dialog: FileDialog
var png_export_dialog: CityPngExportDialog
var png_export_progress: ProgressOverlay
var new_city_dialog: NewCityTerrainDialog
var sign_dialog: CitySignDialog
var bridge_dialog: BridgeSelectionDialog
var tool_choice_dialog: ToolChoiceDialog
var stadium_dialog: StadiumTeamDialog
var network_connection_dialog: RouteConfirmationDialog
var highway_connection_dialog: RouteConfirmationDialog
var tunnel_dialog: RouteConfirmationDialog
var query_dialog: CityQueryDialog
var graph_window: CityGraphWindow
var population_window: CityPopulationWindow
var industry_window: CityIndustryWindow
var simnation_window: CitySimNationWindow
var city_map_window: CityMapDialog
var ordinance_window: CityOrdinanceWindow
var analysis_dialog: CityAnalysisDialog
var newspaper_dialog: NewspaperDialog
var building_objection_dialog: PictureNoticeDialog
var library_windows: LibraryRuminateWindows
var game_over_dialog: AcceptDialog
var notice_dialog: AcceptDialog
var scenario_dialog: ScenarioIntroDialog
var military_dialog: ConfirmationDialog
var budget_dialog: BudgetDialog


func _init(assets: OriginalGameAssets = null) -> void:
	original_assets = assets


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_file_dialogs()
	_create_tool_dialogs()
	_create_information_windows()
	_create_event_dialogs()


func _create_file_dialogs() -> void:
	city_open_dialog = FileDialogs.city_open()
	_register(city_open_dialog, "Files", Modality.MODELESS)
	city_save_dialog = FileDialogs.city_save()
	_register(city_save_dialog, "Files", Modality.BLOCKING)
	tile_set_dialog = FileDialogs.tile_set_open()
	_register(tile_set_dialog, "Files", Modality.MODELESS)
	png_export_dialog = PngExportDialogView.instantiate()
	_register(png_export_dialog, "Files", Modality.BLOCKING)
	png_export_progress = ProgressOverlayView.instantiate()
	_register(png_export_progress, "Files", Modality.BLOCKING)


func _create_tool_dialogs() -> void:
	new_city_dialog = NewCityDialogView.instantiate() as NewCityTerrainDialog
	_register(new_city_dialog, "Startup", Modality.BLOCKING)

	if original_assets != null:
		new_city_dialog.set_control_graphics(original_assets.city_ui_graphics)

	sign_dialog = SignDialogView.instantiate()
	_register(sign_dialog, "Tools", Modality.MODELESS)
	bridge_dialog = BridgeDialogView.instantiate()
	_register(bridge_dialog, "Tools", Modality.BLOCKING)
	tool_choice_dialog = ToolChoiceDialogView.instantiate()
	_register(tool_choice_dialog, "Tools", Modality.BLOCKING)
	stadium_dialog = StadiumDialogView.instantiate()
	_register(stadium_dialog, "Tools", Modality.BLOCKING)
	network_connection_dialog = _route_dialog(
		"Neighbor Connection",
		"Build a road connection to a neighboring city for $1,000?",
		"Build Connection",
		"Keep Route",
	)
	highway_connection_dialog = _route_dialog(
		"Neighbor Connection",
		"Build a highway connection to a neighboring city for $1,500?",
		"Build Connection",
		"Keep Highway",
	)
	tunnel_dialog = _route_dialog(
		"Construct Tunnel",
		"Do you wish to construct the tunnel?",
		"Yes",
		"No",
		Vector2i(500, 200),
	)
	tunnel_dialog.theme = AppUiTheme.current()

	query_dialog = QueryDialogView.instantiate()
	_register(query_dialog, "Tools", Modality.BLOCKING)


func _create_information_windows() -> void:
	graph_window = GraphWindowView.instantiate()
	_register(graph_window, "CityWindows", Modality.MODELESS)
	population_window = PopulationWindowView.instantiate()
	_register(population_window, "CityWindows", Modality.MODELESS)
	industry_window = IndustryWindowView.instantiate()
	_register(industry_window, "CityWindows", Modality.MODELESS)
	industry_window.set_resources(original_assets.industry_icons)
	simnation_window = SimNationWindowView.instantiate()
	_register(simnation_window, "CityWindows", Modality.MODELESS)
	simnation_window.set_resources(original_assets.simnation_sprites)
	city_map_window = CityMapWindowView.instantiate()
	_register(city_map_window, "CityWindows", Modality.MODELESS)
	city_map_window.set_resources(original_assets.city_map_icons)
	ordinance_window = OrdinanceWindowView.instantiate()
	_register(ordinance_window, "CityWindows", Modality.BLOCKING)
	analysis_dialog = AnalysisDialogView.instantiate()
	_register(analysis_dialog, "CityWindows", Modality.MODELESS)
	newspaper_dialog = NewspaperDialogView.new()
	_register(newspaper_dialog, "CityWindows", Modality.MODELESS)
	newspaper_dialog.set_control_graphics(original_assets.city_ui_graphics)
	library_windows = LibraryWindowsView.new()
	_register(library_windows, "CityWindows", Modality.MODELESS)


func _create_event_dialogs() -> void:
	building_objection_dialog = PictureDialogView.instantiate()
	_register(building_objection_dialog, "CityEvents", Modality.BLOCKING)
	building_objection_dialog.configure(
		"BuildingObjectionDialog",
		"Citizen Objection",
		"BuildingObjectionImage",
		"BuildingObjectionMessage",
		original_assets.forest_protest_image,
		BuildingConstants.NUISANCE_OBJECTION,
	)
	game_over_dialog = AcceptDialog.new()
	game_over_dialog.name = "GameOverDialog"
	game_over_dialog.theme = AppUiTheme.current()
	game_over_dialog.min_size = Vector2i(460, 220)
	game_over_dialog.exclusive = true
	_register(game_over_dialog, "CityEvents", Modality.BLOCKING)
	notice_dialog = AcceptDialog.new()
	notice_dialog.name = "SimulationNoticeDialog"
	notice_dialog.theme = AppUiTheme.current()
	notice_dialog.title = "Notice"
	notice_dialog.min_size = Vector2i(420, 160)
	notice_dialog.exclusive = true
	_register(notice_dialog, "CityEvents", Modality.BLOCKING)
	scenario_dialog = ScenarioDialogView.instantiate()
	_register(scenario_dialog, "Startup", Modality.BLOCKING)
	military_dialog = ConfirmationDialog.new()
	military_dialog.name = "MilitaryProposalDialog"
	military_dialog.theme = AppUiTheme.current()
	military_dialog.title = "Military Base Proposal"
	military_dialog.dialog_text = (
		"The military wants to build a base in the city. "
		+ "The base does not cost city funds. Do you accept the proposal?"
	)
	military_dialog.min_size = Vector2i(500, 210)
	military_dialog.get_ok_button().text = "Accept"
	military_dialog.get_cancel_button().text = "Decline"
	military_dialog.exclusive = true
	_register(military_dialog, "CityEvents", Modality.BLOCKING)
	budget_dialog = BudgetDialogView.instantiate() as BudgetDialog
	_register(budget_dialog, "CityWindows", Modality.BLOCKING)


func _route_dialog(
	title: String,
	prompt: String,
	accept_text: String,
	cancel_text: String,
	minimum_size := Vector2i(480, 190)
) -> RouteConfirmationDialog:
	var dialog := RouteDialogView.new()
	dialog.configure(title, prompt, accept_text, cancel_text, minimum_size)
	_register(dialog, "Tools", Modality.BLOCKING)

	return dialog


# true when a visible registered window suspends the simulation
func blocks_simulation() -> bool:
	return any_window_visible(blocking_windows)


static func any_window_visible(windows: Array[Node]) -> bool:
	for window in windows:
		if window is Window and (window as Window).visible:
			return true

		if window is CanvasItem and (window as CanvasItem).visible:
			return true

	return false


func _register(window: Node, group_name: String, modality: Modality) -> void:
	_dialog_parent(group_name).add_child(window)

	if modality == Modality.BLOCKING:
		blocking_windows.append(window)
	else:
		modeless_windows.append(window)


func _dialog_parent(group_name: String) -> Control:
	if not dialog_groups.has(group_name):
		var group := Control.new()
		group.name = group_name
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(group)
		group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dialog_groups[group_name] = group

	return dialog_groups[group_name] as Control
