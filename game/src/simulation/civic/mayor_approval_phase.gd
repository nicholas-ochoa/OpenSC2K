class_name MayorApprovalPhase
extends RefCounted

const MISC_SIZE := 4800
const XGRP_SIZE := 16 * 52 * 4
const MISC_WORKFORCE_LIFE_EXPECTANCY := 0x0048
const MISC_WORKFORCE_EDUCATION := 0x004c
const MISC_BUDGETS := 0x077c
const MISC_UNEMPLOYMENT := 0x0fa4
const MISC_NORMAL_POPULATION := 0x102c
const BUDGET_RECORD_SIZE := 0x006c
const BUDGET_FUNDING := 0x04
const BUDGET_RESIDENTIAL := 0
const GRAPH_TRAFFIC := 4
const GRAPH_POLLUTION := 5
const GRAPH_LAND_VALUE := 6
const GRAPH_CRIME := 7
const GRAPH_VALUE_COUNT := 52
const TILE_MAYOR_HOUSE := 0xf3
const NEWS_HIGH_APPROVAL := 0x201


static func run(city: CityState, random, previous_approval: int) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible random generator is required"}

	var misc_chunk := city.document.find_chunk("MISC")
	var graph_chunk := city.document.find_chunk("XGRP")
	var microsim_chunk := city.document.find_chunk("XMIC")

	if (
		misc_chunk == null
		or misc_chunk.decoded_payload.size() != MISC_SIZE
		or graph_chunk == null
		or graph_chunk.decoded_payload.size() != XGRP_SIZE
		or microsim_chunk == null
		or microsim_chunk.decoded_payload.size()
		!= city.document.decoded_size("XMIC")
	):
		return {"ok": false, "error": "MISC, XGRP, or XMIC has the wrong size"}

	var misc: PackedByteArray = misc_chunk.decoded_payload
	var graphs: PackedByteArray = graph_chunk.decoded_payload
	var microsims: PackedByteArray = microsim_chunk.decoded_payload.duplicate()
	var weights := PackedInt32Array([
		_to_i16(_graph_current(graphs, GRAPH_TRAFFIC)),
		_to_i16(_graph_current(graphs, GRAPH_POLLUTION)),
		_to_i16(_graph_current(graphs, GRAPH_CRIME)),
		_to_i16(_read_u32(misc, MISC_UNEMPLOYMENT)),
		_to_i16(_budget_funding(misc, BUDGET_RESIDENTIAL) * 3),
		maxi(100 - _to_i16(_read_u32(misc, MISC_WORKFORCE_EDUCATION)), 0),
		maxi(70 - _to_i16(_read_u32(misc, MISC_WORKFORCE_LIFE_EXPECTANCY)), 0),
	])
	var total := _to_i16(_graph_current(graphs, GRAPH_LAND_VALUE)) + 50

	for weight in weights:
		total = _to_i16(total + weight)

	var approval := _to_i16(previous_approval)
	var survey_counts := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])

	if total != 0 and _read_u32(misc, MISC_NORMAL_POPULATION) > 99:
		approval = 0

		for _sample in 100:
			var selection: int = random.next_u15() % total
			var category := 0

			while category < weights.size():
				if _to_i16(selection) < int(weights[category]):
					break

				selection = _to_i16(selection - int(weights[category])) & 0xffff
				category += 1

			if category == weights.size():
				approval += 1
			else:
				survey_counts[category] += 1

	var updated_records := 0

	for record_id in range(1, microsims.size() / CityState.MICROSIM_RECORD_SIZE):
		var offset := record_id * CityState.MICROSIM_RECORD_SIZE

		if int(microsims[offset]) != TILE_MAYOR_HOUSE:
			continue

		_write_u16_be(microsims, offset + 4, approval)

		if _read_u16_be(microsims, offset + 6) != 0:
			_write_u16_be(microsims, offset + 6, _read_u16_be(microsims, offset + 6) - 1)
			microsims[offset + 1] = (int(microsims[offset + 1]) + 1) & 0xff

		updated_records += 1

	if not microsim_chunk.set_decoded_payload(microsims):
		return {"ok": false, "error": "cannot store mayor house statistics"}

	var ranking := PackedInt32Array([0, 1, 2, 3, 4, 5, 6])

	for end in range(ranking.size() - 1, 0, -1):
		for index in end:
			if survey_counts[ranking[index]] < survey_counts[ranking[index + 1]]:
				var prior := ranking[index]
				ranking[index] = ranking[index + 1]
				ranking[index + 1] = prior

	var news_items := []

	if previous_approval < 80 and approval > 79:
		news_items.append({"type": NEWS_HIGH_APPROVAL, "argument": 0})

	return {
		"ok": true,
		"error": "",
		"approval": approval,
		"previous_approval": previous_approval,
		"weights": weights,
		"survey_counts": survey_counts,
		"ranking": ranking,
		"updated_mayor_house_records": updated_records,
		"news_items": news_items,
		"complete": true,
	}


static func _graph_current(data: PackedByteArray, graph_id: int) -> int:
	return _read_u32(data, graph_id * GRAPH_VALUE_COUNT * 4)


static func _budget_funding(misc: PackedByteArray, budget_id: int) -> int:
	return _read_i32(
		misc, MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE + BUDGET_FUNDING
	)


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


static func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff
