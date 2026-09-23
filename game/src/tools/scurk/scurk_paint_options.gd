class_name ScurkPaintOptions
extends RefCounted

var lock_transparent := false
var pixel_perfect := false
var shade_ramp := PackedInt32Array()
var shade_direction := 1
var isometric_snap := false
var guide_spacing := Vector2i(16, 8)
var guide_offset := Vector2i.ZERO
var stamp_width := 0
var stamp_height := 0
var stamp_pixels := PackedInt32Array()
var stamp_spacing := 8


func paint_index(existing: int, requested: int) -> int:
	if lock_transparent and (existing < 0 or requested < 0):
		return existing

	return clampi(requested, -1, 255)


func set_shade_ramp(indices: PackedInt32Array) -> void:
	shade_ramp.clear()
	for index in indices:
		if index >= 0 and index <= 255 and not shade_ramp.has(index):
			shade_ramp.append(index)


func shade_index(index: int, direction := 0) -> int:
	var position := shade_ramp.find(index)
	if position < 0:
		return index

	var step := shade_direction if direction == 0 else direction
	return shade_ramp[clampi(position + signi(step), 0, shade_ramp.size() - 1)]


static func pixel_perfect_path(points: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for point in points:
		if not result.is_empty() and result[-1] == point:
			continue
		if result.size() >= 2:
			var first := result[-1] - result[-2]
			var second := point - result[-1]
			if absi(first.x) + absi(first.y) == 1 and absi(second.x) + absi(second.y) == 1 and first.x * second.x + first.y * second.y == 0:
				result.remove_at(result.size() - 1)
		result.append(point)

	return result


func constrain_line(start: Vector2i, finish: Vector2i) -> Vector2i:
	if not isometric_snap or start == finish:
		return finish

	var delta := Vector2(finish - start)
	var directions := [Vector2.RIGHT, Vector2.DOWN, Vector2(2, 1), Vector2(2, -1)]
	var nearest := Vector2.ZERO
	var distance := INF
	for direction: Vector2 in directions:
		var candidate := direction * roundf(delta.dot(direction) / direction.length_squared())
		var candidate_distance := candidate.distance_squared_to(delta)
		if candidate_distance < distance:
			nearest = candidate
			distance = candidate_distance

	return start + Vector2i(roundi(nearest.x), roundi(nearest.y))


func guide_lines(size: Vector2i) -> PackedVector2Array:
	var lines := PackedVector2Array()
	if size.x <= 0 or size.y <= 0:
		return lines

	var spacing := Vector2i(maxi(1, guide_spacing.x), maxi(1, guide_spacing.y))
	for x in range(posmod(guide_offset.x, spacing.x), size.x, spacing.x):
		lines.append_array(PackedVector2Array([Vector2(x, 0), Vector2(x, size.y)]))
	for y in range(posmod(guide_offset.y, spacing.y), size.y, spacing.y):
		lines.append_array(PackedVector2Array([Vector2(0, y), Vector2(size.x, y)]))
	for slope: float in [0.5, -0.5]:
		var offset := float(guide_offset.y) - float(guide_offset.x) * slope
		var first := floori((-float(size.x) * 0.5 - offset) / spacing.y)
		var last := ceili((float(size.y) + float(size.x) * 0.5 - offset) / spacing.y)
		for step in range(first, last + 1):
			var intercept := offset + step * spacing.y
			var low := maxf(0.0, minf(-intercept / slope, (size.y - intercept) / slope))
			var high := minf(float(size.x), maxf(-intercept / slope, (size.y - intercept) / slope))
			if high > low:
				lines.append_array(PackedVector2Array([Vector2(low, slope * low + intercept), Vector2(high, slope * high + intercept)]))

	return lines


func set_stamp(width: int, height: int, pixels: PackedInt32Array) -> bool:
	if width <= 0 or height <= 0 or width > 1024 or height > 1024 or pixels.size() != width * height:
		return false
	for index in pixels:
		if index < -1 or index > 255:
			return false

	stamp_width = width
	stamp_height = height
	stamp_pixels = pixels.duplicate()
	return true


static func resolve_texture_value(source: int, selected_color: int) -> int:
	if source == 0xff:
		return selected_color

	if source == 0xf5 or source == 0:
		return -1

	return clampi(source, 0, 255)
