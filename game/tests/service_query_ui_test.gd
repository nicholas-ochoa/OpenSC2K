extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	root.add_child(main)
	await process_frame
	var city := CityState.from_document(EmptyCityTemplate.create())
	city.set_funds(1000000)
	for subtool in [0, 1]:
		for x in [30, 40]:
			assert(BuildingCommand.apply(city, 13, subtool, Vector2i(x, 30 + subtool * 10), SimLfsrRandom.new(1), SimRandom.new(1)).ok)
	main.city_session.activate_document(city.document)
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	main.current_tool.select_tool_group(16)
	main.current_tool.select_subtool(2)
	var before: PackedByteArray = main.city.document.serialize().data
	for point in [Vector2i(30, 30), Vector2i(30, 40)]:
		var path: Array[Vector2i] = [point]
		main.map_view._shift_pressed = true
		main.city_edits.apply_map_selection(point, point, path, false)
		assert(main.map_view.service_query.analysis.all_stations)
		assert(main.map_view.service_query.analysis.station_count == 2)
		main.map_view._shift_pressed = false
		main.city_edits.apply_map_selection(point, point, path, false)
		assert(not main.map_view.service_query.analysis.all_stations)
	assert(main.city.document.serialize().data == before)
	main.current_tool.select_subtool(0)
	assert(main.map_view.service_query == null)
	main.current_tool.select_subtool(2)
	main.map_view.show_service_query(main.city, Vector2i(30, 30), true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	main._unhandled_key_input(escape)
	assert(main.map_view.service_query == null)
	main.queue_free()
	await process_frame
	print("PASS: Service Query UI selection, Shift selection, tool switching, Escape and unchanged bytes")
	quit()
