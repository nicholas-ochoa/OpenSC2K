extends "res://tests/support/core_test_suite.gd"

## Tools: highways checks.

@warning_ignore_start("integer_division")

const Highways = preload("res://src/tools/city/highway_command.gd")


func test_highway_command(reference_root: String) -> void:
	_check(Highways.supports_tool(6, 1), "Highway command supports its catalog tool")
	_check(not Highways.supports_tool(6, 0), "Highway command rejects the road tool")
	_check(HighwayGeometry.snap_anchor(Vector2i(11, 13)) == Vector2i(10, 12), "Highway pointer snaps to even coordinates")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Highway fixture clears %s" % chunk_id,
		)

	_check(document.set_misc_i32(0x14, 1000), "Highway fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Highway fixture counts clear tiles")
	var city := CityModel.from_document(document)
	var straight := Highways.apply(city, 6, 1, Vector2i(10, 10), Vector2i(14, 10))
	_check(straight.ok and straight.sections.size() == 3, "Highway drag builds three 2-by-2 sections")
	_check(straight.cost == 300 and city.funds() == 700, "Highway drag charges one hundred dollars per section")

	for x in range(10, 16):
		for y in range(10, 12):
			_check(city.building_id(x, y) == 0x4a, "Horizontal highway stores straight tile 0x4a")
			_check(city.zones[x * 128 + y] == 0xf0, "Straight highway sets all XZON corner bits")

	var highway_before: PackedByteArray = document.serialize().data

	for endpoints in [
		[Vector2i(14, 10), Vector2i(18, 10)],
		[Vector2i(6, 10), Vector2i(10, 10)],
		[Vector2i(10, 10), Vector2i(14, 10)],
	]:
		var reuse := Highways.apply(city, 6, 1, endpoints[0], endpoints[1])
		_check(reuse.ok and not reuse.stopped_early,
			"Highway routes can start, end and retrace existing highway sections")
		_check(reuse.cost == (0 if endpoints[0].x == 10 else 200),
			"Highway reuse charges only new sections")
		_check(Highways.undo(city, reuse).ok and document.serialize().data == highway_before,
			"Highway reuse Undo restores exact bytes")

	_check(Highways.undo(city, straight).ok, "Straight highway can be undone")
	_check(city.funds() == 1000 and city.building_id(12, 10) == 0, "Highway undo restores funds and tiles")

	var turn := Highways.apply(city, 6, 1, Vector2i(10, 10), Vector2i(12, 12))
	_check(turn.ok and turn.sections == [Vector2i(10, 10), Vector2i(10, 12), Vector2i(12, 12)], "Highway route follows the recovered dominant-axis rule")
	_check(city.building_id(10, 10) == 0x49, "Highway turn starts with a vertical section")
	_check(city.building_id(10, 12) == 0x65, "North-east highway turn uses shaped tile 0x65")
	_check(city.building_id(12, 12) == 0x4a, "Highway turn ends with a horizontal section")
	_check((city.zones[10 * 128 + 12] & 0xf0) != 0xf0, "Shaped highway stores a 2-by-2 corner mask")
	_check(Highways.undo(city, turn).ok, "Turning highway can be undone")

	_check(city.set_building_id(10, 10, Tiles.ROAD_STRAIGHT_2), "Highway crossing fixture places a horizontal road")
	_check(document.set_misc_u32(0x01f0, 16383), "Highway crossing fixture updates clear count")
	_check(document.set_misc_u32(0x01f0 + 0x1e * 4, 1), "Highway crossing fixture counts road")
	var crossing_city := CityModel.from_document(document)
	var crossing := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(10, 12))
	_check(crossing.ok, "Highway can cross a perpendicular road: %s" % crossing.error)
	_check(crossing_city.building_id(10, 10) == 0x4b, "Vertical highway and horizontal road use crossover 0x4b")
	_check(Highways.undo(crossing_city, crossing).ok, "Highway crossover can be undone")
	_check(crossing_city.set_building_id(10, 10, Tiles.EMPTY), "Highway obstruction fixture removes road")
	_check(crossing_city.set_building_id(14, 10, Tiles.CITY_HALL), "Highway obstruction fixture places a building")
	var partial := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(16, 10))
	_check(partial.ok and partial.stopped_early, "Highway route stops at an obstruction")
	_check(partial.sections == [Vector2i(10, 10), Vector2i(12, 10)], "Highway route keeps its clear prefix")
	_check(partial.cost == 200, "Partial highway charges only its clear sections")
	_check(Highways.undo(crossing_city, partial).ok, "Partial highway can be undone")
	_check(crossing_city.set_tile_flag(10, 10, 0x04, true), "Highway water fixture sets water")
	var water := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(10, 10))
	_check(
		not water.ok and not water.error.is_empty(),
		"Highway bridge start requires a valid 2-by-2 shoreline",
	)

	var bridge_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			bridge_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(size, 0)
			),
			"Highway bridge fixture clears %s" % chunk_id,
		)

	_check(bridge_document.set_misc_i32(0x14, 5000), "Highway bridge fixture sets funds")
	_check(
		bridge_document.set_misc_u32(0x01f0, CityState.TILE_COUNT),
		"Highway bridge fixture counts clear tiles",
	)
	var bridge_city := CityModel.from_document(bridge_document)

	for x in range(76, 88):
		for y in range(20, 22):
			var water_cell := x >= 80 and x < 86
			_check(
				bridge_city.set_land_altitude(x, y, 4 if water_cell else 6)
				and bridge_city.set_water_altitude(x, y, 5)
				and bridge_city.set_tile_flag(x, y, 0x04, water_cell)
				and bridge_city.set_terrain_id(x, y, 0x10 if water_cell else 0),
				"Highway bridge fixture writes its banks and water sections",
			)

	var bridge_request := Highways.apply(
		bridge_city, 6, 1, Vector2i(76, 20), Vector2i(84, 20)
	)
	_check(
		not bridge_request.ok
		and bridge_request.bridge_selection_required
		and bridge_request.sections == [Vector2i(76, 20), Vector2i(78, 20)]
		and bridge_request.bridge_span_length == 3
		and bridge_request.bridge_choices.size() == 2
		and bridge_request.bridge_choices[0].type == Highways.BRIDGE_HIGHWAY
		and bridge_request.bridge_choices[0].cost == 600
		and bridge_request.bridge_choices[1].type == Highways.BRIDGE_REINFORCED
		and bridge_request.bridge_choices[1].cost == 900
		and bridge_city.funds() == 5000,
		"Highway water route offers the normal and reinforced bridge types",
	)
	var canceled_bridge := Highways.apply(
		bridge_city,
		6,
		1,
		Vector2i(76, 20),
		Vector2i(84, 20),
		Highways.CONNECTION_UNSELECTED,
		Highways.BRIDGE_CANCELLED
	)
	_check(
		canceled_bridge.ok
		and canceled_bridge.bridge_cancelled
		and not canceled_bridge.bridge_built
		and canceled_bridge.sections.size() == 2
		and canceled_bridge.cost == 200
		and bridge_city.funds() == 4800
		and bridge_city.building_id(78, 20) == 0x4a
		and bridge_city.building_id(80, 20) == 0,
		"Canceling a highway bridge keeps and charges the dry prefix",
	)
	_check(
		Highways.undo(bridge_city, canceled_bridge).ok and bridge_city.funds() == 5000,
		"Canceled highway bridge prefix can be undone",
	)
	var normal_bridge := Highways.apply(
		bridge_city,
		6,
		1,
		Vector2i(76, 20),
		Vector2i(84, 20),
		Highways.CONNECTION_UNSELECTED,
		Highways.BRIDGE_HIGHWAY
	)
	_check(
		normal_bridge.ok
		and normal_bridge.bridge_built
		and normal_bridge.bridge_span_length == 3
		and normal_bridge.bridge_sections.size() == 3
		and normal_bridge.bridge_cost == 600
		and normal_bridge.cost == 800
		and bridge_city.funds() == 4200,
		"Normal highway bridge charges 200 dollars for each 2-by-2 section",
	)

	for x in range(80, 86):
		for y in range(20, 22):
			_check(
				bridge_city.building_id(x, y) == 0x4a
				and bridge_city.is_water(x, y)
				and (bridge_city.zones[x * 128 + y] & 0xf0) == 0xf0,
				"Normal highway bridge stores straight highway over water",
			)

	_check(
		bridge_city.building_id(86, 20) == 0,
		"Normal highway bridge does not construct a far-bank section",
	)
	_check(Highways.undo(bridge_city, normal_bridge).ok, "Normal highway bridge can be undone")
	_check(
		bridge_city.funds() == 5000 and bridge_city.building_id(80, 20) == 0,
		"Normal highway bridge undo restores funds and water sections",
	)

	var reinforced_bridge := Highways.apply(
		bridge_city,
		6,
		1,
		Vector2i(76, 20),
		Vector2i(84, 20),
		Highways.CONNECTION_UNSELECTED,
		Highways.BRIDGE_REINFORCED
	)
	_check(
		reinforced_bridge.ok
		and reinforced_bridge.bridge_built
		and reinforced_bridge.bridge_cost == 900
		and reinforced_bridge.cost == 1100
		and reinforced_bridge.bridge_endpoint_sections
		== [Vector2i(78, 20), Vector2i(86, 20)]
		and bridge_city.funds() == 3900,
		"Reinforced highway bridge charges 300 dollars per section and writes both banks",
	)
	_check(
		[
			bridge_city.building_id(80, 20),
			bridge_city.building_id(82, 20),
			bridge_city.building_id(84, 20),
		] == [0x6b, 0x6a, 0x6b]
		and bridge_city.building_id(78, 20) == 0x4a
		and bridge_city.building_id(86, 20) == 0x4a,
		"Reinforced highway bridge alternates deck and pylon sections",
	)

	for x in range(80, 86):
		for y in range(20, 22):
			_check(
				bridge_city.is_water(x, y)
				and (bridge_city.tile_flags[x * 128 + y] & 0x02) != 0,
				"Horizontal reinforced bridge stores its recovered mirror bit",
			)

	_check(
		Highways.undo(bridge_city, reinforced_bridge).ok
		and bridge_city.funds() == 5000
		and bridge_city.building_id(86, 20) == 0,
		"Reinforced highway bridge undo restores the far bank and funds",
	)

	_check(bridge_city.set_funds(1000), "Highway bridge funds fixture limits funds")
	var unaffordable_bridge := Highways.apply(
		bridge_city,
		6,
		1,
		Vector2i(76, 20),
		Vector2i(84, 20),
		Highways.CONNECTION_UNSELECTED,
		Highways.BRIDGE_REINFORCED
	)
	_check(
		unaffordable_bridge.ok
		and not unaffordable_bridge.bridge_built
		and not unaffordable_bridge.bridge_error.is_empty()
		and unaffordable_bridge.cost == 200
		and bridge_city.funds() == 800
		and bridge_city.building_id(78, 20) == 0x4a
		and bridge_city.building_id(80, 20) == 0,
		"Unaffordable reinforced bridge keeps the charged dry prefix",
	)
	_check(Highways.undo(bridge_city, unaffordable_bridge).ok, "Unaffordable bridge prefix can be undone")
	_check(bridge_city.set_funds(5000), "Highway bridge fixture restores funds")

	for entry in [
		[Vector2i(80, 20), 0, false],
		[Vector2i(81, 20), 0x10, true],
		[Vector2i(81, 21), 0x10, true],
		[Vector2i(80, 21), 0, false],
	]:
		_check(
			bridge_city.set_terrain_id(entry[0].x, entry[0].y, entry[1])
			and bridge_city.set_tile_flag(entry[0].x, entry[0].y, 0x04, entry[2]),
			"Direct highway bridge fixture writes its shoreline mask",
		)

	var direct_plan := HighwayBridges.plan_bridge_from_start(
		bridge_document.find_chunk("XBLD").decoded_payload,
		bridge_document.find_chunk("XTER").decoded_payload,
		bridge_document.find_chunk("ALTM").decoded_payload,
		Vector2i(80, 20),
		0
	)
	_check(
		HighwayBridges.bridge_terrain_code(
			bridge_document.find_chunk("XTER").decoded_payload, Vector2i(80, 20)
		) == 0x9060
		and direct_plan.ok
		and direct_plan.direction == 1
		and direct_plan.span_length == 3,
		"Direct highway bridge uses the recovered 2-by-2 shoreline direction table",
	)

	var connection_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			connection_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(size, 0)
			),
			"Highway connection fixture clears %s" % chunk_id,
		)

	_check(connection_document.set_misc_i32(0x14, 5000), "Highway connection fixture sets funds")
	_check(connection_document.set_misc_u32(0x01f0, 16384), "Highway connection fixture counts clear tiles")
	var connection_city := CityModel.from_document(connection_document)
	var connection_request := Highways.apply(
		connection_city, 6, 1, Vector2i(120, 10), Vector2i(126, 10)
	)
	_check(
		not connection_request.ok
		and connection_request.connection_selection_required
		and connection_request.connection_anchor == Vector2i(126, 10)
		and connection_request.connection_cost == 1500
		and connection_request.route_cost == 400
		and connection_city.funds() == 5000
		and connection_city.building_id(120, 10) == 0,
		"Highway exit requests the recovered neighbor connection before changing the city",
	)
	var canceled_connection := Highways.apply(
		connection_city,
		6,
		1,
		Vector2i(120, 10),
		Vector2i(126, 10),
		Highways.CONNECTION_CANCELLED
	)
	_check(
		canceled_connection.ok
		and canceled_connection.connection_cancelled
		and not canceled_connection.connection_built
		and canceled_connection.cost == 400
		and connection_city.funds() == 4600
		and connection_city.text_overlay_id(126, 10) == 0,
		"Canceling a neighbor connection still builds and charges the highway route",
	)
	_check(
		Highways.undo(connection_city, canceled_connection).ok
		and connection_city.funds() == 5000,
		"Canceled highway connection route can be undone",
	)
	var confirmed_connection := Highways.apply(
		connection_city,
		6,
		1,
		Vector2i(120, 10),
		Vector2i(126, 10),
		Highways.CONNECTION_CONFIRMED
	)
	_check(
		confirmed_connection.ok
		and confirmed_connection.connection_built
		and confirmed_connection.cost == 1900
		and confirmed_connection.connection_cost == 1500
		and connection_city.funds() == 3100
		and connection_city.text_overlay_id(126, 10) == 0xfa
		and connection_city.building_id(126, 10) == 0x4a,
		"Confirmed highway connection stores XTXT 0xFA and charges the recovered cost",
	)
	_check(
		Highways.undo(connection_city, confirmed_connection).ok
		and connection_city.funds() == 5000
		and connection_city.text_overlay_id(126, 10) == 0,
		"Highway connection undo restores the route, label, and funds",
	)

	var grade_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			grade_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(size, 0)
			),
			"Graded highway fixture clears %s" % chunk_id,
		)

	_check(grade_document.set_misc_i32(0x14, 5000), "Graded highway fixture sets funds")
	_check(
		grade_document.set_misc_u32(0x01f0, 16384),
		"Graded highway fixture counts clear tiles",
	)
	var grade_city := CityModel.from_document(grade_document)
	var north_slope := [
		[Vector2i(20, 20), 1],
		[Vector2i(21, 20), 1],
		[Vector2i(21, 21), 0],
		[Vector2i(20, 21), 0],
	]

	for entry in north_slope:
		_check(
			grade_city.set_terrain_id(entry[0].x, entry[0].y, entry[1]),
			"Graded highway fixture writes the north slope",
		)

	var north_grade := Highways.apply(
		grade_city, 6, 1, Vector2i(20, 20), Vector2i(20, 20)
	)
	_check(
		north_grade.ok
		and north_grade.graded_sections == 1
		and north_grade.cost == 100
		and grade_city.funds() == 4900,
		"A north slope builds one graded highway section for one hundred dollars",
	)

	for point in [Vector2i(20, 20), Vector2i(21, 20), Vector2i(21, 21), Vector2i(20, 21)]:
		_check(
			grade_city.building_id(point.x, point.y) == 0x62,
			"The north grade stores composite tile 0x62",
		)

	_check(
		[
			grade_city.terrain_id(20, 20),
			grade_city.terrain_id(21, 20),
			grade_city.terrain_id(21, 21),
			grade_city.terrain_id(20, 21),
		] == [0x0d, 0x0d, 0x02, 0x02],
		"The north grade writes the recovered terrain pattern",
	)
	_check(
		Highways.undo(grade_city, north_grade).ok
		and grade_city.funds() == 5000
		and grade_city.terrain_id(20, 20) == 1
		and grade_city.building_id(20, 20) == 0,
		"Graded highway undo restores terrain, tiles, and funds",
	)

	var east_slope := [
		[Vector2i(30, 30), 0],
		[Vector2i(31, 30), 1],
		[Vector2i(31, 31), 1],
		[Vector2i(30, 31), 0],
	]

	for entry in east_slope:
		_check(
			grade_city.set_terrain_id(entry[0].x, entry[0].y, entry[1]),
			"Graded highway fixture writes the east slope",
		)

	var east_grade := Highways.apply(
		grade_city, 6, 1, Vector2i(30, 30), Vector2i(30, 30)
	)
	_check(
		east_grade.ok
		and east_grade.graded_sections == 1
		and grade_city.building_id(30, 30) == 0x63,
		"An east slope builds composite highway tile 0x63",
	)
	_check(
		[
			grade_city.terrain_id(30, 30),
			grade_city.terrain_id(31, 30),
			grade_city.terrain_id(31, 31),
			grade_city.terrain_id(30, 31),
		] == [0x03, 0x0d, 0x0d, 0x03],
		"The east grade writes the recovered terrain pattern",
	)
	_check(Highways.undo(grade_city, east_grade).ok, "The east grade can be undone")

	var high_neighbor_points := [
		Vector2i(58, 60),
		Vector2i(59, 60),
		Vector2i(59, 61),
		Vector2i(58, 61),
	]

	for point in high_neighbor_points:
		_check(
			grade_city.set_building_id(point.x, point.y, Tiles.HIGHWAY_STRAIGHT_2)
			and grade_city.set_building_corners(point.x, point.y, 0xf0)
			and grade_city.set_land_altitude(point.x, point.y, 2),
			"Highway retile fixture installs a higher west section",
		)

	_check(
		grade_document.set_misc_u32(0x01f0, CityState.TILE_COUNT - 4)
		and grade_document.set_misc_u32(0x01f0 + 0x4a * 4, 4),
		"Highway retile fixture updates its tile counts",
	)
	var compound_slope := [
		[Vector2i(60, 60), 1],
		[Vector2i(61, 60), 0],
		[Vector2i(61, 61), 0],
		[Vector2i(60, 61), 0],
	]

	for entry in compound_slope:
		_check(
			grade_city.set_terrain_id(entry[0].x, entry[0].y, entry[1]),
			"Highway retile fixture writes a two-direction terrain mask",
		)

	var neighbor_grade := Highways.apply(
		grade_city, 6, 1, Vector2i(60, 60), Vector2i(60, 60)
	)
	_check(
		neighbor_grade.ok
		and neighbor_grade.graded_sections == 1
		and grade_city.building_id(60, 60) == 0x61
		and grade_city.building_id(58, 60) == 0x61,
		"A height transition converts both joined sections to grade kind 4",
	)
	_check(
		[
			grade_city.terrain_id(60, 60),
			grade_city.terrain_id(61, 60),
			grade_city.terrain_id(61, 61),
			grade_city.terrain_id(60, 61),
		] == [0x0d, 0x01, 0x01, 0x0d],
		"Elevation-aware highway retile writes the selected kind 4 terrain",
	)
	_check(
		Highways.undo(grade_city, neighbor_grade).ok
		and grade_city.building_id(60, 60) == 0
		and grade_city.building_id(58, 60) == 0x4a,
		"Elevation-aware grade undo preserves the pre-existing neighbor",
	)

	_check(
		grade_city.set_building_id(40, 40, Tiles.CITY_HALL),
		"Invalid highway grade fixture places a building",
	)
	_check(
		HighwayGeometry.terrain_section_shape(
			grade_document.find_chunk("XBLD").decoded_payload,
			grade_document.find_chunk("XTER").decoded_payload,
			grade_document.find_chunk("ALTM").decoded_payload,
			Vector2i(40, 40)
		) == Highways.INVALID_TERRAIN_SHAPE,
		"Highway terrain validation rejects an occupied section",
	)
	_check(
		grade_city.set_building_id(40, 40, Tiles.EMPTY),
		"Invalid highway grade fixture removes its building",
	)

	for x in range(52, 54):
		for y in range(50, 52):
			_check(
				grade_city.set_land_altitude(x, y, 2),
				"Highway elevation fixture raises the next section two levels",
			)

	var steep_route := Highways.apply(
		grade_city, 6, 1, Vector2i(50, 50), Vector2i(52, 50)
	)
	_check(
		steep_route.ok
		and steep_route.stopped_early
		and steep_route.sections == [Vector2i(50, 50)]
		and steep_route.cost == 100,
		"A highway route stops before a section more than one level away",
	)
	_check(Highways.undo(grade_city, steep_route).ok, "The stopped elevation route can be undone")

	for x in range(52, 54):
		for y in range(50, 52):
			_check(
				grade_city.set_land_altitude(x, y, 1),
				"Highway elevation fixture lowers the next section to one level",
			)

	var stepped_route := Highways.apply(
		grade_city, 6, 1, Vector2i(50, 50), Vector2i(52, 50)
	)
	_check(
		stepped_route.ok
		and not stepped_route.stopped_early
		and stepped_route.sections.size() == 2
		and stepped_route.cost == 200,
		"A highway route accepts a section one level away",
	)
	_check(Highways.undo(grade_city, stepped_route).ok, "The one-level route can be undone")
