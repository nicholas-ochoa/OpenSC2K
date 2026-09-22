extends SceneTree
## Test the shared shape table through surface and underground retiling.

# Saved road tile IDs for all N/E/S/W connection masks, independent of the owner.
const ROAD_TILES := [0x1d, 0x1d, 0x1e, 0x23, 0x1d, 0x1d, 0x24, 0x28,
	0x1e, 0x26, 0x1e, 0x27, 0x25, 0x2a, 0x29, 0x2b]
const NEIGHBORS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const POINT := Vector2i(8, 8)

var checks := 0
var failures := 0


func _initialize() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))

	for mask in 16:
		_check(_surface(city, mask, POINT) == ROAD_TILES[mask], "Road shape for mask %d" % mask)
		_check(_surface(city, mask, POINT, 1) == ROAD_TILES[mask] + 15, "Rail shape for mask %d" % mask)
		_check(_surface(city, mask, POINT, 2) == ROAD_TILES[mask] - 15, "Power shape for mask %d" % mask)
		_check(_underground(city, mask, POINT, false) == ROAD_TILES[mask] - 28, "Subway shape for mask %d" % mask)
		var pipe_tile: int = 30 if mask == 0 else ROAD_TILES[mask] - 13
		_check(_underground(city, mask, POINT, true) == pipe_tile, "Pipe shape for mask %d" % mask)

	# A slope has its own shape even when the neighbor mask asks for a junction.
	for slope in range(1, 5):
		_check(_surface(city, 15, POINT, 0, slope) == 30 + slope, "Road slope overrides junction")
		_check(_underground(city, 15, POINT, false, slope) == 2 + slope, "Subway slope overrides junction")
		_check(_underground(city, 0, POINT, true, slope) == 17 + slope, "Pipe slope overrides isolation rule")

	var edges := [Vector2i(0, 8), Vector2i(8, 0), Vector2i(15, 8), Vector2i(8, 15), Vector2i(0, 0)]
	var edge_roads := [40, 41, 42, 39, 36]

	for index in edges.size():
		_check(_surface(city, 15, edges[index]) == edge_roads[index], "Surface ignores out-of-map neighbors")
		_check(_underground(city, 15, edges[index], false) == edge_roads[index] - 28,
			"Underground ignores out-of-map neighbors")
		_check(_surface(city, 15, edges[index], 0, 0, true) == 43,
			"Surface connection marker retains the out-of-map branch")

	_check_neighbor_rules(city)
	print("Network topology: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func _empty(city: CityState) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(city.map_size * city.map_size)

	return result


func _surface(city: CityState, mask: int, point: Vector2i, mode := 0, slope := 0, connection := false) -> int:
	var base: int = [29, 44, 14][mode]
	var buildings := _empty(city)
	var terrain := _empty(city)
	var zones := _empty(city)
	var flags := _empty(city)
	var overlays := _empty(city)
	var misc := city.document.find_chunk("MISC").decoded_payload.duplicate()
	var center := city.index_of(point.x, point.y)
	buildings[center] = base
	terrain[center] = slope
	overlays[center] = 250 if connection else 0
	BinaryData.write_u32_be(misc, 0x01f0 + base * 4, 1)

	for direction in 4:
		var near: Vector2i = point + NEIGHBORS[direction]
		var index := city.index_of(near.x, near.y)

		if index >= 0 and mask & (1 << direction):
			buildings[index] = base
			flags[index] = 128

	NetworkTiles.retile_surface(buildings, terrain, zones, flags, misc, point, mode, overlays, city.map_size)

	return buildings[center]


func _underground(city: CityState, mask: int, point: Vector2i, pipes: bool, slope := 0) -> int:
	var base := 16 if pipes else 1
	var underground := _empty(city)
	var terrain := _empty(city)
	var center := city.index_of(point.x, point.y)
	underground[center] = base
	terrain[center] = slope

	for direction in 4:
		var near: Vector2i = point + NEIGHBORS[direction]
		var index := city.index_of(near.x, near.y)

		if index >= 0 and mask & (1 << direction):
			underground[index] = base

	BuildingUnderground._retile_underground(underground, terrain, point, pipes, city.map_size)

	return underground[center]


func _check_neighbor_rules(city: CityState) -> void:
	var underground := _empty(city)
	var terrain := _empty(city)
	var center := city.index_of(POINT.x, POINT.y)
	var east := city.index_of(POINT.x + 1, POINT.y)
	var south := city.index_of(POINT.x, POINT.y + 1)
	underground[center] = 1
	underground[east] = 35 # A subway entrance connects to a subway.
	underground[south] = 16 # A pipe does not connect to a subway.
	BuildingUnderground._retile_underground(underground, terrain, POINT, false, city.map_size)
	_check(underground[center] == 2, "Subway accepts an entrance and ignores a pipe")
	underground[center] = 1
	terrain[east] = 2 # This terrain blocks a horizontal connection.
	BuildingUnderground._retile_underground(underground, terrain, POINT, false, city.map_size)
	_check(underground[center] == 1, "Neighbor terrain can block a subway connection")
	underground[center] = 35
	BuildingUnderground._retile_underground(underground, terrain, POINT, false, city.map_size)
	_check(underground[center] == 35, "Retiling preserves a subway entrance")
