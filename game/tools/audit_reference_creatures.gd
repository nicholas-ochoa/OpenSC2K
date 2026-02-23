extends SceneTree
## Print creature metadata.


func _initialize() -> void:
	var roles := {385: "monster attack", 478: "monster part 0", 479: "monster part 1", 480: "monster part 2", 481: "monster part 3", 482: "monster part 4", 483: "monster part 5", 484: "monster part 6", 485: "monster part 7", 486: "monster part 8", 487: "monster part 9", 488: "monster part 10", 489: "monster part 11", 490: "monster part 12", 491: "monster part 13", 495: "superhero", 497: "tornado 0", 498: "tornado 1", 499: "tornado 2"}

	for archive_name in ["LARGE.DAT", "SMALLMED.DAT", "SPECIAL.DAT"]:
		var archive := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/" + archive_name)
		assert(archive.is_valid(), archive.parse_error)

		for entry in archive.entries:
			var base := entry.sprite_id % 500

			if not roles.has(base):
				continue

			var pixels: PackedInt32Array = entry.decode_indices().pixels
			var colors := {}
			var cycles := {}
			var bounds := Rect2i()
			var bottom_x := []

			for i in pixels.size():
				var index := int(pixels[i])

				if index < 0:
					continue

				colors[index] = int(colors.get(index, 0)) + 1

				if index in range(171, 239):
					cycles[index] = int(cycles.get(index, 0)) + 1

				var point := Vector2i(i % entry.width, i / entry.width)

				if point.y == entry.height - 1:
					bottom_x.append(point.x)

				bounds = bounds.merge(Rect2i(point, Vector2i.ONE)) if bounds.has_area() else Rect2i(point, Vector2i.ONE)

			print("%d %s: %dx%d, %d opaque, bounds %s, colors %s, cycles %s" % [entry.sprite_id, str(roles[base]), entry.width, entry.height, pixels.size() - pixels.count(-1), str(bounds), str(colors), str(cycles)])
			print("  bottom-row x bounds: %s" % str([bottom_x.min(), bottom_x.max()]))

	quit()
