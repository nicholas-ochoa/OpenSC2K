class_name MainOverlayRegistry
extends Control

const MainMenuView = preload("res://src/ui/startup/main_menu_control.tscn")
const SettingsDialogView = preload("res://src/ui/settings/app_settings_dialog.tscn")
const AboutDialogView = preload("res://src/ui/settings/about_dialog.tscn")
const SaveChangesDialogView = preload("res://src/ui/shared/save_changes_dialog.gd")

var scurk_workspace: Control

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

	about_dialog = AboutDialogView.instantiate()
	add_child(about_dialog)

	save_changes_dialog = SaveChangesDialogView.new()
	add_child(save_changes_dialog)


func _scurk_parent() -> Control:
	if scurk_workspace == null:
		scurk_workspace = Control.new()
		scurk_workspace.name = "SCURK"
		scurk_workspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(scurk_workspace)
		scurk_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	return scurk_workspace


func ensure_scurk_editor() -> ScurkEditorControl:
	if scurk_editor == null:
		scurk_editor = (load("res://src/ui/scurk/scurk_editor_control.tscn") as PackedScene).instantiate() as ScurkEditorControl
		scurk_editor.z_index = 940
		_scurk_parent().add_child(scurk_editor)

	return scurk_editor


func ensure_scurk_place_print() -> ScurkPlacePrintControl:
	if scurk_place_print == null:
		scurk_place_print = (load("res://src/ui/scurk/scurk_place_print_control.tscn") as PackedScene).instantiate() as ScurkPlacePrintControl
		_scurk_parent().add_child(scurk_place_print)

	return scurk_place_print


func ensure_scurk_print() -> ScurkPrintControl:
	if scurk_print == null:
		scurk_print = (load("res://src/ui/scurk/scurk_print_control.tscn") as PackedScene).instantiate() as ScurkPrintControl
		ensure_scurk_place_print().add_child(scurk_print)

	return scurk_print
