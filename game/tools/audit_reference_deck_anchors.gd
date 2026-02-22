extends SceneTree
## Summarize sprite positions from the archive.


func _initialize() -> void:
	var archive := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	assert(archive.is_valid(), archive.parse_error)
	for base in [29, 30, 73, 74, 81, 87, 88, 93, 94, 95, 96, 97, 98, 99, 100, 101, 105, 106, 107]:
		var entry := archive.find_sprite(base + 1000)
		var decoded := entry.decode_indices()
		var count := 0
		var sum_y := 0.0
		var low := Vector2i(999, 999)
		var high := Vector2i(-1, -1)
		for i in decoded.pixels.size():
			if decoded.pixels[i] == 0xa1:
				var x: int = i % entry.width
				var y := int(i / entry.width)
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
				sum_y += y
				count += 1
		var baseline_offset := 8 if base >= 97 and base <= 107 else 0
		print("%d deck_count=%d bounds=%s..%s mean_relative_y=%.2f" % [base, count, low, high, sum_y / maxi(count, 1) + 17 - entry.height + baseline_offset])
	quit()
