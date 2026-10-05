class_name QueryStrings
extends RefCounted
## The text of the query dialog. The native simulation library holds the
## tables; see native/core/sim/src/sim/tools/query/strings.rs.

static var _strings: Dictionary = NativeCityTools.query_strings()
# the first strict upper bound greater than xbld selects the name index
static var GENERAL_NAME_UPPER_BOUNDS: PackedInt32Array = _strings.general_name_upper_bounds
# tile names by name index
static var TILE_NAMES: PackedStringArray = _strings.tile_names
static var CLEAR_TERRAIN: String = _strings.clear_terrain
static var FRESH_WATER: String = _strings.fresh_water
static var SALT_WATER: String = _strings.salt_water
static var SAILBOAT: String = _strings.sailboat
static var SPORTS: PackedStringArray = _strings.sports
# information lines for each xmic type
static var MICROSIM_LINES: Array = _strings.microsim_lines
const ACTIONS := { "city_analysis": "Analyze", "library_ruminate": "Ruminate" }


static func tile_name(tile_id: int) -> String:
	return NativeCityTools.query_tile_name(tile_id)
