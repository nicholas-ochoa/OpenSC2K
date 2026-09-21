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
const SPECIAL_SIMPLE_TILES := [Tiles.CONTROL_TOWER_ONE, Tiles.CONTROL_TOWER_TWO, Tiles.SEAPORT_WAREHOUSE, Tiles.AIRPORT_BUILDING_ONE, Tiles.AIRPORT_BUILDING_TWO, Tiles.TARMAC, Tiles.FIGHTER_JET, Tiles.HANGAR_ONE, Tiles.RADAR]
const SPECIAL_TWO_BY_TWO_TILES := [Tiles.PARKING_LOT_ONE, Tiles.PARKING_LOT_TWO, Tiles.LOADING_BAY, Tiles.TOP_SECRET, Tiles.CARGO_YARD, Tiles.HANGAR_TWO]
const CARDINAL_DIRECTIONS := [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
]
const MILITARY_TILE_COUNT_INDEX := {
	Tiles.RUNWAY: 1,
	Tiles.RUNWAY_CROSSING: 2,
	Tiles.PARKING_LOT_TWO: 3,
	Tiles.CARGO_YARD: 4,
	Tiles.RADAR: 5,
	Tiles.SEAPORT_WAREHOUSE: 6,
	Tiles.AIRPORT_BUILDING_ONE: 7,
	Tiles.AIRPORT_BUILDING_TWO: 8,
	Tiles.TOP_SECRET: 9,
	Tiles.CRANE: 10,
	Tiles.CONTROL_TOWER_TWO: 11,
	Tiles.FIGHTER_JET: 12,
	Tiles.HANGAR_ONE: 13,
	Tiles.HANGAR_TWO: 14,
	Tiles.MISSILE_SILO: 15,
}
