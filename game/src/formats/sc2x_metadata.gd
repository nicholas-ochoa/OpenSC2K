class_name Sc2xMetadata
extends RefCounted
## metadata.json of an SC2X version 4 archive: the file contract, the map edge,
## the shared names, the identity counters, and the simulation state that no
## binary structure saves. MISC stays authoritative for the values it holds.
## The native simulation library checks the rules and writes the text; see
## native/core/sim/src/formats/sc2x/metadata.rs.

const FORMAT := "OpenSC2K.SC2X"
const FILE_VERSION := 4
const SCHEMA_PATH := "res://assets/data/sc2x-metadata.schema.json"
const MAX_NAME_CODE_POINTS := 64
const TEAM_COUNT := 5
# simulation.phase_state keys; see Sc2xCheckpoint
const PHASE_KEYS: PackedStringArray = [
	"ship_home", "commerce_connections", "industry_connections",
	"bus_passengers", "rail_passengers", "subway_passengers", "mayor_approval",
	"pending_disaster_type", "pending_disaster_point", "active_disaster_type", "unsupported_disaster_type",
	"disaster_map_counter", "disaster_hurricane_counter", "terminal_state",
	"subtick_counter", "simulation_ready",
	"developed_tiles", "power_usage_percent", "water_usage_percent", "city_status_resource_id",
]
# optional phase_state key: milliseconds of the fire timer, 0 through 1000.
# Files without it resume with a new timer.
const FIRE_TIMER_KEY := "fire_elapsed_msec"
# optional phase_state key: true while a staged arcology launch has batches
# left. Files without it have no launch in progress.
const LAUNCH_ACTIVE_KEY := "arcology_launch_active"
# additional capabilities that this version supports. File version 4 itself needs none.
const SUPPORTED_FEATURES: PackedStringArray = []

var map_size := 128
var city_name := ""
var mayor_name := ""
var stadium_teams := PackedStringArray(["", "", "", "", ""])
var next_sign_id := 1
var next_object_id := 1
var process_random := 1
var lfsr_random := 1
var game_random := 1
var phase_state: Dictionary = {}
var required_features := PackedStringArray()
var legacy: Dictionary = {}
var extensions: Dictionary = {}


func copy() -> Sc2xMetadata:
	return from_fields(to_fields())


# The features that a document requires but this version does not support.
# Such a document can be inspected but not edited or simulated.
func unsupported_features() -> PackedStringArray:
	var result := PackedStringArray()

	for feature in required_features:
		if not SUPPORTED_FEATURES.has(feature):
			result.append(feature)

	return result


func to_dictionary() -> Dictionary:
	return NativeCityDocument.metadata_dictionary(to_fields())


# UTF-8 JSON with a fixed key order and tab indentation
func to_json() -> String:
	return NativeCityDocument.metadata_json(to_fields())


func to_bytes() -> PackedByteArray:
	return to_json().to_utf8_buffer()


# The fields that the native library reads and returns.
func to_fields() -> Dictionary:
	return {
		"map_size": map_size, "city_name": city_name, "mayor_name": mayor_name,
		"stadium_teams": stadium_teams.duplicate(), "next_sign_id": next_sign_id, "next_object_id": next_object_id,
		"process_random": process_random, "lfsr_random": lfsr_random, "game_random": game_random,
		"phase_state": phase_state.duplicate(true), "required_features": required_features.duplicate(),
		"legacy": legacy.duplicate(true), "extensions": extensions.duplicate(true),
	}


static func from_fields(fields: Dictionary) -> Sc2xMetadata:
	var result := Sc2xMetadata.new()
	result.map_size = fields.map_size
	result.city_name = fields.city_name
	result.mayor_name = fields.mayor_name
	result.stadium_teams = fields.stadium_teams
	result.next_sign_id = fields.next_sign_id
	result.next_object_id = fields.next_object_id
	result.process_random = fields.process_random
	result.lfsr_random = fields.lfsr_random
	result.game_random = fields.game_random
	result.phase_state = fields.phase_state
	result.required_features = fields.required_features
	result.legacy = fields.legacy
	result.extensions = fields.extensions

	return result


static func parse_bytes(bytes: PackedByteArray) -> Result:
	return _result(NativeCityDocument.parse_metadata(bytes))


static func parse(text: String) -> Result:
	return parse_bytes(text.to_utf8_buffer())


static func from_dictionary(data: Variant) -> Result:
	return _result(NativeCityDocument.metadata_from_value(data))


# empty when `value` is a valid shared or record name: a string of at most 64
# code points and 256 UTF-8 bytes, with no NUL
static func name_error(value: Variant) -> String:
	return NativeCityDocument.name_error(value)


# the first 64 code points of `text` without NUL characters
static func limit_name(text: String) -> String:
	return NativeCityDocument.limit_name(text)


# Empty phase state is valid: a converted city starts with the load defaults.
# Otherwise every key must be present with its type.
static func phase_state_error(state: Dictionary) -> String:
	return NativeCityDocument.phase_state_error(state)


static func schema_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SCHEMA_PATH)


static func _result(parsed: Dictionary) -> Result:
	return Result.success(from_fields(parsed.metadata)) if parsed.ok else Result.failure(parsed.error)


class Result extends RefCounted:
	var ok := false
	var error := ""
	var metadata: Sc2xMetadata

	static func success(value: Sc2xMetadata) -> Result:
		var result := Result.new()
		result.ok = true
		result.metadata = value

		return result

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result
