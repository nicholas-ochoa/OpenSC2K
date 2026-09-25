extends SceneTree


func _initialize() -> void:
	var pixels := PackedInt32Array()

	for y in 16:
		for x in 32:
			pixels.append(-1 if x == 0 else 171 + x % 8 if x < 16 else 224 + x % 14)

	var palette := Sc2Palette.index_encoding()
	var encoded := IndexedGif.encode_cycle(32, 16, pixels, palette)
	assert(encoded.ok and encoded.frame_count > 1 and encoded.duration_cs == 660)
	assert(palette.scurk_animation_index_map(31) == palette.scurk_animation_index_map(151))
	var args := OS.get_cmdline_user_args()
	var path := args[0] if not args.is_empty() else "user://gif-cycle-test.gif"
	_write(path, encoded.bytes)
	var metadata := {"width":32, "height":16, "pixels":Array(pixels), "frames": []}

	for tick in 120:
		metadata.frames.append(Array(palette.scurk_animation_index_map(31 + tick)))

	_write(path + ".json", JSON.stringify(metadata).to_utf8_buffer())
	# the first frame of the cycle export decodes with its cycled colors
	var first_frame := IndexedGif.decode(encoded.bytes)
	assert(first_frame.ok and first_frame.width == 32 and first_frame.height == 16 and first_frame.pixels[0] == -1)
	var static_path := path.get_base_dir().path_join("static.gif")
	_check_static(pixels, palette, static_path)

	if args.size() > 1:
		_check_fixtures(args[1])

	if args.is_empty():
		for name in [path, path + ".json", static_path, static_path + ".json"]:
			DirAccess.remove_absolute(name)

	print("PASS: GIF full cycle, frame count, single-frame indexed GIF, decoder fixtures and transparent indexed round trip")
	quit()


# a single-frame gif keeps every index, including duplicate colors, and its transparency
func _check_static(pixels: PackedInt32Array, palette: Sc2Palette, path: String) -> void:
	var encoded := IndexedGif.encode(32, 16, pixels, palette)
	assert(encoded.ok and encoded.frame_count == 1)
	var decoded := IndexedGif.decode(encoded.bytes)
	assert(decoded.ok and decoded.width == 32 and decoded.height == 16 and decoded.pixels == pixels)
	assert(decoded.palette.colors == palette.colors)
	_write(path, encoded.bytes)
	_write(path + ".json", JSON.stringify({"width": 32, "height": 16, "pixels": Array(pixels)}).to_utf8_buffer())
	var every_index := PackedInt32Array()

	for index in 256:
		every_index.append(index)

	assert(IndexedGif.decode(IndexedGif.encode(16, 16, every_index, palette).bytes).pixels == every_index)

	for index in 16:
		every_index.append(-1)

	assert(not IndexedGif.encode(16, 17, every_index, palette).ok, "A full palette leaves no transparent index")
	assert(not IndexedGif.decode("GIF89a".to_ascii_buffer()).ok)
	assert(not IndexedGif.decode(encoded.bytes.slice(0, encoded.bytes.size() - 40)).ok)


# independent pillow files: small tables, interlace, 12-bit codes, local tables and offsets
func _check_fixtures(folder: String) -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("fixtures.json")))
	assert(cases.size() == 5)

	for expected: Dictionary in cases:
		var decoded := IndexedGif.load_path(folder.path_join(expected.file))
		assert(decoded.ok, "%s: %s" % [expected.file, decoded.error])
		assert(decoded.width == int(expected.width) and decoded.height == int(expected.height), expected.file)
		assert(decoded.pixels == PackedInt32Array(expected.pixels), expected.file)

		for index in expected.colors.size():
			var color: Array = expected.colors[index]
			assert(decoded.palette.colors[index] == Color8(int(color[0]), int(color[1]), int(color[2])), expected.file)


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
