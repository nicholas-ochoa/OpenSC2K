class_name QueryConstants
extends RefCounted

const Facilities = preload("res://src/model/facility_metadata.gd")
const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const Presentation = preload("res://src/view/query_presentation.gd")
const FULL_MAP_SIZE := CityState.MAP_SIZE
const DETAIL_MAP_SIZE := 64
const FIRST_MICROSIM_LABEL := 51
const LAST_MICROSIM_LABEL := 200
const FIRST_BUILDING_WITH_UTILITIES := Tiles.SMALL_PARK
const MILITARY_ZONE := Sc2ZoneLayout.MILITARY
const WATER_PUMP := Tiles.WATER_PUMP
const WATER_TOWER := Tiles.WATER_TOWER
const CITY_HALL := Tiles.CITY_HALL
const LIBRARY := Tiles.LIBRARY
const MICROSIM_TYPE_BY_TILE := Facilities.MICROSIM_TYPE_BY_TILE
# the name tables of the native query; see native/core/sim/src/sim/tools/query/strings.rs
static var _strings: Dictionary = NativeCityTools.query_strings()
static var GRADE_NAMES: PackedStringArray = _strings.grade_names
# the executable names unused zones 10 and 11 as Seaport and Airport
static var ZONE_NAMES: PackedStringArray = _strings.zone_names
static var ZONE_DENSITIES: PackedStringArray = _strings.zone_densities
static var UNDERGROUND_NAMES: PackedStringArray = _strings.underground_names
static var FLAG_LABELS: Array = _strings.flag_labels
static var THING_NAMES: PackedStringArray = _strings.thing_names
static var DIRECTION_NAMES: PackedStringArray = _strings.direction_names
