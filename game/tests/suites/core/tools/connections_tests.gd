extends "res://tests/support/core_test_suite.gd"

## Tools: connections checks.

@warning_ignore_start("integer_division")

const Random = preload("res://src/simulation/random/sim_random.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const Hydro = preload("res://src/tools/city/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/city/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/city/onramp_command.gd")
const Tunnels = preload("res://src/tools/city/tunnel_command.gd")


func test_hydro_command(reference_root: String) -> void:
	_check(Hydro.supports_tool(3, 3), "Hydroelectric command supports the hydro tool")
	_check(not Hydro.supports_tool(3, 2), "Hydroelectric command rejects coal power")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XZON", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Hydroelectric fixture clears %s" % chunk_id,
		)

	_check(document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Hydroelectric fixture clears XLAB")
	_check(document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Hydroelectric fixture clears XMIC")
	_check(document.set_misc_i32(0x14, 1000), "Hydroelectric fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Hydroelectric fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0xc7 * 4, 0), "Hydroelectric fixture clears hydro count")
	_check(
		document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, 49999),
		"Hydroelectric fixture sets population below the utility threshold",
	)
	var city := CityModel.from_document(document)
	_check(city.set_terrain_id(20, 20, 0x2e), "Hydroelectric fixture places a waterfall")
	_check(city.set_land_altitude(20, 20, 5), "Hydroelectric fixture sets waterfall altitude")
	_check(city.set_land_altitude(20, 19, 6), "Hydroelectric fixture sets a higher north tile")
	var process_random := Random.new(33)
	var command := Hydro.apply(city, 3, 3, Vector2i(20, 20), process_random)
	_check(command.ok, "Hydroelectric placement succeeds: %s" % command.error)
	_check(command.tile_id == 0xc7 and city.building_id(20, 20) == 0xc7, "Hydroelectric tile follows the recovered slope orientation")
	_check(
		city.funds() == 600
		and city.is_powerable(20, 20)
		and city.is_powered(20, 20)
		and command.immediate_power_refresh
		and command.power_usage_percent == 0,
		"Low-population hydroelectric placement charges cost and refreshes power",
	)
	_check(city.zones[20 * 128 + 20] == 0xf0, "Hydroelectric placement sets all corner bits")
	_check(command.overlay_id == 56 and not city.label(56).is_empty(), "Hydroelectric placement uses fixed XMIC record five")
	_check(city.microsim(5).stat_1 == 1 and city.microsim(5).stat_2 == 20, "Hydroelectric placement increments fixed XMIC totals")
	_check(Hydro.undo(city, command, process_random).ok, "Hydroelectric placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.funds() == 1000, "Hydroelectric undo restores the tile and funds")
	for population in [49_999, 50_000, 49_999_999, 50_000_000]:
		var expect_refresh: bool = population < 50_000_000

		_check(
			document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, population),
			"Hydroelectric fixture sets the strict utility threshold",
		)
		var threshold_command := Hydro.apply(
			city, 3, 3, Vector2i(20, 20), process_random
		)
		_check(
			threshold_command.ok
			and threshold_command.immediate_power_refresh == expect_refresh
			and (threshold_command.power_usage_percent >= 0) == expect_refresh
			and city.is_powerable(20, 20)
			and city.is_powered(20, 20) == expect_refresh,
			"Hydroelectric power refresh at population %d" % population,
		)
		_check(
			Hydro.undo(city, threshold_command, process_random).ok,
			"Threshold hydroelectric placement can be undone",
		)
	var wrong_terrain := Hydro.apply(city, 3, 3, Vector2i(21, 21), process_random)
	_check(not wrong_terrain.ok and not wrong_terrain.error.is_empty(), "Hydroelectric placement requires waterfall terrain")


func test_subway_to_rail_command(reference_root: String) -> void:
	_check(SubwayToRail.supports_tool(7, 4), "Subway-to-rail command supports its catalog tool")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Subway-to-rail fixture clears %s" % chunk_id,
		)

	_check(document.set_misc_i32(0x14, 0), "Subway-to-rail fixture clears funds")
	_check(document.set_misc_u32(0x01f0, 16383), "Subway-to-rail fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0x2c * 4, 1), "Subway-to-rail fixture counts rail")
	_check(document.set_misc_u32(0x0fe8, 0), "Subway-to-rail fixture clears subway count")
	var city := CityModel.from_document(document)
	_check(city.set_building_id(21, 20, Tiles.RAIL_STRAIGHT_1), "Subway-to-rail fixture places adjacent rail")
	_check(city.set_zone_id(20, 20, 3), "Subway-to-rail fixture places a commercial zone")
	var surface := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(surface.ok, "Subway-to-rail placement beside surface rail succeeds: %s" % surface.error)
	_check(surface.tile_id == 0x6c and city.building_id(20, 20) == 0x6c, "East rail selects connector orientation zero")
	_check(city.underground_id(20, 20) == 0x23, "Subway-to-rail placement writes underground entrance 0x23")
	_check(document.misc_u32(0x0fe8) == 1, "Subway-to-rail increments the saved subway count")
	_check(city.zones[20 * 128 + 20] == 0xf3, "Subway-to-rail placement preserves the zone and sets all corners")
	_check(city.funds() == 0 and surface.cost == 0 and surface.listed_cost == 250, "Subway-to-rail reproduces the executable's missing cost deduction")
	_check(SubwayToRail.undo(city, surface).ok, "Subway-to-rail placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.underground_id(20, 20) == 0, "Subway-to-rail undo restores surface and underground maps")
	_check(document.misc_u32(0x0fe8) == 0, "Subway-to-rail undo restores the saved subway count")

	_check(city.set_building_id(21, 20, Tiles.EMPTY), "Underground connection fixture removes surface rail")
	_check(city.set_underground_id(21, 20, UnderTiles.SUBWAY_LR), "Underground connection fixture places adjacent subway")
	var underground := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(underground.ok and underground.tile_id == 0x6e, "East subway selects the opposite connector orientation")
	_check(SubwayToRail.undo(city, underground).ok, "Underground-oriented connector can be undone")
	_check(city.set_underground_id(21, 20, UnderTiles.EMPTY), "Missing-neighbor fixture removes adjacent subway")
	var no_neighbor := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(not no_neighbor.ok and not no_neighbor.error.is_empty(), "Subway-to-rail placement requires an adjacent network")


func test_onramp_command(reference_root: String) -> void:
	_check(Onramps.supports_tool(6, 3), "On-ramp command supports its catalog tool")
	_check(not Onramps.supports_tool(6, 1), "On-ramp command rejects the highway tool")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"On-ramp fixture clears %s" % chunk_id,
		)

	_check(document.set_misc_i32(0x14, 100), "On-ramp fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16382), "On-ramp fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0x49 * 4, 1), "On-ramp fixture counts highway")
	_check(document.set_misc_u32(0x01f0 + 0x1d * 4, 1), "On-ramp fixture counts road")
	var city := CityModel.from_document(document)
	_check(city.set_building_id(21, 20, Tiles.HIGHWAY_STRAIGHT_1), "On-ramp fixture places east highway")
	_check(city.set_building_id(20, 19, Tiles.ROAD_STRAIGHT_1), "On-ramp fixture places north road")
	var north := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(north.ok, "North-road on-ramp succeeds: %s" % north.error)
	_check(north.tile_id == 0x5f and city.building_id(20, 20) == 0x5f, "East highway and north road select ramp 0x5f")
	_check(city.building_id(20, 19) == 0x2b, "On-ramp converts its adjacent road to tile 0x2b")
	_check((city.tile_flags[20 * 128 + 20] & 0x02) != 0, "North-road on-ramp sets the flipped flag")
	_check(city.funds() == 75 and north.cost == 25, "On-ramp charges the catalog cost")
	_check(Onramps.undo(city, north).ok, "On-ramp placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.building_id(20, 19) == 0x1d, "On-ramp undo restores both surface tiles")
	_check(city.funds() == 100, "On-ramp undo restores funds")

	_check(city.set_building_id(21, 20, Tiles.EMPTY), "Second on-ramp fixture removes east highway")
	_check(city.set_building_id(20, 19, Tiles.EMPTY), "Second on-ramp fixture removes north road")
	_check(city.set_building_id(20, 19, Tiles.HIGHWAY_STRAIGHT_1), "Second on-ramp fixture places north highway")
	_check(city.set_building_id(21, 20, Tiles.ROAD_STRAIGHT_1), "Second on-ramp fixture places east road")
	var east := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(east.ok and east.tile_id == 0x5d, "North highway and east road select ramp 0x5d")
	_check(Onramps.undo(city, east).ok, "East-road on-ramp can be undone")
	_check(city.set_building_id(20, 19, Tiles.EMPTY), "Invalid arrangement fixture removes north highway")
	_check(city.set_building_id(21, 20, Tiles.EMPTY), "Invalid arrangement fixture removes east road")
	_check(city.set_building_id(21, 20, Tiles.HIGHWAY_STRAIGHT_1), "Invalid arrangement fixture places east highway")
	_check(city.set_building_id(19, 20, Tiles.ROAD_STRAIGHT_1), "Invalid arrangement fixture places west road")
	var parallel := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(not parallel.ok and not parallel.error.is_empty(), "On-ramp rejects a road parallel to the highway")
	_check(city.set_funds(24), "On-ramp funds fixture sets insufficient funds")
	_check(city.set_building_id(19, 20, Tiles.EMPTY), "On-ramp funds fixture removes west road")
	_check(city.set_building_id(20, 19, Tiles.ROAD_STRAIGHT_1), "On-ramp funds fixture places north road")
	var unaffordable := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(not unaffordable.ok and not unaffordable.error.is_empty(), "On-ramp command reports insufficient funds")
	_check(city.set_funds(0), "SCURK on-ramp fixture clears funds")
	var free_onramp := Onramps.apply(
		city, 6, 3, Vector2i(20, 20), true
	)
	_check(
		free_onramp.ok
		and free_onramp.cost == 0
		and free_onramp.listed_cost == 25
		and city.funds() == 0,
		"SCURK builds an on-ramp without changing city funds",
	)
	_check(
		Onramps.undo(city, free_onramp).ok and city.funds() == 0,
		"SCURK free on-ramp Undo preserves city funds",
	)


func test_tunnel_command(reference_root: String) -> void:
	_check(Tunnels.supports_tool(6, 2), "Tunnel command supports its catalog tool")
	_check(not Tunnels.supports_tool(6, 1), "Tunnel command rejects the highway tool")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Tunnel fixture clears %s" % chunk_id,
		)

	_check(document.set_misc_i32(0x14, 1000), "Tunnel fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16383), "Tunnel fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0x1d * 4, 1), "Tunnel fixture counts road")
	var city := CityModel.from_document(document)
	_check(city.set_terrain_id(20, 20, 3), "Tunnel fixture places an east-facing slope")
	_check(city.set_land_altitude(20, 20, 5), "Tunnel fixture sets start altitude")
	_check(city.set_land_altitude(21, 20, 6), "Tunnel fixture raises the hill interior")
	_check(city.set_terrain_id(22, 20, 1), "Tunnel fixture places the opposite slope")
	_check(city.set_land_altitude(22, 20, 5), "Tunnel fixture sets finish altitude")
	_check(city.set_building_id(19, 20, Tiles.ROAD_STRAIGHT_1), "Tunnel fixture places an adjacent road")
	var planned := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(
		planned.confirmation_required
		and planned.finish == Vector2i(22, 20)
		and planned.points.size() == 3
		and planned.cost == 450,
		"Tunnel validates its path and cost before confirmation",
	)
	_check(
		city.building_id(20, 20) == 0
		and city.tunnel_levels(21, 20) == 0
		and city.funds() == 1000,
		"Tunnel confirmation request does not change the city",
	)
	var canceled := Tunnels.apply(
		city, 6, 2, Vector2i(20, 20), Tunnels.CONFIRMATION_CANCELLED
	)
	_check(
		canceled.cancelled
		and city.building_id(20, 20) == 0
		and city.tunnel_levels(21, 20) == 0
		and city.funds() == 1000,
		"Tunnel cancel does not change the city",
	)
	var invalid_choice := Tunnels.apply(city, 6, 2, Vector2i(20, 20), 2)
	_check(
		not invalid_choice.ok and not invalid_choice.error.is_empty(),
		"Tunnel rejects an unknown confirmation choice",
	)
	var command := Tunnels.apply(
		city, 6, 2, Vector2i(20, 20), Tunnels.CONFIRMATION_CONFIRMED
	)
	_check(command.ok, "East-facing tunnel succeeds: %s" % command.error)
	_check(command.finish == Vector2i(22, 20) and command.points.size() == 3, "Tunnel finds the first tile at the start altitude")
	_check(city.building_id(20, 20) == 0x41 and city.building_id(22, 20) == 0x3f, "Tunnel writes paired east and west entrances")
	_check(city.tunnel_levels(20, 20) == 1 and city.tunnel_levels(21, 20) == 2 and city.tunnel_levels(22, 20) == 1, "Tunnel writes recovered ALTM depths")
	_check(city.building_id(19, 20) == 0x1e, "Tunnel reconnects an adjacent road")
	_check(command.cost == 450 and city.funds() == 550, "Tunnel charges each traversed tile")
	_check(Tunnels.undo(city, command).ok, "Tunnel placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.building_id(22, 20) == 0, "Tunnel undo restores both entrances")
	_check(city.tunnel_levels(21, 20) == 0 and city.funds() == 1000, "Tunnel undo restores ALTM and funds")

	_check(city.set_tunnel_levels(21, 20, 1), "Tunnel conflict fixture places an existing tunnel")
	var conflict := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not conflict.ok and not conflict.error.is_empty(), "Tunnel rejects an existing ALTM tunnel path")
	_check(city.set_tunnel_levels(21, 20, 0), "Tunnel conflict fixture removes existing tunnel")
	_check(city.set_underground_id(21, 20, UnderTiles.PIPE_LR), "Tunnel conflict fixture places a pipe at depth two")
	var pipe_conflict := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not pipe_conflict.ok and not pipe_conflict.error.is_empty(), "Tunnel rejects a pipe at the matching depth")
	_check(city.set_underground_id(21, 20, UnderTiles.EMPTY), "Tunnel conflict fixture removes pipe")
	_check(city.set_terrain_id(22, 20, 2), "Tunnel exit fixture changes the opposite slope")
	var no_exit := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not no_exit.ok and not no_exit.error.is_empty(), "Tunnel requires the recovered opposite exit slope")
	_check(city.set_terrain_id(22, 20, 1), "Tunnel funds fixture restores the exit slope")
	_check(city.set_funds(449), "Tunnel funds fixture sets insufficient funds")
	var unaffordable_plan := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(
		unaffordable_plan.confirmation_required
		and unaffordable_plan.cost == 450,
		"Tunnel asks for confirmation before it checks funds",
	)
	var unaffordable := Tunnels.apply(
		city, 6, 2, Vector2i(20, 20), Tunnels.CONFIRMATION_CONFIRMED
	)
	_check(not unaffordable.ok and not unaffordable.error.is_empty(), "Tunnel command reports insufficient funds")
	_check(city.set_funds(0), "SCURK tunnel fixture clears funds")
	var free_tunnel := Tunnels.apply(
		city,
		6,
		2,
		Vector2i(20, 20),
		Tunnels.CONFIRMATION_CONFIRMED,
		true
	)
	_check(
		free_tunnel.ok
		and free_tunnel.cost == 0
		and free_tunnel.listed_cost == 450
		and city.funds() == 0,
		"SCURK builds a tunnel without changing city funds",
	)
	_check(
		Tunnels.undo(city, free_tunnel).ok and city.funds() == 0,
		"SCURK free tunnel Undo preserves city funds",
	)
