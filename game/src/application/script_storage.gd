class_name ScriptStorage
extends RefCounted
## The values of `game.storage`: one JSON file of keys and JSON values. The
## console scripts share scripts/storage.json in the user data folder. Each
## mod has storage.json in its own folder.

const FILE_NAME := "storage.json"

var path := ""
var _values: Dictionary = {}
var _loaded := false


func _init(file_path: String) -> void:
	path = file_path


func values() -> Dictionary:
	if not _loaded:
		_loaded = true
		var text := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else {}
		_values = parsed if parsed is Dictionary else {}

	return _values


func get_value(key: String, fallback: Variant) -> Variant:
	return values().get(key, fallback)


## Stores a value. Returns an empty text, or why the file cannot be written.
func set_value(key: String, value: Variant) -> String:
	values()[key] = value

	return save()


func remove(key: String) -> bool:
	var removed := values().erase(key)

	if removed:
		save()

	return removed


func save() -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return "Cannot write %s: %s." % [path, error_string(FileAccess.get_open_error())]

	file.store_string(JSON.stringify(_values, "\t"))
	file.close()

	return ""
