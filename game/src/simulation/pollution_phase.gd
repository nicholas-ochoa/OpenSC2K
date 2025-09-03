class_name PollutionPhase
extends RefCounted

const MAP_SIZE := 64
const SERVICE_MAP_SIZE := 32
const FULL_MAP_SIZE := CityState.MAP_SIZE
const VALUE_COUNT := MAP_SIZE * MAP_SIZE
const MISC_CITY_POLLUTION := 0x0034
const MISC_CITY_LAND_VALUE := 0x0028
const MISC_CITY_CRIME := 0x002c
const MISC_BUDGETS := 0x077c
const MISC_BUDGET_RECORD_SIZE := 0x006c
const MISC_ORDINANCES := 0x0fa0
const MISC_CITY_CENTER_X := 0x1018
const MISC_CITY_CENTER_Y := 0x101c
const MISC_POLLUTION_BONUS := 0x1034
const MISC_PRISON_BONUS := 0x103c
const MISC_TREATMENT_SUFFICIENT := 0x104c
const CLEAN_INDUSTRY_ORDINANCE := 0x00080000
const POLICE_COVERAGE_ORDINANCE := 0x00000800
const FIRE_COVERAGE_ORDINANCE := 0x00000010
const CRIME_REDUCTION_ORDINANCE := 0x00000004
const RADIOACTIVITY := 0x05
const FIRST_TREE := 0x06
const SMALL_PARK := 0x0d
const FIRST_ROAD := 0x1d
const FIRST_POLLUTING_BUILDING := 0x70
const BIG_PARK := 0xd5
const POLICE_STATION := 0xd2
const FIRE_STATION := 0xd3
const FIRST_POWER_PLANT := 0xc6
const FIRST_ARCOLOGY := 0xfb
const LAST_ARCOLOGY := 0xfe
const FLAG_WATER := 0x04
const FLAG_MARK := 0x08
const FLAG_WATERED := 0x10
const FLAG_POWERED := 0x40
const ZONE_BUILDING_ORIGIN := 0x80
const BUDGET_POLICE := 5
const BUDGET_FIRE := 6

const LAND_VALUE_HALVED := {
	0x8a: true, 0x8b: true,
	0xaa: true, 0xab: true, 0xac: true, 0xad: true,
	0xc4: true, 0xc5: true,
}

# nonzero bytes from the supplied executable table at 0x004e95b8
const BUILDING_POLLUTION := {
	0x84: 6, 0x85: 6, 0x86: 6, 0x87: 6,
	0x9e: 12, 0x9f: 12, 0xa0: 12, 0xa1: 12,
	0xa2: 18, 0xa3: 18, 0xa4: 18, 0xa5: 18,
	0xbc: 24, 0xbd: 24, 0xbe: 24, 0xbf: 24, 0xc0: 24, 0xc1: 24,
	0xc9: 10, 0xca: 25, 0xcb: 2, 0xce: 2, 0xcf: 50,
	0xd7: 4, 0xd8: 10, 0xdc: 2, 0xdd: 10, 0xde: 10, 0xdf: 10,
	0xe0: 5, 0xe3: 5, 0xe4: 5, 0xe5: 5, 0xe6: 10, 0xe7: 10,
	0xe9: 5, 0xec: 3, 0xed: 4, 0xee: 2, 0xef: 2, 0xf0: 2, 0xf1: 2,
	0xf2: 10, 0xf4: 10, 0xf6: 5, 0xfb: 25, 0xfc: 10, 0xfd: 12, 0xfe: 15,
}


static func run(city: CityState) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var misc_chunk := city.document.find_chunk("MISC")
	var traffic_chunk := city.document.find_chunk("XTRF")
	var pollution_chunk := city.document.find_chunk("XPLT")
	var land_value_chunk := city.document.find_chunk("XVAL")
	var crime_chunk := city.document.find_chunk("XCRM")
	var police_chunk := city.document.find_chunk("XPLC")
	var fire_chunk := city.document.find_chunk("XFIR")
	var population_chunk := city.document.find_chunk("XPOP")
	var growth_chunk := city.document.find_chunk("XROG")
	if misc_chunk == null or misc_chunk.decoded_payload.size() != 4800:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}
	if traffic_chunk == null or traffic_chunk.decoded_payload.size() != VALUE_COUNT:
		return {"ok": false, "error": "XTRF is missing or has the wrong size"}
	if pollution_chunk == null or pollution_chunk.decoded_payload.size() != VALUE_COUNT:
		return {"ok": false, "error": "XPLT is missing or has the wrong size"}
	for checked in [
		[land_value_chunk, "XVAL", VALUE_COUNT],
		[crime_chunk, "XCRM", VALUE_COUNT],
		[police_chunk, "XPLC", SERVICE_MAP_SIZE * SERVICE_MAP_SIZE],
		[fire_chunk, "XFIR", SERVICE_MAP_SIZE * SERVICE_MAP_SIZE],
		[population_chunk, "XPOP", SERVICE_MAP_SIZE * SERVICE_MAP_SIZE],
		[growth_chunk, "XROG", SERVICE_MAP_SIZE * SERVICE_MAP_SIZE],
	]:
		if checked[0] == null or checked[0].decoded_payload.size() != checked[2]:
			return {"ok": false, "error": "%s is missing or has the wrong size" % checked[1]}

	var temporary := PackedInt32Array()
	temporary.resize(FULL_MAP_SIZE * FULL_MAP_SIZE)
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			var map_index := x * MAP_SIZE + y
			var value := int(traffic_chunk.decoded_payload[map_index] / 5)
			value += pollution_chunk.decoded_payload[map_index]
			for full_x in range(x * 2, x * 2 + 2):
				for full_y in range(y * 2, y * 2 + 2):
					var building := city.building_id(full_x, full_y)
					if building >= FIRST_POLLUTING_BUILDING:
						value += BUILDING_POLLUTION.get(building, 0)
					if building == RADIOACTIVITY:
						value += 200
			temporary[_full_index(x, y)] = value

	var base_divisor := (
		city.document.misc_i32(MISC_TREATMENT_SUFFICIENT)
		- city.document.misc_i32(MISC_POLLUTION_BONUS)
		+ 4
	)
	if city.document.misc_u32(MISC_ORDINANCES) & CLEAN_INDUSTRY_ORDINANCE:
		base_divisor += 1
	base_divisor = maxi(base_divisor, 1)

	var pollution := PackedByteArray()
	pollution.resize(VALUE_COUNT)
	var total := 0
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			var index := x * MAP_SIZE + y
			var numerator := temporary[_full_index(x, y)] * 2
			var divisor := base_divisor
			if x > 0:
				numerator += temporary[_full_index(x - 1, y)]
				divisor += 1
			if x < MAP_SIZE - 1:
				numerator += temporary[_full_index(x + 1, y)]
				divisor += 1
			if y > 0:
				numerator += temporary[_full_index(x, y - 1)]
				divisor += 1
			if y < MAP_SIZE - 1:
				numerator += temporary[_full_index(x, y + 1)]
				divisor += 1
			var value := mini(int(numerator / divisor), 0xff)
			pollution[index] = value
			total += value


	var flags := city.tile_flags.duplicate()
	var coordinate_sum_x := 0
	var coordinate_sum_y := 0
	var center_divisor := 1
	for x in FULL_MAP_SIZE:
		for y in FULL_MAP_SIZE:
			var index := _full_index(x, y)
			if city.buildings[index] > 0x6f:
				coordinate_sum_x += x
				coordinate_sum_y += y
				center_divisor += 1
				temporary[index] = 40
				flags[index] &= ~FLAG_MARK & 0xff
	var center_x := int(coordinate_sum_x / (center_divisor * 2))
	var center_y := int(coordinate_sum_y / (center_divisor * 2))

	var developed_tiles := 0
	for x in FULL_MAP_SIZE:
		for y in FULL_MAP_SIZE:
			var index := _full_index(x, y)
			var quarter_x := int(x / 4)
			var quarter_y := int(y / 4)
			var residential_index := _full_index(quarter_x, quarter_y)
			var industrial_index := _full_index(quarter_x + SERVICE_MAP_SIZE, quarter_y)
			var residential_value := temporary[residential_index]
			var industrial_value := temporary[industrial_index]
			var building := city.buildings[index]
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
			if building >= FIRST_ROAD or city.zone_id(x, y) != 0:
				flags[_full_index(int(x / 2), int(y / 2))] |= FLAG_MARK
				developed_tiles += 1
			if flags[index] & FLAG_WATERED:
				residential_value += 4
				industrial_value += 4
			var terrain := city.terrain[index]
			if terrain != 0 and terrain < 0x10:
				residential_value += 12
			temporary[residential_index] = residential_value
			temporary[industrial_index] = industrial_value

	var old_crime: PackedByteArray = crime_chunk.decoded_payload
	var old_population: PackedByteArray = population_chunk.decoded_payload
	var old_growth: PackedByteArray = growth_chunk.decoded_payload
	var land_value := PackedByteArray()
	land_value.resize(VALUE_COUNT)
	var land_value_total := 0
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			var map_index := x * MAP_SIZE + y
			if not flags[_full_index(x, y)] & FLAG_MARK:
				continue
			var full_x := x * 2
			var full_y := y * 2
			var zone := city.zone_id(full_x, full_y)
			if zone == 0:
				zone = city.zone_id(full_x + 1, full_y + 1)
			var service_x := int(x / 2)
			var service_y := int(y / 2)
			var distance_value := 64 - absi(center_x - x) - absi(center_y - y)
			var value := 0
			match zone:
				3, 4:
					value = _average_service_grid(temporary, service_x, service_y, 0)
					value += maxi(distance_value, 0)
					value -= int(pollution[map_index] / 4)
					value -= int(old_crime[map_index] / 3)
					value += int(old_population[service_x * SERVICE_MAP_SIZE + service_y] / 3)
				5, 6:
					value = _average_service_grid(
						temporary, service_x, service_y, SERVICE_MAP_SIZE
					)
					if zone == 6:
						value += 21
					value += maxi(_divide_toward_zero(distance_value, 4), 0)
					value -= int(pollution[map_index] / 16)
					value -= int(old_crime[map_index] / 4)
				_:
					value = _average_service_grid(temporary, service_x, service_y, 0)
					if old_population[service_x * SERVICE_MAP_SIZE + service_y] < 0x40:
						value += 21
					value += maxi(_divide_toward_zero(distance_value, 2), 0)
					value -= int(pollution[map_index] / 5)
					value -= int(old_crime[map_index] / 3)
			var building := city.building_id(full_x, full_y)
			if building >= FIRST_POLLUTING_BUILDING and LAND_VALUE_HALVED.has(building):
				value -= _divide_toward_zero(value, 2)
			value = clampi(value, 0, 0xff)
			land_value[map_index] = value
			land_value_total += value

	for x in SERVICE_MAP_SIZE:
		for y in SERVICE_MAP_SIZE:
			temporary[_full_index(x, y)] = 0
	var police := PackedByteArray()
	police.resize(SERVICE_MAP_SIZE * SERVICE_MAP_SIZE)
	var fire := PackedByteArray()
	fire.resize(SERVICE_MAP_SIZE * SERVICE_MAP_SIZE)
	var ordinances := city.document.misc_u32(MISC_ORDINANCES)
	for x in range(1, FULL_MAP_SIZE - 1):
		for y in range(1, FULL_MAP_SIZE - 1):
			var index := _full_index(x, y)
			var building := city.buildings[index]
			var service_x := int(x / 4)
			var service_y := int(y / 4)
			var service_index := service_x * SERVICE_MAP_SIZE + service_y
			if building >= FIRST_POLLUTING_BUILDING and building < FIRST_POWER_PLANT:
				temporary[_full_index(service_x, service_y)] += _population_weight(building)
				if ordinances & POLICE_COVERAGE_ORDINANCE and police[service_index] < 0xfe:
					police[service_index] += 2
				if ordinances & FIRE_COVERAGE_ORDINANCE and fire[service_index] < 0xfe:
					fire[service_index] += 2
			elif building >= FIRST_POWER_PLANT:
				temporary[_full_index(service_x, service_y)] += (
					12 if building >= FIRST_ARCOLOGY and building <= LAST_ARCOLOGY else 2
				)
				if not city.zones[index] & ZONE_BUILDING_ORIGIN:
					continue
				if building == POLICE_STATION:
					var strength := int(
						(city.document.misc_i32(MISC_PRISON_BONUS) + 5)
						* _budget_funding(city, BUDGET_POLICE)
						/ 2
					)
					if not flags[index] & FLAG_POWERED:
						strength = _divide_toward_zero(strength, 2)
					_add_service(police, service_x, service_y, strength)
				elif building == FIRE_STATION:
					var strength := int(_budget_funding(city, BUDGET_FIRE) * 5 / 2)
					if not flags[index] & FLAG_POWERED:
						strength = _divide_toward_zero(strength, 2)
					_add_service(fire, service_x, service_y, strength)

	var population := PackedByteArray()
	population.resize(SERVICE_MAP_SIZE * SERVICE_MAP_SIZE)
	var growth := PackedByteArray()
	growth.resize(SERVICE_MAP_SIZE * SERVICE_MAP_SIZE)
	for x in SERVICE_MAP_SIZE:
		for y in SERVICE_MAP_SIZE:
			var index := x * SERVICE_MAP_SIZE + y
			var population_value := mini(temporary[_full_index(x, y)] * 4, 0xff)
			population[index] = population_value
			var growth_numerator := (
				int(old_growth[index]) * 7
				+ (population_value - int(old_population[index])) * 8
				+ 128
			)
			growth[index] = clampi(_divide_toward_zero(growth_numerator, 8), 0, 0xff)

	for x in MAP_SIZE:
		for y in MAP_SIZE:
			var index := x * MAP_SIZE + y
			if not flags[_full_index(x, y)] & FLAG_MARK:
				temporary[_full_index(x, y)] = 0
				continue
			var service_index := int(x / 2) * SERVICE_MAP_SIZE + int(y / 2)
			var value := int(population[service_index])
			value -= int(land_value[index] / 4)
			value -= int(police[service_index] / 2)
			if ordinances & CRIME_REDUCTION_ORDINANCE:
				value += 16
			temporary[_full_index(x, y)] = value

	var crime := PackedByteArray()
	crime.resize(VALUE_COUNT)
	var crime_total := 0
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			var numerator := temporary[_full_index(x, y)]
			var divisor := 1
			if x > 0:
				numerator += temporary[_full_index(x - 1, y)]
				divisor += 1
			if x < MAP_SIZE - 1:
				numerator += temporary[_full_index(x + 1, y)]
				divisor += 1
			if y > 0:
				numerator += temporary[_full_index(x, y - 1)]
				divisor += 1
			if y < MAP_SIZE - 1:
				numerator += temporary[_full_index(x, y + 1)]
				divisor += 1
			var value := clampi(_divide_toward_zero(numerator, divisor), 0, 0xff)
			crime[x * MAP_SIZE + y] = value
			crime_total += value

	for update in [
		[pollution_chunk, pollution, "XPLT"],
		[land_value_chunk, land_value, "XVAL"],
		[police_chunk, police, "XPLC"],
		[fire_chunk, fire, "XFIR"],
		[population_chunk, population, "XPOP"],
		[growth_chunk, growth, "XROG"],
		[crime_chunk, crime, "XCRM"],
	]:
		if not update[0].set_decoded_payload(update[1]):
			return {"ok": false, "error": "cannot store updated %s data" % update[2]}
	if not city.replace_tile_flags(flags):
		return {"ok": false, "error": "cannot store updated XBIT data"}
	for update in [
		[MISC_CITY_POLLUTION, total],
		[MISC_CITY_LAND_VALUE, land_value_total],
		[MISC_CITY_CRIME, crime_total],
		[MISC_CITY_CENTER_X, center_x * 2],
		[MISC_CITY_CENTER_Y, center_y * 2],
	]:
		if not city.document.set_misc_u32(update[0], update[1]):
			return {"ok": false, "error": "cannot store MISC value 0x%x" % update[0]}
	return {
		"ok": true,
		"pollution_total": total,
		"land_value_total": land_value_total,
		"crime_total": crime_total,
		"developed_tiles": developed_tiles,
		"city_center": Vector2i(center_x * 2, center_y * 2),
		"error": "",
	}


static func _full_index(x: int, y: int) -> int:
	return x * FULL_MAP_SIZE + y


static func _average_service_grid(
	values: PackedInt32Array, x: int, y: int, x_offset: int
) -> int:
	var total := values[_full_index(x + x_offset, y)]
	var divisor := 1
	if x > 0:
		total += values[_full_index(x - 1 + x_offset, y)]
		divisor += 1
	if x < SERVICE_MAP_SIZE - 1:
		total += values[_full_index(x + 1 + x_offset, y)]
		divisor += 1
	if y > 0:
		total += values[_full_index(x + x_offset, y - 1)]
		divisor += 1
	if y < SERVICE_MAP_SIZE - 1:
		total += values[_full_index(x + x_offset, y + 1)]
		divisor += 1
	return _divide_toward_zero(total, divisor)


static func _budget_funding(city: CityState, budget_id: int) -> int:
	return city.document.misc_i32(
		MISC_BUDGETS + budget_id * MISC_BUDGET_RECORD_SIZE + 4
	)


static func _population_weight(building: int) -> int:
	if building >= 0x70 and building <= 0x89:
		return 1
	if building >= 0x8c and building <= 0x8f:
		return 2
	if building >= 0x90 and building <= 0x93:
		return 3
	if building >= 0x94 and building <= 0x98:
		return 2
	if building >= 0x99 and building <= 0x9d:
		return 3
	if building >= 0x9e and building <= 0xa1:
		return 2
	if building >= 0xa2 and building <= 0xa5:
		return 3
	if building >= 0xa6 and building <= 0xa7:
		return 2
	if building >= 0xa8 and building <= 0xa9:
		return 3
	if building >= 0xae and building <= 0xc3:
		return 4
	return 0


static func _add_service(values: PackedByteArray, x: int, y: int, strength: int) -> void:
	_add_service_cell(values, x, y, strength)
	var cardinal := _divide_toward_zero(strength * 4, 5)
	for point in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
		_add_service_cell(values, point.x, point.y, cardinal)
	var diagonal := _divide_toward_zero(cardinal * 3, 4)
	for dx in [-1, 1]:
		for dy in [-1, 1]:
			_add_service_cell(values, x + dx, y + dy, diagonal)
	var outer := _divide_toward_zero(diagonal * 2, 3)
	for major in [-2, 2]:
		for minor in [-1, 0, 1]:
			_add_service_cell(values, x + major, y + minor, outer)
			_add_service_cell(values, x + minor, y + major, outer)
	var fringe := _divide_toward_zero(outer, 2)
	for major in [-3, 3]:
		for minor in [-1, 0, 1]:
			_add_service_cell(values, x + major, y + minor, fringe)
			_add_service_cell(values, x + minor, y + major, fringe)
	for dx in [-2, 2]:
		for dy in [-2, 2]:
			_add_service_cell(values, x + dx, y + dy, fringe)


static func _add_service_cell(
	values: PackedByteArray, x: int, y: int, strength: int
) -> void:
	if x < 0 or x >= SERVICE_MAP_SIZE or y < 0 or y >= SERVICE_MAP_SIZE:
		return
	var index := x * SERVICE_MAP_SIZE + y
	values[index] = clampi(int(values[index]) + strength, 0, 0xff)


static func _divide_toward_zero(value: int, divisor: int) -> int:
	return int(value / divisor)
