class_name CityRenameDialog
extends ConfirmationDialog

var name_input: LineEdit


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()
	name_input = $NameInput
	name_input.text_changed.connect(_sync_ok_button)
	name_input.text_submitted.connect(_submit)


func show_name(value: String) -> void:
	name_input.text = value
	_sync_ok_button(value)
	popup_centered()
	name_input.grab_focus()
	name_input.select_all()


func entered_name() -> String:
	return name_input.text.strip_edges()


func _sync_ok_button(_value: String) -> void:
	get_ok_button().disabled = entered_name().is_empty()


func _submit(_value: String) -> void:
	if entered_name().is_empty():
		return

	hide()
	confirmed.emit()


# SC2 and SCN names are shorter than SC2X version 4 names. See Sc2File.name_limit.
func set_max_length(value: int) -> void:
	name_input.max_length = value
