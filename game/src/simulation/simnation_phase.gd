class_name SimNationPhase
extends RefCounted

const MISC_SIZE := 4800
const MISC_NATIONAL_POPULATION := 0x0050
const MISC_NATIONAL_VALUE := 0x0054
const MISC_NATIONAL_FEDERAL_RATE := 0x0058
const MISC_NATIONAL_ECONOMY_TREND := 0x005c
const MISC_NEIGHBORS := 0x06d8
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


static func run(city: CityState, random) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}
	var misc_chunk := city.document.find_chunk("MISC")
	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}

	var data: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var economy_trend := _to_i16(_read_u32(data, MISC_NATIONAL_ECONOMY_TREND))
	if economy_trend < 0 or economy_trend >= ECONOMY_FACTORS.size():
		return {"ok": false, "error": "the national economy trend is out of range"}
	var federal_rate := _to_i16(_read_u32(data, MISC_NATIONAL_FEDERAL_RATE))
	if federal_rate <= 0:
		return {"ok": false, "error": "the national federal rate is not positive"}
	var news_items: Array = []

	var national_population := _read_u32(data, MISC_NATIONAL_POPULATION)
	var population_change := _scaled_change(national_population, economy_trend)
	national_population = _move_about_center(
		national_population, population_change, NATIONAL_POPULATION_CENTER
	)
	_write_u32(data, MISC_NATIONAL_POPULATION, national_population)

	var national_value := _read_u32(data, MISC_NATIONAL_VALUE)
	var value_change := _scaled_change(national_value, ECONOMY_FACTORS[economy_trend])
	national_value = _move_about_center(national_value, value_change, NATIONAL_VALUE_CENTER)
	_write_u32(data, MISC_NATIONAL_VALUE, national_value)

	if random.next_u15() % 10 == 0:
		var national_score := int(float(national_value) / float(national_population + 1) * 100.0)
		if random.next_u15() % 5 < 2:
			if random.next_u15() % (federal_rate * 25) < national_score:
				federal_rate += 1
				_write_u32(data, MISC_NATIONAL_FEDERAL_RATE, federal_rate)
				news_items.append({"type": NEWS_FEDERAL_RATE_UP, "argument": federal_rate})
			if national_score < random.next_u15() % (federal_rate * 25):
				federal_rate -= 1
				if federal_rate == 0:
					federal_rate = 1
				else:
					news_items.append({"type": NEWS_FEDERAL_RATE_DOWN, "argument": federal_rate})
				_write_u32(data, MISC_NATIONAL_FEDERAL_RATE, federal_rate)
		if random.next_u15() % 3 == 0:
			var new_trend := economy_level(national_score)
			if new_trend != economy_trend:
				economy_trend = new_trend
				_write_u32(data, MISC_NATIONAL_ECONOMY_TREND, economy_trend)
				news_items.append({"type": NEWS_NATIONAL_ECONOMY, "argument": economy_trend})

	var neighbor_populations := PackedInt64Array()
	var neighbor_values := PackedInt64Array()
	for neighbor in NEIGHBOR_COUNT:
		var base := MISC_NEIGHBORS + neighbor * NEIGHBOR_STRIDE
		var population := _read_u32(data, base + NEIGHBOR_POPULATION)
		var value := _read_u32(data, base + NEIGHBOR_VALUE)
		if population != 0:
			population_change = _scaled_change(
				population, economy_trend + random.next_u15() % 3
			)
			population = _move_about_center(
				population, population_change, NATIONAL_POPULATION_CENTER
			)
			if population_change == 0:
				population = (population + (random.next_u15() & 1)) & 0xffffffff
			_write_u32(data, base + NEIGHBOR_POPULATION, population)

			var neighbor_score := int(float(value) / float(population) * 100.0)
			var value_factor: int = (
				int(ECONOMY_FACTORS[economy_trend])
				+ random.next_u15() % 5
				- federal_rate
				- economy_level(neighbor_score)
			)
			value_change = _scaled_change(value, value_factor)
			value = _move_about_center(value, value_change, NATIONAL_VALUE_CENTER)
			_write_u32(data, base + NEIGHBOR_VALUE, value)
		neighbor_populations.append(population)
		neighbor_values.append(value)

	var shocked_neighbor := -1
	if random.next_u15() & 0x3f == 0:
		shocked_neighbor = random.next_u15() & 3
		var shock_base := MISC_NEIGHBORS + shocked_neighbor * NEIGHBOR_STRIDE
		neighbor_populations[shocked_neighbor] = int(
			float(neighbor_populations[shocked_neighbor]) * 0.75
		)
		neighbor_values[shocked_neighbor] = int(
			float(neighbor_values[shocked_neighbor]) * 0.5
		)
		_write_u32(
			data, shock_base + NEIGHBOR_POPULATION, neighbor_populations[shocked_neighbor]
		)
		_write_u32(data, shock_base + NEIGHBOR_VALUE, neighbor_values[shocked_neighbor])

	if not misc_chunk.set_decoded_payload(data):
		return {"ok": false, "error": "cannot store the SimNation update"}
	return {
		"ok": true,
		"error": "",
		"national_population": national_population,
		"national_value": national_value,
		"federal_rate": federal_rate,
		"economy_trend": economy_trend,
		"neighbor_populations": neighbor_populations,
		"neighbor_values": neighbor_values,
		"shocked_neighbor": shocked_neighbor,
		"news_items": news_items,
	}


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


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff
