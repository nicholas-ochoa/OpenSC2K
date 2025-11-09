class_name MainOverlayRegistry
extends Control

const MainMenuView = preload("res://src/ui/main_menu_control.gd")
const SettingsDialogView = preload("res://src/ui/app_settings_dialog.gd")
const ScurkEditorView = preload("res://src/ui/scurk_editor_control.gd")
const ScurkPlacePrintView = preload("res://src/ui/scurk_place_print_control.gd")
const ScurkPrintView = preload("res://src/ui/scurk_print_control.gd")
const AboutDialogView = preload("res://src/ui/about_dialog.gd")
const SaveChangesDialogView = preload("res://src/ui/save_changes_dialog.gd")

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
	main_menu = MainMenuView.new()
	main_menu.z_index = 850
	main_menu.visible = false
	add_child(main_menu)

	settings_dialog = SettingsDialogView.new()
	add_child(settings_dialog)

	scurk_editor = ScurkEditorView.new()
	scurk_editor.z_index = 940
	add_child(scurk_editor)

	scurk_place_print = ScurkPlacePrintView.new()
	add_child(scurk_place_print)

	scurk_print = ScurkPrintView.new()
	add_child(scurk_print)

	about_dialog = AboutDialogView.new()
	add_child(about_dialog)

	save_changes_dialog = SaveChangesDialogView.new()
	add_child(save_changes_dialog)
