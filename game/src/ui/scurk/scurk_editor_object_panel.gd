class_name ScurkEditorObjectPanel
extends VBoxContainer

signal search_changed(value: String)
signal object_selected(index: int)
signal name_submitted
signal set_name_requested
signal revert_name_requested

var object_search: LineEdit
var object_list: ScurkTileSelector
var name_edit: LineEdit
var name_button: Button
var revert_name_button: Button
var name_dialog: ConfirmationDialog


func _ready() -> void:
	build()


func build() -> void:
	if object_search != null:
		return

	object_search = $Search
	object_list = $Tiles
	name_dialog = $NameDialog
	name_edit = $NameDialog/Content/Name
	name_button = name_dialog.get_ok_button()
	revert_name_button = $NameDialog/Content/Revert
	object_search.text_changed.connect(search_changed.emit)
	object_list.item_selected.connect(object_selected.emit)
	name_dialog.confirmed.connect(set_name_requested.emit)
	name_edit.text_submitted.connect(func(_text: String) -> void:
		name_submitted.emit()
		name_dialog.hide())
	revert_name_button.pressed.connect(func() -> void:
		revert_name_requested.emit()
		name_dialog.hide())


func edit_name() -> void:
	name_dialog.popup_centered()
	name_edit.grab_focus()
	name_edit.select_all()
