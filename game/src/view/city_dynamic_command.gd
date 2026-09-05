class_name CityDynamicCommand
extends CitySpriteVisual


var position := Vector2i.ZERO
var shadow := false
var depth_order := -1
var record := -1
var overlay := -1
var static_occlusion := true
var train := false
var same_tile_foreground_indices := PackedInt32Array()


func value_signature() -> Array:
	# cache keys compare field values, not the identity of a rebuilt command
	return [sprite_id, flip, position, shadow, depth_order, record, overlay,
		static_occlusion, train, same_tile_foreground_indices]
