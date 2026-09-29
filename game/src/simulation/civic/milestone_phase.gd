class_name MilestonePhase
extends RefCounted

const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_PROGRESSION := Sc2MiscLayout.PROGRESSION
const MISC_GRANTED_REWARDS := Sc2MiscLayout.GRANTED_REWARDS
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION
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


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("milestones", city, null, null, null).result


class Result extends PhaseResult:
	var advanced := false
	var old_progression := 0
	var progression := 0
	var population := 0
	var requirement := 0
	var reward_id := -1
	var military_proposal_pending := false
