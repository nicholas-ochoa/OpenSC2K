class_name NewTerrainHeights
extends NewTerrainConstants


@warning_ignore_start("integer_division")


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
