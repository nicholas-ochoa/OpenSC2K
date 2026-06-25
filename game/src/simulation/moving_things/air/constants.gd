class_name AirThingConstants
extends RefCounted

const MAP_SIZE := CityState.MAP_SIZE
const RECORD_SIZE := CityState.THING_RECORD_SIZE
const TEXT_LABEL_BASE := 201
const TYPE_AIRPLANE := 1
const TYPE_HELICOPTER := 2
const TYPE_EXPLOSION := 6
const SUBTILE_LIMIT := 16
const SOUND_HELICOPTER := 0x1fe
const SOUND_AIR_DISASTER := 0x203
const SOUND_AIRPLANE_TAKEOFF := 0x206
const SOUND_AIRPLANE_LANDING := 0x207
const HELICOPTER_SOUND_DELAY_MSEC := 5000
const EIGHT_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const AIR_ROUTE_DELTAS := [
	Vector2i(0, -3), Vector2i(3, -3), Vector2i(3, 0), Vector2i(3, 3),
	Vector2i(0, 3), Vector2i(-3, 3), Vector2i(-3, 0), Vector2i(-3, -3),
]
const AIR_DIRECTION_OFFSETS := [1, 7, 2, 6, 3, 5, 4]
const THING_SPEEDS := {
	TYPE_AIRPLANE: 16,
	TYPE_HELICOPTER: 8,
}


# final supplied smallmed.dat metadata heights for sprite ids 0x71 through 0xfa
const BUILDING_SPRITE_HEIGHTS := [
	5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 8, 7, 6, 6, 8,
	12, 7, 9, 5, 8, 6, 7, 5, 5, 5, 5, 10, 11, 11, 11, 16,
	14, 20, 20, 9, 11, 11, 12, 12, 14, 19, 17, 19, 22, 11, 11, 11,
	10, 10, 14, 15, 16, 10, 12, 12, 17, 14, 15, 18, 19, 18, 23, 15,
	24, 16, 22, 17, 24, 16, 30, 35, 20, 28, 38, 13, 24, 15, 15, 15,
	13, 21, 17, 18, 24, 9, 9, 11, 23, 29, 21, 20, 24, 18, 28, 18,
	21, 19, 17, 15, 14, 15, 22, 19, 23, 17, 13, 5, 5, 5, 6, 11,
	16, 18, 5, 6, 6, 5, 5, 6, 6, 5, 17, 10, 11, 10, 10, 10,
	14, 9, 10, 10, 14, 10, 13, 14, 13, 16,
]
