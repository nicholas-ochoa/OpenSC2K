class_name TerrainLakes
extends RefCounted


static func carve(heights: PackedInt32Array, flags: PackedByteArray, sea: int, count: int, random: GameLcgRandom, water: int) -> void:
	for lake in count:
		var distance := TerrainElevation._water_distances(heights, sea)
		var preferred := Vector2(24 + random.next_mod(80), 24 + random.next_mod(80))
		var phase := float(random.next_mod(6283)) / 1000.0
		var desired := lerpf(10.0, 30.0, float(water) / 47.0) if count == 2 else lerpf(13.0, 20.0, float(water) / 47.0)
		var center := Vector2.ZERO
		var clearance := 0.0
		var best := -INF

		for x in range(8, 120, 2):
			for y in range(8, 120, 2):
				if heights[x * 128 + y] < sea:
					continue

				var space := minf(float(distance[x * 128 + y]) * 0.7, mini(mini(x, y), mini(127 - x, 127 - y)))
				var score := minf(space, desired + 4.0) * 4.0 - Vector2(x, y).distance_to(preferred) * 0.03

				if score > best:
					best = score
					center = Vector2(x, y)
					clearance = space

		if clearance < 3.0:
			continue

		var radius := minf(desired, clearance * 0.75)

		for x in 128:
			for y in 128:
				var point := (Vector2(x, y) - center) / Vector2(radius, radius * 0.85)
				var angle := point.angle()
				var edge := 1.0 + 0.10 * sin(angle * 3.0 + phase) + 0.06 * sin(angle * 5.0 - phase)

				if point.length() < edge:
					heights[x * 128 + y] = maxi(0, sea - 2)
					flags[x * 128 + y] = 0
