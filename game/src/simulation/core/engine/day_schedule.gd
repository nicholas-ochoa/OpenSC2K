class_name SimulationDaySchedule
extends RefCounted
# Run SimulationDayPhases in order and keep unfinished actions pending.
# The caller owns the state.


static func _execute_day_schedule(engine: SimulationEngine, schedule: Dictionary, annual_budget_approved: bool, span: SimulationTimingSpan) -> Dictionary:

	var applied := PackedStringArray()
	var pending := PackedStringArray()
	var phases := SimulationDayPhases.table()
	var context := _load_context(engine, schedule, annual_budget_approved, span)

	for action in schedule.actions:
		span.mark(action)

		if engine.city.simulation_slice != null:
			engine.city.simulation_slice.checkpoint()

		var phase: SimulationDayPhase = phases.get(action)

		if phase == null or not phase.is_ready(context):
			pending.append(action)
			continue

		context.action = action
		var result := phase.run(context)

		if result.ok and not result.game_over_events.is_empty():
			context.terminal_state = true

		_store_context(context, engine)

		if not result.ok:
			return {"ok": false, "error": result.error}

		if not context.interaction_request.is_empty():
			engine.pending_interaction = context.interaction_request.type
			engine.pending_day_schedule = schedule
			pending.append(action)
			pending.append_array(engine._schedule_after(schedule, action).actions)

			return _day_result(
				engine, schedule, applied, pending, context, [context.interaction_request]
			)

		if result.complete:
			applied.append(action)
		else:
			pending.append(action)

	return _day_result(engine, schedule, applied, pending, context, [])


static func _day_result(
	engine: SimulationEngine,
	schedule: Dictionary,
	applied: PackedStringArray,
	pending: PackedStringArray,
	context: SimulationPhaseContext,
	interaction_requests: Array
) -> Dictionary:
	return {
		"ok": true,
		"day": engine.clock.city_days,
		"schedule": schedule,
		"applied": applied,
		"pending": pending,
		"phase_results": context.phase_results,
		"interaction_requests": interaction_requests,
		"complete": pending.is_empty(),
		"error": "",
	}


static func _load_context(
	engine: SimulationEngine,
	schedule: Dictionary,
	annual_budget_approved: bool,
	span: SimulationTimingSpan
) -> SimulationPhaseContext:
	var context := SimulationPhaseContext.new()
	context.city = engine.city
	context.random = engine.random
	context.lfsr_random = engine.lfsr_random
	context.game_random = engine.game_random
	context.scenario = engine.scenario
	context.span = span
	context.schedule = schedule
	context.annual_budget_approved = annual_budget_approved

	for field in SimulationPhaseContext.ENGINE_STATE:
		context.set(field, engine.get(field))

	return context


static func _store_context(context: SimulationPhaseContext, engine: SimulationEngine) -> void:
	for field in SimulationPhaseContext.ENGINE_STATE:
		engine.set(field, context.get(field))


# true when the day's only work was the data-map scan. those maps carry
# pollution, land value, and service coverage, not surface or underground
# artwork, so a caller can skip the map repaint
static func scanned_data_maps_only(day: Dictionary) -> bool:
	var results: Dictionary = day.get("phase_results", {})

	if results.size() != 1:
		return false

	return results.values()[0] is PollutionPhase.Result


static func _schedule_after(engine: SimulationEngine, schedule: Dictionary, completed_action: String) -> Dictionary:
	var remaining := schedule.duplicate(true)
	remaining.actions = PackedStringArray()
	var found := false

	for action in schedule.actions:
		if found:
			remaining.actions.append(action)
		elif action == completed_action:
			found = true

	return remaining


static func _persist_news_result(engine: SimulationEngine, result: PhaseResult) -> Dictionary:
	return SimulationPhaseContext.persist_news(engine.city, result)
