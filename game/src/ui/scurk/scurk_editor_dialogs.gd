class_name ScurkEditorDialogs
extends Control

const PickCopyControl = preload("res://src/ui/scurk/scurk_pick_copy_control.gd")

var open_dialog: FileDialog
var save_dialog: FileDialog
var import_bmp_dialog: FileDialog
var export_bmp_dialog: FileDialog
var discard_dialog: ConfirmationDialog
var error_dialog: AcceptDialog
var pick_copy_control: ScurkPickCopyControl


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_dialogs()


func _create_dialogs() -> void:
	if open_dialog != null:
		return

	open_dialog = FileDialog.new()
	open_dialog.theme = ThemeDB.get_default_theme().duplicate()
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.add_filter("*.MIF, *.mif", "SCURK tile sets")
	add_child(open_dialog)

	save_dialog = FileDialog.new()
	save_dialog.theme = ThemeDB.get_default_theme().duplicate()
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.add_filter("*.MIF, *.mif", "SCURK tile sets")
	add_child(save_dialog)

	import_bmp_dialog = FileDialog.new()
	import_bmp_dialog.theme = ThemeDB.get_default_theme().duplicate()
	import_bmp_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_bmp_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_bmp_dialog.title = "Import indexed PNG or BMP"
	import_bmp_dialog.add_filter("*.BMP, *.bmp, *.PNG, *.png", "Indexed images (BMP, PNG)")
	add_child(import_bmp_dialog)

	export_bmp_dialog = FileDialog.new()
	export_bmp_dialog.theme = ThemeDB.get_default_theme().duplicate()
	export_bmp_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_bmp_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_bmp_dialog.title = "Export Image"
	export_bmp_dialog.add_filter("*.png", "256-color indexed PNG")
	export_bmp_dialog.add_filter("*.gif", "Animated GIF (palette cycling)")
	add_child(export_bmp_dialog)

	discard_dialog = ConfirmationDialog.new()
	discard_dialog.theme = ClassicUiStyle.create_dialog_theme()
	discard_dialog.title = "Unsaved SCURK Changes"
	discard_dialog.get_ok_button().text = "Discard"
	add_child(discard_dialog)

	error_dialog = AcceptDialog.new()
	error_dialog.theme = ClassicUiStyle.create_dialog_theme()
	error_dialog.title = "SCURK Error"
	add_child(error_dialog)

	pick_copy_control = PickCopyControl.new()
	add_child(pick_copy_control)
