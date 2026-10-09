class_name SimulationDayResult
extends RefCounted

var ok := false
var error := ""
var day := 0
var schedule: SimulationSchedule
var applied := PackedStringArray()
var pending := PackedStringArray()
var phase_results: Dictionary[String, PhaseResult] = {}
var interaction_requests: Array[SimulationInteractionRequest] = []
# the first disaster update, when a disaster starts after the day
var disaster_results: Array[DisasterMapResult] = []
var complete := false
var timing := SimulationTiming.new(0)


static func failure(message: String) -> SimulationDayResult:
	var result := SimulationDayResult.new()
	result.error = message

	return result


# true when the day's only work was the data-map scan. those maps carry
# pollution, land value, and service coverage, not surface or underground
# artwork, so a caller can skip the map repaint
func scanned_data_maps_only() -> bool:
	if phase_results.size() != 1:
		return false

	return phase_results.values()[0] is PollutionPhase.Result
