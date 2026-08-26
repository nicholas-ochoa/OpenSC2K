class_name ApplicationMenus
extends RefCounted


const Zones = preload("res://src/tools/city/zone_command.gd")
const Signs = preload("res://src/tools/city/sign_command.gd")
const CityMenuBarView = preload("res://src/ui/shell/city_menu_bar.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const Networks = preload("res://src/tools/city/network_command.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const Music = preload("res://src/audio/music_director.gd")
const MENU_AUTO_BUDGET := CityMenuBarView.MENU_AUTO_BUDGET
const MENU_AUTO_GOTO := CityMenuBarView.MENU_AUTO_GOTO
const MENU_SOUND_EFFECTS := CityMenuBarView.MENU_SOUND_EFFECTS
const MENU_MUSIC := CityMenuBarView.MENU_MUSIC
const MENU_NO_DISASTERS := CityMenuBarView.MENU_NO_DISASTERS
const MENU_VIEW_CITY_MAP := CityMenuBarView.MENU_VIEW_CITY_MAP
const MENU_VIEW_BUILDINGS := CityMenuBarView.MENU_VIEW_BUILDINGS
const MENU_VIEW_NETWORKS := CityMenuBarView.MENU_VIEW_NETWORKS
const MENU_VIEW_WATER := CityMenuBarView.MENU_VIEW_WATER
const MENU_VIEW_TREES := CityMenuBarView.MENU_VIEW_TREES
const MENU_VIEW_ZONES := CityMenuBarView.MENU_VIEW_ZONES
const MENU_VIEW_SIGNS := CityMenuBarView.MENU_VIEW_SIGNS
const MENU_VIEW_VEHICLES := CityMenuBarView.MENU_VIEW_VEHICLES
const MENU_VIEW_WATER_MAINS := CityMenuBarView.MENU_VIEW_WATER_MAINS
const MENU_VIEW_PIPES := CityMenuBarView.MENU_VIEW_PIPES
const MENU_SCURK_PLACE_PRINT := CityMenuBarView.MENU_SCURK_PLACE_PRINT

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func sync_asset_menu_actions() -> void:
	var popup := app.city_menu_bar.file_menu.get_popup()

	for index in popup.item_count:
		if popup.get_item_id(index) not in [5, 6] and not popup.is_item_separator(index):
			popup.set_item_disabled(index, not app.asset_state.assets_ready)


func on_file_menu(id: int) -> void:
	if not app.asset_state.assets_ready and id not in [5, 6]:
		return

	match id:
		0:
			app.new_city.open_new_city_dialog()
		1:
			app.city_files.open_city_dialog()
		2:
			app.city_files.open_save_dialog()
		CityMenuBar.MENU_SAVE_CITY:
			app.city_files.save_city()
		CityMenuBar.MENU_EXPORT_CITY_PNG:
			app.city_png_export.open_export_dialog()
		3:
			app.scurk_workspace.open_tile_set_dialog()
		4:
			app.scurk_workspace.restore_original_tile_set()
		MENU_SCURK_PLACE_PRINT:
			app.scurk_workspace.open_scurk_place_print()
		5:
			app.city_files.request_main_menu()
		6:
			app.city_files.request_city_exit("quit")


func on_speed_menu(id: int) -> void:
	if app.simulation_state.speed_controller == null:
		return

	if id < 0 or id > 4:
		return

	app.frame.select_speed(id + GameSpeed.Speed.PAUSED)


func on_options_menu(id: int) -> void:
	if id == CityMenuBar.MENU_UPGRADE_SC2X:
		app.city_files.upgrade_city_to_sc2x()

		return

	if id == CityMenuBar.MENU_SETTINGS:
		app.settings.open_settings_dialog()

		return

	if app.document_state.city == null:
		app.interface.show_error("Load a city before you change its options.")

		return

	var enabled := false
	var stored := false
	var option_name := ""

	match id:
		MENU_AUTO_BUDGET:
			enabled = not app.document_state.city.auto_budget_enabled()
			stored = app.document_state.city.set_auto_budget_enabled(enabled)
			option_name = "Auto-Budget"
		MENU_AUTO_GOTO:
			enabled = not app.document_state.city.auto_goto_enabled()
			stored = app.document_state.city.set_auto_goto_enabled(enabled)
			option_name = "Auto-Goto"
		MENU_SOUND_EFFECTS:
			enabled = not app.document_state.city.sound_enabled()
			stored = app.document_state.city.set_sound_enabled(enabled)
			option_name = "Sound Effects"
		MENU_MUSIC:
			enabled = not app.document_state.city.music_enabled()
			stored = app.document_state.city.set_music_enabled(enabled)
			option_name = "Music"
		_:
			return

	if not stored:
		app.interface.show_error("Cannot update the %s option." % option_name)

		return

	sync_city_option_menus()

	if id == MENU_SOUND_EFFECTS and not enabled:
		app.effects_audio.stop_sound_effects()

	if id == MENU_MUSIC:
		if enabled:
			app.effects_audio.play_music_track(app.audio_controller.music_director.next_general_track())
		else:
			app.effects_audio.stop_music()

	app.status_label.theme_type_variation = ""
	app.status_label.text = "%s %s." % [option_name, "enabled" if enabled else "disabled"]


func on_view_menu(id: int) -> void:
	if id >= 0 and id < CityViewMode.DISPLAY_MODES.size():
		set_overlay(CityViewMode.DISPLAY_MODES[id])

		return

	match id:
		MENU_VIEW_CITY_MAP:
			app.reports.open_city_map_window()
		MENU_VIEW_BUILDINGS:
			set_surface_visibility(not bool(app.view_state.surface_visibility.buildings), "buildings")
		MENU_VIEW_NETWORKS:
			set_surface_visibility(not bool(app.view_state.surface_visibility.networks), "networks")
		MENU_VIEW_WATER:
			set_surface_visibility(not bool(app.view_state.surface_visibility.water), "water")
		MENU_VIEW_TREES:
			set_surface_visibility(not bool(app.view_state.surface_visibility.trees), "trees")
		MENU_VIEW_ZONES:
			set_surface_visibility(not bool(app.view_state.surface_visibility.zones), "zones")
		MENU_VIEW_SIGNS:
			set_surface_visibility(not bool(app.view_state.surface_visibility.signs), "signs")
		MENU_VIEW_VEHICLES:
			set_surface_visibility(not app.view_state.show_vehicles, "vehicles")
		MENU_VIEW_WATER_MAINS:
			set_underground_water_mains_visible(not app.view_state.show_underground_water_mains)
		MENU_VIEW_PIPES:
			set_underground_pipes_visible(not app.view_state.show_underground_pipes)


func sync_city_option_menus() -> void:
	if app.options_menu == null or app.disasters_menu == null:
		return

	app.city_files.sync_upgrade_city_option()
	var has_city := app.document_state.city != null
	app.options_menu.disabled = not has_city

	if app.view_menu != null:
		app.view_menu.disabled = not has_city

	var option_states := {
		MENU_AUTO_BUDGET: has_city and app.document_state.city.auto_budget_enabled(),
		MENU_AUTO_GOTO: has_city and app.document_state.city.auto_goto_enabled(),
		MENU_SOUND_EFFECTS: has_city and app.document_state.city.sound_enabled(),
		MENU_MUSIC: has_city and app.document_state.city.music_enabled(),
	}

	for option_id in option_states:
		var option_index := app.options_menu.get_popup().get_item_index(option_id)

		if option_index >= 0:
			app.options_menu.get_popup().set_item_checked(
				option_index, bool(option_states[option_id])
			)

	var no_disasters_index := app.disasters_menu.get_popup().get_item_index(MENU_NO_DISASTERS)

	if no_disasters_index >= 0:
		app.disasters_menu.get_popup().set_item_disabled(no_disasters_index, not has_city)
		app.disasters_menu.get_popup().set_item_checked(
			no_disasters_index, has_city and app.document_state.city.no_disasters_enabled()
		)

	_sync_view_controls()


func _sync_view_controls() -> void:
	if app.view_menu != null:
		for index in CityViewMode.DISPLAY_MODES.size():
			app.view_menu.get_popup().set_item_checked(index, CityViewMode.DISPLAY_MODES[index] == app.view_state.overlay_mode)

	var underground_active := app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND

	if app.view_menu != null and app.view_menu_underground_items != underground_active:
		_rebuild_view_layer_menu(underground_active)

	var states := {
		MENU_VIEW_BUILDINGS: bool(app.view_state.surface_visibility.buildings),
		MENU_VIEW_NETWORKS: bool(app.view_state.surface_visibility.networks),
		MENU_VIEW_WATER: bool(app.view_state.surface_visibility.water),
		MENU_VIEW_TREES: bool(app.view_state.surface_visibility.trees),
		MENU_VIEW_ZONES: bool(app.view_state.surface_visibility.zones),
		MENU_VIEW_SIGNS: bool(app.view_state.surface_visibility.signs),
		MENU_VIEW_VEHICLES: app.view_state.show_vehicles,
		MENU_VIEW_PIPES: app.view_state.show_underground_pipes,
		MENU_VIEW_WATER_MAINS: app.view_state.show_underground_water_mains,
	}

	if app.view_menu != null:
		for menu_id in states:
			var item_index := app.view_menu.get_popup().get_item_index(menu_id)

			if item_index >= 0:
				app.view_menu.get_popup().set_item_checked(item_index, bool(states[menu_id]))
				app.view_menu.get_popup().set_item_disabled(item_index, CityViewMode.is_data(app.view_state.overlay_mode))

	if app.city_toolbar != null:
		app.city_toolbar.sync_view_mode(app.view_state.overlay_mode)

	for key in app.view_visibility_checks:
		var check: CheckBox = app.view_visibility_checks[key]
		check.visible = ((underground_active if key in ["water_mains", "pipes", "subways"] else not underground_active)
				and not CityViewMode.is_data(app.view_state.overlay_mode))
		if app.tool_state.landscape_editor:
			check.visible = key in ["water", "trees"]
		check.disabled = CityViewMode.is_data(app.view_state.overlay_mode)
		var enabled := bool(app.view_state.surface_visibility.get(key, true))
		match key:
			"water_mains":
				enabled = app.view_state.show_underground_water_mains
			"pipes":
				enabled = app.view_state.show_underground_pipes
			"subways":
				enabled = app.view_state.show_underground_subways
			"vehicles":
				enabled = app.view_state.show_vehicles
		check.set_pressed_no_signal(enabled)


func _rebuild_view_layer_menu(underground_active: bool) -> void:
	var popup := app.view_menu.get_popup()

	while popup.item_count > CityViewMode.DISPLAY_MODES.size() + 2:
		popup.remove_item(popup.item_count - 1)

	if underground_active:
		popup.add_check_item("Show Water Mains", MENU_VIEW_WATER_MAINS)
		popup.add_check_item("Show Underground Pipes", MENU_VIEW_PIPES)
	else:
		for view_item in [
			["Show Buildings", MENU_VIEW_BUILDINGS],
			["Show Networks", MENU_VIEW_NETWORKS],
			["Show Water", MENU_VIEW_WATER],
			["Show Trees", MENU_VIEW_TREES],
			["Show Zones", MENU_VIEW_ZONES],
			["Show Signs", MENU_VIEW_SIGNS],
			["Show Vehicles", MENU_VIEW_VEHICLES],
		]:
			popup.add_check_item(view_item[0], view_item[1])

	app.view_menu_underground_items = underground_active


func sync_map_style() -> void:
	# use the published texture until the mode change finishes
	if app.map_view != null:
		app.map_view.dark_underground = (app.preferences.dark_underground
				and app.render_caches.static_render_mode == CityViewMode.Mode.UNDERGROUND and app.map_view.base_palette_lookup_all)


func set_overlay(mode: CityViewMode.Mode) -> void:
	if not CityViewMode.DISPLAY_MODES.has(mode):
		return

	app.view_state.overlay_mode = mode
	_sync_view_controls()
	app.current_tool.update_edit_state()

	if app.document_state.city != null:
		app.status_label.text = "Map view: %s" % CityViewMode.key(app.view_state.overlay_mode).capitalize()
		app.map_render.refresh_map(false)


func set_surface_visibility(enabled: bool, layer: String) -> void:
	if layer == "vehicles":
		_set_vehicles_visible(enabled)

		return

	if not app.view_state.surface_visibility.has(layer) or bool(app.view_state.surface_visibility[layer]) == enabled:
		return

	app.view_state.surface_visibility[layer] = enabled
	app.static_render.invalidate_view_render()
	_sync_view_controls()

	if app.document_state.city != null and app.view_state.overlay_mode == CityViewMode.Mode.CITY:
		app.map_render.refresh_map(false)

	app.status_label.text = "%s %s." % [
		layer.capitalize(), "shown" if enabled else "hidden",
	]


# the visibility switch is also a crash switch
# vehicles draw on the moving-object layer, so the static city is unchanged
# a hidden vehicle also makes no sound and cannot crash into the city
func _set_vehicles_visible(enabled: bool) -> void:
	if app.view_state.show_vehicles == enabled:
		return

	app.view_state.show_vehicles = enabled

	if app.simulation_state.simulation_engine != null:
		app.simulation_state.simulation_engine.vehicle_crashes_enabled = enabled

	_sync_view_controls()

	if app.document_state.city != null and app.view_state.overlay_mode == CityViewMode.Mode.CITY:
		app.moving_sprites.refresh_moving_things()

	app.status_label.text = "Vehicles %s." % ("shown" if enabled else "hidden")


func set_underground_water_mains_visible(enabled: bool) -> void:
	if app.view_state.show_underground_water_mains == enabled:
		return

	app.view_state.show_underground_water_mains = enabled
	app.static_render.invalidate_view_render()
	_sync_view_controls()

	if app.document_state.city != null and app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND:
		app.map_render.refresh_map(false)

	app.status_label.text = "Water mains %s." % ("shown" if enabled else "hidden")


func set_underground_pipes_visible(enabled: bool) -> void:
	if app.view_state.show_underground_pipes == enabled:
		return

	app.view_state.show_underground_pipes = enabled
	app.static_render.invalidate_view_render()
	_sync_view_controls()

	if app.document_state.city != null and app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND:
		app.map_render.refresh_map(false)

	app.status_label.text = "Underground pipes %s." % ("shown" if enabled else "hidden")


func set_underground_subways_visible(enabled: bool) -> void:
	if app.view_state.show_underground_subways == enabled:
		return

	app.view_state.show_underground_subways = enabled
	app.static_render.invalidate_view_render()
	_sync_view_controls()

	if app.document_state.city != null and app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND:
		app.map_render.refresh_map(false)

	app.status_label.text = "Underground subways %s." % ("shown" if enabled else "hidden")
