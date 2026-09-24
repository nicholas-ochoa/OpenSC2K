class_name SimulationDayPhases
extends RefCounted
# Pairs scheduled action names with phases. Add new actions here and
# in simulation_clock.gd.


# built once on load. the phases hold no mutable state, so the simulation
# worker and the main thread can share them
static var _table: Dictionary[String, SimulationDayPhase] = _build_table()


# the action name that `SimulationClock` emits, and the phase that runs it
static func table() -> Dictionary[String, SimulationDayPhase]:
	return _table


static func _build_table() -> Dictionary[String, SimulationDayPhase]:
	return {
		"month_start": MonthStart.new(),
		"budget": Budget.new(),
		"power": Power.new(),
		"growth": Growth.new(),
		"pollution_terrain_land_value": DataMaps.new(),
		"water": Water.new(),
		"traffic": Traffic.new(),
		"rci_demand": RciDemand.new(),
		"education_health": EducationHealth.new(),
		"graphs": Graphs.new(),
		"milestones": Milestones.new(),
		"scenario": Scenario.new(),
		"bankruptcy": Bankruptcy.new(),
		"statistics_windows": Refresh.new(["population", "industries", "graphs"]),
		"map": Refresh.new(["toolbar", "map"]),
		"simnation": Refresh.new(["simnation"]),
		"weather_disaster": WeatherDisaster.new(),
	}


class MonthStart extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var month_start := MonthStartPhase.run(context.city)

		if not month_start.ok:
			return month_start

		return context.record(context.action, month_start)


# the original settles the year, runs the annual facility update, and then
# does the monthly budget work. the annual update can change funds and the
# arcology population that the monthly work reads
class Budget extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var settlement := BudgetPhase.settle_year(context.city, context.annual_budget_approved)

		if not settlement.ok:
			return settlement

		if settlement.requires_annual_budget:
			return context.record(context.action, settlement)

		var annual: MicrosimAnnualPhase.Result

		if settlement.settled_year:
			context.span.mark("annual_microsim")
			_measure_unknown_utilities(context)
			annual = MicrosimAnnualPhase.run(
				context.city,
				context.bus_passengers,
				context.rail_passengers,
				context.subway_passengers,
				context.random,
				context.lfsr_random,
				context.game_random,
				context.power_usage_percent,
				context.water_usage_percent,
				false,
				context.mayor_approval
			)

			if not annual.ok:
				return annual

			var stored_annual := context.record("annual_microsim", annual)

			if not stored_annual.ok:
				return stored_annual

			context.bus_passengers = 0
			context.rail_passengers = 0
			context.subway_passengers = 0
			context.span.mark(context.action)

		var budget := BudgetPhase.run_month(context.city, context.random, settlement)

		if not budget.ok:
			return budget

		var stored := context.record(context.action, budget)

		if not stored.ok:
			return stored

		# a completed annual update completes the budget action
		budget.complete = annual == null or annual.complete

		return budget

	# the original scans power and then water when it loads a city. after a
	# load, the engine has no value until the first scheduled scan. scan a copy
	# here so that the annual update does not change the city or its random state
	func _measure_unknown_utilities(context: SimulationPhaseContext) -> void:
		if context.power_usage_percent >= 0 and context.water_usage_percent >= 0:
			return

		var copy := CityState.copy_for_edit(context.city)
		copy.simulation_slice = context.city.simulation_slice

		if context.power_usage_percent < 0:
			var power := PowerPhase.run(copy, SimRandom.new(context.random.state))

			if power.ok:
				context.power_usage_percent = power.usage_percent

		if context.water_usage_percent < 0:
			var water := WaterPhase.run(copy)

			if water.ok:
				context.water_usage_percent = water.usage_percent


class Power extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var power := PowerPhase.run(context.city, context.random)

		if not power.ok:
			return power

		var stored := context.record(context.action, power)

		if not stored.ok:
			return stored

		context.power_usage_percent = power.usage_percent

		return power


class Growth extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var growth := GrowthScan.run(
			context.city,
			context.random,
			context.schedule.growth_step,
			context.schedule.growth_substep,
			context.lfsr_random,
			context.game_random
		)

		if not growth.ok:
			return growth

		var stored := context.record(context.action, growth)

		if not stored.ok:
			return stored

		context.bus_passengers = (context.bus_passengers + growth.bus_passengers) & 0xffffffff
		context.rail_passengers = (context.rail_passengers + growth.rail_passengers) & 0xffffffff
		context.subway_passengers = (context.subway_passengers + growth.subway_passengers) & 0xffffffff

		if growth.ship_home_found:
			context.ship_home = growth.ship_home

		if growth.spawned_helicopters > 0:
			context.traffic_news_deadline_msec = 0

		return growth


class DataMaps extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var scan := PollutionPhase.run(context.city)

		if not scan.ok:
			return scan

		var stored := context.record(context.action, scan)

		if not stored.ok:
			return stored

		context.developed_tiles = scan.developed_tiles

		return scan


class Water extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var water := WaterPhase.run(context.city)

		if not water.ok:
			return water

		var stored := context.record(context.action, water)

		if not stored.ok:
			return stored

		context.water_usage_percent = water.usage_percent

		return water


class Traffic extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var traffic := TrafficPhase.run(context.city)

		if not traffic.ok:
			return traffic

		return context.record(context.action, traffic)


class RciDemand extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var playback_was_active := context.midi_playback_active
		var selected := MusicDirector.monthly_track(
			context.city.simulation_speed(), playback_was_active, context.random
		)
		var requests := PackedInt32Array()

		if selected >= MusicDirector.FIRST_TRACK_ID:
			requests.append(selected)

			if context.city.music_enabled():
				context.midi_playback_active = true

		var music := context.record(
			"music", MonthlyMusicResult.selected(playback_was_active, requests)
		)

		if not music.ok:
			return music

		var demand := RciDemandPhase.run(context.city)

		if not demand.ok:
			return demand

		var stored := context.record(context.action, demand)

		if not stored.ok:
			return stored

		context.span.mark("rci_aftermath")
		var aftermath := RciAftermathPhase.run(
			context.city, context.random, int(context.schedule.season)
		)

		if not aftermath.ok:
			return aftermath

		return context.record("rci_aftermath", aftermath)


class EducationHealth extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		context.span.mark("simnation calculation")
		var nation := SimNationPhase.run(context.city, context.random)

		if not nation.ok:
			return nation

		var stored_nation := context.record("simnation", nation)

		if not stored_nation.ok:
			return stored_nation

		var demand: RciDemandPhase.Result = context.phase_results.get(
			"rci_demand", RciDemandPhase.Result.new()
		)
		var population_growth := maxi(
			demand.normal_population - demand.previous_population, 0
		)
		context.span.mark("industries")
		var industries := IndustryPhase.run(
			context.city, context.random, context.lfsr_random, population_growth
		)

		if not industries.ok:
			return industries

		var stored_industries := context.record("industries", industries)

		if not stored_industries.ok:
			return stored_industries

		context.span.mark("education_health")
		var demographics := EducationHealthPhase.run(context.city, context.random)

		if not demographics.ok:
			return demographics

		return context.record(context.action, demographics)


class Graphs extends SimulationDayPhase:
	func is_ready(context: SimulationPhaseContext) -> bool:
		return (
			context.developed_tiles >= 0
			and context.power_usage_percent >= 0
			and context.water_usage_percent >= 0
		)

	func run(context: SimulationPhaseContext) -> PhaseResult:
		var graphs := GraphHistory.run(
			context.city,
			context.developed_tiles,
			context.power_usage_percent,
			context.water_usage_percent
		)

		if not graphs.ok:
			return graphs

		return context.record(context.action, graphs)


class Milestones extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var milestones := MilestonePhase.run(context.city)

		if not milestones.ok:
			return milestones

		var stored := context.record(context.action, milestones)

		if not stored.ok:
			return stored

		if milestones.military_proposal_pending:
			context.interaction_request = SimulationInteractionRequest.military_proposal()

		return milestones


class Scenario extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var check := ScenarioPhase.run(context.scenario, context.city)

		if not check.ok:
			return check

		return context.record(context.action, check)


class Bankruptcy extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var bankruptcy := BankruptcyPhase.run(context.city)

		if not bankruptcy.ok:
			return bankruptcy

		return context.record(context.action, bankruptcy)


# an action that only asks the interface to refresh
class Refresh extends SimulationDayPhase:
	var requests: Array[String]

	func _init(refresh_requests: Array[String]) -> void:
		requests = refresh_requests

	func run(context: SimulationPhaseContext) -> PhaseResult:
		return context.record(context.action, PhaseResult.refreshing(requests))


class WeatherDisaster extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var weather := WeatherDisasterPhase.run(
			context.city,
			context.random,
			context.lfsr_random,
			context.power_usage_percent,
			context.water_usage_percent,
			context.commerce_connections,
			context.industry_connections,
			context.pending_disaster_point
		)

		if not weather.ok:
			return weather

		var stored := context.record(context.action, weather)

		if not stored.ok:
			return stored

		context.city_status_resource_id = CityStatusMessages.monthly_resource(
			weather.status_index, context.city.weather_type()
		)

		if weather.disaster_type != 0:
			context.pending_disaster_type = weather.disaster_type
			context.pending_disaster_point = weather.disaster_point

		return weather
