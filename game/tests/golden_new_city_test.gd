extends SceneTree
## Compare new-city terrain with the golden new-city corpus: each layout and
## feature, at two seeds, for the original and the per-tile data maps. Set
## OPENSC2K_UPDATE_FIXTURES=1 to write a missing corpus file; an existing file
## is never replaced. See docs/golden-corpus.md.

const Corpus = preload("res://tests/support/golden_corpus.gd")
const GOLDEN_PATH := "res://tests/fixtures/corpus/golden-new-cities.json"
const SEEDS := [[123, 456], [98765, 4321]]
const COMBINATIONS := [
	["classic", [], false, true, false],
	["classic", [], true, false, false],
	["classic", [], true, true, true],
	["meander", [], false, true, false],
	["delta", [], false, true, false],
	["peninsula", ["bay"], false, true, false],
	["crossing", [], false, true, false],
	["branch", [], false, true, false],
	["rejoin", ["delta"], false, true, false],
	["bay", [], true, false, false],
	["island", ["bay"], false, false, false],
	["islands", ["bay"], false, false, false],
	["plateau", [], false, true, false],
	["ridge", ["lake"], false, false, false],
	["valley", [], false, true, false],
	["rolling", ["lakes"], false, false, false],
	["basin", [], false, false, false],
	["canyon", ["meander"], false, true, false],
	["cliffs", [], true, false, false],
	["lake", ["meander"], false, true, false],
	["lakes", ["plateau"], true, true, true],
]


func _init() -> void:
	var started := Time.get_ticks_msec()
	var actual := {"format": "opensc2k-golden-new-cities", "version": 1, "cases": {}}

	for combination: Array in COMBINATIONS:
		for seeds: Array in SEEDS:
			for native_maps in [false, true]:
				var features: Array[String] = []
				features.assign(combination[1])
				var options := NewCityTerrain.Options.new()
				options.layout = combination[0]
				options.features = features
				options.ocean = combination[2]
				options.river = combination[3]
				options.smooth_slopes = combination[4]
				options.native_maps = native_maps
				options.hills = 5 + int(seeds[0]) % 30
				options.water = int(seeds[1]) % 40
				options.trees = 20
				var session := NewCityTerrainSession.new()
				session.begin(seeds[0], seeds[1])
				var preview := session.generate_preview(options, false)
				var key := "%s+%s-%s%s%s-%d-%s" % [combination[0], ",".join(features), "o" if combination[2] else "",
					"r" if combination[3] else "", "s" if combination[4] else "", seeds[0], "native" if native_maps else "original"]
				actual.cases[key] = Corpus.chunks_hash(preview.document) if preview.ok else "error: " + preview.error

	var path := ProjectSettings.globalize_path(GOLDEN_PATH)

	if not FileAccess.file_exists(path):
		assert(OS.get_environment("OPENSC2K_UPDATE_FIXTURES") == "1", "Missing golden new-city corpus: " + path)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(actual, "\t", true) + "\n")
		file.close()
		print("Wrote the golden new-city corpus: %s" % path)
		quit()

		return

	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var found := Corpus.differences(expected, JSON.parse_string(JSON.stringify(actual)))

	for line in found:
		printerr("CORPUS DIFFERENCE " + line)

	assert(found.is_empty(), "%d new-city corpus values differ" % found.size())
	print("PASS: golden new-city corpus of %d terrain settings (%d ms)" % [actual.cases.size(), Time.get_ticks_msec() - started])
	quit()
