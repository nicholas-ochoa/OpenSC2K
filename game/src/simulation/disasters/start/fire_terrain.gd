class_name DisasterStartFireTerrain
extends DisasterStartConstants


static func _volcano_raise_is_valid(
	heights: PackedInt32Array,
	zones: PackedByteArray,
	flags: PackedByteArray,
	point: Vector2i,
	visited := {},
	map_edge: int = 128,
) -> bool:
	var index := DisasterStartObjectsState._index(point, map_edge)

	if index < 0 or visited.has(index):
		return true

	if zones[index] & Sc2ZoneLayout.TYPE_MASK == TerrainCommand.MILITARY_ZONE:
		return false

	if flags[index] & Sc2TileFlags.WATER != 0 or heights[index] > TerrainCommand.MAX_RAISE_SOURCE:
		return false

	visited[index] = true

	for offset in TerrainCommand.NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = point + offset
		var neighbor_index := DisasterStartObjectsState._index(neighbor, map_edge)

		if neighbor_index < 0:
			continue

		if zones[neighbor_index] & Sc2ZoneLayout.TYPE_MASK == TerrainCommand.MILITARY_ZONE:
			return false

		if flags[neighbor_index] & Sc2TileFlags.WATER != 0:
			return false

	for offset in TerrainCommand.CARDINAL_OFFSETS:
		var neighbor: Vector2i = point + offset
		var neighbor_index := DisasterStartObjectsState._index(neighbor, map_edge)

		if neighbor_index >= 0 and heights[neighbor_index] < heights[index]:
			if not _volcano_raise_is_valid(heights, zones, flags, neighbor, visited, map_edge):
				return false

	return true


static func _starts_fire(result_code: int) -> bool:
	return result_code == 1 or result_code == 3 or result_code == 4
