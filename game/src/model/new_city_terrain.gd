class_name NewCityTerrain
extends NewTerrainConstants


@warning_ignore_start("integer_division")


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
	if layout not in LAYOUTS:
		return Result.failure("unknown terrain layout")

	var selected := features.duplicate()

	if layout != "classic" and layout not in selected:
		selected.append(layout)

	for feature in selected:
		if feature not in LAYOUTS or feature == "classic":
			return Result.failure("unknown terrain feature")

	if "canyon" in selected:
		for river_feature in ["meander", "delta", "crossing", "branch", "rejoin", "valley"]:
			selected.erase(river_feature)

	var extended := not selected.is_empty() or (smooth_slopes and has_ocean and has_river)
	var island := is_island(layout, selected)
	var ocean_requested := has_ocean or "delta" in selected or "peninsula" in selected or "cliffs" in selected

	has_ocean = ocean_requested or island or "bay" in selected
	has_river = (not island and "canyon" not in selected
			and (has_river or "valley" in selected or "delta" in selected or "meander" in selected or "crossing" in selected
			or "branch" in selected
			or "rejoin" in selected))

	var map_edge: int = document.map_size if document != null else 128

	if document == null or not document.is_valid():
		return Result.failure("city document is invalid")

	for value in [hills, water, trees]:
		if value < MIN_SLIDER or value > MAX_SLIDER:
			return Result.failure("terrain sliders must be between 0 and 47")

	if process_random == null or game_random == null:
		return Result.failure("terrain random state is missing")

	var required := {
		"ALTM": (map_edge * map_edge) * 2,
		"XTER": (map_edge * map_edge),
		"XBLD": (map_edge * map_edge),
		"XZON": (map_edge * map_edge),
		"XBIT": (map_edge * map_edge),
		"XTXT": (map_edge * map_edge),
		"MISC": MISC_SIZE,
	}

	var payloads := {}

	for chunk_id in required:
		var chunk := document.find_chunk(chunk_id)

		if chunk == null or chunk.decoded_payload.size() != document.decoded_size(chunk_id):
			return Result.failure("required %s data is missing or invalid" % chunk_id)

		payloads[chunk_id] = chunk.decoded_payload

	var staged_process := ProcessRandom.new(process_random.state)
	var staged_game := GameRandom.new(game_random.state)

	# Generate one original-size landform. The native stage scales it to the map.
	# Larger maps should not gain extra basins.
	var heights := PackedInt32Array()
	heights.resize(128 * 128)
	var coast_flags := PackedByteArray()
	coast_flags.resize(128 * 128)

	NewTerrainHeights._seed_hills(heights, hills + 11, staged_process)

	for pass_values in INTERPOLATION_PASSES:
		NewTerrainHeights._interpolate(heights, pass_values.x, pass_values.y, hills + 10,
			has_ocean and not extended, staged_process)

	var water_level := (water + 4) >> 3

	if has_ocean or has_river or "lake" in selected or "lakes" in selected:
		water_level = maxi(water_level, 4)

	if has_ocean and not extended:
		NewTerrainHeights._carve_ocean(heights, coast_flags, water_level, staged_game)

	if has_river and not extended:
		NewTerrainHeights._carve_river(heights, water_level, staged_game)

	NewTerrainHeights._smooth(heights)
	NewTerrainHeights._smooth(heights)
	NewTerrainHeights._scale_heights(heights)
	NewTerrainHeights._smooth(heights)

	if extended:
		TerrainFeatures.carve(heights, coast_flags, water_level, selected, ocean_requested, has_river, staged_game, water, hills)

	# the native simulation library grades, retiles, plants trees, and runs the
	# streams. see native/simulation/src/sim/tools/new_terrain.rs
	var response: Dictionary = NativeSimulation.run({
		"op": "new_terrain",
		"city": {
			"map_size": map_edge,
			"large_version": document.large_version,
			"disaster_damage_class": -1,
			"chunks": payloads,
		},
		"randoms": PackedInt64Array([staged_process.state, 1, staged_game.state]),
		"scripts": [null, null, null],
		"args": {
			"heights": heights,
			"coast_flags": coast_flags,
			"extended": extended,
			"smooth_slopes": smooth_slopes,
			"has_ocean": has_ocean,
			"has_river": has_river,
			"water_level": water_level,
			"water": water,
			"trees": trees,
		},
		"budget": 0,
	})

	if not response.ok:
		return Result.failure(response.error)

	for chunk_id in ["ALTM", "XTER", "XBLD", "XZON", "XBIT", "MISC"]:
		if not document.find_chunk(chunk_id).set_decoded_payload(response.written[chunk_id], true):
			return Result.failure("cannot store generated %s data" % chunk_id)

	process_random.state = response.randoms[0]
	game_random.state = staged_game.state
	var summary: Dictionary = response.result

	var result := Result.new()
	result.ok = true
	result.has_ocean = has_ocean
	result.has_river = has_river
	result.hills = hills
	result.water = water
	result.trees = trees
	result.water_level = water_level
	result.water_tiles = summary.water_tiles
	result.salt_water_tiles = summary.salt_water_tiles
	result.tree_tiles = summary.tree_tiles
	result.minimum_altitude = summary.minimum_altitude
	result.maximum_altitude = summary.maximum_altitude
	result.error = ""

	return result


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
