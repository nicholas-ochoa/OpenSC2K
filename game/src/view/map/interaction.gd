class_name CityMapInteraction
extends CityMapConstants

var map: CityMapControl
var _stretch_press_y := 0.0
var shift_pressed := false
var _brush_elapsed := 0.0
var panning := false
var _click_button := MOUSE_BUTTON_NONE
var _click_action := ""
var _press_position := Vector2.ZERO
var _pan_button := MOUSE_BUTTON_NONE


func _init(control: CityMapControl) -> void:
	map = control


func _gui_input(event: InputEvent) -> void:
	if not map.data_view_mode == CityViewMode.Mode.NONE and event is InputEventMouseMotion:
		map.queue_redraw()

	if map.city_source == null:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		shift_pressed = event.pressed

		if map.stretch_terrain and map.selection_start.x >= 0:
			map.stretch_changed.emit(map.stretch_height_delta, event.pressed)

		if (map.shift_rectangle_enabled or map.shift_line_enabled) and map.selection_start.x >= 0:
			map.selection._rebuild_selection_path()
			map.selection_changed.emit(map.selection_start, map.selection_end, map.selection_path.duplicate(), map.selection_moved)

		map.queue_redraw()


func _process(delta: float) -> void:
	if not map.continuous_placement or map.brush_box_selection or not map.edit_enabled or map.selection_start.x < 0:
		_brush_elapsed = 0.0

		return

	_brush_elapsed += delta

	if _brush_elapsed < (0.1 if map.selection.uses_paint_brush() else 0.3):
		return

	_brush_elapsed = 0.0

	if map.hover_tile.x >= 0:
		map.selection._emit_brush_dab(map.hover_tile, true)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and map.selection.cancel_active_selection():
		panning = false
		_click_button = MOUSE_BUTTON_NONE
		map.accept_event()

		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		_handle_bound_button(event)

		return

	if not map.edit_enabled:
		return

	var tile := map.camera._tile_at(event.position)
	shift_pressed = event.shift_pressed

	if event.pressed:
		shift_pressed = event.shift_pressed

		if map.shift_query_enabled and not map.shift_rectangle_enabled and not map.shift_line_enabled and event.shift_pressed:
			if tile.x >= 0:
				map.hover_tile = tile
				map.query_requested.emit(tile)

			map.accept_event()

			return

		map.selection._show_placement_error(event.position)

		if tile.x >= 0:
			map.hover_tile = tile
			_stretch_press_y = event.position.y
			map.stretch_height_delta = 0
			map.brush_box_selection = map.selection.uses_paint_brush() and map.shift_rectangle_enabled and event.shift_pressed
			map.selection_start = tile
			map.selection_end = tile
			map.selection_moved = false
			map.selection._rebuild_selection_path()
			map.selection_started.emit()
			_brush_elapsed = 0.0
			map.selection.last_brush_tile = Vector2i(-1, -1)

			if map.continuous_placement and not map.brush_box_selection:
				map.selection._emit_brush_dab(tile, false)

			map.selection_changed.emit(
				map.selection_start, map.selection_end, map.selection_path.duplicate(), false
			)
			map.queue_redraw()

			if map.repeat_placement:
				map.selection._emit_repeat_placement(tile, false)
	else:
		if map.selection_start.x >= 0:
			if tile.x >= 0 and tile != map.selection_end:
				map.selection_end = tile
				map.selection_moved = true
				map.selection._rebuild_selection_path()

			if map.stretch_terrain:
				map.selection_end = map.selection_start
				map.selection_path.assign([map.selection_start])
				map.stretch_height_delta = roundi((_stretch_press_y - event.position.y) / 12.0)
				map.selection_moved = map.selection_moved or absf(_stretch_press_y - event.position.y) >= 6.0

			if map.selection.uses_paint_brush() and not map.brush_box_selection and tile.x >= 0 and tile != map.selection.last_brush_tile:
				map.selection._emit_brush_dab(tile, true)

			var placed_while_held := (
				(map.continuous_placement or map.repeat_placement) and not map.brush_box_selection
			)

			if not placed_while_held:
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


# Buttons other than the left button run the actions that the player binds to
# them. A button bound to map_pan moves the map on a drag, and runs its other
# action on a click that moves 4 pixels or less.
func _handle_bound_button(event: InputEventMouseButton) -> void:
	var bindings := map.control_bindings
	var action := bindings.action_for(event, [ControlActions.KIND_PRESS, ControlActions.KIND_HOLD, ControlActions.KIND_CLICK])
	var pans := bindings.for_action("map_pan").any(func(binding: ControlBinding) -> bool: return binding.matches(event))
	var wheel := event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT,
		MOUSE_BUTTON_WHEEL_RIGHT]

	if wheel:
		if event.pressed and not action.is_empty():
			_run_button_action(action, event.position, true)
			map.accept_event()

		return

	var hold := not action.is_empty() and ControlActions.find(action).kind == ControlActions.KIND_HOLD

	if hold:
		map.control_hold_changed.emit(action, event.button_index, event.pressed)
		map.accept_event()

		return

	if not event.pressed:
		if _click_button == event.button_index:
			if not _click_action.is_empty() and event.position.distance_to(_press_position) <= 4.0:
				_run_button_action(_click_action, event.position, false)

			_click_button = MOUSE_BUTTON_NONE

		if _pan_button == event.button_index:
			panning = false
			_pan_button = MOUSE_BUTTON_NONE

		map.accept_event()

		return

	if action.is_empty() and not pans:
		return

	var clicks := not action.is_empty() and (pans or ControlActions.find(action).kind == ControlActions.KIND_CLICK)

	if not action.is_empty() and not clicks:
		_run_button_action(action, event.position, false)

	_click_button = event.button_index if clicks else MOUSE_BUTTON_NONE
	_click_action = action
	_press_position = event.position

	if pans:
		panning = true
		_pan_button = event.button_index

	map.accept_event()


func _run_button_action(action: String, position: Vector2, wheel: bool) -> void:
	match action:
		"zoom_in":
			if wheel:
				map.camera.wheel_zoom(1, position)
			else:
				map.camera.zoom_in(position)
		"zoom_out":
			if wheel:
				map.camera.wheel_zoom(-1, position)
			else:
				map.camera.zoom_out(position)
		"map_context_menu", "map_center_on_tile":
			var tile := map.camera._tile_at(position)

			if tile.x < 0:
				return

			if action == "map_context_menu":
				map.context_menu.open_at(tile, position)
			else:
				map.center_requested.emit(tile)
		_:
			map.control_action_requested.emit(action)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	map.selection._hide_placement_error()

	if shift_pressed != event.shift_pressed:
		shift_pressed = event.shift_pressed
		map.selection._rebuild_selection_path()
		map.queue_redraw()

	# a dialog that opens during a drag can take the release
	if panning and (event.button_mask & (1 << (_pan_button - 1))) == 0:
		panning = false
		_pan_button = MOUSE_BUTTON_NONE
		_click_button = MOUSE_BUTTON_NONE

	if panning:
		if event.position.distance_to(_press_position) > 4.0:
			_click_button = MOUSE_BUTTON_NONE

		map.source_center -= event.relative / map.camera._view_scale()
		map.camera._clamp_source_center()
		map.layers._sync_base_layer()
		map.queue_redraw()
		map.viewport_changed.emit()
		map.accept_event()

		return

	if map.stretch_terrain and map.selection_start.x >= 0:
		map.stretch_height_delta = roundi((_stretch_press_y - event.position.y) / 12.0)
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
		# a dialog that opens during a repeated placement can take the release
		if map.repeat_placement and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			map.selection._end_held_placement()
			map.accept_event()

			return

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

			if map.repeat_placement:
				map.selection._emit_repeat_placement(tile, true)

		map.accept_event()
