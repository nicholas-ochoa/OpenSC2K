extends SimulationDayPhase


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
