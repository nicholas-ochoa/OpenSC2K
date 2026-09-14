extends SceneTree
## A real Mac demo pack supplies the city without any Windows base files.

const CORPUS := "res://../references/all-versions"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var temporary := ProjectSettings.globalize_path("res://../local/sc2-import-standalone-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var probes: Array = JSON.parse_string(FileAccess.get_file_as_string(CORPUS.path_join("analysis/lineage/binary-probes.json")))
	var path := ""

	for probe: Dictionary in probes:
		if probe.name == "macintosh/demo-1.0":
			path = CORPUS.path_join(probe.path)

	assert(not path.is_empty())
	var source_hash := FileAccess.get_sha256(path)
	var imported := Sc2MediaImporter.import_assets(path, temporary.path_join("packs"))
	assert(imported.ok and imported.partial and not imported.graphics.is_empty(), imported.summary())
	assert(not imported.sound.is_empty() and not imported.music.is_empty(), imported.summary())
	assert(AppSettingsStore.save_values(0.0, 0.0, false, temporary.path_join("settings.cfg"), "folder", imported.graphics,
		"", "gpu", false, [], false, imported.sound, imported.music) == OK)
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", "")
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	main.preferences.settings_path = temporary.path_join("settings.cfg")
	main.asset_state.reference_root = temporary.path_join("no-windows-base")
	root.add_child(main)
	await process_frame
	main.main_menu.city_background.set_process(false)
	assert(main.asset_state.assets_ready and main.asset_state.asset_source.uses_graphics_pack)
	assert(not main.asset_state.asset_source.use_original_data and not main.audio_controller.original_media_enabled)
	assert(main.new_city_state.session.independent_template)
	assert(main.asset_state.reference_root == imported.graphics.get_base_dir())
	assert(main.asset_state.asset_source.assets.toolbar_art == null)
	assert(main.original_text_resources.newspaper_data == null)
	assert(main.audio_controller.sound_pack.files.size() > 0 and main.audio_controller.music_pack.files.size() > 0)
	assert(not main.main_menu.import_button.visible)
	main.new_city.open_new_city_dialog()
	assert(main.new_city_dialog.visible)
	main.new_city_dialog.city_name_input.text = "Mac Pack City"
	main.new_city_dialog.native_maps_input.button_pressed = false
	main.new_city_dialog.hills_input.value = 0
	main.new_city_dialog.water_input.value = 0
	main.new_city_dialog.trees_input.value = 0
	main.new_city_dialog.river_input.button_pressed = false
	main.new_city_dialog.ocean_input.button_pressed = false
	main.new_city.make_new_city_preview()

	while main.new_city_state.preview_job != null:
		await process_frame

	main.new_city.create_new_city_unchecked()
	assert(main.document_state.city != null and main.document_state.city.city_name() == "Mac Pack City")
	main.new_city.start_city()
	assert(main.newspaper_dialog.visible)
	main.newspaper_dialog.hide()
	main.simulation_state.speed_controller.set_speed(GameSpeedController.Speed.PAUSED)
	var encoded := main.document_state.current_document.serialize()
	assert(encoded.ok)
	var reopened := Sc2File.new()
	assert(reopened.parse(encoded.data) and reopened.serialize().data == encoded.data)
	assert(main.simulation_state.simulation_engine.advance_day().ok)
	main.scurk_workspace.open_scurk_dialog()
	assert(main.scurk_editor.visible and main.scurk_editor.tile_set != null)
	assert(not main.scurk_editor.pixel_canvas.original_textures_loaded)
	assert(not main.scurk_editor.pixel_canvas.texture_patterns.is_empty())
	assert(main.scurk_editor.pixel_canvas.clear_background_pixels.is_empty())
	# Reset removes an earlier pack's drawing background rather than retaining it.
	main.scurk_editor.pixel_canvas.clear_background_pixels = PackedInt32Array([23])
	main.scurk_editor.pixel_canvas.set_drawing_graphics(null)
	assert(main.scurk_editor.pixel_canvas.clear_background_pixels.is_empty())
	main.scurk_editor.hide()
	main.scurk_workspace.open_scurk_place_print()
	assert(main.scurk_place_print.visible)
	main.scurk_place_print.hide()
	# Check the same template and media behavior on activation and cold startup.
	main.new_city_state.session.independent_template = false
	main.audio_controller.original_media_enabled = true
	var selected := GameAssetSource.load_source("", "folder", imported.graphics)
	assert(selected.error.is_empty())
	main.assets.apply_graphics_source(selected)
	assert(main.new_city_state.session.independent_template and not main.audio_controller.original_media_enabled)
	main.queue_free()
	await process_frame
	await process_frame
	assert(FileAccess.get_sha256(path) == source_hash)
	assert(OriginalGameInstaller.remove_tree(temporary) == OK)
	print("PASS: standalone Mac demo import, cold startup, generated New City, newspaper fallback, save round trip, simulation, SCURK and live activation")
	quit()
