class_name SimulationTimingSpan
extends RefCounted
# elapsed work time, excluding explicit waits for the next frame grant
# this is not os thread cpu time: preemption is still included

# per-tile step marks cost more than the work they measure in the growth scan
# the debug window turns them on when a detailed breakdown is wanted. callers
# read this once per phase and guard each hot mark with the local copy
static var detailed := false

var budget: SimulationSliceBudget
var started: int
var step_started: int
var current_step := ""
var steps: Dictionary = {}
var indexed_labels: PackedStringArray
var indexed_totals: PackedInt64Array
var current_index := -1


func _init(slice: SimulationSliceBudget = null, labels := PackedStringArray()) -> void:
	budget = slice
	indexed_labels = labels
	indexed_totals.resize(labels.size())
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


# use fixed indices for hot loops. convert labels only when the phase finishes
# a span uses either indexed marks or string marks, not both
func mark_index(index: int) -> void:
	var now := Time.get_ticks_usec() - (budget.parked_usec if budget != null else 0)

	if current_index >= 0:
		indexed_totals[current_index] += now - step_started

	current_index = index
	step_started = now


func finish() -> Dictionary:
	if indexed_labels.is_empty():
		mark("")
	else:
		mark_index(-1)

		for index in indexed_labels.size():
			steps[indexed_labels[index]] = indexed_totals[index]

	return {"work_usec": now_usec() - started, "steps": steps}
