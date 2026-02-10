extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	check(main.new_city_dialog.native_maps_input.button_pressed, "New City defaults to per-tile maps")
	check(main._new_city_terrain_options().native_maps, "New City passes native option")
	main.new_city_dialog.native_maps_input.button_pressed = false
	check(not main._new_city_terrain_options().native_maps, "Original grid option remains available")
	main.new_city_session.independent_template = true
	var options := {"size": 128, "native_maps": true, "ocean": false, "river": false,
		"hills": 0, "water": 0, "trees": 0}
	main.new_city_session.begin(123, 456)
	var preview: Dictionary = main.new_city_session.generate_preview("", options, false)
	check(preview.ok and preview.document.full_resolution_maps(), "Native preview mode")
	var created: Dictionary = main.new_city_session.create_city("", "Native", "Mayor", 1, 1900, options, PackedByteArray())
	check(created.ok and created.document.full_resolution_maps(), "Native new city mode")
	check(created.document.find_chunk("ALTM").decoded_payload == preview.document.find_chunk("ALTM").decoded_payload,
		"Native preview and created terrain match")
	main.app_zoom_graphics = AppSettingsStore.normalize_zoom_graphics([0, 1, 2, 2, 2, 2])
	main.map_view.zoom_factor = 0.25
	main.overlay_mode = "underground"
	var document := EmptyCityTemplate.create(128)
	check(main._activate_document(document), "Activate original city")
	var engine_id: int = main.simulation_engine.get_instance_id()
	var random_state: int = main.simulation_engine.random.state
	var old_bytes: PackedByteArray = document.serialize().data
	main.current_save_path = "user://source-city.SC2"
	main.last_edit_command = {"kind": "old-format-undo"}
	main._on_file_menu(CityMenuBar.MENU_NATIVE_DATA_MAPS)
	check(document.full_resolution_maps(), "File menu converts data maps")
	check(main.current_save_path.is_empty(), "Conversion requires a separate save path")
	check(main.last_edit_command.is_empty(), "Old-format undo is cleared")
	check(main.simulation_engine.get_instance_id() == engine_id and main.simulation_engine.random.state == random_state,
		"Conversion keeps simulation and RNG state")
	check(main.frame_simulation != null, "Native 128 city uses sliced worker")
	check(main.save_dialog.visible and main.save_dialog.current_file.ends_with(".sc2x"), "Conversion opens SC2X Save As")
	check(document.serialize().data != old_bytes and main._city_has_unsaved_changes(), "Conversion is an unsaved change")
	main.save_dialog.hide()
	var saved_path: String = main.current_save_path
	main._enable_native_data_maps()
	check(main.current_save_path == saved_path and not main.save_dialog.visible, "Repeated conversion is harmless")
	main.queue_free()
	await process_frame
	print("Native data-map UI: %d failures" % failures)
	quit(1 if failures else 0)
