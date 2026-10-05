class_name CityLifePaths
extends RefCounted
## Display-only lane geometry. No transport queries or city writes.

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const ROAD_PORTS := [5, 10, 5, 10, 5, 10, 3, 6, 12, 9, 11, 7, 14, 13, 15]
const EDGE_CORNERS := [[0, 1], [1, 2], [2, 3], [3, 0]]


static func ports(city: CityState, tile: Vector2i) -> int:
	if city.index_of(tile.x, tile.y) < 0:
		return 0
	var id := city.building_id(tile.x, tile.y)
	if id >= Tiles.ROAD_STRAIGHT_1 and id <= Tiles.ROAD_CROSSROADS:
		return ROAD_PORTS[id - Tiles.ROAD_STRAIGHT_1]
	if id >= Tiles.ROAD_POWER_CROSSING_1 and id <= Tiles.ROAD_RAIL_CROSSING_2:
		return 5 if (id - Tiles.ROAD_POWER_CROSSING_1) % 2 == 0 else 10
	if id >= Tiles.HIGHWAY_STRAIGHT_1 and id <= Tiles.HIGHWAY_POWER_CROSSING_2:
		return 5 if (id - Tiles.HIGHWAY_STRAIGHT_1) % 2 == 0 else 10
	# Bridge decks and ramps need separate artwork-specific geometry. Keep their
	# classic traffic until they have verified lane templates.
	return 0


static func walkable(city: CityState, tile: Vector2i) -> bool:
	var id := city.building_id(tile.x, tile.y)
	return id >= Tiles.ROAD_STRAIGHT_1 and id <= Tiles.ROAD_CROSSROADS


static func connected(city: CityState, tile: Vector2i, direction: int, walking := false) -> bool:
	var next: Vector2i = tile + DIRECTIONS[direction]
	if not (ports(city, tile) & (1 << direction)) or not (ports(city, next) & (1 << ((direction + 2) % 4))):
		return false
	if walking and (not walkable(city, tile) or not walkable(city, next)):
		return false
	return absf(edge_height(city, tile, direction) - edge_height(city, next, (direction + 2) % 4)) < 0.1


static func edge_height(city: CityState, tile: Vector2i, direction: int) -> float:
	var shape := city.terrain_id(tile.x, tile.y) & 15
	var mask: int = IsometricConstants.TERRAIN_SURFACE_CORNER_MASKS[shape] if shape < 15 else 0
	var corners: Array = EDGE_CORNERS[direction]
	return city.land_altitude(tile.x, tile.y) + float(((mask >> corners[0]) & 1) + ((mask >> corners[1]) & 1)) * 0.5


static func point(city: CityState, tile: Vector2i, enter: int, exit: int, progress: float, walking: bool) -> Vector2:
	var incoming := -Vector2(DIRECTIONS[enter])
	var outgoing := Vector2(DIRECTIONS[exit])
	var lane := 0.39 if walking else 0.13
	var a := -incoming * 0.5 + Vector2(-incoming.y, incoming.x) * lane
	var b := outgoing * 0.5 + Vector2(-outgoing.y, outgoing.x) * lane
	var t := clampf(progress, 0.0, 1.0)
	var offset: Vector2
	if exit == (enter + 2) % 4:
		offset = a.lerp(b, t)
	elif walking:
		var corner := Vector2(a.x, b.y) if is_zero_approx(incoming.x) else Vector2(b.x, a.y)
		var first := a.distance_to(corner)
		var second := corner.distance_to(b)
		var distance := t * (first + second)
		offset = a.lerp(corner, distance / first) if distance < first and first > 0.0 else corner.lerp(b, (distance - first) / maxf(second, 0.001))
	else:
		var c := a + incoming * 0.32
		var d := b - outgoing * 0.32
		offset = a * pow(1.0 - t, 3.0) + c * 3.0 * t * pow(1.0 - t, 2.0) + d * 3.0 * t * t * (1.0 - t) + b * t * t * t
	var altitude := lerpf(edge_height(city, tile, enter), edge_height(city, tile, exit), t)
	return Vector2(32 + (city.map_size + tile.x - tile.y) * 16 + 16, 512 + (tile.x + tile.y) * 8 + 8) \
		+ Vector2((offset.x - offset.y) * 16.0, (offset.x + offset.y) * 8.0 - altitude * 12.0)


static func density(city: CityState, tile: Vector2i, walking: bool) -> int:
	var chunk := city.document.find_chunk("XPOP" if walking else "XTRF")
	if chunk == null:
		return 0
	var value := 0
	# A sidewalk borrows activity from the neighboring blocks. Do not add
	# repeated samples of one coarse cell as if they were extra inhabitants.
	for offset in [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT] if walking else [Vector2i.ZERO]:
		var p: Vector2i = tile + offset
		var index := CityDataGrid.index(chunk.decoded_payload, city.map_size, p.x, p.y)
		if index >= 0:
			value = maxi(value, chunk.decoded_payload[index])
	return value


static func target(density_value: int, strength: float, walking: bool) -> float:
	return (1.3 if walking else 0.7) * pow(clampf(density_value / 255.0, 0.0, 1.0), 0.85) * strength
