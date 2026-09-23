extends SceneTree

const PaintOptions = preload("res://src/tools/scurk/scurk_paint_options.gd")
const PaletteScene = preload("res://src/ui/scurk/scurk_editor_palette_panel.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_paint()
	_test_guides()
	_test_stamp()
	_test_palette()
	print("SCURK paint options and palette checks passed")
	quit()


func _test_paint() -> void:
	var options := PaintOptions.new()
	assert(options.paint_index(-1, 42) == 42)
	options.lock_transparent = true
	assert(options.paint_index(-1, 42) == -1)
	assert(options.paint_index(171, 42) == 42)
	assert(options.paint_index(171, -1) == 171)
	options.set_shade_ramp(PackedInt32Array([71, 42, 171, 42, -1, 256]))
	assert(options.shade_ramp == PackedInt32Array([71, 42, 171]))
	assert(options.shade_index(71) == 42 and options.shade_index(42) == 171)
	assert(options.shade_index(171) == 171 and options.shade_index(71, -1) == 71)
	assert(options.shade_index(171, -1) == 42)
	assert(options.shade_index(0) == 0 and options.shade_index(-1) == -1)
	options.shade_direction = -1
	assert(options.shade_index(42) == 71)
	var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]
	assert(PaintOptions.pixel_perfect_path(path) == [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)])
	assert(path.size() == 5)
	var straight: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert(PaintOptions.pixel_perfect_path(straight) == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	var backtrack: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ZERO]
	assert(PaintOptions.pixel_perfect_path(backtrack) == backtrack)


func _test_guides() -> void:
	var options := PaintOptions.new()
	assert(options.constrain_line(Vector2i.ZERO, Vector2i(8, 5)) == Vector2i(8, 5))
	options.isometric_snap = true
	assert(options.constrain_line(Vector2i.ZERO, Vector2i(8, 5)) == Vector2i(8, 4))
	assert(options.constrain_line(Vector2i.ZERO, Vector2i(1, 8)) == Vector2i(0, 8))
	assert(options.constrain_line(Vector2i(3, 7), Vector2i(-5, 2)) == Vector2i(-5, 3))
	options.guide_spacing = Vector2i(4, 6)
	options.guide_offset = Vector2i(2, 3)
	var lines := options.guide_lines(Vector2i(16, 16))
	assert(lines.size() % 2 == 0 and lines.size() > 12)
	assert(lines[0] == Vector2(2, 0) and lines[1] == Vector2(2, 16))
	for point in lines:
		assert(point.x >= 0 and point.x <= 16 and point.y >= -0.001 and point.y <= 16.001)
	options.guide_spacing = Vector2i.ZERO
	assert(not options.guide_lines(Vector2i(2, 2)).is_empty())
	assert(options.guide_lines(Vector2i.ZERO).is_empty())


func _test_stamp() -> void:
	var options := PaintOptions.new()
	var pixels := PackedInt32Array([42, -1, 171, 3, 2, 1])
	assert(options.set_stamp(3, 2, pixels))
	pixels[0] = 99
	assert(options.stamp_pixels[0] == 42)
	assert(not options.set_stamp(2, 2, pixels))
	assert(options.stamp_width == 3 and options.stamp_height == 2)
	assert(not options.set_stamp(1, 1, PackedInt32Array([256])))


func _test_palette() -> void:
	var panel := PaletteScene.instantiate() as ScurkEditorPalettePanel
	root.add_child(panel)
	panel.configure(Sc2Palette.index_encoding(), [], 42)
	var control := panel.palette_control
	var hovered: Array[int] = []
	var selected: Array[int] = []
	panel.palette_index_hovered.connect(func(index: int) -> void: hovered.append(index))
	panel.palette_index_selected.connect(func(index: int) -> void: selected.append(index))
	panel.set_used_pixels(PackedInt32Array([-1, 171, 42, 42, 252]))
	panel.palette_view.item_selected.emit(ScurkPaletteControl.MODE_USED)
	assert(control.visible_indices == PackedInt32Array([42, 171, 252]))
	assert(control.index_at(Vector2(19, 0)) == 171 and control.index_at(Vector2(55, 0)) == -1)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(19, 0)
	control._gui_input(motion)
	assert(hovered[-1] == 171)
	control.mouse_exited.emit()
	assert(hovered[-1] == -1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(19, 0)
	control._gui_input(click)
	assert(selected[-1] == 171 and control.recent_indices == PackedInt32Array([171]))
	click.shift_pressed = true
	control._gui_input(click)
	assert(control.ramp_indices == PackedInt32Array([171]))
	click.position = Vector2(0, 0)
	control._gui_input(click)
	assert(control.ramp_indices == PackedInt32Array([171, 42]))
	click.shift_pressed = false
	click.meta_pressed = true
	control._gui_input(click)
	assert(control.favorite_indices == PackedInt32Array([42]))
	assert(selected.size() == 1)
	assert(control.animated_indices.has(171) and not control.animated_indices.has(42))
	var saved := panel.export_state()
	control.toggle_favorite(42)
	control.clear_ramp()
	assert(control.favorite_indices.is_empty() and control.ramp_indices.is_empty())
	panel.import_state(saved)
	assert(control.favorite_indices == PackedInt32Array([42]) and control.ramp_indices == PackedInt32Array([171, 42]))
	panel.palette_view.item_selected.emit(ScurkPaletteControl.MODE_RAMP)
	assert(control.index_at(Vector2.ZERO) == 171 and control.index_at(Vector2(19, 0)) == 42)
	panel.ramp_clear_button.pressed.emit()
	assert(control.index_at(Vector2.ZERO) == -1)
	panel.import_state({"favorites": [42, -1, 42, 256, "bad", 3.5], "ramp": "bad"})
	assert(control.favorite_indices == PackedInt32Array([42]) and control.ramp_indices.is_empty())
	for index in 40:
		panel.remember_index(index)
	assert(control.recent_indices.size() == 32 and control.recent_indices[0] == 39 and control.recent_indices[-1] == 8)
	panel.free()
