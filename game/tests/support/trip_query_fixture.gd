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
	assert(NetworkCommand.apply(city, 6, 0, Vector2i(road_x, base.y), Vector2i(road_x, route_y)).ok)

	var destination := Rect2i(Vector2i(base.x + 16, route_y), Vector2i.ONE * destination_size)
	if network == "highway":
		# The horizontal road approaches the south, eastbound highway lane.
		var highway_y := route_y - 2
		var a := Vector2i(base.x + 4, highway_y)
		var b := Vector2i(base.x + 14, highway_y)
		assert(HighwayCommand.apply(city, 6, 1, a, b, 0).ok)
		assert(NetworkCommand.apply(city, 6, 0, Vector2i(road_x, route_y), Vector2i(a.x - 1, route_y)).ok)
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
		assert(NetworkCommand.apply(city, 6, 0, Vector2i(road_x, route_y), Vector2i(destination.position.x - 1, route_y)).ok)

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
	BuildingSites.set_corners(city.zones, site, site.size.x, city.compass_rotation(), city.map_size)
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
	for endpoints in [[block.position, Vector2i(block.end.x - 1, block.position.y)],
		[Vector2i(block.end.x - 1, block.position.y), block.end - Vector2i.ONE],
		[block.end - Vector2i.ONE, Vector2i(block.position.x, block.end.y - 1)],
		[Vector2i(block.position.x, block.end.y - 1), block.position],
		[Vector2i(block.end.x - 1, block.position.y + 3), Vector2i(block.end.x + 8, block.position.y + 3)]]:
		assert(NetworkCommand.apply(city, 6, 0, endpoints[0], endpoints[1]).ok)
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


static func add_subway_scenario(city: CityState, base: Vector2i) -> Dictionary:
	var scenario := add_scenario(city, 0, base)
	var entrance := base + Vector2i(8, 5)
	var exit_station := base + Vector2i(40, 5)
	var bend_a := base + Vector2i(8, 10)
	var bend_b := base + Vector2i(40, 10)
	assert(NetworkCommand.apply(city, 7, 1, entrance, bend_a).ok)
	assert(NetworkCommand.apply(city, 7, 1, bend_a, bend_b).ok)
	assert(NetworkCommand.apply(city, 7, 1, bend_b, exit_station).ok)
	var lfsr := SimLfsrRandom.new(1)
	var random := SimRandom.new(1)
	assert(BuildingCommand.apply(city, 7, 3, entrance, lfsr, random).ok)
	assert(BuildingCommand.apply(city, 7, 3, exit_station, lfsr, random).ok)
	assert(SignCommand.set_sign(city, base + Vector2i(0, 1), "4 Road and subway").ok)
	scenario.merge({"entrance": entrance, "exit_station": exit_station,
		"underground_midpoint": base + Vector2i(24, 10)})
	return scenario


static func add_tunnel_scenario(city: CityState, base: Vector2i) -> Dictionary:
	var road_y := base.y + 6
	var entrance := base + Vector2i(7, 6)
	var exit_portal := base + Vector2i(17, 6)
	var ground := city.land_altitude(base.x, base.y)
	# A one-level plateau with a continuous sloped rim.
	for x in range(base.x + 7, base.x + 18):
		for y in range(base.y + 2, base.y + 11):
			var left := x == base.x + 7
			var right := x == base.x + 17
			var top := y == base.y + 2
			var bottom := y == base.y + 10
			var mask := 15
			if left:
				mask &= 6
			if right:
				mask &= 9
			if top:
				mask &= 12
			if bottom:
				mask &= 3
			city.set_land_altitude(x, y, ground + (1 if mask == 15 else 0))
			city.set_terrain_id(x, y, 0 if mask == 15 else CityIsometricRenderer.TERRAIN_SURFACE_CORNER_MASKS.find(mask))
	assert(NetworkCommand.apply(city, 6, 0, base + Vector2i(0, 6), entrance - Vector2i(1, 0)).ok)
	assert(NetworkCommand.apply(city, 6, 0, exit_portal + Vector2i(1, 0), base + Vector2i(24, 6)).ok)
	assert(TunnelCommand.apply(city, 6, 2, entrance, TunnelCommand.CONFIRMATION_CONFIRMED).ok)
	stamp(city, Rect2i(base + Vector2i(3, 4), Vector2i(2, 2)), 0x8c, 1)
	stamp(city, Rect2i(base + Vector2i(20, 3), Vector2i(3, 3)), 0xb2, 3)
	assert(SignCommand.set_sign(city, base, "5 Road tunnel").ok)
	return {"origin": base + Vector2i(3, 5), "destination": base + Vector2i(20, 5),
		"entrance": entrance, "exit_portal": exit_portal,
		"tunnel_midpoint": Vector2i(base.x + 12, road_y)}


static func add_bus_scenario(city: CityState, base: Vector2i) -> Dictionary:
	var origin := base + Vector2i(1, 2)
	var destination := base + Vector2i(0, 34)
	var stops: Array[Vector2i] = [base + Vector2i(2, 2), base + Vector2i(2, 30)]
	assert(NetworkCommand.apply(city, 6, 0, base + Vector2i(4, 0), base + Vector2i(4, 38)).ok)
	stamp(city, Rect2i(origin, Vector2i.ONE), 0x70, 1)
	stamp(city, Rect2i(destination, Vector2i(3, 3)), 0xb2, 3)
	for stop in stops:
		assert(BuildingCommand.apply(city, 6, 4, stop, SimLfsrRandom.new(1), SimRandom.new(1)).ok)
	assert(SignCommand.set_sign(city, base, "6 Road and buses").ok)
	return {"origin": origin, "destination": destination, "stops": stops,
		"road_midpoint": base + Vector2i(4, 18)}


static func add_full_interchange_scenario(city: CityState, base: Vector2i) -> Dictionary:
	var highway_y := base.y + 4
	assert(HighwayCommand.apply(city, 6, 1, base + Vector2i(2, 4), base + Vector2i(36, 4), 0).ok)
	var ramps: Array[Vector2i] = []
	for road_x in [base.x + 6, base.x + 32]:
		assert(NetworkCommand.apply(city, 6, 0, Vector2i(road_x, base.y), Vector2i(road_x, base.y + 11)).ok)
		for dx in [-1, 1]:
			for y in [highway_y - 1, highway_y + 2]:
				var ramp := Vector2i(road_x + dx, y)
				assert(OnrampCommand.apply(city, 6, 3, ramp).ok)
				ramps.append(ramp)
	var origin := base + Vector2i(5, 9)
	stamp(city, Rect2i(origin, Vector2i.ONE), 0x70, 1)
	stamp(city, Rect2i(base + Vector2i(3, 0), Vector2i(2, 2)), 0x8c, 1)
	var destinations: Array[Vector2i] = [base + Vector2i(30, 0), base + Vector2i(30, 8)]
	for destination in destinations:
		stamp(city, Rect2i(destination, Vector2i(2, 2)), 0x94, 3)
	assert(SignCommand.set_sign(city, base + Vector2i(15, 0), "11 Highway - four ramps per end").ok)
	return {"origin": origin, "ramps": ramps, "destinations": destinations}
