class_name TransportTripResult
extends RefCounted


var ok := false
var error := ""
var reached_destination := false
var cost := 0
var path_length := 0
var used_bus := false
var used_rail := false
var used_subway := false
var expanded_states := 0


func reset() -> void:
	ok = false
	error = ""
	reached_destination = false
	cost = 0
	path_length = 0
	used_bus = false
	used_rail = false
	used_subway = false
	expanded_states = 0


static func failure(message: String) -> TransportTripResult:
	var result := TransportTripResult.new()
	result.error = message

	return result


func same_values(other: TransportTripResult) -> bool:
	return (other != null
		and ok == other.ok
		and error == other.error
		and reached_destination == other.reached_destination
		and cost == other.cost
		and path_length == other.path_length
		and used_bus == other.used_bus
		and used_rail == other.used_rail
		and used_subway == other.used_subway
		and expanded_states == other.expanded_states)
