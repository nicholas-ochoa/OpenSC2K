extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	main.app_settings_path = "user://saved-camera-test.cfg"
	root.add_child(main)
	await process_frame
	main.app_city_renderer = "cpu"
	for target in [Vector2i(25, 91), Vector2i(101, 40)]:
		var document := Sc2File.load_path(ProjectSettings.globalize_path("res://../references/CITIES/ISLAND.SC2"))
		assert(document.set_misc_u32(0x1018, target.x))
		assert(document.set_misc_u32(0x101c, target.y))
		assert(main._activate_document(document))
		var deadline := Time.get_ticks_msec() + 15000
		while main.map_view.pending_loaded_center.x >= 0 and Time.get_ticks_msec() < deadline:
			await process_frame
		assert(main.selected_group == 17 and main.selected_subtool == 0)
		assert(main.map_view.pending_loaded_center.x < 0)
		var actual: Vector2 = main.map_view.source_center
		main.map_view.center_on_tile(target)
		assert(main.map_view.source_center.is_equal_approx(actual))
	main.queue_free()
	await process_frame
	print("PASS: saved city center restored on initial and replacement load; Center tool selected")
	quit()
