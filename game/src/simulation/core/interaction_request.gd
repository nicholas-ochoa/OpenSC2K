class_name SimulationInteractionRequest
extends RefCounted


var type: String
var funding_values := PackedInt32Array()
var auto_budget := false
var notification_id := 0


func _init(interaction_type: String) -> void:
	type = interaction_type


static func annual_budget(values: PackedInt32Array) -> SimulationInteractionRequest:
	var result := SimulationInteractionRequest.new("annual_budget")
	result.funding_values = values

	return result


static func military_proposal() -> SimulationInteractionRequest:
	var result := SimulationInteractionRequest.new("military_proposal")
	result.notification_id = 0xf0

	return result
