class_name GraphicsPackAvailability
extends RefCounted



class Count extends RefCounted:
	var valid := 0
	var total := 0


class Result extends RefCounted:
	var sizes: Array[Count] = []


static func inspect(small_medium: Sc2SpriteArchive, large: Sc2SpriteArchive) -> Result:
	var sizes: Array[Count] = []

	for view in 3:
		var archive := large if view == 2 else small_medium
		var counts := Count.new()

		if archive != null:
			for entry in archive.entries:
				if view == 2 or (entry.sprite_id >= view * 500 and entry.sprite_id < (view + 1) * 500):
					counts.total += 1

					if entry.decode_indices().ok:
						counts.valid += 1

		sizes.append(counts)

	var result := Result.new()
	result.sizes = sizes

	return result
