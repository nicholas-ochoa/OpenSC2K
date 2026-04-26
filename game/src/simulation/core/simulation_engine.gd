class_name SimulationEngine
extends RefCounted

const DisasterMap = preload("res://src/simulation/disasters/disaster_map_phase.gd")
const RciAftermath = preload("res://src/simulation/growth/rci_aftermath_phase.gd")
const SimNation = preload("res://src/simulation/civic/simnation_phase.gd")
const Industries = preload("res://src/simulation/growth/industry_phase.gd")
const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const WeatherDisaster = preload("res://src/simulation/disasters/weather_disaster_phase.gd")
const Music = preload("res://src/audio/music_director.gd")

var city: CityState
var clock: SimulationClock
var random: SimRandom
var lfsr_random: SimLfsrRandom
var game_random: GameLcgRandom
var ship_home := Vector2i(-1, -1)
var developed_tiles := -1
var power_usage_percent := -1
var water_usage_percent := -1
var city_status_resource_id := -1
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
var midi_playback_active := false


func _init(
	initial_city: CityState, random_seed := 1, lfsr_seed := 1, game_random_seed := 1
) -> void:
	city = initial_city
	clock = SimulationClock.new(initial_city.age_in_days() if initial_city != null else 0)
	random = SimRandom.new(random_seed)
	lfsr_random = SimLfsrRandom.new(lfsr_seed)
	game_random = GameLcgRandom.new(game_random_seed)

	if initial_city != null and initial_city.is_valid():
		midi_playback_active = initial_city.music_enabled()
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

		for record in range(1, city.thing_count()):
			var thing := initial_city.thing(record)

			if thing.get("type", 0) == 3:
				ship_home = Vector2i(thing.x, thing.y)
				break


func advance_moving_things(current_time_msec := -1) -> Dictionary:
	var span := SimulationTimingSpan.new(city.simulation_slice)
	var result := _timed_advance_moving_things(current_time_msec)
	result["timing"] = span.finish()

	return result


func _timed_advance_moving_things(current_time_msec := -1) -> Dictionary:
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

	var queue_update := _persist_news_result(result)

	if not queue_update.ok:
		return queue_update

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
	var span := SimulationTimingSpan.new(city.simulation_slice if city != null else null)
	var result := _timed_advance_day()

	if result.get("ok", false):
		var measured := span.finish()
		var scheduled: Dictionary = result.get("timing", {"work_usec": 0, "steps": {}})
		measured.steps = scheduled.steps
		measured.steps["day setup and events"] = maxi(0, int(measured.work_usec) - int(scheduled.work_usec))
		result["timing"] = measured

	return result


func _timed_advance_day() -> Dictionary:
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
	var span := SimulationTimingSpan.new(city.simulation_slice if city != null else null)
	var result := _timed_resolve_annual_budget(funding_values, auto_budget)

	if result.get("ok", false):
		var measured := span.finish()
		var scheduled: Dictionary = result.get("timing", {"work_usec": 0, "steps": {}})
		measured.steps = scheduled.steps
		measured.steps["day setup and events"] = maxi(0, int(measured.work_usec) - int(scheduled.work_usec))
		result["timing"] = measured

	return result


func _timed_resolve_annual_budget(funding_values: PackedInt32Array, auto_budget: bool) -> Dictionary:
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
	var span := SimulationTimingSpan.new(city.simulation_slice if city != null else null)
	var result := _timed_resolve_military_proposal(accepted)

	if result.get("ok", false):
		var measured := span.finish()
		var scheduled: Dictionary = result.get("timing", {"work_usec": 0, "steps": {}})
		measured.steps = scheduled.steps
		measured.steps["day setup and events"] = maxi(0, int(measured.work_usec) - int(scheduled.work_usec))
		result["timing"] = measured

	return result


func _timed_resolve_military_proposal(accepted: bool) -> Dictionary:
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
	var span := SimulationTimingSpan.new(city.simulation_slice)
	var result := _timed_advance_disaster_tick()
	result["timing"] = span.finish()

	return result


func _timed_advance_disaster_tick() -> Dictionary:
	if active_disaster_type == 0:
		return {"ok": false, "error": "no disaster is active"}

	var phase_result := DisasterMap.run_all(
		city, random, lfsr_random, disaster_map_counter, disaster_hurricane_counter
	)

	if not phase_result.get("ok", false):
		return phase_result

	var queue_update := _persist_news_result(phase_result)

	if not queue_update.ok:
		return queue_update

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

	var started := _start_disaster_phase(disaster_type, point)

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

	var queue_update := _persist_news_result(started)

	if not queue_update.ok:
		return queue_update

	return started


func recalculate_mayor_house() -> Dictionary:
	var result := MayorApprovalPhase.run(city, random, mayor_approval)

	if result.get("ok", false):
		mayor_approval = result.approval
		var queue_update := _persist_news_result(result)

		if not queue_update.ok:
			return queue_update

	return result


func rotate_runtime_coordinates(counter_clockwise: bool) -> void:
	var map_edge: int = city.map_size if city != null else 128

	if ship_home.x >= 0 and ship_home.y >= 0:
		ship_home = _rotate_runtime_point(ship_home, counter_clockwise, map_edge)

	if pending_disaster_type != 0:
		pending_disaster_point = _rotate_runtime_point(
			pending_disaster_point, counter_clockwise, map_edge
		)


static func _rotate_runtime_point(point: Vector2i, counter_clockwise: bool, map_edge: int = 128) -> Vector2i:
	if counter_clockwise:
		return Vector2i(point.y, map_edge - 1 - point.x)

	return Vector2i(map_edge - 1 - point.y, point.x)


func _run_day_schedule(schedule: Dictionary, annual_budget_approved: bool) -> Dictionary:
	var span := SimulationTimingSpan.new(city.simulation_slice)
	var result := _execute_day_schedule(schedule, annual_budget_approved, span)
	result["timing"] = span.finish()

	return result


func _execute_day_schedule(schedule: Dictionary, annual_budget_approved: bool, span: SimulationTimingSpan) -> Dictionary:

	var applied := PackedStringArray()
	var pending := PackedStringArray()
	var phase_results: Dictionary = {}

	for action in schedule.actions:
		span.mark(action)

		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

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

				var budget_news := _persist_news_result(budget)

				if not budget_news.ok:
					return budget_news

				phase_results[action] = budget
				var annual_complete := true

				if budget.settled_year:
					span.mark("annual_microsim")
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

					var annual_news := _persist_news_result(annual_microsim)

					if not annual_news.ok:
						return annual_news

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

				var growth_news := _persist_news_result(growth)

				if not growth_news.ok:
					return growth_news

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
				var playback_was_active := midi_playback_active
				var selected_music := Music.monthly_track(
					city.simulation_speed(), playback_was_active, random
				)
				var music_requests := PackedInt32Array()

				if selected_music >= Music.FIRST_TRACK_ID:
					music_requests.append(selected_music)

					if city.music_enabled():
						midi_playback_active = true

				phase_results["music"] = {
					"ok": true,
					"playback_was_active": playback_was_active,
					"selection_attempted": not playback_was_active,
					"music_track_requests": music_requests,
				}
				var demand := RciDemandPhase.run(city)

				if not demand.ok:
					return {"ok": false, "error": demand.error}

				phase_results[action] = demand
				span.mark("rci_aftermath")
				var aftermath := RciAftermath.run(city, random, int(schedule.season))

				if not aftermath.ok:
					return {"ok": false, "error": aftermath.error}

				var aftermath_news := _persist_news_result(aftermath)

				if not aftermath_news.ok:
					return aftermath_news

				phase_results["rci_aftermath"] = aftermath
				applied.append(action)
			"education_health":
				span.mark("simnation calculation")
				var simnation := SimNation.run(city, random)

				if not simnation.ok:
					return {"ok": false, "error": simnation.error}

				var simnation_news := _persist_news_result(simnation)

				if not simnation_news.ok:
					return simnation_news

				phase_results["simnation"] = simnation
				var demand_result: Dictionary = phase_results.get("rci_demand", {})
				var population_growth := maxi(
					int(demand_result.get("normal_population", 0))
					- int(demand_result.get("previous_population", 0)),
					0
				)
				span.mark("industries")
				var industries := Industries.run(city, random, lfsr_random, population_growth)

				if not industries.ok:
					return {"ok": false, "error": industries.error}

				phase_results["industries"] = industries
				span.mark("education_health")
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

				var milestone_news := _persist_news_result(milestones)

				if not milestone_news.ok:
					return milestone_news

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
			"statistics_windows":
				phase_results[action] = {
					"ok": true,
					"refresh_requests": ["population", "industries", "graphs"],
				}
				applied.append(action)
			"map":
				phase_results[action] = {
					"ok": true,
					"refresh_requests": ["toolbar", "map"],
				}
				applied.append(action)
			"simnation":
				phase_results[action] = {
					"ok": true,
					"refresh_requests": ["simnation"],
				}
				applied.append(action)
			"weather_disaster":
				var weather_disaster := WeatherDisaster.run(
					city,
					random,
					lfsr_random,
					power_usage_percent,
					water_usage_percent,
					commerce_connections,
					industry_connections,
					pending_disaster_point
				)

				if not weather_disaster.ok:
					return {"ok": false, "error": weather_disaster.error}

				var weather_news := _persist_news_result(weather_disaster)

				if not weather_news.ok:
					return weather_news

				city_status_resource_id = CityStatusMessages.monthly_resource(
					int(weather_disaster.status_index), city.weather_type()
				)
				phase_results[action] = weather_disaster

				if int(weather_disaster.disaster_type) != 0:
					pending_disaster_type = int(weather_disaster.disaster_type)
					pending_disaster_point = weather_disaster.disaster_point

				applied.append(action)
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


func _persist_news_result(result: Dictionary) -> Dictionary:
	if result.get("news_queue_updated", false):
		return {"ok": true, "error": "", "inserted": 0}

	var news_items: Array = result.get("news_items", [])

	if news_items.is_empty():
		return {"ok": true, "error": "", "inserted": 0}

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var insertion := NewsQueue.insert_items(misc, news_items)

	if not insertion.ok:
		return insertion

	if insertion.inserted == 0:
		return insertion

	if not misc_chunk.set_decoded_payload(misc):
		return {"ok": false, "error": "cannot store newspaper stories"}

	result["news_queue_updated"] = true
	result["news_queue_inserted"] = insertion.inserted

	return insertion


func _append_pending_disaster(result: Dictionary) -> Dictionary:
	if not result.get("ok", false) or not result.get("interaction_requests", []).is_empty():
		return result

	if pending_disaster_type == 0:
		return result

	var disaster_type := pending_disaster_type
	pending_disaster_type = 0

	if not city.document.set_misc_u32(0x0070, 0):
		return {"ok": false, "error": "cannot clear the pending disaster type"}

	var started := _start_disaster_phase(disaster_type, pending_disaster_point)

	if not started.ok:
		return started

	var queue_update := _persist_news_result(started)

	if not queue_update.ok:
		return queue_update

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


func _start_disaster_phase(disaster_type: int, point: Vector2i) -> Dictionary:
	var started := DisasterStartPhase.start(city, disaster_type, point, random, lfsr_random)
	return MaxisManResponse.apply(city, started, random, lfsr_random)
