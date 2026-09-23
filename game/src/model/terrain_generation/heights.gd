class_name NewTerrainHeights
extends NewTerrainConstants


@warning_ignore_start("integer_division")


static func _enlarge_landform(source: PackedInt32Array, coast: PackedByteArray, flags: PackedByteArray, edge: int) -> PackedInt32Array:
	var result := PackedInt32Array()

	result.resize(edge * edge)

	for x in edge:
		var u := float(x) * 127.0 / float(edge - 1)
		var left := floori(u)
		var right := mini(left + 1, 127)

		for y in edge:
			var v := float(y) * 127.0 / float(edge - 1)
			var top := floori(v)
			var bottom := mini(top + 1, 127)
			var a := lerpf(source[NewTerrainValues._index(left, top)], source[NewTerrainValues._index(right, top)], u - left)
			var b := lerpf(source[NewTerrainValues._index(left, bottom)], source[NewTerrainValues._index(right, bottom)], u - left)

			result[NewTerrainValues._index(x, y, edge)] = roundi(lerpf(a, b, v - top))
			flags[NewTerrainValues._index(x, y, edge)] = coast[NewTerrainValues._index(roundi(u), roundi(v))]

	return result


static func _grade_layout(heights: PackedInt32Array, edge := 128) -> void:
	# native slopes span at most one level across a tile, including diagonals
	# two distance-transform sweeps constrain all eight neighbors
	for x in edge:
		for y in edge:
			var index := NewTerrainValues._index(x, y, edge)

			for offset in [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -1)]:
				var near: Vector2i = Vector2i(x, y) + offset

				if NewTerrainValues._in_bounds(near, edge):
					heights[index] = mini(heights[index], heights[NewTerrainValues._index(near.x, near.y, edge)] + 1)

	for x in range(edge - 1, -1, -1):
		for y in range(edge - 1, -1, -1):
			var index := NewTerrainValues._index(x, y, edge)

			for offset in [Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 1)]:
				var near: Vector2i = Vector2i(x, y) + offset

				if NewTerrainValues._in_bounds(near, edge):
					heights[index] = mini(heights[index], heights[NewTerrainValues._index(near.x, near.y, edge)] + 1)


static func _fill_unsupported_slopes(heights: PackedInt32Array, edge: int) -> void:
	# The sprite set has no opposite-corner saddle. Fill these depressions
	# and propagate a one-level diagonal grade before choosing slope sprites.
	var queue := PackedInt32Array()
	var pending := PackedByteArray()

	pending.resize(edge * edge)
	pending.fill(1)

	for index in heights.size():
		queue.append(index)

	var cursor := 0

	while cursor < queue.size():
		var index := queue[cursor]

		cursor += 1
		pending[index] = 0

		var point := Vector2i(index / edge, index % edge)
		var mask := 0
		var maximum := heights[index]

		for neighbor in TerrainTools.NEIGHBOR_OFFSETS.size():
			var near: Vector2i = point + TerrainTools.NEIGHBOR_OFFSETS[neighbor]

			if NewTerrainValues._in_bounds(near, edge):
				var height := heights[NewTerrainValues._index(near.x, near.y, edge)]
				maximum = maxi(maximum, height)

				if height > heights[index]:
					mask |= TerrainTools.NEIGHBOR_MASKS[neighbor]

		var target := maxi(heights[index], maximum - 1)

		if mask in [5, 10, 15]:
			target = maxi(target, heights[index] + 1)

		if target == heights[index]:
			continue

		heights[index] = target

		for offset in TerrainTools.NEIGHBOR_OFFSETS:
			var near: Vector2i = point + offset

			if NewTerrainValues._in_bounds(near, edge):
				var next := NewTerrainValues._index(near.x, near.y, edge)

				if not pending[next]:
					pending[next] = 1
					queue.append(next)


static func _seed_hills(
	heights: PackedInt32Array, maximum: int, random: SimRandom,
	map_edge: int = 128,
) -> void:
	for x in range(0, map_edge, 16):
		for y in range(0, map_edge, 16):
			heights[NewTerrainValues._index(x, y, map_edge)] = random.next_u15() % maximum + 1


static func _interpolate(
	heights: PackedInt32Array,
	step: int,
	mask: int,
	edge_height: int,
	has_ocean: bool,
	random: SimRandom,
	map_edge: int = 128,
) -> void:
	for x in range(0, map_edge, step):
		var x_is_midpoint := (mask & x) != 0

		for y in range(0, map_edge, step):
			var y_is_midpoint := (mask & y) != 0

			if not x_is_midpoint and not y_is_midpoint:
				continue

			var variation := random.next_u15() % step
			var value := 0

			if x_is_midpoint and y_is_midpoint:
				value = (
					_neighbor_height(heights, x - step, y + step, edge_height, has_ocean, map_edge)
					+ _neighbor_height(heights, x + step, y + step, edge_height, has_ocean, map_edge)
					+ _neighbor_height(heights, x - step, y - step, edge_height, has_ocean, map_edge)
					+ _neighbor_height(heights, x + step, y - step, edge_height, has_ocean, map_edge)
				) >> 2
			elif y_is_midpoint:
				value = (
					_neighbor_height(heights, x, y + step, edge_height, has_ocean, map_edge)
					+ _neighbor_height(heights, x, y - step, edge_height, has_ocean, map_edge)
				) >> 1
			else:
				value = (
					_neighbor_height(heights, x - step, y, edge_height, has_ocean, map_edge)
					+ _neighbor_height(heights, x + step, y, edge_height, has_ocean, map_edge)
				) >> 1

			heights[NewTerrainValues._index(x, y, map_edge)] = maxi(1, value + variation)


static func _neighbor_height(
	heights: PackedInt32Array,
	x: int,
	y: int,
	edge_height: int,
	has_ocean: bool,
	map_edge: int = 128,
) -> int:
	if x < 0 or y < 0 or y >= map_edge:
		return edge_height

	if x >= map_edge:
		return 0 if has_ocean else edge_height

	return heights[NewTerrainValues._index(x, y, map_edge)]


static func _carve_ocean(
	heights: PackedInt32Array,
	flags: PackedByteArray,
	water_level: int,
	random: GameLcgRandom,
	map_edge: int = 128,
) -> void:
	var width := random.next_mod(10) + 10

	for y in map_edge:
		var bank_x := map_edge - width
		heights[NewTerrainValues._index(bank_x, y, map_edge)] = water_level - 2

		for x in range(bank_x + 1, map_edge):
			heights[NewTerrainValues._index(x, y, map_edge)] = water_level - 3
			flags[NewTerrainValues._index(x, y, map_edge)] |= FLAG_SALT_WATER

		var target := random.next_mod(30)

		if width < target:
			width += 1
		elif target < width:
			width -= 1


static func _carve_river(
	heights: PackedInt32Array, water_level: int, random: GameLcgRandom,
	map_edge: int = 128,
) -> void:
	var center := map_edge / 2
	var bend := random.next_mod(3) - 1

	for y in range(map_edge - 1, -1, -1):
		for x in range(center - 3, center + 4):
			heights[NewTerrainValues._index(x, y, map_edge)] = water_level - 3

		heights[NewTerrainValues._index(center - 4, y, map_edge)] = water_level - 2
		heights[NewTerrainValues._index(center + 4, y, map_edge)] = water_level - 2

		if random.next_mod(8) == 0:
			bend = random.next_mod(3) - 1

		center += bend + random.next_mod(3) - 1
		center = clampi(center, 5, map_edge - 6)


static func _smooth(heights: PackedInt32Array, map_edge: int = 128) -> void:
	var source := heights.duplicate()

	for x in map_edge:
		for y in map_edge:
			var center := source[NewTerrainValues._index(x, y, map_edge)]
			var north := source[NewTerrainValues._index(x, y - 1, map_edge)] if y > 0 else center
			var east := source[NewTerrainValues._index(x + 1, y, map_edge)] if x < map_edge - 1 else center
			var south := source[NewTerrainValues._index(x, y + 1, map_edge)] if y < map_edge - 1 else center
			var west := source[NewTerrainValues._index(x - 1, y, map_edge)] if x > 0 else center
			heights[NewTerrainValues._index(x, y, map_edge)] = (((north + east + south + west) >> 2) + center) >> 1


static func _scale_heights(heights: PackedInt32Array, map_edge: int = 128) -> void:
	for index in (map_edge * map_edge):
		var scaled := (heights[index] + 3) >> 1
		var shifted := scaled - 4

		if shifted >= 4:
			heights[index] = shifted
		elif shifted >= 0:
			heights[index] = 4
		else:
			heights[index] = scaled


static func _grade_heights(heights: PackedInt32Array, map_edge: int = 128) -> void:
	for x in map_edge:
		for y in map_edge:
			_grade_cell(heights, x, y, map_edge)


static func _grade_cell(heights: PackedInt32Array, x: int, y: int, map_edge: int = 128) -> void:
	var index := NewTerrainValues._index(x, y, map_edge)
	var current := heights[index]
	var must_lower := false

	for offset in CARDINAL_OFFSETS:
		var near: Vector2i = Vector2i(x, y) + offset

		if NewTerrainValues._in_bounds(near, map_edge) and heights[NewTerrainValues._index(near.x, near.y, map_edge)] + 1 < current:
			must_lower = true
			break

	if not must_lower:
		return

	current -= 1
	heights[index] = current

	for offset in CARDINAL_OFFSETS:
		var near: Vector2i = Vector2i(x, y) + offset

		if NewTerrainValues._in_bounds(near, map_edge) and current < heights[NewTerrainValues._index(near.x, near.y, map_edge)]:
			_grade_cell(heights, near.x, near.y, map_edge)
