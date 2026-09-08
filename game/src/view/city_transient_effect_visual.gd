class_name CityTransientEffectVisual
extends RefCounted


var texture: Texture2D
var position: Vector2
var frame: int


func _init(pixels: Texture2D, origin: Vector2, frame_index := 0) -> void:
	texture = pixels
	position = origin
	frame = frame_index
