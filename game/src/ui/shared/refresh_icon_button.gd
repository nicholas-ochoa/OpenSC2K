class_name RefreshIconButton
extends Button


func _draw() -> void:
	var center := size * 0.5
	var ink := get_theme_color("font_disabled_color" if disabled else "font_color")
	for turn in [0.0, PI]:
		var start: float = -0.3 + turn
		var finish: float = 2.1 + turn
		draw_arc(center, 7.0, start, finish, 32, ink, 1.7, true)
		var tip := center + Vector2.from_angle(finish) * 7.0
		var tangent := Vector2.from_angle(finish + PI * 0.5)
		var radial := Vector2.from_angle(finish)
		draw_polyline(PackedVector2Array([tip - tangent * 4.0 - radial * 3.0, tip,
			tip - tangent * 4.0 + radial * 3.0]), ink, 1.7, true)
