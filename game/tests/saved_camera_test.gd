extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	OS.set_environment("OPENSC2K_DATA_PACK", ProjectSettings.globalize_path("res://../ext/data"))
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	main.asset_state.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	main.preferences.settings_path = "user://saved-camera-test.cfg"
	root.add_child(main)
	await process_frame
	main.map_view.zoom_factor = 0.25
	main.preferences.city_renderer = "cpu"

	for target in [Vector2i(25, 91), Vector2i(101, 40)]:
		var document := Sc2File.load_path(ProjectSettings.globalize_path("res://../references/SIMCITY2000/CITIES/ISLAND.SC2"))
		assert(document.set_misc_u32(0x1018, target.x))
		assert(document.set_misc_u32(0x101c, target.y))
		assert(main.city_session.activate_document(document))
		var deadline := Time.get_ticks_msec() + 15000

		while main.map_view.pending_loaded_center.x >= 0 and Time.get_ticks_msec() < deadline:
			await process_frame

		assert(main.tool_state.selected_group == 17 and main.tool_state.selected_subtool == 0)
		assert(main.map_view.pending_loaded_center.x < 0)
		var actual: Vector2 = main.map_view.source_center
		main.map_view.center_on_tile(target)
		assert(main.map_view.source_center.is_equal_approx(actual))

	main.queue_free()
	await process_frame
	print("PASS: saved city center restored on initial and replacement load; Center tool selected")
	quit()
