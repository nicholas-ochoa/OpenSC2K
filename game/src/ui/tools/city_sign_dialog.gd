class_name CitySignDialog
extends ConfirmationDialog

var text_input: LineEdit


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()
	text_input = $TextInput


func show_text(value: String) -> void:
	text_input.text = value
	popup_centered()
	text_input.grab_focus()
	text_input.select_all()


func entered_text() -> String:
	return text_input.text
