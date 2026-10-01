class_name CityTransientEffectVisual
extends RefCounted

var texture: Texture2D
var position: Vector2
var frame: int
# the painter depth order of the effect, and its layer at that depth. the map
# draws the effects that play together in this order
var depth: int
var layer: int
# the draw position among the effects that play now. it keeps the sort stable
var order: int


func _init(pixels: Texture2D, origin: Vector2, frame_index := 0, depth_order := -1, depth_layer := 0) -> void:
	texture = pixels
	position = origin
	frame = frame_index
	depth = depth_order
	layer = depth_layer


static func draws_before(left: CityTransientEffectVisual, right: CityTransientEffectVisual) -> bool:
	if left.depth != right.depth:
		return left.depth < right.depth

	if left.layer != right.layer:
		return left.layer < right.layer

	return left.order < right.order
