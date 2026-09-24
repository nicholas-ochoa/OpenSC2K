class_name WaterPhase
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const MAP_SIZE := CityState.MAP_SIZE
const FLAG_SALT_WATER := Sc2TileFlags.SALT_WATER
const FLAG_WATER := Sc2TileFlags.WATER
const FLAG_MARK := Sc2TileFlags.MARK
const FLAG_WATERED := Sc2TileFlags.WATERED
const FLAG_PIPED := Sc2TileFlags.PIPED
const FLAG_POWERED := Sc2TileFlags.POWERED
const FIRST_CONSUMER := Tiles.DEVELOPED_FIRST
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_TREATMENT_SUFFICIENT := Sc2MiscLayout.TREATMENT_SUFFICIENT
const WATER_PUMP := Tiles.WATER_PUMP
const WATER_TOWER := Tiles.WATER_TOWER
const WATER_TREATMENT := Tiles.WATER_TREATMENT
const DESALINIZATION := Tiles.DESALINIZATION


class Result extends PhaseResult:
	var supply := 0
	var consumers := 0
	var watered_consumers := 0
	var usage_percent := 0
	var treatment_capacity := 0
	var treatment_sufficient := false


# the component tiles stay in the caller's queue. `size` counts them
class Component extends RefCounted:
	var size := 0
	var supply := 0
	var consumers := 0
	var tower_capacity := 0


static func run(city: CityState) -> Result:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return _failed("city is invalid")

	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("clear water and scan marks")
	var flags := Sc2TileFlags.without(city.tile_flags, FLAG_MARK | FLAG_WATERED)
	var buildings := city.buildings
	var slice := city.simulation_slice

	# a water tower keeps its stored water
	for index in city.building_indices([WATER_TOWER]):
		flags[index] |= city.tile_flags[index] & FLAG_WATERED

	var total_supply := 0
	var total_consumers := 0
	var watered_consumers := 0
	var pump_base_supply := int((city.document.misc_u32(Sc2MiscLayout.WEATHER_RAIN) & 0xff) / 2)
	pump_base_supply += city.document.misc_u32(Sc2MiscLayout.WATER_LEVEL) * 5

	var queue := PackedInt32Array()
	queue.resize(flags.size())
	span.mark("find water sources")
	var sources := _sources_in_scan_order(city, city.compass_rotation())

	for index in sources:
		if flags[index] & FLAG_WATERED or not flags[index] & FLAG_POWERED:
			continue

		span.mark("network traversal and supply")
		var component := _trace_component(buildings, flags, queue, index, pump_base_supply, map_edge, slice)
		span.mark("capacity and tower allocation")
		var supply: int = component.supply
		var consumers: int = component.consumers
		var served := mini(supply, consumers)
		var tower_capacity: int = component.tower_capacity
		var stored_units := mini(supply - served, tower_capacity)
		var towers_to_fill := int((stored_units + 50) / 100)

		total_supply += supply
		total_consumers += consumers
		watered_consumers += served

		span.mark("distribute water and fill towers")
		for position in component.size:
			if slice != null and (position & 1023) == 0:
				slice.checkpoint()

			var tile := queue[position]
			var tile_building := buildings[tile]

			if tile_building < FIRST_CONSUMER:
				if served != 0:
					flags[tile] |= FLAG_WATERED
			elif tile_building == WATER_PUMP or tile_building == WATER_TREATMENT or tile_building == DESALINIZATION:
				if flags[tile] & FLAG_POWERED:
					flags[tile] |= FLAG_WATERED
			elif tile_building == WATER_TOWER:
				if flags[tile] & FLAG_POWERED and towers_to_fill != 0:
					flags[tile] |= FLAG_WATERED
					towers_to_fill -= 1
			elif served != 0:
				flags[tile] |= FLAG_WATERED
				served -= 1

			flags[tile] &= ~FLAG_MARK & 0xff

		span.mark("find water sources")

	span.mark("store watered tiles")
	if not city.replace_tile_flags(flags):
		return _failed("cannot store updated XBIT data")

	span.mark("utilization and treatment capacity")
	var usage_percent := 100

	if total_supply != 0:
		usage_percent = int((watered_consumers * 100) / total_supply)

	var treatment_tile_count := city.document.misc_u32(MISC_TILE_COUNTS + WATER_TREATMENT * 4)

	if not city.document.is_extended():
		treatment_tile_count = _to_i16(treatment_tile_count)

	var treatment_capacity := int(treatment_tile_count / 4) * 2000
	var treatment_sufficient := watered_consumers <= treatment_capacity

	if not city.document.set_misc_u32(
		MISC_TREATMENT_SUFFICIENT, 1 if treatment_sufficient else 0
	):
		return _failed("cannot store water-treatment state")

	var result := Result.new()
	result.ok = true
	result.supply = total_supply
	result.consumers = total_consumers
	result.watered_consumers = watered_consumers
	result.usage_percent = usage_percent
	result.treatment_capacity = treatment_capacity
	result.treatment_sufficient = treatment_sufficient
	result.timing = span.finish()

	return result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


# `queue` receives the component tiles in trace order
static func _trace_component(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	queue: PackedInt32Array,
	start: int,
	pump_base_supply: int,
	map_edge: int = 128,
	budget: SimulationSliceBudget = null,
) -> Component:
	var result := Component.new()

	if not flags[start] & FLAG_PIPED:
		return result

	var last_y := map_edge - 1
	var tile_count := flags.size()
	var supply := 0
	var consumers := 0
	var tower_capacity := 0
	var head := 0
	var tail := 1
	flags[start] |= FLAG_MARK
	queue[0] = start

	while head < tail:
		if budget != null and (head & 127) == 0:
			budget.checkpoint()

		var index := queue[head]
		head += 1
		var y := index % map_edge
		var building := buildings[index]

		if building >= FIRST_CONSUMER:
			if building == WATER_PUMP:
				if flags[index] & FLAG_POWERED:
					supply += _pump_supply(flags, index / map_edge, y, pump_base_supply, map_edge)
			elif building == WATER_TOWER:
				tower_capacity += 100

				if flags[index] & FLAG_WATERED:
					supply += 100

				flags[index] &= ~FLAG_WATERED & 0xff
			elif building == DESALINIZATION:
				if flags[index] & FLAG_POWERED:
					supply += _desalinization_supply(flags, index / map_edge, y, map_edge)
			elif building != WATER_TREATMENT:
				consumers += 1

		# neighbors in the original order: y - 1, x - 1, y + 1, x + 1
		var neighbor := index - 1

		if y > 0 and flags[neighbor] & (FLAG_MARK | FLAG_PIPED) == FLAG_PIPED:
			flags[neighbor] |= FLAG_MARK
			queue[tail] = neighbor
			tail += 1

		neighbor = index - map_edge

		if neighbor >= 0 and flags[neighbor] & (FLAG_MARK | FLAG_PIPED) == FLAG_PIPED:
			flags[neighbor] |= FLAG_MARK
			queue[tail] = neighbor
			tail += 1

		neighbor = index + 1

		if y < last_y and flags[neighbor] & (FLAG_MARK | FLAG_PIPED) == FLAG_PIPED:
			flags[neighbor] |= FLAG_MARK
			queue[tail] = neighbor
			tail += 1

		neighbor = index + map_edge

		if neighbor < tile_count and flags[neighbor] & (FLAG_MARK | FLAG_PIPED) == FLAG_PIPED:
			flags[neighbor] |= FLAG_MARK
			queue[tail] = neighbor
			tail += 1

	result.size = tail
	result.supply = supply
	result.consumers = consumers
	result.tower_capacity = tower_capacity

	return result


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


# pumps and desalination plants in the order of the original scan for the
# compass rotation. each rotation scans from a different corner
static func _sources_in_scan_order(city: CityState, rotation: int) -> PackedInt32Array:
	var edge := city.map_size
	var last := edge - 1
	var tile_count := edge * edge
	var ranked := PackedInt64Array()

	for index in city.building_indices([WATER_PUMP, DESALINIZATION]):
		var x := index / edge
		var y := index % edge
		var rank := 0

		match rotation & 3:
			0:
				rank = y * edge + x
			1:
				rank = x * edge + last - y
			2:
				rank = (last - y) * edge + last - x
			3:
				rank = (last - x) * edge + y

		ranked.append(rank * tile_count + index)

	ranked.sort()
	var result := PackedInt32Array()

	for value in ranked:
		result.append(value % tile_count)

	return result


static func _to_i16(value: int) -> int:
	value &= 0xffff

	return value - 0x10000 if value >= 0x8000 else value
