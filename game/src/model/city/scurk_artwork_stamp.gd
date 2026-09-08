class_name ScurkArtworkStamp
extends RefCounted
# one display-only scurk stamp. history owns copies of these values

var tile_id: int
var point: Vector2i


func _init(tile: int, location: Vector2i) -> void:
	tile_id = tile
	point = location


static func copy_all(stamps: Array[ScurkArtworkStamp]) -> Array[ScurkArtworkStamp]:
	var result: Array[ScurkArtworkStamp] = []

	for stamp in stamps:
		result.append(ScurkArtworkStamp.new(stamp.tile_id, stamp.point))

	return result


static func same_values(left: Array[ScurkArtworkStamp], right: Array[ScurkArtworkStamp]) -> bool:
	if left.size() != right.size():
		return false

	for index in left.size():
		if left[index].tile_id != right[index].tile_id or left[index].point != right[index].point:
			return false

	return true
