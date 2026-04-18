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
	1: true,
	3: true,
	15: true,
	17: true,
	19: true,
	31: true,
	33: true,
	35: true,
	47: true,
	68: true,
	69: true,
	70: true,
	71: true,
}
const HORIZONTAL_TERRAIN_BLOCKS := {
	2: true,
	4: true,
	15: true,
	18: true,
	20: true,
	31: true,
	34: true,
	36: true,
	47: true,
	68: true,
	69: true,
	70: true,
	71: true,
}


static func allows_entry(terrain_id: int, direction: int) -> bool:
	return terrain_id >= 0x40 or not ENTRY_BLOCKS_DIRECTION[(terrain_id & 0x0f) * 4 + direction]


static func allows_connection(terrain_id: int, direction: int) -> bool:
	# supplied executable tables 0x004e7c70 and 0x004e7cb8
	if terrain_id < 0 or terrain_id > 71:
		return false

	return not VERTICAL_TERRAIN_BLOCKS.has(terrain_id) if (direction & 1) == 0 else not HORIZONTAL_TERRAIN_BLOCKS.has(terrain_id)


# going downhill isn't just uphill with a minus sign
static func allows_height_step(current_terrain: int, current_height: int, next_terrain: int, next_height: int, keep_straight: bool, rail: bool) -> bool:
	# supplied executable 0x00448f50. preserve its asymmetric tests; this is
	# not a general maximum-height-difference or bridge-clearance rule
	if keep_straight:
		return not rail or next_terrain == 0 or next_height == current_height

	var effective_height: int = current_height + HEIGHT_ADJUSTMENTS[current_terrain & 0x0f]
	var difference := next_height - effective_height

	if HEIGHT_ADJUSTMENTS[next_terrain & 0x0f] != 0 and difference in [0, -2]:
		return false

	return next_terrain != 0 or difference != -1
