extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var header := PackedByteArray()
	header.resize(24)
	header.fill(255)
	header.encode_u32(8, 0)
	header[12] = 2
	header[13] = 4
	var bytes := PackedByteArray([16, 7, 4, 1, 12, 2, 7, 9, 16, 1, 0])
	var decoded := Sc2ImportSprites.dos(header, bytes)
	assert(decoded.error.is_empty() and decoded.warnings.is_empty())
	assert(decoded.archive.entries.size() == 1)
	var entry := decoded.archive.find_sprite(1)
	assert(entry.width == 4 and entry.height == 2)
	assert(entry.decode_indices().pixels == PackedInt32Array([-1, 7, 9, -1, -1, -1, -1, -1]))
	_test_pack(header, bytes)
	_test_bitmap()
	_test_tiles()
	# Keep the first sprite when the second entry is malformed.
	header.encode_u32(16, 0xfffffffe)
	header[20] = 2
	header[21] = 4
	decoded = Sc2ImportSprites.dos(header, bytes)
	assert(decoded.error.is_empty() and decoded.warnings.size() == 1 and decoded.archive.entries.size() == 1)
	assert(not Sc2ImportSprites.dos(header.slice(0, 23), bytes).error.is_empty())
	assert(not Sc2ImportSprites.dos(header, bytes.slice(0, 10)).error.is_empty())
	bytes[3] = 5
	assert(not Sc2ImportSprites.dos(header, bytes).error.is_empty())
	print("PASS: DOS sprite IDs, transparency, pixels, empty rows, bounds and partial recovery")
	quit()


func _test_tiles() -> void:
	var bytes := PackedByteArray()
	bytes.resize(16)
	bytes.encode_u16(0, 1)
	bytes.encode_u16(2, 1001)
	bytes.encode_u16(8, 1)
	bytes.encode_u16(10, 2)
	var pixels := PackedByteArray([4, 1, 2, 4, 7, 9, 4, 1, 2, 4, 3, 5, 2, 1, 2, 2])
	bytes.encode_u32(12, pixels.size())
	bytes.append_array(pixels)
	var recovered := Sc2ImportSprites.tiles_database(bytes)
	assert(recovered.error.is_empty() and recovered.warnings.size() == 1)
	var entry := recovered.archive.find_sprite(1001)
	assert(entry.width == 2 and entry.height == 2)
	assert(entry.decode_indices().pixels == PackedInt32Array([7, 9, 3, 5]))
	assert(not Sc2ImportSprites.tiles_database(bytes.slice(0, 20)).error.is_empty())


func _test_bitmap() -> void:
	var dib := PackedByteArray()
	dib.resize(40 + 64 + 8)
	dib.encode_u32(0, 40)
	dib.encode_u32(4, 3)
	dib.encode_u32(8, 2)
	dib.encode_u16(12, 1)
	dib.encode_u16(14, 4)

	for index in 16:
		dib[40 + index * 4] = index * 10
		dib[42 + index * 4] = index * 5

	dib[104] = 0x45
	dib[105] = 0x60
	dib[108] = 0x12
	dib[109] = 0x30
	var decoded := Sc2ImportBitmap.decode(dib)
	assert(decoded.ok and decoded.width == 3 and decoded.height == 2, decoded.error)
	assert(decoded.pixels == PackedInt32Array([1, 2, 3, 4, 5, 6]))
	assert(decoded.palette.color(3) == Color8(15, 0, 30))
	dib.encode_u32(8, 0xfffffffe)
	assert(Sc2ImportBitmap.decode(dib).pixels == PackedInt32Array([4, 5, 6, 1, 2, 3]))
	assert(not Sc2ImportBitmap.decode(dib.slice(0, 110)).ok)
	dib.encode_u32(4, 0xffffffff)
	assert(not Sc2ImportBitmap.decode(dib).ok)
	var mac := PackedByteArray()
	mac.resize(4112)
	mac[0] = 1
	mac[16] = 255
	mac[20] = 77
	var palette := Sc2ImportGraphics.mac_palette(mac)
	assert(palette != null and palette.color(0) == Color8(255, 0, 77))
	assert(Sc2ImportGraphics.mac_palette(mac.slice(0, 4111)) == null)


func _test_pack(header: PackedByteArray, pixels: PackedByteArray) -> void:
	var palette := PackedByteArray()
	palette.resize(768)

	for index in 256:
		palette[index * 3] = index
		palette[index * 3 + 1] = 255 - index
		palette[index * 3 + 2] = index / 2

	var files := {"LARGE.HED": header, "LARGE.DAT": pixels, "SMALL.HED": header, "SMALL.DAT": pixels, "MINE.PAL": palette}
	var archive := PackedByteArray()
	archive.resize(files.size() * 16)
	var record := 0

	for name: String in files:
		var text := name.to_ascii_buffer()

		for index in text.size():
			archive[record * 16 + index] = text[index]

		archive.encode_u32(record * 16 + 12, archive.size())
		archive.append_array(files[name])
		record += 1

	var temporary := ProjectSettings.globalize_path("res://../local/sc2-import-graphics-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var source := temporary.path_join("source")
	assert(DirAccess.make_dir_recursive_absolute(source) == OK)
	var path := source.path_join("SC2000.DAT")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(archive)
	file.close()
	var imported := Sc2MediaImporter.import_assets(path, temporary.path_join("packs"), PackedStringArray(["graphics"]))
	assert(imported.ok and imported.counts.graphics == 2 and imported.partial, imported.summary())
	assert(imported.platform == "DOS" and imported.sound.is_empty() and imported.music.is_empty())
	var pack := GraphicsPack.load_root(imported.graphics)
	assert(pack.error.is_empty() and pack.partial, pack.error)
	assert(pack.large_sprites.find_sprite(1).decode_indices().pixels == PackedInt32Array([-1, 7, 9, -1, -1, -1, -1, -1]))
	assert(pack.palette.color(9) == Color8(9, 246, 4))
	assert(FileAccess.get_file_as_bytes(path) == archive)
	assert(OriginalGameInstaller.remove_tree(temporary) == OK)
