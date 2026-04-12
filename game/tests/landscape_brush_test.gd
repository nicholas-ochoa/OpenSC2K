extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
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
		for corner in [Vector2i.ZERO, Vector2i(edge - 1, edge - 1)]:
			var tiles: Array[Vector2i] = main.map_view.brush_tiles(corner)
			for tile in tiles:
				assert(main.city.index_of(tile.x, tile.y) >= 0)
		print("Brush size, shape, drag gaps, edges and stroke Undo passed: ", edge)
	main.queue_free()
	await process_frame
	quit()
