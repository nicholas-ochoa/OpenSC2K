extends SceneTree
const History = preload("res://src/ui/file_dialog_history.gd")
const PATH := "user://file-dialog-history-test.cfg"
var history: Node
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	history = History.new()
	history.storage_path = PATH
	root.add_child(history)
	var favorites := PackedStringArray([ProjectSettings.globalize_path("res://../references/SIMCITY2000/"), "/Volumes/Offline Cities/"])
	var recents := PackedStringArray([ProjectSettings.globalize_path("res://../local/large-cities/")])
	if mode == "write":
		FileDialog.set_favorite_list(favorites)
		FileDialog.set_recent_list(recents)
		var dialog := FileDialog.new()
		root.add_child(dialog)
		dialog.popup_centered()
		await process_frame
		dialog.hide()
		await process_frame
		var config := ConfigFile.new()
		assert(config.load(PATH) == OK)
		assert(config.get_value("folders", "favorites") == favorites)
		assert(config.get_value("folders", "recents") == recents)
		dialog.queue_free()
	else:
		assert(FileDialog.get_favorite_list() == favorites, "Favorites changed after restart, including offline folders")
		assert(FileDialog.get_recent_list() == recents, "Recent folders changed after restart")
		assert(History._paths(123).is_empty())
		assert(History._paths(["one", "", 4, "one", "two"]) == PackedStringArray(["one", "two"]))
		FileDialog.set_favorite_list(PackedStringArray())
		history.save_history()
		history.restore_history()
		assert(FileDialog.get_favorite_list().is_empty(), "Removed favorites returned after restart")
	history.queue_free()
	await process_frame
	if mode != "write":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("PASS: file dialog history " + mode)
	quit()
