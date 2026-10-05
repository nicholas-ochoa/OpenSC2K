class_name ModCatalog
extends RefCounted
## Finds the mods: each folder in the mods folder of the user data folder is
## one mod, with an info.json file. The load order puts the dependencies of a
## mod before it, and otherwise follows the ids. See docs/mods.md.

const FOLDER := "mods"


static func default_folder() -> String:
	return AppPaths.path(FOLDER)


## The manifests of the mod folders, in load order. A second folder with the
## same id, and a dependency cycle, give an error.
static func scan(folder: String, game_version: String) -> Array[ModManifest]:
	var found: Array[ModManifest] = []

	if not DirAccess.dir_exists_absolute(folder):
		return found

	var names := DirAccess.get_directories_at(folder)
	names.sort()

	for folder_name in names:
		if folder_name.begins_with("."):
			continue

		found.append(ModManifest.read(folder.path_join(folder_name), game_version))

	var by_id: Dictionary[String, ModManifest] = {}

	for manifest in found:
		if by_id.has(manifest.id):
			manifest.error = "The mod in %s already has the id %s." % [by_id[manifest.id].folder.get_file(), manifest.id]
		elif manifest.error.is_empty():
			by_id[manifest.id] = manifest

	return load_order(found)


## The manifests with each dependency before the mods that need it, else by
## id. A mod in a dependency cycle gets an error. A missing dependency does not
## change the order; the mod then waits for it.
static func load_order(manifests: Array[ModManifest]) -> Array[ModManifest]:
	var sorted := manifests.duplicate()
	sorted.sort_custom(func(first: ModManifest, second: ModManifest) -> bool:
		return first.id < second.id if first.id != second.id else first.folder < second.folder)
	var by_id: Dictionary[String, ModManifest] = {}

	for manifest: ModManifest in sorted:
		if manifest.error.is_empty() and not by_id.has(manifest.id):
			by_id[manifest.id] = manifest

	var result: Array[ModManifest] = []
	# 1 while the mod is on the path of the search, 2 when it is placed
	var marks: Dictionary[ModManifest, int] = {}

	for manifest: ModManifest in sorted:
		_visit(manifest, by_id, marks, result)

	return result


static func _visit(manifest: ModManifest, by_id: Dictionary[String, ModManifest], marks: Dictionary[ModManifest, int],
		result: Array[ModManifest]) -> bool:
	if marks.get(manifest, 0) == 2:
		return true

	if marks.get(manifest, 0) == 1:
		return false

	marks[manifest] = 1
	var acyclic := true

	if manifest.error.is_empty():
		for dependency in manifest.dependencies:
			if by_id.has(dependency) and not _visit(by_id[dependency], by_id, marks, result):
				acyclic = false

	if not acyclic and manifest.error.is_empty():
		manifest.error = "The dependencies of the mod make a cycle: %s." % ", ".join(manifest.dependencies)

	marks[manifest] = 2
	result.append(manifest)

	return acyclic
