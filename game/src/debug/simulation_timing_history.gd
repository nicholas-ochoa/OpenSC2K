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
class Sample extends RefCounted:
	var count := 0
	var total_usec := 0
	var last_usec := 0
	var max_usec := 0
	var age := -1


var days: Dictionary[int, Sample] = {}
var steps: Dictionary[String, Sample] = {}


func clear() -> void:
	days.clear()
	steps.clear()


func record_step(label: String, usec: int) -> void:
	var row: Sample = steps.get(label)

	if row == null:
		row = Sample.new()

	row.count += 1
	row.total_usec += usec
	row.last_usec = usec
	row.max_usec = maxi(row.max_usec, usec)
	steps[label] = row


func consume(result: SimulationTickResult) -> void:
	for day in result.day_results:
		if not day.ok or day.timing.is_empty():
			continue

		var age := int(day.day)
		var slot := posmod(age, 25)
		var row: Sample = days.get(slot)

		if row == null:
			row = Sample.new()

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

		var phases := day.phase_results

		for phase_name: String in phases:
			var phase: PhaseResult = phases[phase_name]
			var group := _phase_group(phase_name)
			var measured_parent := false

			for label: String in day.timing.steps:
				if _phase_group(label) == group:
					measured_parent = true
					break

			if phase.timing.has_total and not measured_parent:
				record_step("Day %02d / %s" % [slot + 1, group], phase.timing.work_usec)

			for label in phase.timing.steps:
				record_step("Day %02d / %s / %s" % [slot + 1, group, label], phase.timing.steps[label])

	for item in result.moving_results:
		if item.ok and not item.timing.is_empty():
			record_step("moving", item.timing.work_usec)

	for item in result.disaster_results:
		if item.ok and not item.timing.is_empty():
			record_step("disaster", item.timing.work_usec)

	for label in result.job_timings:
		record_step(label, result.job_timings[label])


static func _phase_group(label: String) -> String:
	match label:
		"pollution_terrain_land_value":
			return "data maps"
		"simnation calculation":
			return "simnation"

	return label
