class_name PowerPlantExpiry
extends RefCounted


var record: int
var tile: int
var x: int
var y: int

func _init(record_id: int, tile_id: int, location: Vector2i) -> void:
	record = record_id
	tile = tile_id
	x = location.x
	y = location.y
