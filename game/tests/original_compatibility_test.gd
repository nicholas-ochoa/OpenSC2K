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
var save_path := "user://compatibility-test-%d.SC2" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	check_formats()
	check_reference_files(ProjectSettings.globalize_path("res://../references/SIMCITY2000").simplify_path())
	check_fire_clock()
	await check_ui()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("Original compatibility: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


# the city file format selects the save rules
func check_formats() -> void:
	for edge in Sc2File.MAP_SIZES:
		for native in [false, true]:
			var doc := EmptyCityTemplate.create(edge)

			if native:
				doc.enable_full_resolution_maps()

			var original := saved_payloads(doc)
			var sc2: bool = edge == 128 and not native
			check(OriginalCompatibility.uses_original_format(doc) == sc2, "Size and grid extensions select SC2X")
			check(OriginalCompatibility.document_error(doc).is_empty(), "Both formats hold their own payloads")

			if doc.is_extended():
				var file := FileAccess.open(save_path, FileAccess.WRITE)
				file.store_string("keep existing file")
				file.close()
				check(not CityFileStore.save_copy(doc, save_path, "res://../references/SIMCITY2000").ok, "Save rejects SC2X contents with an SC2 filename")
				check(FileAccess.get_file_as_string(save_path) == "keep existing file", "Rejected save does not truncate target")
			else:
				check(CityFileStore.save_copy(doc, save_path, "res://../references/SIMCITY2000").ok, "Save original city")
				check(FileAccess.get_file_as_bytes(save_path) == doc.serialize().data, "Original save stays byte-identical")
				check(not CityFileStore.save_copy(doc, save_path + "x", "res://../references/SIMCITY2000").ok, "An SC2 city rejects the SC2X extension")

			check(saved_payloads(doc) == original, "Policy does not convert or mutate city")

	# an SC2 header with an extended payload cannot save as SC2
	var mixed := EmptyCityTemplate.create(128)
	var altitude := mixed.find_chunk("ALTM")
	var larger := altitude.decoded_payload.duplicate()
	larger.resize(larger.size() * 4)
	altitude.expected_decoded_size = larger.size()
	check(altitude.set_decoded_payload(larger), "Store an extended payload in an SC2 city")
	check(not OriginalCompatibility.save_error(mixed, save_path).is_empty(), "Extended payload in an SC2 city is rejected")

	var options := NewCityTerrain.Options.new()
	options.size = 512
	options.native_maps = false
	options.hills = 10
	var expected := options.copy()
	expected.size = 128
	check(OriginalCompatibility.terrain_options(options, true).same_values(expected), "Compatibility creates an original-format city")
	expected = options.copy()
	expected.native_maps = true
	check(OriginalCompatibility.terrain_options(options, false).same_values(expected), "Other cities use per-tile data maps")
	check(options.size == 512 and not options.native_maps, "Creation policy leaves caller options unchanged")
	# Round-trip an unknown chunk through a compatible save.
	var doc := EmptyCityTemplate.create(128)
	var chunk := Sc2Chunk.new()
	chunk.chunk_id = "TEST"
	chunk.set_decoded_payload(PackedByteArray([1, 2, 3]))
	doc.chunks.append(chunk)
	check(CityFileStore.save_copy(doc, save_path, "res://../references/SIMCITY2000").ok, "Original unknown chunks remain supported")
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
			check(result.ok and result.disaster_results.size() == (5 if original else 1), "SC2 cities use original fire and firestorm cadence")
			var captured := SimulationSnapshot.capture(controller, null)
			check(captured.original_compatibility == original, "Simulation snapshot retains the fire cadence")


func check_ui() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.asset_state.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	root.add_child(main)
	await process_frame
	main.set_process(false)
	var dialog: NewCityTerrainDialog = main.city_dialogs.new_city_dialog
	check(not dialog.compatibility_input.button_pressed and dialog.terrain_options().native_maps, "New City defaults to SC2X")
	dialog.compatibility_input.button_pressed = true
	check(dialog.size_input.is_item_disabled(dialog.size_input.get_item_index(512)), "New City disables other map sizes")
	dialog.size_input.select(dialog.size_input.get_item_index(512))
	check(dialog.terrain_options().size == 128 and not dialog.terrain_options().native_maps, "Creation guard survives programmatic UI selection")
	main.new_city_state.session.independent_template = true
	main.new_city_state.session.begin(123, 456)
	var options: NewCityTerrain.Options = dialog.terrain_options()
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
	dialog.compatibility_input.button_pressed = false
	check(not dialog.size_input.is_item_disabled(dialog.size_input.get_item_index(512)), "Clearing compatibility restores map sizes")
	var small := dialog.terrain_options()
	small.size = 128
	small.hills = 0
	small.water = 0
	small.trees = 0
	small.ocean = false
	small.river = false
	generated = main.new_city_state.session.generate_preview("", small, false)
	check(generated.ok and generated.document.is_extended(), "A 128 preview without compatibility is SC2X")
	created = main.new_city_state.session.create_city("", "Extended", "Mayor", 1, 1900, small, PackedByteArray())
	check(created.ok and created.document.is_extended(), "A 128 city without compatibility is SC2X")

	var doc := EmptyCityTemplate.create(128)
	check(main.city_session.activate_document(doc), "SC2 city activates")
	check(main.simulation_state.speed_controller.original_compatibility, "SC2 city uses original fire timing")
	var extended := EmptyCityTemplate.create(256)
	var extended_file := FileAccess.open(save_path, FileAccess.WRITE)
	extended_file.store_buffer(extended.serialize().data)
	extended_file.close()
	main.city_files._load_city_unchecked(ProjectSettings.globalize_path(save_path))
	check(main.document_state.current_document.is_extended() and main.document_state.current_document.map_size == 256, "SC2X loads normally even with an SC2 filename")
	check(not main.simulation_state.speed_controller.original_compatibility, "SC2X city uses extended fire timing")
	check(main.city_session.activate_document(doc), "Return to SC2 city")
	check(main.simulation_state.speed_controller.original_compatibility, "SC2 timing returns with the SC2 city")
	main.queue_free()
	await process_frame


func check_reference_files(path: String) -> void:
	for directory in DirAccess.get_directories_at(path):
		check_reference_files(path.path_join(directory))

	for filename in DirAccess.get_files_at(path):
		if filename.get_extension().to_upper() not in ["SC2", "SCN"]:
			continue

		var doc := Sc2File.load_path(ProjectSettings.globalize_path(path.path_join(filename)))
		check(doc.is_valid() and OriginalCompatibility.uses_original_format(doc) and OriginalCompatibility.document_error(doc).is_empty(), "Supplied file is SC2: " + filename)
		# Exact corpus rebuilds belong to test_runner; this check owns the policy gate.


func saved_payloads(document: Sc2File) -> Array:
	var values: Array = []
	for chunk in document.chunks:
		values.append(chunk.decoded_payload.duplicate())
	return values
