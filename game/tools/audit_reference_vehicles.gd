extends SceneTree
## Print dimensions, opaque bounds, and palette counts.


func _initialize() -> void:
	for archive_name in ["LARGE.DAT", "SMALLMED.DAT", "SPECIAL.DAT"]:
		var archive := Sc2SpriteArchive.load_path("res://../references/DATA/" + archive_name)
		assert(archive.is_valid(), archive.parse_error)
		for entry in archive.entries:
			var base := entry.sprite_id % 500
			if not (base in range(359, 374) or base in range(379, 386) or base in [390, 391]):
				continue
			var pixels: PackedInt32Array = entry.decode_indices().pixels
			var cycles := {}
			var minimum := Vector2i(entry.width, entry.height)
			var maximum := Vector2i(-1, -1)
			for i in pixels.size():
				var index := int(pixels[i])
				if index < 0:
					continue
				var point := Vector2i(i % entry.width, i / entry.width)
				minimum = minimum.min(point)
				maximum = maximum.max(point)
				if index in range(171, 239):
					cycles[index] = int(cycles.get(index, 0)) + 1
			print("Sprite %d: %dx%d, %d opaque, bounds %s..%s, cycles %s" % [entry.sprite_id, entry.width, entry.height, pixels.size() - pixels.count(-1), str(minimum), str(maximum), str(cycles)])
	print("Eight-direction poses: NW, N, NE, E, SE; S/SW/W mirror E/NE/N.")
	print("Four-direction poses: N, E; S/W mirror E/N. Distressed sailboat uses 1379.")
	quit()
