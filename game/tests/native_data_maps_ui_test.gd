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
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("user://missing-test-art"))
	main.reference_root = ProjectSettings.globalize_path("user://missing-test-originals")
	root.add_child(main)
	await process_frame
	check(main.new_city_dialog.native_maps_input.button_pressed, "New City defaults to per-tile maps")
	check(main.new_city._new_city_terrain_options().native_maps, "New City passes native option")
	main.new_city_dialog.native_maps_input.button_pressed = false
	check(not main.new_city._new_city_terrain_options().native_maps, "Original grid option remains available")
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
	main.preferences.zoom_graphics = AppSettingsStore.normalize_zoom_graphics([0, 1, 2, 2, 2, 2])
	main.map_view.zoom_factor = 0.25
	main.overlay_mode = "underground"
	var document := EmptyCityTemplate.create(128)
	check(main.city_session._activate_document(document), "Activate original city")
	var engine_id: int = main.simulation_engine.get_instance_id()
	var random_state: int = main.simulation_engine.random.state
	var old_bytes: PackedByteArray = document.serialize().data
	main.current_save_path = "user://source-city.SC2"
	main.city_files._sync_upgrade_city_option()
	check(main.options_menu.get_popup().get_item_index(CityMenuBar.MENU_UPGRADE_SC2X) >= 0, "Original SC2 shows upgrade in Options")
	main.preferences.original_compatibility = true
	main.settings._apply_compatibility_controls()
	check(main.options_menu.get_popup().get_item_index(CityMenuBar.MENU_UPGRADE_SC2X) < 0, "Compatibility preference hides upgrade")
	main.preferences.original_compatibility = false
	main.settings._apply_compatibility_controls()
	main.last_edit_command = {"kind": "old-format-undo"}
	main.menus._on_options_menu(CityMenuBar.MENU_UPGRADE_SC2X)
	check(main.sc2x_conversion_dialog.visible and document.serialize().data == old_bytes, "Warning appears before irreversible conversion")
	main.sc2x_conversion_dialog.canceled.emit()
	main.sc2x_conversion_dialog.hide()
	check(document.serialize().data == old_bytes and main.current_save_path == "user://source-city.SC2", "Cancel retains original city and path")
	main.menus._on_options_menu(CityMenuBar.MENU_UPGRADE_SC2X)
	main.sc2x_conversion_dialog.hide()
	main.sc2x_conversion_dialog.confirmed.emit()
	check(document.full_resolution_maps(), "Options upgrades city after confirmation")
	check(main.options_menu.get_popup().get_item_index(CityMenuBar.MENU_UPGRADE_SC2X) < 0, "SC2X hides upgrade")
	check(main.current_save_path.is_empty(), "Conversion requires a separate save path")
	check(main.last_edit_command.is_empty(), "Old-format undo is cleared")
	check(main.simulation_engine.get_instance_id() == engine_id and main.simulation_engine.random.state == random_state,
		"Conversion keeps simulation and RNG state")
	check(main.frame_simulation != null, "Native 128 city uses sliced worker")
	check(main.save_dialog.visible and main.save_dialog.current_file.ends_with(".sc2x"), "Conversion opens SC2X Save As")
	check(document.serialize().data != old_bytes and main.city_files._city_has_unsaved_changes(), "Conversion is an unsaved change")
	main.save_dialog.hide()
	var saved_path: String = main.current_save_path
	main.city_files._upgrade_city_to_sc2x()
	check(main.current_save_path == saved_path and not main.save_dialog.visible, "Repeated conversion is harmless")
	var second := EmptyCityTemplate.create(128)
	check(main.city_session._activate_document(second), "Activate another original city")
	main.current_save_path = "user://second-city.SC2"
	main.preferences.warn_sc2x_conversion = false
	main.city_files._upgrade_city_to_sc2x()
	check(second.is_extended() and not main.sc2x_conversion_dialog.visible, "Disabled warning permits direct conversion")
	main.save_dialog.hide()
	main.queue_free()
	await process_frame
	print("Native data-map UI: %d failures" % failures)
	quit(1 if failures else 0)
