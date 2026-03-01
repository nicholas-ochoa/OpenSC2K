class_name FileDialogHistory
extends Node

const HISTORY_PATH := "user://file-dialog-history.cfg"
var storage_path := HISTORY_PATH


func _ready() -> void:
	restore_history()
	get_tree().node_added.connect(_node_added)


func _node_added(node: Node) -> void:
	if node is FileDialog:
		node.visibility_changed.connect(_visibility_changed.bind(node))


func _visibility_changed(dialog: FileDialog) -> void:
	if not dialog.visible:
		# filedialog can update recents after emitting its close signal
		save_history.call_deferred()


func _exit_tree() -> void:
	save_history()


func restore_history() -> void:
	var config := ConfigFile.new()

	if config.load(storage_path) != OK:
		return

	FileDialog.set_favorite_list(_paths(config.get_value("folders", "favorites", PackedStringArray())))
	FileDialog.set_recent_list(_paths(config.get_value("folders", "recents", PackedStringArray())))


func save_history() -> void:
	var config := ConfigFile.new()
	config.set_value("folders", "favorites", FileDialog.get_favorite_list())
	config.set_value("folders", "recents", FileDialog.get_recent_list())
	var error := config.save(storage_path)

	if error != OK:
		push_warning("Cannot save file dialog folders: %s" % error_string(error))


static func _paths(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()

	if not (value is Array or value is PackedStringArray):
		return result

	for item in value:
		if item is String and not item.is_empty() and item not in result:
			result.append(item)

	return result
