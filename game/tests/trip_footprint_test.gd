extends SceneTree

var checks := 0
var failures := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _initialize() -> void:
	for edge in [128, 512]:
		for network in ["road", "rail", "highway"]:
			for source_size in range(1, 5):
				for destination_size in range(1, 5):
					var city := CityState.from_document(EmptyCityTemplate.create(edge))
					city.set_funds(1000000)
					var base := Vector2i(edge - 60, edge - 60)
					var route := TripQueryFixture.add_route(city, source_size, destination_size, network, base)
					var label := "%d %s %dx%d to %dx%d" % [edge, network, source_size, source_size, destination_size, destination_size]
					var inspected := TripReachAnalysis.inspect(city, route.origin)
					var expected: bool = destination_size < 4 or network == "rail"
					if source_size < 4:
						var trip := TransportTrip.run(city, route.origin, 1,
							GrowthPhase._density(TripQueryFixture.SOURCE_TILES[source_size]), SimRandom.new(7))
						check(trip.reached_destination == expected, label + " simulation destination rule")
						check(inspected.reached_destination == trip.reached_destination, label + " inspection matches simulation")
					else:
						check(not inspected.rci, label + " arcology is exploration, not an RCI growth source")

					for x in range(route.source.position.x, route.source.end.x):
						for y in range(route.source.position.y, route.source.end.y):
							var part := TripReachAnalysis.inspect(city, Vector2i(x, y))
							check(part.origin == route.origin, label + " every source tile resolves to the same anchor")
							check(part.reached_destination == inspected.reached_destination and part.cost == inspected.cost,
								label + " every source tile has the same outcome")
					for point: Vector2i in inspected.get("destinations", {}):
						check(route.destination.has_point(point), label + " destination marker belongs to the destination footprint")

	_test_block_and_endpoints()
	print("Trip footprints: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_block_and_endpoints() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var block := TripQueryFixture.add_block(city)
	for x in range(block.position.x + 1, block.end.x - 1):
		for y in range(block.position.y + 1, block.end.y - 1):
			var distance := mini(mini(x - block.position.x, block.end.x - 1 - x),
				mini(y - block.position.y, block.end.y - 1 - y))
			check(distance <= 3, "Filled block has a maximum three-tile access distance")
			var analysis := TripReachAnalysis.inspect(city, Vector2i(x, y))
			check(analysis.reached_destination and analysis.powered, "Every building in the block has a compatible destination and power")
	var inspected := TripReachAnalysis.inspect(city, block.position + Vector2i(3, 3))
	var endpoint := Vector2i(block.end.x + 8, block.position.y + 3)
	check(not inspected.limit_points.has(endpoint), "Dead ends do not show a red X")
	check(not inspected.limit_points.has(block.position + Vector2i(7, 3)), "Connected junction is not marked as a limit")
	var before: PackedByteArray = city.document.serialize().data
	var view := CityMapControl.new()
	view.show_trip_reach(city, block.position + Vector2i(3, 3))
	check(view.trip_reach.failed_points.is_empty(), "Short dead-end spur has no limit markers")
	var long_route := CityState.from_document(EmptyCityTemplate.create(128))
	for x in range(20, 100):
		long_route.set_building_id(x, 20, 0x1d)
	var limited := view.show_trip_reach(long_route, Vector2i(20, 20))
	check(limited.limit_points.has(Vector2i(53, 20)), "Red X marks the last road tile before the trip limit")
	check(view.trip_reach.failed_points.size() == 1, "Long route has one trip-limit marker")
	check(city.document.serialize().data == before, "Endpoint inspection leaves city bytes unchanged")
	view.free()
