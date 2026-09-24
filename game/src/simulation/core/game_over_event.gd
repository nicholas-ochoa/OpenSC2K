class_name GameOverEvent
extends RefCounted


var type: String
var funds: int
var sound_id: int


func _init(event_type: String, city_funds := 0) -> void:
	type = event_type
	funds = city_funds
	sound_id = 513 if type == "scenario_victory" else 512


func is_terminal() -> bool:
	return type != "scenario_victory"
