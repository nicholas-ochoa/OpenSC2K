class_name NetworkConstants
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

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
# one row per current terrain shape, one column per DIRECTIONS index (N, E, S, W).
# only rows where TERRAIN_IS_NETWORK_SLOPE is true are read
const GRADED_TERRAIN := [
	# FLAT
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.SLOPE_TOP_LEFT, TerrainTileIds.FLAT,
	# SLOPE_TOP_LEFT
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT,
	# SLOPE_TOP_RIGHT
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.SLOPE_TOP_LEFT, TerrainTileIds.SLOPE_TOP_LEFT,
	# SLOPE_BOTTOM_RIGHT
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.SLOPE_TOP_LEFT, TerrainTileIds.SLOPE_TOP_LEFT,
	# SLOPE_BOTTOM_LEFT
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT,
	# RAISED_EXCEPT_BOTTOM
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT,
	# RAISED_EXCEPT_LEFT
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT,
	# RAISED_EXCEPT_TOP
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT,
	# RAISED_EXCEPT_RIGHT
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.FLAT,
	# CORNER_TOP
	TerrainTileIds.SLOPE_TOP_RIGHT, TerrainTileIds.SLOPE_TOP_LEFT, TerrainTileIds.SLOPE_TOP_RIGHT, TerrainTileIds.SLOPE_TOP_LEFT,
	# CORNER_RIGHT
	TerrainTileIds.SLOPE_TOP_RIGHT, TerrainTileIds.SLOPE_BOTTOM_RIGHT, TerrainTileIds.SLOPE_TOP_RIGHT, TerrainTileIds.SLOPE_BOTTOM_RIGHT,
	# CORNER_BOTTOM
	TerrainTileIds.SLOPE_BOTTOM_LEFT, TerrainTileIds.SLOPE_BOTTOM_RIGHT, TerrainTileIds.SLOPE_BOTTOM_LEFT, TerrainTileIds.SLOPE_BOTTOM_RIGHT,
	# CORNER_LEFT
	TerrainTileIds.SLOPE_BOTTOM_LEFT, TerrainTileIds.SLOPE_TOP_LEFT, TerrainTileIds.SLOPE_BOTTOM_LEFT, TerrainTileIds.SLOPE_TOP_LEFT,
	# RAISED
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.SLOPE_TOP_LEFT, TerrainTileIds.RAISED_EXCEPT_LEFT,
	# UNUSED_0E
	TerrainTileIds.FLAT, TerrainTileIds.FLAT, TerrainTileIds.RAISED_EXCEPT_TOP, TerrainTileIds.CORNER_BOTTOM,
	# UNUSED_0F
	TerrainTileIds.SLOPE_TOP_LEFT, TerrainTileIds.CORNER_TOP, TerrainTileIds.SLOPE_TOP_LEFT, TerrainTileIds.CORNER_RIGHT,
]
const NETWORK_SLOPE_SHAPES := [0, 2, 3, 4, 5]
const MILITARY_TILE_COUNT_INDEX := {
	Tiles.RUNWAY: 1,
	Tiles.RUNWAY_CROSSING: 2,
	Tiles.PARKING_LOT_2: 3,
	Tiles.CARGO_YARD: 4,
	Tiles.RADAR: 5,
	Tiles.SEAPORT_WAREHOUSE: 6,
	Tiles.AIRPORT_BUILDING_1: 7,
	Tiles.AIRPORT_BUILDING_2: 8,
	Tiles.TOP_SECRET: 9,
	Tiles.CRANE: 10,
	Tiles.CONTROL_TOWER_2: 11,
	Tiles.FIGHTER_JET: 12,
	Tiles.HANGAR_1: 13,
	Tiles.HANGAR_2: 14,
	Tiles.MISSILE_SILO: 15,
}
