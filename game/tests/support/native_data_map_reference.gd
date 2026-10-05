@warning_ignore_start("integer_division")

# Frozen pre-optimization oracle from e5f6abd9; used only by regression tests.
extends RefCounted

const PollutionReference = preload("res://tests/support/pollution_reference.gd")
const NativeGridReference = preload("res://tests/support/native_grid_reference.gd")

## SC2X v3 rules. These are independent per-tile rules, not executable parity.


static func run(city: CityState) -> PollutionPhase.Result:
	var edge := city.map_size
	var count := edge * edge
	var doc := city.document
	var old := {}

	for id in Sc2File.HALF_MAP_CHUNKS + Sc2File.QUARTER_MAP_CHUNKS:
		var chunk := doc.find_chunk(id)

		if chunk == null or chunk.decoded_payload.size() != count:
			return PollutionPhase.failed("Native data map %s is missing or invalid" % id)

		old[id] = chunk.decoded_payload

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
			var building := int(city.buildings[index])
			var flags := int(city.tile_flags[index])
			var zone := int(city.zones[index]) & 15
			sources[index] = int(old.XPLT[index]) + (int(old.XTRF[index]) / 5)
			sources[index] += int(PollutionReference.BUILDING_POLLUTION.get(building, 0)) * 4

			if building == PollutionReference.RADIOACTIVITY:
				sources[index] += 800

			if building >= PollutionReference.FIRST_POLLUTING_BUILDING:
				center_sum += Vector2i(x, y)
				center_count += 1

			if building >= PollutionReference.FIRST_ROAD or zone != 0:
				developed += 1

			if building == 0:
				residential[index] = 12 if flags & PollutionReference.FLAG_WATER else 4
				industrial[index] = 12 if flags & PollutionReference.FLAG_WATER else 0
			elif building == PollutionReference.BIG_PARK:
				residential[index] = 40
			elif building >= PollutionReference.FIRST_TREE and building <= PollutionReference.SMALL_PARK:
				residential[index] = 20
			elif building < PollutionReference.FIRST_TREE:
				residential[index] = -20

			if flags & PollutionReference.FLAG_WATERED:
				residential[index] += 4
				industrial[index] += 4

			if city.terrain[index] > 0 and city.terrain[index] < 0x10:
				residential[index] += 12

			if building >= 0x70 and building < 0xc6:
				weights[index] = PollutionReference._population_weight(building)
				occupied[index] = 1
			elif building >= 0xc6:
				weights[index] = 12 if building >= 0xfb and building <= 0xfe else 2

	var center := Vector2i(edge / 2, edge / 2) if center_count == 0 else Vector2i(center_sum.x / center_count, center_sum.y / center_count)
	var ordinances := doc.misc_u32(PollutionReference.MISC_ORDINANCES)
	var divisor := PollutionReference.pollution_divisor(doc)
	var pollution := NativeGridReference.bytes(
		NativeGridReference.smooth(sources, edge, 4, maxi(divisor, 1) * 2, 1, 2, city.simulation_slice),
		city.simulation_slice,
	)
	residential = NativeGridReference.neighborhood(residential, edge, 2, 16, city.simulation_slice)
	industrial = NativeGridReference.neighborhood(industrial, edge, 2, 16, city.simulation_slice)
	residential = NativeGridReference.smooth(residential, edge, 1, 1, 4, 1, city.simulation_slice)
	industrial = NativeGridReference.smooth(industrial, edge, 1, 1, 4, 1, city.simulation_slice)
	var population := NativeGridReference.bytes(
		NativeGridReference.neighborhood(weights, edge, 2, 64, city.simulation_slice), city.simulation_slice)
	var ordinance_coverage := NativeGridReference.bytes(
		NativeGridReference.neighborhood(occupied, edge, 2, 32, city.simulation_slice),
		city.simulation_slice,
	)
	var police := PackedByteArray()
	var fire := PackedByteArray()
	police.resize(count)
	fire.resize(count)

	if ordinances & PollutionReference.POLICE_COVERAGE_ORDINANCE:
		police = ordinance_coverage.duplicate()

	if ordinances & PollutionReference.FIRE_COVERAGE_ORDINANCE:
		fire = ordinance_coverage.duplicate()

	_add_stations(city, police, fire)
	var land := PackedByteArray()
	var growth := PackedByteArray()
	land.resize(count)
	growth.resize(count)

	for x in edge:
		_checkpoint(city)

		for y in edge:
			var index := x * edge + y
			growth[index] = clampi((int(old.XROG[index]) * 7 + (int(population[index]) - int(old.XPOP[index])) * 8 + 128) / 8, 0, 255)
			var zone := int(city.zones[index]) & 15

			if city.buildings[index] < PollutionReference.FIRST_ROAD and zone == 0:
				continue

			var distance_value := 64 - ((absi(center.x - x) + absi(center.y - y)) / 2)
			var value := residential[index]

			match zone:
				3, 4:
					value += maxi(distance_value, 0) - (int(pollution[index]) / 4) - (int(old.XCRM[index]) / 3) + (int(old.XPOP[index]) / 3)
				5, 6:
					value = industrial[index] + (21 if zone == 6 else 0)
					value += maxi(distance_value / 4, 0) - (int(pollution[index]) / 16) - (int(old.XCRM[index]) / 4)
				_:
					value += 21 if old.XPOP[index] < 64 else 0
					value += maxi(distance_value / 2, 0) - (int(pollution[index]) / 5) - (int(old.XCRM[index]) / 3)

			if PollutionReference.LAND_VALUE_HALVED.has(int(city.buildings[index])):
				value -= value / 2

			land[index] = clampi(value, 0, 255)

	# Reuse the temporary source array only after pollution has been published locally.
	for x in edge:
		_checkpoint(city)

		for y in edge:
			var index := x * edge + y
			sources[index] = 0

			if city.buildings[index] >= PollutionReference.FIRST_ROAD or city.zones[index] & 15:
				sources[index] = int(population[index]) - (int(land[index]) / 4) - (int(police[index]) / 2)

				if ordinances & PollutionReference.CRIME_REDUCTION_ORDINANCE:
					sources[index] += 16

	var crime := NativeGridReference.bytes(
		NativeGridReference.smooth(sources, edge, 2, 2, 1, 2, city.simulation_slice), city.simulation_slice)
	var updates := { "XPLT": pollution, "XVAL": land, "XCRM": crime, "XPLC": police, "XFIR": fire, "XPOP": population, "XROG": growth }

	for id in updates:
		doc.find_chunk(id).set_decoded_payload(updates[id])

	# MISC totals retain the original half-resolution area unit for economic consumers.
	var pollution_total := _sum(pollution, city) / 4
	var land_total := _sum(land, city) / 4
	var crime_total := _sum(crime, city) / 4

	for update in [[PollutionReference.MISC_CITY_POLLUTION, pollution_total],
		[PollutionReference.MISC_CITY_LAND_VALUE, land_total], [PollutionReference.MISC_CITY_CRIME, crime_total],
		[PollutionReference.MISC_CITY_CENTER_X, center.x], [PollutionReference.MISC_CITY_CENTER_Y, center.y]]:
		doc.set_misc_u32(update[0], update[1])

	return PollutionPhase.totals(
		pollution_total, land_total, crime_total, developed, center
	)


static func _add_stations(city: CityState, police: PackedByteArray, fire: PackedByteArray) -> void:
	var edge := city.map_size

	for x in edge:
		_checkpoint(city)

		for y in edge:
			var index := x * edge + y

			if not city.zones[index] & PollutionReference.ZONE_BUILDING_ORIGIN:
				continue

			var building := int(city.buildings[index])
			var strength := 0

			if building == PollutionReference.POLICE_STATION:
				strength = ((city.document.misc_i32(PollutionReference.MISC_PRISON_BONUS) + 5) * PollutionReference._budget_funding(city,
					PollutionReference.BUDGET_POLICE)) / 2
			elif building == PollutionReference.FIRE_STATION:
				strength = (PollutionReference._budget_funding(city, PollutionReference.BUDGET_FIRE) * 5) / 2
			else:
				continue

			if not city.tile_flags[index] & PollutionReference.FLAG_POWERED:
				strength /= 2

			_checkpoint(city)
			NativeGridReference.add_service(police if building == PollutionReference.POLICE_STATION else fire, edge, Vector2i(x, y), strength)


static func _sum(values: PackedByteArray, city: CityState) -> int:
	var result := 0

	for index in values.size():
		if (index & 1023) == 0:
			_checkpoint(city)

		result += values[index]

	return result


static func _checkpoint(city: CityState) -> void:
	if city.simulation_slice != null:
		city.simulation_slice.checkpoint()
