class_name TerrainFeatures
extends RefCounted


@warning_ignore_start("integer_division")

static func carve(heights: PackedInt32Array, flags: PackedByteArray, sea: int, features: Array, ocean: bool, river: bool, random: GameLcgRandom, water: int, hills: int = 12) -> void:
	var wetness := float(water) / 47.0
	var angle := float(random.next_mod(6283)) / 1000.0
	var phase := float(random.next_mod(6283)) / 1000.0
	var split := -0.18 + float(random.next_mod(280)) / 1000.0
	var bend := -0.12 + float(random.next_mod(240)) / 1000.0
	var width := lerpf(0.022, 0.052, wetness)
	var islands := "island" in features or "islands" in features
	var paths: Array[PackedVector2Array] = []
	var junction := Vector2(bend, split)
	var delta := "delta" in features and not islands
	var mouth := Vector2(0.0, 0.02 if delta else 0.9)

	if not islands:
		if "rejoin" in features:
			var start := Vector2(bend, -0.30)
			var end := Vector2(bend * -0.5, -0.08 if delta else 0.30)
			paths.append(_channel(Vector2(-bend, -0.9), start, 0.04, phase))
			paths.append(_channel(start, end, -0.18, phase))
			paths.append(_channel(start, end, 0.20, phase + 1.0))
			paths.append(_channel(end, mouth, 0.04, phase))
			junction = end
		elif river or "crossing" in features or "branch" in features:
			paths.append(_channel(junction, mouth, 0.055, phase))
			paths.append(_channel(Vector2(-bend, -0.9), junction, 0.075, phase + 1.3))

		if "branch" in features:
			paths.append(_channel(Vector2(-0.72, -0.80), junction, -0.08, phase + 2.4))

		if "crossing" in features:
			# one tributary ends at the shared channel: a t, not an x
			var side := -1.0 if random.next_mod(2) == 0 else 1.0
			paths.append(_channel(Vector2(side * 0.9, split - 0.12), junction, 0.08, phase + 0.8))

	if delta:
		# distributaries fan out from one shared river mouth into the coast
		for branch in 3:
			var spread := (float(branch) - 1.0) * 0.42
			var end := Vector2(spread + 0.04 * sin(phase + branch), 0.9)
			paths.append(_channel(mouth, end, spread * 0.20, phase + branch))

	if "peninsula" in features and not islands:
		# route the shared river beside the neck instead of through the headland
		for index in paths.size():
			for point_index in paths[index].size():
				paths[index][point_index].x -= 0.24

	var oxbows: Array[PackedVector2Array] = []

	if "meander" in features and not islands:
		oxbows = _meander_channels(paths, width, angle, phase, random)

	var noise := FastNoiseLite.new()

	noise.seed = random.next_mod(2147483647)
	noise.frequency = 7.0
	noise.fractal_octaves = 3

	var scale := lerpf(1.08, 0.83, wetness)

	for x in 128:
		for y in 128:
			var point := (Vector2(x, y) / 127.0 - Vector2(0.5, 0.5)).rotated(-angle)
			var rough := noise.get_noise_2d(point.x, point.y)
			var wet := false

			if islands:
				var distance: float

				if "islands" in features:
					var first := _island_distance(point, Vector2(-0.235, -0.06), Vector2(0.165, 0.28) * scale, phase)
					var second := _island_distance(point, Vector2(0.235, 0.075), Vector2(0.16, 0.255) * scale, phase + 2.1)
					distance = minf(first, second)
				else:
					distance = _island_distance(point, Vector2.ZERO, Vector2(0.34, 0.30) * scale, phase)

				wet = distance + rough * 0.05 > 0.0

				if "bay" in features:
					var inlet_center := Vector2(-0.235, 0.19) if "islands" in features else Vector2(0.03, 0.34)
					var inlet := ((point - inlet_center) / Vector2(0.09, 0.18)).length()
					wet = wet or inlet < 1.0 + rough * 0.15

				# always retain a continuous ocean at the map border
				wet = wet or x < 3 or y < 3 or x > 124 or y > 124
			else:
				if ocean:
					wet = point.y > lerpf(0.34, 0.23, wetness) + rough * 0.12 + 0.04 * sin(point.x * 12.0 + phase)

				if "bay" in features:
					var bay_center := 0.86 if delta else 0.64
					var bay := Vector2(point.x / lerpf(0.27, 0.36, wetness), (point.y - bay_center) / lerpf(0.65, 0.77, wetness)).length()
					wet = wet or bay < 1.0 + rough * 0.20 + 0.08 * sin(point.x * 19.0 + phase)

				if "peninsula" in features:
					var axis := 0.08 + 0.04 * sin(point.y * 8.0 + phase)
					var neck_width := lerpf(0.17, 0.14, wetness) * (1.0 + 0.13 * sin(point.y * 12.0 + phase) + rough * 0.20)
					var neck := (point.x - axis) / neck_width
					var coast := lerpf(-0.20, -0.25, wetness) + 0.55 * exp(-pow(absf(neck), 4.0)) + rough * 0.045 + 0.016 * sin(point.x * 23.0 + point.y * 13.0 + phase)
					# keep the headland attached to the mainland; channels can cross it
					wet = point.y > coast

					if "bay" in features and point.x < axis - 0.15:
						wet = wet or point.y > -0.28 + rough * 0.06

				if not wet:
					var local_width := width * (1.0 + rough * 0.50 + 0.12 * sin(point.y * 31.0 + phase))

					if "meander" in features:
						local_width = width * (1.0 + rough * 0.20 + 0.06 * sin(point.y * 10.0 + phase))

					for path in paths:
						if _near_channel(point, path, local_width):
							wet = true
							break

			var index := x * 128 + y

			if wet:
				heights[index] = maxi(0, sea - 2)

				if ocean or islands or "bay" in features:
					flags[index] |= 1
			else:
				heights[index] = maxi(heights[index], sea + 1)

	_keep_main_water(heights, flags, sea)

	# preserve intentional abandoned bends after removing accidental coast pools
	for lake in oxbows:
		for x in 128:
			for y in 128:
				var point := (Vector2(x, y) / 127.0 - Vector2(0.5, 0.5)).rotated(-angle)

				if _near_channel(point, lake, 0.012):
					var index := x * 128 + y
					heights[index] = maxi(0, sea - 2)
					flags[index] = 0

	if "lake" in features or "lakes" in features:
		TerrainLakes.carve(heights, flags, sea, 2 if "lakes" in features else 1, random, water)

	TerrainElevation.apply(heights, sea, features, angle, phase, noise, hills)


static func _meander_channels(paths: Array[PackedVector2Array], width: float, angle: float, phase: float, random: GameLcgRandom) -> Array[PackedVector2Array]:
	var amplitude := 0.19 + float(random.next_mod(60)) / 1000.0
	var frequency := TAU * (1.45 + float(random.next_mod(350)) / 1000.0)
	var bends: Array[Vector2] = []

	for path_index in paths.size():
		var path := paths[path_index]

		for index in path.size():
			var point := path[index]
			var fade := smoothstep(0.9, 0.6, absf(point.y))
			point.x += fade * amplitude * sin(point.y * frequency + phase)
			path[index] = point

		paths[path_index] = path

		for index in range(1, path.size() - 1):
			var point := path[index]

			if absf(point.x) < 0.12 or absf(point.y) > 0.32:
				continue

			if (point.x - path[index - 1].x) * (path[index + 1].x - point.x) < 0.0:
				bends.append(point)

	var lakes: Array[PackedVector2Array] = []

	# most maps have no oxbows. a suitable bend is still required on selected maps
	if bends.is_empty() or random.next_mod(100) >= 35:
		return lakes

	var first := random.next_mod(bends.size())
	var limit := 1 + random.next_mod(2)

	for attempt in bends.size():
		var point := bends[(first + attempt) % bends.size()]
		var side := signf(point.x)
		var center := point + Vector2(side * (width * 1.5 + 0.07), 0.0)
		var lake := PackedVector2Array()
		var clear := true

		for index in 17:
			var t := -PI * 0.5 + PI * float(index) / 16.0
			var sample := center + Vector2(side * 0.045 * cos(t), 0.055 * sin(t))
			var world := sample.rotated(angle)

			if absf(world.x) > 0.46 or absf(world.y) > 0.46:
				clear = false

			for path in paths:
				if _near_channel(sample, path, width * 1.5 + 0.04):
					clear = false

			lake.append(sample)

		if clear:
			lakes.append(lake)

		if lakes.size() >= limit:
			break

	return lakes


static func _island_distance(point: Vector2, center: Vector2, radius: Vector2, phase: float) -> float:
	var local := (point - center) / radius
	var angle := local.angle()
	var edge := 1.0 + 0.17 * sin(3.0 * angle + phase) + 0.10 * sin(5.0 * angle - phase * 1.7) + 0.045 * sin(9.0 * angle + phase * 2.3)

	return local.length() - edge


static func _channel(start: Vector2, end: Vector2, bend: float, phase: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var normal := (end - start).normalized().orthogonal()

	for step in 33:
		var t := float(step) / 32.0
		var meander := sin(t * PI) * (bend + 0.026 * sin(t * TAU * 1.5 + phase))
		points.append(start.lerp(end, t) + normal * meander)

	return points


static func _near_channel(point: Vector2, path: PackedVector2Array, width: float) -> bool:
	for index in range(1, path.size()):
		var a := path[index - 1]
		var b := path[index]

		if point.x < minf(a.x, b.x) - width or point.x > maxf(a.x, b.x) + width:
			continue

		if point.y < minf(a.y, b.y) - width or point.y > maxf(a.y, b.y) + width:
			continue

		if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point, a, b)) <= width * width:
			return true

	return false


static func _keep_main_water(heights: PackedInt32Array, flags: PackedByteArray, sea: int) -> void:
	# fine coast noise can cut off a few pixels. keep the connected water body
	var seen := PackedByteArray()

	seen.resize(128 * 128)

	var largest := PackedInt32Array()

	for index in heights.size():
		if seen[index] or heights[index] >= sea:
			continue

		var queue := PackedInt32Array([index])
		seen[index] = 1
		var cursor := 0

		while cursor < queue.size():
			var current := queue[cursor]

			cursor += 1

			var x := current / 128
			var y := current % 128

			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near: Vector2i = Vector2i(x, y) + offset

				if near.x < 0 or near.y < 0 or near.x >= 128 or near.y >= 128:
					continue

				var next := near.x * 128 + near.y

				if not seen[next] and heights[next] < sea:
					seen[next] = 1
					queue.append(next)

		if queue.size() > largest.size():
			largest = queue

	seen.fill(0)

	for index in largest:
		seen[index] = 1

	for index in heights.size():
		if heights[index] < sea and not seen[index]:
			heights[index] = sea + 1
			flags[index] = 0
