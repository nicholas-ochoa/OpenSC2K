class_name NativeDataMapPhase
extends RefCounted

# Inline integer division avoids a function call for every cell.
@warning_ignore_start("integer_division")
# SC2X v3 per-tile rules. These differ from the original executable's coarse-grid rules.


const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
# per-building tables. the per-tile loops read one table entry in place of a
# chain of range tests or a dictionary lookup
static var _pollution_weights := _make_pollution_weights()
static var _density_weights := _make_density_weights()
static var _residential_values := _make_residential_values()
static var _land_value_halved := _make_land_value_halved()

# the day-two half of the monthly scan. the power scan runs first on the same
# day, so station coverage reads the new powered flags
class PollutionCoverageResult extends PhaseResult:
	var pollution_total := 0
	var city_center := Vector2i.ZERO


# the full monthly scan. the day schedule runs the two halves on separate days
static func run(city: CityState) -> PollutionPhase.Result:
	var span := SimulationTimingSpan.new(city.simulation_slice)
	var coverage := run_pollution_and_coverage(city)

	if not coverage.ok:
		return PollutionPhase.failed(coverage.error)

	var result := run_land_value_and_crime(city)

	if result.ok:
		var steps := coverage.timing.steps.duplicate()
		steps.merge(result.timing.steps)
		result.timing = SimulationTiming.new(span.finish().work_usec, steps)

	return result


# pollution, city center, and police and fire coverage. these read only the
# map, the previous pollution and traffic, and the budget
static func run_pollution_and_coverage(city: CityState) -> PollutionCoverageResult:
	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("pollution sources")
	var edge := city.map_size
	var count := edge * edge
	var doc := city.document
	var invalid := _invalid_chunk(doc, count)

	if not invalid.is_empty():
		return _failed_coverage(invalid)

	var old_pollution := doc.find_chunk("XPLT").decoded_payload
	var old_traffic := doc.find_chunk("XTRF").decoded_payload
	var buildings := city.buildings
	var pollution_weights := _pollution_weights
	var sources := PackedInt32Array()
	sources.resize(count)
	var center_x_sum := 0
	var center_y_sum := 0
	var center_count := 0

	for x in edge:
		_checkpoint(city)
		var row := x * edge

		for y in edge:
			var index := row + y
			var building := buildings[index]
			sources[index] = old_pollution[index] + old_traffic[index] / 5 + pollution_weights[building]

			if building >= PollutionPhase.FIRST_POLLUTING_BUILDING:
				center_x_sum += x
				center_y_sum += y
				center_count += 1

	var center := Vector2i(edge / 2, edge / 2) if center_count == 0 else Vector2i(center_x_sum / center_count, center_y_sum / center_count)
	var ordinances := doc.misc_u32(PollutionPhase.MISC_ORDINANCES)
	var divisor := PollutionPhase.pollution_divisor(doc)
	span.mark("pollution smoothing")
	var pollution_result := NativeGridMath.smooth_bytes(sources, edge, 4, maxi(divisor, 1) * 2, 1, 2, city.simulation_slice)
	span.mark("ordinance coverage")
	var ordinance_coverage := PackedByteArray()

	if ordinances & (PollutionPhase.POLICE_COVERAGE_ORDINANCE | PollutionPhase.FIRE_COVERAGE_ORDINANCE):
		ordinance_coverage = NativeGridMath.neighborhood_bytes(_occupied_tiles(city), edge, 2, 32, city.simulation_slice)

	var police := PackedByteArray()
	var fire := PackedByteArray()
	police.resize(count)
	fire.resize(count)

	if ordinances & PollutionPhase.POLICE_COVERAGE_ORDINANCE:
		police = ordinance_coverage.duplicate()

	if ordinances & PollutionPhase.FIRE_COVERAGE_ORDINANCE:
		fire = ordinance_coverage.duplicate()

	span.mark("station coverage")
	_add_stations(city, police, fire)
	span.mark("store maps and totals")
	var updates := {"XPLT": pollution_result.values, "XPLC": police, "XFIR": fire}

	for id in updates:
		doc.find_chunk(id).set_decoded_payload(updates[id])

	# misc totals retain the original half-resolution area unit for economic consumers
	var pollution_total := int(pollution_result.total) / 4

	for update in [[PollutionPhase.MISC_CITY_POLLUTION, pollution_total],
		[PollutionPhase.MISC_CITY_CENTER_X, center.x], [PollutionPhase.MISC_CITY_CENTER_Y, center.y]]:
		doc.set_misc_u32(update[0], update[1])

	var result := PollutionCoverageResult.new()
	result.ok = true
	result.pollution_total = pollution_total
	result.city_center = center
	result.timing = span.finish()

	return result


# land value, population density, growth, and crime. these read the pollution,
# police coverage, and city center that run_pollution_and_coverage stores
static func run_land_value_and_crime(city: CityState) -> PollutionPhase.Result:
	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("land and density sources")
	var edge := city.map_size
	var count := edge * edge
	var doc := city.document
	var invalid := _invalid_chunk(doc, count)

	if not invalid.is_empty():
		return PollutionPhase.failed(invalid)

	var pollution := doc.find_chunk("XPLT").decoded_payload
	var police := doc.find_chunk("XPLC").decoded_payload
	var old_growth := doc.find_chunk("XROG").decoded_payload
	var old_population := doc.find_chunk("XPOP").decoded_payload
	var old_crime := doc.find_chunk("XCRM").decoded_payload
	var buildings := city.buildings
	var flags := city.tile_flags
	var zones := city.zones
	var terrain := city.terrain
	var density_weights := _density_weights
	var residential_values := _residential_values
	var residential := PackedInt32Array()
	var industrial := PackedInt32Array()
	var weights := PackedInt32Array()

	for values in [residential, industrial, weights]:
		values.resize(count)

	var developed := 0

	for x in edge:
		_checkpoint(city)
		var row := x * edge

		for y in edge:
			var index := row + y
			var building := buildings[index]
			var tile_flags := flags[index]

			if building >= PollutionPhase.FIRST_ROAD or zones[index] & Sc2ZoneLayout.TYPE_MASK:
				developed += 1

			var residential_value := residential_values[building]
			var industrial_value := 0

			if building == Tiles.EMPTY:
				if tile_flags & PollutionPhase.FLAG_WATER:
					residential_value = 12
					industrial_value = 12
				else:
					residential_value = 4

			if tile_flags & PollutionPhase.FLAG_WATERED:
				residential_value += 4
				industrial_value += 4

			var terrain_id := terrain[index]

			if terrain_id > TerrainTileIds.FLAT and terrain_id < TerrainTileIds.DEEP_WATER_FIRST:
				residential_value += 12

			residential[index] = residential_value
			industrial[index] = industrial_value
			weights[index] = density_weights[building]

	var center := Vector2i(doc.misc_u32(PollutionPhase.MISC_CITY_CENTER_X), doc.misc_u32(PollutionPhase.MISC_CITY_CENTER_Y))
	var ordinances := doc.misc_u32(PollutionPhase.MISC_ORDINANCES)
	span.mark("land desirability filters")
	residential = NativeGridMath.neighborhood(residential, edge, 2, 16, city.simulation_slice)
	industrial = NativeGridMath.neighborhood(industrial, edge, 2, 16, city.simulation_slice)
	residential = NativeGridMath.smooth(residential, edge, 1, 1, 4, 1, city.simulation_slice)
	industrial = NativeGridMath.smooth(industrial, edge, 1, 1, 4, 1, city.simulation_slice)
	span.mark("population density")
	var population := NativeGridMath.neighborhood_bytes(weights, edge, 2, 64, city.simulation_slice)
	span.mark("land value, growth and crime sources")
	var land_sum := 0
	var land := PackedByteArray()
	var growth := PackedByteArray()
	var sources := PackedInt32Array()
	land.resize(count)
	growth.resize(count)
	sources.resize(count)
	var land_value_halved := _land_value_halved
	var crime_bonus := 16 if ordinances & PollutionPhase.CRIME_REDUCTION_ORDINANCE else 0

	for x in edge:
		_checkpoint(city)
		var row := x * edge
		var distance_x := absi(center.x - x)

		for y in edge:
			var index := row + y
			var population_value := population[index]
			var old_population_value := old_population[index]
			growth[index] = clampi((old_growth[index] * 7 + (population_value - old_population_value) * 8 + 128) / 8, 0, 255)
			var building := buildings[index]
			var zone := zones[index] & Sc2ZoneLayout.TYPE_MASK

			if building < PollutionPhase.FIRST_ROAD and zone == 0:
				continue

			var distance_value := 64 - (distance_x + absi(center.y - y)) / 2
			var pollution_value := pollution[index]
			var value := residential[index]

			if zone == 3 or zone == 4:
				value += maxi(distance_value, 0) - pollution_value / 4 - old_crime[index] / 3 + old_population_value / 3
			elif zone == 5 or zone == 6:
				value = industrial[index] + (21 if zone == 6 else 0)
				value += maxi(distance_value / 4, 0) - pollution_value / 16 - old_crime[index] / 4
			else:
				value += 21 if old_population_value < 64 else 0
				value += maxi(distance_value / 2, 0) - pollution_value / 5 - old_crime[index] / 3

			if land_value_halved[building]:
				value -= value / 2

			value = clampi(value, 0, 255)
			land[index] = value
			land_sum += value
			# all crime inputs are available here. preserve the same per-tile math
			sources[index] = population_value - value / 4 - police[index] / 2 + crime_bonus

	span.mark("crime smoothing")
	var crime_result := NativeGridMath.smooth_bytes(sources, edge, 2, 2, 1, 2, city.simulation_slice)
	span.mark("store maps and totals")
	var updates := {"XVAL": land, "XCRM": crime_result.values, "XPOP": population, "XROG": growth}

	for id in updates:
		doc.find_chunk(id).set_decoded_payload(updates[id])

	var land_total := land_sum / 4
	var crime_total := int(crime_result.total) / 4

	for update in [[PollutionPhase.MISC_CITY_LAND_VALUE, land_total], [PollutionPhase.MISC_CITY_CRIME, crime_total]]:
		doc.set_misc_u32(update[0], update[1])

	return PollutionPhase.totals(
		doc.misc_u32(PollutionPhase.MISC_CITY_POLLUTION), land_total, crime_total, developed, center, span.finish()
	)


# the name of the first missing or invalid data map, or an empty string
static func _invalid_chunk(doc: Sc2File, count: int) -> String:
	for id in Sc2File.HALF_MAP_CHUNKS + Sc2File.QUARTER_MAP_CHUNKS:
		var chunk := doc.find_chunk(id)

		if chunk == null or chunk.decoded_payload.size() != count:
			return "Native data map %s is missing or invalid" % id

	var misc := doc.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() != Sc2MiscLayout.SIZE:
		return "MISC is missing or invalid"

	return ""


static func _failed_coverage(message: String) -> PollutionCoverageResult:
	var result := PollutionCoverageResult.new()
	result.error = message

	return result


# 1 for each occupied building tile. only the coverage ordinances read this
static func _occupied_tiles(city: CityState) -> PackedInt32Array:
	var buildings := city.buildings
	var occupied := PackedInt32Array()
	occupied.resize(buildings.size())

	for index in buildings.size():
		var building := buildings[index]

		if building >= Tiles.DEVELOPED_FIRST and building < Tiles.HYDRO_POWER_1:
			occupied[index] = 1

	return occupied


# derive once from the shared rules; workers only read these tables
static func _make_pollution_weights() -> PackedInt32Array:
	var values := PackedInt32Array()
	values.resize(Tiles.COUNT)
	for building in values.size():
		values[building] = int(PollutionPhase.BUILDING_POLLUTION.get(building, 0)) * 4

	values[PollutionPhase.RADIOACTIVITY] += 800

	return values


# population weights for occupied buildings, and fixed weights for power
# plants, arcologies, and other large facilities
static func _make_density_weights() -> PackedInt32Array:
	var values := PackedInt32Array()
	values.resize(Tiles.COUNT)
	for building in values.size():
		if building >= Tiles.DEVELOPED_FIRST and building < Tiles.HYDRO_POWER_1:
			values[building] = PollutionPhase._population_weight(building)
		elif building >= Tiles.HYDRO_POWER_1:
			values[building] = 12 if building >= Tiles.PLYMOUTH_ARCOLOGY and building <= Tiles.LAUNCH_ARCOLOGY else 2

	return values


# residential desirability of a tile that is not empty. the scan sets empty
# tiles from their water flag
static func _make_residential_values() -> PackedInt32Array:
	var values := PackedInt32Array()
	values.resize(Tiles.COUNT)
	for building in values.size():
		if building == PollutionPhase.BIG_PARK:
			values[building] = 40
		elif building >= PollutionPhase.FIRST_TREE and building <= PollutionPhase.SMALL_PARK:
			values[building] = 20
		elif building < PollutionPhase.FIRST_TREE:
			values[building] = -20

	return values


static func _make_land_value_halved() -> PackedByteArray:
	var values := PackedByteArray()
	values.resize(Tiles.COUNT)
	for building: int in PollutionPhase.LAND_VALUE_HALVED:
		values[building] = 1

	return values


# police and fire stations add a coverage pattern at their origin tile
static func _add_stations(city: CityState, police: PackedByteArray, fire: PackedByteArray) -> void:
	var edge := city.map_size
	var patterns: Dictionary = {}
	var police_strength := (city.document.misc_i32(PollutionPhase.MISC_PRISON_BONUS) + 5) * PollutionPhase._budget_funding(city, PollutionPhase.BUDGET_POLICE) / 2
	var fire_strength := PollutionPhase._budget_funding(city, PollutionPhase.BUDGET_FIRE) * 5 / 2

	# the station list is in the order of a scan by x, then by y
	for index in city.building_indices([PollutionPhase.POLICE_STATION, PollutionPhase.FIRE_STATION]):
		if not city.zones[index] & PollutionPhase.ZONE_BUILDING_ORIGIN:
			continue

		var building := city.buildings[index]
		var strength := police_strength if building == PollutionPhase.POLICE_STATION else fire_strength

		if not city.tile_flags[index] & PollutionPhase.FLAG_POWERED:
			strength /= 2

		_checkpoint(city)

		if not patterns.has(strength):
			patterns[strength] = NativeGridMath.service_pattern(strength)

		NativeGridMath.apply_service_pattern(police if building == PollutionPhase.POLICE_STATION else fire, edge, Vector2i(index / edge, index % edge), patterns[strength])


static func _checkpoint(city: CityState) -> void:
	if city.simulation_slice != null:
		city.simulation_slice.checkpoint()
