extends SceneTree
## Read-only archive metadata and executable zone-class table verification.

const ZONE_CLASSES := [3, 0, 0, 1, 1, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4]


func _initialize() -> void:
	var loaded := PeBitmapResource._load_resource_directory("res://../references/SIMCITY.EXE")
	assert(loaded.ok, str(loaded.error))
	var bytes: PackedByteArray = loaded.bytes
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK)
	assert(hashing.update(bytes) == OK)
	assert(hashing.finish().hex_encode() == "4f560f7a19586670a8ccb3e0ae69889679699ebf4de706a7a46b2098dd838e69")
	var offset := PeBitmapResource._rva_to_offset(bytes, 0x000e77b8, loaded.section_offset, loaded.section_count)
	assert(offset >= 0)
	var table := bytes.slice(offset, offset + 16)
	assert(table == PackedByteArray(ZONE_CLASSES))
	print("Confirmed supplied zone classes at 0x004e77b8: ", table)
	var count := 0
	for archive_name in ["LARGE.DAT", "SMALLMED.DAT", "SPECIAL.DAT"]:
		var archive := Sc2SpriteArchive.load_path("res://../references/DATA/" + archive_name)
		assert(archive.is_valid(), archive.parse_error)
		for entry in archive.entries:
			if entry.sprite_id % 500 not in range(300, 305) and entry.sprite_id % 500 not in range(354, 359) and entry.sprite_id % 500 not in range(468, 478):
				continue
			var colors := {}
			var pixels: PackedInt32Array = entry.decode_indices().pixels
			for index in pixels:
				if index < 0:
					continue
				assert(index < 171 or index >= 239, "these archive overlays must stay static")
				colors[index] = int(colors.get(index, 0)) + 1
			print("%d: %dx%d, %d opaque, colors %s" % [entry.sprite_id, entry.width, entry.height, pixels.size() - pixels.count(-1), str(colors)])
			count += 1
	assert(count == 60)
	print("PASS: 60 static overlay records and supplied zone-class table")
	quit()
