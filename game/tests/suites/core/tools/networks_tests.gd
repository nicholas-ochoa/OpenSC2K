extends "res://tests/support/core_test_suite.gd"

## Tools: networks checks.

@warning_ignore_start("integer_division")

const Power = preload("res://src/simulation/infrastructure/power_phase.gd")
const Networks = preload("res://src/tools/city/network_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")


func test_network_command(reference_root: String) -> void:
	_check(Networks.supports_tool(6, 0), "Network command supports roads")
	_check(Networks.supports_tool(7, 1), "Network command supports subways")
	_check(not Networks.supports_tool(6, 1), "Highways remain a separate network tool")
	_check(
		NetworkRoutes.route(Vector2i(10, 10), Vector2i(13, 12))
		== [Vector2i(10, 10), Vector2i(11, 10), Vector2i(11, 11), Vector2i(12, 11), Vector2i(12, 12), Vector2i(13, 12)],
		"Network route follows the recovered dominant-axis rule",
	)

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Network fixture clears %s" % chunk_id,
		)

	_check(document.set_misc_i32(0x14, 10000), "Network fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Network fixture counts clear tiles")
	_check(document.set_misc_u32(0x0fe8, 0), "Network fixture clears subway count")
	var city := CityModel.from_document(document)

	var road := Networks.apply(city, 6, 0, Vector2i(10, 10), Vector2i(14, 10))
	_check(road.ok and road.points.size() == 5, "Road drag builds five tiles")
	_check(road.cost == 50 and city.funds() == 9950, "Road drag charges ten dollars per route tile")

	for x in range(10, 15):
		_check(city.building_id(x, 10) == 0x1e, "Road drag stores a connected road shape")

	_check(Networks.undo(city, road).ok, "Road drag can be undone")
	_check(city.funds() == 10000 and city.building_id(12, 10) == 0, "Road undo restores funds and tiles")

	for group in [6, 7, 3]:
		var tile_cost := 2 if group == 3 else (10 if group == 6 else 25)
		var base := Networks.apply(city, group, 0, Vector2i(50, 48), Vector2i(50, 52))
		_check(base.ok, "Reuse fixture builds its existing network")
		var before: PackedByteArray = document.serialize().data

		for endpoints in [
			[Vector2i(50, 50), Vector2i(53, 50)],
			[Vector2i(47, 50), Vector2i(50, 50)],
			[Vector2i(48, 50), Vector2i(52, 50)],
			[Vector2i(50, 48), Vector2i(50, 52)],
			[Vector2i(50, 50), Vector2i(50, 50)],
		]:
			var command := Networks.apply(city, group, 0, endpoints[0], endpoints[1])
			var new_count := 0 if endpoints[0].x == endpoints[1].x else absi(endpoints[1].x - endpoints[0].x)
			_check(command.ok and not command.stopped_early,
				"Road, rail and power routes start, end, cross, retrace and click existing networks")
			_check(command.cost == new_count * tile_cost,
				"Existing network tiles have no repeat construction charge")

			if endpoints[0].x == 48:
				_check(city.building_id(50, 50) == (0x1c if group == 3 else (0x2b if group == 6 else 0x3a)),
					"Crossing the same network forms a four-way junction")

			_check(Networks.undo(city, command).ok and document.serialize().data == before,
				"Reused network route Undo restores exact bytes")

		_check(Networks.undo(city, base).ok, "Reuse fixture restores the original map")

	var road_connection_request := Networks.apply(
		city, 6, 0, Vector2i(124, 40), Vector2i(127, 40)
	)
	_check(
		not road_connection_request.ok
		and road_connection_request.connection_selection_required
		and road_connection_request.connection_anchor == Vector2i(127, 40)
		and road_connection_request.connection_cost == 1000
		and road_connection_request.dry_cost == 40
		and city.funds() == 10000
		and city.building_id(124, 40) == 0,
		"A road dragged out of the map requests its recovered neighbor connection",
	)
	var canceled_road_connection := Networks.apply(
		city,
		6,
		0,
		Vector2i(124, 40),
		Vector2i(127, 40),
		Networks.BRIDGE_UNSELECTED,
		Networks.CONNECTION_CANCELLED
	)
	_check(
		canceled_road_connection.ok
		and canceled_road_connection.connection_cancelled
		and not canceled_road_connection.connection_built
		and canceled_road_connection.cost == 40
		and city.funds() == 9960
		and city.text_overlay_id(127, 40) == 0,
		"Canceling a road connection keeps and charges the dry route",
	)
	_check(
		Networks.undo(city, canceled_road_connection).ok and city.funds() == 10000,
		"Canceled road connection route can be undone",
	)
	var confirmed_road_connection := Networks.apply(
		city,
		6,
		0,
		Vector2i(124, 40),
		Vector2i(127, 40),
		Networks.BRIDGE_UNSELECTED,
		Networks.CONNECTION_CONFIRMED
	)
	_check(
		confirmed_road_connection.ok
		and confirmed_road_connection.connection_built
		and confirmed_road_connection.cost == 1040
		and confirmed_road_connection.connection_cost == 1000
		and city.funds() == 8960
		and city.text_overlay_id(127, 40) == 0xfa
		and city.building_id(127, 40) == 0x1e,
		"A confirmed road connection stores XTXT 0xFA and faces out of the map",
	)
	_check(
		Networks.undo(city, confirmed_road_connection).ok
		and city.funds() == 10000
		and city.text_overlay_id(127, 40) == 0,
		"Road connection undo restores the route, label, and funds",
	)

	var rail_connection_request := Networks.apply(
		city, 7, 0, Vector2i(3, 42), Vector2i(0, 42)
	)
	_check(
		not rail_connection_request.ok
		and rail_connection_request.connection_selection_required
		and rail_connection_request.connection_anchor == Vector2i(0, 42)
		and rail_connection_request.connection_cost == 1500
		and rail_connection_request.dry_cost == 100,
		"A rail route requests the recovered 1,500-dollar neighbor connection",
	)
	var confirmed_rail_connection := Networks.apply(
		city,
		7,
		0,
		Vector2i(3, 42),
		Vector2i(0, 42),
		Networks.BRIDGE_UNSELECTED,
		Networks.CONNECTION_CONFIRMED
	)
	_check(
		confirmed_rail_connection.ok
		and confirmed_rail_connection.cost == 1600
		and city.funds() == 8400
		and city.text_overlay_id(0, 42) == 0xfa
		and city.building_id(0, 42) == 0x2d,
		"A confirmed rail connection stores its label and outward rail shape",
	)
	_check(
		Networks.undo(city, confirmed_rail_connection).ok and city.funds() == 10000,
		"Rail connection can be undone",
	)

	var tangent_edge_route := Networks.apply(
		city, 6, 0, Vector2i(20, 0), Vector2i(24, 0)
	)
	_check(
		tangent_edge_route.ok
		and not tangent_edge_route.connection_selection_required
		and tangent_edge_route.cost == 50
		and city.text_overlay_id(24, 0) == 0,
		"A multi-tile route tangent to the edge does not request a connection",
	)
	_check(Networks.undo(city, tangent_edge_route).ok, "Tangent edge route can be undone")

	var corner_connection_request := Networks.apply(
		city, 6, 0, Vector2i(0, 0), Vector2i(0, 0)
	)
	_check(
		not corner_connection_request.ok
		and corner_connection_request.connection_selection_required,
		"A single click at a corner requests a road connection",
	)
	var corner_connection := Networks.apply(
		city,
		6,
		0,
		Vector2i(0, 0),
		Vector2i(0, 0),
		Networks.BRIDGE_UNSELECTED,
		Networks.CONNECTION_CONFIRMED
	)
	_check(
		corner_connection.ok
		and city.text_overlay_id(0, 0) == 0xfa
		and city.building_id(0, 0) == 0x26,
		"A corner marker adds both recovered outside-map connection directions",
	)
	_check(Networks.undo(city, corner_connection).ok, "Corner road connection can be undone")

	_check(city.set_funds(1039), "Road connection fixture limits funds below its exact total")
	var unaffordable_road_connection := Networks.apply(
		city, 6, 0, Vector2i(124, 44), Vector2i(127, 44)
	)
	_check(
		unaffordable_road_connection.ok
		and not unaffordable_road_connection.connection_error.is_empty()
		and unaffordable_road_connection.cost == 40
		and city.funds() == 999
		and city.text_overlay_id(127, 44) == 0,
		"Funds below the connection total build only the charged road route",
	)
	_check(
		Networks.undo(city, unaffordable_road_connection).ok,
		"Unaffordable road connection route can be undone",
	)
	_check(city.set_funds(10000), "Road connection fixture restores funds")

	_check(city.set_building_id(20, 20, Tiles.ROAD_STRAIGHT_1), "Rail crossover fixture places a road")
	var rail_crossing := Networks.apply(city, 7, 0, Vector2i(20, 20), Vector2i(21, 20))
	_check(rail_crossing.ok and city.building_id(20, 20) == 0x45, "Rail tool creates the recovered road crossover")
	_check(Networks.undo(city, rail_crossing).ok, "Rail crossover can be undone")

	_check(city.set_terrain_id(30, 30, 1), "Road-grade fixture installs a north-south slope")
	var graded_road := Networks.apply(city, 6, 0, Vector2i(30, 30), Vector2i(30, 30))
	_check(
		graded_road.ok
		and graded_road.cost == 10
		and graded_road.graded_tiles == 0
		and city.building_id(30, 30) == 0x1f,
		"Road tool uses the recovered graded sprite on a simple slope",
	)
	_check(Networks.undo(city, graded_road).ok, "Graded road can be undone")
	_check(city.set_terrain_id(30, 30, 0), "Road-grade fixture restores flat terrain")
	_check(city.set_terrain_id(31, 30, 9), "Road-grade fixture installs a compound slope")
	var reshaped_road := Networks.apply(city, 6, 0, Vector2i(31, 30), Vector2i(32, 30))
	_check(
		reshaped_road.ok
		and reshaped_road.cost == 45
		and reshaped_road.graded_tiles == 1
		and city.terrain_id(31, 30) == 1
		and city.building_id(31, 30) == 0x1f,
		"Road tool grades a compound slope and charges the recovered extra cost",
	)
	_check(Networks.undo(city, reshaped_road).ok, "Reshaped road can be undone")

	var crossing_road := Networks.apply(city, 6, 0, Vector2i(60, 60), Vector2i(64, 60))
	_check(crossing_road.ok, "Power-crossing fixture builds a straight road")
	var road_power := Networks.apply(city, 3, 0, Vector2i(62, 58), Vector2i(62, 62))
	_check(
		road_power.ok
		and road_power.points.size() == 5
		and city.building_id(62, 60) == 0x44,
		"Power line crosses a perpendicular road",
	)
	_check(Networks.undo(city, road_power).ok, "Road power crossing can be undone")
	_check(Networks.undo(city, crossing_road).ok, "Power-crossing road can be undone")
	_check(city.set_building_id(65, 65, Tiles.ROAD_STRAIGHT_1), "Single power-crossing fixture places a road")
	var single_road_power := Networks.apply(city, 3, 0, Vector2i(65, 65), Vector2i(65, 65))
	_check(
		single_road_power.ok and city.building_id(65, 65) == 0x43,
		"A single click makes the perpendicular power and road crossing",
	)
	_check(Networks.undo(city, single_road_power).ok, "Single road power crossing can be undone")

	var crossing_rail := Networks.apply(city, 7, 0, Vector2i(70, 70), Vector2i(74, 70))
	_check(crossing_rail.ok, "Power-crossing fixture builds straight rail")
	var rail_power := Networks.apply(city, 3, 0, Vector2i(72, 68), Vector2i(72, 72))
	_check(
		rail_power.ok
		and rail_power.points.size() == 5
		and city.building_id(72, 70) == 0x48,
		"Power line crosses a perpendicular rail",
	)
	_check(Networks.undo(city, rail_power).ok, "Rail power crossing can be undone")
	_check(Networks.undo(city, crossing_rail).ok, "Power-crossing rail can be undone")
	_check(city.set_building_id(75, 75, Tiles.RAIL_STRAIGHT_1), "Single power-crossing fixture places rail")
	var single_rail_power := Networks.apply(city, 3, 0, Vector2i(75, 75), Vector2i(75, 75))
	_check(
		single_rail_power.ok and city.building_id(75, 75) == 0x47,
		"A single click makes the perpendicular power and rail crossing",
	)
	_check(Networks.undo(city, single_rail_power).ok, "Single rail power crossing can be undone")

	var pipes := Networks.apply(city, 4, 0, Vector2i(10, 30), Vector2i(12, 30))
	_check(pipes.ok and pipes.cost == 9, "Pipe drag charges three dollars per tile")

	for x in range(10, 13):
		_check(city.underground_id(x, 30) == 0x11, "Pipe drag stores connected pipe shapes")
		_check(city.is_piped(x, 30), "Pipe drag sets the piped flag")

	var pipes_before: PackedByteArray = document.serialize().data
	var pipe_extension := Networks.apply(city, 4, 0, Vector2i(11, 30), Vector2i(11, 33))
	_check(pipe_extension.ok and pipe_extension.cost == 9 and not pipe_extension.stopped_early,
		"Pipes can start on an existing pipe without charging it again")
	_check(Networks.undo(city, pipe_extension).ok and document.serialize().data == pipes_before,
		"Pipe extension Undo preserves exact bytes")
	var parallel_subway := Networks.apply(city, 7, 1, Vector2i(10, 30), Vector2i(12, 30))
	_check(not parallel_subway.ok and document.serialize().data == pipes_before,
		"Subway rejects parallel pipe tiles without changing the city")
	var subway_over_pipe := Networks.apply(city, 7, 1, Vector2i(11, 29), Vector2i(11, 31))
	_check(subway_over_pipe.ok and subway_over_pipe.cost == 300 and not subway_over_pipe.stopped_early,
		"Subway can cross straight pipe tiles")
	_check(city.is_piped(11, 30) and city.underground_id(11, 30) == 0x1f,
		"Subway crossing keeps the dual-network cell and piped flag")

	_check(Networks.undo(city, subway_over_pipe).ok and document.serialize().data == pipes_before,
		"Subway under pipes has exact Undo")
	_check(Networks.undo(city, pipes).ok, "Pipe drag can be undone")

	var subway := Networks.apply(city, 7, 1, Vector2i(30, 30), Vector2i(30, 32))
	_check(subway.ok and subway.cost == 300, "Subway drag charges one hundred dollars per tile")

	for y in range(30, 33):
		_check(city.underground_id(30, y) == 0x01, "Subway drag stores connected subway shapes")

	_check(document.misc_u32(0x0fe8) == 3, "Subway drag increments the saved subway count")
	_check(Networks.undo(city, subway).ok, "Subway drag can be undone")
	_check(document.misc_u32(0x0fe8) == 0, "Subway undo restores the saved subway count")

	_check(city.set_building_id(42, 40, Tiles.SUSPENSION_BRIDGE_1), "Partial-route fixture places an obstruction")
	var partial := Networks.apply(city, 6, 0, Vector2i(40, 40), Vector2i(44, 40))
	_check(partial.ok and partial.stopped_early, "Road route stops at an obstruction")
	_check(partial.points == [Vector2i(40, 40), Vector2i(41, 40)], "Road route keeps the clear prefix")
	_check(partial.cost == 20, "Partial road route charges only its planned prefix")
	_check(Networks.undo(city, partial).ok, "Partial road route can be undone")

	for x in range(80, 89):
		_check(city.set_land_altitude(x, 20, 4), "Bridge fixture sets land altitude")
		_check(city.set_water_altitude(x, 20, 5), "Bridge fixture sets water altitude")
		_check(city.set_tile_flag(x, 20, 0x04, x < 88), "Bridge fixture sets surface water")
		_check(
			city.set_terrain_id(x, 20, 0x21 if x == 80 else (0x10 if x < 88 else 0)),
			"Bridge fixture sets shoreline and water terrain",
		)

	var bridge_request := Networks.apply(
		city, 6, 0, Vector2i(80, 20), Vector2i(88, 20)
	)
	_check(
		not bridge_request.ok
		and bridge_request.bridge_selection_required
		and bridge_request.bridge_span_length == 8
		and bridge_request.bridge_choices.size() == 3
		and bridge_request.bridge_choices[0].type == Networks.BRIDGE_ROAD_CAUSEWAY
		and bridge_request.bridge_choices[1].type == Networks.BRIDGE_ROAD_RAISING
		and bridge_request.bridge_choices[2].type == Networks.BRIDGE_ROAD_SUSPENSION,
		"Road bridge request offers all recovered choices for an eight-tile span",
	)
	_check(
		NetworkBridges.bridge_choices(4, Networks.MODE_ROAD).size() == 1
		and NetworkBridges.bridge_choices(5, Networks.MODE_ROAD).size() == 2
		and NetworkBridges.bridge_choices(7, Networks.MODE_ROAD).size() == 3
		and NetworkBridges.bridge_choices(12, Networks.MODE_ROAD).size() == 2,
		"Road bridge choices use the recovered length limits",
	)
	var direct_bridge_cancel := Networks.apply(
		city,
		6,
		0,
		Vector2i(80, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_CANCELLED
	)
	_check(
		not direct_bridge_cancel.ok
		and direct_bridge_cancel.cancelled
		and city.funds() == 10000
		and city.building_id(80, 20) == 0,
		"Canceling a direct bridge does not change the city",
	)
	var prefix_bridge_cancel := Networks.apply(
		city,
		6,
		0,
		Vector2i(75, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_CANCELLED
	)
	_check(
		prefix_bridge_cancel.ok
		and prefix_bridge_cancel.bridge_cancelled
		and prefix_bridge_cancel.dry_points.size() == 5
		and prefix_bridge_cancel.cost == 50
		and city.funds() == 9950
		and city.building_id(79, 20) != 0
		and city.building_id(80, 20) == 0,
		"Canceling a bridge keeps and charges its dry route prefix",
	)
	_check(
		Networks.undo(city, prefix_bridge_cancel).ok and city.funds() == 10000,
		"Canceled bridge prefix can be undone",
	)
	var causeway := Networks.apply(
		city,
		6,
		0,
		Vector2i(80, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_ROAD_CAUSEWAY
	)
	_check(
		causeway.ok
		and causeway.bridge_built
		and causeway.bridge_span_length == 8
		and causeway.bridge_points.size() == 8
		and causeway.bridge_cost == 200
		and causeway.cost == 210
		and city.funds() == 9790
		and city.building_id(88, 20) != 0,
		"Causeway keeps its recovered span cost and continues to the dry endpoint",
	)
	_check(
		city.terrain_id(80, 20) == 3
		and city.terrain_id(87, 20) == 1
		and city.land_altitude(80, 20) == 5
		and city.land_altitude(87, 20) == 5
		and not city.is_water(80, 20)
		and not city.is_water(87, 20),
		"Causeway raises and reshapes both recovered bank tiles",
	)

	for x in range(81, 87):
		_check(
			city.building_id(x, 20) == 0x57
			and city.is_water(x, 20)
			and (city.tile_flags[x * 128 + 20] & 0x02) != 0,
			"Causeway stores horizontal span tiles with the recovered mirror flag",
		)

	_check(Networks.undo(city, causeway).ok, "Causeway placement can be undone")
	_check(
		city.funds() == 10000
		and city.terrain_id(80, 20) == 0x21
		and city.land_altitude(80, 20) == 4
		and city.is_water(80, 20),
		"Causeway undo restores funds, terrain, altitude, and water",
	)

	var raising_bridge := Networks.apply(
		city,
		6,
		0,
		Vector2i(80, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_ROAD_RAISING
	)
	_check(
		raising_bridge.ok
		and raising_bridge.bridge_cost == 400
		and [
			city.building_id(81, 20), city.building_id(82, 20),
			city.building_id(83, 20), city.building_id(84, 20),
			city.building_id(85, 20), city.building_id(86, 20),
		] == [0x57, 0x56, 0x58, 0x58, 0x56, 0x57],
		"Raising bridge writes the recovered tower and raised-deck pattern",
	)
	_check(Networks.undo(city, raising_bridge).ok, "Raising bridge placement can be undone")

	var suspension_bridge := Networks.apply(
		city,
		6,
		0,
		Vector2i(80, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_ROAD_SUSPENSION
	)
	_check(
		suspension_bridge.ok
		and suspension_bridge.bridge_cost == 600
		and [
			city.building_id(81, 20), city.building_id(82, 20),
			city.building_id(83, 20), city.building_id(84, 20),
			city.building_id(85, 20), city.building_id(86, 20),
		] == [0x55, 0x54, 0x53, 0x52, 0x51, 0x57],
		"Suspension bridge writes the recovered five-piece pattern",
	)
	_check(Networks.undo(city, suspension_bridge).ok, "Suspension bridge placement can be undone")

	var rail_bridge := Networks.apply(
		city, 7, 0, Vector2i(80, 20), Vector2i(88, 20)
	)
	_check(
		rail_bridge.ok
		and rail_bridge.bridge_type == Networks.BRIDGE_RAIL
		and rail_bridge.bridge_cost == 600
		and [
			city.building_id(81, 20), city.building_id(82, 20),
			city.building_id(83, 20), city.building_id(84, 20),
			city.building_id(85, 20), city.building_id(86, 20),
		] == [0x5a, 0x5b, 0x5b, 0x5a, 0x5b, 0x5b],
		"Rail bridge uses the recovered price and pylon pattern",
	)
	_check(Networks.undo(city, rail_bridge).ok, "Rail bridge placement can be undone")

	var wire_bridge := Networks.apply(
		city, 3, 0, Vector2i(80, 20), Vector2i(88, 20)
	)
	_check(
		wire_bridge.ok
		and wire_bridge.bridge_type == Networks.BRIDGE_WIRE
		and wire_bridge.bridge_cost == 80,
		"Raised wires use the recovered ten-dollar span price",
	)

	for x in range(81, 87):
		_check(
			city.building_id(x, 20) == 0x5c and city.is_powerable(x, 20),
			"Raised wires store powered bridge tiles",
		)

	_check(Networks.undo(city, wire_bridge).ok, "Raised-wire placement can be undone")

	_check(city.set_funds(100), "Bridge funds fixture limits available funds")
	var bridge_after_road := Networks.apply(
		city,
		6,
		0,
		Vector2i(75, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_ROAD_CAUSEWAY
	)
	_check(
		bridge_after_road.ok
		and not bridge_after_road.bridge_built
		and not bridge_after_road.bridge_error.is_empty()
		and bridge_after_road.dry_points.size() == 5
		and bridge_after_road.cost == 50
		and city.funds() == 50,
		"An unaffordable bridge keeps and charges the recovered dry route prefix",
	)
	_check(Networks.undo(city, bridge_after_road).ok, "Unaffordable bridge prefix can be undone")
	_check(city.set_funds(10000), "Network fixture restores funds after bridge checks")

	_check(city.set_funds(1), "Network funds fixture sets insufficient funds")
	var unaffordable := Networks.apply(city, 3, 0, Vector2i(50, 50), Vector2i(51, 50))
	_check(not unaffordable.ok and not unaffordable.error.is_empty(), "Network command reports insufficient funds")
