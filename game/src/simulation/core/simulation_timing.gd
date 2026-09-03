class_name SimulationTiming
extends RefCounted


var has_total := false
var work_usec := 0
var steps: Dictionary[String, int] = {}


func _init(total_usec := -1, measured_steps: Dictionary[String, int] = {}) -> void:
	has_total = total_usec >= 0
	work_usec = maxi(total_usec, 0)
	steps = measured_steps


func is_empty() -> bool:
	return not has_total and steps.is_empty()
