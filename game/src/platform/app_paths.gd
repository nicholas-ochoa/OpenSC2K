class_name AppPaths
extends RefCounted
## Selects the folder for settings, packs, cities, and other user files.
## A "data" folder beside an exported executable selects portable mode. The
## macOS app bundle is signed, thus it always uses the Godot user folder. The
## native platform library holds the rules.

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
	var selected := NativePlatform.app_root(folder, allow_portable, ProjectSettings.globalize_path("user://"))
	_root = selected.root
	_portable = selected.portable
	_error = selected.error


## Portable settings keep paths in the data folder relative, thus the folder can move
## to a different drive or location.
static func stored_path(value: String) -> String:
	return NativePlatform.stored_path(value, root(), is_portable(), OS.has_feature("windows"))


static func loaded_path(value: String) -> String:
	return NativePlatform.loaded_path(value, root(), is_portable())
