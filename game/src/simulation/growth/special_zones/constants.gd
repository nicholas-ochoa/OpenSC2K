class_name SpecialZoneConstants
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const MovingThings = preload("res://src/simulation/moving_things/moving_thing_spawner.gd")
const MISC_TILE_COUNTS := 0x01f0
const MISC_MILITARY_BASE_TYPE := 0x0e4c
const MISC_MILITARY_TILE_COUNTS := 0x0fa8
const MISC_SUBWAY_COUNT := 0x0fe8
const SOUND_SHIP := 517
const CORNER_BOTTOM_LEFT := [0x10, 0x20, 0x40, 0x80]
const CORNER_BOTTOM_RIGHT := [0x20, 0x40, 0x80, 0x10]
const CORNER_TOP_LEFT := [0x40, 0x80, 0x10, 0x20]
const CORNER_TOP_RIGHT := [0x80, 0x10, 0x20, 0x40]
const SPECIAL_SIMPLE_TILES := [Tiles.CONTROL_TOWER_1, Tiles.CONTROL_TOWER_2, Tiles.SEAPORT_WAREHOUSE, Tiles.AIRPORT_BUILDING_1, Tiles.AIRPORT_BUILDING_2, Tiles.TARMAC, Tiles.FIGHTER_JET, Tiles.HANGAR_1, Tiles.RADAR]
const SPECIAL_TWO_BY_TWO_TILES := [Tiles.PARKING_LOT_1, Tiles.PARKING_LOT_2, Tiles.LOADING_BAY, Tiles.TOP_SECRET, Tiles.CARGO_YARD, Tiles.HANGAR_2]
const CARDINAL_DIRECTIONS := [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
]
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
