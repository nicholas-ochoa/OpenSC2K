class_name TerrainEditHeights
extends TerrainEditConstants



class Plan extends RefCounted:
	var valid := false
	var insufficient := false
	var heights := PackedInt32Array()
	var modified := PackedInt32Array()
	var zone_indices := PackedInt32Array()
	var funds := 0
	var cost := 0

	static func invalid(insufficient_funds := false) -> Plan:
		var result := Plan.new()
		result.insufficient = insufficient_funds

		return result


static func plan_raise(
	heights: PackedInt32Array,
	zones: PackedByteArray,
	buildings: PackedByteArray,
	start: Vector2i,
	funds: int,
	map_edge: int = 128,
) -> Plan:
	var visiting: Dictionary[int, bool] = {}
	var visited: Dictionary[int, bool] = {}
	var postorder: Array[Vector2i] = []

	if not _collect_raise_dependencies(heights, zones, start, visiting, visited, postorder, map_edge):
		return Plan.invalid()

	var trial := heights.duplicate()
	var modified := PackedInt32Array()
	var zone_indices := PackedInt32Array()
	var remaining := funds
	var cost := 0

	for point in postorder:
		if remaining < 25:
			continue

		var index := point.x * map_edge + point.y
		trial[index] += 1
		remaining -= 25
		cost += 25
		zone_indices.append(index)

		if not modified.has(index):
			modified.append(index)

		_normalize_cardinal_slopes(trial, buildings, point, modified, map_edge)

	if cost == 0:
		return Plan.invalid(true)

	var result := Plan.new()
	result.valid = true
	result.heights = trial
	result.modified = modified
	result.zone_indices = zone_indices
	result.funds = remaining
	result.cost = cost

	return result


static func _collect_raise_dependencies(
	heights: PackedInt32Array,
	zones: PackedByteArray,
	point: Vector2i,
	visiting: Dictionary[int, bool],
	visited: Dictionary[int, bool],
	postorder: Array[Vector2i],
	map_edge: int = 128,
) -> bool:
	var index := point.x * map_edge + point.y

	if visited.has(index):
		return true

	if visiting.has(index):
		return true

	if (zones[index] & 0x0f) == MILITARY_ZONE or heights[index] > MAX_RAISE_SOURCE:
		return false

	for offset in NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = point + offset

		if _point_is_in_bounds(neighbor, map_edge):
			var neighbor_index := neighbor.x * map_edge + neighbor.y

			if (zones[neighbor_index] & 0x0f) == MILITARY_ZONE:
				return false

	visiting[index] = true

	for offset in RAISE_DEPENDENCY_OFFSETS:
		var neighbor: Vector2i = point + offset

		if not _point_is_in_bounds(neighbor, map_edge):
			continue

		var neighbor_index := neighbor.x * map_edge + neighbor.y

		if heights[neighbor_index] < heights[index]:
			if not _collect_raise_dependencies(
				heights, zones, neighbor, visiting, visited, postorder, map_edge
			):
				return false

	visiting.erase(index)
	visited[index] = true
	postorder.append(point)

	return true


static func _normalize_cardinal_slopes(
	heights: PackedInt32Array,
	buildings: PackedByteArray,
	point: Vector2i,
	modified: PackedInt32Array,
	map_edge: int = 128,
) -> void:
	var index := point.x * map_edge + point.y

	for offset in CARDINAL_OFFSETS:
		var neighbor: Vector2i = point + offset

		if not _point_is_in_bounds(neighbor, map_edge):
			continue

		var neighbor_index := neighbor.x * map_edge + neighbor.y

		if buildings[neighbor_index] >= BuildingTileIds.SMALL_PARK:
			continue

		var difference := heights[index] - heights[neighbor_index]

		if difference >= 2:
			heights[neighbor_index] = heights[index] - 1
		elif difference <= -2:
			heights[neighbor_index] = heights[index] + 1
		else:
			continue

		if not modified.has(neighbor_index):
			modified.append(neighbor_index)

		_normalize_cardinal_slopes(heights, buildings, neighbor, modified, map_edge)


static func _plan_lower(
	heights: PackedInt32Array, start: Vector2i, funds: int,
	map_edge: int = 128,
) -> Plan:
	if funds < 25:
		return Plan.invalid(true)

	var start_index := start.x * map_edge + start.y

	if heights[start_index] == 0:
		return Plan.invalid()

	var trial := heights.duplicate()
	var queue: Array[Vector2i] = []
	queue.resize(512)
	var queue_head := 0
	var queue_tail := 1
	queue[0] = start
	var modified := PackedInt32Array([start_index])
	var zone_indices := PackedInt32Array()
	trial[start_index] -= 1
	var decrements := 1

	while queue_head != queue_tail:
		var point := queue[queue_head]
		queue_head = (queue_head + 1) & 0x1ff
		var index := point.x * map_edge + point.y

		if not zone_indices.has(index):
			zone_indices.append(index)

		var higher_mask := 0

		for neighbor_index in 8:
			var neighbor: Vector2i = point + NEIGHBOR_OFFSETS[neighbor_index]

			if _point_is_in_bounds(neighbor, map_edge):
				var checked_index := neighbor.x * map_edge + neighbor.y

				if trial[checked_index] > trial[index]:
					higher_mask |= NEIGHBOR_MASKS[neighbor_index]

		for neighbor_index in 8:
			var neighbor: Vector2i = point + NEIGHBOR_OFFSETS[neighbor_index]

			if not _point_is_in_bounds(neighbor, map_edge):
				continue

			var checked_index := neighbor.x * map_edge + neighbor.y

			if (
				trial[checked_index] > trial[index] + 1
				or (trial[checked_index] > trial[index] and higher_mask == 15)
			):
				trial[checked_index] -= 1
				decrements += 1
				queue[queue_tail] = neighbor
				queue_tail = (queue_tail + 1) & 0x1ff

				if queue_head == queue_tail:
					queue_head = (queue_tail + 1) & 0x1ff

				if not modified.has(checked_index):
					modified.append(checked_index)

	var result := Plan.new()
	result.valid = true
	result.heights = trial
	result.modified = modified
	result.zone_indices = zone_indices
	result.funds = maxi(0, funds - decrements * 25)
	result.cost = mini(funds, decrements * 25)

	return result


static func _decode_heights(altitude: PackedByteArray, map_edge: int = 128) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize((map_edge * map_edge))

	for index in (map_edge * map_edge):
		result[index] = land_altitude(altitude, index)

	return result


static func _write_heights(
	altitude: PackedByteArray, heights: PackedInt32Array, indices: PackedInt32Array
) -> void:
	for index in indices:
		set_land_altitude(altitude, index, heights[index])


static func land_altitude(altitude: PackedByteArray, index: int) -> int:
	return altitude[index * 2 + 1] & 0x1f


static func set_land_altitude(altitude: PackedByteArray, index: int, value: int) -> void:
	var offset := index * 2
	altitude[offset + 1] = (altitude[offset + 1] & 0xe0) | (value & 0x1f)


static func _set_water_altitude(altitude: PackedByteArray, index: int, value: int) -> void:
	var offset := index * 2
	var word := (altitude[offset] << 8) | altitude[offset + 1]
	word = (word & 0xfc1f) | ((value & 0x1f) << 5)
	altitude[offset] = (word >> 8) & 0xff
	altitude[offset + 1] = word & 0xff


static func _point_is_in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return point.x >= 0 and point.x < map_edge and point.y >= 0 and point.y < map_edge
