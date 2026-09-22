class_name ScurkPixelCanvas
extends Control

@warning_ignore_start("integer_division")

class LoadResult extends RefCounted:
	var ok := false
	var error := ""

	static func failure(message: String) -> LoadResult:
		var result := LoadResult.new()
		result.error = message

		return result


class PixelRegion extends RefCounted:
	var width := 0
	var height := 0
	var pixels := PackedInt32Array()


const PeBitmap = preload("res://src/assets/pe_bitmap_resource.gd")

signal edit_started
signal pixels_committed(pixels: PackedInt32Array)
signal palette_index_picked(index: int, background: bool)
signal pointer_changed(point: Vector2i, index: int)
signal clipboard_changed(width: int, height: int)
signal clipboard_copy_rejected(minimum_span: int)

const MAX_BRUSH_SIZE := 24
const DISPLAY_MARGIN := 1
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
const TOOL_COPY := 10
const TOOL_PASTE := 11
const CYCLE_INTERVAL_SECONDS := Sc2Palette.SCURK_TIMER_INTERVAL_SECONDS
const MINIMUM_COPY_SPAN := 4
const CLEAR_BACKGROUND_RESOURCE_IDS := ScurkGraphics.BACKGROUND_IDS

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
const ORIGINAL_TEXTURE_RESOURCE_IDS := ScurkGraphics.TEXTURE_IDS
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
var copy_active := false
var copy_start := Vector2i(-1, -1)
var copy_finish := Vector2i(-1, -1)
var clipboard_width := 0
var clipboard_height := 0
var clipboard_pixels := PackedInt32Array()
var texture_patterns: Array[PackedInt32Array] = []
var original_textures_loaded := false
var palette_cycle_ticks := 0
var palette_cycle_enabled := true
var palette_cycle_accumulator := 0.0
var edit_mask := PackedByteArray()
var clip_base_size := -1
var show_clip_region := false
var clip_columns := Vector2i(-1, -1)
var background_view := 0
var clear_background_pixels := PackedInt32Array()
var clip_background_pixels: Array[PackedInt32Array] = []
var outline_state: Array = []
var outline_edges := PackedVector2Array()
var display_texture: ImageTexture
var display_state: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_exited.connect(_on_mouse_exited)
	texture_patterns = _fallback_texture_patterns()
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


func set_sprite_data(
	width: int, height: int, value_pixels: PackedInt32Array, value_palette: Sc2Palette
) -> void:
	palette = value_palette
	sprite_width = maxi(0, width)
	sprite_height = maxi(0, height)
	pixels = value_pixels.duplicate()
	_enforce_edit_mask()
	stroke_active = false
	stroke_changed = false
	stroke_base_pixels.clear()
	copy_active = false
	copy_start = Vector2i(-1, -1)
	copy_finish = Vector2i(-1, -1)
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
	tool = clampi(value, TOOL_PENCIL, TOOL_PASTE)
	copy_active = false
	copy_start = Vector2i(-1, -1)
	copy_finish = Vector2i(-1, -1)
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
	queue_redraw()


func clear_edit_region() -> void:
	edit_mask.clear()
	clip_base_size = -1
	clip_columns = Vector2i(-1, -1)
	show_clip_region = false
	queue_redraw()


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
		original_textures_loaded = false
		texture_index = clampi(texture_index, 0, texture_patterns.size() - 1)
		clear_background_pixels.clear()
		clip_background_pixels.clear()
		queue_redraw()
		return

	texture_patterns.clear()

	for pattern in graphics.patterns:
		texture_patterns.append(pattern.duplicate())

	original_textures_loaded = false
	texture_index = clampi(texture_index, 0, texture_patterns.size() - 1)
	clear_background_pixels = graphics.backgrounds[0].duplicate()
	clip_background_pixels.clear()

	for background in graphics.backgrounds.slice(1):
		clip_background_pixels.append(background.duplicate())

	queue_redraw()


func load_original_textures(executable_path: String) -> LoadResult:
	var loaded_patterns: Array[PackedInt32Array] = []
	var loaded_set := PeBitmap.load_numeric_indexed8_many(
		executable_path, ORIGINAL_TEXTURE_RESOURCE_IDS
	)

	if not loaded_set.ok:
		return LoadResult.failure("Cannot load SCURK textures: " + loaded_set.error)

	for index in ORIGINAL_TEXTURE_RESOURCE_IDS.size():
		var resource_id: int = ORIGINAL_TEXTURE_RESOURCE_IDS[index]
		var loaded := loaded_set.entries[index]

		if loaded.width != 8 or loaded.height != 8 or loaded.pixels.size() != 64:
			return LoadResult.failure("SCURK texture %d is not 8 by 8 pixels." % resource_id)

		loaded_patterns.append(loaded.pixels)

	if loaded_patterns.size() != TEXTURE_NAMES.size():
		return LoadResult.failure("The SCURK texture set is incomplete.")

	texture_patterns = loaded_patterns
	original_textures_loaded = true
	texture_index = clampi(texture_index, 0, texture_patterns.size() - 1)
	queue_redraw()

	var result := LoadResult.new()
	result.ok = true
	result.error = ""

	return result


func load_original_clear_backgrounds(executable_path: String) -> LoadResult:
	var loaded_set := PeBitmap.load_numeric_indexed8_many(
		executable_path, CLEAR_BACKGROUND_RESOURCE_IDS
	)

	if not loaded_set.ok:
		return LoadResult.failure("Cannot load SCURK drawing backgrounds: " + loaded_set.error)

	var loaded_backgrounds: Array[PackedInt32Array] = []

	for index in CLEAR_BACKGROUND_RESOURCE_IDS.size():
		var resource_id: int = CLEAR_BACKGROUND_RESOURCE_IDS[index]
		var loaded := loaded_set.entries[index]

		if (
			loaded.width != 128
			or loaded.height != 256
			or loaded.pixels.size() != 128 * 256
		):
			return LoadResult.failure("SCURK drawing background %d is not 128 by 256 pixels."
					% resource_id)

		loaded_backgrounds.append(loaded.pixels)

	clear_background_pixels = loaded_backgrounds[0]
	clip_background_pixels.clear()

	for index in range(1, loaded_backgrounds.size()):
		clip_background_pixels.append(loaded_backgrounds[index])

	queue_redraw()

	var result := LoadResult.new()
	result.ok = true
	result.error = ""

	return result


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


func replace_pixels(value_pixels: PackedInt32Array) -> bool:
	if value_pixels.size() != sprite_width * sprite_height:
		return false

	pixels = value_pixels.duplicate()
	_enforce_edit_mask()
	queue_redraw()

	return true


func pixel_at(point: Vector2i) -> int:
	if not _point_is_valid(point):
		return -2

	return pixels[point.y * sprite_width + point.x]


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

	var old_width := clipboard_width
	clipboard_width = clipboard_height
	clipboard_height = old_width
	clipboard_pixels = rotated
	clipboard_changed.emit(clipboard_width, clipboard_height)
	queue_redraw()


func flip_clipboard_horizontal() -> void:
	if not has_clipboard():
		return

	clipboard_pixels = flip_horizontal(
		clipboard_pixels, clipboard_width, clipboard_height
	)
	clipboard_changed.emit(clipboard_width, clipboard_height)
	queue_redraw()


func flip_clipboard_vertical() -> void:
	if not has_clipboard():
		return

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


static func pattern_color(
	point: Vector2i, foreground: int, background: int, pattern_rows: Array
) -> int:
	if pattern_rows.size() != 8:
		return foreground

	var row_mask := int(pattern_rows[posmod(point.y, 8)])
	var mask := 0x80 >> posmod(point.x, 8)

	return foreground if row_mask & mask else background


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

	return resolve_texture_value(source, foreground, background)


static func resolve_texture_value(source: int, foreground: int, background: int) -> int:
	if source == 0xff:
		return foreground

	if source == 0xf5 or source == 0:
		return background

	return clampi(source, 0, 255)


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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var point := _point_from_position(event.position)

		if point != hover_point:
			hover_point = point
			pointer_changed.emit(point, pixel_at(point))
			queue_redraw()

		if copy_active:
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				if _point_is_valid(point):
					copy_finish = point
					queue_redraw()
			else:
				_finish_copy(copy_finish)

			accept_event()

			return

		if stroke_active:
			var expected_mask := (
				MOUSE_BUTTON_MASK_RIGHT
				if stroke_button == MOUSE_BUTTON_RIGHT
				else MOUSE_BUTTON_MASK_LEFT
			)

			if event.button_mask & expected_mask:
				if _is_shape_tool(tool):
					_preview_shape(point)
				else:
					_apply_free_line(point)
			else:
				_finish_stroke()

			accept_event()

		return

	if not event is InputEventMouseButton:
		return

	if tool == TOOL_COPY:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		var copy_point := _point_from_position(event.position)

		if event.pressed:
			if _point_is_valid(copy_point):
				copy_active = true
				copy_start = copy_point
				copy_finish = copy_point
				queue_redraw()
		else:
			_finish_copy(copy_point if _point_is_valid(copy_point) else copy_finish)

		accept_event()

		return

	if tool == TOOL_PASTE:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var paste_point := _point_from_position(event.position)

			if _point_is_valid(paste_point):
				_apply_clipboard(paste_point)

			accept_event()

		return

	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return

	var point := _point_from_position(event.position)

	if event.pressed:
		if not _point_is_valid(point):
			return

		var use_background: bool = event.button_index == MOUSE_BUTTON_RIGHT

		if tool == TOOL_EYEDROPPER:
			var index := pixel_at(point)

			if index >= 0:
				palette_index_picked.emit(index, use_background)
		elif tool == TOOL_FILL:
			_apply_fill(point, use_background)
		elif _is_shape_tool(tool):
			_begin_shape(point, event.button_index)
		else:
			_begin_stroke(point, event.button_index)
	else:
		if stroke_active and _is_shape_tool(tool) and _point_is_valid(point):
			_preview_shape(point)

		_finish_stroke()

	accept_event()


func _finish_copy(point: Vector2i) -> void:
	if not copy_active:
		return

	copy_active = false

	if _point_is_valid(point):
		copy_finish = point

	if (
		absi(copy_finish.x - copy_start.x) < MINIMUM_COPY_SPAN
		or absi(copy_finish.y - copy_start.y) < MINIMUM_COPY_SPAN
	):
		copy_start = Vector2i(-1, -1)
		copy_finish = Vector2i(-1, -1)
		clipboard_copy_rejected.emit(MINIMUM_COPY_SPAN)
		queue_redraw()

		return

	var copied := copy_region(
		pixels, sprite_width, sprite_height, copy_start, copy_finish
	)
	clipboard_width = copied.width
	clipboard_height = copied.height
	clipboard_pixels = copied.pixels
	copy_start = Vector2i(-1, -1)
	copy_finish = Vector2i(-1, -1)
	clipboard_changed.emit(clipboard_width, clipboard_height)
	queue_redraw()


func _apply_clipboard(point: Vector2i) -> void:
	if not has_clipboard():
		return

	var changed := paste_region(
		pixels, sprite_width, sprite_height, point,
		clipboard_pixels, clipboard_width, clipboard_height
	)

	if edit_mask.size() == changed.size():
		for index in changed.size():
			if edit_mask[index] == 0:
				changed[index] = -1

	if changed == pixels:
		return

	edit_started.emit()
	pixels = changed
	pixels_committed.emit(pixels.duplicate())
	queue_redraw()


func _begin_stroke(point: Vector2i, button: int) -> void:
	stroke_active = true
	stroke_changed = false
	stroke_button = button
	last_stroke_point = point
	edit_started.emit()
	_apply_brush(point)


func _begin_shape(point: Vector2i, button: int) -> void:
	stroke_active = true
	stroke_changed = false
	stroke_button = button
	shape_start = snapped_shape_point(
		point, grid_width, grid_height, snap_to_grid
	)
	stroke_base_pixels = pixels.duplicate()
	edit_started.emit()
	_preview_shape(point)


func _apply_free_line(point: Vector2i) -> void:
	if not _point_is_valid(point):
		return

	if not _point_is_valid(last_stroke_point):
		last_stroke_point = point

	for line_point in line_points(last_stroke_point, point):
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

	for shape_point in shape_points(tool, shape_start, finish, filled_shapes):
		_apply_brush(shape_point)

	queue_redraw()


func _apply_brush(point: Vector2i) -> void:
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
	elif tool == TOOL_PASTE:
		if has_clipboard():
			for y in clipboard_height:
				for x in clipboard_width:
					var target := hover_point + Vector2i(x, y)
					if _point_is_editable(target):
						result[target] = true
	elif tool in [TOOL_COPY, TOOL_EYEDROPPER]:
		result[hover_point] = true
	else:
		var points: Array[Vector2i] = [hover_point]
		if _is_shape_tool(tool):
			var finish := snapped_shape_point(hover_point, grid_width, grid_height, snap_to_grid)
			points = shape_points(tool, shape_start if stroke_active else finish, finish, filled_shapes)
		for point in points:
			for target in brush_points(point):
				result[target] = true

	return result


func _draw_tool_outline() -> void:
	var state: Array = [
		hover_point, tool, brush_size, round_brush, filled_shapes, shape_start,
		stroke_active, grid_width, grid_height, snap_to_grid, clipboard_width,
		clipboard_height, clipboard_pixels.size(), sprite_width, sprite_height, pixels, edit_mask,
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
		for index in outline_edges.size():
			scaled[index] = outline_edges[index] * zoom
		draw_multiline(scaled, Color.BLACK, 3.0)
		draw_multiline(scaled, Color.WHITE, 1.0)


func _apply_pixel(point: Vector2i, value: int) -> void:
	if not _point_is_editable(point):
		return

	var index := point.y * sprite_width + point.x

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

	stroke_changed = false


func _apply_fill(point: Vector2i, force_background: bool) -> void:
	if not _point_is_editable(point):
		return

	var fill_source := pixels.duplicate()

	if edit_mask.size() == fill_source.size():
		for index in fill_source.size():
			if edit_mask[index] == 0:
				fill_source[index] = -2

	var changed := (
		flood_fill(fill_source, sprite_width, sprite_height, point, background_index)
		if force_background
		else flood_fill_texture(
			fill_source, sprite_width, sprite_height, point,
			foreground_index, background_index,
			texture_patterns[texture_index], 8, 8
		)
	)

	if edit_mask.size() == changed.size():
		for index in changed.size():
			if edit_mask[index] == 0:
				changed[index] = -1

	if changed == pixels:
		return

	edit_started.emit()
	pixels = changed
	pixels_committed.emit(pixels.duplicate())
	queue_redraw()


func _is_shape_tool(value: int) -> bool:
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
	if not _point_is_valid(point):
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
		draw_rect(Rect2(Vector2.ZERO, size), Color("ffffff"), true)

		return

	draw_set_transform(Vector2(DISPLAY_MARGIN, 0))
	_update_display_texture()
	draw_texture_rect(display_texture, Rect2(Vector2.ZERO, Vector2(sprite_width, sprite_height) * zoom), false)

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

	if copy_active and _point_is_valid(copy_start) and _point_is_valid(copy_finish):
		var minimum := Vector2i(
			mini(copy_start.x, copy_finish.x), mini(copy_start.y, copy_finish.y)
		)
		var maximum := Vector2i(
			maxi(copy_start.x, copy_finish.x), maxi(copy_start.y, copy_finish.y)
		)
		var selection := Rect2(
			Vector2(minimum * zoom), Vector2((maximum - minimum + Vector2i.ONE) * zoom)
		)
		draw_rect(selection, Color.WHITE, false, 2.0)
		draw_rect(selection.grow(-1.0), Color.BLACK, false, 1.0)

	if not copy_active:
		_draw_tool_outline()


func _update_display_texture() -> void:
	var valid_palette := palette != null and palette.is_valid()
	var indices := palette.scurk_animation_index_map(palette_cycle_ticks) if valid_palette else PackedInt32Array()
	var background := clear_background_pixels
	var state: Array = [sprite_width, sprite_height, background_view, hash(pixels), hash(background),
		hash(palette.colors) if valid_palette else 0, hash(indices)]
	if display_texture != null and display_state == state:
		return

	var colors := PackedInt64Array()
	colors.resize(256)
	for index in 256:
		colors[index] = palette.color(indices[index]).to_abgr32() if valid_palette else Color.WHITE.to_abgr32()
	var rgba := PackedByteArray()
	rgba.resize(pixels.size() * 4)
	var has_background := background.size() == pixels.size()
	var divisor := ScurkDrawingWorkspace.view_divisor(background_view)
	for offset in pixels.size():
		var index := pixels[offset]
		if index < 0 and has_background:
			var x := offset % sprite_width
			var y := offset / sprite_width
			var source_x := mini(sprite_width - 1, (x / divisor) * divisor + divisor - 1)
			var source_y := mini(sprite_height - 1, (y / divisor) * divisor + divisor - 1)
			index = background[source_y * sprite_width + source_x]
			if index == BACKGROUND_TRANSPARENT_INDEX:
				index = -1
		var color := colors[index] if index >= 0 else 0
		rgba.encode_u32(offset * 4, color)
	var image := Image.create_from_data(sprite_width, sprite_height, false, Image.FORMAT_RGBA8, rgba)
	if display_texture == null or display_texture.get_size() != Vector2(sprite_width, sprite_height):
		display_texture = ImageTexture.create_from_image(image)
	else:
		display_texture.update(image)
	display_state = state


func set_background_view(view: int) -> void:
	background_view = clampi(view, 0, 2)
	queue_redraw()


func clip_guide_rects() -> Array[Rect2]:
	if not show_clip_region or clip_columns.x < 0 or clip_columns.y < clip_columns.x:
		return []

	# One display pixel outside each editable column range, including at 1x zoom.
	return [
		Rect2(clip_columns.x * zoom - 1, 0, 1, sprite_height * zoom),
		Rect2((clip_columns.y + 1) * zoom, 0, 1, sprite_height * zoom),
	]
