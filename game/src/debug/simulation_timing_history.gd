class_name SimulationTimingHistory
extends RefCounted
# Statistics for accepted simulation results in this session.
@warning_ignore_start("integer_division")

const DAY_SUMMARIES := [
	"Budget, month start; yearly budget in January", "Power; pollution, police and fire on per-tile maps",
	"Land value, population, crime; pollution, police and fire on grid maps",
	"Growth 1/16", "Growth 2/16", "Growth 3/16", "Growth 4/16", "Growth 5/16", "Growth 6/16",
	"Growth 7/16", "Growth 8/16", "Growth 9/16", "Growth 10/16", "Growth 11/16", "Growth 12/16",
	"Growth 13/16", "Growth 14/16", "Growth 15/16", "Growth 16/16", "Traffic", "Water",
	"Demand, weather, SimNation, industry, education, health, graphs",
	"Milestones, scenario goals, bankruptcy", "Statistics window refresh",
	"Map refresh, city status, random disasters",
]
# a day slot is an outlier when its average is this many times faster or slower than the median slot
const PACING_OUTLIER_RATIO := 4.0
# pacing starts when this many day slots have samples
const PACING_MIN_SLOTS := 13
class Sample extends RefCounted:
	var count := 0
	var total_usec := 0
	var last_usec := 0
	var max_usec := 0
	var age := -1
	# pacing wait after the last sampled day. day slots only
	var last_delay_usec := 0


var days: Dictionary[int, Sample] = {}
var steps: Dictionary[String, Sample] = {}
# the sibling step that ran before each step when it was first recorded. an
# empty text marks a first step. the debug window keeps the steps in this order
var step_after: Dictionary[String, String] = {}
# mean of the day slot averages without outliers. 0 until enough slots have samples
var typical_day_usec := 0


func clear() -> void:
	days.clear()
	steps.clear()
	step_after.clear()
	typical_day_usec = 0


# `after` is the step that ran before this one in the same group, or null when it is not known
func record_step(label: String, usec: int, after: Variant = null) -> void:
	var row: Sample = steps.get(label)

	if row == null:
		row = Sample.new()

		if after != null:
			step_after[label] = after

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
			row.last_delay_usec = 0
			row.age = age

		# resuming a blocking interaction adds work to the same day's sample
		row.last_usec += int(day.timing.work_usec)
		row.total_usec += int(day.timing.work_usec)
		row.max_usec = maxi(row.max_usec, row.last_usec)
		days[slot] = row

		var previous := ""

		for label in day.timing.steps:
			var day_step := "Day %02d / %s" % [slot + 1, _phase_group(label)]
			record_step(day_step, day.timing.steps[label], previous)
			previous = day_step

		var phases := day.phase_results

		for phase_name: String in phases:
			var phase: PhaseResult = phases[phase_name]
			# day 22 records the calculation as simnation. day 25 has a simnation window refresh
			var group := "simnation calculation" if phase is SimNationPhase.Result else _phase_group(phase_name)
			var measured_parent := false

			for label: String in day.timing.steps:
				if _phase_group(label) == group:
					measured_parent = true
					break

			if phase.timing.has_total and not measured_parent:
				record_step("Day %02d / %s" % [slot + 1, group], phase.timing.work_usec)

			var previous_step := ""

			for label in phase.timing.steps:
				var phase_step := "Day %02d / %s / %s" % [slot + 1, group, label]
				record_step(phase_step, phase.timing.steps[label], previous_step)
				previous_step = phase_step

	for item in result.moving_results:
		if item.ok and not item.timing.is_empty():
			record_step("moving", item.timing.work_usec)

	for item in result.disaster_results:
		if item.ok and not item.timing.is_empty():
			record_step("disaster", item.timing.work_usec)

	for label in result.job_timings:
		record_step(label, result.job_timings[label])

	# the delay after a day arrives with the result of the next day
	for age: int in result.pacing_delays:
		var slot := posmod(age, 25)
		var delay: int = result.pacing_delays[age]
		var row: Sample = days.get(slot)
		record_step("Day %02d / pacing delay" % (slot + 1), delay)

		if row != null and row.age == age:
			row.last_delay_usec = delay

	if not result.day_results.is_empty():
		typical_day_usec = _typical_day_usec()


func _typical_day_usec() -> int:
	var averages: Array[float] = []

	for row: Sample in days.values():
		averages.append(float(row.total_usec) / row.count)

	if averages.size() < PACING_MIN_SLOTS:
		return 0

	averages.sort()
	var median := averages[averages.size() / 2]
	var total := 0.0
	var kept := 0

	for value in averages:
		if value * PACING_OUTLIER_RATIO >= median and value <= median * PACING_OUTLIER_RATIO:
			total += value
			kept += 1

	return roundi(total / kept)


static func _phase_group(label: String) -> String:
	match label:
		"pollution_terrain_land_value":
			return "data maps"
		"pollution_coverage":
			return "pollution and coverage"
		"statistics_windows":
			return "statistics window refresh"
		"map":
			return "map refresh"
		"simnation":
			return "simnation window refresh"
		"weather_disaster":
			return "city status and disasters"

	return label
