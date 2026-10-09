extends SceneTree
## Compare the asset packs that an import of the supplied game makes with the
## golden import corpus. A PNG file counts by its decoded pixels; other files
## count by their bytes. Set OPENSC2K_UPDATE_FIXTURES=1 to write a missing
## corpus file; an existing file is never replaced.

const Corpus = preload("res://tests/support/golden_corpus.gd")
const GOLDEN_PATH := "res://tests/fixtures/corpus/golden-import.json"


func _init() -> void:
	var started := Time.get_ticks_msec()
	var folder := ProjectSettings.globalize_path("user://golden-import-%d" % OS.get_process_id())
	OriginalGameInstaller.remove_tree(folder)
	var packs := OriginalPackImporter.import_executable(Corpus.reference_path("SIMCITY.EXE"), folder.path_join("packs"))
	assert(packs.ok, packs.error)
	var media := Sc2MediaImporter.import_assets(Corpus.reference_path(), folder.path_join("media"))
	assert(media.ok and media.failures.is_empty(), media.summary())
	var actual := {
		"format": "opensc2k-golden-import",
		"version": 1,
		"packs": _hash_tree(packs.graphics.get_base_dir().get_base_dir()),
		"media": _hash_tree(_only_folder(folder.path_join("media"))),
	}
	OriginalGameInstaller.remove_tree(folder)
	var path := ProjectSettings.globalize_path(GOLDEN_PATH)

	if not FileAccess.file_exists(path):
		assert(OS.get_environment("OPENSC2K_UPDATE_FIXTURES") == "1", "Missing golden import corpus: " + path)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(actual, "\t", true) + "\n")
		file.close()
		print("Wrote the golden import corpus: %s" % path)
		quit()

		return

	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var found := Corpus.differences(expected, JSON.parse_string(JSON.stringify(actual)))

	for line in found:
		printerr("CORPUS DIFFERENCE " + line)

	assert(found.is_empty(), "%d import corpus values differ" % found.size())
	print("PASS: golden import corpus of graphics, sound, music, data and media packs (%d ms)" % (Time.get_ticks_msec() - started))
	quit()


# the import folder of a media import. Its name holds the time of the import
func _only_folder(root: String) -> String:
	var folders := DirAccess.get_directories_at(root)
	assert(folders.size() == 1, "One media import folder")

	return root.path_join(folders[0])


# relative path -> hash of each file below `root`
func _hash_tree(root: String, relative := "") -> Dictionary:
	var result := {}
	var folder := root.path_join(relative)

	for name in DirAccess.get_files_at(folder):
		var file := relative.path_join(name)
		var full := folder.path_join(name)

		if name.get_extension().to_lower() == "png":
			var image := Image.load_from_file(full)
			result[file] = Corpus.image_hash(image) if image != null else "unreadable"
		else:
			result[file] = FileAccess.get_sha256(full)

	for name in DirAccess.get_directories_at(folder):
		result.merge(_hash_tree(root, relative.path_join(name)))

	return result
