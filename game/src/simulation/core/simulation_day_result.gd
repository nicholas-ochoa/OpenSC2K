class_name SimulationDayResult
extends RefCounted


var ok := false
var error := ""
var day := 0
var schedule: Dictionary = {}
var applied := PackedStringArray()
var pending := PackedStringArray()
var phase_results: Dictionary[String, PhaseResult] = {}
var interaction_requests: Array = []
var complete := false
var timing: Dictionary = {"work_usec": 0, "steps": {}}


static func failure(message: String) -> SimulationDayResult:
	var result := SimulationDayResult.new()
	result.error = message

	return result
