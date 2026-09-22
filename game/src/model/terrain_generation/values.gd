class_name NewTerrainValues
extends NewTerrainConstants



static func _recount_buildings(
	buildings: PackedByteArray, misc: PackedByteArray
) -> void:
	var counts := PackedInt32Array()
	counts.resize(BuildingTileIds.COUNT)

	for building in buildings:
		counts[building] += 1

	for building_id in BuildingTileIds.COUNT:
		_write_u32_be(
			misc, MISC_TILE_COUNTS + building_id * 4, counts[building_id]
		)


static func _count_flag(values: PackedByteArray, mask: int) -> int:
	var count := 0

	for value in values:
		if value & mask:
			count += 1

	return count


static func _count_range(values: PackedByteArray, first: int, last: int) -> int:
	var count := 0

	for value in values:
		if value >= first and value <= last:
			count += 1

	return count


static func _minimum(altitude: PackedByteArray, map_edge: int = 128) -> int:
	var result := 31

	for index in (map_edge * map_edge):
		result = mini(result, _land_altitude(altitude, index))

	return result


static func _maximum(altitude: PackedByteArray, map_edge: int = 128) -> int:
	var result := 0

	for index in (map_edge * map_edge):
		result = maxi(result, _land_altitude(altitude, index))

	return result


static func _land_altitude(altitude: PackedByteArray, index: int) -> int:
	return altitude[index * 2 + 1] & Sc2AltitudeLayout.LEVEL_MASK


static func _index(x: int, y: int, map_edge: int = 128) -> int:
	return x * map_edge + y


static func _in_bounds(point: Vector2i, map_edge: int = 128) -> bool:
	return point.x >= 0 and point.x < map_edge and point.y >= 0 and point.y < map_edge


static func _write_u32_be(
	data: PackedByteArray, offset: int, value: int
) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff
