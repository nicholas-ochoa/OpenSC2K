class_name CityDataGrid
extends RefCounted
# coordinates for legacy coarse grids and sc2x per-tile grids


static func valid(data: PackedByteArray, map_edge: int, legacy_scale: int = 2) -> bool:
	return data.size() == map_edge * map_edge or data.size() == (map_edge / legacy_scale) * (map_edge / legacy_scale)


static func edge(data: PackedByteArray, map_edge: int) -> int:
	if data.size() == map_edge * map_edge:
		return map_edge

	if data.size() == (map_edge / 2) * (map_edge / 2):
		return map_edge / 2

	if data.size() == (map_edge / 4) * (map_edge / 4):
		return map_edge / 4

	return 0


static func index(data: PackedByteArray, map_edge: int, x: int, y: int) -> int:
	var grid_edge := edge(data, map_edge)

	if grid_edge == 0 or x < 0 or y < 0 or x >= map_edge or y >= map_edge:
		return -1

	var scale := map_edge / grid_edge

	return (x / scale) * grid_edge + y / scale


static func expand(data: PackedByteArray, map_edge: int) -> PackedByteArray:
	var result := PackedByteArray()
	var grid_edge := edge(data, map_edge)

	if grid_edge == 0:
		return result

	var scale := map_edge / grid_edge
	result.resize(map_edge * map_edge)

	for x in map_edge:
		for y in map_edge:
			result[x * map_edge + y] = data[(x / scale) * grid_edge + y / scale]

	return result
