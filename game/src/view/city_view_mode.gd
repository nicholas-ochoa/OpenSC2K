class_name CityViewMode
extends RefCounted


enum Mode { NONE = -1, CITY, UNDERGROUND, LAND_VALUE, POLLUTION, CRIME, WATER, POWER, HEIGHT }


const KEYS: Array[String] = ["city", "underground", "land_value", "pollution", "crime", "water", "power", "height"]
# every selectable mode, in view menu order
const DISPLAY_MODES: Array[Mode] = [
	Mode.CITY, Mode.UNDERGROUND, Mode.LAND_VALUE, Mode.POLLUTION, Mode.CRIME, Mode.WATER, Mode.POWER, Mode.HEIGHT
]
# isometric data views, in sidebar order
const DATA_MODES: Array[Mode] = [Mode.LAND_VALUE, Mode.POLLUTION, Mode.CRIME, Mode.WATER, Mode.POWER, Mode.HEIGHT]


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
	return mode >= Mode.LAND_VALUE and mode <= Mode.HEIGHT
