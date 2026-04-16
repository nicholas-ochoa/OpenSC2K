extends Control
# a vector spinner that only animates while visible

var angle := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(32, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(_sync_processing)
	_sync_processing()


func _sync_processing() -> void:
	set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	angle = fposmod(angle + delta * TAU, TAU)
	queue_redraw()


func _draw() -> void:
	var ink := get_theme_color("font_color", "Label")
	var center := size * 0.5
	draw_arc(center, 10.0, 0.0, TAU, 48, Color(ink, 0.18), 2.5, true)
	draw_arc(center, 10.0, angle, angle + TAU * 0.7, 36, ink, 2.5, true)
