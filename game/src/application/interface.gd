class_name ApplicationInterface
extends RefCounted


const DisplayNumbers = preload("res://src/ui/shared/display_number_format.gd")
const CityWorkspaceView = preload("res://src/ui/shell/city_workspace.tscn")
const CityDialogsView = preload("res://src/ui/shell/city_dialog_registry.gd")
const MainOverlaysView = preload("res://src/ui/shell/main_overlay_registry.gd")
const RciAftermath = preload("res://src/simulation/growth/rci_aftermath_phase.gd")
const Music = preload("res://src/audio/music_director.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func build_interface(original_assets: OriginalGameAssets) -> void:
	app.theme = AppUiTheme.current()
	app.city_workspace = CityWorkspaceView.instantiate() as CityWorkspace
	app.city_workspace.toolbar_art = original_assets.toolbar_art
	app.add_child(app.city_workspace)

	app.city_menu_bar = app.city_workspace.menu_bar
	app.city_menu_bar.file_menu_requested.connect(app.menus.on_file_menu)
	app.city_menu_bar.speed_menu_requested.connect(app.menus.on_speed_menu)
	app.city_menu_bar.options_menu_requested.connect(app.menus.on_options_menu)
	app.city_menu_bar.view_menu_requested.connect(app.menus.on_view_menu)
	app.city_menu_bar.disaster_menu_requested.connect(app.reports.on_disaster_menu)
	app.city_menu_bar.windows_menu_requested.connect(app.reports.on_windows_menu)
	app.city_menu_bar.newspaper_menu_requested.connect(app.reports.on_newspaper_menu)
	app.city_menu_bar.newspaper_menu.about_to_popup.connect(app.reports.refresh_newspaper_menu)
	app.city_menu_bar.help_menu_requested.connect(app.reports.on_help_menu)
	app.speed_menu = app.city_menu_bar.speed_menu
	app.options_menu = app.city_menu_bar.options_menu
	app.view_menu = app.city_menu_bar.view_menu
	app.disasters_menu = app.city_menu_bar.disasters_menu

	app.city_toolbar = app.city_workspace.toolbar
	app.city_toolbar.button_clicked.connect(play_toolbar_click)
	app.city_toolbar.group_requested.connect(app.camera_input.choose_tool_group)
	app.city_toolbar.subtool_requested.connect(app.current_tool.select_subtool)
	app.city_toolbar.rotate_requested.connect(app.camera_input.rotate_city)
	app.city_toolbar.zoom_out_requested.connect(app.camera_input.zoom_out)
	app.city_toolbar.zoom_in_requested.connect(app.camera_input.zoom_in)
	app.city_toolbar.overlay_requested.connect(app.menus.set_overlay)
	app.city_toolbar.surface_visibility_requested.connect(app.menus.set_surface_visibility)
	app.city_toolbar.underground_water_mains_visibility_requested.connect(app.menus.set_underground_water_mains_visible)
	app.city_toolbar.underground_pipes_visibility_requested.connect(
		app.menus.set_underground_pipes_visible
	)
	app.city_toolbar.underground_subways_visibility_requested.connect(app.menus.set_underground_subways_visible)
	app.rotate_counter_clockwise_button = app.city_toolbar.rotate_counter_clockwise_button
	app.rotate_clockwise_button = app.city_toolbar.rotate_clockwise_button
	app.zoom_out_button = app.city_toolbar.zoom_out_button
	app.zoom_in_button = app.city_toolbar.zoom_in_button
	app.view_layers_heading = app.city_toolbar.view_layers_heading
	app.view_visibility_checks = app.city_toolbar.view_visibility_checks

	app.map_view = app.city_workspace.map_view
	app.map_view.selection_completed.connect(app.city_edits.apply_map_selection)
	app.map_view.selection_changed.connect(app.camera_input.on_map_selection_changed)
	app.network_preview = NetworkPlacementPreview.new()
	app.network_preview.map_view = app.map_view
	app.network_preview.z_index = CityMapControl.NETWORK_PREVIEW_Z_INDEX
	app.network_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	app.map_view.add_child(app.network_preview)
	app.map_view.selection_finished.connect(app.network_preview.clear)
	app.map_view.selection_canceled.connect(app.network_preview.clear)
	app.map_view.selection_started.connect(app.camera_input.on_map_selection_started)
	app.map_view.stretch_changed.connect(app.camera_input.on_terrain_stretch_changed)
	app.map_view.selection_finished.connect(app.camera_input.on_map_selection_finished)
	app.map_view.selection_canceled.connect(app.camera_input.on_map_selection_canceled)
	app.map_view.query_requested.connect(app.query_choices.open_query)
	app.map_view.center_requested.connect(app.camera_input.center_map_on_tile)
	app.map_view.zoom_changed.connect(app.camera_input.on_city_zoom_changed)
	app.map_view.viewport_changed.connect(app.reports.refresh_city_map_viewport)
	app.city_status_bar = app.city_workspace.status_bar
	app.city_status_bar.disaster_locate_requested.connect(app.camera_input.center_map_on_disaster)
	app.status_label = app.city_status_bar.message_label
	app.frame.sync_speed_ui()

	app.city_dialogs = CityDialogsView.new(original_assets)
	app.city_dialogs.name = "CityDialogs"
	app.add_child(app.city_dialogs)

	app.city_dialogs.city_open_dialog.file_selected.connect(app.city_files.load_city)
	app.city_dialogs.city_save_dialog.file_selected.connect(app.city_files.on_save_path_selected)
	app.city_dialogs.city_save_dialog.canceled.connect(app.city_files.on_save_dialog_canceled)
	app.tile_set_dialog = app.city_dialogs.tile_set_dialog
	app.tile_set_dialog.file_selected.connect(app.scurk_workspace.load_tile_set)
	app.city_png_export.bind_ui(app.city_dialogs.png_export_dialog, app.city_dialogs.png_export_progress)
	app.city_png_export.error_reported.connect(show_error)
	app.city_png_export.status_changed.connect(show_status)
	app.city_dialogs.png_export_dialog.export_requested.connect(app.city_png_export.start_export)


	app.city_toolbar.start_city_requested.connect(app.new_city.start_city)
	app.city_toolbar.regenerate_requested.connect(app.new_city.reopen_terrain_dialog)
	app.city_toolbar.brush_changed.connect(app.current_tool.update_edit_state)
	app.city_dialogs.new_city_dialog.visibility_changed.connect(app.new_city.sync_new_city_workspace)
	app.city_dialogs.new_city_dialog.cancel_requested.connect(app.new_city.cancel_new_city)
	app.city_dialogs.new_city_dialog.build_requested.connect(app.new_city.create_new_city)
	app.city_dialogs.new_city_dialog.preview_requested.connect(app.new_city.schedule_new_city_preview)
	app.city_dialogs.new_city_dialog.terrain_regeneration_requested.connect(app.new_city.make_new_city_preview)
	app.city_dialogs.sign_dialog.confirmed.connect(app.query_choices.commit_sign)
	app.city_dialogs.sign_dialog.canceled.connect(app.query_choices.cancel_sign)
	app.city_dialogs.bridge_dialog.choice_requested.connect(app.network_edits.choose_bridge)
	app.city_dialogs.bridge_dialog.canceled.connect(app.network_edits.cancel_bridge)
	app.city_dialogs.tool_choice_dialog.choice_requested.connect(app.query_choices.choose_tool_variant)
	app.city_dialogs.tool_choice_dialog.canceled.connect(app.query_choices.cancel_tool_choice)
	app.city_dialogs.stadium_dialog.confirmed.connect(app.query_choices.confirm_stadium_team)
	app.city_dialogs.stadium_dialog.canceled.connect(app.query_choices.cancel_stadium_team)
	app.city_dialogs.network_connection_dialog.confirmed.connect(app.network_edits.confirm_network_connection)
	app.city_dialogs.network_connection_dialog.canceled.connect(app.network_edits.cancel_network_connection)
	app.city_dialogs.highway_connection_dialog.confirmed.connect(app.route_edits.confirm_highway_connection)
	app.city_dialogs.highway_connection_dialog.canceled.connect(app.route_edits.cancel_highway_connection)
	app.city_dialogs.tunnel_dialog.confirmed.connect(app.route_edits.confirm_tunnel)
	app.city_dialogs.tunnel_dialog.canceled.connect(app.route_edits.cancel_tunnel)
	app.city_dialogs.query_dialog.close_requested.connect(app.query_choices.close_query)
	app.city_dialogs.query_dialog.action_requested.connect(app.query_choices.run_query_action)
	app.city_dialogs.industry_window.tax_rates_changed.connect(app.reports.on_industry_tax_rates_changed)
	app.city_dialogs.city_map_window.mode_changed.connect(app.reports.on_city_map_mode_changed)
	app.city_dialogs.city_map_window.center_requested.connect(app.reports.on_city_map_center_requested)
	app.city_dialogs.city_map_window.isometric_view_requested.connect(app.reports.on_city_map_isometric_view_requested)
	app.city_dialogs.ordinance_window.ordinances_changed.connect(app.reports.on_ordinances_changed)
	app.city_dialogs.ordinance_window.update_failed.connect(show_error)
	app.city_dialogs.newspaper_dialog.visibility_changed.connect(app.new_city.on_founding_newspaper_visibility_changed)
	app.city_dialogs.newspaper_dialog.visibility_changed.connect(app.reports.on_scheduled_newspaper_visibility_changed)
	app.city_dialogs.building_objection_dialog.confirmed.connect(app.reports.on_building_objection_closed)
	app.city_dialogs.building_objection_dialog.canceled.connect(app.reports.on_building_objection_closed)
	app.city_dialogs.scenario_dialog.confirmed.connect(app.budget.begin_scenario)
	app.city_dialogs.military_dialog.confirmed.connect(app.budget.accept_military_proposal)
	app.city_dialogs.military_dialog.canceled.connect(app.budget.decline_military_proposal)
	app.city_dialogs.budget_dialog.apply_requested.connect(app.budget.commit_budget)
	app.city_dialogs.budget_dialog.cancel_requested.connect(app.budget.cancel_budget)
	app.city_dialogs.budget_dialog.issue_bond_requested.connect(app.budget.request_issue_bond)
	app.city_dialogs.budget_dialog.repay_bond_requested.connect(app.budget.request_repay_bond)
	app.city_dialogs.budget_dialog.bond_confirmation_resolved.connect(app.budget.resolve_bond_action)

	app.current_tool.select_tool_group(app.tool_state.selected_group)
	app.camera_input.update_zoom_controls(app.map_view.zoom_percent())
	_build_main_menu()
	app.effects_audio.bind_view(app.map_view, app.main_menu)
	app.main_overlays.about_dialog.set_assets(original_assets)


func _build_main_menu() -> void:
	app.main_overlays = MainOverlaysView.new()
	app.main_overlays.name = "ApplicationOverlays"
	app.add_child(app.main_overlays)
	app.main_menu = app.main_overlays.main_menu
	app.main_menu.button_clicked.connect(play_toolbar_click)
	app.main_menu.continue_requested.connect(hide_main_menu)
	app.main_menu.new_city_requested.connect(app.new_city.open_new_city_dialog)
	app.main_menu.open_city_requested.connect(app.city_files.open_city_dialog)
	app.main_menu.scenario_requested.connect(app.city_files.open_scenario_dialog)
	app.main_menu.settings_requested.connect(app.settings.open_settings_dialog)
	app.main_menu.import_assets_requested.connect(app.settings.open_import_settings)
	app.main_menu.scurk_requested.connect(app.scurk_workspace.open_scurk_dialog)
	app.main_menu.about_requested.connect(open_about_dialog)
	app.main_menu.exit_requested.connect(app.city_files.request_city_exit.bind("quit"))

	app.main_overlays.settings_dialog.confirmed.connect(app.settings.apply_settings)
	app.main_overlays.settings_dialog.import_original_requested.connect(app.assets.show_reference_import_dialog)
	app.reference_import_dialog = app.main_overlays.asset_import_dialog
	app.reference_import_dialog.packs_imported.connect(app.assets.activate_imported_packs)
	app.reference_import_dialog.dismissed.connect(app.assets._on_reference_import_canceled)


	app.main_overlays.save_changes_dialog.confirmed.connect(app.city_files.save_pending_city_exit)
	app.main_overlays.save_changes_dialog.canceled.connect(app.city_files.cancel_pending_city_exit)
	app.main_overlays.save_changes_dialog.custom_action.connect(app.city_files.on_save_changes_action)


func show_status(message: String) -> void:
	app.status_label.theme_type_variation = ""
	app.status_label.text = message


func show_main_menu() -> void:
	if app.main_menu == null:
		return

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.scurk_place_print.hide()
		app.current_tool.update_edit_state()

	if app.scurk_print != null:
		app.scurk_print.hide()

	app.menus.sync_asset_menu_actions()
	app.main_menu.set_assets_ready(app.asset_state.assets_ready)

	if app.asset_state.assets_ready:
		app.main_menu.city_background.configure(app.asset_state.reference_root, app.asset_state.palette, app.asset_state.large_sprites)

	app.main_menu.show_menu(app.document_state.city != null)
	app.status_label.text = "Main menu."


func hide_main_menu() -> void:
	if app.audio_controller != null and app.audio_controller.menu_music:
		app.audio_controller.set_menu_music(false)

		if app.document_state.city != null and app.document_state.city.music_enabled():
			app.effects_audio.play_music_track(app.audio_controller.music_director.next_general_track())

	if app.main_menu != null:
		app.main_menu.hide()
		app.main_menu.city_background.release_render_data()

	if app.document_state.city != null:
		app.status_label.text = "City ready."


func open_about_dialog() -> void:
	app.main_overlays.about_dialog.popup_centered()
	if (app.asset_state.assets_ready and app.audio_controller != null and app.audio_controller.music_volume > 0.0
			and (app.document_state.city == null or app.document_state.city.music_enabled())):
		app.audio_controller.play_music_track(Music.ABOUT_TRACK, false, true)


func refresh_details() -> void:
	if app.document_state.city == null:
		return

	app.menus.sync_city_option_menus()

	if app.city_dialogs.graph_window != null:
		app.city_dialogs.graph_window.refresh_city(app.document_state.city)

	if app.city_dialogs.population_window != null:
		app.city_dialogs.population_window.refresh_city(app.document_state.city)

	if app.city_dialogs.industry_window != null:
		app.city_dialogs.industry_window.refresh_city(app.document_state.city)

	if app.city_dialogs.simnation_window != null:
		app.city_dialogs.simnation_window.refresh_city(app.document_state.city)

	if app.city_dialogs.ordinance_window != null:
		app.city_dialogs.ordinance_window.refresh_city()

	if app.city_dialogs.city_map_window != null:
		app.city_dialogs.city_map_window.refresh_city(app.document_state.city, app.asset_state.palette, app.reports.city_map_viewport_outline())

	var demand := app.document_state.city.rci_demand()
	var weather_trend := app.document_state.city.document.misc_u32(RciAftermath.MISC_WEATHER_TREND) & 0xff
	var weather_name: String = (
		RciAftermath.WEATHER_NAMES[weather_trend]
		if weather_trend < RciAftermath.WEATHER_NAMES.size()
		else "Unknown"
	)
	var display_date := "%02d/%02d/%04d" % [
		app.document_state.city.current_month(),
		app.document_state.city.current_day(),
		app.document_state.city.current_year(),
	]
	app.city_menu_bar.set_date(display_date)
	app.city_menu_bar.set_money("$%s" % format_number(app.document_state.city.funds()))
	refresh_status_summary(demand, weather_name)

	if app.current_tool.refresh_tool_availability():
		app.current_tool.update_edit_state()


func refresh_status_summary(
	demand := Vector3i(0, 0, 0), weather_name := ""
) -> void:
	if app.city_menu_bar == null or app.city_status_bar == null:
		return

	app.city_status_bar.set_compass(app.document_state.city.compass_rotation() if app.document_state.city != null else -1)

	if app.document_state.city == null:
		app.city_menu_bar.set_population("--", false)
		app.city_status_bar.clear_environment()
	else:
		if weather_name.is_empty():
			var weather_trend := app.document_state.city.document.misc_u32(
				RciAftermath.MISC_WEATHER_TREND
			) & 0xff
			weather_name = (
				RciAftermath.WEATHER_NAMES[weather_trend]
				if weather_trend < RciAftermath.WEATHER_NAMES.size()
				else "Unknown"
			)
			demand = app.document_state.city.rci_demand()

		app.city_menu_bar.set_population(format_number(app.document_state.city.population()))
		app.city_status_bar.set_environment(demand, weather_name)

	app.frame.sync_speed_ui()
	app.city_status_bar.refresh_tooltips()


func show_error(message: String) -> void:
	app.status_label.text = message
	app.status_label.theme_type_variation = "ErrorLabel"


func format_number(value: int) -> String:
	return DisplayNumbers.format(value)


func play_toolbar_click() -> void:
	if app.preferences.toolbar_sounds:
		app.audio_controller.play_toolbar_click(app.document_state.city == null or app.document_state.city.sound_enabled())
