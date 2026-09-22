extends "res://tests/support/core_test_suite.gd"

## Tools: buildings checks.

@warning_ignore_start("integer_division")

const Random = preload("res://src/simulation/random/sim_random.gd")
const LfsrRandom = preload("res://src/simulation/random/sim_lfsr_random.gd")
const Water = preload("res://src/simulation/infrastructure/water_phase.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const Landscapes = preload("res://src/tools/landscape/landscape_command.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")


func test_landscape_command(reference_root: String) -> void:
	var tree_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XTXT", "XBIT"]:
		_check(
			tree_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Tree fixture clears %s" % chunk_id,
		)

	_check(tree_document.set_misc_i32(0x14, 100), "Tree fixture sets funds")
	_check(tree_document.set_misc_u32(0x01f0, 16384), "Tree fixture counts clear tiles")

	for tree_id in range(6, 13):
		_check(tree_document.set_misc_u32(0x01f0 + tree_id * 4, 0), "Tree fixture clears tree count")

	var tree_city := CityModel.from_document(tree_document)
	var tree_random := Random.new(1)
	var first_tree := Landscapes.apply_path(
		tree_city, 1, 0, [Vector2i(10, 10)], tree_random
	)
	_check(first_tree.ok, "Tree tool places a tree: %s" % first_tree.error)
	_check(tree_city.building_id(10, 10) == 7, "Tree tool uses the executable random first tree ID")
	_check(tree_city.funds() == 97, "Tree tool charges three dollars")
	_check(tree_document.misc_u32(0x01f0) == 16383, "Tree tool decrements the old tile count")
	_check(tree_document.misc_u32(0x01f0 + 7 * 4) == 1, "Tree tool increments the new tile count")
	var denser_tree := Landscapes.apply_path(
		tree_city, 1, 0, [Vector2i(10, 10)], tree_random
	)
	_check(denser_tree.ok and tree_city.building_id(10, 10) == 8, "Tree tool advances an existing tree")
	_check(Landscapes.undo(tree_city, denser_tree, tree_random).ok, "Later tree action can be undone")
	_check(tree_city.building_id(10, 10) == 7 and tree_city.funds() == 97, "Tree undo restores map and funds")
	_check(Landscapes.undo(tree_city, first_tree, tree_random).ok, "First tree action can be undone")
	_check(tree_city.building_id(10, 10) == 0 and tree_random.state == 1, "Tree undo restores tile and random state")
	_check(tree_city.funds() == 100, "Tree undo restores original funds")
	_check(tree_city.set_tile_flag(11, 11, 0x04, true), "Tree rejection fixture marks water")
	var rejected_tree := Landscapes.apply_path(
		tree_city, 1, 0, [Vector2i(11, 11)], tree_random
	)
	_check(not rejected_tree.ok, "Tree tool rejects water")

	var water_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XTXT", "XBIT"]:
		_check(
			water_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Water fixture clears %s" % chunk_id,
		)

	_check(water_document.set_misc_i32(0x14, 500), "Water fixture sets funds")
	_check(water_document.set_misc_u32(0x01f0, 16383), "Water fixture counts clear tiles")
	_check(water_document.set_misc_u32(0x01f0 + 6 * 4, 1), "Water fixture counts one tree")
	var water_city := CityModel.from_document(water_document)
	_check(water_city.set_building_id(10, 10, Tiles.TREES_1), "Water fixture places a tree")
	_check(water_city.set_zone_id(10, 10, 1), "Water fixture places a zone")
	_check(water_city.set_building_corners(10, 10, 0xa0), "Water fixture sets corner bits")
	_check(water_city.set_land_altitude(10, 10, 5), "Water fixture sets land altitude")
	_check(water_city.set_water_altitude(10, 10, 2), "Water fixture sets old water altitude")
	_check(water_city.set_tile_flag(9, 10, 0x04, true), "Water fixture places adjacent water")
	_check(water_city.set_terrain_id(9, 10, 0x3d), "Water fixture sets adjacent water shape")
	var water_random := Random.new(123)
	var water := Landscapes.apply_path(
		water_city, 1, 1, [Vector2i(10, 10)], water_random
	)
	_check(water.ok, "Water tool places water: %s" % water.error)
	_check(water_city.funds() == 400 and water.cost == 100, "Water tool charges one hundred dollars")
	_check(water_city.is_water(10, 10) and water_city.building_id(10, 10) == 0, "Water tool clears the building and sets XBIT water")
	_check(water_city.zone_id(10, 10) == 0 and water_city.building_corners(10, 10) == 0xa0, "Water tool clears only the zone nibble")
	_check(water_city.water_altitude(10, 10) == 5, "Water tool copies land altitude to water altitude")
	_check(water_city.terrain_id(10, 10) == 0x44, "Water tool selects the west-connected surface shape")
	_check(water_city.terrain_id(9, 10) == 0x42, "Water tool retiles adjacent water")
	_check(water_document.misc_u32(0x01f0 + 6 * 4) == 0, "Water tool decrements the cleared tree count")
	_check(water_document.misc_u32(0x01f0) == 16384, "Water tool increments the clear building count")
	_check(Landscapes.undo(water_city, water, water_random).ok, "Water action can be undone")
	_check(not water_city.is_water(10, 10) and water_city.building_id(10, 10) == 6, "Water undo restores map data")
	_check(water_city.zone_id(10, 10) == 1 and water_city.building_corners(10, 10) == 0xa0, "Water undo restores XZON")
	_check(water_city.land_altitude(10, 10) == 5 and water_city.water_altitude(10, 10) == 2, "Water undo restores ALTM")
	_check(water_city.funds() == 500, "Water undo restores funds")
	_check(water_city.set_text_overlay_id(12, 12, 250), "Water rejection fixture sets protected text")
	var protected_water := Landscapes.apply_path(
		water_city, 1, 1, [Vector2i(12, 12)], water_random
	)
	_check(not protected_water.ok, "Water tool rejects XTXT values above 249")
	_check(water_city.set_funds(99), "Water funds fixture sets insufficient funds")
	var unaffordable_water := Landscapes.apply_path(
		water_city, 1, 1, [Vector2i(13, 13)], water_random
	)
	_check(not unaffordable_water.ok and not unaffordable_water.error.is_empty(), "Water tool reports insufficient funds")


func test_building_command(reference_root: String) -> void:
	_check(BuildingSites.tile_for_tool(3, 2) == 0xcf, "Building table maps coal power")
	_check(BuildingSites.tile_for_tool(14, 4) == 0xf8, "Building table maps the marina")
	_check(Buildings.supports_tool(13, 0), "Building command supports police stations")
	_check(not Buildings.supports_tool(3, 3), "Hydroelectric power remains a special tool")
	_check(BuildingSites.footprint(Vector2i(20, 20), 1) == Rect2i(20, 20, 1, 1), "One-tile footprint starts at the pointer")
	_check(BuildingSites.footprint(Vector2i(20, 20), 2) == Rect2i(20, 20, 2, 2), "Two-tile footprint starts at the pointer")
	_check(BuildingSites.footprint(Vector2i(20, 20), 4) == Rect2i(19, 19, 4, 4), "Four-tile footprint starts one tile before the pointer")

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Building fixture clears %s" % chunk_id,
		)

	_check(document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Building fixture clears XLAB")
	_check(document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Building fixture clears XMIC")
	_check(document.set_misc_i32(0x14, 20000), "Building fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Building fixture counts clear tiles")
	_check(document.set_misc_u32(0x0fe8, 0), "Building fixture clears subway count")
	_check(document.set_misc_u32(Buildings.MISC_STADIUM_TEAMS, 0), "Building fixture clears stadium teams")
	_check(document.set_misc_u32(Buildings.MISC_ARCOLOGY_POPULATION, 0), "Building fixture clears arcology population")
	_check(document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, 180000), "Building fixture sets normal population")
	_check(document.set_misc_u32(0x01f0 + 0xcf * 4, 0), "Building fixture clears coal count")
	_check(document.set_misc_u32(0x077c + 5 * 0x6c, 2), "Building fixture sets police count")
	_check(document.set_misc_u32(0x077c + 5 * 0x6c + 4, 80), "Building fixture funds police")
	_check(document.set_misc_u32(0x077c + 6 * 0x6c + 4, 80), "Building fixture funds fire")
	_check(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 0), "Building fixture clears progression")
	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0x0f), "Building fixture grants one-use rewards")

	for invention_index in ToolAvailability.INVENTION_COUNT:
		_check(
			document.set_misc_u32(
				ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
				0,
			),
			"Building fixture unlocks invention %d" % invention_index,
		)

	var city := CityModel.from_document(document)
	var random := LfsrRandom.new(1)
	var process_random := Random.new(1)

	var utility_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			utility_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Immediate utility fixture clears %s" % chunk_id,
		)

	_check(
		utility_document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)),
		"Immediate utility fixture clears XLAB",
	)
	_check(
		utility_document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)),
		"Immediate utility fixture clears XMIC",
	)
	_check(utility_document.set_misc_i32(0x14, 5000), "Immediate utility fixture sets funds")
	_check(
		utility_document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, 49999),
		"Immediate utility fixture sets population below the threshold",
	)
	_check(
		utility_document.set_misc_u32(Water.MISC_TREATMENT_SUFFICIENT, 0),
		"Immediate utility fixture clears treatment state",
	)
	var utility_city := CityModel.from_document(utility_document)
	_check(
		utility_city.set_tile_flag(10, 10, 0x40, true)
		and utility_city.set_tile_flag(10, 10, 0x10, true),
		"Immediate utility fixture stores stale utility flags",
	)
	var utility_random := LfsrRandom.new(0x2211)
	var utility_process_random := Random.new(0x3344)
	var low_population_station := Buildings.apply(
		utility_city,
		13,
		0,
		Vector2i(20, 20),
		utility_random,
		utility_process_random,
	)
	_check(
		low_population_station.ok
		and low_population_station.immediate_power_refresh
		and low_population_station.immediate_water_refresh,
		"A low-population building immediately refreshes power and water",
	)
	_check(
		not utility_city.is_powered(20, 20)
		and utility_city.is_powerable(20, 20)
		and utility_city.is_piped(20, 20),
		"Immediate power removes the new isolated building's initial powered flag",
	)
	_check(
		not utility_city.is_powered(10, 10)
		and not utility_city.is_watered(10, 10)
		and utility_document.misc_u32(Water.MISC_TREATMENT_SUFFICIENT) == 1,
		"Immediate utility phases update existing flags and saved treatment state",
	)
	_check(
		Buildings.undo(
			utility_city,
			low_population_station,
			utility_random,
			utility_process_random,
		).ok,
		"Immediate utility changes can be undone with their building",
	)
	_check(
		utility_city.is_powered(10, 10)
		and utility_city.is_watered(10, 10)
		and utility_document.misc_u32(Water.MISC_TREATMENT_SUFFICIENT) == 0,
		"Building undo restores the utility phase changes",
	)
	for population in [49_999, 50_000, 49_999_999, 50_000_000]:
		var expect_refresh: bool = population < 50_000_000

		_check(
			utility_document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, population),
			"Immediate utility fixture selects the strict threshold",
		)
		var threshold_station := Buildings.apply(
			utility_city,
			13,
			0,
			Vector2i(20, 20),
			utility_random,
			utility_process_random,
		)
		_check(
			threshold_station.ok
			and threshold_station.immediate_power_refresh == expect_refresh
			and threshold_station.immediate_water_refresh == expect_refresh
			and utility_city.is_powered(20, 20) != expect_refresh,
			"Building utility refresh at population %d" % population,
		)
		_check(
			Buildings.undo(
				utility_city,
				threshold_station,
				utility_random,
				utility_process_random,
			).ok,
			"Threshold building placement can be undone",
		)

	var coal := Buildings.apply(city, 3, 2, Vector2i(20, 20), random, process_random)
	_check(coal.ok, "Coal plant placement succeeds: %s" % coal.error)
	_check(coal.site == Rect2i(19, 19, 4, 4), "Coal plant uses the original asymmetric footprint")
	_check(coal.tile_indices.size() == 16, "Coal plant changes sixteen map tiles")
	_check(city.funds() == 16000, "Coal plant charges its tool cost once")
	_check(city.building_id(19, 19) == 0xcf and city.building_id(22, 22) == 0xcf, "Coal plant fills its footprint")
	_check(city.tile_flags[19 * 128 + 19] & 0xe0 == 0xe0, "Coal plant sets structure utility flags")
	_check(city.zones[19 * 128 + 19] == 0x10, "Rotation zero stores the bottom-left corner")
	_check(city.zones[22 * 128 + 19] == 0x20, "Rotation zero stores the bottom-right corner")
	_check(city.zones[22 * 128 + 22] == 0x40, "Rotation zero stores the top-left corner")
	_check(city.zones[19 * 128 + 22] == 0x80, "Rotation zero stores the top-right corner")
	_check(coal.overlay_id == 61 and city.text_overlay_id(19, 19) == 61, "Coal plant attaches the first dynamic microsim label")
	_check(not city.label(61).is_empty(), "Coal plant gets the original default label")
	_check(city.microsim(10).tile_id == 0xcf and city.microsim(10).stat_1 == 200, "Coal plant initializes its XMIC capacity")
	_check(document.misc_u32(0x01f0) == 16368, "Coal plant decrements clear tile count")
	_check(document.misc_u32(0x01f0 + 0xcf * 4) == 16, "Coal plant increments its tile count")
	_check(Buildings.undo(city, coal, random, process_random).ok, "Coal plant placement can be undone")
	_check(city.funds() == 20000 and city.building_id(19, 19) == 0, "Building undo restores funds and tiles")
	_check(city.text_overlay_id(19, 19) == 0 and city.microsim(10).tile_id == 0, "Building undo restores XTXT and XMIC")

	var police := Buildings.apply(city, 13, 0, Vector2i(30, 30), random, process_random)
	_check(police.ok, "Police station placement succeeds")
	_check(document.misc_u32(0x077c + 5 * 0x6c) == 3, "Police station increments the current budget count")
	_check(city.microsim(10).stat_1 == 160, "Police station starts with the funded population cap")
	_check(Buildings.undo(city, police, random, process_random).ok, "Police station placement can be undone")
	var fire := Buildings.apply(city, 13, 1, Vector2i(34, 30), random, process_random)
	_check(fire.ok, "Fire station placement succeeds")
	_check(
		city.microsim(10).stat_1 == 40 and city.microsim(10).stat_2 == 4,
		"Fire station starts with the funded population cap and four engines",
	)
	_check(Buildings.undo(city, fire, random, process_random).ok, "Fire station placement can be undone")
	var city_hall := Buildings.apply(city, 5, 1, Vector2i(38, 30), random, process_random)
	_check(city_hall.ok, "City Hall placement succeeds")
	_check(
		city.microsim(10).stat_1 == 200
		and city.microsim(10).stat_2 == city.current_year(),
		"City Hall starts with its population cap and construction year",
	)
	_check(Buildings.undo(city, city_hall, random, process_random).ok, "City Hall placement can be undone")
	var museum := Buildings.apply(city, 12, 3, Vector2i(42, 30), random, process_random)
	_check(museum.ok, "Museum placement succeeds")
	_check(city.microsim(7).stat_0 == 100, "Museum system starts with score byte 100")
	_check(Buildings.undo(city, museum, random, process_random).ok, "Museum placement can be undone")
	_check(city.set_building_id(40, 40, Tiles.POWER_LINE_STRAIGHT_1), "Small park rejection fixture places a power line")
	var blocked_park := Buildings.apply(
		city, 14, 0, Vector2i(40, 40), random, process_random
	)
	_check(
		not blocked_park.ok
		and not blocked_park.error.is_empty()
		and city.building_id(40, 40) == 0x0e,
		"Small park cannot replace a power line",
	)
	_check(city.set_building_id(40, 40, Tiles.EMPTY), "Small park rejection fixture clears its power line")
	var park := Buildings.apply(city, 14, 0, Vector2i(40, 40), random, process_random)
	_check(park.ok, "Small park placement succeeds")
	_check(city.tile_flags[40 * 128 + 40] & 0xe0 == 0x20, "Small park gets only the piped structure flag")
	_check(city.building_corners(40, 40) == 0xf0, "One-tile building gets all corner bits")
	_check(Buildings.undo(city, park, random, process_random).ok, "Small park placement can be undone")
	var first_bus := Buildings.apply(city, 6, 4, Vector2i(70, 70), random, process_random)
	var second_bus := Buildings.apply(city, 6, 4, Vector2i(73, 70), random, process_random)
	_check(first_bus.ok and second_bus.ok, "Bus depots use the shared placement command")
	_check(first_bus.overlay_id == 52 and second_bus.overlay_id == 52, "Bus depots share fixed microsim record one")
	_check(not city.label(52).is_empty(), "Fixed bus microsim gets its default system label")
	_check(city.microsim(1).tile_id == 0xec and city.microsim(1).stat_1 == 2, "Fixed bus microsim aggregates two depots")
	_check(Buildings.undo(city, second_bus, random, process_random).ok, "Fixed microsim aggregation can be undone")
	_check(city.microsim(1).stat_1 == 1, "Fixed microsim undo restores the prior aggregate")
	var mayor_random_before := process_random.state
	var mayor_house := Buildings.apply(city, 5, 0, Vector2i(80, 80), random, process_random)
	_check(mayor_house.ok and mayor_house.overlay_id == 61, "Mayor house allocates a dynamic microsim")
	_check(document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x0e, "Mayor house placement consumes its saved reward bit")
	_check(not city.label(61).is_empty(), "Mayor house gets its default label")
	_check(city.microsim(10).stat_1 == city.current_year(), "Mayor house stores its construction year")
	_check(city.microsim(10).stat_2 >= 10 and city.microsim(10).stat_2 <= 39, "Mayor house initializes the recovered age statistic")
	_check(Buildings.undo(city, mayor_house, random, process_random).ok, "Mayor house placement can be undone")
	_check(document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x0f, "Mayor house undo restores its reward bit")
	_check(process_random.state == mayor_random_before, "Building undo restores the process random state")
	var llama_random := Random.new(123)
	var expected_llama_random := Random.new(123)
	var expected_llama_stat := expected_llama_random.next_u15() & 0x3f
	var llama := Buildings.apply(city, 5, 3, Vector2i(84, 80), random, llama_random)
	_check(llama.ok, "Llama Dome placement succeeds")
	_check(
		city.microsim(10).stat_3 == expected_llama_stat,
		"US Llama Dome placement stores one masked process-random value",
	)
	_check(Buildings.undo(city, llama, random, llama_random).ok, "Llama Dome placement can be undone")
	var australian_random := Random.new(456)
	var australian_state := australian_random.state
	var australian_llama := Buildings.apply(
		city, 5, 3, Vector2i(84, 80), random, australian_random, true
	)
	_check(australian_llama.ok, "Australian Llama Dome placement succeeds")
	_check(
		city.microsim(10).stat_3 == city.current_year()
		and australian_random.state == australian_state,
		"Australian Llama Dome stores its construction year without random use",
	)
	_check(
		Buildings.undo(city, australian_llama, random, australian_random).ok,
		"Australian Llama Dome placement can be undone",
	)

	_check(city.set_underground_id(59, 60, UnderTiles.PIPE_LTBR), "Pump fixture places an adjacent isolated pipe")
	var pump := Buildings.apply(city, 4, 1, Vector2i(60, 60), random, process_random)
	_check(pump.ok, "Water pump placement succeeds")
	_check(city.underground_id(59, 60) == 0x11 and city.underground_id(60, 60) == 0x11, "Water pump reconnects its adjacent pipe")
	_check(city.is_piped(60, 60), "Water pump keeps the piped flag")
	_check(Buildings.undo(city, pump, random, process_random).ok, "Water pump underground changes can be undone")
	_check(city.underground_id(59, 60) == 0x1e and city.underground_id(60, 60) == 0, "Pump undo restores both underground tiles")

	_check(city.set_underground_id(64, 65, UnderTiles.SUBWAY_LTBR), "Subway fixture places an adjacent isolated subway")
	_check(document.set_misc_u32(0x0fe8, 1), "Subway fixture counts its adjacent subway")
	var subway_station := Buildings.apply(city, 7, 3, Vector2i(65, 65), random, process_random)
	_check(subway_station.ok, "Subway station placement succeeds")
	_check(city.underground_id(65, 65) == 0x23, "Subway station writes the underground entrance")
	_check(city.underground_id(64, 65) == 0x02, "Subway station reconnects its adjacent subway")
	_check(document.misc_u32(0x0fe8) == 2, "Subway station increments the saved subway count")
	_check(not city.is_piped(65, 65) and not city.is_powered(65, 65) and city.is_powerable(65, 65) and subway_station.immediate_power_refresh, "Subway station clears piped and refreshes its isolated power state")
	_check(Buildings.undo(city, subway_station, random, process_random).ok, "Subway station underground changes can be undone")
	_check(document.misc_u32(0x0fe8) == 1, "Subway station undo restores the saved subway count")

	var statue := Buildings.apply(city, 5, 2, Vector2i(68, 68), random, process_random)
	_check(statue.ok, "Statue placement succeeds")
	_check(document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x0b, "Statue placement consumes its saved reward bit")
	_check(city.is_piped(68, 68) and city.is_powered(68, 68) and not city.is_powerable(68, 68), "Statue clears the powerable flag")
	_check(Buildings.undo(city, statue, random, process_random).ok, "Statue placement can be undone")
	_check(document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x0f, "Statue undo restores its reward bit")
	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0), "Building fixture removes one-use rewards")
	var locked_reward := Buildings.apply(city, 5, 0, Vector2i(75, 75), random, process_random)
	_check(
		not locked_reward.ok and not locked_reward.error.is_empty(),
		"Building command rejects a reward that the city has not granted",
	)
	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0x0f), "Building fixture restores one-use rewards")

	_check(
		BuildingFacilities.stadium_team_choices(city) == PackedInt32Array([0, 1, 2, 3, 4]),
		"A city without teams offers all five stadium teams",
	)
	_check(
		BuildingFacilities.stadium_team_name(city, 2) == "Camels",
		"An empty sports label uses the supplied default team name",
	)
	var stadium := Buildings.apply(
		city, 14, 3, Vector2i(90, 90), random, process_random
	)
	_check(
		stadium.ok
		and stadium.stadium_team_selection_required
		and stadium.overlay_id >= 61,
		"Stadium placement requests a team when it gets an XMIC record",
	)
	var assigned_stadium := BuildingFacilities.assign_stadium_team(
		city, stadium, 2, "Camel City Flyers"
	)
	_check(
		assigned_stadium.ok,
		"Stadium team assignment succeeds: %s" % assigned_stadium.error,
	)

	if assigned_stadium.ok:
		var stadium_record_id := (
			int(stadium.overlay_id) - Buildings.MICROSIM_LABEL_BASE
		)
		var stadium_record := city.microsim(stadium_record_id)
		_check(
			document.misc_u32(Buildings.MISC_STADIUM_TEAMS) == 0x04,
			"Stadium assignment sets its saved team bit",
		)
		_check(
			stadium_record.stat_2 == 2 and stadium_record.stat_3 == 0xfd,
			"Stadium assignment stores the team index and sports-label ID in XMIC",
		)
		_check(
			city.label(0xfd) == "Camel City Flyers",
			"Stadium assignment stores the editable team name in XLAB",
		)
		_check(
			Buildings.undo(
				city, assigned_stadium, random, process_random
			).ok,
			"Assigned stadium placement can be undone as one transaction",
		)
		_check(
			document.misc_u32(Buildings.MISC_STADIUM_TEAMS) == 0
			and city.label(0xfd).is_empty()
			and city.building_id(89, 89) == 0,
			"Stadium undo restores the team bit, label, XMIC, and map",
		)

	_check(document.set_misc_u32(Buildings.MISC_STADIUM_TEAMS, 0x1b), "Stadium fixture uses four teams")
	_check(
		BuildingFacilities.stadium_team_choices(city) == PackedInt32Array([2]),
		"The Stadium dialog offers only unused teams",
	)
	_check(document.set_misc_u32(Buildings.MISC_STADIUM_TEAMS, 0x1f), "Stadium fixture uses all teams")
	_check(
		BuildingFacilities.stadium_team_choices(city) == PackedInt32Array([0, 1, 2, 3, 4]),
		"The Stadium dialog permits every team after all five are used",
	)
	_check(document.set_misc_u32(Buildings.MISC_STADIUM_TEAMS, 0), "Building fixture restores stadium teams")

	var edge := Buildings.apply(city, 3, 2, Vector2i(1, 1), random, process_random)
	_check(not edge.ok and not edge.error.is_empty(), "Four-tile building rejects the inner map edge")
	_check(city.set_building_id(20, 20, Tiles.ROAD_STRAIGHT_1), "Blocked-site fixture places a road")
	var blocked := Buildings.apply(city, 3, 2, Vector2i(20, 20), random, process_random)
	_check(not blocked.ok and not blocked.error.is_empty(), "Building placement rejects a road")
	_check(city.set_building_id(20, 20, Tiles.EMPTY), "Blocked-site fixture removes the road")
	_check(city.set_zone_id(20, 20, 7), "Military fixture sets a military zone")
	var military := Buildings.apply(city, 3, 2, Vector2i(20, 20), random, process_random)
	_check(not military.ok and not military.error.is_empty(), "Building placement rejects military zones")
	_check(city.set_zone_id(20, 20, 0), "Military fixture clears the military zone")

	for x in range(50, 53):
		for y in range(50, 53):
			_check(city.set_tile_flag(x, y, 0x04, x == 50), "Marina fixture sets shoreline water")

	var marina := Buildings.apply(city, 14, 4, Vector2i(51, 51), random, process_random)
	_check(marina.ok, "Marina placement accepts mixed land and water")
	_check(Buildings.undo(city, marina, random, process_random).ok, "Marina placement can be undone")

	for y in range(50, 53):
		_check(city.set_tile_flag(50, y, 0x04, false), "Marina dry fixture removes water")

	var dry_marina := Buildings.apply(city, 14, 4, Vector2i(51, 51), random, process_random)
	_check(not dry_marina.ok and not dry_marina.error.is_empty(), "Marina rejects an all-dry site")

	var nuisance_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			nuisance_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Nuisance fixture clears %s" % chunk_id,
		)

	_check(
		nuisance_document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0))
		and nuisance_document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)),
		"Nuisance fixture clears labels and microsimulations",
	)
	_check(nuisance_document.set_misc_i32(0x14, 5000), "Nuisance fixture sets funds")
	_check(
		nuisance_document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, 50_000_000),
		"Nuisance fixture prevents an immediate utility refresh",
	)
	var nuisance_city := CityModel.from_document(nuisance_document)

	for residential_point in [Vector2i(12, 12), Vector2i(12, 13), Vector2i(12, 14)]:
		_check(
			nuisance_city.set_zone_id(residential_point.x, residential_point.y, 1),
			"Nuisance fixture stores one nearby residential tile",
		)

	var nuisance_lfsr := LfsrRandom.new(1)
	var nuisance_process := Random.new(123)
	var nuisance_process_before := nuisance_process.state
	var rejected_nuisance := Buildings.apply(
		nuisance_city,
		3,
		2,
		Vector2i(20, 20),
		nuisance_lfsr,
		nuisance_process,
	)
	var contrasting_lcg := GameRandom.new(1)
	_check(
		not rejected_nuisance.ok
		and not rejected_nuisance.error.is_empty()
		and rejected_nuisance.residential_tiles == 3
		and rejected_nuisance.resident_objection
		and rejected_nuisance.lfsr_advanced
		and rejected_nuisance.sound_events == [512]
		and rejected_nuisance.notice_bitmap_id == 403
		and rejected_nuisance.notice_string_id == 106
		and nuisance_lfsr.state == 2
		and contrasting_lcg.next_mod(200) == 38,
		"Building nuisance rejection exposes the original notice, sound, and LFSR result",
	)
	_check(
		nuisance_city.funds() == 5000
		and nuisance_process.state == nuisance_process_before
		and nuisance_city.building_id(19, 19) == 0,
		"Nuisance rejection changes only the original LFSR state",
	)

	for residential_point in [Vector2i(12, 12), Vector2i(12, 13), Vector2i(12, 14)]:
		_check(
			nuisance_city.set_zone_id(residential_point.x, residential_point.y, 0),
			"Nuisance fixture clears one nearby residential tile",
		)

	_check(nuisance_city.set_building_id(20, 20, Tiles.ROAD_STRAIGHT_1), "Nuisance fixture blocks a Coal plant site")
	var blocked_lfsr := LfsrRandom.new(1)
	var nuisance_blocked := Buildings.apply(
		nuisance_city,
		3,
		2,
		Vector2i(20, 20),
		blocked_lfsr,
		Random.new(123),
	)
	_check(
		not nuisance_blocked.ok
		and not nuisance_blocked.error.is_empty()
		and nuisance_blocked.lfsr_advanced
		and blocked_lfsr.state == 2,
		"A nuisance building consumes its LFSR value before the site test",
	)
	_check(nuisance_city.set_building_id(20, 20, Tiles.EMPTY), "Nuisance fixture clears the blocked site")
	var edge_lfsr := LfsrRandom.new(1)
	var nuisance_edge := Buildings.apply(
		nuisance_city,
		3,
		2,
		Vector2i(1, 1),
		edge_lfsr,
		Random.new(123),
	)
	_check(
		not nuisance_edge.ok
		and not nuisance_edge.error.is_empty()
		and nuisance_edge.lfsr_advanced
		and edge_lfsr.state == 2,
		"A nuisance building consumes its LFSR value before the footprint limit",
	)

	_check(city.set_funds(3999), "Building funds fixture sets insufficient funds")
	var insufficient_lfsr_before := random.state
	var unaffordable := Buildings.apply(city, 3, 2, Vector2i(60, 60), random, process_random)
	_check(
		not unaffordable.ok
		and not unaffordable.error.is_empty()
		and not unaffordable.lfsr_advanced
		and random.state == insufficient_lfsr_before,
		"Insufficient building funds stop before the nuisance LFSR call",
	)
