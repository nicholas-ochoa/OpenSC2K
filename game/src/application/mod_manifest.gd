class_name ModManifest
extends RefCounted
## The info.json file of a mod folder: the identity of the mod, its main
## script, and the facts that the Mods window shows. A manifest with a
## problem keeps the problem in `error`, and the mod does not load.
## See docs/mods.md.

const FILE_NAME := "info.json"

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
## with an error and the folder name as its name. The native library holds the
## rules; see native/core/platform/src/mods/manifest.rs.
static func read(mod_folder: String, current_game_version: String) -> ModManifest:
	return from_fields(NativePlatform.mod_manifest(mod_folder, current_game_version))


static func from_fields(fields: Dictionary) -> ModManifest:
	var manifest := ModManifest.new()

	for key: String in fields:
		manifest.set(key, fields[key])

	return manifest


## The facts of the mod for scripts and for the Mods window.
func info() -> Dictionary:
	return {
		"id": id, "name": name, "version": version, "description": description, "main": main, "author": author,
		"email": email, "website": website, "license": license, "gameVersion": game_version,
		"dependencies": Array(dependencies),
	}


## Compares dotted versions such as "0.10.2" and "0.9": -1, 0 or 1. A part
## that is not a number counts its leading digits.
static func compare_versions(first: String, second: String) -> int:
	return NativePlatform.compare_versions(first, second)
