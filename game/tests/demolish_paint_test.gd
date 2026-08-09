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
	var scale := map.camera._view_scale()
	var result := center * scale + map.camera._draw_offset(scale)
	assert(map.camera._tile_at(result) == tile, "Picked %s instead of %s" % [map.camera._tile_at(result), tile])
	return result


func _button(map: CityMapControl, tile: Vector2i, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = _position(map, tile)
	event.pressed = pressed
	event.shift_pressed = shift
	map.interaction._handle_mouse_button(event)


func _motion(map: CityMapControl, tile: Vector2i, shift := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _position(map, tile)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.shift_pressed = shift
	map.interaction._handle_mouse_motion(event)


func _run() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	main.preferences.settings_path = "user://city-demolish-paint-test.cfg"
	root.add_child(main)
	await process_frame
	main.map_view.zoom_factor = 0.25
	for edge in [64, 512]:
		assert(main.city_session.activate_document(EmptyCityTemplate.create(edge)))
		main.frame.select_speed(GameSpeedController.Speed.PAUSED)
		main.document_state.city.set_sound_enabled(false)
		main.current_tool.select_tool_group(0)
		main.current_tool.select_subtool(0)
		var map: CityMapControl = main.map_view
		map.city = main.document_state.city
		assert(map.demolish_brush and map.continuous_placement and not map.landscape_brush)
		var start := Vector2i(edge - 20, edge - 20)
		var buildings: PackedByteArray = main.document_state.current_document.find_chunk("XBLD").decoded_payload.duplicate()
		for x in range(start.x, start.x + 11):
			for y in range(start.y, start.y + 4):
				buildings[main.document_state.city.index_of(x, y)] = 1 # Rubble has no protest branch.
		assert(main.document_state.city.replace_buildings(buildings))
		var before: Array = DocumentState.capture(main.document_state.current_document)
		var rng: int = main.tool_random.state
		_button(map, start, true)
		assert(map.selection.bulldozer_visible())
		assert(main.document_state.city.building_id(start.x, start.y) == 0)
		_motion(map, start + Vector2i(8, 0))
		var cost: int = main.last_edit_command.cost
		map._process(0.5)
		assert(main.last_edit_command.cost == cost, "Holding over an empty tile charged again")
		# Changing Shift mid-stroke keeps the paint tool active.
		_motion(map, start + Vector2i(9, 0), true)
		assert(not map.brush_box_selection and map.selection.bulldozer_visible())
		for zoom in (CityMapControl.ZOOM_LEVELS if edge == 64 else [1.0]):
			map.zoom_factor = zoom
			for direction in 4:
				var visual: Dictionary = main.moving_sprites.demolish_brush_visual(start, direction)
				assert(not visual.is_empty() and visual.texture.get_size().x > 0)
		map.zoom_factor = 0.25
		_button(map, start + Vector2i(10, 0), false)
		assert(not map.selection.bulldozer_visible())
		for x in range(start.x, start.x + 11):
			assert(main.document_state.city.building_id(x, start.y) == 0)
			assert(main.document_state.city.building_id(x, start.y + 1) == 1)
		assert(main.last_edit_command.cost == 11 and main.last_edit_command.action_count == 11)
		assert(DemolishCommand.undo(main.document_state.city, main.last_edit_command, main.tool_random).ok)
		assert(DocumentState.capture(main.document_state.current_document) == before and main.tool_random.state == rng)

		_button(map, start, true, true)
		_motion(map, start + Vector2i(3, 2), true)
		map._process(0.5)
		assert(map.selection_path.size() == 12 and not map.selection.bulldozer_visible())
		assert(DocumentState.capture(main.document_state.current_document) == before)
		_button(map, start + Vector2i(3, 2), false)
		assert(main.last_edit_command.cost == 12 and main.last_edit_command.action_count == 12)
		assert(DemolishCommand.undo(main.document_state.city, main.last_edit_command, main.tool_random).ok)
		assert(DocumentState.capture(main.document_state.current_document) == before and main.tool_random.state == rng)

		_button(map, start, true, true)
		_motion(map, start + Vector2i(3, 2), true)
		assert(map.cancel_active_selection())
		assert(DocumentState.capture(main.document_state.current_document) == before and not map.selection.bulldozer_visible())
		_button(map, start, true)
		_motion(map, start + Vector2i(3, 0))
		assert(map.cancel_active_selection() and not map.selection.bulldozer_visible())
		assert(DemolishCommand.undo(main.document_state.city, main.last_edit_command, main.tool_random).ok)
		assert(DocumentState.capture(main.document_state.current_document) == before and main.tool_random.state == rng)
		# Dust advances the RNG. Keep the first random-state snapshot across later dabs.
		buildings = main.document_state.city.buildings.duplicate()
		buildings[main.document_state.city.index_of(start.x, start.y)] = 0x0d
		buildings[main.document_state.city.index_of(start.x + 2, start.y)] = 0x0d
		assert(main.document_state.city.replace_buildings(buildings))
		before = DocumentState.capture(main.document_state.current_document)
		rng = main.tool_random.state
		_button(map, start, true)
		_motion(map, start + Vector2i(2, 0))
		_button(map, start + Vector2i(2, 0), false)
		assert(main.tool_random.state != rng and main.last_edit_command.cost > 0)
		assert(DemolishCommand.undo(main.document_state.city, main.last_edit_command, main.tool_random).ok)
		assert(DocumentState.capture(main.document_state.current_document) == before and main.tool_random.state == rng)

		# The underground tool uses the same input, without a surface vehicle.
		main.menus.set_overlay(CityViewMode.Mode.UNDERGROUND)
		var underground: PackedByteArray = main.document_state.current_document.find_chunk("XUND").decoded_payload.duplicate()
		for x in range(start.x, start.x + 4):
			underground[main.document_state.city.index_of(x, start.y)] = 0x10
		assert(main.document_state.current_document.find_chunk("XUND").set_decoded_payload(underground))
		before = DocumentState.capture(main.document_state.current_document)
		_button(map, start, true)
		assert(not map.selection.bulldozer_visible())
		_motion(map, start + Vector2i(3, 0))
		_button(map, start + Vector2i(3, 0), false)
		assert(main.last_edit_command.underground_view and main.last_edit_command.cost == 4)
		assert(DemolishCommand.undo(main.document_state.city, main.last_edit_command, main.tool_random).ok)
		assert(DocumentState.capture(main.document_state.current_document) == before and main.tool_random.state == rng)
		main.menus.set_overlay(CityViewMode.Mode.CITY)
		# A protest keeps its tree without a notice or ending the held stroke.
		buildings = main.document_state.city.buildings.duplicate()
		buildings[main.document_state.city.index_of(start.x, start.y)] = 6
		assert(main.document_state.city.replace_buildings(buildings))
		var probe := SimRandom.new()
		for seed in range(1, 1000):
			probe.state = seed
			if probe.next_u15() % 20 == 0:
				main.tool_random.state = seed
				break
		rng = main.tool_random.state
		before = DocumentState.capture(main.document_state.current_document)
		_button(map, start, true)
		assert(map.is_left_drag_active() and main.last_edit_command.easter_events == 1)
		_button(map, start, false)
		assert(not map.selection.bulldozer_visible())
		assert(DemolishCommand.undo(main.document_state.city, main.last_edit_command, main.tool_random).ok)
		assert(DocumentState.capture(main.document_state.current_document) == before and main.tool_random.state == rng)
		print("PASS: Demolish paint, gaps, costs, native sprites, Shift boxes, cancel and exact Undo at ", edge)
	main.queue_free()
	await process_frame
	quit()
