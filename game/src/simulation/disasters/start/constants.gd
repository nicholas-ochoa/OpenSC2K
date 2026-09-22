class_name DisasterStartConstants
extends RefCounted

const DisasterMapDamage = preload("res://src/simulation/disasters/disaster_damage.gd")
const SpecialZoneGrowth = preload("res://src/simulation/growth/special_zone_growth.gd")
const TerrainCommand = preload("res://src/tools/landscape/terrain_command.gd")
const DISASTER_NONE := 0
const DISASTER_FIRE := 1
const DISASTER_FLOOD := 2
const DISASTER_RIOT := 3
const DISASTER_TOXIC_SPILL := 4
const DISASTER_AIR_CRASH := 5
const DISASTER_EARTHQUAKE := 6
const DISASTER_TORNADO := 7
const DISASTER_MONSTER := 8
const DISASTER_MELTDOWN := 9
const DISASTER_MICROWAVE := 10
const DISASTER_VOLCANO := 11
const DISASTER_FIRESTORM := 12
const DISASTER_MASS_RIOTS := 13
const DISASTER_MASS_FLOODS := 14
const DISASTER_POLLUTION := 15
const DISASTER_HURRICANE := 16
const DISASTER_HELICOPTER_CRASH := 17
const DISASTER_PLANE_CRASH := 18
const TYPE_AIRPLANE := Sc2ThingLayout.Type.AIRPLANE
const TYPE_MONSTER := Sc2ThingLayout.Type.MONSTER
const TYPE_EXPLOSION := Sc2ThingLayout.Type.EXPLOSION
const TYPE_TORNADO := Sc2ThingLayout.Type.TORNADO
const TEXT_THING_BASE := 201
const SOUND_SIREN := 520
const SOUND_FLOOD := 511
const SOUND_RIOT := 512
const SOUND_MICROWAVE := 514
const SOUND_EARTHQUAKE := 504
const SOUND_VOLCANO := 507
const SOUND_HURRICANE := 502
const VOLCANO_BUDGET := 25000
const MISC_CITY_CENTER_X := Sc2MiscLayout.CITY_CENTER_X
const MISC_CITY_CENTER_Y := Sc2MiscLayout.CITY_CENTER_Y
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION
const FIRE_SPIRAL_X := [0, 1, 0, -1]
const FIRE_SPIRAL_Y := [-1, 0, 1, 0]
const RIOT_OVERLAY_FORWARD := 0xfd
const RIOT_OVERLAY_REVERSE := 0xfe
const NUCLEAR_POWER_PLANT := BuildingTileIds.NUCLEAR_POWER
const RADIOACTIVITY_TILE := BuildingTileIds.RADIOACTIVE_WASTE
const MICROWAVE_POWER_PLANT := BuildingTileIds.MICROWAVE_POWER
const EIGHT_DIRECTIONS := [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]
const MAP_CHUNK_SIZES := {
	"ALTM": CityState.TILE_COUNT * 2,
	"XBLD": CityState.TILE_COUNT,
	"XTER": CityState.TILE_COUNT,
	"XZON": CityState.TILE_COUNT,
	"XUND": CityState.TILE_COUNT,
	"XBIT": CityState.TILE_COUNT,
	"XTRF": 64 * 64,
	"XTXT": CityState.TILE_COUNT,
	"XLAB": CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE,
	"XMIC": CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE,
	"MISC": Sc2MiscLayout.SIZE,
}
