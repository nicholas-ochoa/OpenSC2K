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

static func run(city: CityState) -> PollutionPhase.Result:
	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("sources and terrain")
	var edge := city.map_size
	var count := edge * edge
	var doc := city.document
	var old := {}

	for id in Sc2File.HALF_MAP_CHUNKS + Sc2File.QUARTER_MAP_CHUNKS:
		var chunk := doc.find_chunk(id)

		if chunk == null or chunk.decoded_payload.size() != count:
			return PollutionPhase.failed("Native data map %s is missing or invalid" % id)

		old[id] = chunk.decoded_payload

	var old_pollution: PackedByteArray = old.XPLT
	var old_traffic: PackedByteArray = old.XTRF
	var old_growth: PackedByteArray = old.XROG
	var old_population: PackedByteArray = old.XPOP
	var old_crime: PackedByteArray = old.XCRM
	var buildings := city.buildings
	var flags := city.tile_flags
	var zones := city.zones
	var terrain := city.terrain
	var pollution_weights := _pollution_weights
	var density_weights := _density_weights
	var residential_values := _residential_values
	var misc := doc.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() != Sc2MiscLayout.SIZE:
		return PollutionPhase.failed("MISC is missing or invalid")

	var sources := PackedInt32Array()
	var residential := PackedInt32Array()
	var industrial := PackedInt32Array()
	var weights := PackedInt32Array()
	var occupied := PackedInt32Array()

	for values in [sources, residential, industrial, weights, occupied]:
		values.resize(count)

	var center_x_sum := 0
	var center_y_sum := 0
	var center_count := 0
	var developed := 0

	for x in edge:
		_checkpoint(city)
		var row := x * edge

		for y in edge:
			var index := row + y
			var building := buildings[index]
			var tile_flags := flags[index]
			sources[index] = old_pollution[index] + old_traffic[index] / 5 + pollution_weights[building]

			if building >= PollutionPhase.FIRST_POLLUTING_BUILDING:
				center_x_sum += x
				center_y_sum += y
				center_count += 1

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

			if building >= Tiles.DEVELOPED_FIRST and building < Tiles.HYDRO_POWER_1:
				occupied[index] = 1

	var center := Vector2i(edge / 2, edge / 2) if center_count == 0 else Vector2i(center_x_sum / center_count, center_y_sum / center_count)
	var ordinances := doc.misc_u32(PollutionPhase.MISC_ORDINANCES)
	var divisor := PollutionPhase.pollution_divisor(doc)
	span.mark("pollution smoothing")
	var pollution_result := NativeGridMath.smooth_bytes(sources, edge, 4, maxi(divisor, 1) * 2, 1, 2, city.simulation_slice)
	var pollution: PackedByteArray = pollution_result.values
	span.mark("land desirability filters")
	residential = NativeGridMath.neighborhood(residential, edge, 2, 16, city.simulation_slice)
	industrial = NativeGridMath.neighborhood(industrial, edge, 2, 16, city.simulation_slice)
	residential = NativeGridMath.smooth(residential, edge, 1, 1, 4, 1, city.simulation_slice)
	industrial = NativeGridMath.smooth(industrial, edge, 1, 1, 4, 1, city.simulation_slice)
	span.mark("population density")
	var population := NativeGridMath.neighborhood_bytes(weights, edge, 2, 64, city.simulation_slice)
	span.mark("ordinance coverage")
	var ordinance_coverage := PackedByteArray()

	if ordinances & (PollutionPhase.POLICE_COVERAGE_ORDINANCE | PollutionPhase.FIRE_COVERAGE_ORDINANCE):
		ordinance_coverage = NativeGridMath.neighborhood_bytes(occupied, edge, 2, 32, city.simulation_slice)

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
	span.mark("land value, growth and crime sources")
	var land_sum := 0
	var land := PackedByteArray()
	var growth := PackedByteArray()
	land.resize(count)
	growth.resize(count)
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
			sources[index] = 0

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
	var crime: PackedByteArray = crime_result.values
	span.mark("store maps and totals")
	var updates := {"XPLT": pollution, "XVAL": land, "XCRM": crime, "XPLC": police, "XFIR": fire, "XPOP": population, "XROG": growth}

	for id in updates:
		doc.find_chunk(id).set_decoded_payload(updates[id])

	# misc totals retain the original half-resolution area unit for economic consumers
	var pollution_total := int(pollution_result.total) / 4
	var land_total := land_sum / 4
	var crime_total := int(crime_result.total) / 4

	for update in [[PollutionPhase.MISC_CITY_POLLUTION, pollution_total],
		[PollutionPhase.MISC_CITY_LAND_VALUE, land_total], [PollutionPhase.MISC_CITY_CRIME, crime_total],
		[PollutionPhase.MISC_CITY_CENTER_X, center.x], [PollutionPhase.MISC_CITY_CENTER_Y, center.y]]:
		doc.set_misc_u32(update[0], update[1])

	return PollutionPhase.totals(
		pollution_total, land_total, crime_total, developed, center, span.finish()
	)


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
