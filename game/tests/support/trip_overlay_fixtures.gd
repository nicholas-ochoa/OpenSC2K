extends RefCounted
## Generated inputs shared by the overlay parity test and CPU benchmark.


class Fixture extends RefCounted:
	var name: String
	var city: CityState
	var result: TransportTripReachResult

	func _init(label: String, source: CityState, analysis: TransportTripReachResult) -> void:
		name = label
		city = source
		result = analysis


static func road() -> Fixture:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var route := TripQueryFixture.add_route(city, 2, 3, "road")
	return Fixture.new("road", city, TripReachAnalysis.inspect(city, route.origin))


static func mixed() -> Fixture:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	city.set_funds(1000000)
	var route := TripQueryFixture.add_scenario(city, 2, Vector2i(16, 12))
	return Fixture.new("mixed", city, TripReachAnalysis.inspect(city, route.origin))


static func dense(edge: int) -> Fixture:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	var center := Vector2i(edge - 50, edge - 50)
	for x in range(center.x - 40, center.x + 41):
		for y in range(center.y - 40, center.y + 41):
			city.set_building_id(x, y, BuildingTileIds.ROAD_CROSSROADS)
	return Fixture.new("dense_%d" % edge, city, TripReachAnalysis.inspect(city, center))


static func modes() -> Fixture:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	city.set_land_altitude(5, 5, 4)
	city.set_terrain_id(5, 5, 1)
	city.set_land_altitude(6, 5, 3)
	TripQueryFixture.stamp(city, Rect2i(1, 1, 3, 3), BuildingTileIds.OFFICE_PARK_3X3, 3)
	var result := TransportTripReachResult.new()
	result.ok = true
	result.limit = 100
	result.origin = Vector2i(5, 5)
	result.start = Vector2i(-1, -1)
	result.summary = PackedStringArray(["generated marker A", "generated marker B"])
	for mode in range(TransportTrip.SUBWAY_MODE + 1):
		result.reachable.append(TransportTripReachResult.ReachNode.new(Vector2i(5, 5), mode, mode * 9))
		result.reachable.append(TransportTripReachResult.ReachNode.new(Vector2i(6, 5), mode, mode * 9 + 1))
		result.links.append(TransportTripReachResult.Link.new(Vector2i(5, 5), Vector2i(6, 5), mode, mode, mode * 9 + 1))
	for ramp in 4:
		var point := Vector2i(8 + ramp, 8)
		city.set_building_id(point.x, point.y, BuildingTileIds.HIGHWAY_ONRAMP_1 + ramp)
		city.set_land_altitude(point.x, point.y, ramp)
		for mode in [TransportTrip.HIGHWAY_MODE, TransportTrip.ROAD_MODE, TransportTrip.BUS_HIGHWAY_MODE]:
			result.reachable.append(TransportTripReachResult.ReachNode.new(point, mode, 50))
			result.links.append(TransportTripReachResult.Link.new(point, point + Vector2i.DOWN, mode, mode, 60))
	# One elevated point has duplicate highway links and a different surface height.
	var highway := Vector2i(9, 6)
	result.reachable.append(TransportTripReachResult.ReachNode.new(highway, TransportTrip.HIGHWAY_MODE, 30))
	result.reachable.append(TransportTripReachResult.ReachNode.new(highway, TransportTrip.ROAD_MODE, 20))
	for mode in [TransportTrip.HIGHWAY_MODE, TransportTrip.BUS_HIGHWAY_MODE, TransportTrip.ROAD_MODE]:
		result.links.append(TransportTripReachResult.Link.new(highway, highway + Vector2i.RIGHT, mode, mode, 40))
	for point in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(-1, 0), Vector2i(16, 15)]:
		result.destinations[point] = 20
	result.limit_points[Vector2i(5, 5)] = "limit"
	result.limit_points[Vector2i(9, 6)] = "limit"
	result.limit_points[Vector2i(15, 15)] = "limit"
	return Fixture.new("modes", city, result)


static func values(overlay: RefCounted) -> Array:
	return [overlay.segments, overlay.colors, overlay.arrows, overlay.arrow_colors,
		overlay.markers, overlay.marker_colors, overlay.destinations, overlay.tile_costs,
		overlay.tile_modes, overlay.failed_points, overlay.origin, overlay.access]


static func digest(overlay: RefCounted) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(values(overlay)))
	return hash.finish().hex_encode()
