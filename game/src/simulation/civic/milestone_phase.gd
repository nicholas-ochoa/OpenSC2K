class_name MilestonePhase
extends RefCounted

const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")

const MISC_SIZE := 4800
const MISC_PROGRESSION := 0x0020
const MISC_GRANTED_REWARDS := 0x0078
const MISC_NORMAL_POPULATION := 0x102c

const NEWS_GROWTH := 3
const PROGRESSION_REQUIREMENTS := [
	2000,
	10000,
	30000,
	60000,
	90000,
	120000,
	500000,
	1000000,
	5000000,
	10000000,
]


class Result extends PhaseResult:
	var advanced := false
	var old_progression := 0
	var progression := 0
	var population := 0
	var requirement := 0
	var reward_id := -1
	var military_proposal_pending := false


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return _failed("MISC is missing or has the wrong size")

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var progression := _read_u32(misc, MISC_PROGRESSION) & 0xffff
	var population := _read_u32(misc, MISC_NORMAL_POPULATION)

	if progression >= PROGRESSION_REQUIREMENTS.size():
		return _unchanged_result(progression, population)

	var requirement := int(PROGRESSION_REQUIREMENTS[progression])

	if population <= requirement:
		return _unchanged_result(progression, population, requirement)

	var old_progression := progression
	progression += 1
	_write_u32(misc, MISC_PROGRESSION, progression)
	var reward_id := -1
	var military_proposal_pending := false

	if progression < 4:
		reward_id = progression - 1
	elif progression == 4:
		military_proposal_pending = true
	elif progression == 5:
		reward_id = 3

	if reward_id >= 0:
		_write_u32(
			misc,
			MISC_GRANTED_REWARDS,
			_read_u32(misc, MISC_GRANTED_REWARDS) | (1 << reward_id)
		)

	ToolAvailability.rebuild_reward_mask(misc)

	if not misc_chunk.set_decoded_payload(misc):
		return _failed("cannot store milestone state")

	var result := Result.new()
	result.ok = true
	result.advanced = true
	result.old_progression = old_progression
	result.progression = progression
	result.population = population
	result.requirement = requirement
	result.reward_id = reward_id
	result.military_proposal_pending = military_proposal_pending
	result.news_items = [NewsEvent.new(NEWS_GROWTH, old_progression)]
	result.complete = not military_proposal_pending

	return result


static func _unchanged_result(
	progression: int, population: int, requirement := 0
) -> Result:
	var result := Result.new()
	result.ok = true
	result.old_progression = progression
	result.progression = progression
	result.population = population
	result.requirement = requirement

	return result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff
