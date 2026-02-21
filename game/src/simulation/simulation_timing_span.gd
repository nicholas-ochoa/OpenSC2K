class_name SimulationTimingSpan
extends RefCounted
# elapsed work time, excluding explicit waits for the next frame grant
# this is not os thread cpu time: preemption is still included
var budget: SimulationSliceBudget
var started: int
var step_started: int
var current_step := ""
var steps: Dictionary = {}

func _init(slice: SimulationSliceBudget = null) -> void:
	budget = slice
	started = now_usec()
	step_started = started

func now_usec() -> int:
	return Time.get_ticks_usec() - (budget.parked_usec if budget != null else 0)

func mark(label: String) -> void:
	var now := now_usec()
	if not current_step.is_empty():
		steps[current_step] = int(steps.get(current_step, 0)) + now - step_started
	current_step = label
	step_started = now

func finish() -> Dictionary:
	mark("")
	return {"work_usec": now_usec() - started, "steps": steps}
