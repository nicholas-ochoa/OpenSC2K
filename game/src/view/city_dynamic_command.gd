class_name CityDynamicCommand
extends CitySpriteVisual

var position := Vector2i.ZERO
var shadow := false
var depth_order := -1
var record := -1
var overlay := -1
var static_occlusion := true
var train := false
# Supporting rail tiles during an interpolated step, in painter order.
var train_support_orders := PackedInt32Array()
var same_tile_foreground_indices := PackedInt32Array()
# the water altitude under a ship or sailboat. -1 for other sprites
var floating_altitude := -1


func value_signature() -> Array:
	# cache keys compare field values, not the identity of a rebuilt command
	return [sprite_id, flip, position, shadow, depth_order, record, overlay,
		static_occlusion, train, same_tile_foreground_indices, floating_altitude, train_support_orders]
