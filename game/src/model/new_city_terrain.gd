class_name NewCityTerrain
extends NewTerrainConstants


# The native simulation library makes the landform and its features, scales
# it to the map, grades it, retiles it, plants trees, and runs the streams.
# See native/core/sim/src/sim/new_city.
static func generate(
	document: Sc2File,
	has_ocean: bool,
	has_river: bool,
	hills: int,
	water: int,
	trees: int,
	process_random: SimRandom,
	game_random: GameLcgRandom,
	layout: String = "classic",
	features: Array = [],
	smooth_slopes := false,
) -> Result:
	if document == null or not document.is_valid():
		return Result.failure("city document is invalid")

	if process_random == null or game_random == null:
		return Result.failure("terrain random state is missing")

	var payloads := {}

	for chunk_id in ["ALTM", "XTER", "XBLD", "XZON", "XBIT", "XTXT", "MISC"]:
		var chunk := document.find_chunk(chunk_id)

		if chunk != null:
			payloads[chunk_id] = chunk.decoded_payload

	var response: Dictionary = NativeSimulation.run({
		"op": "new_terrain",
		"city": {
			"map_size": document.map_size,
			"large_version": document.large_version,
			"disaster_damage_class": -1,
			"chunks": payloads,
		},
		"randoms": PackedInt64Array([process_random.state, 1, game_random.state]),
		"scripts": [null, null, null],
		"args": {
			"ocean": has_ocean, "river": has_river, "hills": hills, "water": water, "trees": trees,
			"layout": layout, "features": PackedStringArray(features), "smooth_slopes": smooth_slopes,
		},
		"budget": 0,
	})

	if not response.ok:
		return Result.failure(response.error)

	for chunk_id in ["ALTM", "XTER", "XBLD", "XZON", "XBIT", "MISC"]:
		if not document.find_chunk(chunk_id).set_decoded_payload(response.written[chunk_id], true):
			return Result.failure("cannot store generated %s data" % chunk_id)

	process_random.state = response.randoms[0]
	game_random.state = response.randoms[2]
	var options := Options.new()
	options.hills = hills
	options.water = water
	options.trees = trees

	return Result.from_summary(response.result, options)


# an island map has ocean on all four sides
static func is_island(layout: String, features: Array) -> bool:
	return layout in ["island", "islands"] or "island" in features or "islands" in features


class Options extends RefCounted:
	var size := 128
	var native_maps := false
	var ocean := DEFAULT_OCEAN
	var river := DEFAULT_RIVER
	var hills := DEFAULT_HILLS
	var water := DEFAULT_WATER
	var trees := DEFAULT_TREES
	var layout := "classic"
	var smooth_slopes := false
	var features: Array[String] = []

	func copy() -> Options:
		var result := Options.new()
		result.size = size
		result.native_maps = native_maps
		result.ocean = ocean
		result.river = river
		result.hills = hills
		result.water = water
		result.trees = trees
		result.layout = layout
		result.smooth_slopes = smooth_slopes
		result.features = features.duplicate()

		return result

	func same_values(other: Options) -> bool:
		return (other != null
			and size == other.size
			and native_maps == other.native_maps
			and ocean == other.ocean
			and river == other.river
			and hills == other.hills
			and water == other.water
			and trees == other.trees
			and layout == other.layout
			and smooth_slopes == other.smooth_slopes
			and features == other.features)


class Result extends RefCounted:
	var ok := false
	var error := ""
	var has_ocean := false
	var has_river := false
	var hills := 0
	var water := 0
	var trees := 0
	var water_level := 0
	var water_tiles := 0
	var salt_water_tiles := 0
	var tree_tiles := 0
	var minimum_altitude := 0
	var maximum_altitude := 0

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result

	# the result of native terrain: its settings and counts
	static func from_summary(summary: Dictionary, options: Options) -> Result:
		var result := Result.new()
		result.ok = true
		result.has_ocean = summary.has_ocean
		result.has_river = summary.has_river
		result.hills = options.hills
		result.water = options.water
		result.trees = options.trees
		result.water_level = summary.water_level
		result.water_tiles = summary.water_tiles
		result.salt_water_tiles = summary.salt_water_tiles
		result.tree_tiles = summary.tree_tiles
		result.minimum_altitude = summary.minimum_altitude
		result.maximum_altitude = summary.maximum_altitude
		result.error = ""

		return result
