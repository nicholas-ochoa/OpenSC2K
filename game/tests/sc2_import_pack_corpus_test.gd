extends SceneTree
## End-to-end graphics packs from distinct original platform containers.

const CORPUS := "res://../references/all-versions"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var temporary := ProjectSettings.globalize_path("res://../local/sc2-import-pack-corpus-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var probes: Array = JSON.parse_string(FileAccess.get_file_as_string(CORPUS.path_join("analysis/lineage/binary-probes.json")))
	var checked := 0

	for probe: Dictionary in probes:
		if probe.name not in ["windows-95/1996-special-edition", "windows-95/network-1.0.042", "windows-3x/english", "macintosh/68k-1.1", "macintosh/demo-1.0"]:
			continue

		var path := CORPUS.path_join(probe.path)
		var result := Sc2MediaImporter.import_assets(path, temporary, PackedStringArray(["graphics"]))
		assert(result.ok and not result.graphics.is_empty(), str(probe.name) + ": " + result.summary())
		assert(result.sound.is_empty() and result.music.is_empty())
		var pack := GraphicsPack.load_root(result.graphics)
		assert(pack.error.is_empty() and pack.large_sprites.entries.size() >= 450 and pack.small_medium_sprites.entries.size() >= 800, str(probe.name) + ": " + result.summary())
		assert(pack.large_sprites.find_sprite(1001) != null)
		assert(FileAccess.get_sha256(path) == probe.sha256)
		var standalone := GameAssetSource.load_source("", "folder", result.graphics)
		assert(standalone.error.is_empty(), str(probe.name) + ": " + standalone.error)
		assert(standalone.assets.large_sprites.entries.size() == pack.large_sprites.entries.size())
		assert(standalone.assets.small_medium_sprites.entries.size() == pack.small_medium_sprites.entries.size())

		if probe.name == "windows-95/1996-special-edition":
			assert(probe.sha256 != OriginalGameInstaller.EXPECTED_SIMCITY_SHA256)
			assert(OriginalGameInstaller.validate_executable(path).ok)
			assert(not OriginalGameInstaller.validate_executable(path, OriginalGameInstaller.EXPECTED_SIMCITY_SHA256).ok)
			var original := OriginalGameAssets.load_root(path.get_base_dir())
			assert(original.error.is_empty(), original.error)
			assert(pack.palette.colors == original.palette.colors)
			assert(pack.scenario_palette.colors == original.scenario_palette.colors)
			assert(pack.large_sprites.entries.size() == original.large_sprites.entries.size())
			assert(pack.small_medium_sprites.entries.size() == original.small_medium_sprites.entries.size())

			for field in GraphicsPack.UI_FIELDS:
				var actual: Image = pack.ui_images[field].duplicate()
				var expected: Image = original.get(field).duplicate()
				actual.convert(Image.FORMAT_RGBA8)
				expected.convert(Image.FORMAT_RGBA8)
				assert(actual.get_data() == expected.get_data(), field)

			for index in pack.large_sprites.entries.size():
				assert(pack.large_sprites.entries[index].decode_indices().pixels == original.large_sprites.entries[index].decode_indices().pixels)

			assert(standalone.reference_root.begins_with(result.root))
			assert(standalone.use_original_data)
		elif probe.name == "windows-95/network-1.0.042":
			assert(result.counts.graphics == 1500 and result.partial, result.summary())

		checked += 1
		print("Imported %s: %d graphics" % [probe.name, result.counts.graphics])
		assert(OriginalGameInstaller.remove_tree(result.root) == OK)

	var inventory := FileAccess.open(CORPUS.path_join("catalog/local-payload-sha256.jsonl"), FileAccess.READ)
	var dos := ""

	while not inventory.eof_reached():
		var line := inventory.get_line()

		if line.is_empty():
			continue

		var record: Dictionary = JSON.parse_string(line)

		if str(record.path).contains("/dos-pack-SC2DAT.") and str(record.path).ends_with("/SC2000.DAT"):
			dos = CORPUS.path_join(record.path)
			break

	assert(not dos.is_empty())
	var result := Sc2MediaImporter.import_assets(dos, temporary)
	assert(result.ok and result.counts.graphics >= 1400 and result.counts.sound >= 28 and result.counts.music == 19, result.summary())
	assert(GraphicsPack.load_root(result.graphics).error.is_empty())
	var dos_source := GameAssetSource.load_source("", "folder", result.graphics)
	assert(dos_source.error.is_empty() and not dos_source.use_original_data, dos_source.error)
	assert(MediaPack.load_folder(result.sound, "sound").error.is_empty())
	assert(MediaPack.load_folder(result.music, "music").error.is_empty())
	# GOG's macOS app wraps the DOS game. Importing the bundle must detect DOS,
	# even when launch scripts and unrelated host files are also present.
	var bundle := temporary.path_join("installed/SimCity Special Edition.app")
	assert(Sc2MediaImporter._write(bundle.path_join("Contents/Resources/game/SC2000.DAT"), FileAccess.get_file_as_bytes(dos)).is_empty())
	assert(Sc2MediaImporter._write(bundle.path_join("Contents/Resources/script"), "unused launcher".to_utf8_buffer()).is_empty())
	var gog := Sc2MediaImporter.import_assets(bundle, temporary.path_join("gog-packs"))
	assert(gog.ok and gog.platform == "DOS" and gog.counts == result.counts, gog.summary())
	assert(gog.root != result.root and FileAccess.file_exists(result.graphics))
	assert(checked == 5)
	print("Imported DOS: %d graphics, %d sounds, %d music tracks" % [result.counts.graphics, result.counts.sound, result.counts.music])
	assert(OriginalGameInstaller.remove_tree(temporary) == OK)
	print("PASS: six desktop platform/release graphics packs, Windows pixel parity, DOS all-category import and source hashes")
	quit()
