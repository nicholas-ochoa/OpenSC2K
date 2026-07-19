class_name ApplicationInterface
extends RefCounted


const DisplayNumbers = preload("res://src/ui/shared/display_number_format.gd")
const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")
const CityWorkspaceView = preload("res://src/ui/shell/city_workspace.tscn")
const CityDialogsView = preload("res://src/ui/shell/city_dialog_registry.gd")
const MainOverlaysView = preload("res://src/ui/shell/main_overlay_registry.gd")
const RciAftermath = preload("res://src/simulation/growth/rci_aftermath_phase.gd")
const Music = preload("res://src/audio/music_director.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func _build_interface(original_assets: OriginalGameAssets) -> void:
	app.theme = ClassicStyle.create_theme()
	app.city_workspace = CityWorkspaceView.instantiate() as CityWorkspace
	app.city_workspace.toolbar_art = original_assets.toolbar_art
	app.add_child(app.city_workspace)

	app.city_menu_bar = app.city_workspace.menu_bar
	app.city_menu_bar.file_menu_requested.connect(app.menus._on_file_menu)
	app.city_menu_bar.speed_menu_requested.connect(app.menus._on_speed_menu)
	app.city_menu_bar.options_menu_requested.connect(app.menus._on_options_menu)
	app.city_menu_bar.view_menu_requested.connect(app.menus._on_view_menu)
	app.city_menu_bar.disaster_menu_requested.connect(app.reports._on_disaster_menu)
	app.city_menu_bar.windows_menu_requested.connect(app.reports._on_windows_menu)
	app.city_menu_bar.newspaper_menu_requested.connect(app.reports._on_newspaper_menu)
	app.city_menu_bar.newspaper_menu.about_to_popup.connect(app.reports._refresh_newspaper_menu)
	app.city_menu_bar.help_menu_requested.connect(app.reports._on_help_menu)
	app.speed_menu = app.city_menu_bar.speed_menu
	app.options_menu = app.city_menu_bar.options_menu
	app.view_menu = app.city_menu_bar.view_menu
	app.disasters_menu = app.city_menu_bar.disasters_menu

	app.city_toolbar = app.city_workspace.toolbar
	app.city_toolbar.button_clicked.connect(func() -> void:
		if app.app_toolbar_sounds:
			app.audio_controller.play_toolbar_click(app.city == null or app.city.sound_enabled())
	)
	app.city_toolbar.group_requested.connect(app.camera_input._choose_tool_group)
	app.city_toolbar.subtool_requested.connect(app.current_tool._select_subtool)
	app.city_toolbar.rotate_requested.connect(app.camera_input._rotate_city)
	app.city_toolbar.zoom_out_requested.connect(app.camera_input._zoom_out)
	app.city_toolbar.zoom_in_requested.connect(app.camera_input._zoom_in)
	app.city_toolbar.overlay_requested.connect(app.menus._set_overlay)
	app.city_toolbar.surface_visibility_requested.connect(app.menus._set_surface_visibility)
	app.city_toolbar.underground_water_mains_visibility_requested.connect(app.menus._set_underground_water_mains_visible)
	app.city_toolbar.underground_pipes_visibility_requested.connect(
		app.menus._set_underground_pipes_visible
	)
	app.city_toolbar.underground_subways_visibility_requested.connect(app.menus._set_underground_subways_visible)
	app.rotate_counter_clockwise_button = app.city_toolbar.rotate_counter_clockwise_button
	app.rotate_clockwise_button = app.city_toolbar.rotate_clockwise_button
	app.zoom_out_button = app.city_toolbar.zoom_out_button
	app.zoom_in_button = app.city_toolbar.zoom_in_button
	app.view_layers_heading = app.city_toolbar.view_layers_heading
	app.view_visibility_checks = app.city_toolbar.view_visibility_checks

	app.map_view = app.city_workspace.map_view
	app.map_view.selection_completed.connect(app.city_edits._apply_map_selection)
	app.map_view.selection_changed.connect(app.camera_input._on_map_selection_changed)
	app.network_preview = NetworkPlacementPreview.new()
	app.network_preview.map_view = app.map_view
	app.network_preview.z_index = CityMapControl.NETWORK_PREVIEW_Z_INDEX
	app.network_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	app.map_view.add_child(app.network_preview)
	app.map_view.selection_finished.connect(app.network_preview.clear)
	app.map_view.selection_canceled.connect(app.network_preview.clear)
	app.map_view.selection_started.connect(app.camera_input._on_map_selection_started)
	app.map_view.stretch_changed.connect(app.camera_input._on_terrain_stretch_changed)
	app.map_view.selection_finished.connect(app.camera_input._on_map_selection_finished)
	app.map_view.selection_canceled.connect(app.camera_input._on_map_selection_canceled)
	app.map_view.query_requested.connect(app.query_choices._open_query)
	app.map_view.center_requested.connect(app.camera_input._center_map_on_tile)
	app.map_view.zoom_changed.connect(app.camera_input._on_city_zoom_changed)
	app.map_view.viewport_changed.connect(app.reports._refresh_city_map_viewport)
	app.city_status_bar = app.city_workspace.status_bar
	app.status_label = app.city_status_bar.message_label
	app.frame._sync_speed_ui()

	app.city_dialogs = CityDialogsView.new(original_assets)
	app.city_dialogs.name = "CityDialogs"
	app.add_child(app.city_dialogs)

	app.file_dialog = app.city_dialogs.city_open_dialog
	app.file_dialog.file_selected.connect(app.city_files._load_city)
	app.save_dialog = app.city_dialogs.city_save_dialog
	app.save_dialog.file_selected.connect(app.city_files._on_save_path_selected)
	app.save_dialog.canceled.connect(app.city_files._on_save_dialog_canceled)
	app.tile_set_dialog = app.city_dialogs.tile_set_dialog
	app.tile_set_dialog.file_selected.connect(app.scurk_workspace._load_tile_set)
	app.city_png_export_dialog = app.city_dialogs.png_export_dialog
	app.city_png_export_dialog.export_requested.connect(app.city_png_export._start_export)
	app.city_png_export_progress = app.city_dialogs.png_export_progress


	app.city_toolbar.start_city_requested.connect(app.new_city._start_city)
	app.city_toolbar.regenerate_requested.connect(app.new_city._reopen_terrain_dialog)
	app.city_toolbar.brush_changed.connect(app.current_tool._update_edit_state)
	app.new_city_dialog = app.city_dialogs.new_city_dialog
	app.new_city_dialog.visibility_changed.connect(app.new_city._sync_new_city_workspace)
	app.new_city_dialog.cancel_requested.connect(app.new_city._cancel_new_city)
	app.new_city_dialog.build_requested.connect(app.new_city._create_new_city)
	app.new_city_dialog.preview_requested.connect(app.new_city._schedule_new_city_preview)
	app.new_city_dialog.terrain_regeneration_requested.connect(app.new_city._make_new_city_preview)
	app.sign_dialog = app.city_dialogs.sign_dialog
	app.sign_dialog.confirmed.connect(app.query_choices._commit_sign)
	app.sign_dialog.canceled.connect(app.query_choices._cancel_sign)
	app.bridge_dialog = app.city_dialogs.bridge_dialog
	app.bridge_dialog.choice_requested.connect(app.network_edits._choose_bridge)
	app.bridge_dialog.canceled.connect(app.network_edits._cancel_bridge)
	app.tool_choice_dialog = app.city_dialogs.tool_choice_dialog
	app.tool_choice_dialog.choice_requested.connect(app.query_choices._choose_tool_variant)
	app.tool_choice_dialog.canceled.connect(app.query_choices._cancel_tool_choice)
	app.stadium_dialog = app.city_dialogs.stadium_dialog
	app.stadium_dialog.confirmed.connect(app.query_choices._confirm_stadium_team)
	app.stadium_dialog.canceled.connect(app.query_choices._cancel_stadium_team)
	app.network_connection_dialog = app.city_dialogs.network_connection_dialog
	app.network_connection_dialog.confirmed.connect(app.network_edits._confirm_network_connection)
	app.network_connection_dialog.canceled.connect(app.network_edits._cancel_network_connection)
	app.highway_connection_dialog = app.city_dialogs.highway_connection_dialog
	app.highway_connection_dialog.confirmed.connect(app.route_edits._confirm_highway_connection)
	app.highway_connection_dialog.canceled.connect(app.route_edits._cancel_highway_connection)
	app.tunnel_dialog = app.city_dialogs.tunnel_dialog
	app.tunnel_dialog.confirmed.connect(app.route_edits._confirm_tunnel)
	app.tunnel_dialog.canceled.connect(app.route_edits._cancel_tunnel)
	app.query_dialog = app.city_dialogs.query_dialog
	app.query_dialog.close_requested.connect(app.query_choices._close_query)
	app.query_dialog.action_requested.connect(app.query_choices._run_query_action)
	app.graph_window = app.city_dialogs.graph_window
	app.population_window = app.city_dialogs.population_window
	app.industry_window = app.city_dialogs.industry_window
	app.industry_window.tax_rates_changed.connect(app.reports._on_industry_tax_rates_changed)
	app.simnation_window = app.city_dialogs.simnation_window
	app.city_map_window = app.city_dialogs.city_map_window
	app.city_map_window.mode_changed.connect(app.reports._on_city_map_mode_changed)
	app.city_map_window.center_requested.connect(app.reports._on_city_map_center_requested)
	app.ordinance_window = app.city_dialogs.ordinance_window
	app.ordinance_window.ordinances_changed.connect(app.reports._on_ordinances_changed)
	app.ordinance_window.update_failed.connect(_show_error)
	app.city_analysis_dialog = app.city_dialogs.analysis_dialog
	app.newspaper_dialog = app.city_dialogs.newspaper_dialog
	app.newspaper_dialog.visibility_changed.connect(app.new_city._on_founding_newspaper_visibility_changed)
	app.building_objection_dialog = app.city_dialogs.building_objection_dialog
	app.building_objection_dialog.confirmed.connect(app.reports._on_building_objection_closed)
	app.building_objection_dialog.canceled.connect(app.reports._on_building_objection_closed)
	app.library_ruminate_windows = app.city_dialogs.library_windows
	app.game_over_dialog = app.city_dialogs.game_over_dialog
	app.scenario_dialog = app.city_dialogs.scenario_dialog
	app.scenario_dialog.confirmed.connect(app.budget._begin_scenario)
	app.military_dialog = app.city_dialogs.military_dialog
	app.military_dialog.confirmed.connect(app.budget._accept_military_proposal)
	app.military_dialog.canceled.connect(app.budget._decline_military_proposal)
	app.budget_dialog = app.city_dialogs.budget_dialog
	app.budget_dialog.apply_requested.connect(app.budget._commit_budget)
	app.budget_dialog.cancel_requested.connect(app.budget._cancel_budget)
	app.budget_dialog.issue_bond_requested.connect(app.budget._request_issue_bond)
	app.budget_dialog.repay_bond_requested.connect(app.budget._request_repay_bond)
	app.budget_dialog.bond_confirmation_resolved.connect(app.budget._resolve_bond_action)

	app.current_tool._select_tool_group(app.selected_group)
	app.camera_input._update_zoom_controls(app.map_view.zoom_percent())
	_build_main_menu()
	app.about_dialog.set_assets(original_assets)


func _build_main_menu() -> void:
	app.main_overlays = MainOverlaysView.new()
	app.main_overlays.name = "ApplicationOverlays"
	app.add_child(app.main_overlays)
	app.main_menu = app.main_overlays.main_menu
	app.main_menu.continue_requested.connect(_hide_main_menu)
	app.main_menu.new_city_requested.connect(app.new_city._open_new_city_dialog)
	app.main_menu.open_city_requested.connect(app.city_files._open_city_dialog)
	app.main_menu.scenario_requested.connect(app.city_files._open_scenario_dialog)
	app.main_menu.settings_requested.connect(app.settings._open_settings_dialog)
	app.main_menu.import_assets_requested.connect(app.settings._open_import_settings)
	app.main_menu.scurk_requested.connect(app.scurk_workspace._open_scurk_dialog)
	app.main_menu.scurk_place_requested.connect(app.scurk_workspace._open_scurk_place_print)
	app.main_menu.about_requested.connect(_open_about_dialog)
	app.main_menu.exit_requested.connect(app.city_files._request_city_exit.bind("quit"))

	app.settings_dialog = app.main_overlays.settings_dialog
	app.settings_dialog.confirmed.connect(app.settings._apply_settings)
	app.settings_dialog.import_original_requested.connect(app.assets._show_reference_import_dialog)

	app.about_dialog = app.main_overlays.about_dialog

	app.save_changes_dialog = app.main_overlays.save_changes_dialog
	app.save_changes_dialog.confirmed.connect(app.city_files._save_pending_city_exit)
	app.save_changes_dialog.canceled.connect(app.city_files._cancel_pending_city_exit)
	app.save_changes_dialog.custom_action.connect(app.city_files._on_save_changes_action)


func _show_main_menu() -> void:
	if app.main_menu == null:
		return

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.scurk_place_print.hide()
		app.current_tool._update_edit_state()

	if app.scurk_print != null:
		app.scurk_print.hide()

	app.menus._sync_asset_menu_actions()
	app.main_menu.set_assets_ready(app.assets_ready)

	if app.assets_ready:
		app.main_menu.city_background.configure(app.reference_root, app.palette, app.large_sprites)

	app.main_menu.show_menu(app.city != null)
	app.status_label.text = "Main menu."


func _hide_main_menu() -> void:
	if app.audio_controller != null and app.audio_controller.menu_music:
		app.audio_controller.set_menu_music(false)

		if app.city != null and app.city.music_enabled():
			app.effects_audio._play_music_track(app.audio_controller.music_director.next_general_track())

	if app.main_menu != null:
		app.main_menu.hide()

	if app.city != null:
		app.status_label.text = "City ready."


func _open_about_dialog() -> void:
	app.about_dialog.popup_centered()
	if app.assets_ready and app.audio_controller != null and app.audio_controller.music_volume > 0.0 and (app.city == null or app.city.music_enabled()):
		app.audio_controller.play_music_track(Music.ABOUT_TRACK, false, true)


func _refresh_details() -> void:
	if app.city == null:
		return

	app.menus._sync_city_option_menus()

	if app.graph_window != null:
		app.graph_window.refresh_city(app.city)

	if app.population_window != null:
		app.population_window.refresh_city(app.city)

	if app.industry_window != null:
		app.industry_window.refresh_city(app.city)

	if app.simnation_window != null:
		app.simnation_window.refresh_city(app.city)

	if app.ordinance_window != null:
		app.ordinance_window.refresh_city()

	if app.city_map_window != null:
		app.city_map_window.refresh_city(app.city, app.palette, app.reports._city_map_viewport_outline())

	var demand := app.city.rci_demand()
	var weather_trend := app.city.document.misc_u32(RciAftermath.MISC_WEATHER_TREND) & 0xff
	var weather_name: String = (
		RciAftermath.WEATHER_NAMES[weather_trend]
		if weather_trend < RciAftermath.WEATHER_NAMES.size()
		else "Unknown"
	)
	var display_date := "%02d/%02d/%04d" % [
		app.city.current_month(),
		app.city.current_day(),
		app.city.current_year(),
	]
	app.city_menu_bar.set_date(display_date)
	app.city_menu_bar.set_money("$%s" % _format_number(app.city.funds()))
	_refresh_status_summary(demand, weather_name)

	if app.current_tool._refresh_tool_availability():
		app.current_tool._update_edit_state()


func _refresh_status_summary(
	demand := Vector3i(0, 0, 0), weather_name := ""
) -> void:
	if app.city_menu_bar == null or app.city_status_bar == null:
		return

	app.city_status_bar.set_compass(app.city.compass_rotation() if app.city != null else -1)

	if app.city == null:
		app.city_menu_bar.set_population("--", false)
		app.city_status_bar.clear_environment()
	else:
		if weather_name.is_empty():
			var weather_trend := app.city.document.misc_u32(
				RciAftermath.MISC_WEATHER_TREND
			) & 0xff
			weather_name = (
				RciAftermath.WEATHER_NAMES[weather_trend]
				if weather_trend < RciAftermath.WEATHER_NAMES.size()
				else "Unknown"
			)
			demand = app.city.rci_demand()

		app.city_menu_bar.set_population(_format_number(app.city.population()))
		var weather_id := CityStatusMessages.WEATHER_FIRST + app.city.weather_type()
		if app.city.weather_type() >= 0 and app.city.weather_type() < CityStatusMessages.WEATHER_COUNT:
			weather_name = CityStatusMessages.text(weather_id, app.original_query_strings)
		app.city_status_bar.set_environment(demand, weather_name)

	app.frame._sync_speed_ui()
	app.city_status_bar.refresh_tooltips()


func _show_error(message: String) -> void:
	app.status_label.text = message
	app.status_label.theme_type_variation = "ErrorLabel"


func _format_number(value: int) -> String:
	return DisplayNumbers.format(value)
