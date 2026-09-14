extends SceneTree
## Independent inventory hashes locate evidence; readers validate actual payloads.

const CORPUS := "res://../references/all-versions"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var path := CORPUS.path_join("analysis/lineage/binary-probes.json")
	assert(FileAccess.file_exists(path), "This audit requires the local platform corpus.")
	var probes: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var containers := 0
	var sounds := 0
	var sequences := 0

	for probe: Dictionary in probes:
		var name: String = probe.name
		var origin := CORPUS.path_join(probe.path)
		var parsed: Sc2ImportContainer

		if name.begins_with("macintosh/"):
			parsed = Sc2ImportContainer.macintosh(FileAccess.get_file_as_bytes(origin), origin)
		elif name.begins_with("windows-"):
			parsed = Sc2ImportContainer.windows(FileAccess.get_file_as_bytes(origin), origin)
		else:
			continue

		assert(parsed.error.is_empty(), name + ": " + parsed.error)
		assert(not parsed.resources.is_empty(), name)
		containers += 1

		if name in ["macintosh/68k-1.1", "windows-95/1996-special-edition", "windows-3x/english"]:
			var discovered := Sc2ImportSource.scan(origin)
			assert(discovered.error.is_empty(), name + ": " + discovered.error)
			assert(not discovered.resources.is_empty())
			var expected: String = {"macintosh": "Macintosh", "windows-95": "Windows", "windows-3x": "Windows 3.x"}[name.get_slice("/", 0)]
			assert(discovered.platform == expected, "%s detected as %s" % [name, discovered.platform])

		for resource in parsed.resources:
			if resource.type == "MIDI" and resource.bytes.slice(0, 4).get_string_from_ascii() == "MThd":
				var midi := StandardMidiFile.new()
				assert(midi.parse(resource.bytes), name + ": " + midi.parse_error)
				sequences += 1
			if resource.type == "snd " and resource.id >= 500 and resource.id <= 529:
				var converted := Sc2ImportAudio.mac_sound(resource.bytes)
				assert(converted.ok, "%s sound %d: %s" % [name, resource.id, converted.error])
				assert(AudioStreamWAV.load_from_buffer(converted.bytes) != null)
				sounds += 1

	var checked_archives: Dictionary[String, bool] = {}
	var checked_voc: Dictionary[String, bool] = {}
	var checked_xmi: Dictionary[String, bool] = {}
	var checked_sprites: Dictionary[String, bool] = {}
	var dos_sprites := 0
	var manifest := FileAccess.open(CORPUS.path_join("catalog/local-payload-sha256.jsonl"), FileAccess.READ)

	while not manifest.eof_reached():
		var line := manifest.get_line()

		if line.is_empty():
			continue

		var record: Dictionary = JSON.parse_string(line)
		var relative: String = record.path
		var platform := relative.get_slice("/", 1)

		if platform != "dos" or relative.get_file().to_upper() != "SC2000.DAT" or checked_archives.has(record.sha256):
			continue

		var origin := CORPUS.path_join(relative)
		var archive := Sc2ImportContainer.named_archive(FileAccess.get_file_as_bytes(origin), origin)
		assert(archive.error.is_empty(), relative + ": " + archive.error)
		assert(not archive.resources.is_empty())
		checked_archives[record.sha256] = true

		if platform == "dos":
			var files: Dictionary[String, PackedByteArray] = {}

			for resource in archive.resources:
				files[resource.name.to_upper()] = resource.bytes

			for stem in ["LARGE", "SMALL", "OTHER"]:
				if not files.has(stem + ".HED") or not files.has(stem + ".DAT"):
					continue

				var hash := HashingContext.new()
				hash.start(HashingContext.HASH_SHA256)
				hash.update(files[stem + ".HED"])
				hash.update(files[stem + ".DAT"])
				var digest := hash.finish().hex_encode()

				if checked_sprites.has(digest):
					continue

				var sprites := Sc2ImportSprites.dos(files[stem + ".HED"], files[stem + ".DAT"])
				assert(sprites.error.is_empty(), relative + ": " + sprites.error)
				assert(sprites.warnings.is_empty(), relative + ": " + "\n".join(sprites.warnings))
				dos_sprites += sprites.archive.entries.size()
				checked_sprites[digest] = true

			for resource in archive.resources:
				var suffix := resource.name.get_extension().to_lower()
				var stem := resource.name.get_basename()
				var hash := HashingContext.new()
				hash.start(HashingContext.HASH_SHA256)
				hash.update(resource.bytes)
				var digest := hash.finish().hex_encode()

				if suffix == "voc" and not checked_voc.has(digest):
					var converted := Sc2ImportVoc.convert(resource.bytes)
					assert(converted.ok, "%s/%s: %s" % [relative, resource.name, converted.error])
					assert(AudioStreamWAV.load_from_buffer(converted.bytes) != null)
					checked_voc[digest] = true
				elif suffix == "xmi" and stem.is_valid_int() and int(stem) >= 10000 and int(stem) <= 10018 and not checked_xmi.has(digest):
					var converted := Sc2ImportXmi.convert(resource.bytes)
					assert(converted.ok, "%s/%s: %s" % [relative, resource.name, converted.error])
					var midi := StandardMidiFile.new()
					assert(midi.parse(converted.bytes), midi.parse_error)
					checked_xmi[digest] = true

	assert(containers >= 15 and sounds >= 100 and sequences >= 100 and checked_archives.size() >= 5)
	assert(checked_voc.size() >= 30 and checked_xmi.size() >= 19)
	assert(checked_sprites.size() >= 3 and dos_sprites >= 1400)
	print("PASS: %d resource containers, %d Mac sounds, %d MIDIs, %d DOS archives, %d distinct VOCs and %d distinct XMIDIs" % [containers, sounds, sequences, checked_archives.size(), checked_voc.size(), checked_xmi.size()])
	print("PASS: %d DOS sprites from %d distinct archive pairs" % [dos_sprites, checked_sprites.size()])
	quit()
