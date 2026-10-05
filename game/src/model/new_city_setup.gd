class_name NewCitySetup
extends RefCounted

## Founding a new city. The native simulation library sets the starting
## values; see native/core/sim/src/sim/new_city/setup.rs.

const STARTING_YEARS := [1900, 1950, 2000, 2050]


# Found a city from `template`. The random generators advance only when the
# city is founded
static func create(
	template: Sc2File,
	requested_city_name: String,
	requested_mayor_name: String,
	difficulty: int,
	starting_year: int,
	random: SimRandom,
	game_random: GameLcgRandom = null,
	terrain_options: NewCityTerrain.Options = null,
	newspaper_session_state: PackedByteArray = PackedByteArray(),
	island := false,
) -> Result:
	if template == null or not template.is_valid():
		return Result.failure("default city template is invalid")

	if random == null:
		return Result.failure("random state is missing")

	var settings := {
		"city_name": requested_city_name, "mayor_name": requested_mayor_name, "difficulty": difficulty,
		"starting_year": starting_year, "newspaper_session": newspaper_session_state, "island": island,
	}

	if terrain_options != null:
		settings.terrain = {
			"ocean": bool(terrain_options.ocean), "river": bool(terrain_options.river), "hills": int(terrain_options.hills),
			"water": int(terrain_options.water), "trees": int(terrain_options.trees), "layout": str(terrain_options.layout),
			"features": PackedStringArray(terrain_options.features), "smooth_slopes": bool(terrain_options.smooth_slopes),
		}

	var founded: Dictionary = NativeCityDocument.found_city(template.to_native(), settings, random.state,
		game_random.state if game_random != null else -1)

	if not founded.ok:
		return Result.failure(founded.error)

	var document := Sc2File.new()
	document.apply_native(founded.document)
	random.state = founded.random_state

	if game_random != null:
		game_random.state = founded.game_state

	var result := Result.new()
	result.ok = true
	result.document = document
	result.city_name = founded.city_name
	result.mayor_name = founded.mayor_name
	result.difficulty = difficulty
	result.starting_year = starting_year
	result.invention_years = founded.invention_years
	result.error = ""

	if not founded.terrain.is_empty():
		result.terrain = NewCityTerrain.Result.from_summary(founded.terrain, terrain_options)

	return result


# FUN_0040e250: four different random neighbor names, each with a population
# that is the smallest of three draws and a value of 1/1, 1/2, or 1/3 of it.
# The native simulation library draws them; see template.rs of new_city.
static func draw_neighbors(document: Sc2File, random: SimRandom) -> void:
	var misc := document.find_chunk("MISC")
	var drawn: Dictionary = NativeCityDocument.draw_neighbors(misc.decoded_payload, random.state)
	misc.set_decoded_payload(drawn.misc, true)
	random.state = drawn.state


class Result extends RefCounted:
	var ok := false
	var error := ""
	var stage := ""
	var document: Sc2File
	var city_name := ""
	var mayor_name := ""
	var difficulty := 0
	var starting_year := 0
	var invention_years := PackedInt32Array()
	var terrain: NewCityTerrain.Result
	var process_state := 0
	var game_state := 0

	static func failure(message: String, failed_stage := "") -> Result:
		var result := Result.new()
		result.error = message
		result.stage = failed_stage

		return result
