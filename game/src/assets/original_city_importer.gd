class_name OriginalCityImporter
extends RefCounted
# copy original saved games without replacing the player's existing files


static func import_saved_games(source_root: String, saved_root: String) -> Dictionary:
	var copied := PackedStringArray()
	var counts := {"cities": 0, "scenarios": 0}

	for entry in [["CITIES", "cities", "sc2"], ["SCENARIO", "scenarios", "scn"]]:
		var source := source_root.path_join(entry[0])
		var files := PackedStringArray()
		_collect(source, "", entry[2], files)
		files.sort()

		for relative in files:
			var original := source.path_join(relative)
			var desired := saved_root.path_join(entry[1]).path_join(relative)
			var destination := desired
			var suffix := 1

			while FileAccess.file_exists(destination):
				if FileAccess.get_sha256(destination) == FileAccess.get_sha256(original):
					break

				destination = desired.get_basename() + " (Original %d)." % suffix + desired.get_extension()
				suffix += 1

			if not FileAccess.file_exists(destination):
				if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK:
					rollback(copied)

					return {"ok": false, "error": "Cannot create saved-game folder: " + destination.get_base_dir()}

				if DirAccess.copy_absolute(original, destination) != OK:
					DirAccess.remove_absolute(destination)
					rollback(copied)

					return {"ok": false, "error": "Cannot import saved game: " + destination}

				copied.append(destination)

				if FileAccess.get_sha256(original) != FileAccess.get_sha256(destination):
					rollback(copied)

					return {"ok": false, "error": "Saved game copy failed verification: " + destination}

			counts[entry[1]] += 1

	return {"ok": true, "error": "", "created": copied, "cities": counts.cities, "scenarios": counts.scenarios}


static func rollback(created: PackedStringArray) -> void:
	for path in created:
		DirAccess.remove_absolute(path)


static func _collect(root: String, relative: String, extension: String, files: PackedStringArray) -> void:
	var directory := DirAccess.open(root.path_join(relative))

	if directory == null:
		return

	directory.list_dir_begin()
	var name := directory.get_next()

	while not name.is_empty():
		var path := relative.path_join(name) if not relative.is_empty() else name

		if not directory.is_link(name):
			if directory.current_is_dir():
				_collect(root, path, extension, files)
			elif name.get_extension().to_lower() == extension:
				files.append(path)

		name = directory.get_next()

	directory.list_dir_end()
