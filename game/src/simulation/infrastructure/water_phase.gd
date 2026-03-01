class_name WaterPhase
extends RefCounted

const MAP_SIZE := CityState.MAP_SIZE
const FLAG_SALT_WATER := 0x01
const FLAG_WATER := 0x04
const FLAG_MARK := 0x08
const FLAG_WATERED := 0x10
const FLAG_PIPED := 0x20
const FLAG_POWERED := 0x40
const FIRST_CONSUMER := 0x70
const MISC_TILE_COUNTS := 0x01f0
const MISC_TREATMENT_SUFFICIENT := 0x104c
const WATER_PUMP := 0xdc
const WATER_TOWER := 0xeb
const WATER_TREATMENT := 0xf4
const DESALINIZATION := 0xfa


static func run(city: CityState) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	var flags := city.tile_flags.duplicate()

	for index in flags.size():
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		flags[index] &= ~FLAG_MARK & 0xff

		if city.buildings[index] != WATER_TOWER:
			flags[index] &= ~FLAG_WATERED & 0xff

	var total_supply := 0
	var total_consumers := 0
	var watered_consumers := 0
	var pump_base_supply := int((city.document.misc_u32(0x68) & 0xff) / 2)
	pump_base_supply += city.document.misc_u32(0x0e40) * 5

	for index in _source_scan_order(city.compass_rotation(), map_edge, city.simulation_slice):
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		var building := city.buildings[index]

		if building != WATER_PUMP and building != DESALINIZATION:
			continue

		if flags[index] & FLAG_WATERED or not flags[index] & FLAG_POWERED:
			continue

		var component := _trace_component(city.buildings, flags, index, pump_base_supply, map_edge, city.simulation_slice)
		var supply: int = component.supply
		var consumers: int = component.consumers
		var served := mini(supply, consumers)
		var tower_capacity: int = component.tower_capacity
		var stored_units := mini(supply - served, tower_capacity)
		var towers_to_fill := int((stored_units + 50) / 100)

		total_supply += supply
		total_consumers += consumers
		watered_consumers += served

		for component_index in component.tiles:
			var tile_building := city.buildings[component_index]

			match tile_building:
				WATER_PUMP, WATER_TREATMENT, DESALINIZATION:
					if flags[component_index] & FLAG_POWERED:
						flags[component_index] |= FLAG_WATERED
				WATER_TOWER:
					if flags[component_index] & FLAG_POWERED and towers_to_fill != 0:
						flags[component_index] |= FLAG_WATERED
						towers_to_fill -= 1
				_:
					if served != 0:
						flags[component_index] |= FLAG_WATERED

						if tile_building >= FIRST_CONSUMER:
							served -= 1

			flags[component_index] &= ~FLAG_MARK & 0xff

	if not city.replace_tile_flags(flags):
		return {"ok": false, "error": "cannot store updated XBIT data"}

	var usage_percent := 100

	if total_supply != 0:
		usage_percent = int(watered_consumers * 100 / total_supply)

	var treatment_tile_count := city.document.misc_u32(MISC_TILE_COUNTS + WATER_TREATMENT * 4)

	if not city.document.is_extended():
		treatment_tile_count = _to_i16(treatment_tile_count)

	var treatment_capacity := int(treatment_tile_count / 4) * 2000
	var treatment_sufficient := watered_consumers <= treatment_capacity

	if not city.document.set_misc_u32(
		MISC_TREATMENT_SUFFICIENT, 1 if treatment_sufficient else 0
	):
		return {"ok": false, "error": "cannot store water-treatment state"}

	return {
		"ok": true,
		"supply": total_supply,
		"consumers": total_consumers,
		"watered_consumers": watered_consumers,
		"usage_percent": usage_percent,
		"treatment_capacity": treatment_capacity,
		"treatment_sufficient": treatment_sufficient,
		"error": "",
	}


static func _trace_component(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	start: int,
	pump_base_supply: int,
	map_edge: int = 128,
	budget: SimulationSliceBudget = null,
) -> Dictionary:
	var queue := PackedInt32Array([start])
	var queue_position := 0
	var tiles := PackedInt32Array()
	var supply := 0
	var consumers := 0
	var tower_capacity := 0

	if not flags[start] & FLAG_PIPED:
		return {
			"tiles": tiles,
			"supply": supply,
			"consumers": consumers,
			"tower_capacity": tower_capacity,
		}

	flags[start] |= FLAG_MARK

	while queue_position < queue.size():
		if budget != null and (queue_position & 127) == 0:
			budget.checkpoint()

		var index := queue[queue_position]
		queue_position += 1
		tiles.append(index)
		var x := int(index / map_edge)
		var y := index % map_edge
		var building := buildings[index]

		if building >= FIRST_CONSUMER:
			match building:
				WATER_PUMP:
					if flags[index] & FLAG_POWERED:
						supply += _pump_supply(flags, x, y, pump_base_supply, map_edge)
				WATER_TOWER:
					tower_capacity += 100

					if flags[index] & FLAG_WATERED:
						supply += 100

					flags[index] &= ~FLAG_WATERED & 0xff
				WATER_TREATMENT:
					pass
				DESALINIZATION:
					if flags[index] & FLAG_POWERED:
						supply += _desalinization_supply(flags, x, y, map_edge)
				_:
					consumers += 1

		if y > 0:
			_queue_piped_tile(queue, flags, index - 1)

		if x > 0:
			_queue_piped_tile(queue, flags, index - map_edge)

		if y < map_edge - 1:
			_queue_piped_tile(queue, flags, index + 1)

		if x < map_edge - 1:
			_queue_piped_tile(queue, flags, index + map_edge)

	return {
		"tiles": tiles,
		"supply": supply,
		"consumers": consumers,
		"tower_capacity": tower_capacity,
	}


static func _queue_piped_tile(
	queue: PackedInt32Array, flags: PackedByteArray, index: int
) -> void:
	if flags[index] & (FLAG_MARK | FLAG_PIPED) != FLAG_PIPED:
		return

	flags[index] |= FLAG_MARK
	queue.append(index)


static func _pump_supply(
	flags: PackedByteArray, x: int, y: int, base_supply: int,
	map_edge: int = 128,
) -> int:
	var supply := base_supply

	for near_x in range(maxi(x - 1, 0), mini(x + 2, map_edge)):
		for near_y in range(maxi(y - 1, 0), mini(y + 2, map_edge)):
			var water_bits := flags[near_x * map_edge + near_y] & (
				FLAG_SALT_WATER | FLAG_WATER
			)

			if water_bits == FLAG_WATER:
				supply += 10

	return supply


static func _desalinization_supply(flags: PackedByteArray, x: int, y: int, map_edge: int = 128) -> int:
	var supply := 0

	for near_x in range(maxi(x - 1, 0), mini(x + 2, map_edge)):
		for near_y in range(maxi(y - 1, 0), mini(y + 2, map_edge)):
			var water_bits := flags[near_x * map_edge + near_y] & (
				FLAG_SALT_WATER | FLAG_WATER
			)

			if water_bits == FLAG_SALT_WATER | FLAG_WATER:
				supply += 20

	return supply


static func _source_scan_order(rotation: int, map_edge: int = 128, budget: SimulationSliceBudget = null) -> PackedInt32Array:
	var result := PackedInt32Array()

	match rotation & 3:
		0:
			for y in map_edge:
				if budget != null:
					budget.checkpoint()

				for x in map_edge:
					result.append(x * map_edge + y)
		1:
			for x in map_edge:
				if budget != null:
					budget.checkpoint()

				for y in range(map_edge - 1, -1, -1):
					result.append(x * map_edge + y)
		2:
			for y in range(map_edge - 1, -1, -1):
				if budget != null:
					budget.checkpoint()

				for x in range(map_edge - 1, -1, -1):
					result.append(x * map_edge + y)
		3:
			for x in range(map_edge - 1, -1, -1):
				if budget != null:
					budget.checkpoint()

				for y in map_edge:
					result.append(x * map_edge + y)

	return result


static func _to_i16(value: int) -> int:
	value &= 0xffff

	return value - 0x10000 if value >= 0x8000 else value
