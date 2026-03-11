extends RefCounted

const CityModel = preload("res://src/model/city_state.gd")
const NewCity = preload("res://src/model/new_city_setup.gd")
const NewCityTerrain = preload("res://src/model/new_city_terrain.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const ScurkPlaceControl = preload("res://src/ui/scurk/scurk_place_print_control.gd")
const RciStatus = preload("res://src/view/rci_status_control.gd")
const GraphControl = preload("res://src/view/city_graph_control.gd")
const MainMenu = preload("res://src/ui/startup/main_menu_control.gd")
const SettingsDialogUi = preload("res://src/ui/settings/app_settings_dialog.gd")
const SettingsStoreUi = preload("res://src/ui/settings/app_settings_store.gd")
const ScenarioIntroDialogUi = preload("res://src/ui/startup/scenario_intro_dialog.gd")
const CityAnalysisDialogUi = preload("res://src/ui/city_windows/city_analysis_dialog.gd")
const LibraryRuminateWindowsUi = preload("res://src/ui/city_windows/library_ruminate_windows.gd")
const CitySignDialogUi = preload("res://src/ui/tools/city_sign_dialog.gd")
const BridgeSelectionDialogUi = preload("res://src/ui/tools/bridge_selection_dialog.gd")
const ToolChoiceDialogUi = preload("res://src/ui/tools/tool_choice_dialog.gd")
const StadiumTeamDialogUi = preload("res://src/ui/tools/stadium_team_dialog.gd")
const RouteConfirmationDialogUi = preload("res://src/ui/tools/route_confirmation_dialog.gd")
const PictureNoticeDialogUi = preload("res://src/ui/shared/picture_notice_dialog.tscn")
const AboutDialogUi = preload("res://src/ui/settings/about_dialog.tscn")
const SaveChangesDialogUi = preload("res://src/ui/shared/save_changes_dialog.gd")
const DebugOverlayUi = preload("res://src/debug/debug_overlay.tscn")
const CityStatusBarUi = preload("res://src/ui/shell/city_status_bar.gd")
const FileDialogsUi = preload("res://src/ui/shared/file_dialog_factory.gd")
const CityMenuBarUi = preload("res://src/ui/shell/city_menu_bar.gd")
const CityToolbarUi = preload("res://src/ui/shell/city_toolbar.gd")
const CityWorkspaceUi = preload("res://src/ui/shell/city_workspace.gd")
const CityDialogsUi = preload("res://src/ui/shell/city_dialog_registry.gd")
const MainOverlaysUi = preload("res://src/ui/shell/main_overlay_registry.gd")
const ScurkEditorToolbarUi = preload("res://src/ui/scurk/scurk_editor_toolbar.gd")
const ScurkEditorDialogsUi = preload("res://src/ui/scurk/scurk_editor_dialogs.gd")
const ScurkEditorPalettePanelUi = preload("res://src/ui/scurk/scurk_editor_palette_panel.gd")
const ScurkEditorObjectPanelUi = preload("res://src/ui/scurk/scurk_editor_object_panel.gd")
const ScurkEditorDrawingControlsUi = preload("res://src/ui/scurk/scurk_editor_drawing_controls.gd")
const ScurkEditorCanvasPanelUi = preload("res://src/ui/scurk/scurk_editor_canvas_panel.gd")
const OriginalAssetsUi = preload("res://src/assets/original_game_assets.gd")
const ClassicStyleUi = preload("res://src/ui/shared/classic_ui_style.gd")
const GraphWindowUi = preload("res://src/ui/city_windows/city_graph_window.gd")
const PopulationWindowUi = preload("res://src/ui/city_windows/city_population_window.gd")
const IndustryWindowUi = preload("res://src/ui/city_windows/city_industry_window.gd")
const SimNationWindowUi = preload("res://src/ui/city_windows/city_simnation_window.gd")
const CityMapWindowUi = preload("res://src/ui/city_windows/city_map_window.gd")
const OrdinanceWindowUi = preload("res://src/ui/city_windows/city_ordinance_window.gd")
const NewCityTerrainDialogUi = preload("res://src/ui/startup/new_city_terrain_dialog.gd")
const BudgetDialogUi = preload("res://src/ui/city_windows/budget_dialog.gd")
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
	var classic_box := ClassicStyleUi.create_box(
		Color("c0c0c0"), Color("808080"), 2, 8, 6
	)
	var classic_theme := ClassicStyleUi.create_theme()
	_check(
		classic_box.bg_color == Color("c0c0c0")
		and classic_box.border_color == Color("808080")
		and classic_box.get_border_width(SIDE_LEFT) == 2
		and classic_box.content_margin_left == 8
		and classic_box.content_margin_top == 6
		and classic_theme.default_font_size == 13
		and classic_theme.get_color("font_color", "TooltipLabel") == Color.WHITE,
		"Classic UI style owns shared boxes and theme defaults",
	)
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
		and library_windows.windows[1].position
		- library_windows.windows[0].position == Vector2(28, 28)
		and library_windows.windows[3].z_index
		> library_windows.windows[0].z_index,
		"Library Ruminate container owns its modeless text windows",
	)
	library_windows.free()
	var sign_dialog := CitySignDialogUi.new()
	sign_dialog._ready()
	sign_dialog.text_input.text = "Waterfront"
	_check(
		sign_dialog.text_input.max_length == 23
		and sign_dialog.entered_text() == "Waterfront",
		"City Sign dialog owns its bounded text input",
	)
	sign_dialog.free()
	var bridge_dialog := BridgeSelectionDialogUi.new()
	bridge_dialog._ready()
	bridge_dialog.set_choices(4, "network", [
		{"name": "Standard", "cost": 12345, "cost_per_tile": 678},
		{"name": "Reinforced", "cost": 23456, "cost_per_tile": 789},
	], false)
	_check(
		bridge_dialog.choice_buttons.size() == 3
		and bridge_dialog.dialog_text == "Select a bridge for 4 water tiles."
		and bridge_dialog.choice_buttons[0].text
		== "Standard\n$12,345 total\n$678 for each water tile"
		and not bridge_dialog.choice_buttons[2].visible,
		"Bridge dialog owns its choice layout and price formatting",
	)
	bridge_dialog.free()
	var tool_choice_dialog := ToolChoiceDialogUi.new()
	tool_choice_dialog._ready()
	tool_choice_dialog.set_tools("Select Arcology", "Select one.", [
		{"name": "Plymouth Arcology", "cost": 100000},
		{"name": "Forest Arcology", "cost": 120000},
	])
	_check(
		tool_choice_dialog.choice_buttons.size() == 9
		and tool_choice_dialog.title == "Select Arcology"
		and tool_choice_dialog.choice_buttons[0].text
		== "Plymouth Arcology\n$100,000"
		and not tool_choice_dialog.choice_buttons[2].visible,
		"Tool choice dialog owns its building grid and price formatting",
	)
	tool_choice_dialog.free()
	var stadium_dialog := StadiumTeamDialogUi.new()
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
		and route_dialog.min_size == Vector2i(520, 210)
		and route_dialog.exclusive
		and route_dialog.get_ok_button().text == "Build Connection"
		and route_dialog.get_cancel_button().text == "Keep Rail",
		"Route confirmation dialog owns its prompt and button labels",
	)
	route_dialog.free()
	var notice_dialog := PictureNoticeDialogUi.instantiate()
	notice_dialog._ready()
	notice_dialog.configure(
		"TestNoticeDialog",
		"Test Notice",
		"TestNoticeImage",
		"TestNoticeMessage",
		null,
		"First line\r\nSecond line",
	)
	_check(
		notice_dialog.name == "TestNoticeDialog"
		and notice_dialog.title == "Test Notice"
		and notice_dialog.picture_view.name == "TestNoticeImage"
		and notice_dialog.picture_view.texture_filter
		== CanvasItem.TEXTURE_FILTER_NEAREST
		and notice_dialog.message_label.name == "TestNoticeMessage"
		and notice_dialog.message_label.text == "First line\nSecond line",
		"Picture notice dialog owns its image and message layout",
	)
	notice_dialog.free()
	var about_dialog := AboutDialogUi.instantiate()
	about_dialog._ready()
	_check(
		about_dialog.title == "About OpenSC2K"
		and about_dialog.dialog_text.contains("SimCity 2000 for Windows 95")
		and about_dialog.min_size == Vector2i(560, 250)
		and about_dialog.exclusive,
		"About dialog owns its fixed product text and layout",
	)
	about_dialog.free()
	var save_changes_dialog := SaveChangesDialogUi.new()
	save_changes_dialog._ready()
	save_changes_dialog.set_city("Starter City")
	var has_discard_button := false

	for child in save_changes_dialog.find_children("*", "Button", true, false):
		var button := child as Button

		if button != null and button.text == "Don't Save":
			has_discard_button = true

	_check(
		save_changes_dialog.title == "Save Changes"
		and save_changes_dialog.dialog_text
		== "Save changes to Starter City before you continue?"
		and save_changes_dialog.min_size == Vector2i(480, 190)
		and save_changes_dialog.exclusive
		and save_changes_dialog.get_label().get_theme_color("font_color") == Color.WHITE
		and save_changes_dialog.get_ok_button().text == "Save"
		and save_changes_dialog.get_cancel_button().text == "Cancel"
		and has_discard_button,
		"Save Changes dialog owns its prompt and standard actions",
	)
	save_changes_dialog.free()
	var status_bar := preload("res://src/ui/shell/city_status_bar.tscn").instantiate() as CityStatusBar
	status_bar._ready()
	_check(
		status_bar.message_label.text == "Ready."
		and status_bar.message_label.size_flags_horizontal
		== Control.SIZE_EXPAND_FILL
		and status_bar.weather_label.text == "Weather: --"
		and status_bar.rci_graph != null
		and status_bar.reports_label.text == "News: None"
		and status_bar.speed_label.text == "Speed: --",
		"City status bar owns its metrics and RCI layout",
	)
	status_bar.set_environment(Vector3i(300, -200, 100), "Sunny")
	status_bar.set_speed("Cheetah")
	status_bar.set_reports(PackedStringArray(["First", "Second"]))
	status_bar.update_report_rotation(CityStatusBarUi.REPORT_ROTATION_SECONDS)
	_check(
		status_bar.weather_label.text == "Weather: Sunny"
		and status_bar.rci_graph.demand == Vector3i(300, -200, 100)
		and status_bar.speed_label.text == "Speed: Cheetah"
		and status_bar.reports_label.text == "News: Second",
		"City status bar owns live values and report rotation",
	)
	status_bar.prepend_reports(PackedStringArray(["Latest"]))
	status_bar.prepend_news_items([
		{"type": 0x211},
		{"type": -1},
	])
	status_bar.clear_environment()
	_check(
		status_bar.reports_label.text == "News: City report"
		and status_bar.recent_reports.size() == 3
		and status_bar.recent_reports[1] == "Arcology launch"
		and status_bar.weather_label.text == "Weather: --"
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
		menu_bar.file_menu.get_popup().item_count == 12
		and menu_bar.file_menu.get_popup().get_item_index(CityMenuBarUi.MENU_SAVE_CITY) >= 0
		and menu_bar.options_menu.get_popup().get_item_index(CityMenuBarUi.MENU_UPGRADE_SC2X) < 0
		and menu_bar.speed_menu.get_popup().item_count == 5
		and menu_bar.speed_menu.get_popup().is_item_checkable(pause_index)
		and menu_bar.options_menu.disabled
		and menu_bar.view_menu.get_popup().get_item_index(
			CityMenuBarUi.MENU_VIEW_CITY_MAP
		) >= 0
		and menu_bar.disasters_menu.get_popup().get_item_index(
			CityMenuBarUi.MENU_NO_DISASTERS
		) >= 0
		and menu_bar.city_label.text == "No city loaded"
		and menu_bar.population_label.text == "Population: --"
		and menu_bar.date_label.text == "--/--/----"
		and menu_bar.money_label.text == "$--"
		and menu_bar.fps_label.text == "FPS: --",
		"City menu bar owns menus and city metrics",
	)
	_check(
		CityMenuBarUi.disaster_name(1) == "Fire"
		and CityMenuBarUi.disaster_name(18) == "Plane Crash"
		and CityMenuBarUi.disaster_name(0) == "None"
		and CityMenuBarUi.disaster_name(99) == "Disaster",
		"City menu bar owns disaster display names",
	)
	menu_bar.set_city_name("Test City")
	menu_bar.set_population("12,345")
	menu_bar.set_date("01/02/2003")
	menu_bar.set_money("$45,678")
	menu_bar.set_fps(120)
	_check(
		menu_bar.city_label.text == "Test City"
		and menu_bar.city_label.tooltip_text == "Test City"
		and menu_bar.population_label.text == "Population: 12,345"
		and menu_bar.date_label.text == "01/02/2003"
		and menu_bar.money_label.text == "$45,678"
		and menu_bar.fps_label.text == "FPS: 120",
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
		and toolbar.child_tool_grid.columns == 1
		and toolbar.child_tool_buttons.size() == 2
		and first_residential == 0
		and toolbar.active_tool_group_label.text == "Residential"
		and toolbar.child_tool_buttons[0].text == "Light Residential\n$5"
		and toolbar.child_tool_buttons[1].text == "Dense Residential\n$10"
		and toolbar.child_palette.size_flags_vertical == Control.SIZE_EXPAND_FILL
		and toolbar.view_mode_buttons.size() == 2
		and toolbar.view_mode_buttons.city.button_pressed
		and toolbar.view_visibility_checks.size() == 8
		and toolbar.view_visibility_checks["buildings"].button_pressed
		and toolbar.view_visibility_checks["pipes"].button_pressed,
		"City toolbar owns tool groups, child tools, views, and layer controls",
	)
	toolbar.free()
	var workspace := preload("res://src/ui/shell/city_workspace.tscn").instantiate() as CityWorkspace
	workspace._ready()
	_check(
		workspace.menu_bar != null
		and workspace.toolbar != null
		and workspace.map_view != null
		and workspace.status_bar != null
		and workspace.map_view.get_parent() == workspace
		and workspace.get_node("Page/Content/MapSpace").mouse_filter == Control.MOUSE_FILTER_IGNORE
		and workspace.status_bar.get_parent() == workspace.menu_bar.get_parent(),
		"City workspace owns the main shell layout",
	)
	workspace.free()
	var dialog_registry := CityDialogsUi.new(OriginalAssetsUi.new())
	dialog_registry._create_file_dialogs()
	dialog_registry._create_tool_dialogs()
	_check(
		dialog_registry.city_open_dialog != null
		and dialog_registry.city_save_dialog != null
		and dialog_registry.new_city_dialog != null
		and dialog_registry.sign_dialog != null
		and dialog_registry.bridge_dialog != null
		and dialog_registry.tool_choice_dialog != null
		and dialog_registry.stadium_dialog != null
		and dialog_registry.query_dialog != null,
		"City dialog registry owns file and tool dialogs",
	)
	_check(
		dialog_registry.network_connection_dialog.dialog_text.contains("$1,000")
		and dialog_registry.highway_connection_dialog.dialog_text.contains("$1,500")
		and dialog_registry.tunnel_dialog.min_size == Vector2i(500, 200),
		"City dialog registry owns fixed route prompts",
	)
	dialog_registry.free()
	var main_overlays := MainOverlaysUi.new()
	main_overlays._create_overlays()
	_check(
		main_overlays.main_menu != null
		and not main_overlays.main_menu.visible
		and main_overlays.main_menu.z_index == 850
		and main_overlays.settings_dialog != null
		and main_overlays.scurk_editor != null
		and main_overlays.scurk_editor.z_index == 940
		and main_overlays.scurk_place_print != null
		and main_overlays.scurk_print != null
		and main_overlays.about_dialog != null
		and main_overlays.save_changes_dialog != null,
		"Main overlay registry owns menu, SCURK, and application overlays",
	)
	main_overlays.free()
	var scurk_toolbar := ScurkEditorToolbarUi.new()
	scurk_toolbar._ready()
	_check(
		scurk_toolbar.get_child_count() == 16
		and scurk_toolbar.get_child(0).text == "Open..."
		and scurk_toolbar.save_button.text == "Save"
		and scurk_toolbar.undo_button.text == "Undo"
		and scurk_toolbar.redo_button.text == "Redo"
		and scurk_toolbar.revert_button.text == "Revert Object"
		and scurk_toolbar.clear_button.text == "Clear Object"
		and scurk_toolbar.get_child(15).text == "City",
		"SCURK editor toolbar owns its command controls",
	)
	scurk_toolbar.free()
	var scurk_dialogs := ScurkEditorDialogsUi.new()
	scurk_dialogs._create_dialogs()
	_check(
		scurk_dialogs.open_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE
		and scurk_dialogs.open_dialog.filters[0].contains("*.MIF")
		and scurk_dialogs.save_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE
		and scurk_dialogs.import_bmp_dialog.filters[0].contains("*.BMP")
		and scurk_dialogs.export_bmp_dialog.file_mode
		== FileDialog.FILE_MODE_SAVE_FILE
		and scurk_dialogs.discard_dialog.title == "Unsaved SCURK Changes"
		and scurk_dialogs.error_dialog.title == "SCURK Error"
		and scurk_dialogs.pick_copy_control != null,
		"SCURK editor dialog registry owns its fixed windows",
	)
	scurk_dialogs.free()
	var scurk_palette_panel := ScurkEditorPalettePanelUi.new()
	scurk_palette_panel.build()
	scurk_palette_panel.set_colors(4, 255)
	scurk_palette_panel.set_pointer(Vector2i(3, 7), 12)
	_check(
		scurk_palette_panel.custom_minimum_size.x == 300
		and scurk_palette_panel.palette_control != null
		and scurk_palette_panel.texture_control != null
		and scurk_palette_panel.foreground_color_label.text
		== "Foreground: 4 (0x04)"
		and scurk_palette_panel.background_color_label.text
		== "Background: 255 (0xFF)"
		and scurk_palette_panel.pointer_status_label.text
		== "Pointer: 3, 7 — index 12",
		"SCURK palette panel owns colors, textures, and pointer text",
	)
	scurk_palette_panel.free()
	var scurk_object_panel := ScurkEditorObjectPanelUi.new()
	scurk_object_panel.build()
	_check(
		scurk_object_panel.custom_minimum_size.x == 220
		and scurk_object_panel.object_search.placeholder_text
		== "Filter by ID or name"
		and scurk_object_panel.object_list.name == "TileObjectList"
		and scurk_object_panel.object_list.size_flags_vertical
		== Control.SIZE_EXPAND_FILL
		and scurk_object_panel.name_edit.placeholder_text
		== "Optional tile name"
		and scurk_object_panel.name_button.text == "Set Name"
		and scurk_object_panel.revert_name_button.text == "Revert Name",
		"SCURK object panel owns filter, list, and query-name controls",
	)
	scurk_object_panel.free()
	var scurk_drawing_controls := ScurkEditorDrawingControlsUi.new()
	scurk_drawing_controls.build()
	_check(
		scurk_drawing_controls.view_buttons.size() == 3
		and scurk_drawing_controls.view_buttons[0].button_pressed
		and scurk_drawing_controls.zoom_label.text == "4x"
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
	var scurk_canvas_panel := ScurkEditorCanvasPanelUi.new()
	scurk_canvas_panel.build()
	_check(
		scurk_canvas_panel.pixel_canvas.name == "PixelCanvas"
		and scurk_canvas_panel.view_previews.size() == 3
		and scurk_canvas_panel.view_preview_panels.size() == 3
		and scurk_canvas_panel.view_previews[0].name == "LargeViewPreview"
		and scurk_canvas_panel.view_previews[1].name == "MediumViewPreview"
		and scurk_canvas_panel.view_previews[2].name == "SmallViewPreview"
		and scurk_canvas_panel.sprite_status_label.text
		== "No sprite is selected.",
		"SCURK canvas panel owns the pixel canvas, view windows, and sprite status",
	)
	scurk_canvas_panel.free()
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
