class_name SimulationDaySchedule
extends RefCounted
# Run SimulationDayPhases in order and keep unfinished actions pending.
# The caller owns the state.


# true when the day's only work was the data-map scan. those maps carry
# pollution, land value, and service coverage, not surface or underground
# artwork, so a caller can skip the map repaint
static func scanned_data_maps_only(day: SimulationDayResult) -> bool:
	var results := day.phase_results

	if results.size() != 1:
		return false

	return results.values()[0] is PollutionPhase.Result


static func _schedule_after(schedule: SimulationSchedule, completed_action: String) -> SimulationSchedule:
	var remaining := schedule.copy()
	remaining.actions = PackedStringArray()
	var found := false

	for action in schedule.actions:
		if found:
			remaining.actions.append(action)
		elif action == completed_action:
			found = true

	return remaining


static func _persist_news_result(engine: SimulationEngine, result: PhaseResult) -> SimulationPhaseContext.NewsPersistenceResult:
	return SimulationPhaseContext.persist_news(engine.city, result)


# run the scheduled actions natively. the engine state crosses in and out
static func _execute_day_schedule(
	engine: SimulationEngine,
	schedule: SimulationSchedule,
	annual_budget_approved: bool,
	span: SimulationTimingSpan,
) -> SimulationDayResult:
	var state := {}

	for field in SimulationPhaseContext.ENGINE_STATE:
		state[field] = engine.get(field)

	var response := NativeSimulationBridge.run("day.schedule", engine.city, engine.random, engine.lfsr_random,
		engine.game_random, {
			"schedule": {
				"city_days": schedule.city_days,
				"month_day": schedule.month_day,
				"season": schedule.season,
				"actions": schedule.actions,
				"growth_step": schedule.growth_step,
				"growth_substep": schedule.growth_substep,
			},
			"annual_budget_approved": annual_budget_approved,
			"engine": state,
			"scenario": ScenarioPhase.fields(engine.scenario) if engine.scenario != null else {},
			"detailed": SimulationTimingSpan.detailed,
		})
	var day: Dictionary = response.result

	for field in SimulationPhaseContext.ENGINE_STATE:
		engine.set(field, day.engine[field])

	if day.scenario_cleared:
		engine.scenario = null
	elif engine.scenario != null and day.scenario_time_limit >= 0:
		engine.scenario.time_limit_months = day.scenario_time_limit

	if not day.ok:
		return SimulationDayResult.failure(day.error)

	span.steps = day.timing.steps
	var interaction_requests: Array[SimulationInteractionRequest] = []

	if not day.interaction.is_empty():
		engine.pending_interaction = day.interaction
		engine.pending_day_schedule = schedule
		interaction_requests.append(SimulationInteractionRequest.military_proposal())

	var outcome := SimulationDayResult.new()
	outcome.ok = true
	outcome.day = engine.clock.city_days
	outcome.schedule = schedule
	outcome.applied = day.applied
	outcome.pending = day.pending
	outcome.phase_results.assign(day.phase_results)
	outcome.interaction_requests = interaction_requests
	outcome.complete = day.pending.is_empty()
	outcome.error = ""

	return outcome
