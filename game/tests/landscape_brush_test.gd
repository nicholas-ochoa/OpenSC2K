extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	await process_frame
	for edge in [128, 256, 384, 512]:
		assert(main._activate_document(EmptyCityTemplate.create(edge)))
		main._enter_landscape_editor()
		main._select_tool_group(1)
		for tool in [0, 1, 3]:
			main._select_subtool(tool)
			for width in [1, 2, 5, 15]:
				for shape in [0, 1]:
					main.city_toolbar.brush_size_input.value = width
					main.city_toolbar.brush_shape_input.select(shape)
					main._update_edit_state()
					var point := Vector2i(edge - 24, edge - 24)
					var before: PackedByteArray = main.current_document.serialize().data
					var rng: int = main.tool_random.state
					main.map_view.selection_start = point
					main.map_view.selection_end = point
					main._on_map_selection_started()
					main.map_view._last_brush_tile = Vector2i(-1, -1)
					main.map_view._emit_brush_dab(point, false)
					main.map_view._emit_brush_dab(point + Vector2i(18, 0), true)
					assert(main.last_edit_command.ok)
					assert(main.city.funds() == 20000)
					if tool != 3:
						for x in range(point.x, point.x + 19):
							assert(main.city.is_water(x, point.y) if tool == 1 else main.city.building_id(x, point.y) in range(6, 13))
					main.map_view._clear_selection()
					assert(LandscapeCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
					assert(main.current_document.serialize().data == before)
					assert(main.tool_random.state == rng)
		_check_level_brush(main, Vector2i(edge - 40, edge - 40))
		for corner in [Vector2i.ZERO, Vector2i(edge - 1, edge - 1)]:
			var tiles: Array[Vector2i] = main.map_view.brush_tiles(corner)
			for tile in tiles:
				assert(main.city.index_of(tile.x, tile.y) >= 0)
		print("Brush size, shape, drag gaps, edges and stroke Undo passed: ", edge)
	main.queue_free()
	await process_frame
	quit()


func _check_level_brush(main: Node, origin: Vector2i) -> void:
	for editor in [true, false]:
		var point := origin + Vector2i(0, 0 if editor else 10)
		main.landscape_editor = editor
		main.city_toolbar.set_landscape_editor(editor)
		main._select_tool_group(0)
		main._select_subtool(2)
		for bump in [point + Vector2i(10, 0), point + Vector2i(10, 1)]:
			for step in 3:
				assert(TerrainCommand.apply_path(main.city, 0, 2, bump, [bump], main.tool_random, true).ok)
		main._select_subtool(1)
		main._update_edit_state()
		var width := 5 if editor else 1
		assert(main.map_view.landscape_brush and main.map_view.brush_size == width and main.map_view.brush_round)
		assert(not main.city_toolbar.brush_controls.visible)
		assert(main.map_view.brush_tiles(point).size() == (21 if editor else 1))
		var target: int = main.city.land_altitude(point.x, point.y)
		var funds: int = main.city.funds()
		var before: PackedByteArray = main.current_document.serialize().data
		var rng: int = main.tool_random.state
		main.map_view.selection_start = point
		main.map_view.selection_end = point
		main._on_map_selection_started()
		main.map_view._last_brush_tile = Vector2i(-1, -1)
		main.map_view._emit_brush_dab(point, false)
		main.map_view._emit_brush_dab(point + Vector2i(18, 0), true)
		assert(main.last_edit_command.ok and main.last_edit_command.command_type == "terrain")
		assert(main.city.funds() == funds if editor else main.city.funds() < funds)
		var rows := [-1, 0, 1] if editor else [0]
		for x in range(point.x, point.x + 19):
			for dy in rows:
				assert(main.city.land_altitude(x, point.y + dy) == target)
		main.map_view._clear_selection()
		assert(TerrainCommand.undo(main.city, main.last_edit_command, main.tool_random).ok)
		assert(main.current_document.serialize().data == before)
		assert(main.tool_random.state == rng)
	main.landscape_editor = true
	main.city_toolbar.set_landscape_editor(true)
	main._select_tool_group(1)
