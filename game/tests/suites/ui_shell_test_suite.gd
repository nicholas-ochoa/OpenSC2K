extends RefCounted

const NewCity = preload("res://src/model/new_city_setup.gd")
const NewCityTerrain = preload("res://src/model/new_city_terrain.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const RciStatus = preload("res://src/view/rci_status_control.gd")
const SettingsStoreUi = preload("res://src/ui/settings/app_settings_store.gd")
const CityAnalysisDialogUi = preload("res://src/ui/city_windows/city_analysis_dialog.tscn")
const LibraryRuminateWindowsUi = preload("res://src/ui/city_windows/library_ruminate_windows.gd")
const RouteConfirmationDialogUi = preload("res://src/ui/tools/route_confirmation_dialog.gd")
const CityStatusBarUi = preload("res://src/ui/shell/city_status_bar.gd")
const FileDialogsUi = preload("res://src/ui/shared/file_dialog_factory.gd")
const CityMenuBarUi = preload("res://src/ui/shell/city_menu_bar.gd")
const ScurkEditorDialogsUi = preload("res://src/ui/scurk/scurk_editor_dialogs.tscn")
const NewCityTerrainDialogUi = preload("res://src/ui/startup/new_city_terrain_dialog.tscn")
const BudgetDialogUi = preload("res://src/ui/city_windows/budget_dialog.tscn")

var check_callback: Callable


func _init(callback: Callable) -> void:
	check_callback = callback


func test_rci_status_control() -> void:
	_test_rci_status_control()


func test_shell_controls() -> void:
	_test_main_menu()
	_test_budget_dialog()


func _test_rci_status_control() -> void:
	var graph_rect := Rect2(27, 2, 71, 20)
	var bars := RciStatus.bar_rects(Vector3i(2000, -1000, 0), graph_rect)
	var zero_y := graph_rect.get_center().y
	_check(
		bars[0].size.y > 0 and bars[1].size.y > 0
		and bars[0].end.y <= zero_y and bars[1].position.y >= zero_y
		and bars[0].size.y == bars[1].size.y * 2
		and bars[2].size.y == 0
		and graph_rect.encloses(bars[0]) and graph_rect.encloses(bars[1]),
		"RCI bars show signed, proportional demand within the graph",
	)
	var control := RciStatus.new()
	control.set_demand(Vector3i(3000, -3000, 50))
	_check(
		control.demand == Vector3i(2000, -2000, 50)
		and control.demand_available,
		"RCI status control clamps values to the saved demand range",
	)
	control.clear_demand()
	_check(
		not control.demand_available,
		"RCI status control has an explicit no-city state",
	)
	control.free()


func _test_main_menu() -> void:
	var settings_path := "user://test_app_settings_%d.cfg" % OS.get_process_id()
	var settings_error := SettingsStoreUi.save_values(-0.5, 1.5, true, settings_path)
	var saved_settings := SettingsStoreUi.load_values(settings_path)
	_check(
		settings_error == OK
		and saved_settings.music_volume == 0.0
		and saved_settings.effects_volume == 1.0
		and saved_settings.fullscreen,
		"Application settings store saves clamped values",
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	var default_settings := SettingsStoreUi.load_values(
		settings_path, 0.25, 0.75, false
	)
	_check(
		default_settings.music_volume == 0.25
		and default_settings.effects_volume == 0.75
		and not default_settings.fullscreen,
		"Application settings store uses defaults when no file exists",
	)
	_check(
		ScurkPlacePrintControl.placeable_groups()
		== PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 9, 10]),
		"SCURK Place & Print omits both non-placeable animation groups",
	)
	var analysis_dialog := CityAnalysisDialogUi.instantiate() as CityAnalysisDialog
	analysis_dialog._ready()
	analysis_dialog.set_categories([
		QueryActions.Category.new(0, "Roads", 12, 34),
	])
	var analysis_root := analysis_dialog.table.get_root()
	var analysis_item := analysis_root.get_first_child()
	_check(
		analysis_dialog.table.columns == 3
		and analysis_item.get_text(0) == "Roads"
		and analysis_item.get_text(1) == "12"
		and analysis_item.get_text(2) == "34%",
		"City Analysis dialog shows category names, areas, and percentages",
	)
	analysis_dialog.free()
	var library_windows := LibraryRuminateWindowsUi.new()
	library_windows._ready()
	library_windows.show_texts({
		3000: "First\r\nPage",
		3001: "Second",
		3002: "Third",
		3003: "Fourth",
	}, Vector2i(1280, 800))
	_check(
		library_windows.windows.size() == 4
		and library_windows.text_views.size() == 4
		and library_windows.text_views[0].text == "First\nPage",
		"Library Ruminate container owns its modeless text windows",
	)
	library_windows.free()
	var route_dialog := RouteConfirmationDialogUi.new()
	route_dialog.configure(
		"Neighbor Connection",
		"Build a road connection?",
		"Build Connection",
		"Keep Road",
	)
	route_dialog.set_message("Build a rail connection?", "Keep Rail")
	_check(
		route_dialog.title == "Neighbor Connection"
		and route_dialog.dialog_text == "Build a rail connection?"
		and route_dialog.exclusive
		and route_dialog.get_ok_button().text == "Build Connection"
		and route_dialog.get_cancel_button().text == "Keep Rail",
		"Route confirmation dialog owns its prompt and button labels",
	)
	route_dialog.free()
	var status_bar := preload("res://src/ui/shell/city_status_bar.tscn").instantiate() as CityStatusBar
	status_bar._ready()
	status_bar.set_environment(Vector3i(300, -200, 100), "Sunny")
	status_bar.set_speed("Cheetah")
	status_bar.set_reports(PackedStringArray(["First", "Second"]))
	status_bar.update_report_rotation(CityStatusBarUi.REPORT_ROTATION_SECONDS)
	_check(
		status_bar.weather_label.text.contains("Sunny")
		and status_bar.rci_graph.demand == Vector3i(300, -200, 100)
		and status_bar.speed_label.text.contains("Cheetah")
		and status_bar.reports_label.text == "Second",
		"City status bar owns live values and report rotation",
	)
	status_bar.prepend_reports(PackedStringArray(["Latest"]))
	status_bar.prepend_news_items([
		NewsEvent.new(0x211),
		NewsEvent.new(-1),
	])
	status_bar.clear_environment()
	_check(
		status_bar.recent_reports.size() == 3
		and status_bar.reports_label.text == CityStatusBarUi.report_name(-1)
		and status_bar.recent_reports[1] == CityStatusBarUi.report_name(0x211)
		and not status_bar.rci_graph.demand_available,
		"City status bar maps news, replaces reports, and clears city values",
	)
	status_bar.free()
	var city_open_dialog := FileDialogsUi.city_open()
	var city_save_dialog := FileDialogsUi.city_save()
	var tile_set_dialog := FileDialogsUi.tile_set_open()
	var bitmap_dialog := FileDialogsUi.city_bitmap_save()
	var pdf_dialog := FileDialogsUi.city_pdf_save()
	_check(
		city_open_dialog.access == FileDialog.ACCESS_FILESYSTEM
		and city_open_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE
		and city_open_dialog.filters.size() == 3
		and city_open_dialog.filters[0].contains("*.SC2")
		and city_open_dialog.filters[1].contains("*.sc2x")
		and city_open_dialog.filters[2].contains("*.SCN")
		and city_save_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE
		and tile_set_dialog.filters[0].contains("*.MIF")
		and bitmap_dialog.filters[0].contains("*.BMP")
		and pdf_dialog.filters[0].contains("*.PDF"),
		"File dialog factory owns modes and file filters",
	)
	city_open_dialog.free()
	city_save_dialog.free()
	tile_set_dialog.free()
	bitmap_dialog.free()
	pdf_dialog.free()
	var menu_bar := CityMenuBarUi.new()
	menu_bar._ready()
	var pause_index := menu_bar.speed_menu.get_popup().get_item_index(0)
	_check(
		menu_bar.file_menu.get_popup().get_item_index(CityMenuBarUi.MENU_SAVE_CITY) >= 0
		and menu_bar.options_menu.get_popup().get_item_index(CityMenuBarUi.MENU_UPGRADE_SC2X) < 0
		and menu_bar.speed_menu.get_popup().is_item_checkable(pause_index)
		and menu_bar.options_menu.disabled
		and menu_bar.view_menu.get_popup().get_item_index(
			CityMenuBarUi.MENU_VIEW_CITY_MAP
		) >= 0
		and menu_bar.disasters_menu.get_popup().get_item_index(
			CityMenuBarUi.MENU_NO_DISASTERS
		) >= 0,
		"City menu bar owns menus and city metrics",
	)
	menu_bar.set_city_name("Test City")
	menu_bar.set_population("12,345")
	menu_bar.set_date("01/02/2003")
	menu_bar.set_money("$45,678")
	menu_bar.set_fps(120)
	_check(
		menu_bar.city_label.text == "Test City"
		and menu_bar.city_label.tooltip_text == "Test City"
		and menu_bar.population_label.text.contains("12,345")
		and menu_bar.date_label.text == "01/02/2003"
		and menu_bar.money_label.text == "$45,678"
		and menu_bar.fps_label.text.contains("120"),
		"City menu bar owns live metric formatting",
	)
	menu_bar.free()
	var toolbar := preload("res://src/ui/shell/city_toolbar.tscn").instantiate() as CityToolbar
	toolbar._ready()
	var first_residential := toolbar.show_tool_group(9, null)
	_check(
		toolbar.toolbar_buttons.size() == 18
		and toolbar.rotate_counter_clockwise_button.disabled
		and toolbar.rotate_clockwise_button.disabled
		and toolbar.child_tool_buttons.size() == 2
		and first_residential == 0
		and toolbar.view_mode_buttons.size() == 3
		and not toolbar.view_mode_buttons[CityViewMode.Mode.HEIGHT].visible
		and toolbar.view_mode_buttons[CityViewMode.Mode.CITY].button_pressed
		and toolbar.view_visibility_checks.size() == 10
		and toolbar.view_visibility_checks["buildings"].button_pressed
		and toolbar.view_visibility_checks["vehicles"].button_pressed
		and toolbar.view_visibility_checks["pipes"].button_pressed
		and toolbar.view_visibility_checks["water_mains"].button_pressed,
		"City toolbar owns tool groups, child tools, views, and layer controls",
	)
	toolbar.free()
	var scurk_dialogs := ScurkEditorDialogsUi.instantiate() as ScurkEditorDialogs
	scurk_dialogs._create_dialogs()
	_check(
		scurk_dialogs.open_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE
		and scurk_dialogs.open_dialog.filters[0].contains("*.scurk")
		and scurk_dialogs.open_dialog.filters[1].contains("*.MIF")
		and scurk_dialogs.save_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE
		and scurk_dialogs.import_bmp_dialog.filters[0].contains("*.BMP")
		and scurk_dialogs.export_bmp_dialog.file_mode
		== FileDialog.FILE_MODE_SAVE_FILE
		and scurk_dialogs.pick_copy_control != null,
		"SCURK editor dialog registry owns its fixed windows",
	)
	scurk_dialogs.free()
	var new_city_dialog := NewCityTerrainDialogUi.instantiate() as NewCityTerrainDialog
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


func _test_budget_dialog() -> void:
	var dialog := BudgetDialogUi.instantiate() as BudgetDialog
	dialog._ready()
	dialog.set_bond_state(2, 15000, 27500, 3)
	_check(
		dialog.controls.size() == Budget.BUDGET_COUNT
		and dialog.controls[Budget.BUDGET_RESIDENTIAL].max_value == 22
		and dialog.controls[Budget.BUDGET_POLICE].max_value == 100
		and not dialog.issue_bond_button.disabled
		and not dialog.repay_bond_button.disabled,
		"Budget dialog owns funding and bond controls",
	)
	dialog.free()


func _check(condition: bool, message: String) -> void:
	check_callback.call(condition, message)
