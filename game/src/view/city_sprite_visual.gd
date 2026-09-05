class_name CitySpriteVisual
extends RefCounted


var sprite_id: int
var flip: bool


func _init(id: int = 0, mirrored := false) -> void:
	sprite_id = id
	flip = mirrored
