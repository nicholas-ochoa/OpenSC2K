class_name AppPaths
extends RefCounted
## Selects the folder for settings, packs, cities, and other user files.
## A "data" folder beside an exported executable selects portable mode. The
## macOS app bundle is signed, thus it always uses the Godot user folder.

const PORTABLE_FOLDER := "data"

static var _root := ""
static var _portable := false
static var _error := ""


static func root() -> String:
	if _root.is_empty():
		use_executable_folder(OS.get_executable_path().get_base_dir(),
			OS.has_feature("template") and not OS.has_feature("macos"))

	return _root


static func path(relative: String) -> String:
	return root().path_join(relative)


static func is_portable() -> bool:
	root()

	return _portable


## Returns a message when the portable folder cannot be written.
static func error() -> String:
	root()

	return _error


## Selects the root from the executable folder. Tests use a disposable folder.
static func use_executable_folder(folder: String, allow_portable: bool) -> void:
	var portable_root := folder.path_join(PORTABLE_FOLDER).simplify_path()
	_portable = allow_portable and DirAccess.dir_exists_absolute(portable_root)
	_root = portable_root if _portable else ProjectSettings.globalize_path("user://").simplify_path()
	_error = ""

	if _portable and not _writable(_root):
		_error = "Cannot write to the portable data folder:\n%s\n\nMove OpenSC2K to a folder that you can write to, or remove the data folder." % _root


## Portable settings keep paths in the data folder relative, thus the folder can move
## to a different drive or location.
static func stored_path(value: String) -> String:
	if not is_portable() or value.is_empty():
		return value

	var full := value.simplify_path()
	var prefix := _root + "/"

	if _same_path(full, _root):
		return "."

	if _same_path(full.left(prefix.length()), prefix):
		return full.substr(prefix.length())

	return value


static func loaded_path(value: String) -> String:
	if not is_portable() or value.is_empty() or value.is_absolute_path():
		return value

	return _root.path_join(value).simplify_path()


static func _same_path(a: String, b: String) -> bool:
	# windows paths do not use letter case
	return a.to_lower() == b.to_lower() if OS.has_feature("windows") else a == b


static func _writable(folder: String) -> bool:
	var probe := folder.path_join(".write-test-%d" % OS.get_process_id())
	var file := FileAccess.open(probe, FileAccess.WRITE)

	if file == null:
		return false

	file.close()
	DirAccess.remove_absolute(probe)

	return true
