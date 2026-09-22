class_name DisasterThingConstants
extends RefCounted

const Landscape = preload("res://src/tools/landscape/landscape_command.gd")
const DisasterMapDamage = preload("res://src/simulation/disasters/disaster_damage.gd")
const MAP_SIZE := CityState.MAP_SIZE
const RECORD_SIZE := CityState.THING_RECORD_SIZE
const FIRST_RECORD := 1
const LAST_RECORD := CityState.THING_COUNT - 1
const TEXT_LABEL_BASE := 201
const TYPE_AIRPLANE := 1
const TYPE_HELICOPTER := 2
const TYPE_MONSTER := 5
const TYPE_EXPLOSION := 6
const TYPE_TORNADO := 15
const MISC_PENDING_DISASTER := 0x0070
const SOUND_EXPLOSION := 0x1f8
const SOUND_MONSTER_DAMAGE := 0x202
const EIGHT_DIRECTIONS := MovingThingMotion.DIRECTIONS
const THING_SPEEDS := {
	TYPE_MONSTER: 8,
	TYPE_TORNADO: 8,
}
