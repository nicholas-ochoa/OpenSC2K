extends RefCounted


## Compare deterministic results while retaining all non-timing fields.
static func without_timings(value: Variant) -> Variant:
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
