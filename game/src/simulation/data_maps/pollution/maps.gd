class_name PollutionMaps
extends PollutionValues

# Inline integer division avoids a function call for every cell.
@warning_ignore_start("integer_division")
# compute coarse maps in their original scan and checkpoint order


static func build(
	city: CityState, span: SimulationTimingSpan, map_edge: int,
	traffic_chunk: Sc2Chunk, pollution_chunk: Sc2Chunk, crime_chunk: Sc2Chunk,
	population_chunk: Sc2Chunk, growth_chunk: Sc2Chunk
) -> Dictionary:
	# the half and quarter grid edges stay constant for the whole scan
	var half_edge := map_edge / 2
	var quarter_edge := map_edge / 4
	var buildings := city.buildings
	var zones := city.zones
	var terrain_map := city.terrain
	var old_pollution: PackedByteArray = pollution_chunk.decoded_payload
	var old_traffic: PackedByteArray = traffic_chunk.decoded_payload
	var pollution_sources := PackedInt32Array()
	pollution_sources.resize(map_edge * map_edge)

	for x in half_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var coarse_row := x * half_edge
		var pollution_sources_row := x * map_edge

		for y in half_edge:
			var map_index := coarse_row + y
			var value := int(old_traffic[map_index]) / 5
			value += old_pollution[map_index]

			for full_x in range(x * 2, x * 2 + 2):
				var full_row := full_x * map_edge

				for full_y in range(y * 2, y * 2 + 2):
					var building := buildings[full_row + full_y]

					if building >= FIRST_POLLUTING_BUILDING:
						value += BUILDING_POLLUTION.get(building, 0)

					if building == RADIOACTIVITY:
						value += 200

			pollution_sources[pollution_sources_row + y] = value

	span.mark("pollution smoothing")
	var base_divisor := pollution_divisor(city.document)

	var pollution := PackedByteArray()
	pollution.resize(half_edge * half_edge)
	var total := 0

	for x in half_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var map_row := x * half_edge
		var pollution_sources_row := x * map_edge

		for y in half_edge:
			var index := map_row + y
			var pollution_sources_index := pollution_sources_row + y
			var numerator := pollution_sources[pollution_sources_index] * 2
			var divisor := base_divisor

			if x > 0:
				numerator += pollution_sources[pollution_sources_index - map_edge]
				divisor += 1

			if x < half_edge - 1:
				numerator += pollution_sources[pollution_sources_index + map_edge]
				divisor += 1

			if y > 0:
				numerator += pollution_sources[pollution_sources_index - 1]
				divisor += 1

			if y < half_edge - 1:
				numerator += pollution_sources[pollution_sources_index + 1]
				divisor += 1

			var value := mini(numerator / divisor, 0xff)
			pollution[index] = value
			total += value


	span.mark("city center")
	var flags := city.tile_flags.duplicate()
	var coordinate_sum_x := 0
	var coordinate_sum_y := 0
	var center_divisor := 1

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var row := x * map_edge

		for y in map_edge:
			var index := row + y

			if buildings[index] > 0x6f:
				coordinate_sum_x += x
				coordinate_sum_y += y
				center_divisor += 1
				flags[index] &= ~FLAG_MARK & 0xff

	var center_x := int(coordinate_sum_x / (center_divisor * 2))
	var center_y := int(coordinate_sum_y / (center_divisor * 2))

	span.mark("terrain desirability")
	# pollution and full-coordinate center scans must not seed quarter-grid values
	var temporary := PackedInt32Array()
	temporary.resize(map_edge * map_edge)
	var developed_tiles := 0

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var row := x * map_edge
		var quarter_x := x >> 2
		var residential_row := quarter_x * map_edge
		var industrial_row := (quarter_x + quarter_edge) * map_edge
		var marked_row := (x >> 1) * map_edge

		for y in map_edge:
			var index := row + y
			var quarter_y := y >> 2
			var residential_index := residential_row + quarter_y
			var industrial_index := industrial_row + quarter_y
			var residential_value := temporary[residential_index]
			var industrial_value := temporary[industrial_index]
			var building := buildings[index]

			if building == 0:
				if flags[index] & FLAG_WATER:
					residential_value += 12
					industrial_value += 12
				else:
					residential_value += 4
			elif building == BIG_PARK:
				residential_value += 40
			elif building >= FIRST_TREE and building <= SMALL_PARK:
				residential_value += 20
			elif building < FIRST_TREE:
				residential_value -= 20

			if building >= FIRST_ROAD or zones[index] & 0x0f:
				flags[marked_row + (y >> 1)] |= FLAG_MARK
				developed_tiles += 1

			if flags[index] & FLAG_WATERED:
				residential_value += 4
				industrial_value += 4

			var terrain := terrain_map[index]

			if terrain != 0 and terrain < 0x10:
				residential_value += 12

			temporary[residential_index] = residential_value
			temporary[industrial_index] = industrial_value

	span.mark("land value")
	var old_crime: PackedByteArray = crime_chunk.decoded_payload
	var old_population: PackedByteArray = population_chunk.decoded_payload
	var old_growth: PackedByteArray = growth_chunk.decoded_payload
	var land_value := PackedByteArray()
	land_value.resize(half_edge * half_edge)
	var land_value_total := 0

	for x in half_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var map_row := x * half_edge
		var flag_row := x * map_edge
		var full_x := x * 2
		var building_row := full_x * map_edge

		for y in half_edge:
			var map_index := map_row + y

			if not flags[flag_row + y] & FLAG_MARK:
				continue

			var full_y := y * 2
			var full_index := building_row + full_y
			var zone := zones[full_index] & 0x0f

			if zone == 0:
				zone = zones[full_index + map_edge + 1] & 0x0f

			var service_x := x >> 1
			var service_y := y >> 1
			var distance_value := 64 - absi(center_x - x) - absi(center_y - y)
			var value := 0

			match zone:
				3, 4:
					value = _average_service_grid(temporary, service_x, service_y, 0, map_edge)
					value += maxi(distance_value, 0)
					value -= int(pollution[map_index]) / 4
					value -= int(old_crime[map_index]) / 3
					value += int(old_population[service_x * quarter_edge + service_y]) / 3
				5, 6:
					value = _average_service_grid(
						temporary, service_x, service_y, quarter_edge, map_edge
					)

					if zone == 6:
						value += 21

					value += maxi(_divide_toward_zero(distance_value, 4), 0)
					value -= int(pollution[map_index]) / 16
					value -= int(old_crime[map_index]) / 4
				_:
					value = _average_service_grid(temporary, service_x, service_y, 0, map_edge)

					if old_population[service_x * quarter_edge + service_y] < 0x40:
						value += 21

					value += maxi(_divide_toward_zero(distance_value, 2), 0)
					value -= int(pollution[map_index]) / 5
					value -= int(old_crime[map_index]) / 3

			var building := buildings[full_index]

			if building >= FIRST_POLLUTING_BUILDING and LAND_VALUE_HALVED.has(building):
				value -= _divide_toward_zero(value, 2)

			value = clampi(value, 0, 0xff)
			land_value[map_index] = value
			land_value_total += value

	for x in quarter_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var row := x * map_edge

		for y in quarter_edge:
			temporary[row + y] = 0

	span.mark("services and population sources")
	var police := PackedByteArray()
	police.resize(quarter_edge * quarter_edge)
	var fire := PackedByteArray()
	fire.resize(quarter_edge * quarter_edge)
	var ordinances := city.document.misc_u32(MISC_ORDINANCES)

	for x in range(1, map_edge - 1):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var row := x * map_edge
		var service_x := x >> 2
		var temporary_row := service_x * map_edge

		for y in range(1, map_edge - 1):
			var index := row + y
			var building := buildings[index]
			var service_y := y >> 2
			var service_index := service_x * quarter_edge + service_y

			if building >= FIRST_POLLUTING_BUILDING and building < FIRST_POWER_PLANT:
				temporary[temporary_row + service_y] += _population_weight(building)

				if ordinances & POLICE_COVERAGE_ORDINANCE and police[service_index] < 0xfe:
					police[service_index] += 2

				if ordinances & FIRE_COVERAGE_ORDINANCE and fire[service_index] < 0xfe:
					fire[service_index] += 2
			elif building >= FIRST_POWER_PLANT:
				temporary[temporary_row + service_y] += (
					12 if building >= FIRST_ARCOLOGY and building <= LAST_ARCOLOGY else 2
				)

				if not city.zones[index] & ZONE_BUILDING_ORIGIN:
					continue

				if building == POLICE_STATION:
					var strength := int(
						(((city.document.misc_i32(MISC_PRISON_BONUS) + 5)
						* _budget_funding(city, BUDGET_POLICE)) / 2)
					)

					if not flags[index] & FLAG_POWERED:
						strength = _divide_toward_zero(strength, 2)

					_add_service(police, service_x, service_y, strength, map_edge)
				elif building == FIRE_STATION:
					var strength := int((_budget_funding(city, BUDGET_FIRE) * 5) / 2)

					if not flags[index] & FLAG_POWERED:
						strength = _divide_toward_zero(strength, 2)

					_add_service(fire, service_x, service_y, strength, map_edge)

	span.mark("population and growth")
	var population := PackedByteArray()
	population.resize(quarter_edge * quarter_edge)
	var growth := PackedByteArray()
	growth.resize(quarter_edge * quarter_edge)

	for x in quarter_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var row := x * quarter_edge
		var temporary_row := x * map_edge

		for y in quarter_edge:
			var index := row + y
			var population_value := mini(temporary[temporary_row + y] * 4, 0xff)
			population[index] = population_value
			var growth_numerator := (
				int(old_growth[index]) * 7
				+ (population_value - int(old_population[index])) * 8
				+ 128
			)
			growth[index] = clampi(_divide_toward_zero(growth_numerator, 8), 0, 0xff)

	for x in half_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var map_row := x * half_edge
		var temporary_row := x * map_edge
		var service_row := (x >> 1) * quarter_edge

		for y in half_edge:
			var index := map_row + y
			var temporary_index := temporary_row + y

			if not flags[temporary_index] & FLAG_MARK:
				temporary[temporary_index] = 0
				continue

			var service_index := service_row + (y >> 1)
			var value := int(population[service_index])
			value -= int(land_value[index]) / 4
			value -= int(police[service_index]) / 2

			if ordinances & CRIME_REDUCTION_ORDINANCE:
				value += 16

			temporary[temporary_index] = value

	span.mark("crime smoothing")
	var crime := PackedByteArray()
	crime.resize(half_edge * half_edge)
	var crime_total := 0

	for x in half_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var map_row := x * half_edge
		var temporary_row := x * map_edge

		for y in half_edge:
			var temporary_index := temporary_row + y
			var numerator := temporary[temporary_index]
			var divisor := 1

			if x > 0:
				numerator += temporary[temporary_index - map_edge]
				divisor += 1

			if x < half_edge - 1:
				numerator += temporary[temporary_index + map_edge]
				divisor += 1

			if y > 0:
				numerator += temporary[temporary_index - 1]
				divisor += 1

			if y < half_edge - 1:
				numerator += temporary[temporary_index + 1]
				divisor += 1

			var value := clampi(_divide_toward_zero(numerator, divisor), 0, 0xff)
			crime[map_row + y] = value
			crime_total += value

	return {
		"pollution": pollution,
		"land_value": land_value,
		"police": police,
		"fire": fire,
		"population": population,
		"growth": growth,
		"crime": crime,
		"flags": flags,
		"total": total,
		"land_value_total": land_value_total,
		"crime_total": crime_total,
		"center_x": center_x,
		"center_y": center_y,
		"developed_tiles": developed_tiles,
	}
