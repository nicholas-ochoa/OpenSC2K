class_name ScurkPixelOperations
extends RefCounted

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
		value_pixels, width, height, start, replacement,
		TEXTURE_ROWS[0]
	)


static func flood_fill_pattern(
	value_pixels: PackedInt32Array,
	width: int,
	height: int,
	start: Vector2i,
	selected_color: int,
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
		value_pixels, width, height, start, selected_color, pattern, 8, 8
	)


static func flood_fill_texture(
	value_pixels: PackedInt32Array,
	width: int,
	height: int,
	start: Vector2i,
	selected_color: int,
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
		or selected_color < -1
		or selected_color > 255
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
			point, selected_color,
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
	selected_color: int,
	pattern_pixels: PackedInt32Array,
	pattern_width: int,
	pattern_height: int
) -> int:
	if (
		pattern_width <= 0
		or pattern_height <= 0
		or pattern_pixels.size() != pattern_width * pattern_height
	):
		return selected_color

	var source := pattern_pixels[
		posmod(point.y, pattern_height) * pattern_width
		+ posmod(point.x, pattern_width)
	]

	return ScurkPaintOptions.resolve_texture_value(source, selected_color)


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


class PixelRegion extends RefCounted:
	var width := 0
	var height := 0
	var pixels := PackedInt32Array()
