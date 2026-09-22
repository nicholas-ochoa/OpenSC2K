class_name MayorApprovalPhase
extends RefCounted

@warning_ignore_start("integer_division")

const MISC_SIZE := Sc2MiscLayout.SIZE
const XGRP_SIZE := 16 * 52 * 4
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION
const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const BUDGET_FUNDING := Sc2BudgetLayout.FUNDING
const BUDGET_RESIDENTIAL := Sc2BudgetLayout.RESIDENTIAL
const GRAPH_TRAFFIC := 4
const GRAPH_POLLUTION := 5
const GRAPH_LAND_VALUE := 6
const GRAPH_CRIME := 7
const GRAPH_VALUE_COUNT := 52
const TILE_MAYOR_HOUSE := BuildingTileIds.MAYOR_HOUSE
const NEWS_HIGH_APPROVAL := 0x201


class Result extends PhaseResult:
	var approval := 0
	var previous_approval := 0
	var weights := PackedInt32Array()
	var survey_counts := PackedInt32Array()
	var ranking := PackedInt32Array()
	var updated_mayor_house_records := 0


static func failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func run(city: CityState, random: SimRandom, previous_approval: int) -> Result:
	if city == null or not city.is_valid():
		return failed("city is invalid")

	if random == null:
		return failed("a compatible random generator is required")

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
		return failed("MISC, XGRP, or XMIC has the wrong size")

	var misc: PackedByteArray = misc_chunk.decoded_payload
	var graphs: PackedByteArray = graph_chunk.decoded_payload
	var microsims: PackedByteArray = microsim_chunk.decoded_payload.duplicate()
	var weights := complaint_weights(city)
	var total := _to_i16(_graph_current(graphs, GRAPH_LAND_VALUE)) + 50

	for weight in weights:
		total = _to_i16(total + weight)

	var approval := _to_i16(previous_approval)
	var survey_counts := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])

	if total != 0 and BinaryData.read_u32_be(misc, MISC_NORMAL_POPULATION) > 99:
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

		BinaryData.write_u16_be(microsims, offset + 4, approval)

		if BinaryData.read_u16_be(microsims, offset + 6) != 0:
			BinaryData.write_u16_be(microsims, offset + 6, BinaryData.read_u16_be(microsims, offset + 6) - 1)
			microsims[offset + 1] = (int(microsims[offset + 1]) + 1) & 0xff

		updated_records += 1

	if not microsim_chunk.set_decoded_payload(microsims):
		return failed("cannot store mayor house statistics")

	var ranking := PackedInt32Array([0, 1, 2, 3, 4, 5, 6])

	for end in range(ranking.size() - 1, 0, -1):
		for index in end:
			if survey_counts[ranking[index]] < survey_counts[ranking[index + 1]]:
				var prior := ranking[index]
				ranking[index] = ranking[index + 1]
				ranking[index + 1] = prior

	var news_items: Array[NewsEvent] = []

	if previous_approval < 80 and approval > 79:
		news_items.append(NewsEvent.new(NEWS_HIGH_APPROVAL, 0))

	var result := Result.new()
	result.ok = true
	result.approval = approval
	result.previous_approval = previous_approval
	result.weights = weights
	result.survey_counts = survey_counts
	result.ranking = ranking
	result.updated_mayor_house_records = updated_records
	result.news_items = news_items

	return result


static func complaint_weights(city: CityState) -> PackedInt32Array:
	if city == null or not city.is_valid():
		return PackedInt32Array()

	var misc_chunk := city.document.find_chunk("MISC")
	var graph_chunk := city.document.find_chunk("XGRP")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return PackedInt32Array()

	if graph_chunk == null or graph_chunk.decoded_payload.size() != XGRP_SIZE:
		return PackedInt32Array()

	var misc: PackedByteArray = misc_chunk.decoded_payload
	var graphs: PackedByteArray = graph_chunk.decoded_payload
	return PackedInt32Array([
		_to_i16(_graph_current(graphs, GRAPH_TRAFFIC)),
		_to_i16(_graph_current(graphs, GRAPH_POLLUTION)),
		_to_i16(_graph_current(graphs, GRAPH_CRIME)),
		_to_i16(BinaryData.read_u32_be(misc, Sc2MiscLayout.UNEMPLOYMENT)),
		_to_i16(_budget_funding(misc, BUDGET_RESIDENTIAL) * 3),
		maxi(100 - _to_i16(BinaryData.read_u32_be(misc, Sc2MiscLayout.WORKFORCE_EDUCATION)), 0),
		maxi(70 - _to_i16(BinaryData.read_u32_be(misc, Sc2MiscLayout.WORKFORCE_LIFE_EXPECTANCY)), 0),
	])


static func _graph_current(data: PackedByteArray, graph_id: int) -> int:
	return BinaryData.read_u32_be(data, graph_id * GRAPH_VALUE_COUNT * 4)


static func _budget_funding(misc: PackedByteArray, budget_id: int) -> int:
	return BinaryData.read_i32_be(
		misc, MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE + BUDGET_FUNDING
	)


static func _to_i16(value: int) -> int:
	var wrapped := value & 0xffff

	return wrapped - 0x10000 if wrapped >= 0x8000 else wrapped
