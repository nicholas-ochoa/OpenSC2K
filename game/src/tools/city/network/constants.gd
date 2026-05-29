class_name NetworkConstants
extends RefCounted

const MISC_FUNDS := 0x0014
const MISC_TILE_COUNTS := 0x01f0
const MISC_MILITARY_TILE_COUNTS := 0x0fa8
const MILITARY_ZONE := 7
const FLAG_WATER := 0x04
const FLAG_FLIPPED := 0x02
const FLAG_PIPED := 0x20
const FLAG_POWERABLE := 0x80

const MODE_ROAD := 0
const MODE_RAIL := 1
const MODE_POWER := 2
const MODE_SUBWAY := 3
const MODE_PIPE := 4

const BRIDGE_CANCELLED := -2
const BRIDGE_UNSELECTED := -1
const BRIDGE_WIRE := 0
const BRIDGE_RAIL := 1
const BRIDGE_ROAD_CAUSEWAY := 2
const BRIDGE_ROAD_RAISING := 3
const BRIDGE_ROAD_SUSPENSION := 4

const CONNECTION_LABEL := 0xfa
const CONNECTION_UNSELECTED := -1
const CONNECTION_CANCELLED := 0
const CONNECTION_CONFIRMED := 1
const ROAD_CONNECTION_COST := 1000
const RAIL_CONNECTION_COST := 1500

const BRIDGE_NAMES := [
	"Raised Wires",
	"Rail Bridge",
	"Causeway",
	"Raising Bridge",
	"Suspension Bridge",
]
const BRIDGE_COSTS := [10, 75, 25, 50, 75]
const BRIDGE_MODE_MASKS := [0x1c, 0x02, 0x01]
const BRIDGE_SHORE_DIRECTIONS := [
	0, 2, 4, 8, 1, 6, 12, 9,
	3, 0, 0, 0, 0, 0, 0, 0,
]

const NETWORK_TOOLS := {
	36: MODE_POWER,
	48: MODE_PIPE,
	72: MODE_ROAD,
	84: MODE_RAIL,
	85: MODE_SUBWAY,
}

const NETWORK_SHAPES := [0, 0, 1, 6, 0, 0, 7, 11, 1, 9, 1, 10, 8, 13, 12, 14]
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const TERRAIN_REQUIRES_GRADING := [
	false, false, false, false, false, true, true, true,
	true, true, true, true, true, false, false, false,
]
const TERRAIN_IS_NETWORK_SLOPE := [
	false, true, true, true, true, false, false, false,
	false, true, true, true, true, false, false, false,
]
const TERRAIN_BLOCKS_DIRECTION := NetworkTerrainRules.ENTRY_BLOCKS_DIRECTION
const GRADED_TERRAIN := [
	0, 0, 1, 0,
	0, 0, 0, 0,
	0, 0, 1, 1,
	0, 0, 1, 1,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
	2, 1, 2, 1,
	2, 3, 2, 3,
	4, 3, 4, 3,
	4, 1, 4, 1,
	0, 0, 1, 6,
	0, 0, 7, 11,
	1, 9, 1, 10,
]
const NETWORK_SLOPE_SHAPES := [0, 2, 3, 4, 5]
const MILITARY_TILE_COUNT_INDEX := {
	0xdd: 1,
	0xde: 2,
	0xef: 3,
	0xf2: 4,
	0xea: 5,
	0xe3: 6,
	0xe4: 7,
	0xe5: 8,
	0xf1: 9,
	0xe0: 10,
	0xe2: 11,
	0xe7: 12,
	0xe8: 13,
	0xf6: 14,
	0xf9: 15,
}
