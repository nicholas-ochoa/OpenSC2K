extends SceneTree

var folder := ProjectSettings.globalize_path("user://app-paths-test-%d" % OS.get_process_id())


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var executable := folder.path_join("OpenSC2K")
	var moved := folder.path_join("moved")
	var user_root := ProjectSettings.globalize_path("user://").simplify_path()
	DirAccess.make_dir_recursive_absolute(executable.path_join("data"))
	DirAccess.make_dir_recursive_absolute(moved.path_join("data"))

	# the editor, tests, and the macOS bundle ignore the portable folder
	AppPaths.use_executable_folder(executable, false)
	assert(not AppPaths.is_portable() and AppPaths.root() == user_root and AppPaths.error().is_empty())
	assert(AppPaths.stored_path(user_root.path_join("packs/music")) == user_root.path_join("packs/music"))
	assert(AppPaths.loaded_path("packs/music") == "packs/music")

	AppPaths.use_executable_folder(moved.path_join("empty"), true)
	assert(not AppPaths.is_portable() and AppPaths.root() == user_root)

	var root := executable.path_join("data")
	AppPaths.use_executable_folder(executable, true)
	assert(AppPaths.is_portable() and AppPaths.root() == root and AppPaths.error().is_empty())
	assert(AppSettingsStore.default_path() == root.path_join("settings.cfg"))
	assert(MediaPack.default_folder("music") == root.path_join("packs/music"))
	assert(DataPack.default_folder() == root.path_join("packs/data"))

	# paths in the data folder are relative in the file, and other paths stay unchanged
	assert(AppPaths.stored_path(root) == ".")
	assert(AppPaths.stored_path(root.path_join("packs/sound/")) == "packs/sound")
	assert(AppPaths.stored_path(executable.path_join("data-old/packs")) == executable.path_join("data-old/packs"))
	assert(AppPaths.stored_path("/games/SC2K/OST") == "/games/SC2K/OST")
	assert(AppPaths.loaded_path(".") == root)
	assert(AppPaths.loaded_path("/games/SC2K/OST") == "/games/SC2K/OST")

	var options := AppSettingsStore.SaveOptions.new()
	options.graphics_source = "folder"
	options.graphics_folder = root.path_join("packs/Original/graphics")
	options.sound_pack_folder = root.path_join("packs/Original/sound")
	options.music_pack_folder = "/games/music"
	options.data_pack_folder = root.path_join("packs/Original/data")
	options.soundtrack_folder = root.path_join("soundtrack")
	options.toolbar_sounds = false
	assert(AppSettingsStore.save_values(0.5, 0.5, false, AppSettingsStore.default_path(), options) == OK)
	var config := ConfigFile.new()
	assert(config.load(root.path_join("settings.cfg")) == OK)
	assert(config.get_value("graphics", "folder") == "packs/Original/graphics")
	assert(config.get_value("audio", "sound_pack_folder") == "packs/Original/sound")
	assert(config.get_value("audio", "music_pack_folder") == "/games/music")
	assert(config.get_value("data", "pack_folder") == "packs/Original/data")
	assert(config.get_value("audio", "soundtrack_folder") == "soundtrack")
	assert(config.get_value("audio", "toolbar_sounds") == false)

	# a copied data folder resolves its paths from the new location
	var moved_root := moved.path_join("data")
	DirAccess.copy_absolute(root.path_join("settings.cfg"), moved_root.path_join("settings.cfg"))
	AppPaths.use_executable_folder(moved, true)
	var values := AppSettingsStore.load_values()
	assert(values.graphics_folder == moved_root.path_join("packs/Original/graphics"))
	assert(values.sound_pack_folder == moved_root.path_join("packs/Original/sound"))
	assert(values.music_pack_folder == "/games/music")
	assert(values.data_pack_folder == moved_root.path_join("packs/Original/data"))
	assert(values.soundtrack_folder == moved_root.path_join("soundtrack"))
	assert(not values.toolbar_sounds)

	var history := FileDialogHistory.new()
	history.storage_path = moved_root.path_join("history.cfg")
	# the file dialog adds a final slash to each folder
	var recents := PackedStringArray([moved_root.path_join("cities") + "/", "/games/SC2K/CITIES/"])
	FileDialog.set_recent_list(recents)
	history.save_history()
	assert(config.load(history.storage_path) == OK)
	assert(config.get_value("folders", "recents") == PackedStringArray(["cities", "/games/SC2K/CITIES/"]))
	FileDialog.set_recent_list(PackedStringArray())
	history.restore_history()
	assert(FileDialog.get_recent_list() == recents)
	FileDialog.set_recent_list(PackedStringArray())
	history.free()

	if not OS.has_feature("windows"):
		FileAccess.set_unix_permissions(moved_root, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
		AppPaths.use_executable_folder(moved, true)
		assert(AppPaths.is_portable() and not AppPaths.error().is_empty())
		FileAccess.set_unix_permissions(moved_root, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER)

	AppPaths.use_executable_folder(OS.get_executable_path().get_base_dir(), false)
	_remove(folder)
	print("PASS: portable data folder selection, relative settings paths, moved folder, and write check")
	quit()


func _remove(path: String) -> void:
	for child in DirAccess.get_directories_at(path):
		_remove(path.path_join(child))

	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))

	DirAccess.remove_absolute(path)
