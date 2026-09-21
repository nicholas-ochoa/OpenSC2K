class_name IsometricConstants
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const TILE_WIDTH := 32
# 17 pixels of art on a 16-pixel diamond, keep the shared edge
const TILE_HEIGHT := 17
const HALF_WIDTH := 16
const HALF_HEIGHT := 8
const ALTITUDE_STEP := 12
# each bit raises one dry-terrain corner in top, right, bottom, left order
const TERRAIN_SURFACE_CORNER_MASKS: PackedInt32Array = [
	0x0, 0x9, 0x3, 0x6, 0xc, 0xb, 0x7, 0xe,
	0xd, 0x1, 0x2, 0x4, 0x8, 0xf, 0x0,
]
const TOP_MARGIN := 512
const SIDE_MARGIN := 32
const VIEW_SMALL := 0
const VIEW_MEDIUM := 1
const VIEW_LARGE := 2
const IMAGE_SIZE_LARGE := Vector2i(4160, 2944)
const TRAFFIC_SPRITE_OFFSET := 399
const POWER_MARKER_SPRITE_OFFSET := 386
const SPECIAL_OVERLAY_SPRITE_OFFSETS := {
	0xfb: [496],
	0xfc: [492],
	0xfd: [493, 494],
	0xfe: [493, 494],
	0xff: [396, 397, 398, 399],
}
# traffic sprite variant for each xbld id from ROAD_STRAIGHT_1. zero draws no traffic
const TRAFFIC_TILE_FIRST := Tiles.ROAD_STRAIGHT_1
const TRAFFIC_TILE_VARIANTS: PackedInt32Array = [
	# roads
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 2, 1, 2, 1, 2,
	# rail
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	# tunnel entrances
	2, 1, 0, 0,
	# road crossings
	1, 2, 1, 2,
	# rail power crossings
	0, 0,
	# highways and highway crossings
	11, 12, 11, 12, 11, 12, 11, 12,
	# bridges
	13, 13, 13, 13, 13, 13, 13, 13, 0, 0, 0, 0,
	# on-ramps and highway slopes, curves, and intersection
	15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
	# highway bridges
	0, 0,
	# rail subway entrances
	0, 0, 28, 29,
]
const TRAFFIC_HIGH_VARIANTS: PackedInt32Array = [
	0, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41,
	15, 16, 17, 18, 42, 43, 44, 45, 46, 47, 48, 49, 50,
]
const DISPATCH_SPRITE_OFFSETS := {7: 382, 8: 383, 14: 384}
const TEXT_THING_BASE := 201
const THING_SPRITES: PackedInt32Array = [
	0, 1359, 1364, 1369, 1390, 1490, 1387, 1382, 1383,
	1380, 1374, 1374, 1374, 1374, 1384, 1497, 1495,
]
const THING_MINIMUM_VIEW: PackedInt32Array = [0, 0, 2, 0, 0, 0, 1, 0, 0, 2, 2, 2, 2, 3, 0, 0, 2]
const THING_X_DIVISOR: PackedInt32Array = [4, 2, 1]
const THING_Y_DIVISOR: PackedInt32Array = [8, 4, 2]
const SHIP_DIRECTION_POSITION: PackedInt32Array = [1, 2, 3, 4, 3, 2, 1, 0]
const SHIP_DIRECTION_FLIP := [false, false, false, false, true, true, true, false]
const THING_DIRECTION_POSITION: PackedInt32Array = [0, 1, 1, 0]
const THING_DIRECTION_FLIP := [false, false, true, true]
const TRAIN_TILE_VARIANT: PackedInt32Array = [
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 50, 50, 50, 50, 50, 10,
	11, 12, 13, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
]
const TRAIN_TRANSITION_VARIANT: PackedInt32Array = [0, 17, 1, 16, 0, 17, 1, 16]
const TRAIN_SPRITE_POSITION: PackedInt32Array = [
	0, 0, 3, 3, 4, 4, 2, 1, 2, 1, 3, 3, 4, 4, 0, 0, 2, 1,
]
const TRAIN_SPRITE_FLIP := [
	false, true, true, false, false, true, false, false, false,
	false, true, false, false, true, false, true, false, false,
]
const TRAIN_SCREEN_X: PackedInt32Array = [0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0]
const TRAIN_SCREEN_Y: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 8, 8, 6, 6, 0, 0, 0, 6]
const OCCLUSION_CELL_SIZE := 128
const POWER_CROSSING_BASE_TILE := {
	Tiles.ROAD_POWER_CROSSING_1: Tiles.FIRST_ROAD,
	Tiles.ROAD_POWER_CROSSING_2: Tiles.ROAD_STRAIGHT_2,
	Tiles.RAIL_POWER_CROSSING_1: Tiles.RAIL_FIRST,
	Tiles.RAIL_POWER_CROSSING_2: Tiles.RAIL_STRAIGHT_2,
	Tiles.HIGHWAY_POWER_CROSSING_1: Tiles.HIGHWAY_STRAIGHT_1,
	Tiles.HIGHWAY_POWER_CROSSING_2: Tiles.HIGHWAY_STRAIGHT_2,
}
const HIGHWAY_GROUND_SOURCE_OFFSETS := [
	Vector2i(0, 0), Vector2i(0, -1),
	Vector2i(1, -1), Vector2i(1, 0),
]
const MONSTER_UPPER_FIRST_X: PackedInt32Array = [-15, -3]
const MONSTER_UPPER_SECOND_X: PackedInt32Array = [-24, 14]
const MONSTER_UPPER_FIRST_Y: PackedInt32Array = [6, 52]
const MONSTER_UPPER_SECOND_Y: PackedInt32Array = [43, 33]
const MONSTER_LOWER_FIRST_X: PackedInt32Array = [-15, 2]
const MONSTER_LOWER_SECOND_X: PackedInt32Array = [-20, 18]
const MONSTER_LOWER_FIRST_Y: PackedInt32Array = [6, 32]
const MONSTER_LOWER_SECOND_Y: PackedInt32Array = [49, 46]
