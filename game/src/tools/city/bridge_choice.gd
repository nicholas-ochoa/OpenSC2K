class_name BridgeChoice
extends RefCounted


var type: int
var name: String
var cost_per_tile: int
var cost: int


func _init(bridge_type: int, bridge_name: String, unit_cost: int, total_cost: int) -> void:
	type = bridge_type
	name = bridge_name
	cost_per_tile = unit_cost
	cost = total_cost


func copy() -> BridgeChoice:
	return BridgeChoice.new(type, name, cost_per_tile, cost)
