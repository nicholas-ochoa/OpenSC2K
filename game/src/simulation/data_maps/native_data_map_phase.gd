class_name NativeDataMapPhase
extends RefCounted

# Inline integer division avoids a function call for every cell.
@warning_ignore_start("integer_division")
# SC2X v3 per-tile rules. These differ from the original executable's coarse-grid rules.


const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

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
	var misc := doc.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() != 4800:
		return PollutionPhase.failed("MISC is missing or invalid")

	var sources := PackedInt32Array()
	var residential := PackedInt32Array()
	var industrial := PackedInt32Array()
	var weights := PackedInt32Array()
	var occupied := PackedInt32Array()

	for values in [sources, residential, industrial, weights, occupied]:
		values.resize(count)

	var center_sum := Vector2i.ZERO
	var center_count := 0
	var developed := 0

	for x in edge:
		_checkpoint(city)

		for y in edge:
			var index := x * edge + y
			var building := int(buildings[index])
			var tile_flags := int(flags[index])
			var zone := int(zones[index]) & 15
			sources[index] = int(old_pollution[index]) + int(old_traffic[index]) / 5
			sources[index] += int(PollutionPhase.BUILDING_POLLUTION.get(building, 0)) * 4

			if building == PollutionPhase.RADIOACTIVITY:
				sources[index] += 800

			if building >= PollutionPhase.FIRST_POLLUTING_BUILDING:
				center_sum += Vector2i(x, y)
				center_count += 1

			if building >= PollutionPhase.FIRST_ROAD or zone != 0:
				developed += 1

			if building == Tiles.EMPTY:
				residential[index] = 12 if tile_flags & PollutionPhase.FLAG_WATER else 4
				industrial[index] = 12 if tile_flags & PollutionPhase.FLAG_WATER else 0
			elif building == PollutionPhase.BIG_PARK:
				residential[index] = 40
			elif building >= PollutionPhase.FIRST_TREE and building <= PollutionPhase.SMALL_PARK:
				residential[index] = 20
			elif building < PollutionPhase.FIRST_TREE:
				residential[index] = -20

			if tile_flags & PollutionPhase.FLAG_WATERED:
				residential[index] += 4
				industrial[index] += 4

			if terrain[index] > TerrainTileIds.FLAT and terrain[index] < TerrainTileIds.DEEP_WATER_FIRST:
				residential[index] += 12

			if building >= Tiles.DEVELOPED_FIRST and building < Tiles.HYDRO_POWER_1:
				weights[index] = PollutionPhase._population_weight(building)
				occupied[index] = 1
			elif building >= Tiles.HYDRO_POWER_1:
				weights[index] = 12 if building >= Tiles.PLYMOUTH_ARCOLOGY and building <= Tiles.LAUNCH_ARCOLOGY else 2

	var center := Vector2i(edge / 2, edge / 2) if center_count == 0 else Vector2i(center_sum.x / center_count, center_sum.y / center_count)
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

	for x in edge:
		_checkpoint(city)

		for y in edge:
			var index := x * edge + y
			growth[index] = clampi((int(old_growth[index]) * 7 + (int(population[index]) - int(old_population[index])) * 8 + 128) / 8, 0, 255)
			var zone := int(zones[index]) & 15
			sources[index] = 0

			if buildings[index] < PollutionPhase.FIRST_ROAD and zone == 0:
				continue

			var distance_value := 64 - (absi(center.x - x) + absi(center.y - y)) / 2
			var value := residential[index]

			match zone:
				3, 4:
					value += maxi(distance_value, 0) - int(pollution[index]) / 4 - int(old_crime[index]) / 3 + int(old_population[index]) / 3
				5, 6:
					value = industrial[index] + (21 if zone == 6 else 0)
					value += maxi(distance_value / 4, 0) - int(pollution[index]) / 16 - int(old_crime[index]) / 4
				_:
					value += 21 if old_population[index] < 64 else 0
					value += maxi(distance_value / 2, 0) - int(pollution[index]) / 5 - int(old_crime[index]) / 3

			if PollutionPhase.LAND_VALUE_HALVED.has(int(buildings[index])):
				value -= value / 2

			land[index] = clampi(value, 0, 255)
			land_sum += land[index]
			# all crime inputs are available here. preserve the same per-tile math
			sources[index] = int(population[index]) - int(land[index]) / 4 - int(police[index]) / 2

			if ordinances & PollutionPhase.CRIME_REDUCTION_ORDINANCE:
				sources[index] += 16

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


static func _add_stations(city: CityState, police: PackedByteArray, fire: PackedByteArray) -> void:
	var edge := city.map_size
	var patterns: Dictionary = {}
	var police_strength := (city.document.misc_i32(PollutionPhase.MISC_PRISON_BONUS) + 5) * PollutionPhase._budget_funding(city, PollutionPhase.BUDGET_POLICE) / 2
	var fire_strength := PollutionPhase._budget_funding(city, PollutionPhase.BUDGET_FIRE) * 5 / 2

	for x in edge:
		_checkpoint(city)

		for y in edge:
			var index := x * edge + y

			if not city.zones[index] & PollutionPhase.ZONE_BUILDING_ORIGIN:
				continue

			var building := int(city.buildings[index])
			var strength := 0

			if building == PollutionPhase.POLICE_STATION:
				strength = police_strength
			elif building == PollutionPhase.FIRE_STATION:
				strength = fire_strength
			else:
				continue

			if not city.tile_flags[index] & PollutionPhase.FLAG_POWERED:
				strength /= 2

			_checkpoint(city)

			if not patterns.has(strength):
				patterns[strength] = NativeGridMath.service_pattern(strength)

			NativeGridMath.apply_service_pattern(police if building == PollutionPhase.POLICE_STATION else fire, edge, Vector2i(x, y), patterns[strength])


static func _checkpoint(city: CityState) -> void:
	if city.simulation_slice != null:
		city.simulation_slice.checkpoint()
