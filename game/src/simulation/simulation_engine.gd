class_name SimulationEngine
extends RefCounted

const DisasterMap = preload("res://src/simulation/disaster_map_phase.gd")
const RciAftermath = preload("res://src/simulation/rci_aftermath_phase.gd")
const SimNation = preload("res://src/simulation/simnation_phase.gd")

var city: CityState
var clock: SimulationClock
var random: SimRandom
var lfsr_random: SimLfsrRandom
var game_random: GameLcgRandom
var ship_home := Vector2i(-1, -1)
var developed_tiles := -1
var power_usage_percent := -1
var water_usage_percent := -1
var commerce_connections := 0
var industry_connections := 0
var traffic_news_deadline_msec := 0
var pending_interaction := ""
var pending_day_schedule: Dictionary = {}
var scenario: ScenarioState
var terminal_state := false
var bus_passengers := 0
var rail_passengers := 0
var subway_passengers := 0
var mayor_approval := 0
var pending_disaster_type := 0
var pending_disaster_point := Vector2i.ZERO
var active_disaster_type := 0
var unsupported_disaster_type := 0
var disaster_map_counter := 0
var disaster_hurricane_counter := 0


func _init(
	initial_city: CityState, random_seed := 1, lfsr_seed := 1, game_random_seed := 1
) -> void:
	city = initial_city
	clock = SimulationClock.new(initial_city.age_in_days() if initial_city != null else 0)
	random = SimRandom.new(random_seed)
	lfsr_random = SimLfsrRandom.new(lfsr_seed)
	game_random = GameLcgRandom.new(game_random_seed)
	if initial_city != null and initial_city.is_valid():
		pending_disaster_type = initial_city.disaster_type() & 0xffff
		if initial_city.document.find_chunk("SCEN") != null:
			var loaded_scenario := ScenarioState.from_document(initial_city.document)
			if loaded_scenario.is_valid():
				scenario = loaded_scenario
				pending_disaster_type = scenario.disaster_type
				pending_disaster_point = Vector2i(scenario.disaster_x, scenario.disaster_y)
		var connections := RciDemandPhase.connection_counts(initial_city)
		commerce_connections = connections.commerce
		industry_connections = connections.industry
		for record in range(1, CityState.THING_COUNT):
			var thing := initial_city.thing(record)
			if thing.get("type", 0) == 3:
				ship_home = Vector2i(thing.x, thing.y)
				break


func advance_moving_things(current_time_msec := -1) -> Dictionary:
	if terminal_state:
		return {"ok": false, "error": "the game has ended"}
	if current_time_msec < 0:
		current_time_msec = Time.get_ticks_msec()
	var result := MovingThingPhase.run(
		city,
		random,
		lfsr_random,
		game_random,
		ship_home,
		true,
		current_time_msec,
		traffic_news_deadline_msec
	)
	if not result.get("ok", false):
		return result
	traffic_news_deadline_msec = result.traffic_news_deadline_msec
	for change in result.connection_count_changes:
		if change.kind == "commerce":
			commerce_connections = (commerce_connections + int(change.delta)) & 0xffff
		else:
			industry_connections = (industry_connections + int(change.delta)) & 0xffff
	for request in result.disaster_start_requests:
		pending_disaster_type = int(request.type)
		pending_disaster_point = request.point
	return result


func advance_day() -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not pending_interaction.is_empty():
		return {"ok": false, "error": "%s interaction is pending" % pending_interaction}
	if terminal_state:
		return {"ok": false, "error": "the game has ended"}
	if active_disaster_type != 0:
		return {"ok": false, "error": "a disaster is active"}
	var schedule := clock.advance_day()
	if not city.set_age_in_days(clock.city_days):
		return {"ok": false, "error": "cannot store the new simulation day"}
	if BudgetPhase.requires_annual_budget(city):
		pending_interaction = "annual_budget"
		pending_day_schedule = schedule
		return {
			"ok": true,
			"day": clock.city_days,
			"schedule": schedule,
			"applied": PackedStringArray(),
			"pending": schedule.actions.duplicate(),
			"phase_results": {},
			"interaction_requests": [{
				"type": "annual_budget",
				"funding_values": BudgetPhase.funding_values(city),
				"auto_budget": false,
			}],
			"complete": false,
			"error": "",
		}
	return _append_pending_disaster(_run_day_schedule(schedule, false))


func resolve_annual_budget(funding_values: PackedInt32Array, auto_budget: bool) -> Dictionary:
	if pending_interaction != "annual_budget" or pending_day_schedule.is_empty():
		return {"ok": false, "error": "no annual budget interaction is pending"}
	var stored := BudgetPhase.set_funding(city, funding_values, auto_budget)
	if not stored.ok:
		return stored
	var result := _run_day_schedule(pending_day_schedule, true)
	if result.get("ok", false):
		pending_interaction = ""
		pending_day_schedule = {}
	return _append_pending_disaster(result)


func resolve_military_proposal(accepted: bool) -> Dictionary:
	if pending_interaction != "military_proposal" or pending_day_schedule.is_empty():
		return {"ok": false, "error": "no military proposal interaction is pending"}
	var proposal := MilitaryProposalPhase.resolve(city, accepted, game_random)
	if not proposal.ok:
		return proposal
	var original_schedule: Dictionary = pending_day_schedule
	var remaining_schedule := _schedule_after(original_schedule, "milestones")
	pending_interaction = ""
	pending_day_schedule = {}
	var result := _run_day_schedule(remaining_schedule, false)
	if not result.get("ok", false):
		return result
	var applied := PackedStringArray(["milestones"])
	applied.append_array(result.applied)
	var phase_results := {"military_proposal": proposal}
	for phase_name in result.phase_results:
		phase_results[phase_name] = result.phase_results[phase_name]
	result.schedule = original_schedule
	result.applied = applied
	result.phase_results = phase_results
	return _append_pending_disaster(result)


func advance_disaster_tick() -> Dictionary:
	if active_disaster_type == 0:
		return {"ok": false, "error": "no disaster is active"}
	var phase_result := DisasterMap.run_all(
		city, random, lfsr_random, disaster_map_counter, disaster_hurricane_counter
	)
	if not phase_result.get("ok", false):
		return phase_result
	disaster_map_counter = int(phase_result.get("map_counter", disaster_map_counter))
	disaster_hurricane_counter = int(
		phase_result.get("hurricane_counter", disaster_hurricane_counter)
	)
	var still_active: bool = bool(phase_result.active) or DisasterStartPhase.has_active_object(
		city, active_disaster_type
	)
	var ended_type := 0
	if not still_active:
		ended_type = active_disaster_type
		active_disaster_type = 0
		disaster_map_counter = 0
		disaster_hurricane_counter = 0
		if not city.document.set_misc_u32(0x0004, 1):
			return {"ok": false, "error": "cannot restore city mode after the disaster"}
	phase_result["active"] = still_active
	phase_result["disaster_type"] = active_disaster_type if still_active else ended_type
	phase_result["ended_type"] = ended_type
	phase_result["complete"] = not still_active
	return phase_result


func start_disaster(disaster_type: int, point: Vector2i) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if terminal_state:
		return {"ok": false, "error": "the game has ended"}
	if not pending_interaction.is_empty():
		return {"ok": false, "error": "%s interaction is pending" % pending_interaction}
	if active_disaster_type != 0:
		return {"ok": false, "error": "a disaster is already active"}
	var started := DisasterStartPhase.start(city, disaster_type, point, random, lfsr_random)
	if not started.get("ok", false):
		return started
	if not started.get("started", false):
		if not started.get("complete", false):
			unsupported_disaster_type = disaster_type
		return started
	active_disaster_type = disaster_type
	disaster_map_counter = int(started.get("map_counter", 0))
	disaster_hurricane_counter = int(started.get("hurricane_counter", 0))
	unsupported_disaster_type = 0
	if not city.document.set_misc_u32(0x0004, 2):
		active_disaster_type = 0
		disaster_map_counter = 0
		disaster_hurricane_counter = 0
		return {"ok": false, "error": "cannot store active disaster mode"}
	return started


func recalculate_mayor_house() -> Dictionary:
	var result := MayorApprovalPhase.run(city, random, mayor_approval)
	if result.get("ok", false):
		mayor_approval = result.approval
	return result


func rotate_runtime_coordinates(counter_clockwise: bool) -> void:
	if ship_home.x >= 0 and ship_home.y >= 0:
		ship_home = _rotate_runtime_point(ship_home, counter_clockwise)
	if pending_disaster_type != 0:
		pending_disaster_point = _rotate_runtime_point(
			pending_disaster_point, counter_clockwise
		)


static func _rotate_runtime_point(point: Vector2i, counter_clockwise: bool) -> Vector2i:
	if counter_clockwise:
		return Vector2i(point.y, CityState.MAP_SIZE - 1 - point.x)
	return Vector2i(CityState.MAP_SIZE - 1 - point.y, point.x)


func _run_day_schedule(schedule: Dictionary, annual_budget_approved: bool) -> Dictionary:

	var applied := PackedStringArray()
	var pending := PackedStringArray()
	var phase_results: Dictionary = {}
	for action in schedule.actions:
		match action:
			"month_start":
				var month_start := MonthStartPhase.run(city)
				if not month_start.ok:
					return {"ok": false, "error": month_start.error}
				phase_results[action] = month_start
				applied.append(action)
			"budget":
				var budget := BudgetPhase.run(city, random, annual_budget_approved)
				if not budget.ok:
					return {"ok": false, "error": budget.error}
				phase_results[action] = budget
				var annual_complete := true
				if budget.settled_year:
					var annual_microsim := MicrosimAnnualPhase.run(
						city,
						bus_passengers,
						rail_passengers,
						subway_passengers,
						random,
						lfsr_random,
						game_random,
						power_usage_percent,
						water_usage_percent,
						false,
						mayor_approval
					)
					if not annual_microsim.ok:
						return {"ok": false, "error": annual_microsim.error}
					phase_results["annual_microsim"] = annual_microsim
					annual_complete = annual_microsim.complete
					bus_passengers = 0
					rail_passengers = 0
					subway_passengers = 0
				if (budget.complete or budget.settled_year) and annual_complete:
					applied.append(action)
				else:
					pending.append(action)
			"power":
				var power := PowerPhase.run(city, random)
				if not power.ok:
					return {"ok": false, "error": power.error}
				phase_results[action] = power
				power_usage_percent = power.usage_percent
				applied.append(action)
			"growth":
				var growth := GrowthPhase.run(
					city,
					random,
					schedule.growth_step,
					schedule.growth_substep,
					lfsr_random,
					game_random
				)
				if not growth.ok:
					return {"ok": false, "error": growth.error}
				phase_results[action] = growth
				bus_passengers = (bus_passengers + int(growth.bus_passengers)) & 0xffffffff
				rail_passengers = (rail_passengers + int(growth.rail_passengers)) & 0xffffffff
				subway_passengers = (subway_passengers + int(growth.subway_passengers)) & 0xffffffff
				if growth.has("ship_home"):
					ship_home = growth.ship_home
				if growth.complete:
					applied.append(action)
				else:
					pending.append(action)
			"pollution_terrain_land_value":
				var scan := PollutionPhase.run(city)
				if not scan.ok:
					return {"ok": false, "error": scan.error}
				phase_results[action] = scan
				developed_tiles = scan.developed_tiles
				applied.append(action)
			"water":
				var water := WaterPhase.run(city)
				if not water.ok:
					return {"ok": false, "error": water.error}
				phase_results[action] = water
				water_usage_percent = water.usage_percent
				applied.append(action)
			"traffic":
				var traffic := TrafficPhase.run(city)
				if not traffic.ok:
					return {"ok": false, "error": traffic.error}
				phase_results[action] = traffic
				applied.append(action)
			"rci_demand":
				var demand := RciDemandPhase.run(city)
				if not demand.ok:
					return {"ok": false, "error": demand.error}
				phase_results[action] = demand
				var aftermath := RciAftermath.run(city, random, int(schedule.season))
				if not aftermath.ok:
					return {"ok": false, "error": aftermath.error}
				phase_results["rci_aftermath"] = aftermath
				applied.append(action)
			"education_health":
				var simnation := SimNation.run(city, random)
				if not simnation.ok:
					return {"ok": false, "error": simnation.error}
				phase_results["simnation"] = simnation
				var demographics := EducationHealthPhase.run(city, random)
				if not demographics.ok:
					return {"ok": false, "error": demographics.error}
				phase_results[action] = demographics
				applied.append(action)
			"graphs":
				if developed_tiles < 0 or power_usage_percent < 0 or water_usage_percent < 0:
					pending.append(action)
					continue
				var graphs := GraphHistory.run(
					city, developed_tiles, power_usage_percent, water_usage_percent
				)
				if not graphs.ok:
					return {"ok": false, "error": graphs.error}
				phase_results[action] = graphs
				applied.append(action)
			"milestones":
				var milestones := MilestonePhase.run(city)
				if not milestones.ok:
					return {"ok": false, "error": milestones.error}
				phase_results[action] = milestones
				if milestones.military_proposal_pending:
					pending_interaction = "military_proposal"
					pending_day_schedule = schedule
					pending.append(action)
					var remaining_schedule := _schedule_after(schedule, action)
					pending.append_array(remaining_schedule.actions)
					return {
						"ok": true,
						"day": clock.city_days,
						"schedule": schedule,
						"applied": applied,
						"pending": pending,
						"phase_results": phase_results,
						"interaction_requests": [{
							"type": "military_proposal",
							"notification_id": 0xf0,
						}],
						"complete": false,
						"error": "",
					}
				applied.append(action)
			"scenario":
				var scenario_check := ScenarioPhase.run(scenario, city)
				if not scenario_check.ok:
					return {"ok": false, "error": scenario_check.error}
				phase_results[action] = scenario_check
				applied.append(action)
				if not scenario_check.game_over_events.is_empty():
					terminal_state = true
			"bankruptcy":
				var bankruptcy := BankruptcyPhase.run(city)
				if not bankruptcy.ok:
					return {"ok": false, "error": bankruptcy.error}
				phase_results[action] = bankruptcy
				applied.append(action)
				if not bankruptcy.game_over_events.is_empty():
					terminal_state = true
			_:
				pending.append(action)
	return {
		"ok": true,
		"day": clock.city_days,
		"schedule": schedule,
		"applied": applied,
		"pending": pending,
		"phase_results": phase_results,
		"interaction_requests": [],
		"complete": pending.is_empty(),
		"error": "",
	}


func _schedule_after(schedule: Dictionary, completed_action: String) -> Dictionary:
	var remaining := schedule.duplicate(true)
	remaining.actions = PackedStringArray()
	var found := false
	for action in schedule.actions:
		if found:
			remaining.actions.append(action)
		elif action == completed_action:
			found = true
	return remaining


func _append_pending_disaster(result: Dictionary) -> Dictionary:
	if not result.get("ok", false) or not result.get("interaction_requests", []).is_empty():
		return result
	if pending_disaster_type == 0:
		return result
	var disaster_type := pending_disaster_type
	pending_disaster_type = 0
	if not city.document.set_misc_u32(0x0070, 0):
		return {"ok": false, "error": "cannot clear the pending disaster type"}
	var started := DisasterStartPhase.start(
		city, disaster_type, pending_disaster_point, random, lfsr_random
	)
	if not started.ok:
		return started
	result.phase_results["disaster_start"] = started
	if started.started:
		active_disaster_type = disaster_type
		disaster_map_counter = int(started.get("map_counter", 0))
		disaster_hurricane_counter = int(started.get("hurricane_counter", 0))
		if not city.document.set_misc_u32(0x0004, 2):
			return {"ok": false, "error": "cannot store active disaster mode"}
		result.applied.append("disaster_start")
	elif not started.complete:
		unsupported_disaster_type = disaster_type
		result.pending.append("disaster_start")
		result.complete = false
	return result
