extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _position(map: CityMapControl, tile: Vector2i) -> Vector2:
	var polygon := CityIsometricRenderer.tile_polygon(map.city, tile.x, tile.y)
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	center /= float(polygon.size())
	var scale := map._view_scale()
	var result := center * scale + map._draw_offset(scale)
	assert(map._tile_at(result) == tile, "Picked %s instead of %s" % [map._tile_at(result), tile])
	return result


func _button(map: CityMapControl, tile: Vector2i, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = _position(map, tile)
	event.pressed = pressed
	event.shift_pressed = shift
	map._handle_mouse_button(event)


func _motion(map: CityMapControl, tile: Vector2i, shift := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _position(map, tile)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.shift_pressed = shift
	map._handle_mouse_motion(event)


func _run() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	main.app_settings_path = "user://city-demolish-paint-test.cfg"
	root.add_child(main)
	await process_frame
	for edge in [128, 256, 384, 512]:
		assert(main._activate_document(EmptyCityTemplate.create(edge)))
		main._select_speed(GameSpeedController.Speed.PAUSED)
		main.city.set_sound_enabled(false)
		main._select_tool_group(0)
		main._select_subtool(0)
		var map: CityMapControl = main.map_view
		map.city = main.city
		assert(map.demolish_brush and map.continuous_placement and not map.landscape_brush)
		var start := Vector2i(edge - 20, edge - 20)
		var buildings: PackedByteArray = main.current_document.find_chunk("XBLD").decoded_payload.duplicate()
		for x in range(start.x, start.x + 11):
			for y in range(start.y, start.y + 4):
				buildings[main.city.index_of(x, y)] = 1 # Rubble has no protest branch.
		assert(main.city.replace_buildings(buildings))
		var before: PackedByteArray = main.current_document.serialize().data
		var rng: int = main.tool_random.state
		_button(map, start, true)
		assert(map.bulldozer_visible())
		assert(main.city.building_id(start.x, start.y) == 0)
		_motion(map, start + Vector2i(8, 0))
		var cost: int = main.last_edit_command.cost
		map._process(0.5)
		assert(main.last_edit_command.cost == cost, "Holding over an empty tile charged again")
		# Changing Shift mid-stroke keeps the paint tool active.
		_motion(map, start + Vector2i(9, 0), true)
		assert(not map.brush_box_selection and map.bulldozer_visible())
		for zoom in CityMapControl.ZOOM_LEVELS:
			map.zoom_factor = zoom
			for direction in 4:
				var visual: Dictionary = main._demolish_brush_visual(start, direction)
				assert(not visual.is_empty() and visual.texture.get_size().x > 0)
		map.zoom_factor = 1.0
		_button(map, start + Vector2i(10, 0), false)
		assert(not map.bulldozer_visible())
		for x in range(start.x, start.x + 11):
			assert(main.city.building_id(x, start.y) == 0)
			assert(main.city.building_id(x, start.y + 1) == 1)
		assert(main.last_edit_command.cost == 11 and main.last_edit_command.action_count == 11)
		assert(DemolishCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
		assert(main.current_document.serialize().data == before and main.tool_random.state == rng)

		_button(map, start, true, true)
		_motion(map, start + Vector2i(3, 2), true)
		map._process(0.5)
		assert(map.selection_path.size() == 12 and not map.bulldozer_visible())
		assert(main.current_document.serialize().data == before)
		_button(map, start + Vector2i(3, 2), false)
		assert(main.last_edit_command.cost == 12 and main.last_edit_command.action_count == 12)
		assert(DemolishCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
		assert(main.current_document.serialize().data == before and main.tool_random.state == rng)

		_button(map, start, true, true)
		_motion(map, start + Vector2i(3, 2), true)
		assert(map.cancel_active_selection())
		assert(main.current_document.serialize().data == before and not map.bulldozer_visible())
		_button(map, start, true)
		_motion(map, start + Vector2i(3, 0))
		assert(map.cancel_active_selection() and not map.bulldozer_visible())
		assert(DemolishCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
		assert(main.current_document.serialize().data == before and main.tool_random.state == rng)
		# Dust advances the RNG. Keep the first random-state snapshot across later dabs.
		buildings = main.city.buildings.duplicate()
		buildings[main.city.index_of(start.x, start.y)] = 0x0d
		buildings[main.city.index_of(start.x + 2, start.y)] = 0x0d
		assert(main.city.replace_buildings(buildings))
		before = main.current_document.serialize().data
		rng = main.tool_random.state
		_button(map, start, true)
		_motion(map, start + Vector2i(2, 0))
		_button(map, start + Vector2i(2, 0), false)
		assert(main.tool_random.state != rng and main.last_edit_command.cost > 0)
		assert(DemolishCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
		assert(main.current_document.serialize().data == before and main.tool_random.state == rng)

		# The underground tool uses the same input, without a surface vehicle.
		main._set_overlay("underground")
		var underground: PackedByteArray = main.current_document.find_chunk("XUND").decoded_payload.duplicate()
		for x in range(start.x, start.x + 4):
			underground[main.city.index_of(x, start.y)] = 0x10
		assert(main.current_document.find_chunk("XUND").set_decoded_payload(underground))
		before = main.current_document.serialize().data
		_button(map, start, true)
		assert(not map.bulldozer_visible())
		_motion(map, start + Vector2i(3, 0))
		_button(map, start + Vector2i(3, 0), false)
		assert(main.last_edit_command.underground_view and main.last_edit_command.cost == 4)
		assert(DemolishCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
		assert(main.current_document.serialize().data == before and main.tool_random.state == rng)
		main._set_overlay("city")
		# A protest keeps its tree without a notice or ending the held stroke.
		buildings = main.city.buildings.duplicate()
		buildings[main.city.index_of(start.x, start.y)] = 6
		assert(main.city.replace_buildings(buildings))
		var probe := SimRandom.new()
		for seed in range(1, 1000):
			probe.state = seed
			if probe.next_u15() % 20 == 0:
				main.tool_random.state = seed
				break
		rng = main.tool_random.state
		before = main.current_document.serialize().data
		_button(map, start, true)
		assert(map.is_left_drag_active() and main.last_edit_command.easter_events == 1)
		_button(map, start, false)
		assert(not map.bulldozer_visible())
		assert(DemolishCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
		assert(main.current_document.serialize().data == before and main.tool_random.state == rng)
		print("PASS: Demolish paint, gaps, costs, native sprites, Shift boxes, cancel and exact Undo at ", edge)
	main.queue_free()
	await process_frame
	quit()
