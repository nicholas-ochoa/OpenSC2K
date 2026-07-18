class_name CityMapInteraction
extends CityMapConstants


var map: CityMapControl


func _init(control: CityMapControl) -> void:
	map = control


func _gui_input(event: InputEvent) -> void:
	if not map.data_view_mode.is_empty() and event is InputEventMouseMotion:
		map.queue_redraw()

	if map.city_source == null:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		map.camera.wheel_zoom(1, event.position)
		map.accept_event()

		return

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		map.camera.wheel_zoom(-1, event.position)
		map.accept_event()

		return

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and map.selection.cancel_active_selection():
		map._panning = false
		map.accept_event()

		return

	if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				map._middle_click_pending = true
				map._middle_press_position = event.position
			elif map._middle_click_pending:
				var tile := map.camera._tile_at(event.position)

				if tile.x >= 0 and event.position.distance_to(map._middle_press_position) <= 4.0:
					map.center_requested.emit(tile)

				map._middle_click_pending = false
		else:
			map._middle_click_pending = false

		map._panning = event.pressed
		map.accept_event()

		return

	if event.button_index != MOUSE_BUTTON_LEFT or not map.edit_enabled:
		return

	var tile := map.camera._tile_at(event.position)
	map._shift_pressed = event.shift_pressed

	if event.pressed:
		map._shift_pressed = event.shift_pressed

		if map.shift_query_enabled and not map.shift_rectangle_enabled and not map.shift_line_enabled and event.shift_pressed:
			if tile.x >= 0:
				map.hover_tile = tile
				map.query_requested.emit(tile)

			map.accept_event()

			return

		map.selection._show_placement_error(event.position)

		if tile.x >= 0:
			map.hover_tile = tile
			map._stretch_press_y = event.position.y
			map.stretch_height_delta = 0
			map.brush_box_selection = map.selection.uses_paint_brush() and map.shift_rectangle_enabled and event.shift_pressed
			map.selection_start = tile
			map.selection_end = tile
			map.selection_moved = false
			map.selection._rebuild_selection_path()
			map.selection_started.emit()
			map._brush_elapsed = 0.0
			map._last_brush_tile = Vector2i(-1, -1)

			if map.continuous_placement and not map.brush_box_selection:
				map.selection._emit_brush_dab(tile, false)

			map.selection_changed.emit(
				map.selection_start, map.selection_end, map.selection_path.duplicate(), false
			)
			map.queue_redraw()
	else:
		if map.selection_start.x >= 0:
			if tile.x >= 0 and tile != map.selection_end:
				map.selection_end = tile
				map.selection_moved = true
				map.selection._rebuild_selection_path()

			if map.stretch_terrain:
				map.selection_end = map.selection_start
				map.selection_path.assign([map.selection_start])
				map.stretch_height_delta = roundi((map._stretch_press_y - event.position.y) / 12.0)
				map.selection_moved = map.selection_moved or absf(map._stretch_press_y - event.position.y) >= 6.0

			if map.selection.uses_paint_brush() and not map.brush_box_selection and tile.x >= 0 and tile != map._last_brush_tile:
				map.selection._emit_brush_dab(tile, true)

			if not map.continuous_placement or map.brush_box_selection:
				map.selection_completed.emit(
					map.selection_start,
					map.selection_end,
					map.selection_path.duplicate(),
					map.selection_moved,
				)

			map.selection._clear_selection()
			map.queue_redraw()
			map.selection_finished.emit()

	map.accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	map.selection._hide_placement_error()

	if map._shift_pressed != event.shift_pressed:
		map._shift_pressed = event.shift_pressed
		map.selection._rebuild_selection_path()
		map.queue_redraw()

	if (
		map._panning
		and (
			event.button_mask
			& (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT)
		) == 0
	):
		map._panning = false
		map._middle_click_pending = false

	if map._panning:
		if event.position.distance_to(map._middle_press_position) > 4.0:
			map._middle_click_pending = false

		map.source_center -= event.relative / map.camera._view_scale()
		map.camera._clamp_source_center()
		map.layers._sync_base_layer()
		map.queue_redraw()
		map.viewport_changed.emit()
		map.accept_event()

		return

	if map.stretch_terrain and map.selection_start.x >= 0:
		map.stretch_height_delta = roundi((map._stretch_press_y - event.position.y) / 12.0)
		map.hover_tile = map.selection_start
		map.selection_moved = map.selection_moved or map.stretch_height_delta != 0
		map.stretch_changed.emit(map.stretch_height_delta, event.shift_pressed)
		map.queue_redraw()
		map.accept_event()

		return

	var tile := map.camera._tile_at(event.position)

	if tile != map.hover_tile:
		map.hover_tile = tile
		map.queue_redraw()

	if map.edit_enabled and map.selection_start.x >= 0:
		if tile.x >= 0 and tile != map.selection_end:
			map.selection_end = tile
			map.selection_moved = true
			map.selection._rebuild_selection_path()
			if map.selection.uses_paint_brush() and not map.brush_box_selection:
				map.selection._emit_brush_dab(tile, true)
			map.selection_changed.emit(
				map.selection_start,
				map.selection_end,
				map.selection_path.duplicate(),
				true,
			)
			map.queue_redraw()

		map.accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		map._shift_pressed = event.pressed

		if map.stretch_terrain and map.selection_start.x >= 0:
			map.stretch_changed.emit(map.stretch_height_delta, event.pressed)

		if (map.shift_rectangle_enabled or map.shift_line_enabled) and map.selection_start.x >= 0:
			map.selection._rebuild_selection_path()
			map.selection_changed.emit(map.selection_start, map.selection_end, map.selection_path.duplicate(), map.selection_moved)

		map.queue_redraw()


func _process(delta: float) -> void:
	if not map.continuous_placement or map.brush_box_selection or not map.edit_enabled or map.selection_start.x < 0:
		map._brush_elapsed = 0.0

		return

	map._brush_elapsed += delta

	if map._brush_elapsed < (0.1 if map.selection.uses_paint_brush() else 0.3):
		return

	map._brush_elapsed = 0.0

	if map.hover_tile.x >= 0:
		map.selection._emit_brush_dab(map.hover_tile, true)
