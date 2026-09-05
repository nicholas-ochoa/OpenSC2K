class_name ScurkEditTool
extends RefCounted


var name: String
var group: int
var subtool: int
var zone: int
var view: String


func _init(value_name: String, value_group: int, value_subtool: int, value_zone: int, value_view: String) -> void:
	name = value_name
	group = value_group
	subtool = value_subtool
	zone = value_zone
	view = value_view


func copy() -> ScurkEditTool:
	return ScurkEditTool.new(name, group, subtool, zone, view)
