class_name WeatherDisasterPhase
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const MISC_SIZE := Sc2MiscLayout.SIZE
const POLLUTION_SIZE := 64 * 64
const MISC_CITY_DAYS := Sc2MiscLayout.CITY_DAYS
const MISC_DIFFICULTY := Sc2MiscLayout.DIFFICULTY
const MISC_WEATHER_HEAT := Sc2MiscLayout.WEATHER_HEAT
const MISC_WEATHER_TREND := Sc2MiscLayout.WEATHER_TREND
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_INVENTION_YEARS := Sc2MiscLayout.INVENTION_YEARS
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_NO_DISASTERS := Sc2MiscLayout.NO_DISASTERS
const MISC_CITY_CENTER_X := Sc2MiscLayout.CITY_CENTER_X
const MISC_CITY_CENTER_Y := Sc2MiscLayout.CITY_CENTER_Y
const MISC_ARCOLOGY_POPULATION := Sc2MiscLayout.ARCOLOGY_POPULATION
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION
const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const BUDGET_CURRENT := Sc2BudgetLayout.CURRENT
const BUDGET_RESIDENTIAL := Sc2BudgetLayout.RESIDENTIAL
const BUDGET_ROAD := Sc2BudgetLayout.ROAD
const TILE_HOSPITAL := Tiles.HOSPITAL
const TILE_POLICE := Tiles.POLICE_STATION
const TILE_FIRE := Tiles.FIRE_STATION
const TILE_BIG_PARK := Tiles.BIG_PARK
const TILE_SCHOOL := Tiles.SCHOOL
const TILE_STADIUM := Tiles.STADIUM
const TILE_PRISON := Tiles.PRISON
const TILE_ZOO := Tiles.ZOO
const TILE_RUNWAY := Tiles.RUNWAY
const TILE_RUNWAY_CROSSING := Tiles.RUNWAY_CROSSING
const TILE_CRANE := Tiles.CRANE
const TILE_SUBWAY_STATION := Tiles.SUBWAY_STATION
const TILE_RAIL_STATION := Tiles.RAIL_STATION
const TILE_MICROWAVE_PLANT := Tiles.MICROWAVE_POWER
const TILE_NUCLEAR_PLANT := Tiles.NUCLEAR_POWER
const TILE_MARINA := Tiles.MARINA
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


static func _select_disaster(
	misc: PackedByteArray,
	pollution: PackedByteArray,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	current_point: Vector2i,
	map_edge: int = 128,
) -> Result:
	var difficulty := BinaryData.read_u32_be(misc, MISC_DIFFICULTY) & 0xffff
	var difficulty_is_valid := difficulty > 0 and difficulty < DISASTER_WAIT_MONTHS.size()
	var wait_months := int(DISASTER_WAIT_MONTHS[difficulty]) if difficulty_is_valid else -1
	var result := Result.new()
	result.ok = true
	result.disaster_type = DISASTER_NONE
	result.disaster_point = current_point
	result.wait_months = wait_months
	result.disaster_roll = -1
	result.candidate_type = DISASTER_NONE

	if BinaryData.read_u32_be(misc, MISC_NO_DISASTERS) != 0:
		return result

	if not difficulty_is_valid:
		return _failed("city difficulty is out of range")

	var city_months := int(BinaryData.read_u32_be(misc, MISC_CITY_DAYS) / CityCalendar.DAYS_PER_MONTH)

	if city_months < wait_months:
		return result

	var disaster_roll: int = random.next_u15() % wait_months
	result.disaster_roll = disaster_roll
	var weather_trend := BinaryData.read_u32_be(misc, MISC_WEATHER_TREND) & 0xff
	var has_ocean := BinaryData.read_u32_be(misc, Sc2MiscLayout.HAS_OCEAN) != 0
	var has_river := BinaryData.read_u32_be(misc, Sc2MiscLayout.HAS_RIVER) != 0

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
		BinaryData.read_u32_be(misc, MISC_CITY_CENTER_X) & 0xffff,
		BinaryData.read_u32_be(misc, MISC_CITY_CENTER_Y) & 0xffff
	)
	var population := BinaryData.read_u32_be(misc, MISC_NORMAL_POPULATION)

	match candidate:
		DISASTER_FIRE:
			if (BinaryData.read_u32_be(misc, MISC_WEATHER_HEAT) & 0xff) < ((random.next_u15() & 0x7f) + 0x7f):
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

			if BinaryData.read_i32_be(misc, Sc2MiscLayout.UNEMPLOYMENT) < 10:
				return result

			if (BinaryData.read_u32_be(misc, MISC_WEATHER_HEAT) & 0xff) < 170:
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
			if _budget_current(misc, Sc2BudgetLayout.INDUSTRIAL) < 10000:
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


static func _random_map_point(random: SimRandom, map_edge: int = 128) -> Vector2i:
	var y: int = random.next_u15() % (map_edge - 2) + 1
	var x: int = random.next_u15() % (map_edge - 2) + 1

	return Vector2i(x, y)


static func _random_center_point(random: SimRandom, center: Vector2i, radius: int) -> Vector2i:
	var y: int = (random.next_u15() & 0x1f) + center.y - radius
	var x: int = (random.next_u15() & 0x1f) + center.x - radius

	return Vector2i(x, y)


static func _toxic_spill_point(
	pollution: PackedByteArray, lfsr_random: SimLfsrRandom,
	map_edge: int = 128,
) -> Vector2i:
	var highest := 0
	var point := Vector2i(-1, -1)
	var grid_edge := CityDataGrid.edge(pollution, map_edge)

	if grid_edge == 0:
		return point

	var scale := map_edge / grid_edge

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
	return BinaryData.read_i32_be(
		misc, MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE + BUDGET_CURRENT
	)


static func _tile_count(misc: PackedByteArray, tile_id: int, map_edge: int = 128) -> int:
	var value := BinaryData.read_u32_be(misc, MISC_TILE_COUNTS + tile_id * 4)

	return _to_i16(value) if map_edge == 128 else value


static func _to_i16(value: int) -> int:
	var word := value & 0xffff

	return word - 0x10000 if word & 0x8000 else word


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func run(
	city: CityState,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	power_usage_percent: int,
	water_usage_percent: int,
	commerce_connections: int,
	industry_connections: int,
	current_disaster_point := Vector2i.ZERO
) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible process random generator is required")

	if lfsr_random == null:
		return _failed("a compatible LFSR generator is required")

	return NativeSimulationBridge.run("weather", city, random, lfsr_random, null, {
		"power_usage_percent": power_usage_percent,
		"water_usage_percent": water_usage_percent,
		"commerce_connections": commerce_connections,
		"industry_connections": industry_connections,
		"current_disaster_point": current_disaster_point,
	}).result


class Result extends PhaseResult:
	var status_index := -1
	var status_news_type := -1
	var disaster_type := 0
	var disaster_point := Vector2i.ZERO
	var wait_months := 0
	var disaster_roll := 0
	var candidate_type := 0
