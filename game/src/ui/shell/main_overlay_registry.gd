class_name MainOverlayRegistry
extends Control

const MainMenuView = preload("res://src/ui/startup/main_menu_control.tscn")
const SettingsDialogView = preload("res://src/ui/settings/app_settings_dialog.tscn")
const AboutDialogView = preload("res://src/ui/settings/about_dialog.tscn")
const AssetImportDialogView = preload("res://src/ui/settings/sc2_asset_import_dialog.tscn")
const SaveChangesDialogView = preload("res://src/ui/shared/save_changes_dialog.gd")

var scurk_workspace: Control
var blocking_windows: Array[Node] = []
var modeless_windows: Array[Node] = []

var main_menu: MainMenuControl
var settings_dialog: AppSettingsDialog
var asset_import_dialog: Sc2AssetImportDialog
var scurk_editor: ScurkEditorControl
var scurk_place_print: ScurkPlacePrintControl
var scurk_print: ScurkPrintControl
var about_dialog: AboutDialog
var save_changes_dialog: SaveChangesDialog
var update_dialog: UpdateCheckDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_overlays()


func _create_overlays() -> void:
	main_menu = MainMenuView.instantiate() as MainMenuControl
	main_menu.z_index = 850
	main_menu.visible = false
	_register(main_menu, self, CityDialogRegistry.Modality.BLOCKING)

	settings_dialog = SettingsDialogView.instantiate() as AppSettingsDialog
	_register(settings_dialog, self, CityDialogRegistry.Modality.BLOCKING)
	asset_import_dialog = AssetImportDialogView.instantiate() as Sc2AssetImportDialog
	_register(asset_import_dialog, self, CityDialogRegistry.Modality.BLOCKING)

	about_dialog = AboutDialogView.instantiate()
	_register(about_dialog, self, CityDialogRegistry.Modality.MODELESS)

	save_changes_dialog = SaveChangesDialogView.new()
	_register(save_changes_dialog, self, CityDialogRegistry.Modality.BLOCKING)

	update_dialog = UpdateCheckDialog.new()
	_register(update_dialog, self, CityDialogRegistry.Modality.BLOCKING)


# true when a visible registered overlay suspends the simulation
func blocks_simulation() -> bool:
	return CityDialogRegistry.any_window_visible(blocking_windows)


func _register(window: Node, parent: Node, modality: CityDialogRegistry.Modality) -> void:
	parent.add_child(window)

	if modality == CityDialogRegistry.Modality.BLOCKING:
		blocking_windows.append(window)
	else:
		modeless_windows.append(window)


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
		_register(scurk_editor, _scurk_parent(), CityDialogRegistry.Modality.BLOCKING)

	return scurk_editor


func ensure_scurk_place_print() -> ScurkPlacePrintControl:
	if scurk_place_print == null:
		scurk_place_print = (load("res://src/ui/scurk/scurk_place_print_control.tscn") as PackedScene).instantiate() as ScurkPlacePrintControl
		_register(scurk_place_print, _scurk_parent(), CityDialogRegistry.Modality.BLOCKING)

	return scurk_place_print


func ensure_scurk_print() -> ScurkPrintControl:
	if scurk_print == null:
		scurk_print = (load("res://src/ui/scurk/scurk_print_control.tscn") as PackedScene).instantiate() as ScurkPrintControl
		_register(scurk_print, ensure_scurk_place_print(), CityDialogRegistry.Modality.BLOCKING)

	return scurk_print
