class_name MicrosimAnnualValues
extends MicrosimAnnualConstants


@warning_ignore_start("integer_division")


static func _tile_count(misc: PackedByteArray, tile_id: int, map_edge: int = 128) -> int:
	var value := BinaryData.read_u32_be(misc, MISC_TILE_COUNTS + tile_id * 4)

	return _to_i16(value) if map_edge == 128 else value


static func _budget_funding(misc: PackedByteArray, budget_id: int) -> int:
	return BinaryData.read_i32_be(
		misc, MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE + BUDGET_FUNDING
	)


static func _find_microsim_location(
	text_overlays: PackedByteArray,
	record_id: int,
	map_edge: int = 128,
	budget: SimulationSliceBudget = null,
) -> Vector2i:
	if OverlayData.count(text_overlays) != map_edge * map_edge:
		return Vector2i(-1, -1)

	var text_id := OverlayData.facility_id(record_id)

	for x in map_edge:
		if budget != null:
			budget.checkpoint()

		for y in map_edge:
			if int(OverlayData.read(text_overlays, x * map_edge + y)) == text_id:
				if x == 0 and y == 0:
					return Vector2i(-1, -1)

				return Vector2i(x, y)

	return Vector2i(-1, -1)


static func _to_i16(value: int) -> int:
	var wrapped := value & 0xffff

	return wrapped - 0x10000 if wrapped >= 0x8000 else wrapped


static func _to_i32(value: int) -> int:
	var wrapped := value & 0xffffffff

	return wrapped - 0x100000000 if wrapped >= 0x80000000 else wrapped


static func _divide_toward_zero(value: int, divisor: int) -> int:
	if value >= 0:
		return int(value / divisor)

	return -int((-value) / divisor)
