class_name IsometricFloatingOcclusion
extends IsometricConstants
## Occlusion of ships and sailboats. They float on the water, but their sprites
## reach past their tile. Tile painter order alone hides them under later water
## and draws them over the bridge of their own tile. Each sprite column stands on
## the water at its lowest opaque pixel. A static draw hides a column that stands
## under or behind the draw's tile. The water surface hides no column.
## The native painter applies the same rule in `raster.rs`.

@warning_ignore_start("integer_division")

const FLOATING_THING_TYPES := [3, 9]
# sprite offsets of the water surface, shore, map edge and channel artwork of a view
const WATER_SURFACE_FIRST := 270
const WATER_SURFACE_LAST := 290
const VIEW_SPRITE_SPAN := 500


static func is_floating_type(thing_type: int) -> bool:
	return thing_type in FLOATING_THING_TYPES


static func is_water_surface(sprite_id: int) -> bool:
	var offset := sprite_id % VIEW_SPRITE_SPAN

	return offset >= WATER_SURFACE_FIRST and offset <= WATER_SURFACE_LAST


# the row under the lowest opaque pixel of each column, or -1 for an empty column
static func waterline(image: Image) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(image.get_width())
	result.fill(-1)

	for x in image.get_width():
		for y in range(image.get_height() - 1, -1, -1):
			if image.get_pixel(x, y).a > 0.0:
				result[x] = y + 1
				break

	return result


# 1 for each column that stands under or behind `tile`. Column i is at view x
# `origin.x + (i + 0.5) * pixel` and meets the water at view y
# `origin.y + waterline[i] * pixel`, on water at `altitude`
static func hidden_columns(
	waterline_rows: PackedInt32Array,
	origin: Vector2,
	pixel: float,
	configuration: CityViewConfiguration,
	altitude: int,
	map_edge: int,
	tile: Vector2i
) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(waterline_rows.size())
	var ground_x := float(configuration.side_margin + (map_edge + 1) * configuration.half_width)
	var ground_y := float(configuration.top_margin - altitude * configuration.altitude_step)

	for column in waterline_rows.size():
		if waterline_rows[column] < 0:
			continue

		# map x - y and x + y of the point where the column meets the water
		var across := (origin.x + (column + 0.5) * pixel - ground_x) / configuration.half_width
		var along := (origin.y + waterline_rows[column] * pixel - ground_y) / configuration.half_height

		if along + across < 2 * (tile.x + 1) and along - across < 2 * (tile.y + 1):
			result[column] = 1

	return result


# blend `source_rect` of `occluder` into `mask` at `destination`, but only in the
# mask columns that `hidden` marks
static func blend_hidden_columns(
	mask: Image, occluder: Image, source_rect: Rect2i, destination: Vector2i, hidden: PackedByteArray
) -> void:
	var run_start := -1

	for offset in source_rect.size.x + 1:
		var column := destination.x + offset
		var inside := offset < source_rect.size.x and column >= 0 and column < hidden.size() and hidden[column] != 0

		if inside and run_start < 0:
			run_start = offset
		elif not inside and run_start >= 0:
			mask.blend_rect(
				occluder,
				Rect2i(source_rect.position + Vector2i(run_start, 0), Vector2i(offset - run_start, source_rect.size.y)),
				destination + Vector2i(run_start, 0)
			)
			run_start = -1


# the map tile of a painter depth order
static func depth_tile(depth_order: int, map_edge: int) -> Vector2i:
	var y := depth_order % map_edge
	var x := depth_order / map_edge - y

	return Vector2i(x, y)
