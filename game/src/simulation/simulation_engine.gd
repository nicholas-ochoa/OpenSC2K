class_name SimulationEngine
extends RefCounted

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


func _init(
	initial_city: CityState, random_seed := 1, lfsr_seed := 1, game_random_seed := 1
) -> void:
	city = initial_city
	clock = SimulationClock.new(initial_city.age_in_days() if initial_city != null else 0)
	random = SimRandom.new(random_seed)
	lfsr_random = SimLfsrRandom.new(lfsr_seed)
	game_random = GameLcgRandom.new(game_random_seed)
	if initial_city != null and initial_city.is_valid():
		if initial_city.document.find_chunk("SCEN") != null:
			var loaded_scenario := ScenarioState.from_document(initial_city.document)
			if loaded_scenario.is_valid():
				scenario = loaded_scenario
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
	return result


func advance_day() -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not pending_interaction.is_empty():
		return {"ok": false, "error": "%s interaction is pending" % pending_interaction}
	if terminal_state:
		return {"ok": false, "error": "the game has ended"}
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
	return _run_day_schedule(schedule, false)


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
	return result


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
						water_usage_percent
					)
					if not annual_microsim.ok:
						return {"ok": false, "error": annual_microsim.error}
					phase_results["annual_microsim"] = annual_microsim
					bus_passengers = 0
					rail_passengers = 0
					subway_passengers = 0
				if budget.complete:
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
				applied.append(action)
			"education_health":
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
				if milestones.complete:
					applied.append(action)
				else:
					pending.append(action)
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
