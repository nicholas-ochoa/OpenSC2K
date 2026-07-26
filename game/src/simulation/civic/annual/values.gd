class_name MicrosimAnnualValues
extends MicrosimAnnualConstants


@warning_ignore_start("integer_division")


static func _tile_count(misc: PackedByteArray, tile_id: int, map_edge: int = 128) -> int:
	var value := _read_u32(misc, MISC_TILE_COUNTS + tile_id * 4)

	return _to_i16(value) if map_edge == 128 else value


static func _budget_funding(misc: PackedByteArray, budget_id: int) -> int:
	return _read_i32(
		misc, MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE + BUDGET_FUNDING
	)


static func _raw_population(misc: PackedByteArray, cohort: int) -> int:
	return _read_u32(misc, MISC_RAW_POPULATION + cohort * MISC_DEMOGRAPHIC_RECORD_SIZE)


static func _find_microsim_location(text_overlays: PackedByteArray, record_id: int, map_edge: int = 128, budget: SimulationSliceBudget = null) -> Dictionary:
	if OverlayData.count(text_overlays) != map_edge * map_edge:
		return {}

	var text_id := OverlayData.facility_id(record_id)

	for x in map_edge:
		if budget != null:
			budget.checkpoint()

		for y in map_edge:
			if int(OverlayData.read(text_overlays, x * map_edge + y)) == text_id:
				if x == 0 and y == 0:
					return {}

				return {"x": x, "y": y}

	return {}


static func _arcology_count(misc: PackedByteArray, map_edge: int = 128) -> int:
	var count := 0

	for tile_id in range(TILE_ARCOLOGY_FIRST, TILE_ARCOLOGY_LAST + 1):
		count += _tile_count(misc, tile_id, map_edge)

	return _divide_toward_zero(count, 16)


static func _service_score(
	numerator: int, denominator: int, slope: int, best_limit := 50, zero_limit := 111
) -> int:
	var safe_denominator := denominator & 0xffff

	if safe_denominator == 0:
		safe_denominator = 1

	var ratio := _divide_toward_zero(numerator, safe_denominator)

	if ratio < best_limit:
		return 12

	if ratio < zero_limit:
		return _divide_toward_zero(zero_limit - 1 - ratio, slope)

	return 0


static func _adjusted_population(misc: PackedByteArray, map_edge: int = 128) -> int:
	var arcology_count := 0

	for tile_id in range(0xfb, 0xff):
		arcology_count += _tile_count(misc, tile_id, map_edge)

	arcology_count = _divide_toward_zero(arcology_count, 16)
	var adjustment := 0

	if arcology_count > 140:
		adjustment = (arcology_count * 5 - 700) * 4000

	return (
		_read_u32(misc, MISC_ARCOLOGY_POPULATION)
		+ adjustment
		+ _read_u32(misc, MISC_NORMAL_POPULATION)
	)


static func _population_cap(misc: PackedByteArray, maximum: int, divisor: int, map_edge: int = 128) -> int:
	if divisor == 0:
		divisor = 100

	var arcology_count := 0

	for tile_id in range(0xfb, 0xff):
		arcology_count += _tile_count(misc, tile_id, map_edge)

	arcology_count = _divide_toward_zero(arcology_count, 16)
	var arcology_adjustment := 0

	if arcology_count >= 141:
		arcology_adjustment = arcology_count * 20000 - 2800000

	var total_population := (
		arcology_adjustment
		+ _read_u32(misc, MISC_ARCOLOGY_POPULATION)
		+ _read_u32(misc, MISC_NORMAL_POPULATION)
	)
	var available := int(total_population / divisor) & (0xffff if map_edge == 128 else 0xffffffff)
	var signed_maximum := _to_i16(maximum)

	return signed_maximum if signed_maximum <= available else available


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _read_i32(data: PackedByteArray, offset: int) -> int:
	var value := _read_u32(data, offset)

	return value - 0x100000000 if value >= 0x80000000 else value


static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 8) | data[offset + 1]


static func _to_i16(value: int) -> int:
	var wrapped := value & 0xffff

	return wrapped - 0x10000 if wrapped >= 0x8000 else wrapped


static func _to_i32(value: int) -> int:
	var wrapped := value & 0xffffffff

	return wrapped - 0x100000000 if wrapped >= 0x80000000 else wrapped


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff


static func _write_i32(data: PackedByteArray, offset: int, value: int) -> void:
	_write_u32(data, offset, value & 0xffffffff)


static func _divide_toward_zero(value: int, divisor: int) -> int:
	if value >= 0:
		return int(value / divisor)

	return -int((-value) / divisor)


static func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff
