class_name WeatherDisasterPhase
extends RefCounted

const MISC_SIZE := 4800
const POLLUTION_SIZE := 64 * 64
const MISC_CITY_DAYS := 0x0010
const MISC_DIFFICULTY := 0x001c
const MISC_WEATHER_HEAT := 0x0060
const MISC_WEATHER_TREND := 0x006c
const MISC_TILE_COUNTS := 0x01f0
const MISC_INVENTION_YEARS := 0x0738
const MISC_BUDGETS := 0x077c
const MISC_NO_DISASTERS := 0x1000
const MISC_CITY_CENTER_X := 0x1018
const MISC_CITY_CENTER_Y := 0x101c
const MISC_ARCOLOGY_POPULATION := 0x1020
const MISC_NORMAL_POPULATION := 0x102c
const MISC_UNEMPLOYMENT := 0x0fa4

const BUDGET_RECORD_SIZE := 0x006c
const BUDGET_CURRENT := 0x00
const BUDGET_RESIDENTIAL := 0
const BUDGET_COMMERCIAL := 1
const BUDGET_INDUSTRIAL := 2
const BUDGET_ROAD := 10

const TILE_HOSPITAL := 0xd1
const TILE_POLICE := 0xd2
const TILE_FIRE := 0xd3
const TILE_BIG_PARK := 0xd5
const TILE_SCHOOL := 0xd6
const TILE_STADIUM := 0xd7
const TILE_PRISON := 0xd8
const TILE_ZOO := 0xda
const TILE_RUNWAY := 0xdd
const TILE_RUNWAY_CROSSING := 0xde
const TILE_PIER := 0xe0
const TILE_SUBWAY_STATION := 0xe9
const TILE_RAIL_STATION := 0xed
const TILE_MICROWAVE_PLANT := 0xcd
const TILE_NUCLEAR_PLANT := 0xcb
const TILE_MARINA := 0xf8

const NEWS_DEMAND_BASE := 0x2e
const STATUS_NONE := -1
const STATUS_WEATHER := -2
const STATUS_POWER := 0
const STATUS_TRANSIT := 1
const STATUS_POLICE := 2
const STATUS_FIRE := 3
const STATUS_WATER := 4
const STATUS_HOSPITAL := 5
const STATUS_SCHOOL := 6
const STATUS_SEAPORT := 7
const STATUS_AIRPORT := 8
const STATUS_ZOO := 9
const STATUS_STADIUM := 10
const STATUS_MARINA := 11
const STATUS_PARK := 12
const STATUS_INDUSTRIAL_CONNECTION := 13
const STATUS_COMMERCIAL_CONNECTION := 14

const DISASTER_NONE := 0
const DISASTER_FIRE := 1
const DISASTER_FLOOD := 2
const DISASTER_RIOT := 3
const DISASTER_TOXIC_SPILL := 4
const DISASTER_EARTHQUAKE := 6
const DISASTER_TORNADO := 7
const DISASTER_MONSTER := 8
const DISASTER_MELTDOWN := 9
const DISASTER_MICROWAVE := 10
const DISASTER_MASS_RIOTS := 13
const DISASTER_MASS_FLOODS := 14
const DISASTER_POLLUTION := 15
const DISASTER_HURRICANE := 16
const DISASTER_PLANE_CRASH := 18

# indexed by the saved difficulty. values are simulation months. the supplied
# executable stores 0, 100, 60, and 30 at 0x004e9908
const DISASTER_WAIT_MONTHS := [0, 100, 60, 30]


static func run(
	city: CityState,
	random,
	lfsr_random,
	power_usage_percent: int,
	water_usage_percent: int,
	commerce_connections: int,
	industry_connections: int,
	current_disaster_point := Vector2i.ZERO
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}

	if lfsr_random == null or not lfsr_random.has_method("next_mod"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var misc_chunk := city.document.find_chunk("MISC")
	var pollution_chunk := city.document.find_chunk("XPLT")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}

	if pollution_chunk == null or pollution_chunk.decoded_payload.size() != city.document.decoded_size("XPLT"):
		return {"ok": false, "error": "XPLT is missing or has the wrong size"}

	var misc: PackedByteArray = misc_chunk.decoded_payload
	var pollution: PackedByteArray = pollution_chunk.decoded_payload
	var effective_power := maxi(power_usage_percent, 0)
	var effective_water := maxi(water_usage_percent, 0)
	var status_index := _status_index(
		misc,
		random,
		effective_power,
		effective_water,
		commerce_connections & 0xffff,
		industry_connections & 0xffff, map_edge
	)
	var news_items: Array[Dictionary] = []

	if status_index >= 0:
		news_items.append({"type": NEWS_DEMAND_BASE + status_index, "argument": 0})

	var selection := _select_disaster(
		misc, pollution, random, lfsr_random, current_disaster_point, map_edge
	)

	if not selection.ok:
		return selection

	return {
		"ok": true,
		"error": "",
		"status_index": status_index,
		"status_news_type": NEWS_DEMAND_BASE + status_index if status_index >= 0 else -1,
		"news_items": news_items,
		"disaster_type": selection.disaster_type,
		"disaster_point": selection.disaster_point,
		"wait_months": selection.wait_months,
		"disaster_roll": selection.disaster_roll,
		"candidate_type": selection.candidate_type,
		"refresh_requests": ["toolbar", "map", "simnation", "weather_disaster"],
	}


static func _status_index(
	misc: PackedByteArray,
	random,
	power_usage_percent: int,
	water_usage_percent: int,
	commerce_connections: int,
	industry_connections: int, map_edge: int = 128
) -> int:
	var weather_trend := _read_u32(misc, MISC_WEATHER_TREND) & 0xff

	if weather_trend >= 9:
		return STATUS_WEATHER

	if power_usage_percent >= 99:
		return STATUS_POWER

	var population := _read_u32(misc, MISC_NORMAL_POPULATION)
	var arcology_share := int(IntegerMath.div_trunc(_read_u32(misc, MISC_ARCOLOGY_POPULATION), 12))
	var transit_capacity := (
		_tile_count(misc, TILE_SUBWAY_STATION, map_edge)
		+ _tile_count(misc, TILE_RAIL_STATION, map_edge)
		+ _budget_current(misc, BUDGET_ROAD)
	)

	if int(IntegerMath.div_trunc(population, 100)) >= transit_capacity:
		return STATUS_TRANSIT

	if population < 1000:
		return STATUS_NONE

	var large_city_unit := int(IntegerMath.div_trunc(population, 20000))

	if large_city_unit >= int(IntegerMath.div_trunc(_tile_count(misc, TILE_POLICE, map_edge), 9)) + int(
		IntegerMath.div_trunc(_tile_count(misc, TILE_PRISON, map_edge), 16)
	):
		return STATUS_POLICE

	if large_city_unit >= int(IntegerMath.div_trunc(_tile_count(misc, TILE_FIRE, map_edge), 9)):
		return STATUS_FIRE

	if water_usage_percent >= 99:
		return STATUS_WATER

	if population < 3000:
		return STATUS_NONE

	if int(IntegerMath.div_trunc(population, 25000)) >= int(IntegerMath.div_trunc(_tile_count(misc, TILE_HOSPITAL, map_edge), 9)):
		return STATUS_HOSPITAL

	if large_city_unit >= int(IntegerMath.div_trunc(_tile_count(misc, TILE_SCHOOL, map_edge), 9)):
		return STATUS_SCHOOL

	if population < 8000:
		return STATUS_NONE

	var industrial_population := _budget_current(misc, BUDGET_INDUSTRIAL) - arcology_share

	if (
		_tile_count(misc, TILE_PIER, map_edge) + industry_connections
		< int(IntegerMath.div_trunc(industrial_population, 10000))
	):
		if _read_u32(misc, 0x0e44) == 0 and _read_u32(misc, 0x0e48) == 0:
			return STATUS_INDUSTRIAL_CONNECTION

		return STATUS_SEAPORT

	var commercial_population := _budget_current(misc, BUDGET_COMMERCIAL) - arcology_share

	if (
		_tile_count(misc, TILE_RUNWAY, map_edge)
		+ _tile_count(misc, TILE_RUNWAY_CROSSING, map_edge)
		+ commerce_connections
		< int(IntegerMath.div_trunc(commercial_population, 2000))
	):
		var airport_release_year := _read_u32(misc, MISC_INVENTION_YEARS + 6 * 4) & 0xffff

		return STATUS_AIRPORT if airport_release_year == 0 else STATUS_COMMERCIAL_CONNECTION

	var recreation_count := (
		int(IntegerMath.div_trunc(_tile_count(misc, TILE_BIG_PARK, map_edge), 3))
		+ _tile_count(misc, TILE_STADIUM, map_edge)
		+ _tile_count(misc, TILE_ZOO, map_edge)
		+ _tile_count(misc, TILE_MARINA, map_edge)
	)
	var residential_population := _budget_current(misc, BUDGET_RESIDENTIAL) - arcology_share * 2

	if recreation_count < int(IntegerMath.div_trunc(residential_population, 1000)):
		return STATUS_ZOO + (random.next_u15() & 3)

	return STATUS_NONE


static func _select_disaster(
	misc: PackedByteArray,
	pollution: PackedByteArray,
	random,
	lfsr_random,
	current_point: Vector2i,
	map_edge: int = 128,
) -> Dictionary:
	var difficulty := _read_u32(misc, MISC_DIFFICULTY) & 0xffff
	var difficulty_is_valid := difficulty > 0 and difficulty < DISASTER_WAIT_MONTHS.size()
	var wait_months := int(DISASTER_WAIT_MONTHS[difficulty]) if difficulty_is_valid else -1
	var result := {
		"ok": true,
		"error": "",
		"disaster_type": DISASTER_NONE,
		"disaster_point": current_point,
		"wait_months": wait_months,
		"disaster_roll": -1,
		"candidate_type": DISASTER_NONE,
	}

	if _read_u32(misc, MISC_NO_DISASTERS) != 0:
		return result

	if not difficulty_is_valid:
		return {"ok": false, "error": "city difficulty is out of range"}

	var city_months := int(IntegerMath.div_trunc(_read_u32(misc, MISC_CITY_DAYS), 25))

	if city_months < wait_months:
		return result

	var disaster_roll: int = random.next_u15() % wait_months
	result.disaster_roll = disaster_roll
	var weather_trend := _read_u32(misc, MISC_WEATHER_TREND) & 0xff
	var has_ocean := _read_u32(misc, 0x0e44) != 0
	var has_river := _read_u32(misc, 0x0e48) != 0

	if weather_trend == 10 and has_ocean and disaster_roll < 15:
		result.disaster_type = DISASTER_HURRICANE

		return result

	if weather_trend == 11 and disaster_roll < 15:
		result.disaster_type = DISASTER_TORNADO
		result.disaster_point = _random_map_point(random, map_edge)

		return result

	if disaster_roll != 0:
		return result

	var candidate: int = random.next_u15() % 19
	result.candidate_type = candidate
	var center := Vector2i(
		_read_u32(misc, MISC_CITY_CENTER_X) & 0xffff,
		_read_u32(misc, MISC_CITY_CENTER_Y) & 0xffff
	)
	var population := _read_u32(misc, MISC_NORMAL_POPULATION)

	match candidate:
		DISASTER_FIRE:
			if (_read_u32(misc, MISC_WEATHER_HEAT) & 0xff) < ((random.next_u15() & 0x7f) + 0x7f):
				return result

			result.disaster_point = _random_map_point(random, map_edge)
		DISASTER_TOXIC_SPILL:
			var toxic_point := _toxic_spill_point(pollution, lfsr_random, map_edge)

			if toxic_point.x < 0:
				return result

			result.disaster_point = toxic_point
		DISASTER_EARTHQUAKE:
			result.disaster_point = _random_map_point(random, map_edge)
		DISASTER_TORNADO:
			if weather_trend < 8:
				return result

			result.disaster_point = _random_map_point(random, map_edge)
		DISASTER_MONSTER:
			if population < 45000:
				return result

			result.disaster_point = _random_center_point(random, center, 15)
		DISASTER_MELTDOWN:
			if _tile_count(misc, TILE_NUCLEAR_PLANT, map_edge) == 0:
				return result
		DISASTER_MICROWAVE:
			if _tile_count(misc, TILE_MICROWAVE_PLANT, map_edge) == 0:
				return result
		DISASTER_RIOT, DISASTER_MASS_RIOTS:
			if candidate == DISASTER_MASS_RIOTS and population < 30000:
				return result

			if _read_u32(misc, MISC_UNEMPLOYMENT) < 10:
				return result

			if (_read_u32(misc, MISC_WEATHER_HEAT) & 0xff) < 170:
				return result

			result.disaster_point = _random_center_point(random, center, 16)
		DISASTER_FLOOD, DISASTER_MASS_FLOODS:
			if candidate == DISASTER_MASS_FLOODS and weather_trend < 9:
				return result

			if not has_ocean and not has_river:
				return result

			if weather_trend < 3:
				return result

			result.disaster_point = _random_map_point(random, map_edge)
		DISASTER_POLLUTION:
			if _budget_current(misc, BUDGET_INDUSTRIAL) < 10000:
				return result

			result.disaster_point = _random_center_point(random, center, 15)
		DISASTER_HURRICANE:
			if weather_trend < 8 or not has_ocean:
				return result
		DISASTER_PLANE_CRASH:
			if _tile_count(misc, TILE_RUNWAY, map_edge) == 0:
				return result

			result.disaster_point = _random_map_point(random, map_edge)
		_:
			return result

	result.disaster_type = candidate

	return result


static func _random_map_point(random, map_edge: int = 128) -> Vector2i:
	var y: int = random.next_u15() % (map_edge - 2) + 1
	var x: int = random.next_u15() % (map_edge - 2) + 1

	return Vector2i(x, y)


static func _random_center_point(random, center: Vector2i, radius: int) -> Vector2i:
	var y: int = (random.next_u15() & 0x1f) + center.y - radius
	var x: int = (random.next_u15() & 0x1f) + center.x - radius

	return Vector2i(x, y)


static func _toxic_spill_point(
	pollution: PackedByteArray, lfsr_random,
	map_edge: int = 128,
) -> Vector2i:
	var highest := 0
	var point := Vector2i(-1, -1)
	var grid_edge := CityDataGrid.edge(pollution, map_edge)

	if grid_edge == 0:
		return point

	var scale := IntegerMath.div_trunc(map_edge, grid_edge)

	for x in grid_edge:
		for y in grid_edge:
			var value := int(pollution[x * grid_edge + y])

			if value <= 0x95 or value <= highest:
				continue

			if lfsr_random.next_mod(10) != 0:
				continue

			highest = value
			point = Vector2i(
				x * scale + lfsr_random.next_mod(10) - 5,
				y * scale + lfsr_random.next_mod(10) - 5
			)

	if point.x < 0 or point.x > (map_edge - 1) or point.y < 0 or point.y > (map_edge - 1) or highest == 0:
		return Vector2i(-1, -1)

	return point


static func _budget_current(misc: PackedByteArray, budget_id: int) -> int:
	return _read_i32(
		misc, MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE + BUDGET_CURRENT
	)


static func _tile_count(misc: PackedByteArray, tile_id: int, map_edge: int = 128) -> int:
	var value := _read_u32(misc, MISC_TILE_COUNTS + tile_id * 4)

	return _to_i16(value) if map_edge == 128 else value


static func _to_i16(value: int) -> int:
	var word := value & 0xffff

	return word - 0x10000 if word & 0x8000 else word


static func _read_i32(data: PackedByteArray, offset: int) -> int:
	var value := _read_u32(data, offset)

	return value - 0x100000000 if value & 0x80000000 else value


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)
