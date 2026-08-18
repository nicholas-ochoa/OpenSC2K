extends SceneTree
## Generated city data, original startup, missing-import handling and settings.

const MISSING_ROOT := "user://independent-startup-no-original-data"
const SETTINGS := "user://independent-startup-test.cfg"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_generated_cities()
	_test_settings()
	var source := GameAssetSource.load_source(MISSING_ROOT, "auto")
	assert(not source.error.is_empty() and source.assets == null)

	for mode in ["original", "invalid", "folder"]:
		assert(not GameAssetSource.load_source(MISSING_ROOT, mode).error.is_empty())

	await _test_main()
	await _test_invalid_startup()
	print("PASS: independent startup, 12 New City combinations, generated terrain, monthly and annual dispatch, city round trips, settings and original runtime UI and missing-import handling")
	quit()


func _test_generated_cities() -> void:
	var template := EmptyCityTemplate.create()
	assert(template.is_valid() and template.source_path.is_empty())

	for chunk in template.chunks:
		assert(chunk.decoded_payload.size() == Sc2File.DECODED_SIZES[chunk.chunk_id])

	var unchanged: PackedByteArray = template.serialize().data

	for difficulty in range(1, 4):
		for year in NewCitySetup.STARTING_YEARS:
			var made := NewCitySetup.create(template, "Independent", "Builder", difficulty, year, SimRandom.new(1))
			assert(made.ok, str(made))
			var city := CityState.from_document(made.document)
			assert(city.is_valid() and city.city_name() == "Independent" and city.mayor_name() == "Builder")
			assert(city.founding_year() == year and city.age_in_days() == 0)
			assert(city.document.misc_u32(0x1c) == difficulty)
			assert(city.document.misc_u32(0x14) == (20000 if difficulty == 1 else 10000))
			assert(city.document.misc_u32(0x18) == (1 if difficulty == 3 else 0))

	assert(template.serialize().data == unchanged)
	assert(template.misc_u32(0x1008) == 0 and template.misc_u32(0x1010) == 0)
	assert(template.misc_u32(0x1040) == 0)
	var options := {"ocean": true, "river": true, "hills": 12, "water": 5, "trees": 0}
	var session := NewCityTerrainSession.new()
	session.independent_template = true
	session.begin(1, 1)
	var preview := session.generate_preview(MISSING_ROOT.path_join("DEFAULT.SC2"), options, false)
	assert(preview.ok, str(preview))
	var made := session.create_city(MISSING_ROOT.path_join("DEFAULT.SC2"), "Coast", "Mayor", 1, 1900, options, PackedByteArray())
	assert(made.ok, str(made))

	for chunk_id in ["ALTM", "XTER", "XBLD", "XUND", "XZON"]:
		assert(made.document.find_chunk(chunk_id).decoded_payload == preview.document.find_chunk(chunk_id).decoded_payload)

	var city := CityState.from_document(made.document)
	city.set_auto_budget_enabled(true)
	var simulation := SimulationEngine.new(city, 1, 1, 1)

	# Exercise a month of all dispatch phases, then the annual boundary.
	for day in 25:
		var advanced := simulation.advance_day()
		assert(advanced.ok, str(advanced))

	assert(city.age_in_days() == 25)
	assert(city.set_age_in_days(299))
	simulation.clock.city_days = 299
	assert(simulation.advance_day().ok)
	assert(city.age_in_days() == 300 and city.current_year() == 1901)
	_round_trip_city(city.document)
	var path := ProjectSettings.globalize_path("user://independent-city-%d.SC2" % OS.get_process_id())
	var saved := CityFileStore.save_copy(city.document, path, ProjectSettings.globalize_path(MISSING_ROOT))
	assert(saved.ok, str(saved))
	var reloaded := Sc2File.load_path(path)
	assert(reloaded.is_valid() and reloaded.serialize().data == saved.data)
	assert(DirAccess.remove_absolute(path) == OK)
	assert(session.generate_preview(MISSING_ROOT, options, false).document.serialize().data == preview.document.serialize().data)


func _round_trip_city(document: Sc2File) -> void:
	var encoded := document.serialize()
	assert(encoded.ok, str(encoded))
	var restored := Sc2File.new()
	assert(restored.parse(encoded.data), restored.parse_error)
	assert(CityState.from_document(restored).is_valid())
	assert(restored.serialize().data == encoded.data)


func _test_settings() -> void:
	assert(AppSettingsStore.save_values(0.2, 0.4, false, SETTINGS, "folder", "user://example-pack") == OK)
	var values := AppSettingsStore.load_values(SETTINGS)
	assert(values.graphics_source == "folder" and values.graphics_folder == "user://example-pack")
	assert(AppSettingsStore.save_values(0.3, 0.6, false, SETTINGS) == OK)
	assert(AppSettingsStore.load_values(SETTINGS).graphics_folder == "user://example-pack")
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS)) == OK)
	assert(AppSettingsStore.load_values(SETTINGS).graphics_source == "auto")


func _test_main() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.asset_state.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	root.add_child(main)
	await process_frame
	assert(main.asset_state.runtime_initialized and main.main_menu.visible)
	assert(not main.reference_import_dialog.visible and main.document_state.city == null)
	assert(main.audio_controller.original_media_enabled)
	main.settings.open_settings_dialog()
	assert(main.settings_dialog.visible)

	for mode in GameAssetSource.MODES:
		main.settings_dialog.show_values(0.2, 0.4, false, mode, "user://example-pack")
		assert(main.settings_dialog.selected_values().graphics_source == ("folder" if mode == "folder" else "auto"))
		assert(main.settings_dialog.folder_row.visible)

	main.settings_dialog.hide()
	main.map_view.zoom_factor = 0.25
	main.new_city.open_new_city_dialog()
	assert(main.new_city_dialog.visible and main.new_city_session.preview_document == null)
	main.new_city_dialog.city_name_input.text = "Original Startup"
	# This scenario checks original SC2 save compatibility.
	main.new_city_dialog.native_maps_input.button_pressed = false
	# Terrain algorithms are tested separately; retain the original-size workflow.
	main.new_city_dialog.hills_input.value = 0
	main.new_city_dialog.water_input.value = 0
	main.new_city_dialog.trees_input.value = 0
	main.new_city_dialog.river_input.button_pressed = false
	main.new_city_dialog.ocean_input.button_pressed = false
	main.new_city.make_new_city_preview()
	while main.new_city_preview_job != null:
		await process_frame
	main.new_city.create_new_city_unchecked()
	await process_frame
	assert(main.document_state.city != null and main.document_state.city.city_name() == "Original Startup")
	assert(main.tool_state.landscape_editor and main.city_toolbar.start_city_button.visible)
	main.new_city.start_city()
	main.newspaper_dialog.hide()
	main.speed_controller.set_speed(GameSpeedController.Speed.PAUSED)
	_round_trip_city(main.document_state.current_document)
	main.scurk_workspace.open_scurk_dialog()
	assert(main.scurk_editor.visible and main.scurk_editor.tile_set != null)
	assert(main.scurk_editor.source_path.is_empty() and main.asset_state.asset_source.uses_graphics_pack)
	assert(main.scurk_editor.current_large_id >= 1000)
	main.scurk_editor.hide()
	main.scurk_workspace.open_scurk_place_print()
	assert(main.scurk_place_print.visible)
	main.scurk_place_print.hide()
	main.city_files.open_save_dialog()
	assert(main.save_dialog.visible and main.save_dialog.current_file == "Original Startup.SC2")
	main.save_dialog.hide()
	main.queue_free()
	await process_frame
	await process_frame


func _test_invalid_startup() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "unknown")
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.asset_state.reference_root = ProjectSettings.globalize_path(MISSING_ROOT)
	root.add_child(main)
	await process_frame
	await process_frame
	assert(main.asset_state.runtime_initialized and not main.asset_state.assets_ready)
	assert(not main.reference_import_error_dialog.visible and main.main_menu.import_button.visible)
	assert(main.document_state.city == null and main.asset_state.palette == null)
	assert(main.map_view != null and main.audio_controller != null and not main.audio_controller.original_media_enabled)
	main.queue_free()
	await process_frame
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
