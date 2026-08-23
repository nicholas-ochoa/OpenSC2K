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
) -> Dictionary:
	if layout not in LAYOUTS:
		return NewTerrainValues._failure("unknown terrain layout")

	var selected := features.duplicate()
	if layout != "classic" and layout not in selected:
		selected.append(layout)
	for feature in selected:
		if feature not in LAYOUTS or feature == "classic":
			return NewTerrainValues._failure("unknown terrain feature")
	if "canyon" in selected:
		for river_feature in ["meander", "delta", "crossing", "branch", "rejoin", "valley"]:
			selected.erase(river_feature)
	var extended := not selected.is_empty() or (smooth_slopes and has_ocean and has_river)
	var island := "island" in selected or "islands" in selected
	var ocean_requested := has_ocean or "delta" in selected or "peninsula" in selected or "cliffs" in selected
	has_ocean = ocean_requested or island or "bay" in selected
	has_river = not island and "canyon" not in selected and (has_river or "valley" in selected or "delta" in selected or "meander" in selected or "crossing" in selected or "branch" in selected or "rejoin" in selected)
	var map_edge: int = document.map_size if document != null else 128

	if document == null or not document.is_valid():
		return NewTerrainValues._failure("city document is invalid")

	for value in [hills, water, trees]:
		if value < MIN_SLIDER or value > MAX_SLIDER:
			return NewTerrainValues._failure("terrain sliders must be between 0 and 47")

	if process_random == null or game_random == null:
		return NewTerrainValues._failure("terrain random state is missing")

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
			return NewTerrainValues._failure("required %s data is missing or invalid" % chunk_id)

		payloads[chunk_id] = chunk.decoded_payload.duplicate()

	var staged_process := ProcessRandom.new(process_random.state)
	var staged_game := GameRandom.new(game_random.state)
	var altitude: PackedByteArray = payloads.ALTM
	var terrain: PackedByteArray = payloads.XTER
	var buildings: PackedByteArray = payloads.XBLD
	var zones: PackedByteArray = payloads.XZON
	var flags: PackedByteArray = payloads.XBIT
	var text_overlays: PackedByteArray = payloads.XTXT
	var misc: PackedByteArray = payloads.MISC
	altitude.fill(0)
	terrain.fill(0)
	buildings.fill(0)
	zones.fill(0)
	flags.fill(0)

	# Generate one original-size landform, then scale it to the map.
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
		NewTerrainHeights._grade_layout(heights)

	if map_edge != 128:
		heights = NewTerrainHeights._enlarge_landform(heights, coast_flags, flags, map_edge)
	else:
		flags = coast_flags
		payloads.XBIT = flags

	NewTerrainHeights._grade_heights(heights, map_edge)
	if smooth_slopes or extended or map_edge != 128:
		NewTerrainHeights._grade_layout(heights, map_edge)
		NewTerrainHeights._fill_unsupported_slopes(heights, map_edge)

	for index in (map_edge * map_edge):
		altitude[index * 2 + 1] = heights[index] & 0x1f

	NewTerrainValues._write_u32_be(misc, MISC_WATER_LEVEL, water_level)
	NewTerrainValues._write_u32_be(misc, MISC_HAS_OCEAN, 1 if has_ocean else 0)
	NewTerrainValues._write_u32_be(misc, MISC_HAS_RIVER, 1 if has_river else 0)
	var all_indices := PackedInt32Array()
	all_indices.resize((map_edge * map_edge))

	for index in (map_edge * map_edge):
		all_indices[index] = index

	TerrainRetile.retile_region(
		altitude, buildings, terrain, zones, flags, misc, all_indices, water_level, map_edge
	)

	NewTerrainSurface._grow_trees(
		buildings, flags, (((trees * trees) >> 1) * map_edge * map_edge) / 16384, staged_process, map_edge
	)

	if has_ocean:
		NewTerrainSurface._finish_ocean(flags, map_edge)

	for _stream_index in ((water >> 2) if not extended else 0):
		var start := Vector2i(
			staged_process.next_u15() % map_edge,
			staged_process.next_u15() % map_edge,
		)
		var length := (((staged_process.next_u15() & 0x7f) + 50) * map_edge) / 128
		NewTerrainSurface._make_stream(
			altitude,
			buildings,
			terrain,
			zones,
			flags,
			text_overlays,
			misc,
			start,
			length,
			staged_process, map_edge,
		)

	NewTerrainValues._recount_buildings(buildings, misc)

	for chunk_id in ["ALTM", "XTER", "XBLD", "XZON", "XBIT", "MISC"]:
		if not document.find_chunk(chunk_id).set_decoded_payload(payloads[chunk_id]):
			return NewTerrainValues._failure("cannot store generated %s data" % chunk_id)

	process_random.state = staged_process.state
	game_random.state = staged_game.state

	return {
		"ok": true,
		"has_ocean": has_ocean,
		"has_river": has_river,
		"hills": hills,
		"water": water,
		"trees": trees,
		"water_level": water_level,
		"water_tiles": NewTerrainValues._count_flag(flags, FLAG_WATER),
		"salt_water_tiles": NewTerrainValues._count_flag(flags, FLAG_SALT_WATER),
		"tree_tiles": NewTerrainValues._count_range(buildings, FIRST_TREE, LAST_TREE),
		"minimum_altitude": NewTerrainValues._minimum(altitude, map_edge),
		"maximum_altitude": NewTerrainValues._maximum(altitude, map_edge),
		"error": "",
	}
