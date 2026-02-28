class_name ScurkViewPreview
extends Control

const DrawingWorkspace = preload("res://src/tools/scurk_drawing_workspace.gd")

const CYCLE_INTERVAL_SECONDS := Sc2Palette.SCURK_TIMER_INTERVAL_SECONDS

var palette: Sc2Palette
var view := 0
var preview_width := 0
var preview_height := 0
var preview_indices := PackedInt32Array()
var palette_cycle_enabled := true
var palette_cycle_ticks := 0
var palette_cycle_accumulator := 0.0
var preview_texture: ImageTexture


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_preview(
	value_view: int,
	shape_width: int,
	shape_height: int,
	shape_pixels: PackedInt32Array,
	base_width: int,
	value_palette: Sc2Palette,
	background_workspace: PackedInt32Array
) -> void:
	view = clampi(value_view, 0, 2)
	palette = value_palette
	var divisor := DrawingWorkspace.view_divisor(view)
	preview_width = int(DrawingWorkspace.WIDTH / divisor)
	preview_height = int(DrawingWorkspace.HEIGHT / divisor)
	preview_indices.resize(preview_width * preview_height)
	var workspace := DrawingWorkspace.from_shape(
		shape_width, shape_height, shape_pixels, view, base_width
	)
	var has_background := (
		background_workspace.size()
		== DrawingWorkspace.WIDTH * DrawingWorkspace.HEIGHT
	)

	for y in preview_height:
		var source_y := divisor - 1 + y * divisor

		for x in preview_width:
			var source_x := divisor - 1 + x * divisor
			var source_offset := source_y * DrawingWorkspace.WIDTH + source_x
			var index := workspace[source_offset]

			if index < 0 and has_background:
				index = background_workspace[source_offset]

			preview_indices[y * preview_width + x] = index

	custom_minimum_size = Vector2(preview_width + 2, preview_height + 2)
	reset_size()
	_rebuild_texture()
	queue_redraw()


func clear_preview(value_view: int) -> void:
	view = clampi(value_view, 0, 2)
	var divisor := DrawingWorkspace.view_divisor(view)
	preview_width = int(DrawingWorkspace.WIDTH / divisor)
	preview_height = int(DrawingWorkspace.HEIGHT / divisor)
	preview_indices.resize(preview_width * preview_height)
	preview_indices.fill(-1)
	custom_minimum_size = Vector2(preview_width + 2, preview_height + 2)
	preview_texture = null
	reset_size()
	queue_redraw()


func set_palette_cycle_enabled(enabled: bool) -> void:
	if palette_cycle_enabled == enabled:
		return

	palette_cycle_enabled = enabled
	palette_cycle_accumulator = 0.0
	_rebuild_texture()
	queue_redraw()


func increment_palette_cycle() -> void:
	if palette_cycle_enabled:
		return

	palette_cycle_ticks += Sc2Palette.SCURK_INCREMENT_TIMER_TICKS
	_rebuild_texture()
	queue_redraw()


func _process(delta: float) -> void:
	if not palette_cycle_enabled or not is_visible_in_tree():
		return

	palette_cycle_accumulator += delta
	var changed := false

	while palette_cycle_accumulator >= CYCLE_INTERVAL_SECONDS:
		palette_cycle_accumulator -= CYCLE_INTERVAL_SECONDS
		palette_cycle_ticks += 1
		changed = true

	if changed:
		_rebuild_texture()
		queue_redraw()


func _rebuild_texture() -> void:
	if (
		preview_width <= 0
		or preview_height <= 0
		or preview_indices.size() != preview_width * preview_height
	):
		preview_texture = null

		return

	var animation_map := (
		palette.scurk_animation_index_map(palette_cycle_ticks)
		if palette != null and palette.is_valid()
		else PackedInt32Array()
	)
	var rgba := PackedByteArray()
	rgba.resize(preview_indices.size() * 4)

	for offset in preview_indices.size():
		var index := preview_indices[offset]
		var color := Color("ffffff")

		if index >= 0 and index < 256 and not animation_map.is_empty():
			color = palette.color(animation_map[index])
		elif index < 0:
			var x := offset % preview_width
			var y := int(offset / preview_width)
			color = Color("d8d8d8") if (x + y) % 2 == 0 else Color("ffffff")

		var byte_offset := offset * 4
		rgba[byte_offset] = clampi(roundi(color.r * 255.0), 0, 255)
		rgba[byte_offset + 1] = clampi(roundi(color.g * 255.0), 0, 255)
		rgba[byte_offset + 2] = clampi(roundi(color.b * 255.0), 0, 255)
		rgba[byte_offset + 3] = 255

	var image := Image.create_from_data(
		preview_width, preview_height, false, Image.FORMAT_RGBA8, rgba
	)

	if preview_texture == null:
		preview_texture = ImageTexture.create_from_image(image)
	else:
		preview_texture.update(image)


func _draw() -> void:
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(preview_width + 2, preview_height + 2)),
		Color("404040"), true
	)

	if preview_texture != null:
		draw_texture(preview_texture, Vector2.ONE)
