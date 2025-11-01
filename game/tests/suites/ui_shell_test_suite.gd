extends RefCounted

const CityModel = preload("res://src/model/city_state.gd")
const NewCity = preload("res://src/model/new_city_setup.gd")
const NewCityTerrain = preload("res://src/model/new_city_terrain.gd")
const Budget = preload("res://src/simulation/budget_phase.gd")
const ScurkPlaceControl = preload("res://src/ui/scurk_place_print_control.gd")
const RciStatus = preload("res://src/view/rci_status_control.gd")
const GraphControl = preload("res://src/view/city_graph_control.gd")
const MainMenu = preload("res://src/ui/main_menu_control.gd")
const SettingsDialogUi = preload("res://src/ui/app_settings_dialog.gd")
const ScenarioIntroDialogUi = preload("res://src/ui/scenario_intro_dialog.gd")
const CityAnalysisDialogUi = preload("res://src/ui/city_analysis_dialog.gd")
const GraphWindowUi = preload("res://src/ui/city_graph_window.gd")
const PopulationWindowUi = preload("res://src/ui/city_population_window.gd")
const IndustryWindowUi = preload("res://src/ui/city_industry_window.gd")
const SimNationWindowUi = preload("res://src/ui/city_simnation_window.gd")
const CityMapWindowUi = preload("res://src/ui/city_map_window.gd")
const OrdinanceWindowUi = preload("res://src/ui/city_ordinance_window.gd")
const NewCityTerrainDialogUi = preload("res://src/ui/new_city_terrain_dialog.gd")
const BudgetDialogUi = preload("res://src/ui/budget_dialog.gd")
const MainControl = preload("res://src/main.gd")

var check_callback: Callable


func _init(callback: Callable) -> void:
	check_callback = callback


func test_rci_status_control() -> void:
	_test_rci_status_control()


func test_shell_controls() -> void:
	_test_main_menu()
	_test_budget_dialog()


func _test_rci_status_control() -> void:
	_check(
		RciStatus.GRAPH_BACKGROUND.get_luminance() > 0.8,
		"RCI status bars use a light graph background",
	)
	var graph_rect := Rect2(27, 2, 71, 20)
	var bars := RciStatus.bar_rects(Vector3i(2000, -1000, 0), graph_rect)
	_check(
		bars == [
			Rect2(32, 4, 12, 8),
			Rect2(56, 13, 12, 4),
			Rect2(80, 12, 12, 0),
		],
		"RCI status bars use one shared zero line and signed demand heights",
	)
	_check(
		RciStatus.demand_tooltip(Vector3i(-90, -265, 510))
		== (
			"Residential (green): -90\n"
			+ "Commercial (blue): -265\n"
			+ "Industrial (yellow): +510"
		),
		"RCI status tooltip identifies each zone color and exact demand",
	)
	var control := RciStatus.new()
	control.set_demand(Vector3i(3000, -3000, 50))
	_check(
		control.demand == Vector3i(2000, -2000, 50)
		and control.demand_available
		and control.custom_minimum_size.x == 100,
		"RCI status control clamps values to the saved demand range",
	)
	control.clear_demand()
	_check(
		not control.demand_available
		and control.tooltip_text == "RCI demand is not available.",
		"RCI status control has an explicit no-city state",
	)
	control.free()


func _test_main_menu() -> void:
	_check(
		MainMenu.BUTTON_LABELS == [
			"Continue City",
			"Start New City",
			"Open City...",
			"Play Scenario...",
			"SCURK Paint the Town",
			"SCURK Place & Print",
			"Settings...",
			"About OpenSC2K...",
			"Exit",
		],
		"Main menu exposes every startup workflow",
	)
	var menu := MainMenu.new()
	menu._ready()
	_check(
		menu.continue_button != null
		and menu.new_city_button != null
		and menu.scurk_place_button != null,
		"Main menu builds its initial and continuing city actions",
	)
	_check(
		ScurkPlaceControl.placeable_groups()
		== PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 9, 10]),
		"SCURK Place & Print omits both non-placeable animation groups",
	)
	menu.free()
	var settings_dialog := SettingsDialogUi.new()
	settings_dialog._ready()
	settings_dialog.music_slider.value = 25
	settings_dialog.effects_slider.value = 75
	settings_dialog.fullscreen_check.button_pressed = true
	var selected_settings := settings_dialog.selected_values()
	_check(
		selected_settings.music_volume == 0.25
		and selected_settings.effects_volume == 0.75
		and selected_settings.fullscreen,
		"Settings dialog owns its audio and display values",
	)
	settings_dialog.free()
	var scenario_dialog := ScenarioIntroDialogUi.new()
	scenario_dialog._ready()
	var scenario_picture := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	scenario_picture.fill(Color("123456"))
	scenario_dialog.set_briefing(
		"Test City", scenario_picture, "First line\r\nSecond line"
	)
	_check(
		scenario_dialog.title == "Scenario: Test City"
		and scenario_dialog.picture_view.texture != null
		and scenario_dialog.picture_view.texture_filter
		== CanvasItem.TEXTURE_FILTER_NEAREST
		and scenario_dialog.text_view.text == "First line\nSecond line",
		"Scenario dialog owns its picture and normalized briefing text",
	)
	scenario_dialog.free()
	var analysis_dialog := CityAnalysisDialogUi.new()
	analysis_dialog._ready()
	analysis_dialog.set_categories([
		{"name": "Roads", "acres": 12, "percent": 34},
	])
	var analysis_root := analysis_dialog.table.get_root()
	var analysis_item := analysis_root.get_first_child()
	_check(
		analysis_dialog.table.columns == 3
		and analysis_item.get_text(0) == "Roads"
		and analysis_item.get_text(1) == "12"
		and analysis_item.get_text(2) == "34%"
		and analysis_item.get_text_alignment(1) == HORIZONTAL_ALIGNMENT_RIGHT,
		"City Analysis dialog owns its aligned table rows",
	)
	analysis_dialog.free()
	var new_city_dialog := NewCityTerrainDialogUi.new()
	new_city_dialog._ready()
	_check(
		new_city_dialog.city_name_input != null
		and new_city_dialog.mayor_name_input != null
		and new_city_dialog.difficulty_input.item_count == 3
		and new_city_dialog.year_input.item_count == NewCity.STARTING_YEARS.size()
		and new_city_dialog.hills_input.min_value == NewCityTerrain.MIN_SLIDER
		and new_city_dialog.hills_input.max_value == NewCityTerrain.MAX_SLIDER
		and new_city_dialog.preview_view.texture_filter
		== CanvasItem.TEXTURE_FILTER_NEAREST,
		"New City terrain dialog owns its input and preview controls",
	)
	new_city_dialog.free()
	var graph_window := GraphWindowUi.new()
	graph_window._ready()
	_check(
		graph_window.graph_control != null
		and graph_window.series_buttons.size() == GraphControl.SERIES_COUNT,
		"Graph Window owns its graph and series controls",
	)
	graph_window.free()
	var population_window := PopulationWindowUi.new()
	population_window._ready()
	_check(
		population_window.population_control != null
		and population_window.mode_buttons.size() == 3,
		"Population window owns its chart and mode controls",
	)
	population_window.free()
	var industry_window := IndustryWindowUi.new()
	industry_window._ready()
	_check(
		industry_window.industry_control != null
		and industry_window.mode_buttons.size() == 3,
		"City Industry window owns its chart and mode controls",
	)
	industry_window.free()
	var simnation_window := SimNationWindowUi.new()
	simnation_window._ready()
	_check(
		simnation_window.simnation_control != null,
		"SimNation window owns its neighbor view",
	)
	simnation_window.free()
	var city_map_window := CityMapWindowUi.new()
	city_map_window._ready()
	_check(
		city_map_window.map_control != null,
		"City Map window owns its map control",
	)
	city_map_window.free()
	var ordinance_window := OrdinanceWindowUi.new()
	ordinance_window._ready()
	_check(
		ordinance_window.ordinance_control != null,
		"Ordinance window owns its saved-option control",
	)
	ordinance_window.free()
	var old_buildings := PackedByteArray()
	old_buildings.resize(CityModel.TILE_COUNT)
	var new_buildings := old_buildings.duplicate()
	new_buildings[129] = 0x0d
	var old_altitude := PackedByteArray()
	old_altitude.resize(CityModel.TILE_COUNT * 2)
	var new_altitude := old_altitude.duplicate()
	new_altitude[513 * 2 + 1] = 1
	var old_text := PackedByteArray()
	old_text.resize(CityModel.TILE_COUNT)
	var new_text := old_text.duplicate()
	new_text[777] = 202
	var dirty_indices := MainControl._edit_dirty_indices({
		"old_payloads": {"XBLD": old_buildings, "ALTM": old_altitude},
		"new_payloads": {"XBLD": new_buildings, "ALTM": new_altitude},
		"old_text": old_text,
		"new_text": new_text,
		"tile_indices": PackedInt32Array([42]),
		"points": [Vector2i(3, 4)],
	})
	_check(
		dirty_indices == PackedInt32Array([42, 129, 388, 513, 777]),
		"Edit refresh finds changed static tiles and explicit command points",
	)


func _test_budget_dialog() -> void:
	var dialog := BudgetDialogUi.new()
	dialog._ready()
	dialog.set_bond_state(2, 15000, 27500, 3)
	_check(
		dialog.controls.size() == Budget.BUDGET_COUNT
		and dialog.controls[Budget.BUDGET_RESIDENTIAL].max_value == 22
		and dialog.controls[Budget.BUDGET_POLICE].max_value == 100
		and dialog.bond_summary_label.text
		== "2 outstanding; oldest 3%; average 2.75%"
		and not dialog.issue_bond_button.disabled
		and not dialog.repay_bond_button.disabled,
		"Budget dialog owns funding and bond controls",
	)
	dialog.free()

func _check(condition: bool, message: String) -> void:
	check_callback.call(condition, message)
