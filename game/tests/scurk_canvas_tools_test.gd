extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_selection_masks()
	var canvas := ScurkPixelCanvas.new()
	root.add_child(canvas)
	_test_navigation(canvas)
	_test_selection_paint(canvas)
	_test_selection_drag(canvas)
	_test_selection_drag_missing_mask(canvas)
	_test_floating_paste(canvas)
	_test_paste_during_selection(canvas)
	_test_clipboard_key_repeat(canvas)
	_test_selection_edges(canvas)
	_test_paint_options(canvas)
	_test_layer_display(canvas)
	canvas.free()
	print("PASS: SCURK navigation, selections, floating paste, paint modes and layer composition")
	quit()


func _test_selection_masks() -> void:
	var selection := ScurkSelection.new()
	selection.reset(4, 4)
	selection.combine(selection.rectangle(Vector2i.ZERO, Vector2i(1, 1)))
	assert(selection.mask.count(1) == 4)
	selection.combine(selection.rectangle(Vector2i(3, 0), Vector2i(3, 1)), ScurkSelection.ADD)
	assert(selection.mask.count(1) == 6)
	selection.combine(selection.rectangle(Vector2i(1, 0), Vector2i(1, 3)), ScurkSelection.SUBTRACT)
	assert(selection.mask.count(1) == 4)
	assert(selection.translated(Vector2i.RIGHT).count(1) == 2)
	var polygon := PackedVector2Array([Vector2(0, 0), Vector2(3, 0), Vector2(0, 3)])
	var mask := selection.lasso(polygon)
	assert(mask[0] == 1 and mask[5] == 1 and mask[15] == 0)
	var pixels := PackedInt32Array([1, 1, 2, 1, 1, 2, 2, 1, 2, 2, 1, 1, 2, 2, 2, 2])
	mask = selection.wand(pixels, Vector2i.ZERO)
	assert(mask.count(1) == 3 and mask[3] == 0)
	selection.combine(mask)
	assert(selection.bounds() == Rect2i(0, 0, 2, 2))
	selection.clear()
	assert(not selection.active() and selection.contains(Vector2i(3, 3)))


func _reset(canvas: ScurkPixelCanvas, value := -1) -> void:
	var pixels := PackedInt32Array()
	pixels.resize(64)
	pixels.fill(value)
	canvas.clear_edit_region()
	canvas.paint_options = ScurkPaintOptions.new()
	canvas.editing_disabled = false
	canvas.set_sprite_data(8, 8, pixels, null)
	canvas.set_tool(ScurkPixelCanvas.TOOL_PENCIL)
	canvas.set_zoom(4)
	canvas.set_brush(1, false)
	canvas.set_paint_indices(42, 55)


func _mouse(canvas: ScurkPixelCanvas, point: Vector2i, pressed: bool, button := MOUSE_BUTTON_LEFT, shift := false, command := false, alt := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = Vector2(point * canvas.zoom) + Vector2(canvas.DISPLAY_MARGIN + 1, 1)
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	event.ctrl_pressed = command
	event.alt_pressed = alt
	canvas._gui_input(event)


func _key(canvas: ScurkPixelCanvas, code: Key, pressed := true, command := false, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.ctrl_pressed = command
	event.shift_pressed = shift
	canvas._gui_input(event)


func _test_navigation(canvas: ScurkPixelCanvas) -> void:
	_reset(canvas, 12)
	var zooms: Array = []
	var pans: Array = []
	var picks: Array = []
	canvas.zoom_requested.connect(func(steps: int, point: Vector2): zooms.append([steps, point]))
	canvas.pan_requested.connect(func(delta: Vector2): pans.append(delta))
	canvas.palette_index_picked.connect(func(index: int, background: bool): picks.append([index, background]))
	_mouse(canvas, Vector2i(2, 3), true, MOUSE_BUTTON_WHEEL_UP)
	assert(zooms == [[1, Vector2(10, 13)]])
	_mouse(canvas, Vector2i.ZERO, true, MOUSE_BUTTON_MIDDLE)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(20, -8)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	canvas._gui_input(motion)
	_mouse(canvas, Vector2i.ZERO, false, MOUSE_BUTTON_MIDDLE)
	assert(pans == [Vector2(20, -8)] and not canvas.panning)
	_mouse(canvas, Vector2i.ZERO, true, MOUSE_BUTTON_MIDDLE)
	motion.button_mask = 0
	canvas._gui_input(motion)
	assert(not canvas.panning and pans.size() == 1)
	_mouse(canvas, Vector2i.ZERO, true, MOUSE_BUTTON_MIDDLE)
	canvas._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(not canvas.panning)
	_key(canvas, KEY_SPACE)
	_mouse(canvas, Vector2i.ZERO, true)
	assert(canvas.panning and not canvas.stroke_active)
	_mouse(canvas, Vector2i.ZERO, false)
	_key(canvas, KEY_SPACE, false)
	_mouse(canvas, Vector2i(2, 3), true, MOUSE_BUTTON_LEFT, false, false, true)
	_mouse(canvas, Vector2i(2, 3), false, MOUSE_BUTTON_LEFT, false, false, true)
	assert(picks == [[12, false]] and canvas.pixels.count(12) == 64)
	_key(canvas, KEY_BRACKETRIGHT)
	assert(canvas.brush_size == 2)
	_key(canvas, KEY_BRACKETLEFT)
	assert(canvas.brush_size == 1)
	_key(canvas, KEY_X)
	assert(canvas.foreground_index == 55 and canvas.background_index == 42)
	canvas.set_zoom(8)
	canvas.set_tool(ScurkPixelCanvas.TOOL_LINE)
	assert(canvas.zoom == 8)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	assert(not canvas._handle_editor_key(escape))
	canvas.select_all()
	assert(canvas._handle_editor_key(escape) and not canvas.selection.active())
	var detached := ScurkPixelCanvas.new()
	_reset(detached)
	_mouse(detached, Vector2i.ZERO, true)
	_mouse(detached, Vector2i.ZERO, false)
	assert(detached.pixels[0] == 42)
	_mouse(detached, Vector2i.ZERO, true, MOUSE_BUTTON_MIDDLE)
	assert(detached.panning)
	detached.free()


func _test_selection_paint(canvas: ScurkPixelCanvas) -> void:
	_reset(canvas)
	canvas.set_tool(ScurkPixelCanvas.TOOL_SELECT_RECT)
	_mouse(canvas, Vector2i(1, 1), true)
	_mouse(canvas, Vector2i(3, 3), false)
	assert(canvas.selection.mask.count(1) == 9)
	_mouse(canvas, Vector2i(5, 1), true, MOUSE_BUTTON_LEFT, true)
	_mouse(canvas, Vector2i(5, 3), false)
	assert(canvas.selection.mask.count(1) == 12)
	_mouse(canvas, Vector2i(2, 1), true, MOUSE_BUTTON_LEFT, false, true)
	_mouse(canvas, Vector2i(2, 3), false)
	assert(canvas.selection.mask.count(1) == 9)
	canvas.set_tool(ScurkPixelCanvas.TOOL_PENCIL)
	_mouse(canvas, Vector2i(0, 0), true)
	_mouse(canvas, Vector2i(0, 0), false)
	assert(canvas.pixels.count(42) == 0)
	_mouse(canvas, Vector2i(1, 1), true)
	_mouse(canvas, Vector2i(1, 1), false)
	assert(canvas.pixels.count(42) == 1)
	canvas.set_tool(ScurkPixelCanvas.TOOL_FILL)
	_mouse(canvas, Vector2i(3, 1), true)
	assert(canvas.pixels.count(42) == 4 and canvas.pixel_at(Vector2i(2, 1)) == -1)
	var before := canvas.pixels.duplicate()
	canvas.set_sprite_data(8, 8, before, null, true)
	assert(canvas.selection.mask.count(1) == 9)
	canvas.nudge_selection(Vector2i.RIGHT)
	assert(canvas.pixel_at(Vector2i(1, 1)) == -1 and canvas.pixel_at(Vector2i(2, 1)) == 42)
	assert(canvas.selection.mask[10] == 1)
	canvas.cut_selection()
	assert(canvas.has_clipboard() and canvas.pixels.count(42) == 0)
	canvas.clear_selection()
	canvas.begin_paste(Vector2i(0, 0))
	canvas.commit_paste()
	assert(canvas.pixels.count(42) == 4)
	canvas.select_all()
	canvas.editing_disabled = true
	canvas.delete_selection()
	assert(canvas.pixels.count(42) == 4)


func _motion(canvas: ScurkPixelCanvas, point: Vector2i, held := true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(point * canvas.zoom) + Vector2(canvas.DISPLAY_MARGIN + 1, 1)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	canvas._gui_input(event)


func _test_selection_drag(canvas: ScurkPixelCanvas) -> void:
	var commits: Array[PackedInt32Array] = []
	var record := func(value: PackedInt32Array) -> void: commits.append(value)
	canvas.pixels_committed.connect(record)
	for tool in [ScurkPixelCanvas.TOOL_SELECT_RECT, ScurkPixelCanvas.TOOL_SELECT_LASSO, ScurkPixelCanvas.TOOL_SELECT_WAND]:
		_reset(canvas, 7)
		canvas.pixels[9] = 10
		canvas.pixels[10] = 55
		canvas.pixels[17] = -1
		canvas.pixels[18] = 20
		canvas.selection.combine(canvas.selection.rectangle(Vector2i.ONE, Vector2i(2, 2)))
		canvas.selection.combine(canvas.selection.rectangle(Vector2i(2, 1), Vector2i(2, 1)), ScurkSelection.SUBTRACT)
		canvas.set_tool(tool)
		var before := canvas.pixels.duplicate()
		var mask := canvas.selection.mask.duplicate()
		var count := commits.size()
		_mouse(canvas, Vector2i.ONE, true)
		_mouse(canvas, Vector2i.ONE, false)
		assert(not canvas.paste_active and canvas.pixels == before and canvas.selection.mask == mask)
		assert(commits.size() == count)
		_mouse(canvas, Vector2i.ONE, true)
		_motion(canvas, Vector2i(3, 3))
		assert(canvas.selection_move_dragging and canvas.pixels == before)
		assert(canvas.composite_pixels()[27] == 10)
		_key(canvas, KEY_ESCAPE)
		_mouse(canvas, Vector2i(3, 3), false)
		assert(not canvas.paste_active and canvas.pixels == before and canvas.selection.mask == mask)
		assert(commits.size() == count)
		_mouse(canvas, Vector2i.ONE, true)
		_motion(canvas, Vector2i(3, 3))
		_mouse(canvas, Vector2i(3, 3), false)
		assert(canvas.tool == tool and not canvas.paste_active and not canvas.selection_dragging)
		assert(canvas.pixels[9] == -1 and canvas.pixels[18] == -1 and canvas.pixels[10] == 55)
		assert(canvas.pixels[27] == 10 and canvas.pixels[28] == 7 and canvas.pixels[35] == -1 and canvas.pixels[36] == 20)
		assert(canvas.selection.bounds() == Rect2i(3, 3, 2, 2) and canvas.selection.mask.count(1) == 3)
		assert(commits.size() == count + 1)
		var moved := canvas.pixels.duplicate()
		_mouse(canvas, Vector2i(3, 3), true)
		_motion(canvas, Vector2i(4, 4))
		canvas._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		assert(not canvas.paste_active and canvas.pixels == moved)
		_mouse(canvas, Vector2i(3, 3), true)
		_motion(canvas, Vector2i(4, 4))
		_motion(canvas, Vector2i(5, 5), false)
		assert(not canvas.paste_active and canvas.selection.bounds() == Rect2i(4, 4, 2, 2))
		canvas.editing_disabled = true
		_mouse(canvas, Vector2i(4, 4), true)
		assert(not canvas.paste_active and not canvas.selection_dragging)
		canvas.editing_disabled = false
		_mouse(canvas, Vector2i(4, 4), true, MOUSE_BUTTON_LEFT, true)
		assert(not canvas.paste_active and not canvas.selection_move_dragging)
		_key(canvas, KEY_ESCAPE)
		canvas.selection.combine(canvas.selection.rectangle(Vector2i.ONE, Vector2i(2, 2)))
		_mouse(canvas, Vector2i.ONE, true, MOUSE_BUTTON_LEFT, false, true)
		assert(not canvas.paste_active and not canvas.selection_move_dragging)
		_key(canvas, KEY_ESCAPE)
		canvas.selection.combine(canvas.selection.rectangle(Vector2i(4, 4), Vector2i(5, 5)))
		_mouse(canvas, Vector2i(4, 4), true)
		_motion(canvas, Vector2i(12, 12))
		_mouse(canvas, Vector2i(12, 12), false)
		assert(not canvas.paste_active and not canvas.selection.active())
	canvas.pixels_committed.disconnect(record)


func _test_selection_drag_missing_mask(canvas: ScurkPixelCanvas) -> void:
	_reset(canvas)
	canvas.pixels[9] = 10
	canvas.selection.combine(canvas.selection.rectangle(Vector2i.ONE, Vector2i.ONE))
	canvas.set_tool(ScurkPixelCanvas.TOOL_SELECT_RECT)
	var before := canvas.pixels.duplicate()
	var event := InputEventMouseButton.new()
	event.position = Vector2(-100, -100)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_mouse(canvas, Vector2i.ONE, true)
	_motion(canvas, Vector2i(3, 3), false)
	var dragging := canvas.paste_active and canvas.selection_move_dragging
	var preview := canvas.composite_pixels()
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	assert(held and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	assert(dragging and canvas.pixels == before and preview[27] == 10)
	_mouse(canvas, Vector2i(3, 3), false)
	assert(not canvas.paste_active and canvas.pixel_at(Vector2i.ONE) == -1)
	assert(canvas.pixel_at(Vector2i(3, 3)) == 10 and canvas.selection.bounds() == Rect2i(3, 3, 1, 1))


func _test_floating_paste(canvas: ScurkPixelCanvas) -> void:
	_reset(canvas)
	canvas.clipboard_width = 2
	canvas.clipboard_height = 1
	canvas.clipboard_pixels = PackedInt32Array([10, 20])
	canvas.clipboard_mask.clear()
	canvas.begin_paste()
	assert(canvas.paste_active and canvas.pixels.count(-1) == 64)
	canvas.paste_position = Vector2i(1, 1)
	assert(canvas.composite_pixels()[9] == 10 and canvas.composite_pixels()[10] == 20)
	canvas.rotate_clipboard_clockwise()
	assert(canvas.clipboard_width == 1 and canvas.clipboard_height == 2)
	canvas.flip_clipboard_vertical()
	assert(canvas.clipboard_pixels == PackedInt32Array([20, 10]))
	_key(canvas, KEY_ENTER)
	assert(not canvas.paste_active and canvas.pixel_at(Vector2i(1, 1)) == 20 and canvas.pixel_at(Vector2i(1, 2)) == 10)
	var before := canvas.pixels.duplicate()
	canvas.begin_paste(Vector2i(5, 5))
	_key(canvas, KEY_ESCAPE)
	assert(canvas.pixels == before and not canvas.paste_active)
	canvas.selection.combine(canvas.selection.rectangle(Vector2i(1, 1), Vector2i(1, 2)))
	canvas.duplicate_selection()
	_key(canvas, KEY_RIGHT)
	_key(canvas, KEY_ENTER)
	assert(canvas.pixel_at(Vector2i(1, 1)) == 20 and canvas.pixel_at(Vector2i(2, 1)) == 20)
	canvas.clipboard_width = 2
	canvas.clipboard_height = 1
	canvas.clipboard_pixels = PackedInt32Array([30, 40])
	canvas.clipboard_mask = PackedByteArray([1, 0])
	canvas.rotate_clipboard_clockwise()
	assert(canvas.clipboard_mask == PackedByteArray([1, 0]))
	canvas.flip_clipboard_vertical()
	assert(canvas.clipboard_mask == PackedByteArray([0, 1]))
	_reset(canvas)
	canvas.clipboard_width = 1
	canvas.clipboard_height = 1
	canvas.clipboard_pixels = PackedInt32Array([10])
	canvas.clipboard_mask.clear()
	_mouse(canvas, Vector2i(3, 3), true)
	assert(canvas.stroke_active)
	_key(canvas, KEY_V, true, true)
	assert(canvas.paste_active and not canvas.stroke_active)
	_motion(canvas, Vector2i(5, 5))
	_mouse(canvas, Vector2i(5, 5), false)
	assert(canvas.paste_active and canvas.pixels.count(42) == 1)
	_mouse(canvas, Vector2i(5, 5), true)
	_mouse(canvas, Vector2i(5, 5), false)
	assert(not canvas.paste_active and canvas.pixels.count(42) == 1 and canvas.pixels[45] == 10)


func _test_paste_during_selection(canvas: ScurkPixelCanvas) -> void:
	for tool in [ScurkPixelCanvas.TOOL_SELECT_RECT, ScurkPixelCanvas.TOOL_SELECT_LASSO]:
		_reset(canvas)
		canvas.set_tool(tool)
		canvas.clipboard_width = 2
		canvas.clipboard_height = 1
		canvas.clipboard_pixels = PackedInt32Array([10, 20])
		canvas.clipboard_mask.clear()
		canvas.selection.combine(canvas.selection.rectangle(Vector2i(6, 1), Vector2i(6, 1)))
		var selected := canvas.selection.mask.duplicate()
		for cancel in [true, false]:
			_mouse(canvas, Vector2i.ONE, true)
			_motion(canvas, Vector2i(3, 3))
			assert(canvas.selection_dragging)
			_key(canvas, KEY_V, true, true)
			assert(canvas.paste_active and not canvas.selection_dragging and canvas.selection_preview.is_empty())
			_motion(canvas, Vector2i(4, 4))
			_mouse(canvas, Vector2i(4, 4), false)
			assert(canvas.paste_active and canvas.selection.mask == selected)
			var button := MOUSE_BUTTON_RIGHT if cancel else MOUSE_BUTTON_LEFT
			_mouse(canvas, Vector2i(5, 5), true, button)
			_mouse(canvas, Vector2i(5, 5), false, button)
			assert(not canvas.paste_active and not canvas.selection_dragging)
			if cancel:
				assert(canvas.pixels.count(-1) == 64 and canvas.selection.mask == selected)
			else:
				assert(canvas.pixels[45] == 10 and canvas.pixels[46] == 20)
				assert(canvas.selection.bounds() == Rect2i(5, 5, 2, 1))


func _test_clipboard_key_repeat(canvas: ScurkPixelCanvas) -> void:
	_reset(canvas)
	canvas.pixels[9] = 10
	canvas.pixels[10] = 20
	canvas.selection.combine(canvas.selection.rectangle(Vector2i.ONE, Vector2i(2, 1)))
	_key(canvas, KEY_X, true, true)
	assert(canvas.clipboard_pixels == PackedInt32Array([10, 20]) and canvas.pixels.count(-1) == 64)
	var event := InputEventKey.new()
	event.keycode = KEY_X
	event.pressed = true
	event.ctrl_pressed = true
	event.echo = true
	canvas._gui_input(event)
	assert(canvas.clipboard_pixels == PackedInt32Array([10, 20]))
	event.keycode = KEY_C
	event.ctrl_pressed = false
	event.meta_pressed = true
	canvas._gui_input(event)
	assert(canvas.clipboard_pixels == PackedInt32Array([10, 20]))
	canvas.hover_point = Vector2i(2, 3)
	_key(canvas, KEY_V, true, true)
	_key(canvas, KEY_RIGHT)
	assert(canvas.paste_position == Vector2i(3, 3) and not canvas.paste_follow_cursor)
	event.keycode = KEY_V
	canvas._gui_input(event)
	assert(canvas.paste_active and canvas.paste_position == Vector2i(3, 3) and not canvas.paste_follow_cursor)
	canvas.cancel_paste()


func _test_paint_options(canvas: ScurkPixelCanvas) -> void:
	_reset(canvas)
	canvas.pixels[9] = 42
	canvas.paint_options.lock_transparent = true
	canvas.set_paint_indices(55, 42)
	_mouse(canvas, Vector2i(0, 0), true)
	_mouse(canvas, Vector2i(0, 0), false)
	_mouse(canvas, Vector2i(1, 1), true)
	_mouse(canvas, Vector2i(1, 1), false)
	assert(canvas.pixels[0] == -1 and canvas.pixels[9] == 55)
	canvas.set_tool(ScurkPixelCanvas.TOOL_ERASER)
	_mouse(canvas, Vector2i(1, 1), true)
	_mouse(canvas, Vector2i(1, 1), false)
	assert(canvas.pixels[9] == 55)
	canvas.paint_options.set_shade_ramp(PackedInt32Array([42, 55, 60]))
	canvas.set_tool(ScurkPixelCanvas.TOOL_SHADE)
	canvas._begin_stroke(Vector2i(1, 1), MOUSE_BUTTON_LEFT)
	canvas._apply_free_line(Vector2i(1, 1))
	canvas._finish_stroke()
	assert(canvas.pixels[9] == 60)
	_reset(canvas)
	canvas.paint_options.pixel_perfect = true
	canvas._begin_stroke(Vector2i(1, 1), MOUSE_BUTTON_LEFT)
	canvas._apply_free_line(Vector2i(2, 1))
	canvas._apply_free_line(Vector2i(2, 2))
	canvas._finish_stroke()
	assert(canvas.pixels[9] == 42 and canvas.pixels[10] == -1 and canvas.pixels[18] == 42)
	_reset(canvas)
	canvas.paint_options.set_stamp(2, 1, PackedInt32Array([10, -1]))
	canvas.paint_options.stamp_spacing = 3
	canvas.set_tool(ScurkPixelCanvas.TOOL_STAMP)
	canvas._begin_stroke(Vector2i.ZERO, MOUSE_BUTTON_LEFT)
	canvas._apply_free_line(Vector2i(6, 0))
	canvas._finish_stroke()
	assert(canvas.pixels.count(10) == 3 and canvas.pixels[3] == 10 and canvas.pixels[6] == 10)


func _test_selection_edges(canvas: ScurkPixelCanvas) -> void:
	_reset(canvas, 42)
	canvas.pixels[0] = 10
	canvas.pixels[8] = -1
	canvas.pixels[9] = 20
	canvas.selection.combine(canvas.selection.rectangle(Vector2i.ZERO, Vector2i.ONE))
	canvas.selection.combine(canvas.selection.rectangle(Vector2i(1, 0), Vector2i(1, 0)), ScurkSelection.SUBTRACT)
	assert(canvas.copy_selection())
	assert(canvas.clipboard_pixels == PackedInt32Array([10, -1, -1, 20]))
	assert(canvas.clipboard_mask == PackedByteArray([1, 0, 1, 1]))
	canvas.clear_selection()
	canvas.begin_paste(Vector2i(4, 4))
	canvas.commit_paste()
	assert(canvas.pixel_at(Vector2i(4, 4)) == 10 and canvas.pixel_at(Vector2i(5, 4)) == 42)
	assert(canvas.pixel_at(Vector2i(4, 5)) == -1 and canvas.pixel_at(Vector2i(5, 5)) == 20)
	_reset(canvas)
	canvas.pixels[0] = 10
	canvas.pixels[1] = 20
	canvas.selection.combine(canvas.selection.rectangle(Vector2i.ZERO, Vector2i.RIGHT))
	canvas.nudge_selection(Vector2i.LEFT)
	assert(canvas.pixels[0] == 20 and canvas.pixels[1] == -1)
	assert(canvas.selection.bounds() == Rect2i(0, 0, 1, 1))
	var before := canvas.pixels.duplicate()
	canvas.duplicate_selection()
	canvas.nudge_selection(Vector2i(7, 7))
	canvas.cancel_paste()
	assert(canvas.pixels == before and canvas.selection.bounds() == Rect2i(0, 0, 1, 1))
	_reset(canvas)
	canvas.paint_options.set_stamp(1, 1, PackedInt32Array([10]))
	canvas.paint_options.stamp_spacing = 3
	canvas.set_tool(ScurkPixelCanvas.TOOL_STAMP)
	canvas._begin_stroke(Vector2i.ZERO, MOUSE_BUTTON_LEFT)
	for x in range(1, 7):
		canvas._apply_free_line(Vector2i(x, 0))
	canvas._finish_stroke()
	assert(canvas.pixels.count(10) == 3 and canvas.pixels[3] == 10 and canvas.pixels[6] == 10)


func _test_layer_display(canvas: ScurkPixelCanvas) -> void:
	_reset(canvas)
	canvas.pixels[0] = 10
	canvas.layer_below_pixels = canvas.pixels.duplicate()
	canvas.layer_below_pixels.fill(20)
	canvas.layer_above_pixels = canvas.pixels.duplicate()
	canvas.layer_above_pixels.fill(-1)
	canvas.layer_above_pixels[1] = 30
	var composite := canvas.composite_pixels()
	assert(composite[0] == 10 and composite[1] == 30 and composite[2] == 20)
	assert(canvas.pixels[1] == -1)
	canvas.active_layer_visible = false
	assert(canvas.composite_pixels()[0] == 20 and canvas.display_pixel_at(Vector2i.ZERO) == 20)
	assert(canvas.display_pixel_at(Vector2i(1, 0)) == 30)
	assert(canvas.pixels[0] == 10)
	var picked: Array[int] = []
	canvas.palette_index_picked.connect(func(index: int, _background: bool): picked.append(index))
	canvas.editing_disabled = true
	_mouse(canvas, Vector2i.ZERO, true, MOUSE_BUTTON_LEFT, false, false, true)
	_mouse(canvas, Vector2i.ZERO, false, MOUSE_BUTTON_LEFT, false, false, true)
	canvas.set_tool(ScurkPixelCanvas.TOOL_EYEDROPPER)
	_mouse(canvas, Vector2i(1, 0), true)
	_mouse(canvas, Vector2i(1, 0), false)
	assert(picked == [20, 30])
