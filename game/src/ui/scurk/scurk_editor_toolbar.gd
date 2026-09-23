class_name ScurkEditorToolbar
extends PanelContainer

signal studio_action(action: String)
signal settings_requested
signal open_requested
signal save_requested
signal import_bmp_requested
signal export_bmp_requested
signal close_requested
signal undo_requested
signal redo_requested
signal name_requested
signal revert_requested
signal clear_requested
signal pick_copy_requested
signal about_requested

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

	$Actions/Settings.pressed.connect(settings_requested.emit)
	$Actions/About.pressed.connect(about_requested.emit)
	$Actions/Open.pressed.connect(open_requested.emit)
	$Actions/Save.pressed.connect(save_requested.emit)
	$Actions/SaveAs.pressed.connect(studio_action.emit.bind("ProjectSaveAs"))
	for action in ["RecoverProject", "ExportTileSet", "ReplaceColor", "SelectAll", "Deselect", "CopySelection", "CutSelection", "DuplicateSelection", "DeleteSelection", "PasteSelection", "CopyAllLayers", "CutAllLayers", "PasteNewLayer"]:
		get_node("Actions/" + action).pressed.connect(studio_action.emit.bind(action))
	$Actions/Import.pressed.connect(import_bmp_requested.emit)
	$Actions/Export.pressed.connect(export_bmp_requested.emit)
	$Actions/Close.pressed.connect(close_requested.emit)
	$Actions/Undo.pressed.connect(undo_requested.emit)
	$Actions/Redo.pressed.connect(redo_requested.emit)
	$Actions/Name.pressed.connect(name_requested.emit)
	$Actions/Revert.pressed.connect(revert_requested.emit)
	$Actions/Clear.pressed.connect(clear_requested.emit)
	$Actions/PickCopy.pressed.connect(pick_copy_requested.emit)
	save_button = $Actions/Save
	undo_button = $Actions/Undo
	redo_button = $Actions/Redo
	revert_button = $Actions/Revert
	clear_button = $Actions/Clear
	_bind_menu($Row/File, ["Open", "Save", "SaveAs", "ExportTileSet", "RecoverProject", "", "Import", "Export", "", "Close"])
	_bind_menu($Row/Edit, ["Undo", "Redo", "", "SelectAll", "Deselect", "CopySelection", "CutSelection", "PasteSelection", "CopyAllLayers", "CutAllLayers", "PasteNewLayer", "DuplicateSelection", "DeleteSelection", "", "ReplaceColor", "Name", "Revert", "Clear", "PickCopy"])
	_bind_menu($Row/Options, ["Settings"])
	_bind_menu($Row/Help, ["About"])


func _bind_menu(menu: MenuButton, entries: Array[String]) -> void:
	var popup := menu.get_popup()
	for index in entries.size():
		if entries[index].is_empty():
			popup.add_separator()
		else:
			popup.add_item((get_node("Actions/" + entries[index]) as Button).text, index)

	popup.about_to_popup.connect(func() -> void:
		for index in entries.size():
			if not entries[index].is_empty():
				popup.set_item_disabled(index, (get_node("Actions/" + entries[index]) as Button).disabled))
	popup.id_pressed.connect(func(index: int) -> void:
		var action := get_node("Actions/" + entries[index]) as Button
		if not action.disabled:
			action.pressed.emit())
