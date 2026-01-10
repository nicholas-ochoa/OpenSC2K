class_name ScurkEditorToolbar
extends HBoxContainer

signal open_requested
signal save_requested
signal save_as_requested
signal import_bmp_requested
signal export_bmp_requested
signal pick_copy_requested
signal undo_requested
signal redo_requested
signal revert_requested
signal clear_requested
signal apply_requested
signal place_print_requested
signal close_requested

var save_button: Button
var undo_button: Button
var redo_button: Button
var revert_button: Button
var clear_button: Button


func _ready() -> void:
	build()


func build() -> void:
	if save_button != null:
		return
	custom_minimum_size = Vector2(0, 30)
	var actions := {}
	for entry in [
		["Open...", "open"], ["Save", "save"], ["Save As...", "save_as"],
		["Import BMP...", "import_bmp"], ["Export BMP...", "export_bmp"],
		["Pick & Copy...", "pick_copy"], ["Undo", "undo"], ["Redo", "redo"],
		["Revert Object", "revert"], ["Clear Object", "clear"],
		["Apply to City", "apply"], ["Place & Print", "place_print"], ["Close", "close"],
	]:
		var action := _button(entry[0], StringName(entry[1] + "_requested"), entry[0])
		action.hide()
		add_child(action)
		actions[entry[1]] = action
	save_button = actions.save
	undo_button = actions.undo
	redo_button = actions.redo
	revert_button = actions.revert
	clear_button = actions.clear
	for group in [
		["File", ["open", "save", "save_as", "", "import_bmp", "export_bmp", "", "close"]],
		["Edit", ["undo", "redo", "", "revert", "clear", "", "pick_copy"]],
		["City", ["apply", "place_print"]],
	]:
		var menu := MenuButton.new()
		menu.text = group[0]
		add_child(menu)
		var popup := menu.get_popup()
		var entries: Array = group[1]
		for index in entries.size():
			if str(entries[index]).is_empty():
				popup.add_separator()
			else:
				popup.add_item((actions[entries[index]] as Button).text, index)
		popup.about_to_popup.connect(func() -> void:
			for index in entries.size():
				if actions.has(entries[index]):
					popup.set_item_disabled(index, (actions[entries[index]] as Button).disabled))
		popup.id_pressed.connect(func(index: int) -> void:
			var action: Button = actions[entries[index]]
			if not action.disabled:
				action.pressed.emit())


func _button(label: String, signal_name: StringName, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 30)
	button.pressed.connect(emit_signal.bind(signal_name))
	return button
