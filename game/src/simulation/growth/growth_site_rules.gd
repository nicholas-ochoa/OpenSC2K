class_name GrowthSiteRules
extends RefCounted
## Shared corner and power rules for city growth.


# The zone and building corner flags share one byte.
static func set_corners(
	zones: PackedByteArray, position: Vector2i, area: int, rotation: int,
	map_edge: int = 128,
) -> void:
	var far := position + Vector2i(area - 1, area - 1)
	var view := rotation & 3
	var bottom_left := position.x * map_edge + position.y
	var bottom_right := far.x * map_edge + position.y
	var top_left := far.x * map_edge + far.y
	var top_right := position.x * map_edge + far.y
	zones[bottom_left] = (zones[bottom_left] & Sc2ZoneLayout.TYPE_MASK) | Sc2ZoneLayout.CORNER_BOTTOM_LEFT[view]
	zones[bottom_right] = (zones[bottom_right] & Sc2ZoneLayout.TYPE_MASK) | Sc2ZoneLayout.CORNER_BOTTOM_RIGHT[view]
	zones[top_left] = (zones[top_left] & Sc2ZoneLayout.TYPE_MASK) | Sc2ZoneLayout.CORNER_TOP_LEFT[view]
	zones[top_right] = (zones[top_right] & Sc2ZoneLayout.TYPE_MASK) | Sc2ZoneLayout.CORNER_TOP_RIGHT[view]


# Keep the low-edge checks used by city growth.
static func has_power(flags: PackedByteArray, x: int, y: int, map_edge: int = 128) -> bool:
	var index := x * map_edge + y

	if flags[index] & Sc2TileFlags.POWERED:
		return true

	if x > 1 and flags[(x - 1) * map_edge + y] & Sc2TileFlags.POWERED:
		return true

	if y > 1 and flags[x * map_edge + y - 1] & Sc2TileFlags.POWERED:
		return true

	if x < (map_edge - 1) and flags[(x + 1) * map_edge + y] & Sc2TileFlags.POWERED:
		return true

	return y < (map_edge - 1) and (flags[x * map_edge + y + 1] & Sc2TileFlags.POWERED) != 0
