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
signal generate_requested
signal pick_copy_requested
signal about_requested

# the SCURK action of each menu entry, for its shortcut hint
const ACTION_ENTRIES: Dictionary[String, String] = {
	"Open": "scurk_open", "Save": "scurk_save", "SaveAs": "scurk_save_as", "Undo": "scurk_undo", "Redo": "scurk_redo",
	"SelectAll": "scurk_select_all", "CopySelection": "scurk_copy", "CutSelection": "scurk_cut",
	"PasteSelection": "scurk_paste", "CopyAllLayers": "scurk_copy_all_layers", "CutAllLayers": "scurk_cut_all_layers",
	"PasteNewLayer": "scurk_paste_new_layer", "DuplicateSelection": "scurk_duplicate", "DeleteSelection": "scurk_delete",
}
# Esc stays fixed
const FIXED_HINTS: Dictionary[String, int] = { "Deselect": KEY_ESCAPE, "Close": KEY_ESCAPE }

var bindings := ControlBindings.defaults()
var _menus: Array[Array] = []
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
	for action in ["RecoverProject", "ExportTileSet", "ReplaceColor", "SelectAll", "Deselect", "CopySelection", "CutSelection",
		"DuplicateSelection", "DeleteSelection", "PasteSelection", "CopyAllLayers", "CutAllLayers", "PasteNewLayer"]:
		get_node("Actions/" + action).pressed.connect(studio_action.emit.bind(action))
	$Actions/Import.pressed.connect(import_bmp_requested.emit)
	$Actions/Export.pressed.connect(export_bmp_requested.emit)
	$Actions/Close.pressed.connect(close_requested.emit)
	$Actions/Undo.pressed.connect(undo_requested.emit)
	$Actions/Redo.pressed.connect(redo_requested.emit)
	$Actions/Name.pressed.connect(name_requested.emit)
	$Actions/Revert.pressed.connect(revert_requested.emit)
	$Actions/Clear.pressed.connect(clear_requested.emit)
	$Actions/Generate.pressed.connect(generate_requested.emit)
	$Actions/PickCopy.pressed.connect(pick_copy_requested.emit)
	save_button = $Actions/Save
	undo_button = $Actions/Undo
	redo_button = $Actions/Redo
	revert_button = $Actions/Revert
	clear_button = $Actions/Clear
	_bind_menu($Row/File, ["Open", "", "Save", "SaveAs", "", "RecoverProject",
		"", "PickCopy", "Import", "Export", "ExportTileSet", "", "Close"])
	_bind_menu(
		$Row/Edit,
		[
			"Undo",
			"Redo",
			"",
			"SelectAll",
			"Deselect",
			"",
			"CutSelection",
			"CopySelection",
			"PasteSelection",
			"",
			"CutAllLayers",
			"CopyAllLayers",
			"PasteNewLayer",
			"",
			"DuplicateSelection",
			"DeleteSelection",
			"",
			"ReplaceColor",
			"Name",
			"Generate",
			"",
			"Revert",
			"Clear",
		],
	)
	_bind_menu($Row/Options, ["Settings"])
	_bind_menu($Row/Help, ["About"])


func _bind_menu(menu: MenuButton, entries: Array[String]) -> void:
	menu.get_popup().set_script(preload("res://src/ui/scurk/scurk_context_menu.gd"))
	var popup := menu.get_popup() as ScurkContextMenu
	for index in entries.size():
		if entries[index].is_empty():
			popup.add_separator()
		else:
			popup.add_item((get_node("Actions/" + entries[index]) as Button).text, index)

	_menus.append([popup, entries])
	_set_menu_hints(popup, entries)
	popup.about_to_popup.connect(func() -> void:
		for index in entries.size():
			if not entries[index].is_empty():
				popup.set_item_disabled(index, (get_node("Actions/" + entries[index]) as Button).disabled))
	popup.id_pressed.connect(func(index: int) -> void:
		var action := get_node("Actions/" + entries[index]) as Button
		if not action.disabled:
			action.pressed.emit())
	popup.bind()


# show the player's keys beside the menu items
func refresh_shortcut_hints(value: ControlBindings) -> void:
	bindings = value

	for entry in _menus:
		_set_menu_hints(entry[0], entry[1])


func _set_menu_hints(popup: ScurkContextMenu, entries: Array[String]) -> void:
	popup.hints.clear()
	popup.shortcuts.clear()

	for index in entries.size():
		if FIXED_HINTS.has(entries[index]):
			popup.set_shortcut_hint(index, FIXED_HINTS[entries[index]])
		elif ACTION_ENTRIES.has(entries[index]):
			var binding := bindings.first_key(ACTION_ENTRIES[entries[index]])

			if binding != null:
				popup.set_shortcut_hint(index, binding.key_with_masks())
