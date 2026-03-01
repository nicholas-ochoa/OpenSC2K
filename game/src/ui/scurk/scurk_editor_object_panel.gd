class_name ScurkEditorObjectPanel
extends VBoxContainer

signal search_changed(value: String)
signal object_selected(index: int)
signal name_submitted
signal set_name_requested
signal revert_name_requested

var object_search: LineEdit
var object_list: ItemList
var name_edit: LineEdit
var name_button: Button
var revert_name_button: Button


func _ready() -> void:
	build()


func build() -> void:
	if object_search != null:
		return

	custom_minimum_size = Vector2(220, 0)
	add_theme_constant_override("separation", 5)

	var objects_heading := Label.new()
	objects_heading.text = "Tile Objects"
	objects_heading.add_theme_color_override("font_color", Color("dce8ff"))
	add_child(objects_heading)

	object_search = LineEdit.new()
	object_search.placeholder_text = "Filter by ID or name"
	object_search.text_changed.connect(search_changed.emit)
	add_child(object_search)

	object_list = ItemList.new()
	object_list.name = "TileObjectList"
	object_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	object_list.item_selected.connect(object_selected.emit)
	add_child(object_list)

	var name_heading := Label.new()
	name_heading.text = "Query Name"
	add_child(name_heading)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Optional tile name"
	name_edit.text_submitted.connect(_on_name_submitted)
	add_child(name_edit)

	name_button = Button.new()
	name_button.text = "Set Name"
	name_button.pressed.connect(set_name_requested.emit)
	add_child(name_button)

	revert_name_button = Button.new()
	revert_name_button.text = "Revert Name"
	revert_name_button.tooltip_text = (
		"Remove the custom name and restore the original query name."
	)
	revert_name_button.pressed.connect(revert_name_requested.emit)
	add_child(revert_name_button)


func _on_name_submitted(_value: String) -> void:
	name_submitted.emit()
