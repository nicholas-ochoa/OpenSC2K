class_name MainOverlayRegistry
extends Control

const MainMenuView = preload("res://src/ui/startup/main_menu_control.tscn")
const SettingsDialogView = preload("res://src/ui/settings/app_settings_dialog.tscn")
const ScurkEditorView = preload("res://src/ui/scurk/scurk_editor_control.gd")
const ScurkPlacePrintView = preload("res://src/ui/scurk/scurk_place_print_control.tscn")
const ScurkPrintView = preload("res://src/ui/scurk/scurk_print_control.tscn")
const AboutDialogView = preload("res://src/ui/settings/about_dialog.tscn")
const SaveChangesDialogView = preload("res://src/ui/shared/save_changes_dialog.gd")

var main_menu: MainMenuControl
var settings_dialog: AppSettingsDialog
var scurk_editor: ScurkEditorControl
var scurk_place_print: ScurkPlacePrintControl
var scurk_print: ScurkPrintControl
var about_dialog: AboutDialog
var save_changes_dialog: SaveChangesDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_overlays()


func _create_overlays() -> void:
	main_menu = MainMenuView.instantiate() as MainMenuControl
	main_menu.z_index = 850
	main_menu.visible = false
	add_child(main_menu)

	settings_dialog = SettingsDialogView.instantiate() as AppSettingsDialog
	add_child(settings_dialog)

	scurk_editor = ScurkEditorView.new()
	scurk_editor.z_index = 940
	add_child(scurk_editor)

	scurk_place_print = ScurkPlacePrintView.instantiate() as ScurkPlacePrintControl
	add_child(scurk_place_print)

	scurk_print = ScurkPrintView.instantiate() as ScurkPrintControl
	add_child(scurk_print)

	about_dialog = AboutDialogView.instantiate()
	add_child(about_dialog)

	save_changes_dialog = SaveChangesDialogView.new()
	add_child(save_changes_dialog)
