class_name ScenarioPhase
extends RefCounted


class Result extends PhaseResult:
	var active := false
	var outcome := ""
	var remaining_months := 0
	var unmet := PackedStringArray()


static func run(scenario: ScenarioState, city: CityState) -> Result:
	if scenario == null:
		var inactive := Result.new()
		inactive.ok = true

		return inactive

	if not scenario.is_valid():
		return _failed("scenario is invalid")

	var goals := scenario.evaluate_goals(city)

	if not goals.ok:
		return _failed(goals.error)

	if goals.met:
		var victory := Result.new()
		victory.ok = true
		victory.active = true
		victory.outcome = "victory"
		victory.remaining_months = scenario.time_limit_months
		victory.unmet = goals.unmet
		victory.game_over_events = [GameOverEvent.new("scenario_victory")]

		return victory

	var remaining := (scenario.time_limit_months - 1) & 0xffff

	if not scenario.set_time_limit_months(remaining):
		return _failed("cannot store the scenario time limit")

	var outcome := "failure" if remaining == 0 else ""
	var events: Array[GameOverEvent] = []

	if outcome == "failure":
		events.append(GameOverEvent.new("scenario_failure"))

	var result := Result.new()
	result.ok = true
	result.active = true
	result.outcome = outcome
	result.remaining_months = remaining
	result.unmet = goals.unmet
	result.game_over_events = events

	return result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result
