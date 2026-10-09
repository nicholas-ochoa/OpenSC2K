class_name CityLifePaths
extends RefCounted
## Display-only lane geometry. No transport queries or city writes.

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIAGONAL_FORWARD := [Vector2(1, -1) * 0.7071067811865476, Vector2(1, 1) * 0.7071067811865476,
	Vector2(-1, 1) * 0.7071067811865476, Vector2(-1, -1) * 0.7071067811865476]
# Slope artwork starts on the east/west axis; flat-road artwork starts north/south.
const ROAD_PORTS := [5, 10, 10, 5, 10, 5, 3, 6, 12, 9, 11, 7, 14, 13, 15]
const EDGE_CORNERS := [[0, 1], [1, 2], [2, 3], [3, 0]]


static func candidate_indices(city: CityState, first: Vector2i, last: Vector2i) -> PackedInt32Array:
	if first.x > last.x or first.y > last.y:
		return PackedInt32Array()
	# Search only rows that can reach the viewport. Exclude rail/power-only ids
	# before GDScript examines individual tiles; ports() still decides topology.
	var ids := PackedInt32Array(range(Tiles.ROAD_STRAIGHT_1, Tiles.ROAD_CROSSROADS + 1))
	ids.append_array(PackedInt32Array([Tiles.TUNNEL_ENTRANCE_1, Tiles.TUNNEL_ENTRANCE_2]))
	ids.append_array(PackedInt32Array(range(Tiles.ROAD_POWER_CROSSING_1, Tiles.ROAD_RAIL_CROSSING_2 + 1)))
	ids.append_array(PackedInt32Array(range(Tiles.HIGHWAY_STRAIGHT_1, Tiles.RAISING_BRIDGE_CLOSED + 1)))
	ids.append_array(PackedInt32Array(range(Tiles.HIGHWAY_ONRAMP_1, Tiles.REINFORCED_HIGHWAY_BRIDGE + 1)))
	var start := first.x * city.map_size + first.y
	var plane := city.buildings.slice(start, last.x * city.map_size + last.y + 1)
	var result := PackedInt32Array()
	for id in ids:
		var index := plane.find(id)
		while index >= 0:
			var y := (start + index) % city.map_size
			if y >= first.y and y <= last.y:
				result.append(start + index)
			index = plane.find(id, index + 1)
	result.sort()
	return result


static func ports(city: CityState, tile: Vector2i) -> int:
	if city.index_of(tile.x, tile.y) < 0:
		return 0
	var id := city.building_id(tile.x, tile.y)
	if id >= Tiles.ROAD_STRAIGHT_1 and id <= Tiles.ROAD_CROSSROADS:
		return ROAD_PORTS[id - Tiles.ROAD_STRAIGHT_1]
	if id >= Tiles.ROAD_POWER_CROSSING_1 and id <= Tiles.ROAD_RAIL_CROSSING_2:
		return 5 if (id - Tiles.ROAD_POWER_CROSSING_1) % 2 == 0 else 10
	if id in [Tiles.TUNNEL_ENTRANCE_1, Tiles.TUNNEL_ENTRANCE_2]:
		return 10 if id == Tiles.TUNNEL_ENTRANCE_1 else 5
	if id >= Tiles.HIGHWAY_STRAIGHT_1 and id <= Tiles.HIGHWAY_POWER_CROSSING_2:
		if id in [Tiles.HIGHWAY_ROAD_CROSSING_1, Tiles.HIGHWAY_ROAD_CROSSING_2]:
			return 15
		return 5 if (id - Tiles.HIGHWAY_STRAIGHT_1) % 2 == 0 else 10
	if id >= Tiles.SUSPENSION_BRIDGE_1 and id <= Tiles.RAISING_BRIDGE_CLOSED:
		return 10 if city.is_flipped(tile.x, tile.y) else 5
	if id >= Tiles.HIGHWAY_ONRAMP_1 and id <= Tiles.HIGHWAY_ONRAMP_4:
		return (1 << ramp_highway_direction(city, tile)) | (1 << ramp_road_direction(city, tile))
	if id >= Tiles.HIGHWAY_SLOPE_1 and id <= Tiles.HIGHWAY_SLOPE_4:
		return 10 if (id - Tiles.HIGHWAY_SLOPE_1) % 2 == 0 else 5
	if id >= Tiles.HIGHWAY_CURVE_1 and id <= Tiles.HIGHWAY_CURVE_4:
		var quarter := tile - section_origin(city, tile)
		var rotation := id - Tiles.HIGHWAY_CURVE_1
		# The two decks join at the outside corner; one footprint cell is empty.
		for turn in rotation:
			quarter = Vector2i(quarter.y, 1 - quarter.x)
		var mask := 3 if quarter in [Vector2i.ZERO, Vector2i.ONE] else (15 if quarter == Vector2i(1, 0) else 0)
		for turn in rotation:
			mask = ((mask << 1) | (mask >> 3)) & 15
		return mask
	if id == Tiles.HIGHWAY_INTERSECTION:
		return 15
	if id in [Tiles.HIGHWAY_BRIDGE, Tiles.REINFORCED_HIGHWAY_BRIDGE]:
		return 10 if city.is_flipped(tile.x, tile.y) else 5
	return 0


static func walkable(city: CityState, tile: Vector2i) -> bool:
	var id := city.building_id(tile.x, tile.y)
	return (id >= Tiles.ROAD_STRAIGHT_1 and id <= Tiles.ROAD_CROSSROADS) \
		or (id >= Tiles.SUSPENSION_BRIDGE_1 and id <= Tiles.RAISING_BRIDGE_CLOSED)


static func section_origin(city: CityState, tile: Vector2i) -> Vector2i:
	var corner := city.building_corners(tile.x, tile.y)
	var corners := [0x10, 0x20, 0x40, 0x80]
	var index := corners.find(corner)
	if index < 0:
		return tile
	var quarter: Vector2i = [Vector2i.ZERO, Vector2i(1, 0), Vector2i.ONE, Vector2i(0, 1)][posmod(index - city.compass_rotation(), 4)]
	return tile - quarter


static func ramp_highway_direction(city: CityState, tile: Vector2i) -> int:
	var direction: int = [0, 0, 2, 2][city.building_id(tile.x, tile.y) - Tiles.HIGHWAY_ONRAMP_1]
	return 3 - direction if city.is_flipped(tile.x, tile.y) else direction


static func ramp_road_direction(city: CityState, tile: Vector2i) -> int:
	var direction: int = [1, 3, 3, 1][city.building_id(tile.x, tile.y) - Tiles.HIGHWAY_ONRAMP_1]
	return 3 - direction if city.is_flipped(tile.x, tile.y) else direction


static func can_turn(city: CityState, tile: Vector2i, enter: int, exit: int) -> bool:
	var id := city.building_id(tile.x, tile.y)
	# A road crossing underneath a highway has two separate display levels.
	if id in [Tiles.HIGHWAY_ROAD_CROSSING_1, Tiles.HIGHWAY_ROAD_CROSSING_2]:
		return exit == (enter + 2) % 4
	if id >= Tiles.HIGHWAY_CURVE_1 and id <= Tiles.HIGHWAY_CURVE_4:
		var rotation := id - Tiles.HIGHWAY_CURVE_1
		var local_enter := posmod(enter - rotation, 4)
		var local_exit := posmod(exit - rotation, 4)
		# Inside and outside carriageways do not turn into each other at the shared cell.
		return local_exit == (local_enter ^ 1)
	return true


static func diagonal(city: CityState, tile: Vector2i) -> bool:
	var id := city.building_id(tile.x, tile.y)
	return (id >= Tiles.ROAD_CURVE_1 and id <= Tiles.ROAD_CURVE_4) \
		or (id >= Tiles.HIGHWAY_CURVE_1 and id <= Tiles.HIGHWAY_CURVE_4)


static func paired_exit(city: CityState, tile: Vector2i, enter: int) -> int:
	var mask := ports(city, tile)
	for exit in 4:
		if exit != enter and mask & (1 << exit) and can_turn(city, tile, enter, exit):
			return exit
	return (enter + 2) % 4


# Heading numbers 0..3 retain the original artwork; 4..7 face screen E/S/W/N.
static func heading(enter: int, exit: int, progress: float, is_diagonal: bool) -> int:
	if is_diagonal and enter % 2 != exit % 2:
		var forward: Vector2i = DIRECTIONS[exit] - DIRECTIONS[enter]
		return (4 if forward.y < 0 else 5) if forward.x > 0 else (6 if forward.y > 0 else 7)
	return (enter + 2) % 4 if progress < 0.5 else exit


static func forward(heading_value: int) -> Vector2:
	if heading_value < 4:
		return Vector2(DIRECTIONS[heading_value])
	return DIAGONAL_FORWARD[heading_value - 4]


static func opposite(heading_value: int) -> int:
	return (heading_value + 2) % 4 if heading_value < 4 else 4 + (heading_value - 2) % 4


static func connected(city: CityState, tile: Vector2i, direction: int, walking := false) -> bool:
	var next: Vector2i = tile + DIRECTIONS[direction]
	if not (ports(city, tile) & (1 << direction)) or not (ports(city, next) & (1 << ((direction + 2) % 4))):
		return false
	if walking and (not walkable(city, tile) or not walkable(city, next)):
		return false
	return absf(edge_height(city, tile, direction) - edge_height(city, next, (direction + 2) % 4)) < 0.1


static func edge_height(city: CityState, tile: Vector2i, direction: int) -> float:
	var id := city.building_id(tile.x, tile.y)
	if (id >= Tiles.SUSPENSION_BRIDGE_1 and id <= Tiles.RAISING_BRIDGE_CLOSED) \
			or id in [Tiles.HIGHWAY_BRIDGE, Tiles.REINFORCED_HIGHWAY_BRIDGE]:
		return city.object_altitude(tile.x, tile.y) + 1.0
	var raised := 0.0
	if id >= Tiles.HIGHWAY_ONRAMP_1 and id <= Tiles.HIGHWAY_ONRAMP_4:
		raised = 1.0 if direction == ramp_highway_direction(city, tile) else 0.0
	elif (id >= Tiles.HIGHWAY_STRAIGHT_1 and id <= Tiles.HIGHWAY_POWER_CROSSING_2) \
			or (id >= Tiles.HIGHWAY_SLOPE_1 and id <= Tiles.HIGHWAY_INTERSECTION):
		raised = 1.0
		if id in [Tiles.HIGHWAY_ROAD_CROSSING_1, Tiles.HIGHWAY_ROAD_CROSSING_2]:
			var highway_axis := 0 if id == Tiles.HIGHWAY_ROAD_CROSSING_1 else 1
			if direction % 2 != highway_axis:
				raised = 0.0
	if raised > 0.0 and city.is_water(tile.x, tile.y):
		return city.object_altitude(tile.x, tile.y) + raised
	var shape := city.terrain_id(tile.x, tile.y) & 15
	var mask: int = IsometricConstants.TERRAIN_SURFACE_CORNER_MASKS[shape] if shape < 15 else 0
	var corners: Array = EDGE_CORNERS[direction]
	return city.land_altitude(tile.x, tile.y) + raised + float(((mask >> corners[0]) & 1) + ((mask >> corners[1]) & 1)) * 0.5


static func point(city: CityState, tile: Vector2i, enter: int, exit: int, progress: float, walking: bool) -> Vector2:
	var incoming := -Vector2(DIRECTIONS[enter])
	var outgoing := Vector2(DIRECTIONS[exit])
	var lane := 0.39 if walking else 0.13
	var a := -incoming * 0.5 + Vector2(-incoming.y, incoming.x) * lane
	var b := outgoing * 0.5 + Vector2(-outgoing.y, outgoing.x) * lane
	var t := clampf(progress, 0.0, 1.0)
	var offset: Vector2
	if exit == (enter + 2) % 4 or diagonal(city, tile):
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


# Immutable display geometry shared by figures on the same lane segment.
# point() above remains the uncached reference used by one-time queries.
class Segment extends RefCounted:
	var a: Vector2
	var b: Vector2
	var c: Vector2
	var d: Vector2
	var corner: Vector2
	var first: float
	var second: float
	var base: Vector2
	var low: float
	var high: float
	var straight: bool
	var walking: bool


	func _init(city: CityState, tile: Vector2i, enter: int, exit: int, is_walking: bool) -> void:
		walking = is_walking
		straight = exit == (enter + 2) % 4 or CityLifePaths.diagonal(city, tile)
		var incoming := -Vector2(DIRECTIONS[enter])
		var outgoing := Vector2(DIRECTIONS[exit])
		var lane := 0.39 if walking else 0.13
		a = -incoming * 0.5 + Vector2(-incoming.y, incoming.x) * lane
		b = outgoing * 0.5 + Vector2(-outgoing.y, outgoing.x) * lane
		c = a + incoming * 0.32
		d = b - outgoing * 0.32
		corner = Vector2(a.x, b.y) if is_zero_approx(incoming.x) else Vector2(b.x, a.y)
		first = a.distance_to(corner)
		second = corner.distance_to(b)
		low = CityLifePaths.edge_height(city, tile, enter)
		high = CityLifePaths.edge_height(city, tile, exit)
		base = Vector2(32 + (city.map_size + tile.x - tile.y) * 16 + 16, 512 + (tile.x + tile.y) * 8 + 8)


	func point(progress: float) -> Vector2:
		var t := clampf(progress, 0.0, 1.0)
		var offset: Vector2
		if straight:
			offset = a.lerp(b, t)
		elif walking:
			var distance := t * (first + second)
			offset = a.lerp(corner, distance / first) if distance < first and first > 0.0 else corner.lerp(b, (distance - first) / maxf(second, 0.001))
		else:
			offset = a * pow(1.0 - t, 3.0) + c * 3.0 * t * pow(1.0 - t, 2.0) + d * 3.0 * t * t * (1.0 - t) + b * t * t * t
		var altitude := lerpf(low, high, t)
		return base + Vector2((offset.x - offset.y) * 16.0, (offset.x + offset.y) * 8.0 - altitude * 12.0)


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
