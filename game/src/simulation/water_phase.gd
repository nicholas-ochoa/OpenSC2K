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
const WATER_PUMP := 0xdc
const WATER_TOWER := 0xeb
const WATER_TREATMENT := 0xf4
const DESALINIZATION := 0xfa


static func run(city: CityState) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	var flags := city.tile_flags.duplicate()
	for index in flags.size():
		flags[index] &= ~FLAG_MARK & 0xff
		if city.buildings[index] != WATER_TOWER:
			flags[index] &= ~FLAG_WATERED & 0xff

	var total_supply := 0
	var total_consumers := 0
	var watered_consumers := 0
	for index in _source_scan_order(city.compass_rotation()):
		var building := city.buildings[index]
		if building != WATER_PUMP and building != DESALINIZATION:
			continue
		if flags[index] & FLAG_WATERED or not flags[index] & FLAG_POWERED:
			continue
		var component := _trace_component(city, flags, index)
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
	return {
		"ok": true,
		"supply": total_supply,
		"consumers": total_consumers,
		"watered_consumers": watered_consumers,
		"usage_percent": usage_percent,
		"error": "",
	}


static func _trace_component(city: CityState, flags: PackedByteArray, start: int) -> Dictionary:
	var queue := PackedInt32Array([start])
	var queue_position := 0
	var tiles := PackedInt32Array()
	var supply := 0
	var consumers := 0
	var tower_capacity := 0
	while queue_position < queue.size():
		var index := queue[queue_position]
		queue_position += 1
		if flags[index] & FLAG_MARK or not flags[index] & FLAG_PIPED:
			continue
		flags[index] |= FLAG_MARK
		tiles.append(index)
		var x := int(index / MAP_SIZE)
		var y := index % MAP_SIZE
		var building := city.buildings[index]
		if building >= FIRST_CONSUMER:
			match building:
				WATER_PUMP:
					if flags[index] & FLAG_POWERED:
						supply += _pump_supply(city, flags, x, y)
				WATER_TOWER:
					tower_capacity += 100
					if flags[index] & FLAG_WATERED:
						supply += 100
					flags[index] &= ~FLAG_WATERED & 0xff
				WATER_TREATMENT:
					pass
				DESALINIZATION:
					if flags[index] & FLAG_POWERED:
						supply += _desalinization_supply(flags, x, y)
				_:
					consumers += 1

		if y > 0:
			queue.append(city.index_of(x, y - 1))
		if x > 0:
			queue.append(city.index_of(x - 1, y))
		if y < MAP_SIZE - 1:
			queue.append(city.index_of(x, y + 1))
		if x < MAP_SIZE - 1:
			queue.append(city.index_of(x + 1, y))
	return {
		"tiles": tiles,
		"supply": supply,
		"consumers": consumers,
		"tower_capacity": tower_capacity,
	}


static func _pump_supply(
	city: CityState, flags: PackedByteArray, x: int, y: int
) -> int:
	var rain := city.document.misc_u32(0x68) & 0xff
	var supply := int(rain / 2) + city.document.misc_u32(0x0e40) * 5
	for near_x in range(maxi(x - 1, 0), mini(x + 2, MAP_SIZE)):
		for near_y in range(maxi(y - 1, 0), mini(y + 2, MAP_SIZE)):
			var water_bits := flags[city.index_of(near_x, near_y)] & (
				FLAG_SALT_WATER | FLAG_WATER
			)
			if water_bits == FLAG_WATER:
				supply += 10
	return supply


static func _desalinization_supply(flags: PackedByteArray, x: int, y: int) -> int:
	var supply := 0
	for near_x in range(maxi(x - 1, 0), mini(x + 2, MAP_SIZE)):
		for near_y in range(maxi(y - 1, 0), mini(y + 2, MAP_SIZE)):
			var water_bits := flags[near_x * MAP_SIZE + near_y] & (
				FLAG_SALT_WATER | FLAG_WATER
			)
			if water_bits == FLAG_SALT_WATER | FLAG_WATER:
				supply += 20
	return supply


static func _source_scan_order(rotation: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	match rotation & 3:
		0:
			for y in MAP_SIZE:
				for x in MAP_SIZE:
					result.append(x * MAP_SIZE + y)
		1:
			for x in MAP_SIZE:
				for y in range(MAP_SIZE - 1, -1, -1):
					result.append(x * MAP_SIZE + y)
		2:
			for y in range(MAP_SIZE - 1, -1, -1):
				for x in range(MAP_SIZE - 1, -1, -1):
					result.append(x * MAP_SIZE + y)
		3:
			for x in range(MAP_SIZE - 1, -1, -1):
				for y in MAP_SIZE:
					result.append(x * MAP_SIZE + y)
	return result
