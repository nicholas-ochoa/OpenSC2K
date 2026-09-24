class_name ScurkEditorDialogs
extends Control


var open_dialog: FileDialog
var save_dialog: FileDialog
var import_bmp_dialog: FileDialog
var export_bmp_dialog: FileDialog
var discard_dialog: ConfirmationDialog
var error_dialog: AcceptDialog
var pick_copy_control: ScurkPickCopyControl


var export_options: ConfirmationDialog
var export_view: OptionButton
var generate_options: ConfirmationDialog
var generate_medium: CheckBox
var generate_small: CheckBox


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
	generate_options = $GenerateOptions
	generate_medium = $GenerateOptions/Content/Medium
	generate_small = $GenerateOptions/Content/Small
	generate_medium.toggled.connect(_update_generate_button)
	generate_small.toggled.connect(_update_generate_button)
	for label in ["Large", "Medium", "Small"]:
		export_view.add_item(label)
	for dialog in [open_dialog, save_dialog, import_bmp_dialog, export_bmp_dialog]:
		dialog.theme = AppUiTheme.file_dialog()


func _update_generate_button(_pressed: bool) -> void:
	generate_options.get_ok_button().disabled = not generate_medium.button_pressed and not generate_small.button_pressed
