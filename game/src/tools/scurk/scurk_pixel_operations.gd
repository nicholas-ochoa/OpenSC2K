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


# The native formats library holds the pixel rules; see
# native/core/assets/src/scurk/pixels.rs
static func copy_region(
	value_pixels: PackedInt32Array,
	width: int,
	height: int,
	start: Vector2i,
	finish: Vector2i
) -> PixelRegion:
	var copied := NativeScurkPixels.copy_region(value_pixels, width, height, start, finish)
	var result := PixelRegion.new()
	result.width = copied.width
	result.height = copied.height
	result.pixels = copied.pixels

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
	return NativeScurkPixels.paste_region(
		target_pixels, target_width, target_height, target, source_pixels, source_width, source_height
	)


static func rotate_counterclockwise(
	value_pixels: PackedInt32Array, width: int, height: int
) -> PackedInt32Array:
	return NativeScurkPixels.rotate_counterclockwise(value_pixels, width, height)


static func flip_horizontal(
	value_pixels: PackedInt32Array, width: int, height: int
) -> PackedInt32Array:
	return NativeScurkPixels.flip_horizontal(value_pixels, width, height)


static func flip_vertical(
	value_pixels: PackedInt32Array, width: int, height: int
) -> PackedInt32Array:
	return NativeScurkPixels.flip_vertical(value_pixels, width, height)


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

	var pattern := NativeScurkPixels.pattern_pixels(PackedByteArray(pattern_rows))

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
	return NativeScurkPixels.flood_fill_texture(
		value_pixels, width, height, start, selected_color, pattern_pixels, pattern_width, pattern_height
	)


static func texture_color(
	point: Vector2i,
	selected_color: int,
	pattern_pixels: PackedInt32Array,
	pattern_width: int,
	pattern_height: int
) -> int:
	return NativeScurkPixels.texture_color(point, selected_color, pattern_pixels, pattern_width, pattern_height)


static func line_points(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	return _points(NativeScurkPixels.line_points(start, finish))


static func _points(flat: PackedInt64Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for index in range(0, flat.size(), 2):
		result.append(Vector2i(flat[index], flat[index + 1]))

	return result


class PixelRegion extends RefCounted:
	var width := 0
	var height := 0
	var pixels := PackedInt32Array()
