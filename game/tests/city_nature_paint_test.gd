extends SceneTree
const DocumentState = preload("res://tests/support/document_state.gd")


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
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	main.app_settings_path = "user://city-nature-paint-test.cfg"
	root.add_child(main)
	await process_frame
	main.map_view.zoom_factor = 0.25
	for edge in [128, 512]:
		assert(main._activate_document(EmptyCityTemplate.create(edge)))
		main._select_speed(GameSpeedController.Speed.PAUSED)
		main._select_tool_group(1)
		# City brushes use fixed settings, independent of landscape preferences.
		main.city_toolbar.brush_size_input.value = 15
		main.city_toolbar.brush_shape_input.select(0)
		for tool in [0, 1, 3]:
			main._select_subtool(tool)
			var map: CityMapControl = main.map_view
			map.city = main.city
			assert(not main.landscape_editor and map.landscape_brush)
			assert(not main.city_toolbar.brush_controls.visible)
			assert(map.brush_size == (7 if tool == 3 else 1))
			assert(map.brush_round and not map.shift_line_enabled)
			var start := Vector2i(edge - 30, edge - 30)
			var before: Array = DocumentState.capture(main.current_document)
			var rng: int = main.tool_random.state
			_button(map, start, true)
			_motion(map, start + Vector2i(8, 0))
			_button(map, start + Vector2i(10, 0), false)
			assert(main.last_edit_command.ok and not main.last_edit_command.free_mode)
			assert(main.last_edit_command.cost == 20000 - main.city.funds())
			assert(main.last_edit_command.cost > 0)
			if tool != 3:
				for x in range(start.x, start.x + 11):
					assert(main.city.is_water(x, start.y) if tool == 1 else main.city.building_id(x, start.y) in range(6, 13))
			assert(LandscapeCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
			assert(DocumentState.capture(main.current_document) == before and main.tool_random.state == rng)

			_button(map, start, true, true)
			_motion(map, start + Vector2i(3, 2), true)
			map._process(0.5)
			assert(map.selection_path.size() == 12)
			assert(DocumentState.capture(main.current_document) == before)
			# Releasing Shift mid-drag keeps the box tool active.
			_button(map, start + Vector2i(3, 2), false)
			assert(main.last_edit_command.ok and main.last_edit_command.cost > 0)
			if tool != 3:
				assert(main.last_edit_command.tile_indices.size() == 12)
			assert(LandscapeCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
			assert(DocumentState.capture(main.current_document) == before and main.tool_random.state == rng)

			_button(map, start, true, true)
			_motion(map, start + Vector2i(3, 2), true)
			assert(map.cancel_active_selection())
			assert(DocumentState.capture(main.current_document) == before)
		print("PASS: city painting, fixed brushes, costs, Shift boxes, cancel and exact Undo at ", edge)
	main.free()
	quit()
