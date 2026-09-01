extends RefCounted


## Compare deterministic results while retaining all non-timing fields.
static func without_timings(value: Variant) -> Variant:
	if value is DisasterStartResult.MaxisManArrival or value is PhaseResult or value is SimulationDayResult or value is SimulationTickResult or value is MovingThingResult:
		var fields := {}

		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				fields[property.name] = value.get(property.name)

		return without_timings(fields)

	if value is Dictionary:
		var result := {}

		for key in value:
			if key not in ["timing", "job_timings"]:
				result[key] = without_timings(value[key])

		return result

	if value is Array:
		var result := []

		for item in value:
			result.append(without_timings(item))

		return result

	return value


static func tick_fixture(fields: Dictionary) -> SimulationTickResult:
	var result := SimulationTickResult.new()

	for value in fields.day_results:
		if value is SimulationDayResult:
			result.day_results.append(value)
			continue

		var day := SimulationDayResult.new()

		for key in value:
			if key == "phase_results":
				day.phase_results.assign(value[key])
			else:
				day.set(key, value[key])

		result.day_results.append(day)

	result.job_timings.assign(fields.get("job_timings", {}))

	return result
