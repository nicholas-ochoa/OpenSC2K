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

	_test_subway_scenario()
	_test_scenarios()
	_test_building_coverage()
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


func _test_building_coverage() -> void:
	for edge: int in [128, 256, 384, 512]:
		for distance in range(1, 5):
			var city := CityState.from_document(EmptyCityTemplate.create(edge))
			var shift := Vector2i.ONE * (edge - 100)
			var origin := shift + Vector2i(20, 19)
			var target := shift + Vector2i(35, 20 + distance)
			for x in range(20, 36):
				city.set_building_id(x + shift.x, 20 + shift.y, 0x1e)
			TripQueryFixture.stamp(city, Rect2i(origin, Vector2i.ONE), 0x70, 1)
			TripQueryFixture.stamp(city, Rect2i(target, Vector2i.ONE), 0x7c, 3)
			for rotation in 4:
				var result := TripReachAnalysis.inspect(city, origin)
				var trip := TransportTrip.run(city, origin, 1, 1, SimRandom.new(1))
				check(result.destinations.has(target) == (distance <= 3), "Road arrival catchment includes three tiles, excludes four, at every rotation and map size")
				check(trip.reached_destination == result.reached_destination, "Growth and displayed walking destinations agree")
				CityRotationCommand.apply(city, false)
				origin = CityRotationCommand.rotate_point(origin, edge, false)
				target = CityRotationCommand.rotate_point(target, edge, false)
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var block := TripQueryFixture.add_block(city)
	var origin := block.position + Vector2i(3, 3)
	var result := TripReachAnalysis.inspect(city, origin)
	var overlay := TripReachOverlay.new()
	overlay.rebuild(city, result)
	for x in range(block.position.x + 1, block.end.x - 1):
		for y in range(block.position.y + 1, block.end.y - 1):
			var point := Vector2i(x, y)
			check(result.destinations.has(point) == ((city.zones[city.index_of(x, y)] & 15) == 3), "Every compatible building in the filled block has a checkmark")
			check("Not reached" not in overlay.tile_tooltip(point), "Every interior building has an accurate access tooltip")
	var network := TripReachAnalysis.inspect(city, block.position)
	check(network.destinations.size() == 36, "Direct network query shows every RCI building in its catchment")
	city = CityState.from_document(EmptyCityTemplate.create(128))
	var route := TripQueryFixture.add_route(city, 2, 3, "road")
	result = TripReachAnalysis.inspect(city, route.origin)
	overlay.rebuild(city, result)
	for x in range(route.destination.position.x, route.destination.end.x):
		for y in range(route.destination.position.y, route.destination.end.y):
			check("Destination:" in overlay.tile_tooltip(Vector2i(x, y)), "All destination footprint tiles have a destination tooltip")
	check("Origin:" in overlay.tile_tooltip(route.source.position), "All source footprint tiles have an origin tooltip")
	check(overlay.destinations.size() == 1, "Multi-tile destination has one centered checkmark")
	city = CityState.from_document(EmptyCityTemplate.create(128))
	for x in range(20, 40):
		city.set_building_id(x, 20, 0x2d)
	TripQueryFixture.stamp(city, Rect2i(30, 23, 1, 1), 0x7c, 3)
	result = TripReachAnalysis.inspect(city, Vector2i(20, 20))
	check(result.destinations.is_empty(), "Bare rail has no walking destination catchment")
	check(result.access_tiles.is_empty(), "Bare rail does not label nearby buildings as having access")


func _test_scenarios() -> void:
	for variant in 3:
		var city := CityState.from_document(EmptyCityTemplate.create(128))
		city.set_funds(1000000)
		var scenario := TripQueryFixture.add_scenario(city, variant, Vector2i(16, 12))
		var result := TripReachAnalysis.inspect(city, scenario.origin)
		check(result.reached_destination == (variant > 0), "Long road fails budget; parallel highway and rail enable access")
		var modes := {}
		for node: Dictionary in result.reachable:
			modes[node.mode] = true
		check(modes.has(TransportTrip.HIGHWAY_MODE) == (variant > 0), "Scenario explores highway when present")
		check(modes.has(TransportTrip.RAIL_MODE) == (variant == 2), "Scenario explores rail when stations are present")


func _test_subway_scenario() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	city.set_funds(1000000)
	var scenario := TripQueryFixture.add_subway_scenario(city, Vector2i(16, 102))
	var before: PackedByteArray = city.document.serialize().data
	var result := TripReachAnalysis.inspect(city, scenario.origin)
	check(result.reached_destination and result.used_subway, "Subway scenario reaches industry through both stations")
	check(city.underground_id(scenario.entrance.x, scenario.entrance.y) == 0x23,
		"Subway scenario uses a real underground station entrance")
	var found := false
	for node: Dictionary in result.reachable:
		if node.point == scenario.underground_midpoint and node.mode == TransportTrip.SUBWAY_MODE:
			found = true
	check(found, "Trip Query explores the bent underground route")
	var subway_links := 0
	for link: Dictionary in result.links:
		var underground: bool = link.mode == TransportTrip.SUBWAY_MODE or link.from_mode == TransportTrip.SUBWAY_MODE
		var color := TripReachOverlay.route_color(link, result.limit)
		if underground:
			subway_links += 1
			check(color == TripReachOverlay.UNDERGROUND_COLOR, "Subway links and station transitions use purple")
		else:
			check(color == TripReachOverlay.heat_color(float(link.cost) / result.limit), "Surface links retain the trip-cost heatmap")
	check(subway_links > 0, "Subway fixture has purple underground links")
	var overlay := TripReachOverlay.new()
	overlay.rebuild(city, result)
	check(overlay.colors.size() * 2 == overlay.segments.size(), "Each drawn line segment has one color")
	for index in result.links.size():
		check(overlay.colors[index] == TripReachOverlay.route_color(result.links[index], result.limit),
			"Rendered segment colors match their corresponding transport links")
	check(overlay.destinations.size() == 2, "Both industrial buildings have destination markers")
	check(city.document.serialize().data == before, "Subway inspection preserves saved city bytes")
	var exit_tile := city.building_id(scenario.exit_station.x, scenario.exit_station.y)
	city.set_building_id(scenario.exit_station.x, scenario.exit_station.y, 0)
	check(not TripReachAnalysis.inspect(city, scenario.origin).reached_destination,
		"Subway cannot deliver passengers without the exit station")
	city.set_building_id(scenario.exit_station.x, scenario.exit_station.y, exit_tile)
	city.set_underground_id(scenario.underground_midpoint.x, scenario.underground_midpoint.y, 0)
	check(not TripReachAnalysis.inspect(city, scenario.origin).reached_destination,
		"A gap in the subway stops the trip")
