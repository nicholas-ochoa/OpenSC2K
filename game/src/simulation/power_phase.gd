class_name PowerPhase
extends RefCounted

const MAP_SIZE := CityState.MAP_SIZE
const FLAG_MARK := 0x08
const FLAG_POWERED := 0x40
const FLAG_POWERABLE := 0x80
const FIRST_CONSUMER := 0x70
const FIRST_PLANT := 0xc6
const LAST_PLANT := 0xcf
const SOLAR_EFFICIENCY_ORDINANCE := 0x10000


static func run(city: CityState, random: SimRandom) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null:
		return {"ok": false, "error": "random state is required"}

	var flags := city.tile_flags.duplicate()

	for index in flags.size():
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		flags[index] &= 0xb7

	var total_generation := 0
	var supplied_consumers := 0
	var total_consumers := 0

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

			var component := _trace_component(city, flags, x, y, random)
			var capacity: int = component.capacity
			var consumers: int = component.consumers
			total_generation += capacity
			total_consumers += consumers

			if city.document.misc_u32(0x0fa0) & SOLAR_EFFICIENCY_ORDINANCE:
				capacity += int(capacity / 12)

			supplied_consumers += mini(capacity, consumers)

			for component_index in component.tiles:
				if capacity != 0:
					if city.buildings[component_index] >= FIRST_CONSUMER:
						capacity -= 1

					flags[component_index] |= FLAG_POWERED

				flags[component_index] &= ~FLAG_MARK & 0xff

	if not city.replace_tile_flags(flags):
		return {"ok": false, "error": "cannot store updated XBIT data"}

	var usage_percent := 100

	if total_generation != 0:
		usage_percent = mini(int(supplied_consumers * 100 / total_generation), 100)

	return {
		"ok": true,
		"generation": total_generation,
		"consumers": total_consumers,
		"supplied_consumers": supplied_consumers,
		"usage_percent": usage_percent,
		"error": "",
	}


static func _trace_component(
	city: CityState, flags: PackedByteArray, start_x: int, start_y: int, random: SimRandom
) -> Dictionary:
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

	return {"tiles": tiles, "capacity": capacity, "consumers": consumers}


static func _plant_capacity(
	city: CityState, building: int, x: int, y: int, random: SimRandom
) -> int:
	match building:
		0xc6, 0xc7:
			return 40
		0xc8:
			var wind := city.document.misc_u32(0x64) & 0xff

			return int((city.land_altitude(x, y) + random.next_u15() % (int(wind / 8) + 1)) / 2)
		0xc9:
			return 11
		0xca:
			return 48
		0xcb:
			return 111
		0xcc:
			var rain := city.document.misc_u32(0x68) & 0xff
			var sunlight_range: int = maxi(int((100 - rain) / 10), 1)

			return random.next_u15() % sunlight_range + 5
		0xcd:
			return 355
		0xce:
			return 555
		0xcf:
			return 44

	return 0
