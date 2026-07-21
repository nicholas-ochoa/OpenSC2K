class_name ApplicationCitySession
extends RefCounted


const CityFiles = preload("res://src/formats/city_file_store.gd")
const CityModel = preload("res://src/model/city_state.gd")
const SettingsStore = preload("res://src/ui/settings/app_settings_store.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func _activate_document(
	document: Sc2File, loaded_scenario: ScenarioState = null, status_text := ""
) -> bool:
	var disable_compatibility := app.app_original_compatibility and document != null and document.is_extended()
	var compatibility_error := OriginalCompatibility.document_error(document, app.app_original_compatibility and not disable_compatibility)

	if not compatibility_error.is_empty():
		app.interface._show_error(compatibility_error)

		return false

	app.map_view.clear_trip_reach()
	app.map_view.clear_service_query()
	var loaded_city := CityModel.from_document(document)

	if not loaded_city.is_valid():
		app.interface._show_error(loaded_city.load_error)

		return false

	if disable_compatibility:
		app.app_original_compatibility = false
		app.settings._apply_compatibility_controls()
		var settings_error := SettingsStore.save_original_compatibility(false, app.app_settings_path)
		status_text += " Original compatibility turned off to open this SC2X city."

		if settings_error != OK:
			status_text += " The preference could not be saved."

	app.founding_newspaper_pending = false
	app.landscape_editor = false
	app.city_toolbar.set_landscape_editor(false)
	app.city_menu_bar.disasters_menu.disabled = false
	var music_was_active := app.effects_audio._music_playback_is_active()

	app.budget_dialog.reset_dialogs()

	if app.game_over_dialog.visible:
		app.game_over_dialog.hide()

	if app.scenario_dialog.visible:
		app.scenario_dialog.hide()

	app.military_proposal_pending = false

	if app.military_dialog.visible:
		app.military_dialog.hide()

	app.pending_bridge_request.clear()

	if app.bridge_dialog.visible:
		app.bridge_dialog.hide()

	app.pending_tool_choices.clear()

	if app.tool_choice_dialog.visible:
		app.tool_choice_dialog.hide()

	app.pending_stadium_command.clear()

	if app.stadium_dialog.visible:
		app.stadium_dialog.hide()

	app.pending_network_connection.clear()

	if app.network_connection_dialog.visible:
		app.network_connection_dialog.hide()

	app.pending_highway_connection.clear()

	if app.highway_connection_dialog.visible:
		app.highway_connection_dialog.hide()

	app.pending_tunnel_request.clear()

	if app.tunnel_dialog.visible:
		app.tunnel_dialog.hide()

	if app.building_objection_dialog != null and app.building_objection_dialog.visible:
		app.building_objection_dialog.hide()

	app.pending_building_objection_group = -1
	app.pending_building_objection_subtool = -1

	if app.new_city_dialog != null and app.new_city_dialog.visible:
		app.new_city_dialog.hide()

	app.new_city_return_to_main_menu = false

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.scurk_place_print.hide()

	if app.scurk_print != null:
		app.scurk_print.hide()

	app.pending_scurk_print_options.clear()
	app.scurk_edit_history.clear()
	app.annual_budget_pending = false
	app.game_over_active = false
	app.city = loaded_city
	app.map_view.pending_loaded_center = Vector2i(-1, -1)

	if not document.source_path.is_empty():
		app.map_view.pending_loaded_center = Vector2i(clampi(document.misc_u32(0x1018), 0, app.city.map_size - 1), clampi(document.misc_u32(0x101c), 0, app.city.map_size - 1))

	app.current_tool._select_tool_group(17)
	app.overlay_mode = "city"
	app.current_document = document
	var initial_serialized := app.current_document.serialize()
	app.saved_city_snapshot = (
		initial_serialized.data.duplicate() if initial_serialized.ok else PackedByteArray()
	)
	var facility_repair := FacilityRecordRepair.apply(app.city)

	if not facility_repair.ok:
		status_text += " " + str(facility_repair.error)
	elif facility_repair.linked > 0 or facility_repair.unfilled > 0:
		status_text += " Restored facility records for %d buildings." % facility_repair.linked

		if facility_repair.unfilled > 0:
			status_text += " %d buildings still need records; the table is full." % facility_repair.unfilled

	app.current_city_saved_once = not app.current_document.source_path.is_empty()
	var source_path := app.current_document.source_path.simplify_path()
	app.current_save_path = (
		source_path
		if (
			not source_path.is_empty()
			and not CityFiles.is_reference_path(source_path, app.reference_root)
		)
		else ""
	)
	app.interface._hide_main_menu()
	app.static_render._invalidate_rendered_city()
	app.palette_cycle_ticks = 0
	app.palette_elapsed_msec = 0.0
	app.static_render._update_palette_cycle_texture()
	app.moving_sprites._reset_blend()
	var process_seed := app.tool_random.state
	var game_seed := app.nuisance_random.state
	var lfsr_seed := (
		app.simulation_engine.lfsr_random.state
		if app.simulation_engine != null
		else (Time.get_ticks_msec() & 0xffff) | 1
	)

	if app.frame_simulation != null:
		app.frame_simulation.close()

	app.frame_simulation = null
	app.simulation_timings.clear()
	app.simulation_engine = Simulation.new(app.city, process_seed, lfsr_seed, game_seed)
	app.simulation_engine.vehicle_crashes_enabled = app.show_vehicles
	app.speed_controller = GameSpeed.new(app.simulation_engine)
	app.speed_controller.original_compatibility = app.app_original_compatibility

	if app.current_document.is_extended():
		app.frame_simulation = FrameSimulationRunner.new(app.speed_controller)

	app.frame._sync_speed_ui()
	app.tool_random = app.simulation_engine.random
	app.nuisance_random = app.simulation_engine.game_random
	app.simulation_map_dirty = false
	app.reports._refresh_saved_news_summary()
	app.last_edit_command = {}
	app.dispatch_cycles = PackedInt32Array([0, 0, 0])
	app.dispatch_initialized = false
	app.camera_input._update_zoom_controls(app.map_view.zoom_percent())
	var display_name := app.city.city_name()

	if display_name.is_empty():
		display_name = document.source_path.get_file().get_basename()

	if display_name.is_empty():
		display_name = "New City"

	app.city_menu_bar.set_city_name(display_name)
	app.reports._refresh_newspaper_menu()
	app.interface._refresh_details()
	app.status_label.theme_type_variation = ""
	app.status_label.text = status_text if not status_text.is_empty() else "City ready."
	app.map_render._refresh_map()
	app.current_tool._update_edit_state()

	if not app.city.music_enabled():
		app.effects_audio._stop_music()
	elif music_was_active:
		app.simulation_engine.midi_playback_active = true
	else:
		app.effects_audio._play_music_track(app.audio_controller.music_director.next_general_track())

	if loaded_scenario != null:
		app.budget._open_scenario_intro(loaded_scenario)

	if disable_compatibility or not facility_repair.ok or facility_repair.linked > 0 or facility_repair.unfilled > 0:
		app.status_label.text = status_text

	return true
