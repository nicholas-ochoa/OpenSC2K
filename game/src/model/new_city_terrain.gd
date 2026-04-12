class_name NewCityTerrain
extends RefCounted

const ProcessRandom = preload("res://src/simulation/random/sim_random.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")
const Landscapes = preload("res://src/tools/landscape/landscape_command.gd")

const LAYOUTS := ["classic", "crossing", "branch", "rejoin", "bay", "island", "islands"]
const MAP_SIZE := 128
const TILE_COUNT := MAP_SIZE * MAP_SIZE
const MISC_SIZE := 4800
const MISC_TILE_COUNTS := 0x01f0
const MISC_WATER_LEVEL := 0x0e40
const MISC_HAS_OCEAN := 0x0e44
const MISC_HAS_RIVER := 0x0e48
const FLAG_SALT_WATER := 0x01
const FLAG_WATER := 0x04
const FIRST_TREE := 0x06
const LAST_TREE := 0x0c
const FORBIDDEN_COAST := 0x2e
const WATERFALL := 0x3e

const MIN_SLIDER := 0
const MAX_SLIDER := 47
const DEFAULT_OCEAN := false
const DEFAULT_RIVER := true
const DEFAULT_HILLS := 12
const DEFAULT_WATER := 5
const DEFAULT_TREES := 15

const INTERPOLATION_PASSES := [
	Vector2i(8, 15), Vector2i(4, 7), Vector2i(2, 3), Vector2i(1, 1),
]
const CARDINAL_OFFSETS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const STREAM_X_OFFSETS := [-1, 0, 1, 0]
const STREAM_Y_OFFSETS := [0, 1, 0, -1]
const STREAM_TURN_ORDER := [0, 1, 3, 2]


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
) -> Dictionary:
	if layout not in LAYOUTS:
		return _failure("unknown terrain layout")

	if layout != "classic":
		has_ocean = layout in ["bay", "island", "islands"]
		has_river = layout in ["crossing", "branch", "rejoin"]
	var map_edge: int = document.map_size if document != null else 128

	if document == null or not document.is_valid():
		return _failure("city document is invalid")

	for value in [hills, water, trees]:
		if value < MIN_SLIDER or value > MAX_SLIDER:
			return _failure("terrain sliders must be between 0 and 47")

	if process_random == null or game_random == null:
		return _failure("terrain random state is missing")

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
			return _failure("required %s data is missing or invalid" % chunk_id)

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
	_seed_hills(heights, hills + 11, staged_process)

	for pass_values in INTERPOLATION_PASSES:
		_interpolate(heights, pass_values.x, pass_values.y, hills + 10,
			has_ocean and layout == "classic", staged_process)

	var water_level := (water + 4) >> 3

	if has_ocean or has_river:
		water_level = maxi(water_level, 4)

	if has_ocean and layout not in ["bay", "island", "islands"]:
		_carve_ocean(heights, coast_flags, water_level, staged_game)

	if has_river and layout == "classic":
		_carve_river(heights, water_level, staged_game)

	_smooth(heights)
	_smooth(heights)
	_scale_heights(heights)
	_smooth(heights)

	if layout != "classic":
		_carve_layout(heights, coast_flags, water_level, layout, staged_game, water)
		_grade_layout(heights)

	if map_edge != 128:
		heights = _enlarge_landform(heights, coast_flags, flags, map_edge)
	else:
		flags = coast_flags
		payloads.XBIT = flags

	_grade_heights(heights, map_edge)

	for index in (map_edge * map_edge):
		altitude[index * 2 + 1] = heights[index] & 0x1f

	_write_u32_be(misc, MISC_WATER_LEVEL, water_level)
	_write_u32_be(misc, MISC_HAS_OCEAN, 1 if has_ocean else 0)
	_write_u32_be(misc, MISC_HAS_RIVER, 1 if has_river else 0)
	var all_indices := PackedInt32Array()
	all_indices.resize((map_edge * map_edge))

	for index in (map_edge * map_edge):
		all_indices[index] = index

	TerrainTools._retile_region(
		altitude, buildings, terrain, zones, flags, misc, all_indices, water_level, map_edge
	)

	_grow_trees(
		buildings, flags, ((trees * trees) >> 1) * (IntegerMath.div_trunc(map_edge, 128)) * (IntegerMath.div_trunc(map_edge, 128)), staged_process, map_edge
	)

	if has_ocean:
		_finish_ocean(flags, map_edge)

	for _stream_index in ((water >> 2) if layout == "classic" else 0):
		var start := Vector2i(
			staged_process.next_u15() % map_edge,
			staged_process.next_u15() % map_edge,
		)
		var length := ((staged_process.next_u15() & 0x7f) + 50) * IntegerMath.div_trunc(map_edge, 128)
		_make_stream(
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

	_recount_buildings(buildings, misc)

	for chunk_id in ["ALTM", "XTER", "XBLD", "XZON", "XBIT", "MISC"]:
		if not document.find_chunk(chunk_id).set_decoded_payload(payloads[chunk_id]):
			return _failure("cannot store generated %s data" % chunk_id)

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
		"water_tiles": _count_flag(flags, FLAG_WATER),
		"salt_water_tiles": _count_flag(flags, FLAG_SALT_WATER),
		"tree_tiles": _count_range(buildings, FIRST_TREE, LAST_TREE),
		"minimum_altitude": _minimum(altitude, map_edge),
		"maximum_altitude": _maximum(altitude, map_edge),
		"error": "",
	}


static func _enlarge_landform(source: PackedInt32Array, coast: PackedByteArray,
	flags: PackedByteArray, edge: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(edge * edge)

	for x in edge:
		var u := float(x) * 127.0 / float(edge - 1)
		var left := floori(u)
		var right := mini(left + 1, 127)

		for y in edge:
			var v := float(y) * 127.0 / float(edge - 1)
			var top := floori(v)
			var bottom := mini(top + 1, 127)
			var a := lerpf(source[_index(left, top)], source[_index(right, top)], u - left)
			var b := lerpf(source[_index(left, bottom)], source[_index(right, bottom)], u - left)
			result[_index(x, y, edge)] = roundi(lerpf(a, b, v - top))
			flags[_index(x, y, edge)] = coast[_index(roundi(u), roundi(v))]

	return result


static func _carve_layout(heights: PackedInt32Array, flags: PackedByteArray,
	sea: int, layout: String, random: GameLcgRandom, water: int) -> void:
	var wetness := float(water) / 47.0
	var river_width := lerpf(0.025, 0.065, wetness)
	var island_scale := lerpf(1.08, 0.78, wetness)
	var phase := float(random.next_mod(628)) / 100.0
	var mirror := random.next_mod(2) == 1
	var ocean := layout in ["bay", "island", "islands"]

	for x in 128:
		for y in 128:
			var u := float(x) / 127.0
			var v := float(y) / 127.0
			var center := 0.5 + 0.025 * sin(v * TAU + phase)
			var distance := 1.0

			match layout:
				"crossing":
					distance = minf(absf(u - center), absf(v - 0.5 - 0.025 * sin(u * TAU + phase))) - river_width
				"branch":
					var spread := maxf(0.0, 0.5 - v) * 0.7
					distance = minf(absf(u - center - spread), absf(u - center + spread)) - river_width
				"rejoin":
					var spread := 0.22 * sin(clampf((v - 0.18) / 0.64, 0.0, 1.0) * PI)
					distance = minf(absf(u - center - spread), absf(u - center + spread)) - river_width
				"bay":
					distance = Vector2((u - 1.03) / lerpf(0.62, 0.86, wetness), (v - 0.5) / lerpf(0.32, 0.45, wetness)).length() - 1.0
				"island":
					distance = 1.0 - Vector2((u - 0.5) / (0.36 * island_scale), (v - 0.5) / (0.36 * island_scale)).length()
				"islands":
					var a := Vector2((u - 0.28) / (0.20 * island_scale), (v - 0.43) / (0.31 * island_scale)).length()
					var b := Vector2((u - 0.73) / (0.19 * island_scale), (v - 0.59) / (0.29 * island_scale)).length()
					distance = 1.0 - minf(a, b)

			if ocean:
				distance += 0.035 * sin(u * 19.0 + phase) * sin(v * 17.0 + phase)

			var index := _index(127 - x if mirror else x, y)
			if distance <= 0.0:
				heights[index] = maxi(0, sea - 2)
				if ocean:
					flags[index] |= FLAG_SALT_WATER
			else:
				# keep the intended land mass connected above the sea
				heights[index] = maxi(heights[index], sea + 1)


static func _grade_layout(heights: PackedInt32Array) -> void:
	# two distance-transform sweeps lower steep cut banks to cardinal grades
	for x in 128:
		for y in 128:
			var index := _index(x, y)
			if x > 0:
				heights[index] = mini(heights[index], heights[_index(x - 1, y)] + 1)
			if y > 0:
				heights[index] = mini(heights[index], heights[_index(x, y - 1)] + 1)
	for x in range(127, -1, -1):
		for y in range(127, -1, -1):
			var index := _index(x, y)
			if x < 127:
				heights[index] = mini(heights[index], heights[_index(x + 1, y)] + 1)
			if y < 127:
				heights[index] = mini(heights[index], heights[_index(x, y + 1)] + 1)


static func _seed_hills(
	heights: PackedInt32Array, maximum: int, random: SimRandom,
	map_edge: int = 128,
) -> void:
	for x in range(0, map_edge, 16):
		for y in range(0, map_edge, 16):
			heights[_index(x, y, map_edge)] = random.next_u15() % maximum + 1


static func _interpolate(
	heights: PackedInt32Array,
	step: int,
	mask: int,
	edge_height: int,
	has_ocean: bool,
	random: SimRandom,
	map_edge: int = 128,
) -> void:
	for x in range(0, map_edge, step):
		var x_is_midpoint := (mask & x) != 0

		for y in range(0, map_edge, step):
			var y_is_midpoint := (mask & y) != 0

			if not x_is_midpoint and not y_is_midpoint:
				continue

			var variation := random.next_u15() % step
			var value := 0

			if x_is_midpoint and y_is_midpoint:
				value = (
					_neighbor_height(heights, x - step, y + step, edge_height, has_ocean, map_edge)
					+ _neighbor_height(heights, x + step, y + step, edge_height, has_ocean, map_edge)
					+ _neighbor_height(heights, x - step, y - step, edge_height, has_ocean, map_edge)
					+ _neighbor_height(heights, x + step, y - step, edge_height, has_ocean, map_edge)
				) >> 2
			elif y_is_midpoint:
				value = (
					_neighbor_height(heights, x, y + step, edge_height, has_ocean, map_edge)
					+ _neighbor_height(heights, x, y - step, edge_height, has_ocean, map_edge)
				) >> 1
			else:
				value = (
					_neighbor_height(heights, x - step, y, edge_height, has_ocean, map_edge)
					+ _neighbor_height(heights, x + step, y, edge_height, has_ocean, map_edge)
				) >> 1

			heights[_index(x, y, map_edge)] = maxi(1, value + variation)


static func _neighbor_height(
	heights: PackedInt32Array,
	x: int,
	y: int,
	edge_height: int,
	has_ocean: bool,
	map_edge: int = 128,
) -> int:
	if x < 0 or y < 0 or y >= map_edge:
		return edge_height

	if x >= map_edge:
		return 0 if has_ocean else edge_height

	return heights[_index(x, y, map_edge)]


static func _carve_ocean(
	heights: PackedInt32Array,
	flags: PackedByteArray,
	water_level: int,
	random: GameLcgRandom,
	map_edge: int = 128,
) -> void:
	var width := random.next_mod(10) + 10

	for y in map_edge:
		var bank_x := map_edge - width
		heights[_index(bank_x, y, map_edge)] = water_level - 2

		for x in range(bank_x + 1, map_edge):
			heights[_index(x, y, map_edge)] = water_level - 3
			flags[_index(x, y, map_edge)] |= FLAG_SALT_WATER

		var target := random.next_mod(30)

		if width < target:
			width += 1
		elif target < width:
			width -= 1


static func _carve_river(
	heights: PackedInt32Array, water_level: int, random: GameLcgRandom,
	map_edge: int = 128,
) -> void:
	var center := IntegerMath.div_trunc(map_edge, 2)
	var bend := random.next_mod(3) - 1

	for y in range(map_edge - 1, -1, -1):
		for x in range(center - 3, center + 4):
			heights[_index(x, y, map_edge)] = water_level - 3

		heights[_index(center - 4, y, map_edge)] = water_level - 2
		heights[_index(center + 4, y, map_edge)] = water_level - 2

		if random.next_mod(8) == 0:
			bend = random.next_mod(3) - 1

		center += bend + random.next_mod(3) - 1
		center = clampi(center, 5, map_edge - 6)


static func _smooth(heights: PackedInt32Array, map_edge: int = 128) -> void:
	var source := heights.duplicate()

	for x in map_edge:
		for y in map_edge:
			var center := source[_index(x, y, map_edge)]
			var north := source[_index(x, y - 1, map_edge)] if y > 0 else center
			var east := source[_index(x + 1, y, map_edge)] if x < map_edge - 1 else center
			var south := source[_index(x, y + 1, map_edge)] if y < map_edge - 1 else center
			var west := source[_index(x - 1, y, map_edge)] if x > 0 else center
			heights[_index(x, y, map_edge)] = (((north + east + south + west) >> 2) + center) >> 1


static func _scale_heights(heights: PackedInt32Array, map_edge: int = 128) -> void:
	for index in (map_edge * map_edge):
		var scaled := (heights[index] + 3) >> 1
		var shifted := scaled - 4

		if shifted >= 4:
			heights[index] = shifted
		elif shifted >= 0:
			heights[index] = 4
		else:
			heights[index] = scaled


static func _grade_heights(heights: PackedInt32Array, map_edge: int = 128) -> void:
	for x in map_edge:
		for y in map_edge:
			_grade_cell(heights, x, y, map_edge)


static func _grade_cell(heights: PackedInt32Array, x: int, y: int, map_edge: int = 128) -> void:
	var index := _index(x, y, map_edge)
	var current := heights[index]
	var must_lower := false

	for offset in CARDINAL_OFFSETS:
		var near: Vector2i = Vector2i(x, y) + offset

		if _in_bounds(near, map_edge) and heights[_index(near.x, near.y, map_edge)] + 1 < current:
			must_lower = true
			break

	if not must_lower:
		return

	current -= 1
	heights[index] = current

	for offset in CARDINAL_OFFSETS:
		var near: Vector2i = Vector2i(x, y) + offset

		if _in_bounds(near, map_edge) and current < heights[_index(near.x, near.y, map_edge)]:
			_grade_cell(heights, near.x, near.y, map_edge)


static func _grow_trees(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	cluster_count: int,
	random: SimRandom,
	map_edge: int = 128,
) -> void:
	for _cluster in cluster_count:
		var base_x := random.next_u15() % map_edge
		var base_y := random.next_u15() % map_edge
		var attempts := random.next_u15() & 0x3f

		for _attempt in attempts:
			var x := (
				base_x + random.next_u15() % 5 - random.next_u15() % 5
			)
			var first_y_random := random.next_u15()
			var y := base_y + first_y_random % 5 - random.next_u15() % 5

			if x < 0 or x >= map_edge or y < 0 or y >= map_edge:
				continue

			var index := _index(x, y, map_edge)

			if flags[index] & FLAG_WATER:
				continue

			var current := int(buildings[index])

			if current < FIRST_TREE:
				buildings[index] = FIRST_TREE + (random.next_u15() & 1)
			elif current < 0x0b:
				buildings[index] = current + 1
			elif current <= LAST_TREE:
				buildings[index] = 0x0b + (random.next_u15() & 1)


static func _finish_ocean(flags: PackedByteArray, map_edge: int = 128) -> void:
	for _pass_index in 4:
		for y in range(1, map_edge):
			for x in range(1, map_edge):
				var index := _index(x, y, map_edge)
				var water_bits := flags[index] & (FLAG_SALT_WATER | FLAG_WATER)

				if water_bits == FLAG_SALT_WATER:
					flags[index] &= ~FLAG_SALT_WATER & 0xff
				elif water_bits == (FLAG_SALT_WATER | FLAG_WATER):
					flags[_index(x, y - 1, map_edge)] |= FLAG_SALT_WATER
					flags[_index(x - 1, y, map_edge)] |= FLAG_SALT_WATER


static func _make_stream(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	start: Vector2i,
	length: int,
	random: SimRandom,
	map_edge: int = 128,
) -> void:
	var point := start
	var direction := 1
	_make_water(
		altitude, buildings, terrain, zones, flags, text_overlays, misc, point, map_edge
	)

	for _step in length:
		var altitude_limit := _land_altitude(altitude, _index(point.x, point.y, map_edge))

		if terrain[_index(point.x, point.y, map_edge)] == WATERFALL:
			altitude_limit += 1

		var accepted_attempt := -1
		var next_point := point

		for attempt in 4:
			var candidate_direction: int = (
				int(STREAM_TURN_ORDER[attempt]) + direction
			) & 3
			var candidate := point + Vector2i(
				STREAM_X_OFFSETS[candidate_direction],
				STREAM_Y_OFFSETS[candidate_direction],
			)

			if not _in_bounds(candidate, map_edge):
				return

			var candidate_index := _index(candidate.x, candidate.y, map_edge)
			var candidate_altitude := _land_altitude(altitude, candidate_index)
			var candidate_terrain := int(terrain[candidate_index])

			if candidate_altitude > altitude_limit:
				continue

			if candidate_terrain >= 0x10 and candidate_terrain < 0x30:
				return

			if candidate_altitude < altitude_limit or candidate_terrain == 0:
				accepted_attempt = attempt
				next_point = candidate
				break

		if accepted_attempt == -1:
			return

		point = next_point
		_make_water(
			altitude, buildings, terrain, zones, flags, text_overlays, misc, point, map_edge
		)
		direction += STREAM_TURN_ORDER[accepted_attempt]

		if random.next_u15() % 3 != 0:
			direction = (direction + random.next_u15() * 2 + 1) & 3


static func _make_water(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	var index := _index(point.x, point.y, map_edge)

	if terrain[index] == FORBIDDEN_COAST or terrain[index] == WATERFALL:
		return

	if flags[index] & FLAG_WATER:
		var shape := Landscapes._water_shape(flags, point.x, point.y, map_edge)
		var transition := Landscapes._water_transition(terrain[index], shape)

		if not transition.early_return:
			terrain[index] = transition.value

		return

	Landscapes._place_water(
		buildings, terrain, zones, flags, altitude, text_overlays, misc, point, map_edge
	)


static func _recount_buildings(
	buildings: PackedByteArray, misc: PackedByteArray
) -> void:
	var counts := PackedInt32Array()
	counts.resize(256)

	for building in buildings:
		counts[building] += 1

	for building_id in 256:
		_write_u32_be(
			misc, MISC_TILE_COUNTS + building_id * 4, counts[building_id]
		)


static func _count_flag(values: PackedByteArray, mask: int) -> int:
	var count := 0

	for value in values:
		if value & mask:
			count += 1

	return count


static func _count_range(values: PackedByteArray, first: int, last: int) -> int:
	var count := 0

	for value in values:
		if value >= first and value <= last:
			count += 1

	return count


static func _minimum(altitude: PackedByteArray, map_edge: int = 128) -> int:
	var result := 31

	for index in (map_edge * map_edge):
		result = mini(result, _land_altitude(altitude, index))

	return result


static func _maximum(altitude: PackedByteArray, map_edge: int = 128) -> int:
	var result := 0

	for index in (map_edge * map_edge):
		result = maxi(result, _land_altitude(altitude, index))

	return result


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return altitude[index * 2 + 1] & 0x1f


static func _index(x: int, y: int, map_edge: int = 128) -> int:
	return x * map_edge + y


static func _in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return point.x >= 0 and point.x < map_edge and point.y >= 0 and point.y < map_edge


static func _write_u32_be(
	data: PackedByteArray, offset: int, value: int
) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
