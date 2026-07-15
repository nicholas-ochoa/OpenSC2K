class_name SimulationDaySchedule
extends RefCounted
# Run daily phases and save their news. The caller owns the state.


static func _execute_day_schedule(engine: SimulationEngine, schedule: Dictionary, annual_budget_approved: bool, span: SimulationTimingSpan) -> Dictionary:

	var applied := PackedStringArray()
	var pending := PackedStringArray()
	var phase_results: Dictionary = {}

	for action in schedule.actions:
		span.mark(action)

		if engine.city.simulation_slice != null:
			engine.city.simulation_slice.checkpoint()

		match action:
			"month_start":
				var month_start := MonthStartPhase.run(engine.city)

				if not month_start.ok:
					return {"ok": false, "error": month_start.error}

				phase_results[action] = month_start
				applied.append(action)
			"budget":
				var budget := BudgetPhase.run(engine.city, engine.random, annual_budget_approved)

				if not budget.ok:
					return {"ok": false, "error": budget.error}

				var budget_news := engine._persist_news_result(budget)

				if not budget_news.ok:
					return budget_news

				phase_results[action] = budget
				var annual_complete := true

				if budget.settled_year:
					span.mark("annual_microsim")
					var annual_microsim := MicrosimAnnualPhase.run(
						engine.city,
						engine.bus_passengers,
						engine.rail_passengers,
						engine.subway_passengers,
						engine.random,
						engine.lfsr_random,
						engine.game_random,
						engine.power_usage_percent,
						engine.water_usage_percent,
						false,
						engine.mayor_approval
					)

					if not annual_microsim.ok:
						return {"ok": false, "error": annual_microsim.error}

					var annual_news := engine._persist_news_result(annual_microsim)

					if not annual_news.ok:
						return annual_news

					phase_results["annual_microsim"] = annual_microsim
					annual_complete = annual_microsim.complete
					engine.bus_passengers = 0
					engine.rail_passengers = 0
					engine.subway_passengers = 0

				if (budget.complete or budget.settled_year) and annual_complete:
					applied.append(action)
				else:
					pending.append(action)
			"power":
				var power := PowerPhase.run(engine.city, engine.random)

				if not power.ok:
					return {"ok": false, "error": power.error}

				phase_results[action] = power
				engine.power_usage_percent = power.usage_percent
				applied.append(action)
			"growth":
				var growth := GrowthPhase.run(
					engine.city,
					engine.random,
					schedule.growth_step,
					schedule.growth_substep,
					engine.lfsr_random,
					engine.game_random
				)

				if not growth.ok:
					return {"ok": false, "error": growth.error}

				var growth_news := engine._persist_news_result(growth)

				if not growth_news.ok:
					return growth_news

				phase_results[action] = growth
				engine.bus_passengers = (engine.bus_passengers + growth.bus_passengers) & 0xffffffff
				engine.rail_passengers = (engine.rail_passengers + growth.rail_passengers) & 0xffffffff
				engine.subway_passengers = (engine.subway_passengers + growth.subway_passengers) & 0xffffffff

				if growth.ship_home_found:
					engine.ship_home = growth.ship_home

				if growth.complete:
					applied.append(action)
				else:
					pending.append(action)
			"pollution_terrain_land_value":
				var scan := PollutionPhase.run(engine.city)

				if not scan.ok:
					return {"ok": false, "error": scan.error}

				phase_results[action] = scan
				engine.developed_tiles = scan.developed_tiles
				applied.append(action)
			"water":
				var water := WaterPhase.run(engine.city)

				if not water.ok:
					return {"ok": false, "error": water.error}

				phase_results[action] = water
				engine.water_usage_percent = water.usage_percent
				applied.append(action)
			"traffic":
				var traffic := TrafficPhase.run(engine.city)

				if not traffic.ok:
					return {"ok": false, "error": traffic.error}

				phase_results[action] = traffic
				applied.append(action)
			"rci_demand":
				var playback_was_active := engine.midi_playback_active
				var selected_music := SimulationEngine.Music.monthly_track(
					engine.city.simulation_speed(), playback_was_active, engine.random
				)
				var music_requests := PackedInt32Array()

				if selected_music >= SimulationEngine.Music.FIRST_TRACK_ID:
					music_requests.append(selected_music)

					if engine.city.music_enabled():
						engine.midi_playback_active = true

				phase_results["music"] = MonthlyMusicResult.selected(
					playback_was_active, music_requests
				)
				var demand := RciDemandPhase.run(engine.city)

				if not demand.ok:
					return {"ok": false, "error": demand.error}

				phase_results[action] = demand
				span.mark("rci_aftermath")
				var aftermath := SimulationEngine.RciAftermath.run(
					engine.city, engine.random, int(schedule.season)
				)

				if not aftermath.ok:
					return {"ok": false, "error": aftermath.error}

				var aftermath_news := engine._persist_news_result(aftermath)

				if not aftermath_news.ok:
					return aftermath_news

				phase_results["rci_aftermath"] = aftermath
				applied.append(action)
			"education_health":
				span.mark("simnation calculation")
				var simnation := SimulationEngine.SimNation.run(engine.city, engine.random)

				if not simnation.ok:
					return {"ok": false, "error": simnation.error}

				var simnation_news := engine._persist_news_result(simnation)

				if not simnation_news.ok:
					return simnation_news

				phase_results["simnation"] = simnation
				var demand_result: RciDemandPhase.Result = phase_results.get(
					"rci_demand", RciDemandPhase.Result.new()
				)
				var population_growth := maxi(
					demand_result.normal_population - demand_result.previous_population, 0
				)
				span.mark("industries")
				var industries := SimulationEngine.Industries.run(
					engine.city, engine.random, engine.lfsr_random, population_growth
				)

				if not industries.ok:
					return {"ok": false, "error": industries.error}

				phase_results["industries"] = industries
				span.mark("education_health")
				var demographics := EducationHealthPhase.run(engine.city, engine.random)

				if not demographics.ok:
					return {"ok": false, "error": demographics.error}

				phase_results[action] = demographics
				applied.append(action)
			"graphs":
				if engine.developed_tiles < 0 or engine.power_usage_percent < 0 or engine.water_usage_percent < 0:
					pending.append(action)
					continue

				var graphs := GraphHistory.run(
					engine.city, engine.developed_tiles, engine.power_usage_percent, engine.water_usage_percent
				)

				if not graphs.ok:
					return {"ok": false, "error": graphs.error}

				phase_results[action] = graphs
				applied.append(action)
			"milestones":
				var milestones := MilestonePhase.run(engine.city)

				if not milestones.ok:
					return {"ok": false, "error": milestones.error}

				var milestone_news := engine._persist_news_result(milestones)

				if not milestone_news.ok:
					return milestone_news

				phase_results[action] = milestones

				if milestones.military_proposal_pending:
					engine.pending_interaction = "military_proposal"
					engine.pending_day_schedule = schedule
					pending.append(action)
					var remaining_schedule := engine._schedule_after(schedule, action)
					pending.append_array(remaining_schedule.actions)

					return {
						"ok": true,
						"day": engine.clock.city_days,
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
				var scenario_check := ScenarioPhase.run(engine.scenario, engine.city)

				if not scenario_check.ok:
					return {"ok": false, "error": scenario_check.error}

				phase_results[action] = scenario_check
				applied.append(action)

				if not scenario_check.game_over_events.is_empty():
					engine.terminal_state = true
			"bankruptcy":
				var bankruptcy := BankruptcyPhase.run(engine.city)

				if not bankruptcy.ok:
					return {"ok": false, "error": bankruptcy.error}

				phase_results[action] = bankruptcy
				applied.append(action)

				if not bankruptcy.game_over_events.is_empty():
					engine.terminal_state = true
			"statistics_windows":
				phase_results[action] = PhaseResult.refreshing(["population", "industries", "graphs"])
				applied.append(action)
			"map":
				phase_results[action] = PhaseResult.refreshing(["toolbar", "map"])
				applied.append(action)
			"simnation":
				phase_results[action] = PhaseResult.refreshing(["simnation"])
				applied.append(action)
			"weather_disaster":
				var weather_disaster := SimulationEngine.WeatherDisaster.run(
					engine.city,
					engine.random,
					engine.lfsr_random,
					engine.power_usage_percent,
					engine.water_usage_percent,
					engine.commerce_connections,
					engine.industry_connections,
					engine.pending_disaster_point
				)

				if not weather_disaster.ok:
					return {"ok": false, "error": weather_disaster.error}

				var weather_news := engine._persist_news_result(weather_disaster)

				if not weather_news.ok:
					return weather_news

				engine.city_status_resource_id = CityStatusMessages.monthly_resource(
					weather_disaster.status_index, engine.city.weather_type()
				)
				phase_results[action] = weather_disaster

				if weather_disaster.disaster_type != 0:
					engine.pending_disaster_type = weather_disaster.disaster_type
					engine.pending_disaster_point = weather_disaster.disaster_point

				applied.append(action)
			_:
				pending.append(action)

	return {
		"ok": true,
		"day": engine.clock.city_days,
		"schedule": schedule,
		"applied": applied,
		"pending": pending,
		"phase_results": phase_results,
		"interaction_requests": [],
		"complete": pending.is_empty(),
		"error": "",
	}


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
	if result.news_queue_updated:
		return {"ok": true, "error": "", "inserted": 0}

	if result.news_items.is_empty():
		return {"ok": true, "error": "", "inserted": 0}

	var misc_chunk := engine.city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != SimulationEngine.NewsQueue.MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var insertion := SimulationEngine.NewsQueue.insert_items(misc, result.news_items)

	if not insertion.ok:
		return insertion

	if insertion.inserted == 0:
		return insertion

	if not misc_chunk.set_decoded_payload(misc):
		return {"ok": false, "error": "cannot store newspaper stories"}

	result.news_queue_updated = true
	result.news_queue_inserted = insertion.inserted

	return insertion
