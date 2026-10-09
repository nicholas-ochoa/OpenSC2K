extends SceneTree
## Compare the results of the game with the golden corpus. Set
## OPENSC2K_UPDATE_FIXTURES=1 to write a missing corpus file; an existing file
## is never replaced. See tests/support/golden_corpus.gd and docs/golden-corpus.md.

const Corpus = preload("res://tests/support/golden_corpus.gd")


func _init() -> void:
	var started := Time.get_ticks_msec()
	var actual := Corpus.capture()
	var path := ProjectSettings.globalize_path(Corpus.GOLDEN_PATH)

	if not FileAccess.file_exists(path):
		assert(OS.get_environment("OPENSC2K_UPDATE_FIXTURES") == "1", "Missing golden corpus: " + path)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(actual, "\t", true) + "\n")
		file.close()
		print("Wrote the golden corpus: %s" % path)
		quit()

		return

	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var found := Corpus.differences(expected, JSON.parse_string(JSON.stringify(actual)))

	for line in found:
		printerr("CORPUS DIFFERENCE " + line)

	var notes := Corpus.differences(expected, JSON.parse_string(JSON.stringify(actual)), "", true).size() - found.size()

	if notes > 0:
		print("NOTE: %d GDScript-only corpus values changed" % notes)

	assert(found.is_empty(), "%d corpus values differ" % found.size())
	print("PASS: golden corpus of files, days, new cities and images (%d ms)" % (Time.get_ticks_msec() - started))
	quit()
