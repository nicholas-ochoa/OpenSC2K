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
const MAP_DISPLAY_MODES := ["city", "underground", "land_value", "pollution", "crime", "water", "power", "height"]
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


func _sync_asset_menu_actions() -> void:
	var popup := app.city_menu_bar.file_menu.get_popup()

	for index in popup.item_count:
		if popup.get_item_id(index) not in [5, 6] and not popup.is_item_separator(index):
			popup.set_item_disabled(index, not app.assets_ready)


func _on_file_menu(id: int) -> void:
	if not app.assets_ready and id not in [5, 6]:
		return

	match id:
		0:
			app.new_city._open_new_city_dialog()
		1:
			app.city_files._open_city_dialog()
		2:
			app.city_files._open_save_dialog()
		CityMenuBar.MENU_SAVE_CITY:
			app.city_files._save_city()
		CityMenuBar.MENU_EXPORT_CITY_PNG:
			app.city_png_export._open_export_dialog()
		3:
			app.scurk_workspace._open_tile_set_dialog()
		4:
			app.scurk_workspace._restore_original_tile_set()
		MENU_SCURK_PLACE_PRINT:
			app.scurk_workspace._open_scurk_place_print()
		5:
			app.city_files._request_main_menu()
		6:
			app.city_files._request_city_exit("quit")


func _on_speed_menu(id: int) -> void:
	if app.speed_controller == null:
		return

	if id < 0 or id > 4:
		return

	app.frame._select_speed(id + GameSpeed.Speed.PAUSED)


func _on_options_menu(id: int) -> void:
	if id == CityMenuBar.MENU_UPGRADE_SC2X:
		app.city_files._upgrade_city_to_sc2x()

		return

	if id == CityMenuBar.MENU_SETTINGS:
		app.settings._open_settings_dialog()

		return

	if app.city == null:
		app.interface._show_error("Load a city before you change its options.")

		return

	var enabled := false
	var stored := false
	var option_name := ""

	match id:
		MENU_AUTO_BUDGET:
			enabled = not app.city.auto_budget_enabled()
			stored = app.city.set_auto_budget_enabled(enabled)
			option_name = "Auto-Budget"
		MENU_AUTO_GOTO:
			enabled = not app.city.auto_goto_enabled()
			stored = app.city.set_auto_goto_enabled(enabled)
			option_name = "Auto-Goto"
		MENU_SOUND_EFFECTS:
			enabled = not app.city.sound_enabled()
			stored = app.city.set_sound_enabled(enabled)
			option_name = "Sound Effects"
		MENU_MUSIC:
			enabled = not app.city.music_enabled()
			stored = app.city.set_music_enabled(enabled)
			option_name = "Music"
		_:
			return

	if not stored:
		app.interface._show_error("Cannot update the %s option." % option_name)

		return

	_sync_city_option_menus()

	if id == MENU_SOUND_EFFECTS and not enabled:
		app.effects_audio._stop_sound_effects()

	if id == MENU_MUSIC:
		if enabled:
			app.effects_audio._play_music_track(app.audio_controller.music_director.next_general_track())
		else:
			app.effects_audio._stop_music()

	app.status_label.theme_type_variation = ""
	app.status_label.text = "%s %s." % [option_name, "enabled" if enabled else "disabled"]


func _on_view_menu(id: int) -> void:
	if id >= 0 and id < MAP_DISPLAY_MODES.size():
		_set_overlay(MAP_DISPLAY_MODES[id])

		return

	match id:
		MENU_VIEW_CITY_MAP:
			app.reports._open_city_map_window()
		MENU_VIEW_BUILDINGS:
			_set_surface_visibility(not bool(app.surface_visibility.buildings), "buildings")
		MENU_VIEW_NETWORKS:
			_set_surface_visibility(not bool(app.surface_visibility.networks), "networks")
		MENU_VIEW_WATER:
			_set_surface_visibility(not bool(app.surface_visibility.water), "water")
		MENU_VIEW_TREES:
			_set_surface_visibility(not bool(app.surface_visibility.trees), "trees")
		MENU_VIEW_ZONES:
			_set_surface_visibility(not bool(app.surface_visibility.zones), "zones")
		MENU_VIEW_SIGNS:
			_set_surface_visibility(not bool(app.surface_visibility.signs), "signs")
		MENU_VIEW_VEHICLES:
			_set_surface_visibility(not app.show_vehicles, "vehicles")
		MENU_VIEW_WATER_MAINS:
			_set_underground_water_mains_visible(not app.show_underground_water_mains)
		MENU_VIEW_PIPES:
			_set_underground_pipes_visible(not app.show_underground_pipes)


func _sync_city_option_menus() -> void:
	if app.options_menu == null or app.disasters_menu == null:
		return

	app.city_files._sync_upgrade_city_option()
	var has_city := app.city != null
	app.options_menu.disabled = not has_city

	if app.view_menu != null:
		app.view_menu.disabled = not has_city

	var option_states := {
		MENU_AUTO_BUDGET: has_city and app.city.auto_budget_enabled(),
		MENU_AUTO_GOTO: has_city and app.city.auto_goto_enabled(),
		MENU_SOUND_EFFECTS: has_city and app.city.sound_enabled(),
		MENU_MUSIC: has_city and app.city.music_enabled(),
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
			no_disasters_index, has_city and app.city.no_disasters_enabled()
		)

	_sync_view_controls()


func _sync_view_controls() -> void:
	if app.view_menu != null:
		for index in MAP_DISPLAY_MODES.size():
			app.view_menu.get_popup().set_item_checked(index, MAP_DISPLAY_MODES[index] == app.overlay_mode)

	var underground_active := app.overlay_mode == "underground"

	if app.view_menu != null and app.view_menu_underground_items != underground_active:
		_rebuild_view_layer_menu(underground_active)

	var states := {
		MENU_VIEW_BUILDINGS: bool(app.surface_visibility.buildings),
		MENU_VIEW_NETWORKS: bool(app.surface_visibility.networks),
		MENU_VIEW_WATER: bool(app.surface_visibility.water),
		MENU_VIEW_TREES: bool(app.surface_visibility.trees),
		MENU_VIEW_ZONES: bool(app.surface_visibility.zones),
		MENU_VIEW_SIGNS: bool(app.surface_visibility.signs),
		MENU_VIEW_VEHICLES: app.show_vehicles,
		MENU_VIEW_PIPES: app.show_underground_pipes,
		MENU_VIEW_WATER_MAINS: app.show_underground_water_mains,
	}

	if app.view_menu != null:
		for menu_id in states:
			var item_index := app.view_menu.get_popup().get_item_index(menu_id)

			if item_index >= 0:
				app.view_menu.get_popup().set_item_checked(item_index, bool(states[menu_id]))
				app.view_menu.get_popup().set_item_disabled(item_index, CityDataView.MODES.has(app.overlay_mode))

	if app.city_toolbar != null:
		app.city_toolbar.sync_view_mode(app.overlay_mode)

	for key in app.view_visibility_checks:
		var check: CheckBox = app.view_visibility_checks[key]
		check.visible = (underground_active if key in ["water_mains", "pipes", "subways"] else not underground_active) and not CityDataView.MODES.has(app.overlay_mode)
		if app.landscape_editor:
			check.visible = key in ["water", "trees"]
		check.disabled = CityDataView.MODES.has(app.overlay_mode)
		var enabled := bool(app.surface_visibility.get(key, true))
		match key:
			"water_mains":
				enabled = app.show_underground_water_mains
			"pipes":
				enabled = app.show_underground_pipes
			"subways":
				enabled = app.show_underground_subways
			"vehicles":
				enabled = app.show_vehicles
		check.set_pressed_no_signal(enabled)


func _rebuild_view_layer_menu(underground_active: bool) -> void:
	var popup := app.view_menu.get_popup()

	while popup.item_count > MAP_DISPLAY_MODES.size() + 2:
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


func _sync_map_style() -> void:
	# use the published texture until the mode change finishes
	if app.map_view != null:
		app.map_view.dark_underground = app.app_dark_underground and app.static_render_mode == "underground" and app.map_view.base_palette_lookup_all


func _set_overlay(mode: String) -> void:
	if not MAP_DISPLAY_MODES.has(mode):
		return

	app.overlay_mode = mode
	_sync_view_controls()
	app.current_tool._update_edit_state()

	if app.city != null:
		app.status_label.text = "Map view: %s" % app.overlay_mode.capitalize()
		app.map_render._refresh_map(false)


func _set_surface_visibility(enabled: bool, layer: String) -> void:
	if layer == "vehicles":
		_set_vehicles_visible(enabled)

		return

	if not app.surface_visibility.has(layer) or bool(app.surface_visibility[layer]) == enabled:
		return

	app.surface_visibility[layer] = enabled
	_invalidate_view_render()
	_sync_view_controls()

	if app.city != null and app.overlay_mode == "city":
		app.map_render._refresh_map(false)

	app.status_label.text = "%s %s." % [
		layer.capitalize(), "shown" if enabled else "hidden",
	]


# the visibility switch is also a crash switch
# vehicles draw on the moving-object layer, so the static city is unchanged
# a hidden vehicle also makes no sound and cannot crash into the city
func _set_vehicles_visible(enabled: bool) -> void:
	if app.show_vehicles == enabled:
		return

	app.show_vehicles = enabled

	if app.simulation_engine != null:
		app.simulation_engine.vehicle_crashes_enabled = enabled

	_sync_view_controls()

	if app.city != null and app.overlay_mode == "city":
		app.moving_sprites._refresh_moving_things()

	app.status_label.text = "Vehicles %s." % ("shown" if enabled else "hidden")


func _set_underground_water_mains_visible(enabled: bool) -> void:
	if app.show_underground_water_mains == enabled:
		return

	app.show_underground_water_mains = enabled
	_invalidate_view_render()
	_sync_view_controls()

	if app.city != null and app.overlay_mode == "underground":
		app.map_render._refresh_map(false)

	app.status_label.text = "Water mains %s." % ("shown" if enabled else "hidden")


func _set_underground_pipes_visible(enabled: bool) -> void:
	if app.show_underground_pipes == enabled:
		return

	app.show_underground_pipes = enabled
	_invalidate_view_render()
	_sync_view_controls()

	if app.city != null and app.overlay_mode == "underground":
		app.map_render._refresh_map(false)

	app.status_label.text = "Underground pipes %s." % ("shown" if enabled else "hidden")


func _invalidate_view_render() -> void:
	app.static_render_epoch += 1
	app.static_visual_signature.clear()
	app.static_render_mode = ""
	app.static_view_cache.clear()
	app.static_occlusion_commands.clear()
	app.static_occlusion_grid.clear()
	app.dynamic_occluder_cache.clear()
	app.dynamic_sign_occluders.clear()
	app.dynamic_sign_occlusion_grid.clear()


func _set_underground_subways_visible(enabled: bool) -> void:
	if app.show_underground_subways == enabled:
		return

	app.show_underground_subways = enabled
	_invalidate_view_render()
	_sync_view_controls()

	if app.city != null and app.overlay_mode == "underground":
		app.map_render._refresh_map(false)

	app.status_label.text = "Underground subways %s." % ("shown" if enabled else "hidden")
