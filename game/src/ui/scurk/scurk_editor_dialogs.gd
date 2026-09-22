class_name ScurkEditorDialogs
extends Control

const PickCopyControl = preload("res://src/ui/scurk/scurk_pick_copy_control.tscn")

var open_dialog: FileDialog
var save_dialog: FileDialog
var import_bmp_dialog: FileDialog
var export_bmp_dialog: FileDialog
var discard_dialog: ConfirmationDialog
var error_dialog: AcceptDialog
var pick_copy_control: ScurkPickCopyControl


var export_options: ConfirmationDialog
var export_view: OptionButton


func _ready() -> void:
	_create_dialogs()


func _create_dialogs() -> void:
	if open_dialog != null:
		return

	open_dialog = $Open
	save_dialog = $Save
	import_bmp_dialog = $Import
	export_bmp_dialog = $Export
	discard_dialog = $Discard
	error_dialog = $Error
	pick_copy_control = $PickCopy
	export_options = $ExportOptions
	export_view = $ExportOptions/Content/View
	for label in ["Large", "Medium", "Small"]:
		export_view.add_item(label)
	for dialog in [open_dialog, save_dialog, import_bmp_dialog, export_bmp_dialog]:
		dialog.theme = AppUiTheme.file_dialog()
