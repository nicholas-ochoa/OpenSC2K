class_name DisasterThingConstants
extends RefCounted

const Landscape = preload("res://src/tools/landscape/landscape_command.gd")
const DisasterMapDamage = preload("res://src/simulation/disasters/disaster_damage.gd")
const MAP_SIZE := CityState.MAP_SIZE
const RECORD_SIZE := CityState.THING_RECORD_SIZE
const FIRST_RECORD := 1
const LAST_RECORD := CityState.THING_COUNT - 1
const TEXT_LABEL_BASE := 201
const TYPE_AIRPLANE := Sc2ThingLayout.Type.AIRPLANE
const TYPE_HELICOPTER := Sc2ThingLayout.Type.HELICOPTER
const TYPE_MONSTER := Sc2ThingLayout.Type.MONSTER
const TYPE_EXPLOSION := Sc2ThingLayout.Type.EXPLOSION
const TYPE_TORNADO := Sc2ThingLayout.Type.TORNADO
const MISC_PENDING_DISASTER := Sc2MiscLayout.DISASTER_TYPE
const SOUND_EXPLOSION := 0x1f8
const SOUND_MONSTER_DAMAGE := 0x202
const EIGHT_DIRECTIONS := MovingThingMotion.DIRECTIONS
const THING_SPEEDS := {
	TYPE_MONSTER: 8,
	TYPE_TORNADO: 8,
}
