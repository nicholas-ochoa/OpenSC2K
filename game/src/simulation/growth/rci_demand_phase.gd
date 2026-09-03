class_name RciDemandPhase
extends RefCounted

@warning_ignore_start("integer_division")

const ZONE_POPULATION_OFFSET := 0x05f0
const DEMAND_OFFSET := 0x0718
const BUDGET_OFFSET := 0x077c
const BUDGET_RECORD_SIZE := 0x006c
const TILE_COUNT_OFFSET := 0x01f0
const ORDINANCES_OFFSET := 0x0fa0
const ARCOLOGY_POPULATION_OFFSET := 0x1020
const NORMAL_POPULATION_OFFSET := 0x102c
const INDUSTRIAL_MIX_BONUS_OFFSET := 0x1030
const OLD_RESIDENTIAL_POPULATION_OFFSET := 0x0074
const GARBAGE_OFFSET := 0x0040

const CONNECTION_LABEL := 0xfa
const RATIO_SCALE := 600.0
const COMMERCIAL_SCALE := 0.000006666666666666667
const INDUSTRIAL_MIX_SCALE := 0.01
const MINIMUM_INDUSTRIAL_TARGET := 15.0

const TAX_EFFECT := [
	200, 160, 120, 100, 75, 50, 25, 0, -25, -50, -100, -150,
	-200, -250, -300, -350, -400, -450, -500, -550, -600, -650, -700,
]
const INDUSTRIAL_DIFFICULTY := [0.0, 1.2, 1.1, 0.95]

const COMMERCE_CONNECTION_RANGES := [
	Vector2i(0x1d, 0x2b),
	Vector2i(0x3f, 0x42),
	Vector2i(0x4b, 0x4c),
	Vector2i(0x5d, 0x60),
]
const INDUSTRY_CONNECTION_RANGES := [
	Vector2i(0x2c, 0x3e),
	Vector2i(0x45, 0x50),
	Vector2i(0x61, 0x69),
]


class Result extends PhaseResult:
	var previous_population := 0
	var normal_population := 0
	var tax_population := PackedInt64Array()
	var targets: Array = []
	var demands := PackedInt32Array()
	var commerce_connections := 0
	var industry_connections := 0


class ConnectionCounts extends RefCounted:
	var commerce := 0
	var industry := 0


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	var misc := city.document.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() < 0x1054:
		return _failed("MISC data is missing or too short")

	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("prepare data")
	var zone_population := PackedInt64Array()
	zone_population.resize(8)

	for index in 8:
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		zone_population[index] = city.document.misc_i32(ZONE_POPULATION_OFFSET + index * 4)

	zone_population[0] = 0

	for index in range(1, 7):
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		zone_population[0] += zone_population[index]

	var tax_population := PackedInt64Array([
		zone_population[1] + zone_population[2],
		zone_population[3] + zone_population[4],
		zone_population[5] + zone_population[6],
	])
	var previous_population := city.document.misc_i32(NORMAL_POPULATION_OFFSET)
	var normal_population := int(zone_population[0] * 10)
	var old_residential := city.document.misc_i32(OLD_RESIDENTIAL_POPULATION_OFFSET)
	var jobs := float(tax_population[1] + tax_population[2])
	var resident_job_ratio := float(old_residential) / (jobs + 1.0)

	var residential_target := float(int(tax_population[0] / 50)) + jobs
	residential_target = minf(
		residential_target,
		float(
			(
				int(_tile_count(city, 0xd5) / 3)
				+ _tile_count(city, 0xd7)
				+ _tile_count(city, 0xda)
				+ 10
				+ _tile_count(city, 0xf8)
			) * 150
		),
	)
	residential_target = minf(residential_target, float(tax_population[1] * 4 + 500))

	var industrial_population := float(tax_population[2])
	var commercial_target := (
		float(normal_population + 50000)
		* COMMERCIAL_SCALE
		* resident_job_ratio
		* industrial_population
	)
	var difficulty := clampi(city.difficulty(), 0, INDUSTRIAL_DIFFICULTY.size() - 1)
	var industrial_target: float = (
		(
			float(city.document.misc_i32(INDUSTRIAL_MIX_BONUS_OFFSET))
			* INDUSTRIAL_MIX_SCALE
			+ INDUSTRIAL_DIFFICULTY[difficulty]
		)
		* resident_job_ratio
		* industrial_population
	)
	industrial_target = maxf(industrial_target, MINIMUM_INDUSTRIAL_TARGET)

	span.mark("neighbor connections")
	var connections := connection_counts(city)
	span.mark("demand caps and taxes")
	commercial_target = minf(
		commercial_target,
		float(
			(
				int(
					(connections.commerce + _tile_count(city, 0xdd) + _tile_count(city, 0xde))
					/ 5
				)
				* 4
				+ 4
			) * 375
		),
	)
	industrial_target = minf(
		industrial_target,
		float((_tile_count(city, 0xe0) + 1 + connections.industry) * 1500),
	)

	var targets := [residential_target, commercial_target, industrial_target]
	var ordinance_flags := city.document.misc_u32(ORDINANCES_OFFSET)
	var demands := PackedInt32Array()

	for index in 3:
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		var tax_rate := city.document.misc_i32(BUDGET_OFFSET + index * BUDGET_RECORD_SIZE + 4)
		tax_rate = _ordinance_adjusted_tax_rate(index, tax_rate, ordinance_flags)
		tax_rate = clampi(tax_rate, 0, TAX_EFFECT.size() - 1)
		var ratio := float(targets[index]) / float(tax_population[index] + 1) - 1.0
		var change := int(ratio * RATIO_SCALE + TAX_EFFECT[tax_rate])
		var demand := clampi(city.document.misc_i32(DEMAND_OFFSET + index * 4) + change, -2000, 2000)
		demands.append(demand)

	span.mark("store demand and population")
	var changed := misc.decoded_payload.duplicate()
	_write_i32(changed, ZONE_POPULATION_OFFSET, zone_population[0])
	_write_i32(changed, NORMAL_POPULATION_OFFSET, normal_population)
	_write_i32(changed, GARBAGE_OFFSET, city.document.misc_i32(GARBAGE_OFFSET) + normal_population)
	_write_i32(changed, OLD_RESIDENTIAL_POPULATION_OFFSET, tax_population[0])
	var arcology_population := city.document.misc_i32(ARCOLOGY_POPULATION_OFFSET)

	for index in 3:
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		var budget_population := tax_population[index] * 10
		budget_population += int(arcology_population / (6 if index == 0 else 12))
		_write_i32(changed, BUDGET_OFFSET + index * BUDGET_RECORD_SIZE, budget_population)
		_write_i32(changed, DEMAND_OFFSET + index * 4, demands[index])

	if not misc.set_decoded_payload(changed):
		return _failed("cannot store updated MISC data")

	var result := Result.new()
	result.ok = true
	result.previous_population = previous_population
	result.normal_population = normal_population
	result.tax_population = tax_population
	result.targets = targets
	result.demands = demands
	result.commerce_connections = connections.commerce
	result.industry_connections = connections.industry
	result.timing = span.finish()

	return result

static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func connection_counts(city: CityState) -> ConnectionCounts:
	var map_edge: int = city.map_size if city != null else 128
	var commerce := 0
	var industry := 0

	for index in (map_edge * map_edge):
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		if OverlayData.read(city.text_overlays, index) != CONNECTION_LABEL:
			continue

		var tile := city.buildings[index]

		if _in_ranges(tile, COMMERCE_CONNECTION_RANGES):
			commerce += 1

		if _in_ranges(tile, INDUSTRY_CONNECTION_RANGES):
			industry += 1

	var result := ConnectionCounts.new()
	result.commerce = commerce
	result.industry = industry

	return result


static func _in_ranges(value: int, ranges: Array) -> bool:
	for range_value in ranges:
		if value >= range_value.x and value <= range_value.y:
			return true

	return false


static func _tile_count(city: CityState, tile_id: int) -> int:
	return city.document.misc_i32(TILE_COUNT_OFFSET + tile_id * 4)


static func _ordinance_adjusted_tax_rate(category: int, rate: int, flags: int) -> int:
	match category:
		0:
			if flags & 0x0002:
				rate += 1

			if flags & 0x4000:
				rate -= 1
		1:
			if flags & 0x0001:
				rate += 1

			for mask in [0x1000, 0x8000, 0x40000]:
				if flags & mask:
					rate -= 1
		2:
			if flags & 0x2000:
				rate -= 1

			if flags & 0x80000:
				rate += 1

	return maxi(rate, 0)


static func _write_i32(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff
