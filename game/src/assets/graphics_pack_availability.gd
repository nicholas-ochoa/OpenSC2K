class_name GraphicsPackAvailability
extends RefCounted



static func inspect(small_medium: Sc2SpriteArchive, large: Sc2SpriteArchive) -> Dictionary:
	var sizes: Array[Dictionary] = []

	for view in 3:
		var archive := large if view == 2 else small_medium
		var counts := {"valid": 0, "total": 0}

		if archive != null:
			for entry in archive.entries:
				if view == 2 or (entry.sprite_id >= view * 500 and entry.sprite_id < (view + 1) * 500):
					counts.total += 1

					if entry.decode_indices().ok:
						counts.valid += 1

		sizes.append(counts)

	return {"sizes": sizes}
