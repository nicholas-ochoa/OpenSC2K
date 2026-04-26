extends RefCounted

const CityModel = preload("res://src/model/city_state.gd")
const NewCity = preload("res://src/model/new_city_setup.gd")
const NewCityTerrain = preload("res://src/model/new_city_terrain.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const RciStatus = preload("res://src/view/rci_status_control.gd")
const SettingsStoreUi = preload("res://src/ui/settings/app_settings_store.gd")
const CityAnalysisDialogUi = preload("res://src/ui/city_windows/city_analysis_dialog.tscn")
const LibraryRuminateWindowsUi = preload("res://src/ui/city_windows/library_ruminate_windows.gd")
const CitySignDialogUi = preload("res://src/ui/tools/city_sign_dialog.tscn")
const StadiumTeamDialogUi = preload("res://src/ui/tools/stadium_team_dialog.tscn")
const RouteConfirmationDialogUi = preload("res://src/ui/tools/route_confirmation_dialog.gd")
const DebugOverlayUi = preload("res://src/debug/debug_overlay.tscn")
const CityStatusBarUi = preload("res://src/ui/shell/city_status_bar.gd")
const FileDialogsUi = preload("res://src/ui/shared/file_dialog_factory.gd")
const CityMenuBarUi = preload("res://src/ui/shell/city_menu_bar.gd")
const ScurkEditorDialogsUi = preload("res://src/ui/scurk/scurk_editor_dialogs.gd")
const ScurkEditorDrawingControlsUi = preload("res://src/ui/scurk/scurk_editor_drawing_controls.gd")
const NewCityTerrainDialogUi = preload("res://src/ui/startup/new_city_terrain_dialog.tscn")
const BudgetDialogUi = preload("res://src/ui/city_windows/budget_dialog.tscn")
const MainControl = preload("res://src/main.gd")

var check_callback: Callable


class DebugMetricsControl:
	extends Control

	var query_count := 0


	func _debug_metrics() -> Dictionary:
		query_count += 1

		return {"speed": "Paused"}


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
		bars[0].end.y <= zero_y and bars[1].position.y >= zero_y
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
	var debug_metrics_control := DebugMetricsControl.new()
	var debug_overlay := DebugOverlayUi.instantiate()
	debug_overlay.setup(debug_metrics_control)
	debug_overlay.toggle()
	debug_overlay._process(0.1)
	debug_overlay._process(0.15)
	_check(
		debug_metrics_control.query_count == 2,
		"Debug UI reuses one metrics snapshot between timed refreshes",
	)
	debug_overlay.toggle()
	debug_overlay._process(0.25)
	_check(
		debug_metrics_control.query_count == 2,
		"Hidden debug UI does not collect city metrics",
	)
	debug_overlay.free()
	debug_metrics_control.free()
	var settings_dialog := preload("res://src/ui/settings/app_settings_dialog.tscn").instantiate() as AppSettingsDialog
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
	var analysis_dialog := CityAnalysisDialogUi.instantiate() as CityAnalysisDialog
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
		and library_windows.text_views[0].text == "First\nPage"
		and library_windows.windows[3].z_index
		> library_windows.windows[0].z_index,
		"Library Ruminate container owns its modeless text windows",
	)
	library_windows.free()
	var sign_dialog := CitySignDialogUi.instantiate()
	sign_dialog._ready()
	sign_dialog.text_input.text = "Waterfront"
	_check(
		sign_dialog.text_input.max_length == 23
		and sign_dialog.entered_text() == "Waterfront",
		"City Sign dialog owns its bounded text input",
	)
	sign_dialog.free()
	var stadium_dialog := StadiumTeamDialogUi.instantiate()
	stadium_dialog._ready()
	stadium_dialog.set_teams([
		{"id": 2, "name": "Llamas"},
		{"id": 5, "name": "Reticulators"},
	])
	stadium_dialog.team_selector.select(1)
	stadium_dialog._select_team(1)
	_check(
		stadium_dialog.team_selector.item_count == 2
		and stadium_dialog.name_input.max_length == 23
		and stadium_dialog.selected_team_id() == 5
		and stadium_dialog.entered_name() == "Reticulators",
		"Stadium team dialog owns its selector and editable name",
	)
	stadium_dialog.free()
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
		{"type": 0x211},
		{"type": -1},
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
		and not toolbar.view_mode_buttons.height.visible
		and toolbar.view_mode_buttons.city.button_pressed
		and toolbar.view_visibility_checks.size() == 9
		and toolbar.view_visibility_checks["buildings"].button_pressed
		and toolbar.view_visibility_checks["pipes"].button_pressed
		and toolbar.view_visibility_checks["water_mains"].button_pressed,
		"City toolbar owns tool groups, child tools, views, and layer controls",
	)
	toolbar.free()
	var scurk_dialogs := ScurkEditorDialogsUi.new()
	scurk_dialogs._create_dialogs()
	_check(
		scurk_dialogs.open_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE
		and scurk_dialogs.open_dialog.filters[0].contains("*.MIF")
		and scurk_dialogs.save_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE
		and scurk_dialogs.import_bmp_dialog.filters[0].contains("*.BMP")
		and scurk_dialogs.export_bmp_dialog.file_mode
		== FileDialog.FILE_MODE_SAVE_FILE
		and scurk_dialogs.pick_copy_control != null,
		"SCURK editor dialog registry owns its fixed windows",
	)
	scurk_dialogs.free()
	var scurk_drawing_controls := ScurkEditorDrawingControlsUi.new()
	scurk_drawing_controls.build()
	_check(
		scurk_drawing_controls.view_buttons.size() == 3
		and scurk_drawing_controls.view_buttons[0].button_pressed
		and scurk_drawing_controls.tool_buttons.size() == 12
		and scurk_drawing_controls.tool_buttons[0].button_pressed
		and scurk_drawing_controls.paste_tool_button.disabled
		and scurk_drawing_controls.clipboard_action_buttons.size() == 3
		and scurk_drawing_controls.brush_size_selector.item_count == 6
		and scurk_drawing_controls.grid_check.button_pressed
		and scurk_drawing_controls.grid_width_selector.min_value == 1
		and scurk_drawing_controls.grid_width_selector.max_value == 65
		and scurk_drawing_controls.grid_height_selector.min_value == 1
		and scurk_drawing_controls.grid_height_selector.max_value == 65
		and scurk_drawing_controls.cycle_colors_check.button_pressed
		and scurk_drawing_controls.increment_cycle_button.disabled,
		"SCURK drawing controls own view, tool, clipboard, brush, grid, and cycle rows",
	)
	scurk_drawing_controls.free()
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
