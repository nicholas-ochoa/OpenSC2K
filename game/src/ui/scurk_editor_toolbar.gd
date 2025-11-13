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
	custom_minimum_size = Vector2(0, 38)
	add_theme_constant_override("separation", 5)
	add_child(_button(
		"Open...", &"open_requested", "Open a SCURK MIF tile set."
	))
	save_button = _button("Save", &"save_requested", "Save this tile set.")
	add_child(save_button)
	add_child(_button(
		"Save As...", &"save_as_requested", "Save to a new MIF file."
	))
	add_child(VSeparator.new())
	add_child(_button(
		"Import BMP...",
		&"import_bmp_requested",
		"Replace the current view with a 256-color indexed BMP.",
	))
	add_child(_button(
		"Export BMP...",
		&"export_bmp_requested",
		"Export the current view as a 256-color indexed BMP.",
	))
	add_child(_button(
		"Pick & Copy...",
		&"pick_copy_requested",
		"Copy equivalent objects from another SCURK tile set.",
	))
	add_child(VSeparator.new())
	undo_button = _button(
		"Undo", &"undo_requested", "Undo the last pixel or name edit."
	)
	add_child(undo_button)
	redo_button = _button(
		"Redo", &"redo_requested", "Redo the last undone edit."
	)
	add_child(redo_button)
	revert_button = _button(
		"Revert",
		&"revert_requested",
		"Restore this object to its state when it entered the drawing area.",
	)
	add_child(revert_button)
	clear_button = _button(
		"Clear Object",
		&"clear_requested",
		"Erase the object and leave clean ground and sky.",
	)
	add_child(clear_button)
	add_child(VSeparator.new())
	add_child(_button(
		"Apply to City", &"apply_requested", "Use this tile set in the city view."
	))
	add_child(_button(
		"Place & Print",
		&"place_print_requested",
		"Apply this tile set and open the unrestricted city work area.",
	))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	add_child(_button(
		"Close", &"close_requested", "Close the SCURK editor."
	))


func _button(label: String, signal_name: StringName, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 30)
	button.pressed.connect(emit_signal.bind(signal_name))
	return button
