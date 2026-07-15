class_name SimulationTimingHistory
extends RefCounted
# Statistics for accepted simulation results in this session.
const DAY_SUMMARIES := [
	"Budget and month initialization", "Power",
	"Pollution, land value, services, population density, crime",
	"Growth: partition 1/16", "Growth: partition 2/16", "Growth: partition 3/16",
	"Growth: partition 4/16", "Growth: partition 5/16", "Growth: partition 6/16",
	"Growth: partition 7/16", "Growth: partition 8/16", "Growth: partition 9/16",
	"Growth: partition 10/16", "Growth: partition 11/16", "Growth: partition 12/16",
	"Growth: partition 13/16", "Growth: partition 14/16", "Growth: partition 15/16",
	"Growth: partition 16/16", "Traffic", "Water",
	"Demand, SimNation, industry, education, health, graphs",
	"Milestones, scenarios, bankruptcy", "Statistics-window refresh only",
	"Map and SimNation window refresh, weather and disaster checks",
]
var days: Dictionary = {}
var steps: Dictionary = {}


func clear() -> void:
	days.clear()
	steps.clear()


func record_step(label: String, usec: int) -> void:
	var row: Dictionary = steps.get(label, {"count": 0, "total_usec": 0, "last_usec": 0, "max_usec": 0})
	row.count += 1
	row.total_usec += usec
	row.last_usec = usec
	row.max_usec = maxi(row.max_usec, usec)
	steps[label] = row


func consume(result: Dictionary) -> void:
	for day in result.get("day_results", []):
		if not day.get("ok", false) or not day.has("timing"):
			continue

		var age := int(day.day)
		var slot := posmod(age, 25)
		var row: Dictionary = days.get(slot, {"count": 0, "total_usec": 0, "last_usec": 0, "max_usec": 0, "age": -1})

		if row.age != age:
			row.count += 1
			row.last_usec = 0
			row.age = age

		# resuming a blocking interaction adds work to the same day's sample
		row.last_usec += int(day.timing.work_usec)
		row.total_usec += int(day.timing.work_usec)
		row.max_usec = maxi(row.max_usec, row.last_usec)
		days[slot] = row

		for label in day.timing.steps:
			record_step("Day %02d / %s" % [slot + 1, _phase_group(label)], day.timing.steps[label])

		var phases: Dictionary = day.get("phase_results", {})

		for phase_name: String in phases:
			var phase: PhaseResult = phases[phase_name]
			var group := _phase_group(phase_name)
			var measured_parent := false

			for label: String in day.timing.steps:
				if _phase_group(label) == group:
					measured_parent = true
					break

			if phase.timing.has("work_usec") and not measured_parent:
				record_step("Day %02d / %s" % [slot + 1, group], phase.timing.work_usec)

			for label in phase.timing.get("steps", {}):
				record_step("Day %02d / %s / %s" % [slot + 1, group, label], phase.timing.steps[label])

	for key in ["moving_results", "disaster_results"]:
		for item in result.get(key, []):
			if item.get("ok", false) and item.has("timing"):
				record_step(key.trim_suffix("_results"), item.timing.work_usec)

	for label in result.get("job_timings", {}):
		record_step(label, result.job_timings[label])


static func _phase_group(label: String) -> String:
	match label:
		"pollution_terrain_land_value":
			return "data maps"
		"simnation calculation":
			return "simnation"

	return label
