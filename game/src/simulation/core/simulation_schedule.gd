class_name SimulationSchedule
extends RefCounted

var city_days := 0
var elapsed_years := 0
var month := 0
var month_day := 0
var season := 0
var actions := PackedStringArray()
var growth_step := -1
var growth_substep := -1


func copy() -> SimulationSchedule:
	var result := SimulationSchedule.new()
	result.city_days = city_days
	result.elapsed_years = elapsed_years
	result.month = month
	result.month_day = month_day
	result.season = season
	result.actions = actions.duplicate()
	result.growth_step = growth_step
	result.growth_substep = growth_substep

	return result


# the schedule of the actions after `completed_action`
func after(completed_action: String) -> SimulationSchedule:
	var remaining := copy()
	remaining.actions = PackedStringArray()
	var found := false

	for action in actions:
		if found:
			remaining.actions.append(action)
		elif action == completed_action:
			found = true

	return remaining


# value snapshot for detecting changes while a worker owns a private copy
func stamp() -> Array:
	return [city_days, elapsed_years, month, month_day, season,
		actions.duplicate(), growth_step, growth_substep]
