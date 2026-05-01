class_name CityDialogRegistry
extends Control

const FileDialogs = preload("res://src/ui/shared/file_dialog_factory.gd")
const NewCityDialogView = preload("res://src/ui/startup/new_city_terrain_dialog.tscn")
const SignDialogView = preload("res://src/ui/tools/city_sign_dialog.tscn")
const BridgeDialogView = preload("res://src/ui/tools/bridge_selection_dialog.tscn")
const ToolChoiceDialogView = preload("res://src/ui/tools/tool_choice_dialog.tscn")
const StadiumDialogView = preload("res://src/ui/tools/stadium_team_dialog.tscn")
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
const IndustryView = preload("res://src/view/industry_window_control.gd")
const SimNationView = preload("res://src/view/simnation_window_control.gd")

var dialog_groups: Dictionary = {}

var original_assets: OriginalGameAssets
var city_open_dialog: FileDialog
var city_save_dialog: FileDialog
var tile_set_dialog: FileDialog
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
	_dialog_parent("Files").add_child(city_open_dialog)
	city_save_dialog = FileDialogs.city_save()
	_dialog_parent("Files").add_child(city_save_dialog)
	tile_set_dialog = FileDialogs.tile_set_open()
	_dialog_parent("Files").add_child(tile_set_dialog)


func _create_tool_dialogs() -> void:
	new_city_dialog = NewCityDialogView.instantiate() as NewCityTerrainDialog
	_dialog_parent("Startup").add_child(new_city_dialog)

	if original_assets != null:
		new_city_dialog.set_control_graphics(original_assets.city_ui_graphics)

	sign_dialog = SignDialogView.instantiate()
	_dialog_parent("Tools").add_child(sign_dialog)
	bridge_dialog = BridgeDialogView.instantiate()
	_dialog_parent("Tools").add_child(bridge_dialog)
	tool_choice_dialog = ToolChoiceDialogView.instantiate()
	_dialog_parent("Tools").add_child(tool_choice_dialog)
	stadium_dialog = StadiumDialogView.instantiate()
	_dialog_parent("Tools").add_child(stadium_dialog)
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
	_dialog_parent("Tools").add_child(query_dialog)


func _create_information_windows() -> void:
	graph_window = GraphWindowView.instantiate()
	_dialog_parent("CityWindows").add_child(graph_window)
	population_window = PopulationWindowView.instantiate()
	_dialog_parent("CityWindows").add_child(population_window)
	industry_window = IndustryWindowView.instantiate()
	_dialog_parent("CityWindows").add_child(industry_window)
	var industry_names := PackedStringArray()

	for index in IndustryView.INDUSTRY_COUNT:
		var fallback: String = IndustryView.DEFAULT_NAMES[index]
		industry_names.append(str(original_assets.strings.get(
			OriginalGameAssets.INDUSTRY_STRING_FIRST + index, fallback
		)))

	industry_window.set_resources(industry_names, original_assets.industry_icons)
	simnation_window = SimNationWindowView.instantiate()
	_dialog_parent("CityWindows").add_child(simnation_window)
	simnation_window.set_resources(
		original_assets.simnation_sprites,
		str(original_assets.strings.get(
			OriginalGameAssets.SIMNATION_FORMAT_STRING_ID,
			SimNationView.DEFAULT_NATIONAL_FORMAT,
		)),
		original_assets.strings,
	)
	city_map_window = CityMapWindowView.instantiate()
	_dialog_parent("CityWindows").add_child(city_map_window)
	city_map_window.set_resources(
		original_assets.city_map_icons, original_assets.strings
	)
	ordinance_window = OrdinanceWindowView.instantiate()
	_dialog_parent("CityWindows").add_child(ordinance_window)
	analysis_dialog = AnalysisDialogView.instantiate()
	_dialog_parent("CityWindows").add_child(analysis_dialog)
	newspaper_dialog = NewspaperDialogView.new()
	_dialog_parent("CityWindows").add_child(newspaper_dialog)
	newspaper_dialog.set_control_graphics(original_assets.city_ui_graphics)
	library_windows = LibraryWindowsView.new()
	_dialog_parent("CityWindows").add_child(library_windows)


func _create_event_dialogs() -> void:
	building_objection_dialog = PictureDialogView.instantiate()
	_dialog_parent("CityEvents").add_child(building_objection_dialog)
	building_objection_dialog.configure(
		"BuildingObjectionDialog",
		"Citizen Objection",
		"BuildingObjectionImage",
		"BuildingObjectionMessage",
		original_assets.forest_protest_image,
		original_assets.building_objection_text,
	)
	game_over_dialog = AcceptDialog.new()
	game_over_dialog.name = "GameOverDialog"
	game_over_dialog.theme = ClassicUiStyle.create_dialog_theme()
	game_over_dialog.min_size = Vector2i(460, 220)
	_dialog_parent("CityEvents").add_child(game_over_dialog)
	scenario_dialog = ScenarioDialogView.instantiate()
	_dialog_parent("Startup").add_child(scenario_dialog)
	military_dialog = ConfirmationDialog.new()
	military_dialog.name = "MilitaryProposalDialog"
	military_dialog.theme = ClassicUiStyle.create_dialog_theme()
	military_dialog.title = "Military Base Proposal"
	military_dialog.dialog_text = (
		"The military wants to build a base in the city. "
		+ "The base does not cost city funds. Do you accept the proposal?"
	)
	military_dialog.min_size = Vector2i(500, 210)
	military_dialog.get_ok_button().text = "Accept"
	military_dialog.get_cancel_button().text = "Decline"
	military_dialog.exclusive = true
	_dialog_parent("CityEvents").add_child(military_dialog)
	budget_dialog = BudgetDialogView.instantiate() as BudgetDialog
	_dialog_parent("CityWindows").add_child(budget_dialog)


func _route_dialog(
	title: String,
	prompt: String,
	accept_text: String,
	cancel_text: String,
	minimum_size := Vector2i(480, 190)
) -> RouteConfirmationDialog:
	var dialog := RouteDialogView.new()
	dialog.configure(title, prompt, accept_text, cancel_text, minimum_size)
	_dialog_parent("Tools").add_child(dialog)

	return dialog


func _dialog_parent(group_name: String) -> Control:
	if not dialog_groups.has(group_name):
		var group := Control.new()
		group.name = group_name
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(group)
		group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dialog_groups[group_name] = group

	return dialog_groups[group_name] as Control
