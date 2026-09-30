class_name Sc2xMetadata
extends RefCounted
## metadata.json of an SC2X version 4 archive: the file contract, the map edge,
## the shared names, the identity counters, and the simulation state that no
## binary structure saves. MISC stays authoritative for the values it holds.
## The application checks these rules itself. The included schema is a
## reference for tools and cannot relax them.

const FORMAT := "OpenSC2K.SC2X"
const FILE_VERSION := 4
const SCHEMA_REFERENCE := "metadata.schema.json"
const SCHEMA_PATH := "res://assets/data/sc2x-metadata.schema.json"
const MAX_NAME_CODE_POINTS := 64
const MAX_NAME_BYTES := 256
const TEAM_COUNT := 5
const U32_MAX := 0xffffffff
const MAP_EDGE_MAX := 0xffff
# JSON numbers are doubles. Integers above this cannot keep every value.
const EXACT_INTEGER_MAX := 9007199254740992
const TOP_LEVEL_KEYS: PackedStringArray = [
	"$schema", "format", "file_version", "map", "city", "identity_counters", "simulation",
	"required_features", "legacy", "extensions",
]
const RNG_KEYS: PackedStringArray = ["process_random", "lfsr_random", "game_random"]
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
const FIRE_TIMER_MAX := 1000
const PHASE_INTEGER_KEYS: PackedStringArray = [
	"commerce_connections", "industry_connections", "bus_passengers", "rail_passengers", "subway_passengers",
	"mayor_approval", "pending_disaster_type", "active_disaster_type", "unsupported_disaster_type",
	"disaster_map_counter", "disaster_hurricane_counter", "subtick_counter",
	"developed_tiles", "power_usage_percent", "water_usage_percent", "city_status_resource_id",
]
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
	var result := Sc2xMetadata.new()
	result.map_size = map_size
	result.city_name = city_name
	result.mayor_name = mayor_name
	result.stadium_teams = stadium_teams.duplicate()
	result.next_sign_id = next_sign_id
	result.next_object_id = next_object_id
	result.process_random = process_random
	result.lfsr_random = lfsr_random
	result.game_random = game_random
	result.phase_state = phase_state.duplicate(true)
	result.required_features = required_features.duplicate()
	result.legacy = legacy.duplicate(true)
	result.extensions = extensions.duplicate(true)

	return result


# The features that a document requires but this version does not support.
# Such a document can be inspected but not edited or simulated.
func unsupported_features() -> PackedStringArray:
	var result := PackedStringArray()

	for feature in required_features:
		if not SUPPORTED_FEATURES.has(feature):
			result.append(feature)

	return result


func to_dictionary() -> Dictionary:
	var result := {
		"$schema": SCHEMA_REFERENCE,
		"format": FORMAT,
		"file_version": FILE_VERSION,
		"map": {"size": map_size},
		"city": {"name": city_name, "mayor_name": mayor_name, "stadium_teams": Array(stadium_teams)},
		"identity_counters": {"next_sign_id": next_sign_id, "next_object_id": next_object_id},
		"simulation": {
			"rng_states": {"process_random": process_random, "lfsr_random": lfsr_random, "game_random": game_random},
			"phase_state": _integral(phase_state),
		},
	}

	if not required_features.is_empty():
		result["required_features"] = Array(required_features)

	if not legacy.is_empty():
		result["legacy"] = _integral(legacy)

	if not extensions.is_empty():
		result["extensions"] = _integral(extensions)

	return result


# UTF-8 JSON with a fixed key order and tab indentation
func to_json() -> String:
	return JSON.stringify(to_dictionary(), "\t", false) + "\n"


func to_bytes() -> PackedByteArray:
	return to_json().to_utf8_buffer()


static func parse_bytes(bytes: PackedByteArray) -> Result:
	var text := bytes.get_string_from_utf8()

	if text.to_utf8_buffer() != bytes:
		return Result.failure("metadata.json is not valid UTF-8 text")

	return parse(text)


static func parse(text: String) -> Result:
	var json := JSON.new()

	if json.parse(text) != OK:
		return Result.failure("metadata.json is not valid JSON: %s at line %d" % [json.get_error_message(), json.get_error_line()])

	return from_dictionary(json.data)


static func from_dictionary(data: Variant) -> Result:
	if not data is Dictionary:
		return Result.failure("metadata.json is not a JSON object")

	var root: Dictionary = data

	for key in root:
		if not TOP_LEVEL_KEYS.has(str(key)):
			return Result.failure("metadata.json has unknown field %s" % key)

	for key in ["format", "file_version", "map", "city", "identity_counters", "simulation"]:
		if not root.has(key):
			return Result.failure("metadata.json has no %s" % key)

	if root.has("$schema") and root["$schema"] != SCHEMA_REFERENCE:
		return Result.failure("metadata.json $schema must be %s" % SCHEMA_REFERENCE)

	if root.format != FORMAT:
		return Result.failure("metadata.json format is not %s" % FORMAT)

	if not _is_integer(root.file_version, 0, U32_MAX):
		return Result.failure("metadata.json file_version is not an integer")

	if int(root.file_version) != FILE_VERSION:
		return Result.failure("This version reads SC2X file version %d; the file uses version %d" % [FILE_VERSION, int(root.file_version)])

	var metadata := Sc2xMetadata.new()
	var map: Variant = _object(root.map, ["size"], ["size"])

	if map == null or not _is_integer(map.size, 1, MAP_EDGE_MAX):
		return Result.failure("metadata.json map.size must be an integer from 1 through 65535")

	metadata.map_size = int(map.size)
	var city: Variant = _object(root.city, ["name", "mayor_name", "stadium_teams"], ["name", "mayor_name", "stadium_teams"])

	if city == null:
		return Result.failure("metadata.json city must have name, mayor_name, and stadium_teams")

	for key in ["name", "mayor_name"]:
		var error := name_error(city[key])

		if not error.is_empty():
			return Result.failure("metadata.json city.%s: %s" % [key, error])

	if str(city.name).is_empty():
		return Result.failure("metadata.json city.name is empty")

	metadata.city_name = city.name
	metadata.mayor_name = city.mayor_name

	if not city.stadium_teams is Array or city.stadium_teams.size() != TEAM_COUNT:
		return Result.failure("metadata.json city.stadium_teams must list five names")

	for index in TEAM_COUNT:
		var error := name_error(city.stadium_teams[index])

		if not error.is_empty():
			return Result.failure("metadata.json stadium team %d: %s" % [index + 1, error])

		metadata.stadium_teams[index] = city.stadium_teams[index]

	var counters: Variant = _object(root.identity_counters, ["next_sign_id", "next_object_id"], ["next_sign_id", "next_object_id"])

	if counters == null or not _is_integer(counters.next_sign_id, 1, U32_MAX) or not _is_integer(counters.next_object_id, 1, U32_MAX):
		return Result.failure("metadata.json identity counters must be integers from 1 through 4294967295")

	metadata.next_sign_id = int(counters.next_sign_id)
	metadata.next_object_id = int(counters.next_object_id)
	var simulation: Variant = _object(root.simulation, ["rng_states", "phase_state"], ["rng_states", "phase_state"])

	if simulation == null:
		return Result.failure("metadata.json simulation must have rng_states and phase_state")

	var states: Variant = _object(simulation.rng_states, RNG_KEYS, RNG_KEYS)

	if states == null:
		return Result.failure("metadata.json simulation.rng_states must have process_random, lfsr_random, and game_random")

	for key in RNG_KEYS:
		if not _is_integer(states[key], 0, U32_MAX):
			return Result.failure("metadata.json random state %s is not a 32-bit unsigned integer" % key)

	# the LFSR has 16 bits, and zero never changes
	if int(states.lfsr_random) < 1 or int(states.lfsr_random) > 0xffff:
		return Result.failure("metadata.json lfsr_random must be from 1 through 65535")

	metadata.process_random = int(states.process_random)
	metadata.lfsr_random = int(states.lfsr_random)
	metadata.game_random = int(states.game_random)

	if not simulation.phase_state is Dictionary:
		return Result.failure("metadata.json simulation.phase_state is not an object")

	metadata.phase_state = _integral(simulation.phase_state)

	if root.has("required_features"):
		if not root.required_features is Array:
			return Result.failure("metadata.json required_features is not an array")

		for feature in root.required_features:
			if not feature is String or str(feature).is_empty() or metadata.required_features.has(feature):
				return Result.failure("metadata.json required_features must hold unique nonempty strings")

			metadata.required_features.append(feature)

	for key in ["legacy", "extensions"]:
		if root.has(key) and not root[key] is Dictionary:
			return Result.failure("metadata.json %s is not an object" % key)

	metadata.legacy = _integral(root.get("legacy", {}))
	metadata.extensions = _integral(root.get("extensions", {}))

	return Result.success(metadata)


# empty when `value` is a valid shared or record name: a string of at most 64
# code points and 256 UTF-8 bytes, with no NUL
static func name_error(value: Variant) -> String:
	if not value is String:
		return "the name is not a string"

	var text: String = value

	if text.length() > MAX_NAME_CODE_POINTS:
		return "the name has %d characters; the limit is %d" % [text.length(), MAX_NAME_CODE_POINTS]

	if text.to_utf8_buffer().size() > MAX_NAME_BYTES:
		return "the name has more than %d UTF-8 bytes" % MAX_NAME_BYTES

	if text.to_utf8_buffer().has(0):
		return "the name contains a NUL character"

	return ""


# the first 64 code points of `text` without NUL characters
static func limit_name(text: String) -> String:
	var result := text

	if text.to_utf8_buffer().has(0):
		result = ""

		for character in text:
			if character.unicode_at(0) != 0:
				result += character

	result = result.left(MAX_NAME_CODE_POINTS)

	while result.to_utf8_buffer().size() > MAX_NAME_BYTES:
		result = result.left(result.length() - 1)

	return result


# Empty phase state is valid: a converted city starts with the load defaults.
# Otherwise every key must be present with its type.
static func phase_state_error(state: Dictionary) -> String:
	if state.is_empty():
		return ""

	for key in PHASE_KEYS:
		if not state.has(key):
			return "metadata.json phase_state has no %s" % key

	for key in PHASE_INTEGER_KEYS:
		if not _is_integral(state[key]):
			return "metadata.json phase_state.%s is not an integer" % key

	for key in ["terminal_state", "simulation_ready"]:
		if not state[key] is bool:
			return "metadata.json phase_state.%s is not true or false" % key

	for key in ["ship_home", "pending_disaster_point"]:
		var value: Variant = state[key]

		if not value is Array or value.size() != 2 or not _is_integral(value[0]) or not _is_integral(value[1]):
			return "metadata.json phase_state.%s is not a pair of integers" % key

	if state.has(FIRE_TIMER_KEY):
		var timer: Variant = state[FIRE_TIMER_KEY]

		if not _is_integral(timer) or int(timer) < 0 or int(timer) > FIRE_TIMER_MAX:
			return "metadata.json phase_state.%s is not 0 through %d" % [FIRE_TIMER_KEY, FIRE_TIMER_MAX]

	return ""


static func _is_integral(value: Variant) -> bool:
	return value is int or (value is float and value == floorf(value))


static func schema_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SCHEMA_PATH)


static func _object(value: Variant, allowed: Array, required: Array) -> Variant:
	if not value is Dictionary:
		return null

	for key in value:
		if not allowed.has(str(key)):
			return null

	for key in required:
		if not value.has(key):
			return null

	return value


static func _is_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if value is int:
		return value >= minimum and value <= maximum

	if not value is float or is_nan(value) or is_inf(value) or value != floorf(value):
		return false

	return value >= minimum and value <= maximum


# JSON numbers parse as floats. Keep integral values as integers, so that a
# save writes 3 and not 3.0.
static func _integral(value: Variant) -> Variant:
	if value is float and value == floorf(value) and absf(value) <= EXACT_INTEGER_MAX:
		return int(value)

	if value is Dictionary:
		var result := {}

		for key in value:
			result[key] = _integral(value[key])

		return result

	if value is Array:
		var result := []

		for item in value:
			result.append(_integral(item))

		return result

	return value


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
