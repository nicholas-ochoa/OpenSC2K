@tool
class_name StatusCompass
extends Control
# an original vector north marker. the whole marker follows saved rotation

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
		"North points %s." % ["up", "right", "down", "left"][compass_rotation]
	)


func _draw() -> void:
	if compass_rotation < 0:
		return

	var ink := get_theme_color("font_color", "Label")
	draw_set_transform(size * 0.5, compass_rotation * PI * 0.5)
	# arrow above a hand-drawn n. no imported artwork or font is needed
	draw_line(Vector2(0, -2), Vector2(0, -9), ink, 2.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(-4, -5), Vector2(0, -9), Vector2(4, -5),
	]), ink, 2.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(-3.5, 9), Vector2(-3.5, 1), Vector2(3.5, 9), Vector2(3.5, 1),
	]), ink, 2.0, true)
