class_name ScurkPixelCanvas
extends Control

@warning_ignore_start("integer_division")

class PixelRegion extends RefCounted:
	var width := 0
	var height := 0
	var pixels := PackedInt32Array()


signal edit_started(description: String)
signal edit_cancelled
signal pixels_committed(pixels: PackedInt32Array)
signal palette_index_picked(index: int, background: bool)
signal pointer_changed(point: Vector2i, index: int)
signal clipboard_changed(width: int, height: int)
signal pan_requested(delta: Vector2)
signal zoom_requested(steps: int, local_position: Vector2)
signal selection_changed
signal brush_size_requested(size: int)
signal paint_indices_swap_requested
signal state_changed
signal copy_all_layers_requested(cut: bool)
signal new_layer_paste_committed(pixels: PackedInt32Array)

const MAX_BRUSH_SIZE := 24
const DISPLAY_MARGIN := 1
const SCROLL_PAN_STEP := 48.0
const BACKGROUND_TRANSPARENT_INDEX := 252
const TOOL_PENCIL := 0
const TOOL_ERASER := 1
const TOOL_LINE := 2
const TOOL_DIAMOND := 3
const TOOL_LEFT_WALL := 4
const TOOL_RIGHT_WALL := 5
const TOOL_ELLIPSE := 6
const TOOL_RECTANGLE := 7
const TOOL_FILL := 8
const TOOL_EYEDROPPER := 9
const TOOL_SELECT_RECT := 10
const TOOL_SELECT_LASSO := 11
const TOOL_SELECT_WAND := 12
const TOOL_MOVE := 13
const TOOL_SHADE := 14
const TOOL_STAMP := 15
const CYCLE_INTERVAL_SECONDS := Sc2Palette.SCURK_TIMER_INTERVAL_SECONDS

const TEXTURE_NAMES := [
	"Solid Foreground",
	"Foreground and Background",
	"Solid Background",
	"Texture 01", "Texture 02", "Texture 03", "Texture 04", "Texture 05",
	"Texture 06", "Texture 07", "Texture 08", "Texture 09", "Texture 10",
	"Texture 11", "Texture 12", "Texture 13", "Texture 14", "Texture 15",
	"Texture 16", "Texture 17", "Texture 18", "Texture 19", "Texture 20",
	"Texture 21", "Texture 22", "Texture 23", "Texture 24", "Texture 25",
	"Texture 26", "Texture 27", "Texture 28", "Texture 29", "Texture 30",
	"Texture 31", "Texture 32", "Texture 33", "Texture 34", "Texture 35",
	"Texture 36", "Texture 37", "Texture 38", "Texture 39",
]
const TEXTURE_ROWS := [
	[0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
	[0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55],
	[0xee, 0xbb, 0xee, 0xbb, 0xee, 0xbb, 0xee, 0xbb],
	[0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01],
	[0x81, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0x81],
	[0x88, 0x00, 0x22, 0x00, 0x88, 0x00, 0x22, 0x00],
	[0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc],
	[0xff, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00],
	[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
]

var palette: Sc2Palette
var sprite_width := 0
var sprite_height := 0
var pixels := PackedInt32Array()
var zoom := 4
var tool := TOOL_PENCIL
var foreground_index := 0
var background_index := 255
var texture_index := 0
var brush_size := 1
var round_brush := false
var filled_shapes := false
var show_grid := true
var grid_width := 1
var grid_height := 1
var snap_to_grid := false
var hover_point := Vector2i(-1, -1)
var stroke_active := false
var stroke_changed := false
var stroke_button := MOUSE_BUTTON_NONE
var last_stroke_point := Vector2i(-1, -1)
var shape_start := Vector2i(-1, -1)
var stroke_base_pixels := PackedInt32Array()
var clipboard_width := 0
var clipboard_height := 0
var clipboard_pixels := PackedInt32Array()
var texture_patterns: Array[PackedInt32Array] = []
var palette_cycle_ticks := 0
var palette_cycle_enabled := true
var palette_cycle_accumulator := 0.0
var edit_mask := PackedByteArray()
var clip_base_size := -1
var show_clip_region := false
var clip_shade_texture: ImageTexture
var clip_columns := Vector2i(-1, -1)
var background_view := ScurkSpriteIds.View.LARGE
var clear_background_pixels := PackedInt32Array()
var show_terrain := true
var outline_state: Array = []
var outline_edges := PackedVector2Array()
var display_texture: ImageTexture
var display_state: Array = []
var selection := ScurkSelection.new()
var paint_options := ScurkPaintOptions.new()
var editing_disabled := false
var active_layer_visible := true
var layer_below_pixels := PackedInt32Array()
var layer_above_pixels := PackedInt32Array()
var comparison_pixels := PackedInt32Array()
var comparison_mode := 0
var comparison_hold := false
var highlighted_palette_index := -1
var show_isometric_guides := false
var selection_dragging := false
var selection_mode := ScurkSelection.REPLACE
var selection_start := Vector2i.ZERO
var selection_finish := Vector2i.ZERO
var selection_path := PackedVector2Array()
var selection_preview := PackedByteArray()
var selection_outline_state: Array = []
var selection_outline_edges := PackedVector2Array()
var selection_outline := ScurkSelectionOutline.new()
var selection_move_dragging := false
var selection_move_origin := Vector2i.ZERO
var clipboard_mask := PackedByteArray()
var paste_active := false
var paste_new_layer := false
var paste_position := Vector2i.ZERO
var paste_follow_cursor := false
var paste_dragging := false
var paste_drag_offset := Vector2i.ZERO
var paste_clear_source := false
var paste_source_mask := PackedByteArray()
var paste_selection_before := PackedByteArray()
var panning := false
var scroll_zoom_delta := 0.0
var pan_button_mask := 0
var space_pressed := false
var pencil_path: Array[Vector2i] = []
var stamp_distance := 0.0
var shade_visited: Dictionary[Vector2i, bool] = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_exited.connect(_on_mouse_exited)
	texture_patterns = _fallback_texture_patterns()
	selection_outline.position = Vector2(DISPLAY_MARGIN, 0)
	add_child(selection_outline)
	set_process(true)


func _process(delta: float) -> void:
	if not palette_cycle_enabled or not is_visible_in_tree():
		return

	var before := palette_cycle_ticks
	palette_cycle_accumulator += delta

	while palette_cycle_accumulator >= CYCLE_INTERVAL_SECONDS:
		palette_cycle_accumulator -= CYCLE_INTERVAL_SECONDS
		palette_cycle_ticks += 1

	if palette != null and before != palette_cycle_ticks and palette.scurk_animation_index_map(before) != palette.scurk_animation_index_map(palette_cycle_ticks):
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed:
		if event.keycode == KEY_SPACE:
			space_pressed = false
		elif event.keycode == KEY_BACKSLASH and comparison_hold:
			comparison_hold = false
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_stop_panning()
		if paste_dragging:
			cancel_paste()
		space_pressed = false
		comparison_hold = false
		queue_redraw()


func _stop_panning() -> void:
	panning = false
	pan_button_mask = 0
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func set_sprite_data(
	width: int, height: int, value_pixels: PackedInt32Array, value_palette: Sc2Palette,
	keep_selection: bool = false
) -> void:
	if not keep_selection or selection.width != width or selection.height != height:
		cancel_paste()
		selection.reset(width, height)
		selection_dragging = false
		selection_preview.clear()
		layer_below_pixels.clear()
		layer_above_pixels.clear()
		comparison_pixels.clear()
		active_layer_visible = true
	palette = value_palette
	sprite_width = maxi(0, width)
	sprite_height = maxi(0, height)
	pixels = value_pixels.duplicate()
	_enforce_edit_mask()
	stroke_active = false
	stroke_changed = false
	stroke_base_pixels.clear()
	hover_point = Vector2i(-1, -1)
	_update_minimum_size()
	queue_redraw()


func clear_sprite() -> void:
	set_sprite_data(0, 0, PackedInt32Array(), palette)


func set_zoom(value: int) -> void:
	zoom = clampi(value, 1, 16)
	_update_minimum_size()
	queue_redraw()


func set_tool(value: int) -> void:
	_finish_stroke()
	if paste_active and value != tool:
		cancel_paste()
	if value != tool:
		selection_dragging = false
		selection_preview.clear()
	tool = clampi(value, TOOL_PENCIL, TOOL_STAMP)
	queue_redraw()


func set_edit_region(mask: PackedByteArray, base_size: int) -> void:
	if mask.size() != sprite_width * sprite_height:
		edit_mask.clear()
		clip_base_size = -1
	else:
		edit_mask = mask.duplicate()
		clip_base_size = clampi(base_size, 1, 4)

	clip_columns = Vector2i(sprite_width, -1)
	for offset in edit_mask.size():
		if edit_mask[offset] != 0:
			var x := offset % sprite_width
			clip_columns.x = mini(clip_columns.x, x)
			clip_columns.y = maxi(clip_columns.y, x)
	_enforce_edit_mask()
	_update_clip_shade()
	queue_redraw()


func clear_edit_region() -> void:
	edit_mask.clear()
	clip_base_size = -1
	clip_columns = Vector2i(-1, -1)
	show_clip_region = false
	clip_shade_texture = null
	queue_redraw()


func _update_clip_shade() -> void:
	clip_shade_texture = null
	if edit_mask.is_empty():
		return
	var image := Image.create(sprite_width, sprite_height, false, Image.FORMAT_RGBA8)
	for offset in edit_mask.size():
		if edit_mask[offset] == 0:
			image.set_pixel(offset % sprite_width, offset / sprite_width, Color(0, 0, 0, 0.18))
	clip_shade_texture = ImageTexture.create_from_image(image)


func set_clip_region_visible(enabled: bool) -> void:
	show_clip_region = enabled and not edit_mask.is_empty()
	queue_redraw()


func set_paint_indices(foreground: int, background: int) -> void:
	foreground_index = clampi(foreground, 0, 255)
	background_index = clampi(background, 0, 255)


func set_brush(value_size: int, rounded: bool) -> void:
	brush_size = clampi(value_size, 1, MAX_BRUSH_SIZE)
	round_brush = rounded
	queue_redraw()


func set_grid_settings(width: int, height: int, snap: bool) -> void:
	grid_width = clampi(width, 1, 65)
	grid_height = clampi(height, 1, 65)
	snap_to_grid = snap
	queue_redraw()


func set_texture(value: int) -> void:
	texture_index = clampi(value, 0, maxi(0, texture_patterns.size() - 1))


func set_palette_cycle_enabled(enabled: bool) -> void:
	palette_cycle_enabled = enabled
	palette_cycle_accumulator = 0.0
	queue_redraw()


func increment_palette_cycle() -> void:
	if palette_cycle_enabled:
		return

	palette_cycle_ticks += Sc2Palette.SCURK_INCREMENT_TIMER_TICKS
	queue_redraw()


func display_palette_index(index: int) -> int:
	if index < 0 or index > 255 or palette == null or not palette.is_valid():
		return index

	return palette.scurk_animation_index_map(palette_cycle_ticks)[index]


func set_drawing_graphics(graphics: ScurkGraphics) -> void:
	if graphics == null:
		texture_patterns = _fallback_texture_patterns()
		texture_index = clampi(texture_index, 0, texture_patterns.size() - 1)
		clear_background_pixels.clear()
		queue_redraw()
		return

	texture_patterns.clear()

	for pattern in graphics.patterns:
		texture_patterns.append(pattern.duplicate())

	texture_index = clampi(texture_index, 0, texture_patterns.size() - 1)
	clear_background_pixels = graphics.backgrounds[0].duplicate()

	queue_redraw()


static func _fallback_texture_patterns() -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []

	for source_index in [0, 1, 8, 2, 3, 4, 5, 6, 7]:
		var rows: Array = TEXTURE_ROWS[source_index]
		var pattern := PackedInt32Array()
		pattern.resize(64)

		for y in 8:
			var row_mask := int(rows[y])

			for x in 8:
				pattern[y * 8 + x] = 0xff if row_mask & (0x80 >> x) else 0

		result.append(pattern)

	while result.size() < TEXTURE_NAMES.size():
		result.append(result[3 + posmod(result.size() - 3, 6)].duplicate())

	return result


func pixel_at(point: Vector2i) -> int:
	if not _point_is_valid(point):
		return -2

	return pixels[point.y * sprite_width + point.x]


func display_pixel_at(point: Vector2i) -> int:
	if not _point_is_valid(point):
		return -2

	var offset := point.y * sprite_width + point.x
	if (comparison_hold or comparison_mode == 1) and comparison_pixels.size() == pixels.size():
		return comparison_pixels[offset]
	if layer_above_pixels.size() == pixels.size() and layer_above_pixels[offset] >= 0:
		return layer_above_pixels[offset]
	var value := _floating_pixels()[offset] if paste_active else pixels[offset]
	if not active_layer_visible:
		value = -1
	if value < 0 and layer_below_pixels.size() == pixels.size():
		value = layer_below_pixels[offset]
	return value


func has_clipboard() -> bool:
	return (
		clipboard_width > 0
		and clipboard_height > 0
		and clipboard_pixels.size() == clipboard_width * clipboard_height
	)


func rotate_clipboard_counterclockwise() -> void:
	if not has_clipboard():
		return

	var rotated := rotate_counterclockwise(
		clipboard_pixels, clipboard_width, clipboard_height
	)
	_transform_clipboard_mask(0)
	var old_width := clipboard_width
	clipboard_width = clipboard_height
	clipboard_height = old_width
	clipboard_pixels = rotated
	clipboard_changed.emit(clipboard_width, clipboard_height)
	queue_redraw()


func rotate_clipboard_clockwise() -> void:
	if not has_clipboard():
		return

	var rotated := PackedInt32Array()
	rotated.resize(clipboard_pixels.size())
	for y in clipboard_height:
		for x in clipboard_width:
			rotated[x * clipboard_height + clipboard_height - 1 - y] = clipboard_pixels[y * clipboard_width + x]

	_transform_clipboard_mask(1)
	var old_width := clipboard_width
	clipboard_width = clipboard_height
	clipboard_height = old_width
	clipboard_pixels = rotated
	clipboard_changed.emit(clipboard_width, clipboard_height)
	queue_redraw()


func flip_clipboard_horizontal() -> void:
	if not has_clipboard():
		return

	_transform_clipboard_mask(2)
	clipboard_pixels = flip_horizontal(
		clipboard_pixels, clipboard_width, clipboard_height
	)
	clipboard_changed.emit(clipboard_width, clipboard_height)
	queue_redraw()


func flip_clipboard_vertical() -> void:
	if not has_clipboard():
		return

	_transform_clipboard_mask(3)
	clipboard_pixels = flip_vertical(
		clipboard_pixels, clipboard_width, clipboard_height
	)
	clipboard_changed.emit(clipboard_width, clipboard_height)
	queue_redraw()


static func copy_region(
	value_pixels: PackedInt32Array,
	width: int,
	height: int,
	start: Vector2i,
	finish: Vector2i
) -> PixelRegion:
	if width <= 0 or height <= 0 or value_pixels.size() != width * height:
		var result := PixelRegion.new()
		result.width = 0
		result.height = 0
		result.pixels = PackedInt32Array()

		return result

	var minimum := Vector2i(
		clampi(mini(start.x, finish.x), 0, width - 1),
		clampi(mini(start.y, finish.y), 0, height - 1)
	)
	var maximum := Vector2i(
		clampi(maxi(start.x, finish.x), 0, width - 1),
		clampi(maxi(start.y, finish.y), 0, height - 1)
	)
	var copied_width := maximum.x - minimum.x + 1
	var copied_height := maximum.y - minimum.y + 1
	var copied := PackedInt32Array()
	copied.resize(copied_width * copied_height)

	for y in copied_height:
		for x in copied_width:
			copied[y * copied_width + x] = value_pixels[
				(minimum.y + y) * width + minimum.x + x
			]

	var result := PixelRegion.new()
	result.width = copied_width
	result.height = copied_height
	result.pixels = copied

	return result


static func paste_region(
	target_pixels: PackedInt32Array,
	target_width: int,
	target_height: int,
	target: Vector2i,
	source_pixels: PackedInt32Array,
	source_width: int,
	source_height: int
) -> PackedInt32Array:
	var result := target_pixels.duplicate()

	if (
		target_width <= 0
		or target_height <= 0
		or result.size() != target_width * target_height
		or source_width <= 0
		or source_height <= 0
		or source_pixels.size() != source_width * source_height
	):
		return result

	for source_y in source_height:
		var target_y := target.y + source_y

		if target_y < 0 or target_y >= target_height:
			continue

		for source_x in source_width:
			var target_x := target.x + source_x

			if target_x < 0 or target_x >= target_width:
				continue

			result[target_y * target_width + target_x] = (
				source_pixels[source_y * source_width + source_x]
			)

	return result


static func rotate_counterclockwise(
	value_pixels: PackedInt32Array, width: int, height: int
) -> PackedInt32Array:
	if width <= 0 or height <= 0 or value_pixels.size() != width * height:
		return PackedInt32Array()

	var result := PackedInt32Array()
	result.resize(width * height)
	var result_width := height

	for y in height:
		for x in width:
			var result_x := y
			var result_y := width - 1 - x
			result[result_y * result_width + result_x] = value_pixels[y * width + x]

	return result


static func flip_horizontal(
	value_pixels: PackedInt32Array, width: int, height: int
) -> PackedInt32Array:
	if width <= 0 or height <= 0 or value_pixels.size() != width * height:
		return PackedInt32Array()

	var result := PackedInt32Array()
	result.resize(width * height)

	for y in height:
		for x in width:
			result[y * width + width - 1 - x] = value_pixels[y * width + x]

	return result


static func flip_vertical(
	value_pixels: PackedInt32Array, width: int, height: int
) -> PackedInt32Array:
	if width <= 0 or height <= 0 or value_pixels.size() != width * height:
		return PackedInt32Array()

	var result := PackedInt32Array()
	result.resize(width * height)

	for y in height:
		for x in width:
			result[(height - 1 - y) * width + x] = value_pixels[y * width + x]

	return result


static func flood_fill(
	value_pixels: PackedInt32Array,
	width: int,
	height: int,
	start: Vector2i,
	replacement: int
) -> PackedInt32Array:
	return flood_fill_pattern(
		value_pixels, width, height, start, replacement, replacement,
		TEXTURE_ROWS[0]
	)


static func flood_fill_pattern(
	value_pixels: PackedInt32Array,
	width: int,
	height: int,
	start: Vector2i,
	foreground: int,
	background: int,
	pattern_rows: Array
) -> PackedInt32Array:
	if pattern_rows.size() != 8:
		return value_pixels.duplicate()

	var pattern := PackedInt32Array()
	pattern.resize(64)

	for y in 8:
		var row_mask := int(pattern_rows[y])

		for x in 8:
			pattern[y * 8 + x] = 0xff if row_mask & (0x80 >> x) else 0

	return flood_fill_texture(
		value_pixels, width, height, start, foreground, background, pattern, 8, 8
	)


static func flood_fill_texture(
	value_pixels: PackedInt32Array,
	width: int,
	height: int,
	start: Vector2i,
	foreground: int,
	background: int,
	pattern_pixels: PackedInt32Array,
	pattern_width: int,
	pattern_height: int
) -> PackedInt32Array:
	var result := value_pixels.duplicate()

	if (
		width <= 0
		or height <= 0
		or result.size() != width * height
		or start.x < 0
		or start.y < 0
		or start.x >= width
		or start.y >= height
		or foreground < -1
		or foreground > 255
		or background < -1
		or background > 255
		or pattern_width <= 0
		or pattern_height <= 0
		or pattern_pixels.size() != pattern_width * pattern_height
	):
		return result

	var target := result[start.y * width + start.x]
	var visited := PackedByteArray()
	visited.resize(width * height)
	var pending: Array[Vector2i] = [start]

	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		var point_index := point.y * width + point.x

		if visited[point_index] != 0 or result[point_index] != target:
			continue

		visited[point_index] = 1
		result[point_index] = texture_color(
			point, foreground, background,
			pattern_pixels, pattern_width, pattern_height
		)
		var neighbors: Array[Vector2i] = [
			Vector2i(point.x - 1, point.y),
			Vector2i(point.x + 1, point.y),
			Vector2i(point.x, point.y - 1),
			Vector2i(point.x, point.y + 1),
		]
		for neighbor: Vector2i in neighbors:
			if (
				neighbor.x >= 0
				and neighbor.y >= 0
				and neighbor.x < width
				and neighbor.y < height
			):
				pending.append(neighbor)

	return result


static func texture_color(
	point: Vector2i,
	foreground: int,
	background: int,
	pattern_pixels: PackedInt32Array,
	pattern_width: int,
	pattern_height: int
) -> int:
	if (
		pattern_width <= 0
		or pattern_height <= 0
		or pattern_pixels.size() != pattern_width * pattern_height
	):
		return foreground

	var source := pattern_pixels[
		posmod(point.y, pattern_height) * pattern_width
		+ posmod(point.x, pattern_width)
	]

	return ScurkPaintOptions.resolve_texture_value(source, foreground, background)


static func line_points(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var x := start.x
	var y := start.y
	var dx := absi(finish.x - x)
	var sx := 1 if x < finish.x else -1
	var dy := -absi(finish.y - y)
	var sy := 1 if y < finish.y else -1
	var error := dx + dy

	while true:
		result.append(Vector2i(x, y))

		if x == finish.x and y == finish.y:
			break

		var doubled := error * 2

		if doubled >= dy:
			error += dy
			x += sx

		if doubled <= dx:
			error += dx
			y += sy

	return result


static func shape_points(
	shape_tool: int, start: Vector2i, finish: Vector2i, filled: bool
) -> Array[Vector2i]:
	if shape_tool == TOOL_LINE:
		return line_points(start, finish)

	var result: Array[Vector2i] = []
	var minimum := Vector2i(mini(start.x, finish.x), mini(start.y, finish.y))
	var maximum := Vector2i(maxi(start.x, finish.x), maxi(start.y, finish.y))

	if shape_tool == TOOL_RECTANGLE:
		for y in range(minimum.y, maximum.y + 1):
			for x in range(minimum.x, maximum.x + 1):
				if filled or x in [minimum.x, maximum.x] or y in [minimum.y, maximum.y]:
					result.append(Vector2i(x, y))

		return result

	if shape_tool == TOOL_DIAMOND:
		var center := Vector2(minimum + maximum) * 0.5
		var radius_x := maxf(0.5, float(maximum.x - minimum.x) * 0.5)
		var radius_y := maxf(0.5, float(maximum.y - minimum.y) * 0.5)

		for y in range(minimum.y, maximum.y + 1):
			for x in range(minimum.x, maximum.x + 1):
				var distance := absf((x - center.x) / radius_x) + absf((y - center.y) / radius_y)
				var edge_width := maxf(1.0 / radius_x, 1.0 / radius_y)

				if distance <= 1.0 + edge_width * 0.25 and (filled or distance >= 1.0 - edge_width):
					result.append(Vector2i(x, y))

		return result

	if shape_tool == TOOL_ELLIPSE:
		var ellipse_center := Vector2(minimum + maximum) * 0.5
		var ellipse_radius_x := maxf(0.5, float(maximum.x - minimum.x) * 0.5)
		var ellipse_radius_y := maxf(0.5, float(maximum.y - minimum.y) * 0.5)

		for y in range(minimum.y, maximum.y + 1):
			for x in range(minimum.x, maximum.x + 1):
				var dx := (x - ellipse_center.x) / ellipse_radius_x
				var dy := (y - ellipse_center.y) / ellipse_radius_y
				var distance := dx * dx + dy * dy
				var edge_width := maxf(1.0 / ellipse_radius_x, 1.0 / ellipse_radius_y) * 1.4

				if distance <= 1.0 + edge_width and (filled or distance >= 1.0 - edge_width):
					result.append(Vector2i(x, y))

		return result

	if shape_tool in [TOOL_LEFT_WALL, TOOL_RIGHT_WALL]:
		if minimum.x == maximum.x or minimum.y == maximum.y:
			return line_points(start, finish)

		var half_height := int((maximum.y - minimum.y) / 2)
		var polygon := PackedVector2Array()

		if shape_tool == TOOL_LEFT_WALL:
			polygon = PackedVector2Array([
				Vector2(minimum.x, minimum.y),
				Vector2(maximum.x, minimum.y + half_height),
				Vector2(maximum.x, maximum.y),
				Vector2(minimum.x, maximum.y - half_height),
			])
		else:
			polygon = PackedVector2Array([
				Vector2(maximum.x, minimum.y),
				Vector2(minimum.x, minimum.y + half_height),
				Vector2(minimum.x, maximum.y),
				Vector2(maximum.x, maximum.y - half_height),
			])

		if filled:
			for y in range(minimum.y, maximum.y + 1):
				for x in range(minimum.x, maximum.x + 1):
					if Geometry2D.is_point_in_polygon(Vector2(x, y), polygon):
						result.append(Vector2i(x, y))
		else:
			for index in polygon.size():
				var first := Vector2i(polygon[index])
				var second := Vector2i(polygon[(index + 1) % polygon.size()])
				result.append_array(line_points(first, second))

	return result


static func snapped_shape_point(
	point: Vector2i, width: int, height: int, enabled: bool
) -> Vector2i:
	if not enabled:
		return point

	return Vector2i(
		_snap_coordinate(point.x, clampi(width, 1, 65)),
		_snap_coordinate(point.y, clampi(height, 1, 65))
	)


static func _snap_coordinate(value: int, spacing: int) -> int:
	if value < 0:
		return value

	return int((value * 2 + spacing) / (spacing * 2)) * spacing


func clear_selection() -> void:
	selection.clear()
	selection_preview.clear()
	selection_dragging = false
	selection_changed.emit()
	queue_redraw()


func select_all() -> void:
	selection.combine(selection.rectangle(Vector2i.ZERO, Vector2i(sprite_width - 1, sprite_height - 1)))
	selection_changed.emit()
	queue_redraw()


func selected_mask() -> PackedByteArray:
	var result := selection.mask.duplicate()
	if result.is_empty():
		result.resize(pixels.size())
		result.fill(1)
	if edit_mask.size() == result.size():
		for offset in result.size():
			result[offset] &= edit_mask[offset]
	return result


func copy_selection(whole_if_empty := true, source := PackedInt32Array()) -> bool:
	_finish_stroke()
	if source.is_empty():
		source = pixels
	if pixels.is_empty() or source.size() != pixels.size() or (not whole_if_empty and not selection.active()):
		return false

	var bounds := selection.bounds() if selection.active() else _artwork_bounds(source)
	if not bounds.has_area():
		return false
	var copied := copy_region(source, sprite_width, sprite_height, bounds.position, bounds.end - Vector2i.ONE)
	clipboard_width = copied.width
	clipboard_height = copied.height
	clipboard_pixels = copied.pixels
	clipboard_mask.resize(clipboard_pixels.size())
	for y in clipboard_height:
		for x in clipboard_width:
			var target := bounds.position + Vector2i(x, y)
			var offset := y * clipboard_width + x
			clipboard_mask[offset] = 1 if selection.contains(target) else 0
			if clipboard_mask[offset] == 0:
				clipboard_pixels[offset] = -1
	clipboard_changed.emit(clipboard_width, clipboard_height)
	queue_redraw()
	return true


func _artwork_bounds(source: PackedInt32Array) -> Rect2i:
	var minimum := Vector2i(sprite_width, sprite_height)
	var maximum := Vector2i(-1, -1)
	for offset in source.size():
		if source[offset] >= 0:
			var point := Vector2i(offset % sprite_width, offset / sprite_width)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE) if maximum.x >= 0 else Rect2i()


func cut_selection() -> void:
	if not editing_disabled and copy_selection():
		delete_selection(true)


func delete_selection(whole_if_empty := false) -> void:
	if editing_disabled or (not selection.active() and not whole_if_empty):
		return

	var changed := pixels.duplicate()
	for offset in changed.size():
		if (not selection.active() or selection.mask[offset] != 0) and _point_is_editable(Vector2i(offset % sprite_width, offset / sprite_width)):
			changed[offset] = paint_options.paint_index(changed[offset], -1)
	_commit_changed_pixels(changed, "Delete selection")


func duplicate_selection() -> void:
	_begin_selection_move(true)


func nudge_selection(delta: Vector2i) -> void:
	if paste_active:
		paste_position += delta
		paste_follow_cursor = false
		queue_redraw()
		return

	if _begin_selection_move(false):
		paste_position += delta
		commit_paste()


func begin_paste(point: Vector2i = Vector2i(-1, -1), new_layer := false) -> bool:
	if (editing_disabled and not new_layer) or not has_clipboard():
		return false

	var cursor_point := hover_point
	_finish_stroke()
	selection_dragging = false
	selection_preview.clear()
	cancel_paste()
	paste_active = true
	paste_new_layer = new_layer
	paste_position = point if point.x >= 0 else cursor_point.max(Vector2i.ZERO)
	paste_follow_cursor = true
	paste_selection_before = selection.mask.duplicate()
	state_changed.emit()
	queue_redraw()
	return true


func commit_paste() -> void:
	if not paste_active or (editing_disabled and not paste_new_layer):
		return

	var description := "Move selection" if paste_clear_source else "Paste"
	var changed := _floating_pixels()
	var new_layer := paste_new_layer
	var moved_mask := selection.empty_mask()
	for y in clipboard_height:
		for x in clipboard_width:
			var target := paste_position + Vector2i(x, y)
			if _point_is_valid(target) and _clipboard_contains(y * clipboard_width + x):
				moved_mask[target.y * sprite_width + target.x] = 1
	paste_active = false
	paste_new_layer = false
	paste_dragging = false
	selection_move_dragging = false
	paste_clear_source = false
	paste_source_mask.clear()
	selection.combine(moved_mask)
	selection_changed.emit()
	if new_layer:
		new_layer_paste_committed.emit(changed)
	else:
		_commit_changed_pixels(changed, description)
	state_changed.emit()
	queue_redraw()


func cancel_paste() -> void:
	if paste_active:
		selection.mask = paste_selection_before.duplicate()
		selection_changed.emit()
	paste_active = false
	paste_new_layer = false
	paste_dragging = false
	selection_move_dragging = false
	paste_follow_cursor = false
	paste_clear_source = false
	paste_source_mask.clear()
	state_changed.emit()
	queue_redraw()


func _begin_selection_move(duplicate: bool) -> bool:
	if editing_disabled or not selection.active() or not copy_selection():
		return false

	var source := selection.mask.duplicate()
	var origin := selection.bounds().position
	begin_paste(origin)
	paste_follow_cursor = false
	paste_clear_source = not duplicate
	paste_source_mask = source
	return true


func transform_selection(operation: int) -> void:
	var transforms: Array[Callable] = [rotate_clipboard_counterclockwise,
		rotate_clipboard_clockwise, flip_clipboard_horizontal, flip_clipboard_vertical]
	if operation < 0 or operation >= transforms.size():
		return
	if paste_active:
		transforms[operation].call()
		return
	if editing_disabled or not selection.active():
		return
	var saved_width := clipboard_width
	var saved_height := clipboard_height
	var saved_pixels := clipboard_pixels.duplicate()
	var saved_mask := clipboard_mask.duplicate()
	if _begin_selection_move(false):
		transforms[operation].call()
		commit_paste()
	clipboard_width = saved_width
	clipboard_height = saved_height
	clipboard_pixels = saved_pixels
	clipboard_mask = saved_mask
	clipboard_changed.emit(clipboard_width, clipboard_height)


func _finish_selection_drag() -> void:
	if editing_disabled or paste_position == selection_move_origin:
		cancel_paste()
	else:
		commit_paste()


func _transform_clipboard_mask(operation: int) -> void:
	if clipboard_mask.size() != clipboard_pixels.size():
		return

	var values := PackedInt32Array(Array(clipboard_mask))
	match operation:
		0:
			values = rotate_counterclockwise(values, clipboard_width, clipboard_height)
		1:
			values = rotate_counterclockwise(values, clipboard_width, clipboard_height)
			values = flip_horizontal(flip_vertical(values, clipboard_height, clipboard_width), clipboard_height, clipboard_width)
		2:
			values = flip_horizontal(values, clipboard_width, clipboard_height)
		3:
			values = flip_vertical(values, clipboard_width, clipboard_height)
	clipboard_mask = PackedByteArray(Array(values))


func _clipboard_contains(offset: int) -> bool:
	return clipboard_mask.size() != clipboard_pixels.size() or clipboard_mask[offset] != 0


func _floating_pixels() -> PackedInt32Array:
	var result := pixels.duplicate()
	if not paste_active:
		return result
	if paste_new_layer:
		result.fill(-1)

	if paste_clear_source and paste_source_mask.size() == result.size():
		for offset in result.size():
			if paste_source_mask[offset] != 0:
				result[offset] = paint_options.paint_index(result[offset], -1)
	for y in clipboard_height:
		for x in clipboard_width:
			var source := y * clipboard_width + x
			var target := paste_position + Vector2i(x, y)
			if not _point_is_valid(target) or not _clipboard_contains(source):
				continue
			var offset := target.y * sprite_width + target.x
			if edit_mask.size() == result.size() and edit_mask[offset] == 0:
				continue
			result[offset] = clipboard_pixels[source] if paste_new_layer else paint_options.paint_index(pixels[offset], clipboard_pixels[source])
	return result


func _commit_changed_pixels(changed: PackedInt32Array, description: String) -> void:
	if changed == pixels:
		return

	edit_started.emit(description)
	pixels = changed
	pixels_committed.emit(pixels.duplicate())
	queue_redraw()


func _scroll_canvas(delta: Vector2, position: Vector2, zoom_modifier: bool) -> void:
	if zoom_modifier:
		scroll_zoom_delta -= delta.y if delta.y != 0.0 else delta.x
		var steps := int(scroll_zoom_delta)
		if steps != 0:
			scroll_zoom_delta -= steps
			zoom_requested.emit(steps, position)
	else:
		scroll_zoom_delta = 0.0
		pan_requested.emit(-delta * SCROLL_PAN_STEP)


func _handle_editor_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return _handle_editor_key(event)

	if event is InputEventPanGesture:
		_scroll_canvas(event.delta, event.position, event.ctrl_pressed or event.meta_pressed)
		return true

	if event is InputEventMouseMotion:
		if panning:
			if event.button_mask & pan_button_mask:
				pan_requested.emit(event.relative)
				return true
			_stop_panning()
		var point := _point_from_position(event.position)
		if paste_active:
			if paste_dragging and not (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if selection_move_dragging:
					_finish_selection_drag()
				else:
					commit_paste()
				return true
			if paste_dragging:
				paste_position = point - paste_drag_offset
			elif paste_follow_cursor:
				paste_position = point
			hover_point = point
			queue_redraw()
			return true
		if selection_dragging:
			selection_finish = point
			if tool == TOOL_SELECT_LASSO:
				selection_path.append(Vector2(point))
			_update_selection_preview()
			return true
		return false

	if not event is InputEventMouseButton:
		return false

	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if event.pressed:
			var direction := Vector2.ZERO
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					direction = Vector2.UP
				MOUSE_BUTTON_WHEEL_DOWN:
					direction = Vector2.DOWN
				MOUSE_BUTTON_WHEEL_LEFT:
					direction = Vector2.LEFT
				MOUSE_BUTTON_WHEEL_RIGHT:
					direction = Vector2.RIGHT
			_scroll_canvas(direction * event.factor, event.position, event.ctrl_pressed or event.meta_pressed)
		return true
	if event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and (space_pressed or Input.is_key_pressed(KEY_SPACE) or panning)):
		panning = event.pressed
		if panning:
			_finish_stroke()
			pan_button_mask = MOUSE_BUTTON_MASK_MIDDLE if event.button_index == MOUSE_BUTTON_MIDDLE else MOUSE_BUTTON_MASK_LEFT
			if is_inside_tree():
				grab_focus()
		else:
			pan_button_mask = 0
		mouse_default_cursor_shape = Control.CURSOR_DRAG if panning else Control.CURSOR_ARROW
		return true
	if event.pressed and is_inside_tree():
		grab_focus()
	var point := _point_from_position(event.position)
	if event.button_index == MOUSE_BUTTON_RIGHT and tool in [TOOL_SELECT_RECT, TOOL_SELECT_LASSO, TOOL_SELECT_WAND, TOOL_MOVE]:
		if event.pressed:
			cancel_paste()
			clear_selection()
		return true
	if paste_active and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			cancel_paste()
		return true
	if event.alt_pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var picked := display_pixel_at(point)
		if event.pressed and picked >= 0:
			palette_index_picked.emit(picked, event.button_index == MOUSE_BUTTON_RIGHT)
		return true
	if event.button_index != MOUSE_BUTTON_LEFT:
		return editing_disabled and tool != TOOL_EYEDROPPER
	if paste_active:
		if selection_move_dragging:
			if not event.pressed:
				paste_position = point - paste_drag_offset
				_finish_selection_drag()
		elif event.pressed:
			if paste_follow_cursor:
				paste_position = point
			paste_dragging = true
			paste_follow_cursor = false
			paste_drag_offset = point - paste_position
		elif paste_dragging:
			paste_position = point - paste_drag_offset
			commit_paste()
		return true
	if tool == TOOL_MOVE:
		if event.pressed and selection.contains(point) and _begin_selection_move(false):
			selection_move_dragging = true
			selection_move_origin = paste_position
			paste_dragging = true
			paste_drag_offset = point - paste_position
		return true
	if tool in [TOOL_SELECT_RECT, TOOL_SELECT_LASSO, TOOL_SELECT_WAND]:
		if event.pressed:
			selection_mode = ScurkSelection.SUBTRACT if event.ctrl_pressed or event.meta_pressed else (ScurkSelection.ADD if event.shift_pressed else ScurkSelection.REPLACE)
			if selection_mode == ScurkSelection.REPLACE and selection.active() and selection.contains(point):
				if _begin_selection_move(false):
					selection_move_dragging = true
					selection_move_origin = paste_position
					paste_dragging = true
					paste_drag_offset = point - paste_position
				return true
			selection_start = point
			selection_finish = point
			selection_path = PackedVector2Array([Vector2(point)])
			if tool == TOOL_SELECT_WAND:
				selection.combine(selection.wand(pixels, point), selection_mode)
				selection_changed.emit()
			else:
				selection_dragging = true
				_update_selection_preview()
		elif selection_dragging:
			selection_finish = point
			if tool == TOOL_SELECT_LASSO:
				selection_path.append(Vector2(point))
			_update_selection_preview()
			selection.combine(selection_preview, selection_mode)
			selection_dragging = false
			selection_preview.clear()
			selection_changed.emit()
		queue_redraw()
		return true
	return editing_disabled and tool != TOOL_EYEDROPPER


func _handle_editor_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_SPACE:
		space_pressed = event.pressed
		return true
	if event.keycode == KEY_BACKSLASH:
		comparison_hold = event.pressed
		queue_redraw()
		return true
	if not event.pressed:
		return false

	var command := event.ctrl_pressed or event.meta_pressed
	if event.keycode == KEY_ESCAPE:
		if paste_active:
			cancel_paste()
		elif selection.active() or selection_dragging:
			clear_selection()
		else:
			return false
		return true
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and paste_active:
		commit_paste()
		return true
	if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and (selection.active() or paste_active):
		var directions := {KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN}
		nudge_selection(directions[event.keycode] * (10 if event.shift_pressed else 1))
		return true
	if event.keycode in [KEY_DELETE, KEY_BACKSPACE] and selection.active():
		delete_selection()
		return true
	if command and event.echo and event.keycode in [KEY_X, KEY_C, KEY_V]:
		return true
	if command:
		match event.keycode:
			KEY_A:
				if event.shift_pressed:
					clear_selection()
				else:
					select_all()
			KEY_C:
				if event.shift_pressed:
					copy_all_layers_requested.emit(false)
				else:
					copy_selection()
			KEY_X:
				if event.shift_pressed:
					copy_all_layers_requested.emit(true)
				else:
					cut_selection()
			KEY_D:
				duplicate_selection()
			KEY_V:
				begin_paste(Vector2i(-1, -1), event.shift_pressed)
			_:
				return false
		return true
	match event.keycode:
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			set_brush(brush_size + (-1 if event.keycode == KEY_BRACKETLEFT else 1), round_brush)
			brush_size_requested.emit(brush_size)
		KEY_X:
			var old_foreground := foreground_index
			set_paint_indices(background_index, old_foreground)
			paint_indices_swap_requested.emit()
		_:
			return false
	return true


func _update_selection_preview() -> void:
	selection_preview = selection.lasso(selection_path) if tool == TOOL_SELECT_LASSO else selection.rectangle(selection_start, selection_finish)
	queue_redraw()


func _draw_selection() -> void:
	var mask := selection_preview if selection_dragging else selection.mask
	var width := sprite_width
	var height := sprite_height
	selection_outline.position = Vector2(DISPLAY_MARGIN, 0)
	if paste_active:
		width = clipboard_width
		height = clipboard_height
		mask = clipboard_mask
		if mask.size() != width * height:
			mask.resize(width * height)
			mask.fill(1)
		selection_outline.position += Vector2(paste_position * zoom)
	if mask.size() != width * height or mask.is_empty():
		selection_outline.configure(PackedVector2Array(), false)
		return

	var state: Array = [hash(mask), width, height, zoom]
	if state != selection_outline_state:
		selection_outline_state = state
		selection_outline_edges.clear()
		var steps := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		var corners := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
		for offset in mask.size():
			if mask[offset] == 0:
				continue
			var point := Vector2i(offset % width, offset / width)
			for edge in 4:
				var neighbor: Vector2i = point + steps[edge]
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < width and neighbor.y < height and mask[neighbor.y * width + neighbor.x] != 0:
					continue
				selection_outline_edges.append((Vector2(point) + corners[edge]) * zoom)
				selection_outline_edges.append((Vector2(point) + corners[(edge + 1) % 4]) * zoom)
	selection_outline.configure(selection_outline_edges, not selection_dragging)


func _draw_guides() -> void:
	if not show_isometric_guides:
		return

	var lines := paint_options.guide_lines(Vector2i(sprite_width, sprite_height))
	if not lines.is_empty():
		for index in lines.size():
			lines[index] *= zoom
		draw_multiline(lines, Color(0.2, 0.8, 1.0, 0.45), 1.0)


func _apply_stamp(point: Vector2i) -> void:
	for y in paint_options.stamp_height:
		for x in paint_options.stamp_width:
			var value := paint_options.stamp_pixels[y * paint_options.stamp_width + x]
			if value >= 0:
				_apply_pixel(point + Vector2i(x, y), value)


func _gui_input(event: InputEvent) -> void:
	if _handle_editor_input(event):
		accept_event()
		return

	if event is InputEventMouseMotion:
		var point := _point_from_position(event.position)

		if point != hover_point:
			hover_point = point
			pointer_changed.emit(point, display_pixel_at(point))
			queue_redraw()

		if stroke_active:
			var expected_mask := (
				MOUSE_BUTTON_MASK_RIGHT
				if stroke_button == MOUSE_BUTTON_RIGHT
				else MOUSE_BUTTON_MASK_LEFT
			)

			if event.button_mask & expected_mask:
				if is_shape_tool(tool):
					_preview_shape(point)
				else:
					_apply_free_line(point)
			else:
				_finish_stroke()

			accept_event()

		return

	if not event is InputEventMouseButton:
		return

	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return

	var point := _point_from_position(event.position)

	if event.pressed:
		if not _point_is_valid(point):
			return

		var use_background: bool = event.button_index == MOUSE_BUTTON_RIGHT

		if tool == TOOL_EYEDROPPER or event.alt_pressed:
			var index := display_pixel_at(point)

			if index >= 0:
				palette_index_picked.emit(index, use_background)
		elif tool == TOOL_FILL:
			_apply_fill(point, use_background)
		elif is_shape_tool(tool):
			_begin_shape(point, event.button_index)
		else:
			_begin_stroke(point, event.button_index)
	else:
		if stroke_active and is_shape_tool(tool) and _point_is_valid(point):
			_preview_shape(point)

		_finish_stroke()

	accept_event()


func _begin_stroke(point: Vector2i, button: int) -> void:
	stroke_active = true
	stroke_changed = false
	stroke_button = button
	stroke_base_pixels = pixels.duplicate()
	pencil_path.clear()
	pencil_path.append(point)
	stamp_distance = 0.0
	shade_visited.clear()
	last_stroke_point = point
	edit_started.emit("Paint")
	_apply_brush(point)


func _begin_shape(point: Vector2i, button: int) -> void:
	stroke_active = true
	stroke_changed = false
	stroke_button = button
	shape_start = snapped_shape_point(
		point, grid_width, grid_height, snap_to_grid
	)
	stroke_base_pixels = pixels.duplicate()
	edit_started.emit("Draw shape")
	_preview_shape(point)


func _apply_free_line(point: Vector2i) -> void:
	if not _point_is_valid(point):
		return

	if not _point_is_valid(last_stroke_point):
		last_stroke_point = point

	var segment := line_points(last_stroke_point, point)
	if tool == TOOL_PENCIL and brush_size == 1 and paint_options.pixel_perfect:
		for line_point in segment:
			if pencil_path.is_empty() or pencil_path[-1] != line_point:
				pencil_path.append(line_point)
		pixels = stroke_base_pixels.duplicate()
		stroke_changed = false
		for line_point in paint_options.pixel_perfect_path(pencil_path):
			_apply_brush(line_point)
	elif tool == TOOL_STAMP:
		for index in range(1, segment.size()):
			stamp_distance += Vector2(segment[index] - segment[index - 1]).length()
			if stamp_distance >= maxi(1, paint_options.stamp_spacing):
				_apply_stamp(segment[index])
				stamp_distance = fmod(stamp_distance, maxi(1, paint_options.stamp_spacing))
	else:
		for line_point in segment:
			_apply_brush(line_point)

	last_stroke_point = point


func _preview_shape(point: Vector2i) -> void:
	if stroke_base_pixels.size() != pixels.size():
		return

	pixels = stroke_base_pixels.duplicate()
	stroke_changed = false
	var finish := snapped_shape_point(
		point, grid_width, grid_height, snap_to_grid
	)
	if tool == TOOL_LINE:
		finish = paint_options.constrain_line(shape_start, finish)

	for shape_point in shape_points(tool, shape_start, finish, filled_shapes):
		_apply_brush(shape_point)

	queue_redraw()


func _apply_brush(point: Vector2i) -> void:
	if tool == TOOL_STAMP:
		_apply_stamp(point)
		return

	var erase := tool == TOOL_ERASER
	var force_background := stroke_button == MOUSE_BUTTON_RIGHT
	for target in brush_points(point):
		var value := (
			-1 if erase else (
				background_index if force_background else texture_color(
					target, foreground_index, background_index,
					texture_patterns[texture_index], 8, 8
				)
			)
		)
		if tool == TOOL_SHADE:
			if shade_visited.has(target):
				continue
			shade_visited[target] = true
			value = paint_options.shade_index(pixel_at(target), -1 if force_background else 0)
		_apply_pixel(target, value)


func brush_points(point: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var low := -((brush_size - 1) / 2)
	var high := low + brush_size - 1
	var center := float(low + high) * 0.5
	var radius := float(brush_size) * 0.5

	for y in range(low, high + 1):
		for x in range(low, high + 1):
			if round_brush and Vector2(x - center, y - center).length() > radius:
				continue

			var target := point + Vector2i(x, y)
			if _point_is_editable(target):
				result.append(target)

	return result


func tool_footprint() -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	if not _point_is_valid(hover_point):
		return result

	if tool == TOOL_FILL:
		if not _point_is_editable(hover_point):
			return result

		var source := pixel_at(hover_point)
		var pending: Array[Vector2i] = [hover_point]
		result[hover_point] = true
		while not pending.is_empty():
			var point: Vector2i = pending.pop_back()
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = point + step
				if not result.has(neighbor) and _point_is_editable(neighbor) and pixel_at(neighbor) == source:
					result[neighbor] = true
					pending.append(neighbor)
	elif tool == TOOL_STAMP:
		for y in paint_options.stamp_height:
			for x in paint_options.stamp_width:
				var target := hover_point + Vector2i(x, y)
				if paint_options.stamp_pixels[y * paint_options.stamp_width + x] >= 0 and _point_is_editable(target):
					result[target] = true
	elif tool in [TOOL_EYEDROPPER, TOOL_SELECT_RECT, TOOL_SELECT_LASSO, TOOL_SELECT_WAND, TOOL_MOVE]:
		result[hover_point] = true
	else:
		var points: Array[Vector2i] = [hover_point]
		if is_shape_tool(tool):
			var finish := snapped_shape_point(hover_point, grid_width, grid_height, snap_to_grid)
			if tool == TOOL_LINE and stroke_active:
				finish = paint_options.constrain_line(shape_start, finish)
			points = shape_points(tool, shape_start if stroke_active else finish, finish, filled_shapes)
		for point in points:
			for target in brush_points(point):
				result[target] = true

	return result


func _draw_tool_outline() -> void:
	var state: Array = [
		hover_point, tool, brush_size, round_brush, filled_shapes, shape_start,
		stroke_active, grid_width, grid_height, snap_to_grid, paint_options.isometric_snap, clipboard_width,
		clipboard_height, clipboard_pixels.size(), sprite_width, sprite_height, pixels, edit_mask, selection.mask,
		paint_options.stamp_width, paint_options.stamp_height, paint_options.stamp_pixels, editing_disabled,
	]
	if state != outline_state:
		outline_state = state
		outline_edges.clear()
		var footprint := tool_footprint()
		var edges := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		var corners := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
		for point in footprint:
			for edge in 4:
				if footprint.has(point + edges[edge]):
					continue

				outline_edges.append(Vector2(point) + corners[edge])
				outline_edges.append(Vector2(point) + corners[(edge + 1) % 4])

	if not outline_edges.is_empty():
		var scaled := PackedVector2Array()
		scaled.resize(outline_edges.size())
		var screen_transform := get_screen_transform()
		var pixel_size := 1.0 / maxf(absf(screen_transform.get_scale().x), 0.001)
		var origin := screen_transform * Vector2(DISPLAY_MARGIN, 0)
		for index in outline_edges.size():
			var screen_point := origin + outline_edges[index] * zoom / pixel_size
			scaled[index] = (screen_point.floor() + Vector2(0.5, 0.5) - origin) * pixel_size
		draw_multiline(scaled, Color.BLACK, 3.0 * pixel_size)
		draw_multiline(scaled, Color.WHITE, pixel_size)


func _apply_pixel(point: Vector2i, value: int) -> void:
	if not _point_is_editable(point):
		return

	var index := point.y * sprite_width + point.x

	value = paint_options.paint_index(pixels[index], value)
	if pixels[index] == value:
		return

	pixels[index] = value
	stroke_changed = true
	queue_redraw()


func _finish_stroke() -> void:
	if not stroke_active:
		return

	stroke_active = false
	stroke_button = MOUSE_BUTTON_NONE
	last_stroke_point = Vector2i(-1, -1)
	shape_start = Vector2i(-1, -1)
	stroke_base_pixels.clear()

	if stroke_changed:
		pixels_committed.emit(pixels.duplicate())
	else:
		edit_cancelled.emit()

	stroke_changed = false


func _apply_fill(point: Vector2i, force_background: bool) -> void:
	if not _point_is_editable(point):
		return

	var fill_source := pixels.duplicate()

	for offset in fill_source.size():
		if not _point_is_editable(Vector2i(offset % sprite_width, offset / sprite_width)):
			fill_source[offset] = -2

	var changed := (
		flood_fill(fill_source, sprite_width, sprite_height, point, background_index)
		if force_background
		else flood_fill_texture(
			fill_source, sprite_width, sprite_height, point,
			foreground_index, background_index,
			texture_patterns[texture_index], 8, 8
		)
	)

	for offset in changed.size():
		changed[offset] = pixels[offset] if fill_source[offset] == -2 else paint_options.paint_index(pixels[offset], changed[offset])

	if changed == pixels:
		return

	edit_started.emit("Fill")
	pixels = changed
	pixels_committed.emit(pixels.duplicate())
	queue_redraw()


static func is_shape_tool(value: int) -> bool:
	return value in [
		TOOL_LINE, TOOL_DIAMOND, TOOL_LEFT_WALL, TOOL_RIGHT_WALL,
		TOOL_ELLIPSE, TOOL_RECTANGLE,
	]


func _point_from_position(position: Vector2) -> Vector2i:
	if zoom <= 0:
		return Vector2i(-1, -1)

	return Vector2i(floori((position.x - DISPLAY_MARGIN) / zoom), floori(position.y / zoom))


func _point_is_valid(point: Vector2i) -> bool:
	return (
		point.x >= 0
		and point.y >= 0
		and point.x < sprite_width
		and point.y < sprite_height
		and pixels.size() == sprite_width * sprite_height
	)


func _point_is_editable(point: Vector2i) -> bool:
	if editing_disabled or not _point_is_valid(point) or not selection.contains(point):
		return false

	return edit_mask.is_empty() or edit_mask[point.y * sprite_width + point.x] != 0


func _enforce_edit_mask() -> void:
	if edit_mask.size() != pixels.size():
		return

	for index in pixels.size():
		if edit_mask[index] == 0:
			pixels[index] = -1


func _update_minimum_size() -> void:
	custom_minimum_size = Vector2(
		maxi(1, sprite_width * zoom) + DISPLAY_MARGIN * 2, maxi(1, sprite_height * zoom)
	)
	reset_size()


func _on_mouse_exited() -> void:
	hover_point = Vector2i(-1, -1)
	pointer_changed.emit(hover_point, -2)
	queue_redraw()


func _draw() -> void:
	if sprite_width <= 0 or sprite_height <= 0:
		selection_outline.configure(PackedVector2Array(), false)
		draw_rect(Rect2(Vector2.ZERO, size), Color("ffffff"), true)

		return

	draw_set_transform(Vector2(DISPLAY_MARGIN, 0))
	_update_display_texture()
	draw_texture_rect(display_texture, Rect2(Vector2.ZERO, Vector2(sprite_width, sprite_height) * zoom), false)
	if show_clip_region and clip_shade_texture != null:
		draw_texture_rect(clip_shade_texture, Rect2(Vector2.ZERO, Vector2(sprite_width, sprite_height) * zoom), false)

	if show_grid:
		var grid_color := Color(0.0, 0.0, 0.0, 0.18)

		if grid_width * zoom >= 4:
			for x in range(0, sprite_width + 1, grid_width):
				draw_line(
					Vector2(x * zoom, 0),
					Vector2(x * zoom, sprite_height * zoom),
					grid_color, 1.0
				)

		if grid_height * zoom >= 4:
			for y in range(0, sprite_height + 1, grid_height):
				draw_line(
					Vector2(0, y * zoom),
					Vector2(sprite_width * zoom, y * zoom),
					grid_color, 1.0
				)

	for guide in clip_guide_rects():
		draw_rect(guide, Color.WHITE, true)

	_draw_selection()
	_draw_guides()
	if not selection_dragging and not paste_active and tool != TOOL_STAMP:
		_draw_tool_outline()


func composite_pixels(include_stamp_preview := false) -> PackedInt32Array:
	var result := _floating_pixels() if paste_active else pixels.duplicate()
	if include_stamp_preview and tool == TOOL_STAMP and not paste_active and not selection_dragging and _point_is_valid(hover_point):
		for y in paint_options.stamp_height:
			for x in paint_options.stamp_width:
				var value := paint_options.stamp_pixels[y * paint_options.stamp_width + x]
				var point := hover_point + Vector2i(x, y)
				if value >= 0 and _point_is_editable(point):
					var offset := point.y * sprite_width + point.x
					result[offset] = paint_options.paint_index(result[offset], value)
	if not active_layer_visible and not paste_new_layer:
		result.fill(-1)
	for offset in result.size():
		if paste_new_layer and active_layer_visible and result[offset] < 0:
			result[offset] = pixels[offset]
		if layer_below_pixels.size() == result.size() and result[offset] < 0:
			result[offset] = layer_below_pixels[offset]
		if layer_above_pixels.size() == result.size() and layer_above_pixels[offset] >= 0:
			result[offset] = layer_above_pixels[offset]
	return result


func _update_display_texture() -> void:
	var valid_palette := palette != null and palette.is_valid()
	var indices := palette.scurk_animation_index_map(palette_cycle_ticks) if valid_palette else PackedInt32Array()
	var background := clear_background_pixels if show_terrain else PackedInt32Array()
	var state: Array = [sprite_width, sprite_height, background_view, hash(pixels), hash(background),
		hash(palette.colors) if valid_palette else 0, hash(indices), hash(layer_below_pixels),
		hash(layer_above_pixels), hash(comparison_pixels), comparison_mode, comparison_hold,
		highlighted_palette_index, paste_active, paste_new_layer, paste_position, hash(clipboard_pixels), hash(clipboard_mask),
		hash(paste_source_mask), paint_options.lock_transparent, hash(selection.mask)]
	state.append_array([active_layer_visible, editing_disabled, selection_dragging, hash(edit_mask),
		tool, hover_point if tool == TOOL_STAMP else Vector2i(-1, -1), paint_options.stamp_width,
		paint_options.stamp_height, hash(paint_options.stamp_pixels)])
	if display_texture != null and display_state == state:
		return

	var visible_pixels := composite_pixels(true)
	var mode := 1 if comparison_hold else comparison_mode
	var comparing := comparison_pixels.size() == visible_pixels.size()
	var colors: Array[Color] = []
	for index in 256:
		colors.append(palette.color(indices[index]) if valid_palette else Color.WHITE)
	var rgba := PackedByteArray()
	rgba.resize(pixels.size() * 4)
	var has_background := background.size() == pixels.size()
	var divisor := ScurkDrawingWorkspace.view_divisor(background_view)
	for offset in pixels.size():
		var artwork_index := comparison_pixels[offset] if mode == 1 and comparing else visible_pixels[offset]
		var index := artwork_index
		if index < 0 and has_background:
			var x := offset % sprite_width
			var y := offset / sprite_width
			var source_x := mini(sprite_width - 1, (x / divisor) * divisor + divisor - 1)
			var source_y := mini(sprite_height - 1, (y / divisor) * divisor + divisor - 1)
			index = background[source_y * sprite_width + source_x]
			if index == BACKGROUND_TRANSPARENT_INDEX:
				index = -1
		var color := colors[index] if index >= 0 else Color.TRANSPARENT
		if comparing and mode == 2 and comparison_pixels[offset] >= 0:
			color = color.lerp(colors[comparison_pixels[offset]], 0.5)
		elif comparing and mode == 3:
			color = Color(1.0, 0.25, 0.7) if visible_pixels[offset] != comparison_pixels[offset] else Color(color.v * 0.4, color.v * 0.4, color.v * 0.4, color.a)
		if highlighted_palette_index >= 0 and artwork_index == highlighted_palette_index:
			color = color.lerp(Color.WHITE, 0.6)
		rgba.encode_u32(offset * 4, color.to_abgr32())
	var image := Image.create_from_data(sprite_width, sprite_height, false, Image.FORMAT_RGBA8, rgba)
	if display_texture == null or display_texture.get_size() != Vector2(sprite_width, sprite_height):
		display_texture = ImageTexture.create_from_image(image)
	else:
		display_texture.update(image)
	display_state = state


func set_background_view(view: int) -> void:
	background_view = clampi(view, ScurkSpriteIds.View.LARGE, ScurkSpriteIds.View.SMALL)
	queue_redraw()


func clip_guide_rects() -> Array[Rect2]:
	if not show_clip_region or clip_columns.x < 0 or clip_columns.y < clip_columns.x:
		return []

	# One display pixel outside each editable column range, including at 1x zoom.
	return [
		Rect2(clip_columns.x * zoom - 1, 0, 1, sprite_height * zoom),
		Rect2((clip_columns.y + 1) * zoom, 0, 1, sprite_height * zoom),
	]
