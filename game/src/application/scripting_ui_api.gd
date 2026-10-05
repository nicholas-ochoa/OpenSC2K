class_name ScriptingUiApi
extends ScriptingApiBase
## The `ui` and `game.storage` functions of scripts: message windows,
## sounds, and values that stay after the game closes. See docs/scripting.md.

# the storage file in the user data folder. Each key holds a JSON value
const STORAGE_FILE := "scripts/storage.json"

# the newest message window
var last_alert: AcceptDialog
var _storage: Dictionary = {}
var _storage_loaded := false


func handlers() -> Dictionary[String, Callable]:
	return {
		"ui.alert": _alert,
		"ui.playSound": _play_sound,
		"storage.get": _storage_get,
		"storage.set": _storage_set,
		"storage.remove": _storage_remove,
		"storage.keys": func(_arguments: Array) -> Variant: return _loaded_storage().keys(),
	}


static func storage_path() -> String:
	return AppPaths.path(STORAGE_FILE)


# a message window with an OK button. The game continues while it shows
func _alert(arguments: Array) -> Variant:
	var dialog := AcceptDialog.new()
	dialog.theme = AppUiTheme.current()
	dialog.title = str(argument(arguments, 1, "Script"))
	dialog.dialog_text = str(argument(arguments, 0, ""))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	dialog.popup_centered()
	last_alert = dialog

	return null


# plays a sound of the sound pack: the number of SOUNDS/<id>.WAV
func _play_sound(arguments: Array) -> Variant:
	var id: Variant = argument(arguments, 0)

	if not is_number(id) or int(id) < 0:
		return fail("The sound must be a number, such as 500 for SOUNDS/500.WAV.")

	var ids: Array[int] = [int(id)]
	app.effects_audio.play_sound_ids(ids)

	return null


func _loaded_storage() -> Dictionary:
	if not _storage_loaded:
		_storage_loaded = true
		var text := FileAccess.get_file_as_string(storage_path())
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else {}
		_storage = parsed if parsed is Dictionary else {}

	return _storage


func _storage_get(arguments: Array) -> Variant:
	return _loaded_storage().get(str(argument(arguments, 0, "")), argument(arguments, 1))


func _storage_set(arguments: Array) -> Variant:
	var key := str(argument(arguments, 0, ""))

	if key.is_empty():
		return fail("A storage key cannot be empty.")

	_loaded_storage()[key] = argument(arguments, 1)

	return _save_storage()


func _storage_remove(arguments: Array) -> Variant:
	var removed := _loaded_storage().erase(str(argument(arguments, 0, "")))

	if removed:
		_save_storage()

	return removed


func _save_storage() -> Variant:
	DirAccess.make_dir_recursive_absolute(storage_path().get_base_dir())
	var file := FileAccess.open(storage_path(), FileAccess.WRITE)

	if file == null:
		return fail("Cannot write %s: %s." % [storage_path(), error_string(FileAccess.get_open_error())])

	file.store_string(JSON.stringify(_storage, "\t"))
	file.close()

	return true
