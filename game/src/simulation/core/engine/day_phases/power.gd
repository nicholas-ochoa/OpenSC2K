extends SimulationDayPhase


func run(context: SimulationPhaseContext) -> PhaseResult:
	var power := PowerPhase.run(context.city, context.random)

	if not power.ok:
		return power

	var stored := context.record(context.action, power)

	if not stored.ok:
		return stored

	context.power_usage_percent = power.usage_percent

	# per-tile maps move pollution and service coverage from the data-map
	# day to here. they need the new powered flags and nothing from day 3
	if not context.city.document.full_resolution_maps():
		return power

	context.span.mark("pollution_coverage")
	var coverage := NativeDataMapPhase.run_pollution_and_coverage(context.city)

	if not coverage.ok:
		return coverage

	stored = context.record("pollution_coverage", coverage)

	if not stored.ok:
		return stored

	return power
