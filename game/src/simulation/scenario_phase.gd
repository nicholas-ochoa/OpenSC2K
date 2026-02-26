class_name ScenarioPhase
extends RefCounted


static func run(scenario: ScenarioState, city: CityState) -> Dictionary:
	if scenario == null:
		return {
			"ok": true,
			"error": "",
			"active": false,
			"outcome": "",
			"remaining_months": 0,
			"unmet": PackedStringArray(),
			"game_over_events": [],
			"complete": true,
		}

	if not scenario.is_valid():
		return {"ok": false, "error": "scenario is invalid"}

	var goals := scenario.evaluate_goals(city)

	if not goals.ok:
		return goals

	if goals.met:
		return {
			"ok": true,
			"error": "",
			"active": true,
			"outcome": "victory",
			"remaining_months": scenario.time_limit_months,
			"unmet": goals.unmet,
			"game_over_events": [{"type": "scenario_victory"}],
			"complete": true,
		}

	var remaining := (scenario.time_limit_months - 1) & 0xffff

	if not scenario.set_time_limit_months(remaining):
		return {"ok": false, "error": "cannot store the scenario time limit"}

	var outcome := "failure" if remaining == 0 else ""
	var events: Array[Dictionary] = []

	if outcome == "failure":
		events.append({"type": "scenario_failure"})

	return {
		"ok": true,
		"error": "",
		"active": true,
		"outcome": outcome,
		"remaining_months": remaining,
		"unmet": goals.unmet,
		"game_over_events": events,
		"complete": true,
	}
