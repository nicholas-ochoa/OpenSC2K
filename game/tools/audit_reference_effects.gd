extends SceneTree
## Print effect metadata.


func _initialize() -> void:
	var roles := {387: "explosion 0", 388: "explosion 1", 389: "explosion 2", 392: "dust tall", 393: "dust medium", 394: "dust low", 395: "dust short", 396: "fire 0", 397: "fire 1", 398: "fire 2", 399: "fire 3", 492: "flood", 493: "riot 0", 494: "riot 1", 496: "toxic cloud"}
	for archive_name in ["LARGE.DAT", "SMALLMED.DAT", "SPECIAL.DAT"]:
		var archive := Sc2SpriteArchive.load_path("res://../references/DATA/" + archive_name)
		assert(archive.is_valid(), archive.parse_error)
		for entry in archive.entries:
			var base := entry.sprite_id % 500
			if not roles.has(base):
				continue
			var pixels: PackedInt32Array = entry.decode_indices().pixels
			var colors := {}
			var cycles := {}
			var bounds := Rect2i()
			for i in pixels.size():
				var index := int(pixels[i])
				if index < 0:
					continue
				colors[index] = int(colors.get(index, 0)) + 1
				if index in range(171, 239):
					cycles[index] = int(cycles.get(index, 0)) + 1
				var point := Vector2i(i % entry.width, i / entry.width)
				bounds = bounds.merge(Rect2i(point, Vector2i.ONE)) if bounds.has_area() else Rect2i(point, Vector2i.ONE)
			print("%d %s: %dx%d, %d opaque, bounds %s, colors %s, cycles %s" % [entry.sprite_id, str(roles[base]), entry.width, entry.height, pixels.size() - pixels.count(-1), str(bounds), str(colors), str(cycles)])
	quit()
