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
			# The source landform has 128 tiles per side. Index x * edge + y.
			var a := lerpf(source[left * 128 + top], source[right * 128 + top], u - left)
			var b := lerpf(source[left * 128 + bottom], source[right * 128 + bottom], u - left)
			var index := x * edge + y

			result[index] = roundi(lerpf(a, b, v - top))
			flags[index] = coast[roundi(u) * 128 + roundi(v)]

	return result


static func _grade_layout(heights: PackedInt32Array, edge := 128) -> void:
	# native slopes span at most one level across a tile, including diagonals
	# two distance-transform sweeps constrain all eight neighbors
	# Index x * edge + y. Each sweep reads the neighbors that it has already updated.
	for x in edge:
		for y in edge:
			var index := x * edge + y
			var height := heights[index]

			if x > 0:
				var previous_row := index - edge
				height = mini(height, heights[previous_row] + 1)

				if y > 0:
					height = mini(height, heights[previous_row - 1] + 1)

				if y + 1 < edge:
					height = mini(height, heights[previous_row + 1] + 1)

			if y > 0:
				height = mini(height, heights[index - 1] + 1)

			heights[index] = height

	for x in range(edge - 1, -1, -1):
		for y in range(edge - 1, -1, -1):
			var index := x * edge + y
			var height := heights[index]

			if x + 1 < edge:
				var next_row := index + edge
				height = mini(height, heights[next_row] + 1)

				if y > 0:
					height = mini(height, heights[next_row - 1] + 1)

				if y + 1 < edge:
					height = mini(height, heights[next_row + 1] + 1)

			if y + 1 < edge:
				height = mini(height, heights[index + 1] + 1)

			heights[index] = height


static func _fill_unsupported_slopes(heights: PackedInt32Array, edge: int) -> void:
	# The sprite set has no opposite-corner saddle. Fill these depressions
	# and propagate a one-level diagonal grade before choosing slope sprites.
	var queue := PackedInt32Array()
	var pending := PackedByteArray()

	pending.resize(edge * edge)
	pending.fill(1)

	for index in heights.size():
		queue.append(index)

	# Neighbor steps and masks in TerrainTools order. Index x * edge + y.
	var steps_x := PackedInt32Array()
	var steps_y := PackedInt32Array()
	var masks := PackedInt32Array(TerrainTools.NEIGHBOR_MASKS)

	for offset: Vector2i in TerrainTools.NEIGHBOR_OFFSETS:
		steps_x.append(offset.x)
		steps_y.append(offset.y)

	var cursor := 0

	while cursor < queue.size():
		var index := queue[cursor]

		cursor += 1
		pending[index] = 0

		var x := index / edge
		var y := index % edge
		var height := heights[index]
		var mask := 0
		var maximum := height

		for neighbor in 8:
			var near_x := x + steps_x[neighbor]
			var near_y := y + steps_y[neighbor]

			if near_x >= 0 and near_x < edge and near_y >= 0 and near_y < edge:
				var near_height := heights[near_x * edge + near_y]
				maximum = maxi(maximum, near_height)

				if near_height > height:
					mask |= masks[neighbor]

		var target := maxi(height, maximum - 1)

		if mask == 5 or mask == 10 or mask == 15:
			target = maxi(target, height + 1)

		if target == height:
			continue

		heights[index] = target

		for neighbor in 8:
			var near_x := x + steps_x[neighbor]
			var near_y := y + steps_y[neighbor]

			if near_x >= 0 and near_x < edge and near_y >= 0 and near_y < edge:
				var next := near_x * edge + near_y

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

	# Index x * map_edge + y.
	for x in map_edge:
		for y in map_edge:
			var index := x * map_edge + y
			var center := source[index]
			var north := source[index - 1] if y > 0 else center
			var east := source[index + map_edge] if x < map_edge - 1 else center
			var south := source[index + 1] if y < map_edge - 1 else center
			var west := source[index - map_edge] if x > 0 else center
			heights[index] = (((north + east + south + west) >> 2) + center) >> 1


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
	# Index x * map_edge + y. Visit neighbors in CARDINAL_OFFSETS order: north, east, south, west.
	var index := x * map_edge + y
	var current := heights[index]

	if not ((y > 0 and heights[index - 1] + 1 < current)
			or (x + 1 < map_edge and heights[index + map_edge] + 1 < current)
			or (y + 1 < map_edge and heights[index + 1] + 1 < current)
			or (x > 0 and heights[index - map_edge] + 1 < current)):
		return

	current -= 1
	heights[index] = current

	if y > 0 and current < heights[index - 1]:
		_grade_cell(heights, x, y - 1, map_edge)

	if x + 1 < map_edge and current < heights[index + map_edge]:
		_grade_cell(heights, x + 1, y, map_edge)

	if y + 1 < map_edge and current < heights[index + 1]:
		_grade_cell(heights, x, y + 1, map_edge)

	if x > 0 and current < heights[index - map_edge]:
		_grade_cell(heights, x - 1, y, map_edge)
