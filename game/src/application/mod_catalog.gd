class_name ModCatalog
extends RefCounted
## Finds the mods: each folder in the mods folder of the user data folder is
## one mod, with an info.json file. The load order puts the dependencies of a
## mod before it, and otherwise follows the ids. See docs/mods.md.

const FOLDER := "mods"


static func default_folder() -> String:
	return AppPaths.path(FOLDER)


## The manifests of the mod folders, in load order. A second folder with the
## same id, and a dependency cycle, give an error. The native library holds the
## rules; see native/core/platform/src/mods/catalog.rs.
static func scan(folder: String, game_version: String) -> Array[ModManifest]:
	var found: Array[ModManifest] = []

	if not DirAccess.dir_exists_absolute(folder):
		return found

	var names := DirAccess.get_directories_at(folder)
	names.sort()
	var folders := PackedStringArray()

	for folder_name in names:
		if not folder_name.begins_with("."):
			folders.append(folder.path_join(folder_name))

	for fields: Dictionary in NativePlatform.mod_catalog(folders, game_version):
		found.append(ModManifest.from_fields(fields))

	return found
