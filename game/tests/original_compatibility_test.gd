extends SceneTree

class RecordingEngine extends SimulationEngine:


	func advance_disaster_tick() -> DisasterMapResult:
		var result := DisasterMapResult.new()
		result.ok = true

		return result


	func advance_moving_things(_current_time_msec := -1) -> MovingThingResult:
		var result := MovingThingResult.new()
		result.ok = true

		return result

var checks := 0
var failures := 0
var settings_path := "user://compatibility-test-%d.cfg" % OS.get_process_id()
var save_path := "user://compatibility-test-%d.SC2" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	check(not AppSettingsStore.load_values(settings_path).original_compatibility, "Existing defaults retain extensions")
	check(AppSettingsStore.load_values(settings_path).warn_sc2x_conversion, "Conversion warning defaults on")
	check(AppSettingsStore.save_values(0.8, 0.8, false, settings_path, "", "", null, null, null, null, null, null, null, null, true) == OK, "Save original compatibility preference")
	check(AppSettingsStore.load_values(settings_path).original_compatibility, "Preference persists")
	AppSettingsStore.save_values(0.4, 0.5, false, settings_path)
	check(AppSettingsStore.load_values(settings_path).original_compatibility, "Unrelated preference writes preserve compatibility")
	check_formats()
	check_reference_files(ProjectSettings.globalize_path("res://../references/SIMCITY2000").simplify_path())
	check_fire_clock()
	await check_ui()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("Original compatibility: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_formats() -> void:
	for edge in Sc2File.MAP_SIZES:
		for native in [false, true]:
			var doc := EmptyCityTemplate.create(edge)

			if native:
				doc.enable_full_resolution_maps()

			var original := saved_payloads(doc)
			check(OriginalCompatibility.document_error(doc, true).is_empty() == (edge == 128 and not native), "Format gate covers size and grid extensions")
			check(OriginalCompatibility.document_error(doc, false).is_empty(), "Extensions remain available when mode is off")

			if doc.is_extended():
				var file := FileAccess.open(save_path, FileAccess.WRITE)
				file.store_string("keep existing file")
				file.close()
				check(not CityFileStore.save_copy(doc, save_path, "res://../references/SIMCITY2000", true).ok, "Save rejects extended contents even with SC2 filename")
				check(FileAccess.get_file_as_string(save_path) == "keep existing file", "Rejected save does not truncate target")
			else:
				check(CityFileStore.save_copy(doc, save_path, "res://../references/SIMCITY2000", true).ok, "Save original city")
				check(FileAccess.get_file_as_bytes(save_path) == doc.serialize().data, "Original save stays byte-identical")
				check(not CityFileStore.save_copy(doc, save_path + "x", "res://../references/SIMCITY2000", true).ok, "Strict mode rejects SC2X output extension")

			check(saved_payloads(doc) == original, "Policy does not convert or mutate city")

	var options := NewCityTerrain.Options.new()
	options.size = 512
	options.native_maps = true
	options.hills = 10
	var expected := options.copy()
	expected.size = 128
	expected.native_maps = false
	check(OriginalCompatibility.terrain_options(options, true).same_values(expected), "Creation options force original format")
	check(options.size == 512 and options.native_maps, "Creation policy leaves caller options unchanged")
	# Round-trip an unknown chunk through a compatible save.
	var doc := EmptyCityTemplate.create(128)
	var chunk := Sc2Chunk.new()
	chunk.chunk_id = "TEST"
	chunk.set_decoded_payload(PackedByteArray([1, 2, 3]))
	doc.chunks.append(chunk)
	check(CityFileStore.save_copy(doc, save_path, "res://../references/SIMCITY2000", true).ok, "Original unknown chunks remain supported")
	check(Sc2File.load_path(ProjectSettings.globalize_path(save_path)).find_chunk("TEST").decoded_payload == chunk.decoded_payload, "Unknown original bytes survive")


func check_fire_clock() -> void:
	for disaster in [1, 12]:
		for original in [false, true]:
			var engine := RecordingEngine.new(CityState.from_document(EmptyCityTemplate.create(128)))
			engine.active_disaster_type = disaster
			var controller := GameSpeedController.new(engine)
			controller.set_speed(GameSpeedController.Speed.CHEETAH)
			controller.original_compatibility = original
			var result := controller.advance_time(1000, 1000)
			check(result.ok and result.disaster_results.size() == (5 if original else 1), "Compatibility uses original fire and firestorm cadence")
			var captured := SimulationSnapshot.capture(controller, null)
			check(captured.original_compatibility == original, "Simulation snapshot retains compatibility")


func check_ui() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.asset_state.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	main.preferences.settings_path = settings_path
	root.add_child(main)
	await process_frame
	main.set_process(false)
	check(main.preferences.original_compatibility, "Startup loads compatibility preference")
	main.city_dialogs.new_city_dialog.compatibility_input.button_pressed = true
	check(main.city_dialogs.new_city_dialog.native_maps_input.disabled and not main.city_dialogs.new_city_dialog.native_maps_input.button_pressed, "New City disables native grids")

	check(main.city_dialogs.new_city_dialog.size_input.disabled, "New City disables map size")

	main.city_dialogs.new_city_dialog.size_input.select(main.city_dialogs.new_city_dialog.size_input.get_item_index(512))
	main.city_dialogs.new_city_dialog.native_maps_input.set_pressed_no_signal(true)
	check(main.city_dialogs.new_city_dialog.terrain_options().size == 128 and not main.city_dialogs.new_city_dialog.terrain_options().native_maps, "Creation guard survives programmatic UI selection")
	main.new_city_state.session.independent_template = true
	main.new_city_state.session.begin(123, 456)
	var options: NewCityTerrain.Options = main.city_dialogs.new_city_dialog.terrain_options()
	# Format policy is independent of expensive terrain feature combinations.
	options.hills = 0
	options.water = 0
	options.trees = 0
	options.ocean = false
	options.river = false
	var generated: NewCityTerrainSession.PreviewResult = main.new_city_state.session.generate_preview("", options, false)
	check(generated.ok and not generated.document.is_extended(), "Compatibility generates original-format preview")
	var created: NewCitySetup.Result = main.new_city_state.session.create_city("", "Compatible", "Mayor", 1, 1900, options, PackedByteArray())
	check(created.ok and not created.document.is_extended(), "Compatibility creates original-format city")
	var doc := EmptyCityTemplate.create(128)
	check(main.city_session.activate_document(doc), "Compatible city activates")
	check(main.simulation_state.speed_controller.original_compatibility, "Active simulation receives compatibility")
	var bytes: PackedByteArray = doc.serialize().data
	main.document_state.current_save_path = "user://compatible-city.SC2"
	main.city_files.upgrade_city_to_sc2x()
	check(doc.serialize().data == bytes and not doc.is_extended(), "Conversion handler cannot bypass mode")
	main.interface.show_main_menu()
	var popup: PopupMenu = main.options_menu.get_popup()
	check(popup.get_item_index(CityMenuBar.MENU_UPGRADE_SC2X) < 0, "Main menu refresh retains conversion restriction")
	var extended := EmptyCityTemplate.create(256)
	var extended_file := FileAccess.open(save_path, FileAccess.WRITE)
	extended_file.store_buffer(extended.serialize().data)
	extended_file.close()
	main.city_files._load_city_unchecked(ProjectSettings.globalize_path(save_path))
	check(main.document_state.current_document.is_extended() and main.document_state.current_document.map_size == 256, "SC2X loads normally even with an SC2 filename")
	check(not main.preferences.original_compatibility and not main.simulation_state.speed_controller.original_compatibility, "Opening SC2X disables compatibility")
	check(not AppSettingsStore.load_values(settings_path).original_compatibility, "Automatic mode change persists")
	check(main.city_session.activate_document(doc), "Return to original city")
	main.preferences.original_compatibility = true
	main.settings.apply_compatibility_controls()
	main.settings.open_settings_dialog()
	check(main.main_overlays.settings_dialog.original_compatibility_check.button_pressed, "Settings shows current mode")
	main.main_overlays.settings_dialog.warn_sc2x_conversion_check.button_pressed = false
	main.main_overlays.settings_dialog.original_compatibility_check.button_pressed = false
	main.main_overlays.settings_dialog.hide()
	main.settings.apply_settings()
	check(not main.preferences.original_compatibility and not main.simulation_state.speed_controller.original_compatibility, "Mode can be disabled live")
	main.city_dialogs.new_city_dialog.compatibility_input.button_pressed = false
	check(not main.city_dialogs.new_city_dialog.native_maps_input.disabled, "Disabling New City compatibility restores extensions")
	check(not main.preferences.warn_sc2x_conversion and not AppSettingsStore.load_values(settings_path).warn_sc2x_conversion, "Warning checkbox disables and persists warning")
	check(main.city_session.activate_document(extended), "Extended city activates when mode is off")
	main.settings.open_settings_dialog()
	check(main.main_overlays.settings_dialog.original_compatibility_check.disabled, "SC2X disables compatibility checkbox")
	main.main_overlays.settings_dialog.original_compatibility_check.button_pressed = true
	main.main_overlays.settings_dialog.hide()
	main.settings.apply_settings()
	check(not main.preferences.original_compatibility and main.document_state.current_document == extended, "Enabling mode cannot discard or convert active SC2X city")
	check(not AppSettingsStore.load_values(settings_path).original_compatibility, "Rejected mode change does not persist")
	await process_frame
	main.main_overlays.settings_dialog.hide()
	main.queue_free()
	await process_frame


func check_reference_files(path: String) -> void:
	for directory in DirAccess.get_directories_at(path):
		check_reference_files(path.path_join(directory))

	for filename in DirAccess.get_files_at(path):
		if filename.get_extension().to_upper() not in ["SC2", "SCN"]:
			continue

		var doc := Sc2File.load_path(ProjectSettings.globalize_path(path.path_join(filename)))
		check(doc.is_valid() and OriginalCompatibility.document_error(doc, true).is_empty(), "Compatibility accepts supplied " + filename)
		# Exact corpus rebuilds belong to test_runner; this check owns the policy gate.


func saved_payloads(document: Sc2File) -> Array:
	var values: Array = []
	for chunk in document.chunks:
		values.append(chunk.decoded_payload.duplicate())
	return values
