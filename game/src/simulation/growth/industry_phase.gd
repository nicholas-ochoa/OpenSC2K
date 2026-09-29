class_name IndustryPhase
extends RefCounted


@warning_ignore_start("integer_division")

const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_START_YEAR := Sc2MiscLayout.START_YEAR
const MISC_CITY_DAYS := Sc2MiscLayout.CITY_DAYS
const MISC_ORDINANCES := Sc2MiscLayout.ORDINANCES
const INDUSTRY_COUNT := Sc2IndustryLayout.COUNT
# five 50-year rows from executable table 0x004e9458
const WORLD_DEMAND := [
	[20, 20, 10, 10, 15, 5, 0, 15, 8, 0, 10],
	[30, 20, 40, 10, 20, 40, 20, 20, 16, 10, 20],
	[35, 20, 30, 10, 25, 40, 30, 25, 24, 80, 30],
	[20, 50, 20, 10, 20, 30, 40, 30, 40, 80, 40],
	[10, 20, 10, 10, 20, 20, 50, 30, 20, 80, 50],
]


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func world_demands(start_year: int, elapsed_years: int) -> PackedInt32Array:
	var period := _divide_toward_zero(start_year - 1900, 50) + int(elapsed_years / 50)

	if period < 0:
		return PackedInt32Array()

	if period >= WORLD_DEMAND.size() - 1:
		return PackedInt32Array(WORLD_DEMAND[WORLD_DEMAND.size() - 1])

	var remainder := elapsed_years % 50
	var result := PackedInt32Array()

	for industry in INDUSTRY_COUNT:
		result.append(int(
			((
				int(WORLD_DEMAND[period + 1][industry]) * remainder
				+ (50 - remainder) * int(WORLD_DEMAND[period][industry])
			) / 50)
		))

	return result


static func _divide_toward_zero(value: int, divisor: int) -> int:
	return int(float(value) / float(divisor))


static func run(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom, population_growth: int) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible process random generator is required")

	if lfsr_random == null:
		return _failed("a compatible game LFSR generator is required")

	return NativeSimulationBridge.run("industry", city, random, lfsr_random, null, {"population_growth": population_growth}).result


class Result extends PhaseResult:
	var start_year := 0
	var elapsed_years := 0
	var world_demands := PackedInt32Array()
	var demands := PackedInt32Array()
	var adjusted_demands := PackedInt32Array()
	var ratios := PackedInt64Array()
	var ratio_total_before := 0
	var ratio_total_after := 0
	var industrial_population := 0
	var positive_demand_total := 0
	var pollution_share := 0
	var pollution_bonus := 0
	var maximum_share := 0
	var mix_bonus := 0
