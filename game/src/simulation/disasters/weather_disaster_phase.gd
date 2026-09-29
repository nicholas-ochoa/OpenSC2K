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
