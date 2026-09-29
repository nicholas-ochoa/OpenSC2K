class_name MayorApprovalPhase
extends RefCounted


@warning_ignore_start("integer_division")

const MISC_SIZE := Sc2MiscLayout.SIZE
const XGRP_SIZE := Sc2GraphLayout.SIZE
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION
const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const BUDGET_FUNDING := Sc2BudgetLayout.FUNDING
const BUDGET_RESIDENTIAL := Sc2BudgetLayout.RESIDENTIAL
const GRAPH_TRAFFIC := 4
const GRAPH_POLLUTION := 5
const GRAPH_CRIME := 7
const GRAPH_VALUE_COUNT := Sc2GraphLayout.VALUES_PER_SERIES


static func failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

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
	return BinaryData.read_u32_be(data, graph_id * GRAPH_VALUE_COUNT * Sc2GraphLayout.VALUE_SIZE)


static func _budget_funding(misc: PackedByteArray, budget_id: int) -> int:
	return BinaryData.read_i32_be(
		misc, MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE + BUDGET_FUNDING
	)


static func _to_i16(value: int) -> int:
	var wrapped := value & 0xffff

	return wrapped - 0x10000 if wrapped >= 0x8000 else wrapped


static func run(city: CityState, random: SimRandom, previous_approval: int) -> Result:
	if city == null or not city.is_valid():
		return failed("city is invalid")

	if random == null:
		return failed("a compatible random generator is required")

	return NativeSimulationBridge.run("mayor_approval", city, random, null, null, {
		"previous_approval": previous_approval,
	}).result


class Result extends PhaseResult:
	var approval := 0
	var previous_approval := 0
	var weights := PackedInt32Array()
	var survey_counts := PackedInt32Array()
	var ranking := PackedInt32Array()
	var updated_mayor_house_records := 0
