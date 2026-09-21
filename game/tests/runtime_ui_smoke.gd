extends SceneTree

const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const Music = preload("res://src/audio/music_director.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var user_args := OS.get_cmdline_user_args()

	if user_args.is_empty():
		push_error("runtime_ui_smoke.gd needs the reference directory")
		quit(2)

		return

	var reference_root := str(user_args[0])
	if "--quick" in user_args:
		await _run_quick(reference_root)
		return
	var packed_scene := load("res://main.tscn") as PackedScene

	if packed_scene == null:
		push_error("Cannot load the main scene")
		quit(2)

		return

	var main := packed_scene.instantiate()
	main.asset_state.reference_root = reference_root
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	root.add_child(main)
	await process_frame
	await process_frame
	main.new_city.call("open_new_city_dialog")
	await process_frame
	var main_menu := main.get("main_menu") as MainMenuControl
	var new_city_dialog := main.get("new_city_dialog") as NewCityTerrainDialog

	if main_menu == null or new_city_dialog == null or main_menu.visible or not new_city_dialog.visible:
		push_error("New City does not take input ownership from the main menu")
		main.queue_free()
		quit(2)

		return

	main.new_city.call("cancel_new_city")
	await process_frame

	if not main_menu.visible or new_city_dialog.visible:
		push_error("Canceling New City does not restore the main menu")
		main.queue_free()
		quit(2)

		return

	for relative_path in [
		"CITIES/ISLAND.SC2",
		"SCENARIO/CHARLEST.SCN",
	]:
		var city_path := reference_root.path_join(relative_path).simplify_path()
		main.city_files.call("_load_city_unchecked", city_path)
		await process_frame
		await process_frame
		var document: Sc2File = main.document_state.current_document

		if (
			main.document_state.city == null
			or document == null
			or document.source_path.simplify_path() != city_path
		):
			push_error("Cannot load the smoke-test city: %s" % relative_path)
			main.queue_free()
			quit(2)

			return

		var loaded_city: CityState = main.document_state.city
		var menu_bar := main.get("city_menu_bar") as CityMenuBar
		var status_bar := main.get("city_status_bar") as CityStatusBar
		var date_label := menu_bar.date_label
		var money_label := menu_bar.money_label
		var population_label := menu_bar.population_label
		var speed_label := status_bar.speed_label
		var speed_menu := main.get("speed_menu") as MenuButton
		var rci_graph := status_bar.rci_graph
		var expected_date := "%02d/%02d/%04d" % [
			loaded_city.current_month(),
			loaded_city.current_day(),
			loaded_city.current_year(),
		]
		var expected_money := "$%s" % main.interface.call(
			"format_number", loaded_city.funds()
		)

		if (
			date_label.text != expected_date
			or money_label.text != expected_money
			or not population_label.text.contains(main.interface.call("format_number", loaded_city.population()))
			or rci_graph.demand != loaded_city.rci_demand()
			or not rci_graph.demand_available
			or not speed_label.text.contains((main.simulation_state.speed_controller as GameSpeedController).speed_name())
			or speed_menu == null
		):
			push_error("Menu or status metrics are not synchronized for %s" % relative_path)
			main.queue_free()
			quit(2)

			return

		if relative_path == "CITIES/ISLAND.SC2":
			if main.city_files.call("_city_has_unsaved_changes"):
				push_error("A newly loaded city is incorrectly marked as changed")
				main.queue_free()
				quit(2)

				return

			if not _test_save_city(main):
				main.queue_free()
				quit(2)

				return

			var original_funds := loaded_city.funds()
			loaded_city.set_funds(original_funds + 1)
			main.city_files.call("request_city_exit", "quit")
			var save_changes_dialog := main.get("save_changes_dialog") as ConfirmationDialog

			if (
				not main.city_files.call("_city_has_unsaved_changes")
				or save_changes_dialog == null
				or not save_changes_dialog.visible
				or main.city_files.pending_city_exit_action != "quit"
			):
				push_error("A changed city does not show the save-changes gate")
				main.queue_free()
				quit(2)

				return

			save_changes_dialog.hide()
			main.city_files.call("cancel_pending_city_exit")
			loaded_city.set_funds(original_funds)

			if main.city_files.call("_city_has_unsaved_changes"):
				push_error("Restoring a city to its loaded bytes does not clear the changed state")
				main.queue_free()
				quit(2)

				return

			status_bar.set_reports(PackedStringArray([
				"Good health", "Good employment", "Low crime",
			]))
			main.interface.call("refresh_status_summary")
			# Reports rotate when no priority city status is displayed.
			status_bar.set_city_status(null, false)
			var report_label := status_bar.reports_label
			status_bar.update_report_rotation(6.0)
			var first_report_stable := report_label.text == "Good health"
			status_bar.update_report_rotation(1.1)

			if (
				not first_report_stable
				or report_label.text != "Good employment"
				or not report_label.tooltip_text.contains("Low crime")
			):
				push_error("Status news does not rotate one saved report every seven seconds")
				main.queue_free()
				quit(2)

				return

			main.reports.call("refresh_saved_news_summary")
			var patch_point := Vector2i(-1, -1)

			for x in range(8, CityState.MAP_SIZE - 8):
				if patch_point.x >= 0:
					break

				for y in range(8, CityState.MAP_SIZE - 8):
					if (
						loaded_city.building_id(x, y) == 0
						and loaded_city.terrain_id(x, y) == 0
						and not loaded_city.is_water(x, y)
						and loaded_city.zone_id(x, y) == 0
					):
						patch_point = Vector2i(x, y)
						break

			if patch_point.x < 0:
				push_error("Cannot find clear terrain for the regional edit smoke test")
				main.queue_free()
				quit(2)

				return

			var funds_before_tree := loaded_city.funds()
			main.tool_state.selected_group = 1
			main.tool_state.selected_subtool = 0
			var patch_path: Array[Vector2i] = [patch_point]
			main.city_edits.call(
				"apply_map_selection",
				patch_point,
				patch_point,
				patch_path,
				false
			)
			var landscape_command: EditCommandResult = main.tool_state.last_edit_command

			if (
				landscape_command.command_type != "landscape"
				or loaded_city.building_id(patch_point.x, patch_point.y) < 0x06
			):
				push_error("The simple edit flow did not apply the landscape command")
				main.queue_free()
				quit(2)

				return

			main.city_edits.call("undo_last_edit")

			if (
				loaded_city.building_id(patch_point.x, patch_point.y) != 0
				or loaded_city.funds() != funds_before_tree
			):
				push_error("Landscape Undo did not restore the city")
				main.queue_free()
				quit(2)

				return

			main.tool_state.selected_group = 9
			main.tool_state.selected_subtool = 0
			main.city_edits.call(
				"apply_map_selection",
				patch_point,
				patch_point,
				patch_path,
				false
			)
			var patch_command: EditCommandResult = main.tool_state.last_edit_command
			var view_size := int(main.static_render.call("city_view_size"))
			var expected_signature: Array = main.static_render.call(
				"static_signature_for_mode", CityViewMode.Mode.CITY, view_size
			)

			if (
				patch_command.command_type != "zone"
				or main.static_render_state.task != null
				or main.render_caches.static_visual_signature != expected_signature
			):
				push_error("A bounded city edit did not use the exact regional refresh")
				main.queue_free()
				quit(2)

				return

			main.city_edits.call("undo_last_edit")

			if (
				main.static_render_state.task != null
				or loaded_city.zone_id(patch_point.x, patch_point.y) != 0
			):
				push_error("Regional city-edit Undo did not restore the prior view")
				main.queue_free()
				quit(2)

				return

			var funds_before_scurk := loaded_city.funds()
			main.scurk_workspace.call("open_scurk_place_print")
			await process_frame
			var place_print: ScurkPlacePrintControl = main.get("scurk_place_print")

			if place_print == null:
				push_error("SCURK Place & Print control is missing")
				main.queue_free()
				quit(2)

				return

			var place_list: ItemList = place_print.object_list

			if (
				not place_print.visible
				or place_list == null
				or place_list.item_count != 24
				or not place_print.select_tile(BuildingTileIds.SMALL_PARK)
			):
				push_error("Cannot open the SCURK Place & Print object selector")
				main.queue_free()
				quit(2)

				return

			if (
				place_print.export_bmp_button == null
				or not place_print.export_bmp_button.disabled
			):
				push_error("SCURK city BMP export is not gated to the small view")
				main.queue_free()
				quit(2)

				return

			main.scurk_output.call("_open_scurk_print_dialog")
			await process_frame
			var print_control: ScurkPrintControl = main.get("scurk_print")

			if (
				print_control == null
				or not print_control.visible
				or print_control.preview.preview_texture == null
				or print_control.preview.selected_pages.size() != 2
				or print_control.preview.selected_page_count() != 2
			):
				push_error("SCURK printable city dialog did not prepare its 1x preview")
				main.queue_free()
				quit(2)

				return

			print_control.magnification_selector.select(1)
			print_control.call("_on_magnification_changed", 1)
			print_control.view_selector.select(1)
			print_control.call("_on_view_changed", 1)

			if (
				print_control.preview.selected_pages.size() != 8
				or not print_control.pipes_check.visible
				or print_control.buildings_check.visible
				or print_control.preview.preview_texture == null
			):
				push_error("SCURK printable city options do not match the 2x underground view")
				main.queue_free()
				quit(2)

				return

			print_control.hide()
			var place_preview: Array[Vector2i] = main.get("map_view").selection.point_preview_tiles(
				patch_point
			)
			main.city_edits.call(
				"apply_map_selection",
				patch_point,
				patch_point,
				patch_path,
				false
			)
			var scurk_command: EditCommandResult = main.tool_state.last_edit_command

			if (
				place_preview != [patch_point]
				or scurk_command.command_type != "scurk_place_object"
				or loaded_city.building_id(patch_point.x, patch_point.y) != 0x0d
				or loaded_city.funds() != funds_before_scurk
			):
				push_error("SCURK Place & Print did not place the previewed object")
				main.queue_free()
				quit(2)

				return

			main.scurk_workspace.call("undo_scurk_place")

			if loaded_city.building_id(patch_point.x, patch_point.y) != 0:
				push_error("SCURK Place & Print Undo did not restore the city")
				main.queue_free()
				quit(2)

				return

			main.scurk_workspace.call("_redo_scurk_place")

			if loaded_city.building_id(patch_point.x, patch_point.y) != 0x0d:
				push_error("SCURK Place & Print Redo did not restore the object")
				main.queue_free()
				quit(2)

				return

			main.scurk_workspace.call("undo_scurk_place")

			if (
				not place_print.select_edit_tool(16)
				or place_print.tool_list == null
				or place_print.tool_list.item_count != 25
				or place_print.is_object_mode()
				or place_print.selected_edit_tool().group != 6
				or place_print.selected_edit_tool().subtool != 0
				or main.get("map_view").selection_mode != "path"
			):
				push_error("SCURK Place & Print edit toolbox is not available")
				main.queue_free()
				quit(2)

				return

			main.city_edits.call(
				"apply_map_selection",
				patch_point,
				patch_point,
				patch_path,
				false
			)
			var scurk_road: EditCommandResult = main.tool_state.last_edit_command

			if (
				scurk_road.command_type != "network"
				or not scurk_road.scurk_place_history
				or scurk_road.cost != 0
				or loaded_city.funds() != funds_before_scurk
				or loaded_city.building_id(patch_point.x, patch_point.y) < 0x1d
			):
				push_error("SCURK Place & Print did not build its free road")
				main.queue_free()
				quit(2)

				return

			main.scurk_workspace.call("undo_scurk_place")

			if loaded_city.building_id(patch_point.x, patch_point.y) != 0:
				push_error("SCURK free road Undo did not restore the city")
				main.queue_free()
				quit(2)

				return

			main.scurk_workspace.call("_redo_scurk_place")

			if loaded_city.building_id(patch_point.x, patch_point.y) < 0x1d:
				push_error("SCURK free road Redo did not restore the route")
				main.queue_free()
				quit(2)

				return

			main.scurk_workspace.call("undo_scurk_place")

			if not place_print.select_edit_tool(15):
				push_error("SCURK Military Zone tool is not selectable")
				main.queue_free()
				quit(2)

				return

			main.city_edits.call(
				"apply_map_selection",
				patch_point,
				patch_point,
				patch_path,
				true
			)
			var scurk_military_zone: EditCommandResult = main.tool_state.last_edit_command

			if (
				scurk_military_zone.command_type != "zone"
				or loaded_city.zone_id(patch_point.x, patch_point.y) != 7
				or loaded_city.funds() != funds_before_scurk
			):
				push_error("SCURK Place & Print did not apply its free Military Zone")
				main.queue_free()
				quit(2)

				return

			main.scurk_workspace.call("undo_scurk_place")

			if loaded_city.zone_id(patch_point.x, patch_point.y) != 0:
				push_error("SCURK Military Zone Undo did not restore the city")
				main.queue_free()
				quit(2)

				return

			main.scurk_workspace.call("close_scurk_place_print")

		var focus_engine: SimulationEngine = main.simulation_state.simulation_engine
		var audio_controller = main.get("audio_controller")
		var focus_director: MusicDirector = audio_controller.music_director
		loaded_city.set_music_enabled(true)
		audio_controller.dummy_music_active = true
		audio_controller.application_has_focus = true
		focus_engine.midi_playback_active = true
		audio_controller.set_background_audio(false)
		var focus_general_index := focus_director.general_track_index
		var effect_probe := AudioStreamPlayer.new()
		main.add_child(effect_probe)
		effect_probe.add_to_group(&"open_sc2k_sound_effects")
		main.effects_audio.call("handle_application_focus_out")
		var focus_out_ok: bool = (
			not audio_controller.application_has_focus
			and audio_controller.dummy_music_active
			and audio_controller.focus_paused
			and focus_engine.midi_playback_active
			and effect_probe.is_queued_for_deletion()
		)
		main.effects_audio.call("handle_application_focus_in")
		var expected_general_index := (
			focus_general_index
		)
		var focus_in_ok: bool = (
			audio_controller.application_has_focus
			and audio_controller.dummy_music_active
			and focus_engine.midi_playback_active
			and focus_director.general_track_index == expected_general_index
		)
		main.effects_audio.call("handle_application_focus_in")

		if (
			not focus_out_ok
			or not focus_in_ok
			or focus_director.general_track_index != expected_general_index
		):
			push_error("Application focus does not preserve paused music state")
			main.queue_free()
			quit(2)

			return

		loaded_city.set_sound_enabled(true)
		var wave_gate = audio_controller.wave_sound_gate
		var wave_cache: Dictionary = audio_controller.wave_stream_cache
		var wave_accepted_before := int(wave_gate.accepted_count)
		var wave_suppressed_before := int(wave_gate.suppressed_count)
		var repeated_sounds: Array[int] = [504, 504, 504]
		main.effects_audio.call("play_sound_ids", repeated_sounds)

		if (
			wave_cache.size() != 30
			or wave_gate.current_sound_id != 504
			or wave_gate.accepted_count != wave_accepted_before + 1
			or wave_gate.suppressed_count != wave_suppressed_before + 2
		):
			push_error("The cached run-time WAVE gate does not suppress an immediate repeat burst")
			main.queue_free()
			quit(2)

			return

		main.effects_audio.call("stop_sound_effects")
		main.effects_audio.call("start_tool_loop_sound", 508)
		var bulldozer_loop := audio_controller.tool_loop_player as AudioStreamPlayer
		var bulldozer_stream := (
			bulldozer_loop.stream as AudioStreamWAV
			if bulldozer_loop != null
			else null
		)
		var bulldozer_loop_ok := (
			bulldozer_loop != null
			and bulldozer_loop.is_playing()
			and bulldozer_stream != null
			and bulldozer_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		)
		main.effects_audio.call("stop_tool_loop_sound")

		if (
			not bulldozer_loop_ok
			or audio_controller.tool_loop_player != null
			or not bulldozer_loop.is_queued_for_deletion()
		):
			push_error("Bulldozer feedback does not start and stop its held sound")
			main.queue_free()
			quit(2)

			return

		loaded_city.set_music_enabled(false)
		loaded_city.set_sound_enabled(false)
		var scenario_dialog := main.get("scenario_dialog") as Window

		if scenario_dialog != null:
			scenario_dialog.hide()

		for menu_id in range(5):
			main.menus.call("on_speed_menu", menu_id)
			var controller: GameSpeedController = main.simulation_state.speed_controller
			var checked_speed_items := 0

			for item_index in speed_menu.get_popup().item_count:
				if speed_menu.get_popup().is_item_checked(item_index):
					checked_speed_items += 1

			if (
				controller.speed != menu_id + GameSpeed.Speed.PAUSED
				or checked_speed_items != 1
				or not speed_menu.get_popup().is_item_checked(menu_id)
				or not speed_label.text.contains(controller.speed_name())
			):
				push_error("Speed menu item %d selected the wrong speed" % menu_id)
				main.queue_free()
				quit(2)

				return

		main.frame.call("select_speed", GameSpeed.Speed.AFRICAN_SWALLOW)

		for tick in range(25 if relative_path == "CITIES/ISLAND.SC2" else 5):
			main.frame.call("process", 0.2)

			if bool(main.simulation_state.annual_budget_pending):
				main.budget.call("commit_budget")
				var budget_dialog := main.get("budget_dialog") as Window
				budget_dialog.hide()

			if bool(main.simulation_state.military_proposal_pending):
				main.budget.call("decline_military_proposal")
				var military_dialog := main.get("military_dialog") as Window
				military_dialog.hide()

		main.frame.call("select_speed", GameSpeed.Speed.PAUSED)

	for mode in [CityViewMode.Mode.UNDERGROUND, CityViewMode.Mode.CITY]:
		main.menus.call("set_overlay", mode)
		await process_frame

	for layer in ["buildings", "networks", "water", "trees", "zones", "signs"]:
		main.menus.call("set_surface_visibility", false, layer)
		main.menus.call("set_surface_visibility", true, layer)

	main.menus.call("set_overlay", CityViewMode.Mode.UNDERGROUND)
	main.menus.call("set_underground_pipes_visible", false)
	main.menus.call("set_underground_pipes_visible", true)
	main.menus.call("set_overlay", CityViewMode.Mode.CITY)

	for entry in [
		[main.reports._open_ordinance_window, "ordinance_window"],
		[main.reports._open_population_window, "population_window"],
		[main.reports._open_industry_window, "industry_window"],
		[main.reports._open_graph_window, "graph_window"],
		[main.reports._open_simnation_window, "simnation_window"],
		[main.reports.open_city_map_window, "city_map_window"],
		[main.reports.on_newspaper_menu.bind(0), "newspaper_dialog"],
		[main.budget.open_manual_budget, "budget_dialog"],
		[main.settings.open_settings_dialog, "settings_dialog"],
		[main.interface.open_about_dialog, "about_dialog"],
	]:
		entry[0].call()

		await process_frame
		var opened_window := main.get(entry[1]) as Window

		if opened_window != null:
			opened_window.hide()

		await process_frame

	main.query_choices.call("open_query", Vector2i(64, 64))
	await process_frame
	main.query_choices.call("close_query", false)

	for group in range(18):
		main.current_tool.call("select_tool_group", group)
		await process_frame

	main.current_tool.call("select_tool_group", 0)
	var debug_overlay := main.get("debug_overlay") as CityDebugOverlay

	if debug_overlay == null or debug_overlay.get("_window") == null or debug_overlay.is_open:
		push_error("The native debug window is not initialized and hidden")
		main.queue_free()
		quit(2)

		return

	debug_overlay.toggle()
	await process_frame
	var debug_metrics: Dictionary = main.debug.call("debug_metrics")

	if (
		not debug_overlay.is_open
		or not debug_metrics.has("dynamic_revisions")
		or not debug_metrics.has("sign_scans")
		or str(debug_metrics.get("tool", "")).is_empty()
	):
		push_error("The F12 debug overlay does not expose city renderer metrics")
		main.queue_free()
		quit(2)

		return

	# Scenario playback may still have an active disaster. Start debug actions from idle.
	assert(main.debug.call("debug_end_disaster").ok)
	var debug_city: CityState = main.document_state.city
	var debug_misc_chunk := debug_city.document.find_chunk("MISC")
	var debug_old_misc: PackedByteArray = debug_misc_chunk.decoded_payload.duplicate()
	var debug_old_funds := debug_city.funds()
	var money_result: ApplicationDebug.ActionResult = main.debug.call("debug_add_funds", 10000)
	var unlock_result: ApplicationDebug.ActionResult = main.debug.call("debug_unlock_everything")
	var unlocked := ToolAvailability.inspect(debug_city)

	if (
		not money_result.ok
		or debug_city.funds() != debug_old_funds + 10000
		or not unlock_result.ok
		or not unlocked.ok
		or int(unlocked.power_plant_mask) != 0x1ff
		or int(unlocked.group_masks[5]) & 0x10 == 0
	):
		push_error("The debug money or unlock action did not update the city")
		main.queue_free()
		quit(2)

		return

	debug_misc_chunk.set_decoded_payload(debug_old_misc)
	var debug_thing_chunk := debug_city.document.find_chunk("XTHG")
	var debug_text_chunk := debug_city.document.find_chunk("XTXT")
	var debug_old_things: PackedByteArray = debug_thing_chunk.decoded_payload.duplicate()
	var debug_old_text: PackedByteArray = debug_text_chunk.decoded_payload.duplicate()
	var debug_engine: SimulationEngine = main.simulation_state.simulation_engine
	var debug_old_active_disaster := debug_engine.active_disaster_type
	var debug_old_pending_disaster := debug_engine.pending_disaster_type
	var debug_old_pending_point := debug_engine.pending_disaster_point
	var debug_old_map_counter := debug_engine.disaster_map_counter
	var debug_old_hurricane_counter := debug_engine.disaster_hurricane_counter
	var empty_things := PackedByteArray()
	empty_things.resize(CityState.THING_COUNT * CityState.THING_RECORD_SIZE)
	empty_things.fill(0)
	var empty_text := PackedByteArray()
	empty_text.resize(CityState.TILE_COUNT)
	empty_text.fill(0)
	debug_thing_chunk.set_decoded_payload(empty_things)
	debug_text_chunk.set_decoded_payload(empty_text)
	debug_city.text_overlays = empty_text.duplicate()
	debug_city.set_text_overlay_id(64, 64, 0xff)
	var maxis_result: ApplicationDebug.ActionResult = main.debug.call("debug_dispatch_maxis_man")

	if not maxis_result.ok or debug_city.thing(1).type != 16:
		push_error("The debug Maxis Man action did not dispatch a saved moving object")
		main.queue_free()
		quit(2)

		return

	debug_thing_chunk.set_decoded_payload(empty_things)
	debug_text_chunk.set_decoded_payload(empty_text)
	debug_city.text_overlays = empty_text.duplicate()
	var start_disaster: ApplicationDebug.ActionResult = main.debug.call(
		"debug_start_disaster", DisasterStart.DISASTER_TORNADO
	)
	var active_disaster_metrics: Dictionary = main.debug.call("debug_metrics")

	if (
		not start_disaster.ok
		or debug_engine.active_disaster_type != DisasterStart.DISASTER_TORNADO
		or debug_city.city_mode() != 2
		or str(active_disaster_metrics.get("active_disaster", "")).is_empty()
	):
		push_error("The debug disaster starter did not enter normal disaster mode: %s" % start_disaster)
		main.queue_free()
		quit(2)

		return

	debug_city.set_text_overlay_id(65, 64, 0xff)
	var end_disaster: ApplicationDebug.ActionResult = main.debug.call("debug_end_disaster")
	var disable_disasters: ApplicationDebug.ActionResult = main.debug.call("debug_set_no_disasters", true)

	if (
		not end_disaster.ok
		or debug_engine.active_disaster_type != 0
		or debug_city.city_mode() != 1
		or debug_city.thing(1).type != 0
		or debug_city.text_overlay_id(65, 64) != 0
		or not disable_disasters.ok
		or not debug_city.no_disasters_enabled()
	):
		push_error("The debug disaster controls did not update and clear normal city state")
		main.queue_free()
		quit(2)

		return

	debug_thing_chunk.set_decoded_payload(debug_old_things)
	debug_text_chunk.set_decoded_payload(debug_old_text)
	debug_misc_chunk.set_decoded_payload(debug_old_misc)
	debug_city.text_overlays = debug_old_text
	debug_engine.active_disaster_type = debug_old_active_disaster
	debug_engine.pending_disaster_type = debug_old_pending_disaster
	debug_engine.pending_disaster_point = debug_old_pending_point
	debug_engine.disaster_map_counter = debug_old_map_counter
	debug_engine.disaster_hurricane_counter = debug_old_hurricane_counter
	main.interface.call("refresh_details")
	main.moving_sprites.call("refresh_moving_things")
	debug_overlay.toggle()

	var menu_bar := main.get("city_menu_bar") as CityMenuBar
	var status_bar := main.get("city_status_bar") as CityStatusBar
	var overflow_text := "Overflow tooltip validation ".repeat(40)

	for section_data in [
		["message", status_bar.message_label],
		["population", menu_bar.population_label],
		["weather", status_bar.weather_label],
		["reports", status_bar.reports_label],
		["speed", status_bar.speed_label],
	]:
		var section_name := str(section_data[0])
		var section := section_data[1] as Label
		var original_text := section.text
		section.text = overflow_text

		if section == menu_bar.population_label:
			menu_bar.refresh_population_tooltip()
		else:
			status_bar.refresh_tooltips()

		if section.tooltip_text.is_empty():
			push_error("Status section %s does not expose overflow text" % section_name)
			main.queue_free()
			quit(2)

			return

		section.text = original_text

	menu_bar.refresh_population_tooltip()
	status_bar.refresh_tooltips()

	main.scurk_workspace.call("open_scurk_dialog")
	await process_frame
	var scurk_editor := main.get("scurk_editor") as Control
	var object_list := scurk_editor.get("object_list") as ItemList

	if not scurk_editor.visible or object_list.item_count != 499:
		push_error("Cannot open the complete SCURK object catalog")
		main.queue_free()
		quit(2)

		return

	# Sample catalog boundaries and categories in the integrated shell. Archive and
	# SCURK format tests own exhaustive sprite coverage. Hide display-only previews.
	scurk_editor.hide()

	for item_index in [0, 24, 100, object_list.item_count - 1]:
		scurk_editor.call("_on_object_selected", item_index)
		assert(scurk_editor.current_large_id == int(object_list.get_item_metadata(item_index)), "Catalog selection reaches the editor")

		for view in range(3):
			scurk_editor.call("_select_view", view)

	main.queue_free()
	await process_frame
	print("PASS: runtime UI smoke")
	quit()


func _test_save_city(main: Node) -> bool:
	var dialog := main.get("save_dialog") as FileDialog
	main.menus.call("on_file_menu", CityMenuBar.MENU_SAVE_CITY)

	if not dialog.visible:
		push_error("Save City must use Save As for a protected reference city")

		return false

	dialog.hide()
	var path := "user://save-city-smoke-%d.SC2" % OS.get_process_id()
	var absolute_path := ProjectSettings.globalize_path(path)
	var document := main.document_state.current_document as Sc2File
	var source_path := document.source_path
	var funds := document.misc_i32(0x14)
	main.city_files.call("on_save_path_selected", absolute_path)
	var first_save := FileAccess.get_file_as_bytes(path)
	document.set_misc_i32(0x14, funds + 123)
	main.menus.call("on_file_menu", CityMenuBar.MENU_SAVE_CITY)
	var saved := FileAccess.get_file_as_bytes(path)
	var expected := document.serialize()
	var passed: bool = (
		not first_save.is_empty() and saved != first_save
		and expected.ok and saved == expected.data
		and not dialog.visible and not main.city_files.call("_city_has_unsaved_changes")
		and main.document_state.current_save_path == absolute_path
	)
	DirAccess.remove_absolute(absolute_path)
	document.set_misc_i32(0x14, funds)
	document.source_path = source_path
	main.document_state.current_save_path = ""
	main.document_state.saved_city_snapshot = document.serialize().data

	if not passed:
		push_error("Save City did not overwrite the selected copy and update saved state")

	return passed


func _run_quick(reference_root: String) -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main)
	main.asset_state.reference_root = reference_root
	root.add_child(main)
	await process_frame
	assert(main.asset_state.assets_ready and main.main_menu.visible and main.document_state.city == null)
	var source := reference_root.path_join("CITIES/ISLAND.SC2")
	var source_hash := FileAccess.get_sha256(source)
	main.city_files._load_city_unchecked(source)
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	assert(main.document_state.city != null)
	var city: CityState = main.document_state.city
	var before: PackedByteArray = city.document.serialize().data
	var point := Vector2i(-1, -1)
	for x in range(8, city.document.map_size - 8):
		for y in range(8, city.document.map_size - 8):
			if city.building_id(x, y) == 0 and city.terrain_id(x, y) == 0 and not city.is_water(x, y) and city.zone_id(x, y) == 0:
				point = Vector2i(x, y)
				break
		if point.x >= 0:
			break
	assert(point.x >= 0, "Smoke fixture needs clear terrain")
	main.current_tool.select_tool_group(1)
	main.current_tool.select_subtool(0)
	var path: Array[Vector2i] = [point]
	main.city_edits.apply_map_selection(point, point, path, false)
	assert(main.tool_state.last_edit_command.command_type == "landscape")
	assert(city.document.serialize().data != before)
	main.city_edits.undo_last_edit()
	assert(city.document.serialize().data == before, "Undo restores all saved bytes")
	main.settings.open_settings_dialog()
	assert(main.settings_dialog.visible)
	main.settings_dialog.hide()
	main.query_choices.open_query(point)
	assert(main.query_dialog.visible)
	main.query_choices.close_query()
	main.new_city.open_new_city_dialog()
	assert(main.new_city_dialog.visible)
	main.new_city_dialog.size_input.select(main.new_city_dialog.size_input.get_item_index(128))
	main.new_city_dialog.city_name_input.text = "Workflow smoke"
	main.new_city.make_new_city_preview()
	while main.new_city_state.preview_job != null:
		await process_frame
	assert(main.new_city_dialog.candidate_valid)
	main.new_city.create_new_city_unchecked()
	assert(main.document_state.city != city and main.document_state.city.display_name() == "Workflow smoke")
	assert(main.tool_state.landscape_editor)
	var output := ProjectSettings.globalize_path("user://workflow-smoke.sc2x")
	main.city_files.on_save_path_selected(output)
	var saved := FileAccess.get_file_as_bytes(output)
	assert(not saved.is_empty() and saved == main.document_state.current_document.serialize().data)
	main.city_files._load_city_unchecked(output)
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	assert(main.document_state.current_document.serialize().data == saved)
	assert(FileAccess.get_sha256(source) == source_hash)
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(output)
	print("PASS: workflow start, load, edit, exact Undo, dialogs, New City, save and reload")
	quit()
