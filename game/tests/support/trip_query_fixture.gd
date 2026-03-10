class_name TripQueryFixture
extends RefCounted

const SOURCE_TILES := [0, 0x70, 0x8c, 0xae, 0xfb]
const DESTINATION_TILES := [0, 0x7c, 0x94, 0xb2, 0xfb]


static func add_route(city: CityState, source_size: int, destination_size: int,
	network: String, base := Vector2i(20, 20)) -> Dictionary:
	var source := Rect2i(base, Vector2i.ONE * source_size)
	stamp(city, source, SOURCE_TILES[source_size], 1 if source_size < 4 else 0)
	var route_y := base.y + 6
	var road_x := base.x - 1
	for y in range(base.y, route_y + 1):
		city.set_building_id(road_x, y, 0x1d)

	var destination := Rect2i(Vector2i(base.x + 16, route_y), Vector2i.ONE * destination_size)
	if network == "highway":
		# The horizontal road approaches the south, eastbound highway lane.
		var highway_y := route_y - 2
		var a := Vector2i(base.x + 4, highway_y)
		var b := Vector2i(base.x + 14, highway_y)
		assert(HighwayCommand.apply(city, 6, 1, a, b, 0).ok)
		for x in range(road_x, a.x):
			city.set_building_id(x, route_y, 0x1e)
		city.set_building_id(b.x + 1, route_y, 0x1e)
		assert(OnrampCommand.apply(city, 6, 3, a + Vector2i(0, 2)).ok)
		assert(OnrampCommand.apply(city, 6, 3, b + Vector2i(0, 2)).ok)
	elif network == "rail":
		stamp(city, Rect2i(base.x, route_y, 2, 2), 0xed, 0)
		for x in range(base.x + 2, base.x + 16):
			city.set_building_id(x, route_y, 0x2d)
		if destination_size < 4:
			stamp(city, Rect2i(base.x + 14, route_y, 2, 2), 0xed, 0)
	else:
		for x in range(road_x, destination.position.x):
			city.set_building_id(x, route_y, 0x1e)

	stamp(city, destination, DESTINATION_TILES[destination_size], 3 if destination_size < 4 else 0)
	city.document.find_chunk("XZON").set_decoded_payload(city.zones)
	return {"source": source, "destination": destination,
		"origin": Vector2i(base.x, base.y + source_size - 1), "network": network}


static func stamp(city: CityState, site: Rect2i, tile: int, zone: int) -> void:
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			city.set_building_id(x, y, tile)
			city.set_zone_id(x, y, zone)
			city.set_tile_flag(x, y, 0x40, true)
	BuildingCommand._set_corners(city.zones, site, site.size.x, city.compass_rotation(), city.map_size)
	city.document.find_chunk("XZON").set_decoded_payload(city.zones)


static func add_block(city: CityState, origin := Vector2i(70, 20)) -> Rect2i:
	var block := Rect2i(origin, Vector2i(8, 8))
	for x in range(block.position.x, block.end.x):
		for y in range(block.position.y, block.end.y):
			if x in [block.position.x, block.end.x - 1] or y in [block.position.y, block.end.y - 1]:
				city.set_building_id(x, y, 0x1e if y in [block.position.y, block.end.y - 1] else 0x1d)
			else:
				var residential := (x + y) % 2 == 0
				stamp(city, Rect2i(x, y, 1, 1), 0x70 if residential else 0x7c, 1 if residential else 3)
	# A spur deliberately ends without a destination.
	for x in range(block.end.x, block.end.x + 9):
		city.set_building_id(x, block.position.y + 3, 0x1e)
	return block


static func add_scenario(city: CityState, variant: int, base: Vector2i) -> Dictionary:
	var road_y := base.y + 6
	assert(NetworkCommand.apply(city, 6, 0, Vector2i(base.x, road_y), Vector2i(base.x + 44, road_y)).ok)
	for x in range(base.x, base.x + 8):
		for y in range(base.y + 4, base.y + 6):
			stamp(city, Rect2i(x, y, 1, 1), 0x70 + (x + y) % 4, 1)
	stamp(city, Rect2i(base.x + 41, base.y + 4, 2, 2), 0x9e, 5)
	stamp(city, Rect2i(base.x + 41, base.y + 7, 2, 2), 0x9f, 5)
	assert(NetworkCommand.apply(city, 3, 0, base + Vector2i(7, 3), base + Vector2i(44, 3)).ok)
	assert(NetworkCommand.apply(city, 3, 0, base + Vector2i(44, 3), base + Vector2i(44, 9)).ok)
	if variant >= 1:
		assert(HighwayCommand.apply(city, 6, 1, base + Vector2i(4, 0), base + Vector2i(46, 0), 0).ok)
		for x in [base.x + 8, base.x + 40]:
			assert(NetworkCommand.apply(city, 6, 0, Vector2i(x, base.y + 2), Vector2i(x, road_y)).ok)
			assert(OnrampCommand.apply(city, 6, 3, Vector2i(x + 1, base.y + 2)).ok)
	if variant >= 2:
		stamp(city, Rect2i(base.x + 4, base.y + 8, 2, 2), 0xed, 0)
		stamp(city, Rect2i(base.x + 38, base.y + 8, 2, 2), 0xed, 0)
		assert(NetworkCommand.apply(city, 7, 0, base + Vector2i(4, 10), base + Vector2i(39, 10)).ok)
		city.set_building_id(base.x + 5, base.y + 7, 0x1d)
		city.set_building_id(base.x + 39, base.y + 7, 0x1d)
	var label: String = ["1 Road only", "2 Road and highway", "3 Road highway and rail"][variant]
	assert(SignCommand.set_sign(city, base + Vector2i(0, 1), label).ok)
	return {"origin": base + Vector2i(7, 5), "destination": base + Vector2i(41, 5),
		"road_end": base + Vector2i(44, 6), "variant": variant}
