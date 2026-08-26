extends SceneTree

@warning_ignore_start("integer_division")
const DocumentState = preload("res://tests/support/document_state.gd")

var fixtures: Dictionary = {}
var checks := 0
var failures := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func fixture(edge: int, native: bool) -> CityState:
	var key := Vector2i(edge, int(native))
	if not fixtures.has(key):
		var document := EmptyCityTemplate.create(edge)
		if native:
			document.enable_full_resolution_maps()
		CityState.from_document(document).set_funds(1000000)
		fixtures[key] = document
	return CityState.from_document(fixtures[key].duplicate_document())


func _initialize() -> void:
	for edge in [128, 256, 384, 512]:
		for native in [false, true]:
			_test_highway(edge, native)
			_test_branches(edge, native)
			_test_station_and_tunnel(edge, native)
	_test_walking_cache()
	_test_multimodal()
	_test_dead_end_turns()
	_test_overpasses()
	_test_curve()
	_test_lane_geometry()
	_test_ui()
	print("Trip reach: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_highway(edge: int, native: bool) -> void:
	var city := fixture(edge, native)
	var shift := Vector2i(edge - 100, edge - 100)
	var a := Vector2i(20, 20) + shift
	var b := Vector2i(60, 20) + shift
	check(HighwayCommand.apply(city, 6, 1, a, b, 0).ok, "Place highway")
	# Both ramps attach to the eastbound outside lane.
	city.set_building_id(a.x - 1, a.y + 2, 0x1d)
	city.set_building_id(b.x + 1, b.y + 2, 0x1d)
	check(OnrampCommand.apply(city, 6, 3, a + Vector2i(0, 2)).ok, "Place entry ramp")
	check(OnrampCommand.apply(city, 6, 3, b + Vector2i(0, 2)).ok, "Place exit ramp")
	var origin := a + Vector2i(-2, 2)
	var destination := b + Vector2i(2, 2)
	city.set_zone_id(origin.x, origin.y, 1)
	city.set_zone_id(destination.x, destination.y, 3)
	var first_cost := -1
	for seed in [1, 2, 7, 29]:
		var result := TransportTrip.run(city, origin, 1, 2, SimRandom.new(seed))
		check(result.ok and result.reached_destination, "Every seed reaches a valid highway destination at edge %d" % edge)
		if first_cost < 0:
			first_cost = result.cost
		check(result.cost == first_cost and result.cost < 75, "Highway cost is stable and below low-density budget")
	var before: Array = DocumentState.capture(city.document)
	var diagnostic := TripReachAnalysis.inspect(city, origin)
	check(diagnostic.reached_destination, "Diagnostic agrees with simulation")
	check(DocumentState.capture(city.document) == before, "Inspection does not change any city bytes")
	var reached := {}
	for node: Dictionary in diagnostic.reachable:
		reached[node.point] = true
		check(node.cost < diagnostic.limit, "All displayed states are within budget")
	check(reached.has(a + Vector2i(10, 1)), "Correct lane is reached")
	check(reached.has(a + Vector2i(10, 0)), "Trip reaches the return lane through the highway endpoint")
	# Reverse-direction travel must go around the endpoints to use the return lane.
	var reverse := TransportTrip.run(city, destination, 3, 2, SimRandom.new(1))
	check(reverse.reached_destination and reverse.cost > first_cost, "Reverse trip uses longer endpoint turnaround route")
	for ccw in ([false, true] if edge == 128 and not native else []):
		var rotated := CityState.from_document(city.document.duplicate_document())
		var rotated_origin := origin
		for turn in 4:
			CityRotationCommand.apply(rotated, ccw)
			rotated_origin = CityRotationCommand.rotate_point(rotated_origin, edge, ccw)
			var result := TransportTrip.run(rotated, rotated_origin, 1, 2, SimRandom.new(1))
			check(result.reached_destination and result.cost == first_cost, "Highway reach and cost survive rotation")


func _test_branches(edge: int, native: bool) -> void:
	var city := fixture(edge, native)
	for x in range(20, 61):
		city.set_building_id(x, 20, 0x1d)
	city.set_zone_id(20, 21, 3)
	for seed in [1, 7, 29]:
		check(TransportTrip.run(city, Vector2i(19, 20), 1, 2, SimRandom.new(seed)).reached_destination,
			"Long dead-end branch cannot hide a short destination")
	city.set_zone_id(20, 21, 0)
	city.set_zone_id(61, 20, 3)
	check(not TransportTrip.run(city, Vector2i(19, 20), 1, 2, SimRandom.new(1)).reached_destination,
		"Road still obeys the trip cost limit")
	city.set_zone_id(61, 20, 0)
	city.set_zone_id(48, 20, 3)
	check(TransportTrip.run(city, Vector2i(19, 20), 1, 2, SimRandom.new(1)).reached_destination,
		"Normal density has a 100-unit limit")
	check(not TransportTrip.run(city, Vector2i(19, 20), 1, 1, SimRandom.new(1)).reached_destination,
		"Density one keeps its 75-unit limit")


func _test_station_and_tunnel(edge: int, native: bool) -> void:
	var city := fixture(edge, native)
	city.set_building_id(20, 23, 0xed)
	for y in range(24, 34):
		city.set_building_id(20, y, 0x2c)
	city.set_building_id(20, 34, 0xed)
	city.set_zone_id(20, 37, 3)
	var trip := TransportTrip.run(city, Vector2i(20, 20), 1, 2, SimRandom.new(1))
	check(trip.reached_destination and trip.used_rail, "Three-tile station access works at both ends")
	city.set_zone_id(20, 37, 0)
	city.set_zone_id(20, 38, 3)
	check(not TransportTrip.run(city, Vector2i(20, 20), 1, 2, SimRandom.new(1)).reached_destination,
		"Station catchment does not extend to four tiles")
	city = fixture(edge, native)
	city.set_building_id(20, 20, 0x1d)
	city.set_building_id(20, 21, 0x3f)
	for y in range(22, 25):
		city.altitude_words[20 * edge + y] = 0x400
	city.set_building_id(20, 25, 0x40)
	city.set_building_id(20, 26, 0x1d)
	city.set_zone_id(20, 29, 3)
	trip = TransportTrip.run(city, Vector2i(20, 19), 1, 2, SimRandom.new(1))
	check(trip.reached_destination and trip.cost == 18, "Car traverses tunnel in tunnel mode at road cost")


func _test_lane_geometry() -> void:
	var city := fixture(128, false)
	for tile: int in TransportTrip.HIGHWAY_PORTS:
		for x in range(18, 24):
			for y in range(18, 24):
				city.set_building_id(x, y, tile)
		var ports: int = TransportTrip.HIGHWAY_PORTS[tile]
		for direction in 4:
			var corner: Vector2i = TransportTrip.LANE_CORNERS[TransportTrip.EGRESS_CORNERS[direction]]
			var point := Vector2i(20, 20) + corner
			var next_point: Vector2i = point + TransportTrip.DIRECTIONS[direction]
			var allowed := TransportTripSteps.highway_step(city.buildings, point, next_point, 128)
			check(allowed == ((ports & (1 << direction)) != 0 and (ports & (1 << ((direction + 2) & 3))) != 0),
				"External highway movement respects both section ports")


func _test_ui() -> void:
	var city := fixture(128, false)
	city.set_building_id(20, 21, 0x1d)
	city.set_building_id(20, 22, 0x1d)
	city.set_zone_id(20, 20, 1)
	city.set_zone_id(20, 23, 3)
	var view := CityMapControl.new()
	var result := view.show_trip_reach(city, Vector2i(20, 20))
	check(result.ok and result.reached_destination, "Map accepts Trip Reach selection")
	check(not view.trip_reach.segments.is_empty(), "Reach overlay contains vector segments")
	check(result.summary.is_empty(), "Reach summary omits coordinates, power, and demand")
	check(ToolCatalog.tool(16, 1).id == "trip_reach", "Query has a Trip Reach child")
	check(ToolEditState.normal(city, CityViewMode.Mode.CITY, 16, 1).enabled, "Trip Reach is enabled")
	check(ToolEditState.normal(city, CityViewMode.Mode.UNDERGROUND, 16, 1).enabled, "Trip Reach works underground")
	var palette := CityChildToolPalette.new()
	palette.build()
	palette.show_tool_group(16, city)
	check(palette.scroll.visible and palette.buttons.has(1), "Query palette exposes the Trip Reach button")
	palette.free()
	view.clear_trip_reach()
	check(view.trip_reach == null, "Reach overlay clears")
	view.free()


func _test_multimodal() -> void:
	var city := fixture(128, false)
	city.set_building_id(20, 21, 0xec)
	for y in range(22, 61):
		city.set_building_id(20, y, 0x1d)
	city.set_zone_id(20, 63, 3)
	var result := TransportTrip.run(city, Vector2i(20, 20), 1, 2, SimRandom.new(1))
	check(result.reached_destination and result.used_bus and result.cost == 78, "Bus route keeps its two-unit road cost")
	city = fixture(128, false)
	city.set_building_id(20, 21, 0xe9)
	for y in range(22, 62):
		city.set_underground_id(20, y, 1)
	city.set_building_id(20, 61, 0xe9)
	city.set_zone_id(20, 64, 3)
	result = TransportTrip.run(city, Vector2i(20, 20), 1, 2, SimRandom.new(1))
	check(result.reached_destination and result.used_subway, "Subway keeps mode transitions and destination catchment")
	city = fixture(128, false)
	city.set_building_id(20, 21, 0x1d)
	for y in range(22, 26):
		city.set_building_id(20, y, 0x51)
	city.set_building_id(20, 26, 0x1d)
	city.set_zone_id(20, 27, 3)
	result = TransportTrip.run(city, Vector2i(20, 20), 1, 2, SimRandom.new(1))
	check(result.reached_destination and result.cost == 15, "Road bridge keeps straight heading and road cost")


func _test_curve() -> void:
	var city := fixture(128, false)
	check(HighwayCommand.apply(city, 6, 1, Vector2i(20, 20), Vector2i(30, 20), 0).ok, "Place first curve leg")
	check(HighwayCommand.apply(city, 6, 1, Vector2i(30, 20), Vector2i(30, 30), 0).ok, "Place second curve leg")
	city.set_building_id(19, 22, 0x1d)
	city.set_building_id(29, 31, 0x1d)
	check(OnrampCommand.apply(city, 6, 3, Vector2i(20, 22)).ok, "Place curve entry")
	check(OnrampCommand.apply(city, 6, 3, Vector2i(29, 30)).ok, "Place curve exit")
	city.set_zone_id(18, 22, 1)
	city.set_zone_id(29, 32, 3)
	var origin := Vector2i(18, 22)
	for turn in 4:
		var result := TransportTrip.run(city, origin, 1, 2, SimRandom.new(1))
		check(result.reached_destination, "Trip follows a constructed highway curve")
		CityRotationCommand.apply(city, false)
		origin = CityRotationCommand.rotate_point(origin, 128, false)


func _test_overpasses() -> void:
	for edge: int in [128, 512]:
		for network: int in ([0, 1, 2] if edge == 128 else [0]):
			for highway_first in ([false, true] if edge == 128 else [false]):
				var city := fixture(edge, false)
				var shift := Vector2i.ONE * (edge - 100)
				var a := Vector2i(20, 20) + shift
				var b := Vector2i(60, 20) + shift
				var under_start := Vector2i(40, 10) + shift
				var under_end := Vector2i(40, 32) + shift
				var group: int = [6, 7, 3][network]
				if highway_first:
					check(HighwayCommand.apply(city, 6, 1, a, b, 0).ok, "Place highway before crossing")
				check(NetworkCommand.apply(city, group, 0, under_start, under_end).ok, "Place road, rail, or power crossing")
				if not highway_first:
					check(HighwayCommand.apply(city, 6, 1, a, b, 0).ok, "Place highway over existing network")
				city.set_building_id(a.x - 1, a.y + 2, 0x1d)
				city.set_building_id(b.x + 1, b.y + 2, 0x1d)
				check(OnrampCommand.apply(city, 6, 3, a + Vector2i(0, 2)).ok, "Place overpass entry ramp")
				check(OnrampCommand.apply(city, 6, 3, b + Vector2i(0, 2)).ok, "Place overpass exit ramp")
				var origin := a + Vector2i(-2, 2)
				var destination := b + Vector2i(2, 2)
				city.set_zone_id(origin.x, origin.y, 1)
				city.set_zone_id(destination.x, destination.y, 3)
				for rotation in (4 if edge == 128 else 1):
					var trip := TransportTrip.run(city, origin, 1, 2, SimRandom.new(1))
					check(trip.reached_destination, "Highway trip continues across each overpass orientation and build order")
					var reach := TripReachAnalysis.inspect(city, origin)
					check(reach.reached_destination, "Highway overlay continues across the overpass")
					if network < 2:
						var under := TripReachAnalysis.inspect(city, under_start)
						var points := {}
						for node: Dictionary in under.reachable:
							points[node.point] = true
						check(points.has(under_end), "Road and rail trips continue under the highway")
					if edge != 128 or rotation == 3:
						continue
					CityRotationCommand.apply(city, false)
					origin = CityRotationCommand.rotate_point(origin, edge, false)
					under_start = CityRotationCommand.rotate_point(under_start, edge, false)
					under_end = CityRotationCommand.rotate_point(under_end, edge, false)


func _test_dead_end_turns() -> void:
	for edge: int in [128, 256, 384, 512]:
		var city := fixture(edge, false)
		var a := Vector2i(edge - 40, edge - 40)
		var b := a + Vector2i(20, 0)
		check(HighwayCommand.apply(city, 6, 1, a, b, 0).ok, "Construct highway with open ends")
		var end_lane := b + Vector2i(1, 1)
		var return_lane := b + Vector2i(1, 0)
		var middle := a + Vector2i(11, 1)
		var middle_across := a + Vector2i(11, 0)
		for rotation in (4 if edge == 128 else 1):
			check(TransportTripSteps.highway_step(city.buildings, end_lane, return_lane, edge), "Open highway end permits a median turnaround")
			check(not TransportTripSteps.highway_step(city.buildings, middle, middle_across, edge), "Connected highway does not permit a median shortcut")
			for mode in [TransportTrip.HIGHWAY_MODE, TransportTrip.BUS_HIGHWAY_MODE]:
				check(TransportTripSteps.advance(city.buildings, city.zones, city.underground,
					city.text_overlays, city.altitude_words, end_lane, return_lane, mode, 1, edge) == ((mode << 8) | 1),
					"Car and bus turnaround costs one highway step")
			var result := TripReachAnalysis.inspect(city, middle)
			check(result.expanded_states <= 88, "End turnarounds terminate without repeatedly circling")
			if edge != 128 or rotation == 3:
				continue
			CityRotationCommand.apply(city, false)
			end_lane = CityRotationCommand.rotate_point(end_lane, edge, false)
			return_lane = CityRotationCommand.rotate_point(return_lane, edge, false)
			middle = CityRotationCommand.rotate_point(middle, edge, false)
			middle_across = CityRotationCommand.rotate_point(middle_across, edge, false)
		var boundary := fixture(edge, false)
		for x in range(edge - 4, edge):
			boundary.set_building_id(x, 20, 0x4a)
			boundary.set_building_id(x, 21, 0x4a)
		check(TransportTripSteps.highway_step(boundary.buildings, Vector2i(edge - 1, 21), Vector2i(edge - 1, 20), edge),
			"True map edge permits a safe turnaround")


## Compare cached and uncached searches, including their traffic and RNG writes.
func _compare_walking_cache(scan: GrowthScan.TileScan, point: Vector2i, zone: int, mode: int) -> void:
	var cached_random := SimRandom.new(123)
	var direct_random := SimRandom.new(123)
	var cached_traffic := scan.traffic.duplicate()
	var direct_traffic := scan.traffic.duplicate()
	var start := (mode << (14 if scan.map_edge == 128 else 18)) | (point.x * scan.map_edge + point.y)
	var direct := TransportTripSearch.trace(scan.buildings, scan.zones, scan.underground,
		scan.text_overlays, scan.altitudes, direct_traffic, point, zone, 2,
		direct_random, 10, scan.map_edge, false, start)
	var cached := TransportTripSearch.trace(scan.buildings, scan.zones, scan.underground,
		scan.text_overlays, scan.altitudes, cached_traffic, point, zone, 2,
		cached_random, 10, scan.map_edge, false, start, scan.walking_access[(zone + 1) >> 1])
	check(cached == direct, "Cached trip keeps every result field")
	check(cached_random.state == direct_random.state, "Cached trip keeps random state")
	check(cached_traffic == direct_traffic, "Cached trip keeps traffic bytes")


func _test_walking_cache() -> void:
	for edge in [128, 512]:
		var city := fixture(edge, false)
		var payloads := GrowthState.payloads(city)
		var scan := GrowthScan.TileScan.new(city, payloads, SimRandom.new(1),
			SimLfsrRandom.new(1), GameLcgRandom.new(1), SimulationTimingSpan.new())
		# All four boundaries, the inner seam, all 24 offsets, and all zone bits.
		var points := [Vector2i.ZERO, Vector2i(edge - 1, 0), Vector2i(0, edge - 1),
			Vector2i(edge - 1, edge - 1), Vector2i(edge / 2, edge / 2)]
		for point: Vector2i in points:
			for offset_index in TransportTrip.TRANSPORT_OFFSETS.size():
				var target: Vector2i = point + TransportTrip.TRANSPORT_OFFSETS[offset_index]
				var index := TransportTripSteps._index(target, edge)
				if index >= 0:
					scan.zones[index] = (offset_index % 16) | 0xa0
			for zone in 7:
				_compare_walking_cache(scan, point, zone, TransportTrip.ROAD_MODE)
				_compare_walking_cache(scan, point, zone, TransportTrip.ROAD_MODE)
		# Every mode reads the same populated cache without gaining foot access.
		for mode in 14:
			_compare_walking_cache(scan, points[-1], 1, mode)

		var church := Vector2i(20, 20)
		for x in range(20, 22):
			for y in range(19, 21):
				scan.zones[x * edge + y] = 1
		var access := Vector2i(18, 20)
		_compare_walking_cache(scan, access, 3, TransportTrip.ROAD_MODE)
		check(scan.walking_access[2][access.x * edge + access.y] == 2, "Residential zone gives commercial walking access")
		GrowthState._write_u32(scan.misc, GrowthConstants.MISC_NORMAL_POPULATION, 10000)
		GrowthState._write_u32(scan.misc, GrowthConstants.MISC_TILE_COUNTS + GrowthConstants.CHURCH_TILE * 4, 0)
		for unused in 100:
			if scan._try_complete_construction(church, 1, 2):
				break
		check(scan.churches_built == 1, "Construction places the church through the scan")
		_compare_walking_cache(scan, access, 3, TransportTrip.ROAD_MODE)
		check(scan.walking_access[2][access.x * edge + access.y] == 1, "Church removes cached commercial walking access")
