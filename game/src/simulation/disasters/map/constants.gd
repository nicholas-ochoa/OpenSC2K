class_name DisasterMapConstants
extends RefCounted

const DisasterMapDamage = preload("res://src/simulation/disasters/disaster_damage.gd")
const FIRE_OVERLAY := 0xff
const TOXIC_OVERLAY := 0xfb
const FLOOD_OVERLAY := 0xfc
const RIOT_OVERLAY_FORWARD := 0xfd
const RIOT_OVERLAY_REVERSE := 0xfe
const SOUND_FIRE := 0x1fb
const SOUND_FLOOD := 0x1ff
const SOUND_RIOT := 0x200
const SOUND_HURRICANE := 0x1f6
const SOUND_EARTHQUAKE := 0x1f8
const TYPE_EXPLOSION := 6
const TYPE_POLICE := 7
const TYPE_FIRE_DISPATCH := 8
const TYPE_MILITARY := 14
const TEXT_THING_BASE := 201
const SPECIAL_TOXIC_BUILDINGS := {BuildingTileIds.CHEMICAL_STORAGE_1X1: true, BuildingTileIds.CHEMICAL_PROCESSING_2X2: true, BuildingTileIds.CHEMICAL_PROCESSING_3X3: true}
const CARDINAL_DIRECTIONS := [
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1),
]
const MAP_CHUNK_SIZES := {
	"ALTM": CityState.TILE_COUNT * 2,
	"XBLD": CityState.TILE_COUNT,
	"XTER": CityState.TILE_COUNT,
	"XZON": CityState.TILE_COUNT,
	"XUND": CityState.TILE_COUNT,
	"XBIT": CityState.TILE_COUNT,
	"XTRF": 64 * 64,
	"XVAL": 64 * 64,
	"XTXT": CityState.TILE_COUNT,
	"XLAB": CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE,
	"XMIC": CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE,
	"XTHG": CityState.THING_COUNT * CityState.THING_RECORD_SIZE,
	"XFIR": 32 * 32,
	"MISC": 4800,
}
