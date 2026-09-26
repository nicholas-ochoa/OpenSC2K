extends SimulationDayPhase


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
