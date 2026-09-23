class_name ScurkViewPreview
extends Control

@warning_ignore_start("integer_division")

const DrawingWorkspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")

const CYCLE_INTERVAL_SECONDS := Sc2Palette.SCURK_TIMER_INTERVAL_SECONDS

@export var preview_scale := 1

var palette: Sc2Palette
var view := ScurkSpriteIds.View.LARGE
var preview_width := 0
var preview_height := 0
var preview_indices := PackedInt32Array()
var palette_cycle_enabled := true
var palette_cycle_ticks := 0
var palette_cycle_accumulator := 0.0
var preview_texture: ImageTexture
var texture_state: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visibility_changed.connect(_refresh_visible_texture)
	set_process(true)


func set_preview(
	value_view: int,
	shape_width: int,
	shape_height: int,
	shape_pixels: PackedInt32Array,
	base_width: int,
	value_palette: Sc2Palette,
	background_workspace: PackedInt32Array,
	clipping_enabled := true
) -> void:
	view = clampi(value_view, ScurkSpriteIds.View.LARGE, ScurkSpriteIds.View.SMALL)
	palette = value_palette
	var divisor := DrawingWorkspace.view_divisor(view)
	preview_width = DrawingWorkspace.WIDTH / divisor
	preview_height = DrawingWorkspace.HEIGHT / divisor
	preview_indices.resize(preview_width * preview_height)
	var workspace := DrawingWorkspace.from_shape(
		shape_width, shape_height, shape_pixels, view, base_width, clipping_enabled
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
				if index == ScurkPixelCanvas.BACKGROUND_TRANSPARENT_INDEX:
					index = -1

			preview_indices[y * preview_width + x] = index

	custom_minimum_size = Vector2(preview_width * preview_scale + 2, preview_height * preview_scale + 2)
	reset_size()
	_rebuild_texture()
	queue_redraw()


func clear_preview(value_view: int) -> void:
	view = clampi(value_view, ScurkSpriteIds.View.LARGE, ScurkSpriteIds.View.SMALL)
	var divisor := DrawingWorkspace.view_divisor(view)
	preview_width = DrawingWorkspace.WIDTH / divisor
	preview_height = DrawingWorkspace.HEIGHT / divisor
	preview_indices.resize(preview_width * preview_height)
	preview_indices.fill(-1)
	custom_minimum_size = Vector2(preview_width * preview_scale + 2, preview_height * preview_scale + 2)
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
	var state: Array = [preview_width, preview_height, hash(preview_indices),
		hash(palette.colors) if palette != null else 0, hash(animation_map)]
	if preview_texture != null and texture_state == state:
		return

	var colors := PackedInt64Array()
	colors.resize(256)
	for index in 256:
		colors[index] = palette.color(animation_map[index]).to_abgr32() if not animation_map.is_empty() else Color.WHITE.to_abgr32()
	var rgba := PackedByteArray()
	rgba.resize(preview_indices.size() * 4)
	for offset in preview_indices.size():
		var index := preview_indices[offset]
		var color := colors[index] if index >= 0 else 0
		rgba.encode_u32(offset * 4, color)
	var image := Image.create_from_data(
		preview_width, preview_height, false, Image.FORMAT_RGBA8, rgba
	)

	if preview_texture == null or preview_texture.get_size() != Vector2(preview_width, preview_height):
		preview_texture = ImageTexture.create_from_image(image)
	else:
		preview_texture.update(image)
	texture_state = state


func _draw() -> void:
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(preview_width * preview_scale + 2, preview_height * preview_scale + 2)),
		Color("404040"), false, 1.0
	)

	if preview_texture != null:
		draw_texture_rect(preview_texture, Rect2(Vector2.ONE, Vector2(preview_width, preview_height) * preview_scale), false)


func set_cycle_tick(tick: int) -> void:
	palette_cycle_ticks = tick
	if is_visible_in_tree():
		_rebuild_texture()
		queue_redraw()


func _refresh_visible_texture() -> void:
	if is_visible_in_tree():
		_rebuild_texture()
		queue_redraw()
