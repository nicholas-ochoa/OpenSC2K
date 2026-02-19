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
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(encoded.bytes)
	file.close()
	var metadata := {"width":32, "height":16, "pixels":Array(pixels), "frames": []}
	for tick in 120:
		metadata.frames.append(Array(palette.scurk_animation_index_map(31 + tick)))
	file = FileAccess.open(path + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata))
	file.close()
	if args.is_empty():
		DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(path + ".json")
	print("PASS: GIF full cycle, frame count, transparent indexed fixture")
	quit()
