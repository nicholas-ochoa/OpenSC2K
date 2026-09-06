class_name QueryThing
extends ThingRecord


var record := -1
var type_name := ""
var direction_name := ""
var sprite_id := -1
var sprite_flip := false


func _init(source: ThingRecord = null) -> void:
	if source == null:
		return

	type = source.type
	direction = source.direction
	state = source.state
	x = source.x
	y = source.y
	z = source.z
	px = source.px
	py = source.py
	dx = source.dx
	dy = source.dy
	label = source.label
	goal = source.goal
