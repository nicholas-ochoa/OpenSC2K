class_name HighwayConstants
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const GROUP_ROADS := 6
const SUBTOOL_HIGHWAY := 1
const RADIOACTIVITY := Tiles.RADIOACTIVE_WASTE
const SMALL_PARK := Tiles.SMALL_PARK
const STRAIGHT_FIRST := Tiles.HIGHWAY_STRAIGHT_ONE
const STRAIGHT_LAST := Tiles.HIGHWAY_POWER_CROSSING_TWO
const SHAPED_FIRST := Tiles.HIGHWAY_SLOPE_FIRST
const SHAPED_LAST := Tiles.REINFORCED_HIGHWAY_BRIDGE
const FLAG_WATER := 0x04
const CONNECTION_LABEL := 0xfa
const CONNECTION_COST := 1500
const CONNECTION_UNSELECTED := -1
const CONNECTION_CANCELLED := 0
const CONNECTION_CONFIRMED := 1
const BRIDGE_CANCELLED := -2
const BRIDGE_UNSELECTED := -1
const BRIDGE_HIGHWAY := 5
const BRIDGE_REINFORCED := 6
const BRIDGE_COSTS := {BRIDGE_HIGHWAY: 200, BRIDGE_REINFORCED: 300}
const BRIDGE_NAMES := {
	BRIDGE_HIGHWAY: "Highway Bridge",
	BRIDGE_REINFORCED: "Reinforced Bridge",
}

const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SHAPE_BY_CONNECTIONS := [2, 2, 3, 8, 2, 2, 9, 12, 3, 11, 3, 12, 10, 12, 12, 12]
const GRADED_SHAPE_BY_CONNECTIONS := [2, 2, 3, 3, 2, 2, 3, 2, 3, 3, 3, 2, 3, 2, 2, 2]
const EAST_WEST_KIND_CONNECTIONS := [
	false, false, true, false, true, false, true, false, true,
	true, true, true, true, false, true, false, true, false,
]
const NORTH_SOUTH_KIND_CONNECTIONS := [
	false, true, false, true, false, true, false, true, true,
	true, true, true, true, true, false, true, false, false,
]
const BRIDGE_DIRECTION_MASK_BY_LAND := [
	0, 6, 12, 4, 9, 0, 8, 12, 3, 2, 0, 6, 1, 3, 9, 0,
]
const INVALID_TERRAIN_SHAPE := -1
const FLAT_TERRAIN_SHAPE := 0x0f
const FILLED_FLAT_TERRAIN_SHAPE := 0x4000
