class_name GameOverEvent
extends RefCounted


var type: String
var funds: int


func _init(event_type: String, city_funds := 0) -> void:
	type = event_type
	funds = city_funds
