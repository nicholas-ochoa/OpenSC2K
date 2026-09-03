class_name GraphHistory
extends RefCounted

@warning_ignore_start("integer_division")

const SERIES_COUNT := 16
const VALUES_PER_SERIES := 52
const MISC_SIZE := 4800
const MISC_CITY_LAND_VALUE := 0x0028
const MISC_CITY_CRIME := 0x002c
const MISC_CITY_TRAFFIC := 0x0030
const MISC_CITY_POLLUTION := 0x0034
const MISC_WORKFORCE_LE := 0x0048
const MISC_WORKFORCE_EQ := 0x004c
const MISC_NATIONAL_POPULATION := 0x0050
const MISC_NATIONAL_VALUE := 0x0054
const MISC_NATIONAL_FEDERAL_RATE := 0x0058
const MISC_TILE_COUNTS := 0x01f0
const MISC_ZONE_POPULATIONS := 0x05f0
const MISC_BUDGETS := 0x077c
const MISC_BUDGET_RECORD_SIZE := 0x006c
const MISC_UNEMPLOYMENT := 0x0fa4
const MISC_ARCOLOGY_POPULATION := 0x1020

const BUDGET_ROAD := 10
const BUDGET_HIGHWAY := 11
const BUDGET_BRIDGE := 12
const FIRST_ARCOLOGY := 0xfb
const LAST_ARCOLOGY := 0xfe


class Result extends PhaseResult:
	var month := 0
	var elapsed_years := 0
	var values := PackedInt64Array()
	var unemployment := 0


static func run(
	city: CityState, developed_tiles: int, power_usage_percent: int, water_usage_percent: int
) -> Result:
	var span := SimulationTimingSpan.new(city.simulation_slice if city != null else null)
	span.mark("calculate graph values")
	var calculation := calculate_current_values(
		city, developed_tiles, power_usage_percent, water_usage_percent
	)

	if not calculation.ok:
		return _failed(calculation.error)

	var chunk := city.document.find_chunk("XGRP")

	if chunk == null or chunk.decoded_payload.size() != SERIES_COUNT * VALUES_PER_SERIES * 4:
		return _failed("XGRP is missing or has the wrong size")

	span.mark("store unemployment")
	if not city.document.set_misc_u32(MISC_UNEMPLOYMENT, calculation.unemployment):
		return _failed("cannot store the unemployment percentage")

	span.mark("shift graph histories")
	var history := advance(city, calculation.values)

	if not history.ok:
		return _failed(history.error)

	var result := Result.new()
	result.ok = true
	result.month = history.month
	result.elapsed_years = history.elapsed_years
	result.values = calculation.values
	result.unemployment = calculation.unemployment
	result.timing = span.finish()

	return result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func calculate_current_values(
	city: CityState, developed_tiles: int, power_usage_percent: int, water_usage_percent: int
) -> Result:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return _failed("city is invalid")

	var misc := city.document.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() != MISC_SIZE:
		return _failed("MISC is missing or has the wrong size")

	if developed_tiles < 0 or developed_tiles > (map_edge * map_edge):
		return _failed("developed tile count is out of range")

	if power_usage_percent < 0 or power_usage_percent > 100:
		return _failed("power usage percentage is out of range")

	if water_usage_percent < 0 or water_usage_percent > 100:
		return _failed("water usage percentage is out of range")

	var zone_populations := PackedInt64Array()

	for index in 8:
		zone_populations.append(
			city.document.misc_u32(MISC_ZONE_POPULATIONS + index * 4)
		)

	var total_zone_population := 0

	for index in range(1, 7):
		total_zone_population += zone_populations[index]

	var tax_populations := PackedInt64Array(
		[
			zone_populations[1] + zone_populations[2],
			zone_populations[3] + zone_populations[4],
			zone_populations[5] + zone_populations[6],
		]
	)

	var arcology_tiles := 0

	for tile_id in range(FIRST_ARCOLOGY, LAST_ARCOLOGY + 1):
		arcology_tiles += city.document.misc_i32(MISC_TILE_COUNTS + tile_id * 4)

	var arcology_count := _divide_toward_zero(arcology_tiles, 16)
	var arcology_adjustment := 0

	if arcology_count > 140:
		arcology_adjustment = (arcology_count * 5 - 700) * 4000

	var arcology_population := city.document.misc_u32(MISC_ARCOLOGY_POPULATION)
	var adjusted_arcology_population := arcology_population + arcology_adjustment

	var transport_cost := 1

	for budget_id in [BUDGET_ROAD, BUDGET_HIGHWAY, BUDGET_BRIDGE]:
		transport_cost += city.document.misc_i32(
			MISC_BUDGETS + budget_id * MISC_BUDGET_RECORD_SIZE
		)

	if transport_cost <= 0:
		return _failed("transport graph divisor is not positive")

	var developed_divisor := _divide_toward_zero(developed_tiles, 4) + 1
	var unemployment := int(
		((zone_populations[7] * 100) / (total_zone_population + zone_populations[7] + 1))
	)

	var values := PackedInt64Array(
		[
			arcology_population + total_zone_population * 10 + arcology_adjustment,
			_divide_toward_zero(adjusted_arcology_population, 2) + tax_populations[0] * 10,
			_divide_toward_zero(adjusted_arcology_population, 4) + tax_populations[1] * 10,
			_divide_toward_zero(adjusted_arcology_population, 4) + tax_populations[2] * 10,
			int(city.document.misc_u32(MISC_CITY_TRAFFIC) / transport_cost),
			int(city.document.misc_u32(MISC_CITY_POLLUTION) / developed_divisor),
			int(city.document.misc_u32(MISC_CITY_LAND_VALUE) / developed_divisor),
			int(city.document.misc_u32(MISC_CITY_CRIME) / developed_divisor),
			100 - power_usage_percent,
			100 - water_usage_percent,
			city.document.misc_u32(MISC_WORKFORCE_LE),
			city.document.misc_u32(MISC_WORKFORCE_EQ),
			unemployment,
			city.document.misc_u32(MISC_NATIONAL_VALUE),
			city.document.misc_u32(MISC_NATIONAL_POPULATION),
			city.document.misc_i32(MISC_NATIONAL_FEDERAL_RATE),
		]
	)

	var result := Result.new()
	result.ok = true
	result.values = values
	result.unemployment = unemployment
	result.error = ""

	return result


static func advance(city: CityState, current_values: PackedInt64Array) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if current_values.size() != SERIES_COUNT:
		return _failed("sixteen current graph values are required")

	var chunk := city.document.find_chunk("XGRP")

	if chunk == null or chunk.decoded_payload.size() != SERIES_COUNT * VALUES_PER_SERIES * 4:
		return _failed("XGRP is missing or has the wrong size")

	var data := chunk.decoded_payload.duplicate()
	var month := int((city.age_in_days() % 300) / 25)
	var elapsed_years := int(city.age_in_days() / 300)

	for series in SERIES_COUNT:
		for index in range(11, 0, -1):
			_copy_value(data, series, index - 1, index)

		_write_value(data, series, 0, current_values[series])

		if month == 0 or month == 6:
			for index in range(31, 12, -1):
				_copy_value(data, series, index - 1, index)

			_copy_value(data, series, 0, 12)

		if month == 0 and elapsed_years % 5 == 0:
			for index in range(51, 32, -1):
				_copy_value(data, series, index - 1, index)

			_copy_value(data, series, 0, 32)

	if not chunk.set_decoded_payload(data):
		return _failed("cannot store updated XGRP data")

	var result := Result.new()
	result.ok = true
	result.month = month
	result.elapsed_years = elapsed_years
	result.error = ""

	return result


static func _copy_value(data: PackedByteArray, series: int, source: int, target: int) -> void:
	var base := series * VALUES_PER_SERIES * 4

	for byte_index in 4:
		data[base + target * 4 + byte_index] = data[base + source * 4 + byte_index]


static func _write_value(data: PackedByteArray, series: int, index: int, value: int) -> void:
	var offset := (series * VALUES_PER_SERIES + index) * 4
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff


static func _divide_toward_zero(value: int, divisor: int) -> int:
	return int(value / divisor)
