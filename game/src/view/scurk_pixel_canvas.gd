class_name ScurkPixelCanvas
extends Control

signal edit_started
signal pixels_committed(pixels: PackedInt32Array)
signal palette_index_picked(index: int, background: bool)
signal pointer_changed(point: Vector2i, index: int)

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

const TEXTURE_NAMES := [
	"Solid Foreground",
	"Checker",
	"Dense Checker",
	"Diagonal",
	"Crosshatch",
	"Dots",
	"Vertical Stripes",
	"Horizontal Stripes",
	"Solid Background",
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
var hover_point := Vector2i(-1, -1)
var stroke_active := false
var stroke_changed := false
var stroke_button := MOUSE_BUTTON_NONE
var last_stroke_point := Vector2i(-1, -1)
var shape_start := Vector2i(-1, -1)
var stroke_base_pixels := PackedInt32Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_exited.connect(_on_mouse_exited)


func set_sprite_data(
	width: int, height: int, value_pixels: PackedInt32Array, value_palette: Sc2Palette
) -> void:
	palette = value_palette
	sprite_width = maxi(0, width)
	sprite_height = maxi(0, height)
	pixels = value_pixels.duplicate()
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
	tool = clampi(value, TOOL_PENCIL, TOOL_EYEDROPPER)


func set_paint_indices(foreground: int, background: int) -> void:
	foreground_index = clampi(foreground, 0, 255)
	background_index = clampi(background, 0, 255)


func set_brush(value_size: int, rounded: bool) -> void:
	brush_size = clampi(value_size, 1, 6)
	round_brush = rounded


func set_texture(value: int) -> void:
	texture_index = clampi(value, 0, TEXTURE_ROWS.size() - 1)


func replace_pixels(value_pixels: PackedInt32Array) -> bool:
	if value_pixels.size() != sprite_width * sprite_height:
		return false
	pixels = value_pixels.duplicate()
	queue_redraw()
	return true


func pixel_at(point: Vector2i) -> int:
	if not _point_is_valid(point):
		return -2
	return pixels[point.y * sprite_width + point.x]


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
		or pattern_rows.size() != 8
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
		result[point_index] = pattern_color(
			point, foreground, background, pattern_rows
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var point := _point_from_position(event.position)
		if point != hover_point:
			hover_point = point
			pointer_changed.emit(point, pixel_at(point))
			queue_redraw()
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
	shape_start = point
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
	for shape_point in shape_points(tool, shape_start, point, filled_shapes):
		_apply_brush(shape_point)
	queue_redraw()


func _apply_brush(point: Vector2i) -> void:
	var erase := tool == TOOL_ERASER
	var force_background := stroke_button == MOUSE_BUTTON_RIGHT
	var low := -int((brush_size - 1) / 2)
	var high := low + brush_size - 1
	var brush_center := float(low + high) * 0.5
	var radius := float(brush_size) * 0.5
	for offset_y in range(low, high + 1):
		for offset_x in range(low, high + 1):
			if round_brush and brush_size >= 5:
				var distance := Vector2(
					float(offset_x) - brush_center, float(offset_y) - brush_center
				).length()
				if distance > radius:
					continue
			var target := point + Vector2i(offset_x, offset_y)
			var value := (
				-1
				if erase
				else (
					background_index
					if force_background
					else pattern_color(
						target, foreground_index, background_index,
						TEXTURE_ROWS[texture_index]
					)
				)
			)
			_apply_pixel(target, value)


func _apply_pixel(point: Vector2i, value: int) -> void:
	if not _point_is_valid(point):
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
	var foreground := background_index if force_background else foreground_index
	var background := background_index
	var rows: Array = TEXTURE_ROWS[0] if force_background else TEXTURE_ROWS[texture_index]
	var changed := flood_fill_pattern(
		pixels, sprite_width, sprite_height, point, foreground, background, rows
	)
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
	return Vector2i(floori(position.x / zoom), floori(position.y / zoom))


func _point_is_valid(point: Vector2i) -> bool:
	return (
		point.x >= 0
		and point.y >= 0
		and point.x < sprite_width
		and point.y < sprite_height
		and pixels.size() == sprite_width * sprite_height
	)


func _update_minimum_size() -> void:
	custom_minimum_size = Vector2(
		maxi(1, sprite_width * zoom), maxi(1, sprite_height * zoom)
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
	for y in sprite_height:
		for x in sprite_width:
			var index := pixels[y * sprite_width + x]
			var color := (
				palette.color(index)
				if index >= 0 and palette != null and palette.is_valid()
				else (Color("d8d8d8") if (x + y) % 2 == 0 else Color("ffffff"))
			)
			draw_rect(Rect2(x * zoom, y * zoom, zoom, zoom), color, true)
	if show_grid and zoom >= 6:
		var grid_color := Color(0.0, 0.0, 0.0, 0.18)
		for x in range(sprite_width + 1):
			draw_line(
				Vector2(x * zoom, 0), Vector2(x * zoom, sprite_height * zoom),
				grid_color, 1.0
			)
		for y in range(sprite_height + 1):
			draw_line(
				Vector2(0, y * zoom), Vector2(sprite_width * zoom, y * zoom),
				grid_color, 1.0
			)
	if _point_is_valid(hover_point):
		draw_rect(
			Rect2(hover_point.x * zoom, hover_point.y * zoom, zoom, zoom),
			Color("ffffff"), false, 1.0
		)
		if zoom >= 3:
			draw_rect(
				Rect2(
					hover_point.x * zoom + 1, hover_point.y * zoom + 1,
					zoom - 2, zoom - 2
				),
				Color("000000"), false, 1.0
			)
