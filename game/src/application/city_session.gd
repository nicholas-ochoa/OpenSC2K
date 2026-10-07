class_name ApplicationCitySession
extends RefCounted

const CityFiles = preload("res://src/formats/city_file_store.gd")
const CityModel = preload("res://src/model/city_state.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")

var app: CityApplication
var document_state: ActiveDocumentState


func _init(application: CityApplication) -> void:
	app = application
	document_state = application.document_state


func activate_document(
	document: Sc2File, loaded_scenario: ScenarioState = null, status_text := "", loaded_from_file := false,
	content_snapshot := PackedByteArray()
) -> bool:
	app.map_view.clear_trip_reach()
	var loaded_city := CityModel.from_document(document)

	if not loaded_city.is_valid():
		app.interface.show_error(loaded_city.load_error)

		return false

	app.newspaper_state.founding_pending = false
	app.newspaper_state.scheduled_pending = false
	app.tool_state.landscape_editor = false
	app.city_toolbar.set_landscape_editor(false)
	app.city_menu_bar.disasters_menu.disabled = false

	var music_was_active := app.effects_audio.music_playback_is_active()
	app.effects_audio.stop_sound_loop()

	app.budget.reset_prompts()
	app.current_tool.reset_prompts()

	if app.city_dialogs.new_city_dialog != null and app.city_dialogs.new_city_dialog.visible:
		app.city_dialogs.new_city_dialog.hide()

	app.new_city_state.return_to_main_menu = false

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.scurk_place_print.hide()

	if app.scurk_print != null:
		app.scurk_print.hide()

	app.scurk_state.pending_print_options = null
	app.scurk_state.edit_history.clear()
	app.budget.reset_pending_state()
	app.document_state.city = loaded_city
	app.map_view.pending_loaded_center = Vector2i(-1, -1)

	if not document.source_path.is_empty() or not document.sc2x_converted_from.is_empty():
		app.map_view.pending_loaded_center = Vector2i(clampi(document.misc_u32(Sc2MiscLayout.CITY_CENTER_X), 0,
			app.document_state.city.map_size - 1),
				clampi(document.misc_u32(Sc2MiscLayout.CITY_CENTER_Y), 0, app.document_state.city.map_size - 1))

	app.current_tool.select_tool_group(CityToolIds.Group.CENTERING)
	app.view_state.overlay_mode = CityViewMode.Mode.CITY
	document_state.current_document = document
	# a large city computes its snapshot while it loads
	document_state.saved_city_snapshot = content_snapshot if not content_snapshot.is_empty() else document.content_snapshot()
	var facility_repair := FacilityRecordRepair.apply(app.document_state.city)

	if not facility_repair.ok:
		status_text += " " + str(facility_repair.error)
	elif facility_repair.linked > 0 or facility_repair.unfilled > 0:
		status_text += tr(" Restored facility records for %d buildings.") % facility_repair.linked

		if facility_repair.unfilled > 0:
			status_text += tr(" %d buildings still need records; the table is full.") % facility_repair.unfilled

	document_state.current_city_saved_once = not document_state.current_document.source_path.is_empty()
	var source_path := document_state.current_document.source_path.simplify_path()
	document_state.current_save_path = (
		source_path
		if (
			not source_path.is_empty()
			and not CityFiles.is_reference_path(source_path, app.asset_state.reference_root)
		)
		else ""
	)
	app.interface.hide_main_menu()
	app.static_render.invalidate_rendered_city()
	app.palette_clock.cycle_ticks = 0
	app.palette_clock.elapsed_msec = 0.0
	app.static_render.update_palette_cycle_texture()

	var process_seed := app.tool_state.tool_random.state
	var game_seed := app.simulation_state.nuisance_random.state
	var lfsr_seed := (
		app.simulation_state.simulation_engine.lfsr_random.state
		if app.simulation_state.simulation_engine != null
		else (Time.get_ticks_msec() & 0xffff) | 1
	)

	if app.simulation_state.frame_simulation != null:
		app.simulation_state.frame_simulation.close()

	app.simulation_state.frame_simulation = null
	app.timing_state.simulation_timings.clear()
	app.simulation_state.simulation_engine = Simulation.new(app.document_state.city, process_seed, lfsr_seed, game_seed)

	# an sc2x version 4 save holds the random states, even without phase state,
	# and the engine state with the load-scan results
	var saved_file := loaded_from_file and document.is_sc2x() and document.sc2x_converted_from.is_empty()
	var saved_state := saved_file and Sc2xCheckpoint.has_saved_state(document.sc2x_metadata)

	if saved_file:
		Sc2xCheckpoint.restore_random(app.simulation_state.simulation_engine, document.sc2x_metadata)

	# the load-time utility scan is not a player change. keep a repaired city unsaved
	if loaded_from_file and not saved_state:
		var before_scan := document_state.current_document.content_snapshot()
		var unchanged := not before_scan.is_empty() and before_scan == document_state.saved_city_snapshot

		if not app.simulation_state.simulation_engine.initialize_loaded_city():
			status_text += " The power and water scan failed."
		elif unchanged:
			document_state.saved_city_snapshot = document_state.current_document.content_snapshot()

	app.simulation_state.simulation_engine.vehicle_crashes_enabled = app.view_state.show_vehicles
	app.simulation_state.speed_controller = GameSpeed.new(app.simulation_state.simulation_engine)
	app.simulation_state.resume_speed = app.simulation_state.speed_controller.speed

	if saved_state:
		var restore_error := Sc2xCheckpoint.restore(app.simulation_state.speed_controller, document.sc2x_metadata)

		if not restore_error.is_empty():
			status_text += " " + restore_error

	if document_state.current_document.is_extended():
		app.simulation_state.frame_simulation = FrameSimulationRunner.new(app.simulation_state.speed_controller)

	app.frame.sync_speed_ui()
	app.tool_state.tool_random = app.simulation_state.simulation_engine.random
	app.simulation_state.nuisance_random = app.simulation_state.simulation_engine.game_random
	app.simulation_state.simulation_map_dirty = false
	app.reports.refresh_saved_news_summary()
	app.tool_state.last_edit_command = null
	app.tool_state.dispatch_cycles = PackedInt32Array([0, 0, 0])
	app.tool_state.dispatch_epoch = -1
	app.camera_input.update_zoom_controls(app.map_view.zoom_percent())

	app.city_menu_bar.set_city_name(app.document_state.city.display_name(),
		DebugFileInfo.city_tooltip(app.document_state.city.display_name(), app.document_state.current_document))
	app.city_menu_bar.set_scenario_available(app.simulation_state.simulation_engine.scenario != null)
	app.reports.refresh_newspaper_menu()
	app.interface.refresh_details()
	app.status_label.theme_type_variation = ""
	app.status_label.text = status_text if not status_text.is_empty() else "City ready."
	app.map_render.refresh_map()
	app.debug_tools.on_city_activated()
	app.current_tool.update_edit_state()

	if not app.document_state.city.music_enabled():
		app.effects_audio.stop_music()
	elif music_was_active:
		app.simulation_state.simulation_engine.midi_playback_active = true
	else:
		app.effects_audio.play_music_track(app.audio_controller.music_director.next_general_track())

	if loaded_scenario != null:
		app.budget.open_scenario_intro(loaded_scenario)

	if not facility_repair.ok or facility_repair.linked > 0 or facility_repair.unfilled > 0:
		app.status_label.text = status_text

	app.scripting.on_city_opened()

	return true


# Loss returns to city selection. The ended city cannot be continued.
func finish_game() -> void:
	if app.simulation_state.frame_simulation != null:
		app.simulation_state.frame_simulation.close()

	app.simulation_state.frame_simulation = null
	app.static_render.restart_static_render()
	app.static_render.invalidate_rendered_city()
	app.budget.reset_prompts()
	app.budget.reset_pending_state()
	app.current_tool.reset_prompts()

	for window in app.city_dialogs.blocking_windows + app.city_dialogs.modeless_windows:
		window.hide()

	app.simulation_state.speed_controller = null
	app.simulation_state.simulation_engine = null
	app.document_state.city = null
	app.scripting.emit("city.closed")
	document_state.current_document = null
	document_state.current_save_path = ""
	document_state.saved_city_snapshot = PackedByteArray()
	document_state.current_city_saved_once = false
	app.tool_state.last_edit_command = null
	app.scurk_state.edit_history.clear()
	app.city_menu_bar.set_scenario_available(false)
	app.interface.show_main_menu()
