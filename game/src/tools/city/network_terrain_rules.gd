class_name NetworkTerrainRules
extends RefCounted
# original ground-network terrain rules. these do not define network identity,
# saved connection permissions, bridge clearance, or an elevated deck height

const HEIGHT_ADJUSTMENTS := [0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0]
const ENTRY_BLOCKS_DIRECTION := [
	false, false, false, false,
	true, false, true, false,
	false, true, false, true,
	true, false, true, false,
	false, true, false, true,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	false, false, false, false,
	true, false, true, false,
	true, false, true, false,
]

const VERTICAL_TERRAIN_BLOCKS := {
	TerrainTileIds.SLOPE_TOP_LEFT: true,
	TerrainTileIds.SLOPE_BOTTOM_RIGHT: true,
	TerrainTileIds.UNUSED_0F: true,
	TerrainTileIds.DEEP_WATER_SLOPE_TOP_LEFT: true,
	TerrainTileIds.DEEP_WATER_SLOPE_BOTTOM_RIGHT: true,
	TerrainTileIds.UNUSED_1F: true,
	TerrainTileIds.SHORE_SLOPE_TOP_LEFT: true,
	TerrainTileIds.SHORE_SLOPE_BOTTOM_RIGHT: true,
	TerrainTileIds.UNUSED_2F: true,
	TerrainTileIds.CHANNEL_W: true,
	TerrainTileIds.CHANNEL_N: true,
	TerrainTileIds.UNUSED_46: true,
	TerrainTileIds.UNUSED_47: true,
}
const HORIZONTAL_TERRAIN_BLOCKS := {
	TerrainTileIds.SLOPE_TOP_RIGHT: true,
	TerrainTileIds.SLOPE_BOTTOM_LEFT: true,
	TerrainTileIds.UNUSED_0F: true,
	TerrainTileIds.DEEP_WATER_SLOPE_TOP_RIGHT: true,
	TerrainTileIds.DEEP_WATER_SLOPE_BOTTOM_LEFT: true,
	TerrainTileIds.UNUSED_1F: true,
	TerrainTileIds.SHORE_SLOPE_TOP_RIGHT: true,
	TerrainTileIds.SHORE_SLOPE_BOTTOM_LEFT: true,
	TerrainTileIds.UNUSED_2F: true,
	TerrainTileIds.CHANNEL_W: true,
	TerrainTileIds.CHANNEL_N: true,
	TerrainTileIds.UNUSED_46: true,
	TerrainTileIds.UNUSED_47: true,
}


static func allows_entry(terrain_id: int, direction: int) -> bool:
	return terrain_id >= TerrainTileIds.CHANNEL_FIRST or not ENTRY_BLOCKS_DIRECTION[(terrain_id & TerrainTileIds.SHAPE_MASK) * 4 + direction]


static func allows_connection(terrain_id: int, direction: int) -> bool:
	# supplied executable tables 0x004e7c70 and 0x004e7cb8
	if terrain_id < TerrainTileIds.FLAT or terrain_id > TerrainTileIds.UNUSED_47:
		return false

	return not VERTICAL_TERRAIN_BLOCKS.has(terrain_id) if (direction & 1) == 0 else not HORIZONTAL_TERRAIN_BLOCKS.has(terrain_id)


# going downhill isn't just uphill with a minus sign
static func allows_height_step(current_terrain: int, current_height: int, next_terrain: int, next_height: int, keep_straight: bool, rail: bool) -> bool:
	# supplied executable 0x00448f50. preserve its asymmetric tests; this is
	# not a general maximum-height-difference or bridge-clearance rule
	if keep_straight:
		return not rail or next_terrain == TerrainTileIds.FLAT or next_height == current_height

	var effective_height: int = current_height + HEIGHT_ADJUSTMENTS[current_terrain & TerrainTileIds.SHAPE_MASK]
	var difference := next_height - effective_height

	if HEIGHT_ADJUSTMENTS[next_terrain & TerrainTileIds.SHAPE_MASK] != 0 and difference in [0, -2]:
		return false

	return next_terrain != TerrainTileIds.FLAT or difference != -1
