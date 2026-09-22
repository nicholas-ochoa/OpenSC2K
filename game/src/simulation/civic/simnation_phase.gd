class_name SimNationPhase
extends RefCounted

const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_NATIONAL_POPULATION := Sc2MiscLayout.NATIONAL_POPULATION
const MISC_NATIONAL_FEDERAL_RATE := Sc2MiscLayout.NATIONAL_FEDERAL_RATE
const MISC_NATIONAL_ECONOMY_TREND := Sc2MiscLayout.NATIONAL_ECONOMY_TREND
const NEIGHBOR_STRIDE := 0x10
const NEIGHBOR_POPULATION := 0x04
const NEIGHBOR_VALUE := 0x08
const NEIGHBOR_COUNT := 4

const NATIONAL_POPULATION_CENTER := 5_000_000
const NATIONAL_VALUE_CENTER := 3_500_000
const MONTHLY_SCALE := 1200.0
const ECONOMY_FACTORS := [6, 3, 0, -3]

const NEWS_NATIONAL_ECONOMY := 0x07
const NEWS_FEDERAL_RATE_UP := 0x09
const NEWS_FEDERAL_RATE_DOWN := 0x0a


class Result extends PhaseResult:
	var national_population := 0
	var national_value := 0
	var federal_rate := 0
	var economy_trend := 0
	var neighbor_populations := PackedInt64Array()
	var neighbor_values := PackedInt64Array()
	var shocked_neighbor := -1


static func run(city: CityState, random: SimRandom) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible process random generator is required")

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return _failed("MISC is missing or has the wrong size")

	var data: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var economy_trend := _to_i16(BinaryData.read_u32_be(data, MISC_NATIONAL_ECONOMY_TREND))

	if economy_trend < 0 or economy_trend >= ECONOMY_FACTORS.size():
		return _failed("the national economy trend is out of range")

	var federal_rate := _to_i16(BinaryData.read_u32_be(data, MISC_NATIONAL_FEDERAL_RATE))

	if federal_rate <= 0:
		return _failed("the national federal rate is not positive")

	var news_items: Array[NewsEvent] = []

	var national_population := BinaryData.read_u32_be(data, MISC_NATIONAL_POPULATION)
	var population_change := _scaled_change(national_population, economy_trend)
	national_population = _move_about_center(
		national_population, population_change, NATIONAL_POPULATION_CENTER
	)
	BinaryData.write_u32_be(data, MISC_NATIONAL_POPULATION, national_population)

	var national_value := BinaryData.read_u32_be(data, Sc2MiscLayout.NATIONAL_VALUE)
	var value_change := _scaled_change(national_value, ECONOMY_FACTORS[economy_trend])
	national_value = _move_about_center(national_value, value_change, NATIONAL_VALUE_CENTER)
	BinaryData.write_u32_be(data, Sc2MiscLayout.NATIONAL_VALUE, national_value)

	if random.next_u15() % 10 == 0:
		var national_score := int(float(national_value) / float(national_population + 1) * 100.0)

		if random.next_u15() % 5 < 2:
			if random.next_u15() % (federal_rate * 25) < national_score:
				federal_rate += 1
				BinaryData.write_u32_be(data, MISC_NATIONAL_FEDERAL_RATE, federal_rate)
				news_items.append(NewsEvent.new(NEWS_FEDERAL_RATE_UP, federal_rate))

			if national_score < random.next_u15() % (federal_rate * 25):
				federal_rate -= 1

				if federal_rate == 0:
					federal_rate = 1
				else:
					news_items.append(NewsEvent.new(NEWS_FEDERAL_RATE_DOWN, federal_rate))

				BinaryData.write_u32_be(data, MISC_NATIONAL_FEDERAL_RATE, federal_rate)

		if random.next_u15() % 3 == 0:
			var new_trend := economy_level(national_score)

			if new_trend != economy_trend:
				economy_trend = new_trend
				BinaryData.write_u32_be(data, MISC_NATIONAL_ECONOMY_TREND, economy_trend)
				news_items.append(NewsEvent.new(NEWS_NATIONAL_ECONOMY, economy_trend))

	var neighbor_populations := PackedInt64Array()
	var neighbor_values := PackedInt64Array()

	for neighbor in NEIGHBOR_COUNT:
		var base := Sc2MiscLayout.NEIGHBORS + neighbor * NEIGHBOR_STRIDE
		var population := BinaryData.read_u32_be(data, base + NEIGHBOR_POPULATION)
		var value := BinaryData.read_u32_be(data, base + NEIGHBOR_VALUE)

		if population != 0:
			population_change = _scaled_change(
				population, economy_trend + random.next_u15() % 3
			)
			population = _move_about_center(
				population, population_change, NATIONAL_POPULATION_CENTER
			)

			if population_change == 0:
				population = (population + (random.next_u15() & 1)) & 0xffffffff

			BinaryData.write_u32_be(data, base + NEIGHBOR_POPULATION, population)

			var neighbor_score := int(float(value) / float(population) * 100.0)
			var value_factor: int = (
				int(ECONOMY_FACTORS[economy_trend])
				+ random.next_u15() % 5
				- federal_rate
				- economy_level(neighbor_score)
			)
			value_change = _scaled_change(value, value_factor)
			value = _move_about_center(value, value_change, NATIONAL_VALUE_CENTER)
			BinaryData.write_u32_be(data, base + NEIGHBOR_VALUE, value)

		neighbor_populations.append(population)
		neighbor_values.append(value)

	var shocked_neighbor := -1

	if random.next_u15() & 0x3f == 0:
		shocked_neighbor = random.next_u15() & 3
		var shock_base := Sc2MiscLayout.NEIGHBORS + shocked_neighbor * NEIGHBOR_STRIDE
		neighbor_populations[shocked_neighbor] = int(
			float(neighbor_populations[shocked_neighbor]) * 0.75
		)
		neighbor_values[shocked_neighbor] = int(
			float(neighbor_values[shocked_neighbor]) * 0.5
		)
		BinaryData.write_u32_be(
			data, shock_base + NEIGHBOR_POPULATION, neighbor_populations[shocked_neighbor]
		)
		BinaryData.write_u32_be(data, shock_base + NEIGHBOR_VALUE, neighbor_values[shocked_neighbor])

	if not misc_chunk.set_decoded_payload(data):
		return _failed("cannot store the SimNation update")

	var result := Result.new()
	result.ok = true
	result.national_population = national_population
	result.national_value = national_value
	result.federal_rate = federal_rate
	result.economy_trend = economy_trend
	result.neighbor_populations = neighbor_populations
	result.neighbor_values = neighbor_values
	result.shocked_neighbor = shocked_neighbor
	result.news_items = news_items

	return result

static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func economy_level(score: int) -> int:
	if score < 45:
		return 0

	if score < 60:
		return 1

	if score < 75:
		return 2

	return 3


static func _scaled_change(value: int, factor: int) -> int:
	return int(float(value) * float(factor) / MONTHLY_SCALE)


static func _move_about_center(value: int, change: int, center: int) -> int:
	return ((value - change) if value > center else (value + change)) & 0xffffffff


static func _to_i16(value: int) -> int:
	var word := value & 0xffff

	return word - 0x10000 if word & 0x8000 else word
