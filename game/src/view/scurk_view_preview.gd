class_name ScurkViewPreview
extends Control

@warning_ignore_start("integer_division")

const DrawingWorkspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")

const CYCLE_INTERVAL_SECONDS := Sc2Palette.SCURK_TIMER_INTERVAL_SECONDS

@export var preview_scale := 1
@export var crop_to_artwork := false
@export var size_label := ""

var artwork_bounds := Rect2i()
var display_bounds := Rect2i()

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
	# a UI scale change on the main window changes the whole-pixel size
	ready.connect(func() -> void: get_tree().root.size_changed.connect(_on_screen_pixels_changed))
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

	var minimum := Vector2i(preview_width, preview_height)
	var maximum := Vector2i(-1, -1)
	for y in preview_height:
		var source_y := divisor - 1 + y * divisor

		for x in preview_width:
			var source_x := divisor - 1 + x * divisor
			var source_offset := source_y * DrawingWorkspace.WIDTH + source_x
			var index := workspace[source_offset]
			if index >= 0:
				minimum = minimum.min(Vector2i(x, y))
				maximum = maximum.max(Vector2i(x, y))

			if index < 0 and has_background:
				index = background_workspace[source_offset]
				if index == ScurkPixelCanvas.BACKGROUND_TRANSPARENT_INDEX:
					index = -1

			preview_indices[y * preview_width + x] = index

	artwork_bounds = Rect2i(minimum, maximum - minimum + Vector2i.ONE) if maximum.x >= 0 else Rect2i()
	_update_preview_size()
	_rebuild_texture()
	queue_redraw()


func clear_preview(value_view: int) -> void:
	view = clampi(value_view, ScurkSpriteIds.View.LARGE, ScurkSpriteIds.View.SMALL)
	var divisor := DrawingWorkspace.view_divisor(view)
	preview_width = DrawingWorkspace.WIDTH / divisor
	preview_height = DrawingWorkspace.HEIGHT / divisor
	preview_indices.resize(preview_width * preview_height)
	preview_indices.fill(-1)
	artwork_bounds = Rect2i()
	_update_preview_size()
	preview_texture = null
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


func _update_preview_size() -> void:
	display_bounds = Rect2i(0, 0, preview_width, preview_height)
	if crop_to_artwork:
		var bounds := artwork_bounds if artwork_bounds.has_area() else Rect2i(preview_width / 2, preview_height / 2, 1, 1)
		display_bounds = bounds.grow(4).intersection(display_bounds)
	var extent := _art_extent() + Vector2(2, 2)
	if not size_label.is_empty():
		extent.x = maxf(extent.x, get_theme_default_font().get_string_size(size_label, HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size()).x + 10)
		extent.y += _label_size() + 6
	custom_minimum_size = extent
	reset_size()


# the artwork size at the preview scale, on whole screen pixels
func _art_extent() -> Vector2:
	return Vector2(ScreenPixels.art_length(display_bounds.size.x, preview_scale), ScreenPixels.art_length(display_bounds.size.y, preview_scale))


func _on_screen_pixels_changed() -> void:
	_update_preview_size()
	queue_redraw()


func _label_size() -> int:
	return 14 if view == ScurkSpriteIds.View.LARGE else (12 if view == ScurkSpriteIds.View.MEDIUM else 10)


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, custom_minimum_size)
	draw_rect(frame, Color("404040"), false, 1.0)
	var label_height := _label_size() + 6 if not size_label.is_empty() else 0
	if preview_texture != null:
		var extent := _art_extent()
		var position := Vector2(floorf((frame.size.x - extent.x) * 0.5), 1 + label_height)
		draw_texture_rect_region(preview_texture, Rect2(position, extent), Rect2(display_bounds))
	if not size_label.is_empty():
		draw_string(get_theme_default_font(), Vector2(5, _label_size() + 2), size_label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size(), get_theme_color("font_color", "Label"))


func set_cycle_tick(tick: int) -> void:
	palette_cycle_ticks = tick
	if is_visible_in_tree():
		_rebuild_texture()
		queue_redraw()


func _refresh_visible_texture() -> void:
	if is_visible_in_tree():
		_rebuild_texture()
		queue_redraw()
