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
	var original := GameAssetSource.load_source(ProjectSettings.globalize_path("res://../references"), "original")
	assert(original.error.is_empty(), original.error)
	_test_generated_mif(original.assets)
	await _test_main()
	await _test_invalid_startup()
	print("PASS: independent startup, 12 New City combinations, generated terrain, a simulation year, city/MIF round trips, settings and original runtime UI and missing-import handling")
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
			_round_trip_city(made.document)
	assert(template.serialize().data == unchanged)
	assert(template.misc_u32(0x1008) == 0 and template.misc_u32(0x1010) == 0)
	assert(template.misc_u32(0x1040) == 0)
	var options := {"ocean": true, "river": true, "hills": 20, "water": 20, "trees": 20}
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
	for day in 300:
		var advanced := simulation.advance_day()
		assert(advanced.ok, str(advanced))
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


func _test_generated_mif(assets: OriginalGameAssets) -> void:
	var combined := Sc2SpriteArchive.combine([assets.large_sprites, assets.small_medium_sprites])
	var tile_set := ScurkMif.from_archives([assets.large_sprites, assets.small_medium_sprites])
	assert(tile_set.is_valid(), tile_set.parse_error)
	assert(tile_set.shapes.size() == combined.entries_by_id.size())
	var encoded := tile_set.to_bytes()
	assert(encoded.ok, str(encoded))
	var restored := ScurkMif.new()
	assert(restored.parse(encoded.bytes), restored.parse_error)
	assert(restored.to_bytes().bytes == encoded.bytes)
	for sprite_id in combined.entries_by_id:
		var expected := combined.find_sprite(sprite_id)
		var actual := restored.archive.find_sprite(sprite_id)
		assert(actual != null and actual.width == expected.width and actual.height == expected.height)
		assert(actual.decode_indices().pixels == expected.decode_indices().pixels)


func _test_main() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.unset_environment("OPENSC2K_GRAPHICS_PACK")
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_root = ProjectSettings.globalize_path("res://../references")
	root.add_child(main)
	await process_frame
	assert(main.runtime_initialized and main.main_menu.visible)
	assert(not main.reference_import_dialog.visible and main.city == null)
	assert(not main.audio_controller.original_media_enabled and main.audio_controller.wave_stream_cache.is_empty())
	assert(not main.audio_controller.play_music_track(MusicDirector.FIRST_TRACK_ID))
	assert(not main.audio_controller.music_playback_is_active())
	main._open_settings_dialog()
	assert(main.settings_dialog.visible)
	for mode in GameAssetSource.MODES:
		main.settings_dialog.show_values(0.2, 0.4, false, mode, "user://example-pack", main.asset_source.graphics_name)
		assert(main.settings_dialog.selected_values().graphics_source == mode)
		assert(main.settings_dialog.folder_row.visible == (mode == "folder"))
	main.settings_dialog.hide()
	main._open_new_city_dialog()
	assert(main.new_city_dialog.visible and main.new_city_session.preview_document != null)
	main.new_city_dialog.city_name_input.text = "Original Startup"
	main._create_new_city_unchecked()
	await process_frame
	assert(main.city != null and main.city.city_name() == "Original Startup")
	assert(main.landscape_editor and main.city_toolbar.start_city_button.visible)
	main._start_city()
	main.speed_controller.set_speed(GameSpeedController.Speed.PAUSED)
	_round_trip_city(main.current_document)
	main._open_scurk_dialog()
	assert(main.scurk_editor.visible and main.scurk_editor.tile_set != null)
	assert(main.scurk_editor.source_path.ends_with("SCURKART/ORIGINAL.MIF") and not main.scurk_editor.dirty)
	assert(main.scurk_editor.current_large_id >= 1000)
	main.scurk_editor.hide()
	main._open_scurk_place_print()
	assert(main.scurk_place_print.visible)
	main.scurk_place_print.hide()
	main._open_save_dialog()
	assert(main.save_dialog.visible and main.save_dialog.current_file == "Original Startup.SC2")
	main.save_dialog.hide()
	main.queue_free()
	await process_frame
	await process_frame


func _test_invalid_startup() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "unknown")
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_root = ProjectSettings.globalize_path("res://../references")
	root.add_child(main)
	await process_frame
	await process_frame
	assert(not main.runtime_initialized)
	assert(main.reference_import_error_dialog.visible)
	assert(main.reference_import_error_dialog.dialog_text.contains("Import the original"))
	assert(main.map_view == null and main.audio_controller == null)
	main.queue_free()
	await process_frame
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
