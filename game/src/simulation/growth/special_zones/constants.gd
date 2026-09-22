class_name SpecialZoneConstants
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const MovingThings = preload("res://src/simulation/moving_things/moving_thing_spawner.gd")
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_MILITARY_BASE_TYPE := Sc2MiscLayout.MILITARY_BASE_TYPE
const MISC_MILITARY_TILE_COUNTS := Sc2MiscLayout.MILITARY_TILE_COUNTS
const MISC_SUBWAY_COUNT := Sc2MiscLayout.SUBWAY_COUNT
const SOUND_SHIP := 517
const SPECIAL_SIMPLE_TILES := [Tiles.CONTROL_TOWER_1, Tiles.CONTROL_TOWER_2, Tiles.SEAPORT_WAREHOUSE, Tiles.AIRPORT_BUILDING_1, Tiles.AIRPORT_BUILDING_2, Tiles.TARMAC, Tiles.FIGHTER_JET, Tiles.HANGAR_1, Tiles.RADAR]
const SPECIAL_TWO_BY_TWO_TILES := [Tiles.PARKING_LOT_1, Tiles.PARKING_LOT_2, Tiles.LOADING_BAY, Tiles.TOP_SECRET, Tiles.CARGO_YARD, Tiles.HANGAR_2]
const CARDINAL_DIRECTIONS := [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
]
const MILITARY_TILE_COUNT_INDEX := Sc2MilitaryLayout.TILE_COUNT_INDEX
