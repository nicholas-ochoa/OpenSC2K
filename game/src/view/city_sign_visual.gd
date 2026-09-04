class_name CitySignVisual
extends RefCounted


var indexed := false
var indices: Image
var texture: Texture2D
var position := Vector2.ZERO
var size := Vector2.ZERO


func _init(image_texture: Texture2D = null) -> void:
	texture = image_texture
	size = Vector2(texture.get_size()) if texture != null else Vector2.ZERO


func copy() -> CitySignVisual:
	var result := CitySignVisual.new(texture)
	result.indexed = indexed
	result.indices = indices
	result.position = position
	result.size = size

	return result


func matches(other: CitySignVisual) -> bool:
	return (other != null and indexed == other.indexed and indices == other.indices
		and texture == other.texture and position == other.position and size == other.size)
