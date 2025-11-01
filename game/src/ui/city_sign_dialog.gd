class_name CitySignDialog
extends ConfirmationDialog

var text_input: LineEdit


func _ready() -> void:
	title = "City Sign"
	dialog_text = "Enter sign text. An empty value removes the sign."
	min_size = Vector2i(440, 170)

	text_input = LineEdit.new()
	text_input.max_length = 23
	text_input.set_anchors_preset(Control.PRESET_TOP_WIDE)
	text_input.offset_left = 14
	text_input.offset_top = 58
	text_input.offset_right = -14
	text_input.offset_bottom = 92
	add_child(text_input)


func show_text(value: String) -> void:
	text_input.text = value
	popup_centered()
	text_input.grab_focus()
	text_input.select_all()


func entered_text() -> String:
	return text_input.text
