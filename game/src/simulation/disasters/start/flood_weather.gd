class_name DisasterStartFloodWeather
extends DisasterStartConstants

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")


static func find_flood_shore(terrain: PackedByteArray, origin: Vector2i, map_edge: int = 128) -> Vector2i:
	# retain the original search for legacy cities. extended cities select the
	# same first match: smallest square radius, then increasing x and y
	if map_edge == 128:
		for radius in map_edge:
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					var point := origin + Vector2i(dx, dy)
					var index := DisasterStartObjectsState._index(point, map_edge)

					if index >= 0 and terrain[index] >= TerrainTileIds.SHORE_FIRST and terrain[index] < TerrainTileIds.SURFACE_WATER_FIRST:
						return point

		return Vector2i(-1, -1)

	var selected := Vector2i(-1, -1)
	var nearest_radius := map_edge

	for x in map_edge:
		for y in map_edge:
			var tile := terrain[x * map_edge + y]

			if tile < TerrainTileIds.SHORE_FIRST or tile >= TerrainTileIds.SURFACE_WATER_FIRST:
				continue

			var radius := maxi(absi(x - origin.x), absi(y - origin.y))

			if radius < nearest_radius:
				nearest_radius = radius
				selected = Vector2i(x, y)

	return selected
