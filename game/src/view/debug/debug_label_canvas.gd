class_name CityDebugLabelCanvas
extends Control
## Debug text at map positions, in screen pixels so that it stays sharp. The
## map draws it again after a pan or zoom. Text appears only when few enough
## labels are visible.

const FONT_SIZE := 11
# the most labels in one draw. more labels show nothing
const MAX_LABELS := 1500

# [Vector2 source position, String, Color]
var labels: Array = []
var view_scale := 1.0
var view_offset := Vector2.ZERO
var drawn := 0


func _init() -> void:
	name = "DebugLabelCanvas"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_view_transform(scale_value: float, offset: Vector2) -> void:
	view_scale = scale_value
	view_offset = offset
	queue_redraw()


func _draw() -> void:
	drawn = 0
	var font := ThemeDB.fallback_font
	var bounds := Rect2(Vector2.ZERO, size).grow(16)
	var visible_labels := []

	for label in labels:
		var at: Vector2 = view_offset + (label[0] as Vector2) * view_scale

		if bounds.has_point(at):
			visible_labels.append([at, label[1], label[2]])

			if visible_labels.size() > MAX_LABELS:
				return

	for label in visible_labels:
		var text: String = label[1]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var at: Vector2 = label[0] - Vector2(width * 0.5, -FONT_SIZE * 0.35)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, Color(0, 0, 0, 0.85))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, label[2])
		drawn += 1
