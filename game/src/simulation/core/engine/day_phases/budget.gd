extends SimulationDayPhase
# the original settles the year, runs the annual facility update, and then
# does the monthly budget work. the annual update can change funds and the
# arcology population that the monthly work reads


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
