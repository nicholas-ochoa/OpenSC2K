class_name IndustryPhase
extends RefCounted

@warning_ignore_start("integer_division")

const MISC_SIZE := 4800
const MISC_START_YEAR := 0x000c
const MISC_CITY_DAYS := 0x0010
const MISC_WORKFORCE_EQ := 0x004c
const MISC_INDUSTRIES := 0x016c
const MISC_ZONE_POPULATIONS := 0x05f0
const MISC_ORDINANCES := 0x0fa0
const MISC_INDUSTRIAL_MIX_BONUS := 0x1030
const MISC_INDUSTRIAL_POLLUTION_BONUS := 0x1034

const INDUSTRY_COUNT := 11
const INDUSTRY_STRIDE := 0x0c
const INDUSTRY_DEMAND := 0x00
const INDUSTRY_TAX_RATE := 0x04
const INDUSTRY_RATIO := 0x08

const INDUSTRY_NAMES := [
	"Steel/Mining",
	"Textiles",
	"Petrochemicals",
	"Food",
	"Construction",
	"Automotive",
	"Aerospace",
	"Finance",
	"Media",
	"Electronics",
	"Tourism",
]

# five 50-year rows from executable table 0x004e9458
const WORLD_DEMAND := [
	[20, 20, 10, 10, 15, 5, 0, 15, 8, 0, 10],
	[30, 20, 40, 10, 20, 40, 20, 20, 16, 10, 20],
	[35, 20, 30, 10, 25, 40, 30, 25, 24, 80, 30],
	[20, 50, 20, 10, 20, 30, 40, 30, 40, 80, 40],
	[10, 20, 10, 10, 20, 20, 50, 30, 20, 80, 50],
]

const ORDINANCE_CLEAN_INDUSTRY := 0x00080000
const POLLUTING_INDUSTRIES := [0, 1, 2, 5]
const MID_EQ_INDUSTRIES := [2, 5, 7, 8, 6, 9]
const HIGH_EQ_INDUSTRIES := [6, 9]


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


static func run(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom, population_growth: int) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible process random generator is required")

	if lfsr_random == null:
		return _failed("a compatible game LFSR generator is required")

	if population_growth < 0:
		return _failed("population growth is negative")

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return _failed("MISC is missing or has the wrong size")

	var data: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var start_year := _to_i16(BinaryData.read_u32_be(data, MISC_START_YEAR))
	var elapsed_years := int(BinaryData.read_u32_be(data, MISC_CITY_DAYS) / 300)
	var targets := world_demands(start_year, elapsed_years)

	if targets.is_empty():
		return _failed("the industry era is before 1900")

	var demands := PackedInt32Array()
	var adjusted := PackedInt32Array()
	var ratios := PackedInt64Array()
	var ratio_total := 0

	for industry in INDUSTRY_COUNT:
		var base := MISC_INDUSTRIES + industry * INDUSTRY_STRIDE
		var old_demand := _to_i16(BinaryData.read_u32_be(data, base + INDUSTRY_DEMAND))
		var random_sum := 0

		for roll in 4:
			random_sum += lfsr_random.next_mask(0x7f)

		var random_target := _divide_toward_zero(random_sum * targets[industry], 256)
		var demand := _divide_toward_zero(random_target + old_demand * 3, 4)
		demands.append(demand)
		adjusted.append(demand)
		var ratio := BinaryData.read_u32_be(data, base + INDUSTRY_RATIO)
		ratios.append(ratio)
		ratio_total += ratio

	var ordinances := BinaryData.read_u32_be(data, MISC_ORDINANCES)

	if ordinances & ORDINANCE_CLEAN_INDUSTRY:
		_scale_demands(adjusted, POLLUTING_INDUSTRIES, 0.9)

	if population_growth != 0:
		_scale_demands(adjusted, [4], 1.1)

	var workforce_eq := BinaryData.read_u32_be(data, MISC_WORKFORCE_EQ)

	if workforce_eq > 130:
		_scale_demands(adjusted, HIGH_EQ_INDUSTRIES, 1.2)
	elif workforce_eq > 100:
		_scale_demands(adjusted, MID_EQ_INDUSTRIES, 1.1)
	elif workforce_eq < 60:
		_scale_demands(adjusted, HIGH_EQ_INDUSTRIES, 0.8)

	var positive_total := 0

	for industry in INDUSTRY_COUNT:
		var base := MISC_INDUSTRIES + industry * INDUSTRY_STRIDE
		adjusted[industry] -= _to_i16(BinaryData.read_u32_be(data, base + INDUSTRY_TAX_RATE))

		if adjusted[industry] <= 0:
			adjusted[industry] = 0
		else:
			positive_total += adjusted[industry]

	var industrial_population := (
		BinaryData.read_u32_be(data, MISC_ZONE_POPULATIONS + 5 * 4)
		+ BinaryData.read_u32_be(data, MISC_ZONE_POPULATIONS + 6 * 4)
	)

	if ratio_total > industrial_population:
		var excess := ratio_total - industrial_population

		for industry in INDUSTRY_COUNT:
			var scaled := int((excess * 100 * ratios[industry]) / ratio_total)
			ratios[industry] -= int(scaled / 100)

			if random.next_u15() % 100 < scaled % 100:
				ratios[industry] -= 1
	elif ratio_total < industrial_population and positive_total != 0:
		var shortage := industrial_population - ratio_total

		for industry in INDUSTRY_COUNT:
			if adjusted[industry] == 0:
				continue

			var scaled := int((shortage * 100 * adjusted[industry]) / positive_total)
			ratios[industry] += int(scaled / 100)

			if random.next_u15() % 100 < scaled % 100:
				ratios[industry] += 1

	var pollution_share := int(
		(((ratios[0] + ratios[1] + ratios[2] + ratios[5])
		* 100) / (industrial_population + 1))
	)
	var pollution_bonus := (
		0xffff if pollution_share < 20 else int((pollution_share - 20) / 30)
	)
	var maximum_share := 0

	for ratio in ratios:
		maximum_share = maxi(maximum_share, int((ratio * 100) / (industrial_population + 1)))

	var mix_bonus := 0 if maximum_share < 20 else int((maximum_share - 20) / 5)

	for industry in INDUSTRY_COUNT:
		var base := MISC_INDUSTRIES + industry * INDUSTRY_STRIDE
		BinaryData.write_u32_be(data, base + INDUSTRY_DEMAND, demands[industry])
		BinaryData.write_u32_be(data, base + INDUSTRY_RATIO, ratios[industry])

	BinaryData.write_u32_be(data, MISC_INDUSTRIAL_MIX_BONUS, mix_bonus)
	BinaryData.write_u32_be(data, MISC_INDUSTRIAL_POLLUTION_BONUS, pollution_bonus)

	if not misc_chunk.set_decoded_payload(data):
		return _failed("cannot store the industry update")

	var result := Result.new()
	result.ok = true
	result.start_year = start_year
	result.elapsed_years = elapsed_years
	result.world_demands = targets
	result.demands = demands
	result.adjusted_demands = adjusted
	result.ratios = ratios
	result.ratio_total_before = ratio_total
	result.ratio_total_after = _sum(ratios)
	result.industrial_population = industrial_population
	result.positive_demand_total = positive_total
	result.pollution_share = pollution_share
	result.pollution_bonus = pollution_bonus
	result.maximum_share = maximum_share
	result.mix_bonus = mix_bonus

	return result

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


static func _scale_demands(values: PackedInt32Array, industries: Array, factor: float) -> void:
	for industry in industries:
		values[int(industry)] = int(float(values[int(industry)]) * factor)


static func _sum(values: PackedInt64Array) -> int:
	var total := 0

	for value in values:
		total += value

	return total


static func _divide_toward_zero(value: int, divisor: int) -> int:
	return int(float(value) / float(divisor))


static func _to_i16(value: int) -> int:
	var word := value & 0xffff

	return word - 0x10000 if word & 0x8000 else word
