class_name ScurkSelection
extends RefCounted

const REPLACE := 0
const ADD := 1
const SUBTRACT := 2

var width := 0
var height := 0
var mask := PackedByteArray()


func reset(value_width: int, value_height: int) -> void:
	width = maxi(0, value_width)
	height = maxi(0, value_height)
	mask.clear()


func clear() -> void:
	mask.clear()


func active() -> bool:
	return not mask.is_empty() and mask.size() == width * height


func contains(point: Vector2i) -> bool:
	if point.x < 0 or point.y < 0 or point.x >= width or point.y >= height:
		return false

	return not active() or mask[point.y * width + point.x] != 0


# The native formats library holds the mask rules; see
# native/core/assets/src/scurk/selection.rs
func bounds() -> Rect2i:
	return NativeScurkPixels.mask_bounds(mask, width, height)


func combine(value: PackedByteArray, mode: int = REPLACE) -> void:
	if value.size() != width * height:
		return

	mask = NativeScurkPixels.combine_masks(mask, value, mode)


func rectangle(start: Vector2i, finish: Vector2i) -> PackedByteArray:
	return NativeScurkPixels.rectangle_mask(width, height, start, finish)


func lasso(points: PackedVector2Array) -> PackedByteArray:
	var result := empty_mask()
	if points.size() < 3:
		return result

	var polygon := points.duplicate()
	for index in polygon.size():
		polygon[index] += Vector2(0.5, 0.5)
	for y in height:
		for x in width:
			var point := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(point, polygon):
				result[y * width + x] = 1
				continue
			for edge in polygon.size():
				if Geometry2D.get_closest_point_to_segment(
					point,
					polygon[edge],
					polygon[(edge + 1) % polygon.size()],
				).distance_squared_to(point) < 0.01:
					result[y * width + x] = 1
					break

	return result


func wand(pixels: PackedInt32Array, start: Vector2i) -> PackedByteArray:
	return NativeScurkPixels.wand_mask(pixels, width, height, start)


func translated(delta: Vector2i) -> PackedByteArray:
	return NativeScurkPixels.translated_mask(mask, width, height, delta)


func empty_mask() -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(width * height)
	return result
