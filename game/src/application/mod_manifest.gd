class_name ModManifest
extends RefCounted
## The info.json file of a mod folder: the identity of the mod, its main
## script, and the facts that the Mods window shows. A manifest with a
## problem keeps the problem in `error`, and the mod does not load.
## See docs/mods.md.

const FILE_NAME := "info.json"
# a mod id: lowercase letters, digits, ".", "_" and "-"
const ID_PATTERN := "^[a-z0-9][a-z0-9._-]{0,63}$"
# event sources and the console use these names
const RESERVED_IDS: PackedStringArray = ["console", "game"]
const SCRIPT_EXTENSIONS: PackedStringArray = ["js", "mjs"]

var id := ""
var name := ""
var version := ""
var description := ""
# the path of the main script, relative to the mod folder
var main := ""
var author := ""
var email := ""
var website := ""
var license := ""
# the oldest OpenSC2K version that the mod works with, or empty
var game_version := ""
# the ids of the mods that must load first
var dependencies: PackedStringArray = []
# the absolute path of the mod folder
var folder := ""
var error := ""


## Reads info.json in the folder. A missing or wrong file gives a manifest
## with an error and the folder name as its name.
static func read(mod_folder: String, current_game_version: String) -> ModManifest:
	var manifest := ModManifest.new()
	manifest.folder = mod_folder
	manifest.id = mod_folder.get_file().to_lower()
	manifest.name = mod_folder.get_file()
	var path := mod_folder.path_join(FILE_NAME)

	if not FileAccess.file_exists(path):
		manifest.error = "The folder has no %s file." % FILE_NAME

		return manifest

	var json := JSON.new()

	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		manifest.error = "%s is not valid JSON: %s on line %d." % [FILE_NAME, json.get_error_message(), json.get_error_line()]

		return manifest

	if not json.data is Dictionary:
		manifest.error = "%s must hold a JSON object." % FILE_NAME

		return manifest

	manifest.error = manifest._apply(json.data, current_game_version)

	return manifest


# takes the fields of the JSON object. Returns the first problem, or an empty text
func _apply(data: Dictionary, current_game_version: String) -> String:
	id = _text(data, "id", id).to_lower()
	name = _text(data, "name", "")
	version = _text(data, "version", "")
	main = _text(data, "main", "")
	description = _text(data, "description", "")
	email = _text(data, "email", "")
	website = _text(data, "website", "")
	license = _text(data, "license", "")
	game_version = _text(data, "gameVersion", "")
	_apply_author(data.get("author"))

	if not RegEx.create_from_string(ID_PATTERN).search(id) or RESERVED_IDS.has(id):
		return "The id \"%s\" is not valid. Use lowercase letters, digits, \".\", \"_\" and \"-\"." % id

	if name.is_empty():
		name = folder.get_file()

		return "%s needs a \"name\"." % FILE_NAME

	if version.is_empty():
		return "%s needs a \"version\", such as \"1.0.0\"." % FILE_NAME

	var main_problem := _main_problem()

	if not main_problem.is_empty():
		return main_problem

	var dependency_problem := _apply_dependencies(data.get("dependencies", []))

	if not dependency_problem.is_empty():
		return dependency_problem

	if not game_version.is_empty() and compare_versions(current_game_version, game_version) < 0:
		return "The mod needs OpenSC2K %s or newer." % game_version

	return ""


# "author" is a name, or an object { name, email, website }
func _apply_author(value: Variant) -> void:
	if value is Dictionary:
		author = _text(value, "name", "")
		email = email if not email.is_empty() else _text(value, "email", "")
		website = website if not website.is_empty() else _text(value, "website", _text(value, "url", ""))
	elif value != null:
		author = str(value).strip_edges()


func _main_problem() -> String:
	if main.is_empty():
		return "%s needs a \"main\" script, such as \"main.js\"." % FILE_NAME

	if main.is_absolute_path() or main.begins_with("/") or main.begins_with("\\") or ".." in main.replace("\\", "/").split("/"):
		return "The main script must be a path in the mod folder, not %s." % main

	if not SCRIPT_EXTENSIONS.has(main.get_extension().to_lower()):
		return "The main script must be a .js or .mjs file, not %s." % main

	if not FileAccess.file_exists(folder.path_join(main)):
		return "The main script %s is missing." % main

	return ""


func _apply_dependencies(value: Variant) -> String:
	if not value is Array:
		return "\"dependencies\" must be a list of mod ids."

	for item: Variant in value:
		var dependency := str(item).to_lower()

		if not item is String or dependency == id:
			return "\"dependencies\" has a wrong mod id: %s." % str(item)

		if not dependencies.has(dependency):
			dependencies.append(dependency)

	return ""


## The facts of the mod for scripts and for the Mods window.
func info() -> Dictionary:
	return {
		"id": id, "name": name, "version": version, "description": description, "main": main, "author": author,
		"email": email, "website": website, "license": license, "gameVersion": game_version,
		"dependencies": Array(dependencies),
	}


static func _text(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key)

	if value == null:
		return fallback

	if typeof(value) == TYPE_FLOAT and value == floorf(value):
		return str(int(value))

	return str(value).strip_edges()


## Compares dotted versions such as "0.10.2" and "0.9": -1, 0 or 1. A part
## that is not a number counts its leading digits.
static func compare_versions(first: String, second: String) -> int:
	var first_parts := first.split(".")
	var second_parts := second.split(".")

	for index in maxi(first_parts.size(), second_parts.size()):
		var a := _version_part(first_parts, index)
		var b := _version_part(second_parts, index)

		if a != b:
			return -1 if a < b else 1

	return 0


static func _version_part(parts: PackedStringArray, index: int) -> int:
	if index >= parts.size():
		return 0

	var digits := RegEx.create_from_string("^\\d+").search(parts[index].strip_edges())

	return int(digits.get_string()) if digits != null else 0
