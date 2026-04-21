@tool
class_name StatusCompass
extends Control
# an original split pointer aligned with map north

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


func _draw() -> void:
	if compass_rotation < 0:
		return

	var ink := get_theme_color("font_color", "Label")
	var center := size * 0.5
	var north := north_direction(compass_rotation).normalized()

	# the right half is solid. the left half shows the panel through its outline
	draw_set_transform(center, north.angle() + PI * 0.5)
	var tip := Vector2(0, -3.5)
	var left := Vector2(-4.2, 5.5)
	var right := Vector2(4.2, 5.5)
	var notch := Vector2(0, 3.0)
	draw_colored_polygon(PackedVector2Array([tip, right, notch]), ink)
	draw_polyline(PackedVector2Array([tip, left, notch, right, tip]), ink, 1.1, true)
	draw_line(tip, notch, ink, 1.0, true)

	# n sits beyond the tip and turns with the pointer
	draw_set_transform(center + north * 9.0, north.angle() + PI * 0.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, 2.5), Vector2(-2, -2.5), Vector2(-1, -2.5),
		Vector2(1, 0.5), Vector2(1, -2.5), Vector2(2, -2.5),
		Vector2(2, 2.5), Vector2(1, 2.5), Vector2(-1, -0.5),
		Vector2(-1, 2.5),
	]), ink)
