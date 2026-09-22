class_name PowerPhase
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const MAP_SIZE := CityState.MAP_SIZE
const FLAG_MARK := Sc2TileFlags.MARK
const FLAG_POWERED := Sc2TileFlags.POWERED
const FLAG_POWERABLE := Sc2TileFlags.POWERABLE
const FIRST_CONSUMER := Tiles.DEVELOPED_FIRST
const FIRST_PLANT := Tiles.HYDRO_POWER_1
const LAST_PLANT := Tiles.COAL_POWER
const SOLAR_EFFICIENCY_ORDINANCE := OrdinanceIds.ENERGY_CONSERVATION_MASK


class Result extends PhaseResult:
	var generation := 0
	var consumers := 0
	var supplied_consumers := 0
	var usage_percent := 0


class Component extends RefCounted:
	var tiles := PackedInt32Array()
	var capacity := 0
	var consumers := 0


static func run(city: CityState, random: SimRandom) -> Result:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("random state is required")

	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("copy tile flags")
	var flags := city.tile_flags.duplicate()
	span.mark("clear power and scan marks")

	for index in flags.size():
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		flags[index] &= ~(Sc2TileFlags.MARK | Sc2TileFlags.POWERED) & 0xff

	var total_generation := 0
	var supplied_consumers := 0
	var total_consumers := 0
	span.mark("find power sources")

	for x in map_edge:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y in map_edge:
			var index := city.index_of(x, y)
			var building := city.buildings[index]

			if building < FIRST_PLANT or building > LAST_PLANT:
				continue

			if flags[index] & FLAG_POWERED:
				continue

			span.mark("network traversal and generation")
			var component := _trace_component(city, flags, x, y, random)
			span.mark("capacity and ordinance totals")
			var capacity: int = component.capacity
			var consumers: int = component.consumers
			total_generation += capacity
			total_consumers += consumers

			if city.document.misc_u32(Sc2MiscLayout.ORDINANCES) & SOLAR_EFFICIENCY_ORDINANCE:
				capacity += int(capacity / 12)

			supplied_consumers += mini(capacity, consumers)

			span.mark("distribute power")
			for component_index in component.tiles:
				if capacity != 0:
					if city.buildings[component_index] >= FIRST_CONSUMER:
						capacity -= 1

					flags[component_index] |= FLAG_POWERED

				flags[component_index] &= ~FLAG_MARK & 0xff

			span.mark("find power sources")

	span.mark("store powered tiles")
	if not city.replace_tile_flags(flags):
		return _failed("cannot store updated XBIT data")

	span.mark("utilization")
	var usage_percent := 100

	if total_generation != 0:
		usage_percent = mini(int((supplied_consumers * 100) / total_generation), 100)

	var result := Result.new()
	result.ok = true
	result.generation = total_generation
	result.consumers = total_consumers
	result.supplied_consumers = supplied_consumers
	result.usage_percent = usage_percent
	result.timing = span.finish()

	return result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func _trace_component(
	city: CityState, flags: PackedByteArray, start_x: int, start_y: int, random: SimRandom
) -> Component:
	var map_edge: int = city.map_size if city != null else 128
	var queue := PackedInt32Array([city.index_of(start_x, start_y)])
	var queue_position := 0
	var tiles := PackedInt32Array()
	var capacity := 0
	var consumers := 0
	var extended_consumers := city.document.is_extended()

	while queue_position < queue.size():
		if city.simulation_slice != null and (queue_position & 127) == 0:
			city.simulation_slice.checkpoint()

		var index := queue[queue_position]
		queue_position += 1

		if flags[index] & FLAG_MARK or not flags[index] & FLAG_POWERABLE:
			continue

		flags[index] |= FLAG_MARK
		tiles.append(index)
		var x := int(index / map_edge)
		var y := index % map_edge
		var building := city.buildings[index]

		if building >= FIRST_PLANT and building <= LAST_PLANT:
			capacity += _plant_capacity(city, building, x, y, random)
		elif building >= FIRST_CONSUMER and (extended_consumers or building < FIRST_PLANT):
			consumers += 1

		if y > 0:
			queue.append(city.index_of(x, y - 1))

		if x > 0:
			queue.append(city.index_of(x - 1, y))

		if y < map_edge - 1:
			queue.append(city.index_of(x, y + 1))

		if x < map_edge - 1:
			queue.append(city.index_of(x + 1, y))

	var result := Component.new()
	result.tiles = tiles
	result.capacity = capacity
	result.consumers = consumers

	return result


static func _plant_capacity(
	city: CityState, building: int, x: int, y: int, random: SimRandom
) -> int:
	match building:
		Tiles.HYDRO_POWER_1, Tiles.HYDRO_POWER_2:
			return 40
		Tiles.WIND_POWER:
			var wind := city.document.misc_u32(Sc2MiscLayout.WEATHER_WIND) & 0xff

			return int((city.land_altitude(x, y) + random.next_u15() % (int(wind / 8) + 1)) / 2)
		Tiles.GAS_POWER:
			return 11
		Tiles.OIL_POWER:
			return 48
		Tiles.NUCLEAR_POWER:
			return 111
		Tiles.SOLAR_POWER:
			var rain := city.document.misc_u32(Sc2MiscLayout.WEATHER_RAIN) & 0xff
			var sunlight_range: int = maxi(int((100 - rain) / 10), 1)

			return random.next_u15() % sunlight_range + 5
		Tiles.MICROWAVE_POWER:
			return 355
		Tiles.FUSION_POWER:
			return 555
		Tiles.COAL_POWER:
			return 44

	return 0
