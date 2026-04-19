@tool
class_name StatusCompass
extends Control
# an original vector compass rose aligned with the city grid

var compass_rotation := 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


func set_compass(value: int) -> void:
	var next_rotation := (value & 3) if value >= 0 else -1

	if compass_rotation != next_rotation:
		compass_rotation = next_rotation
		queue_redraw()

	tooltip_text = "Map compass: no city loaded." if value < 0 else (
		"North points %s." % ["lower-right", "upper-right", "upper-left", "lower-left"][compass_rotation]
	)


static func north_direction(value: int) -> Vector2:
	return [Vector2(2, 1), Vector2(2, -1), Vector2(-2, -1), Vector2(-2, 1)][value & 3]


static func rose_transform(value: int) -> Transform2D:
	# neighbors places north at +x for saved rotation zero. project the rotated
	# grid axes with the city renderer's two-to-one tile width/height ratio
	var north := north_direction(value) * 0.5
	var east := north_direction(value - 1) * 0.5
	return Transform2D(east, -north, Vector2.ZERO)


func _draw() -> void:
	if compass_rotation < 0:
		return

	var ink := get_theme_color("font_color", "Label")
	var gray := ink.lerp(Color(0.55, 0.55, 0.55), 0.8)
	var projection := rose_transform(compass_rotation)
	draw_set_transform(size * 0.5)

	# short gray diagonal points sit behind the four long cardinal points
	for index in range(4):
		var direction := Vector2.from_angle(PI * 0.25 + index * PI * 0.5)
		var screen_direction := (projection * direction).normalized()
		var side := screen_direction.orthogonal() * 1.5
		draw_colored_polygon(PackedVector2Array([
			side, screen_direction * 4.5, -side,
		]), gray)

	for index in range(4):
		var direction := Vector2.from_angle(index * PI * 0.5)
		var screen_direction := (projection * direction).normalized()
		var side := screen_direction.orthogonal() * 2.0
		draw_colored_polygon(PackedVector2Array([
			side, screen_direction * 9.0, -side,
		]), ink)

	draw_circle(Vector2.ZERO, 2.5, gray, true, -1.0, true)
	# n moves with the north point but stays upright and easy to read
	var north := north_direction(compass_rotation).normalized()
	draw_set_transform(size * 0.5 + north * 14.0)
	# a filled outline gives the n flat ends without acute line-join spikes
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.5, 3.25), Vector2(-2.5, -3.25), Vector2(-1.5, -3.25),
		Vector2(1.5, 1.1), Vector2(1.5, -3.25), Vector2(2.5, -3.25),
		Vector2(2.5, 3.25), Vector2(1.5, 3.25), Vector2(-1.5, -1.1),
		Vector2(-1.5, 3.25),
	]), ink)
