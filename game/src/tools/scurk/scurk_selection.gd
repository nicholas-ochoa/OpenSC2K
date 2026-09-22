class_name ScurkSelection
extends RefCounted

@warning_ignore_start("integer_division")

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


func bounds() -> Rect2i:
	var minimum := Vector2i(width, height)
	var maximum := Vector2i(-1, -1)
	for offset in mask.size():
		if mask[offset] == 0:
			continue
		var point := Vector2i(offset % width, offset / width)
		minimum = minimum.min(point)
		maximum = maximum.max(point)

	return Rect2i(minimum, maximum - minimum + Vector2i.ONE) if maximum.x >= 0 else Rect2i()


func combine(value: PackedByteArray, mode: int = REPLACE) -> void:
	if value.size() != width * height:
		return

	if mode == REPLACE or mask.size() != value.size():
		mask.resize(value.size())
		mask.fill(0)
	for offset in value.size():
		if mode == SUBTRACT:
			mask[offset] = 0 if value[offset] != 0 else mask[offset]
		else:
			mask[offset] = 1 if value[offset] != 0 or mask[offset] != 0 else 0
	if not mask.has(1):
		mask.clear()


func rectangle(start: Vector2i, finish: Vector2i) -> PackedByteArray:
	var result := empty_mask()
	var minimum := start.min(finish).max(Vector2i.ZERO)
	var maximum := start.max(finish).min(Vector2i(width - 1, height - 1))
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			result[y * width + x] = 1

	return result


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
				if Geometry2D.get_closest_point_to_segment(point, polygon[edge], polygon[(edge + 1) % polygon.size()]).distance_squared_to(point) < 0.01:
					result[y * width + x] = 1
					break

	return result


func wand(pixels: PackedInt32Array, start: Vector2i) -> PackedByteArray:
	var result := empty_mask()
	if pixels.size() != result.size() or start.x < 0 or start.y < 0 or start.x >= width or start.y >= height:
		return result

	var color := pixels[start.y * width + start.x]
	var pending: Array[Vector2i] = [start]
	result[start.y * width + start.x] = 1
	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = point + step
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= width or neighbor.y >= height:
				continue
			var offset := neighbor.y * width + neighbor.x
			if result[offset] == 0 and pixels[offset] == color:
				result[offset] = 1
				pending.append(neighbor)

	return result


func translated(delta: Vector2i) -> PackedByteArray:
	var result := empty_mask()
	for offset in mask.size():
		if mask[offset] == 0:
			continue
		var target := Vector2i(offset % width, offset / width) + delta
		if target.x >= 0 and target.y >= 0 and target.x < width and target.y < height:
			result[target.y * width + target.x] = 1

	return result


func empty_mask() -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(width * height)
	return result
