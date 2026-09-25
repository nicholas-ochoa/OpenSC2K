class_name CityViewMode
extends RefCounted


enum Mode {
	NONE = -1, CITY, UNDERGROUND, DENSITY, GROWTH, TRAFFIC, POLLUTION, CRIME,
	POLICE_POWER, FIRE_POWER, LAND_VALUE, WATER, POWER, HEIGHT
}

# string keys for status text, debug output, and dialog options
const KEYS: Array[String] = [
	"city", "underground", "density", "growth", "traffic", "pollution", "crime",
	"police_power", "fire_power", "land_value", "water", "power", "height",
]
# every selectable mode, in view menu ID order
const DISPLAY_MODES: Array[Mode] = [
	Mode.CITY, Mode.UNDERGROUND, Mode.DENSITY, Mode.GROWTH, Mode.TRAFFIC, Mode.POLLUTION, Mode.CRIME,
	Mode.POLICE_POWER, Mode.FIRE_POWER, Mode.LAND_VALUE, Mode.WATER, Mode.POWER, Mode.HEIGHT
]
# isometric data views, in sidebar order
const DATA_MODES: Array[Mode] = [
	Mode.DENSITY, Mode.GROWTH, Mode.TRAFFIC, Mode.POLLUTION, Mode.CRIME,
	Mode.POLICE_POWER, Mode.FIRE_POWER, Mode.LAND_VALUE, Mode.WATER, Mode.POWER, Mode.HEIGHT
]


static func key(mode: Mode) -> String:
	return KEYS[mode] if mode >= 0 and mode < KEYS.size() else ""


static func from_key(value: String) -> Mode:
	var index := KEYS.find(value)

	return index as Mode if index >= 0 else Mode.NONE


# true for the sprite-rendered surface and underground views
static func is_map(mode: Mode) -> bool:
	return mode == Mode.CITY or mode == Mode.UNDERGROUND


# true for the isometric data views
static func is_data(mode: Mode) -> bool:
	return mode >= Mode.DENSITY and mode <= Mode.HEIGHT
