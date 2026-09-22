extends "res://tests/support/core_test_suite.gd"

## Tools: demolition checks.

@warning_ignore_start("integer_division")

const Random = preload("res://src/simulation/random/sim_random.gd")
const LfsrRandom = preload("res://src/simulation/random/sim_lfsr_random.gd")
const Water = preload("res://src/simulation/infrastructure/water_phase.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")


func test_demolish_command(reference_root: String) -> void:
	_check(Demolish.supports_tool(0, 0), "Demolish command supports its catalog tool")
	_check(not Demolish.supports_tool(0, 4), "Demolish command rejects De-zone")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Demolish fixture clears %s" % chunk_id,
		)

	_check(document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Demolish fixture clears XLAB")
	_check(document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Demolish fixture clears XMIC")
	_check(document.set_misc_i32(0x14, 1000), "Demolish fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Demolish fixture counts clear tiles")
	var city := CityModel.from_document(document)
	var placement_random := LfsrRandom.new(11)
	var process_random := Random.new(17)
	var hospital := Buildings.apply(city, 13, 2, Vector2i(20, 20), placement_random, process_random)
	_check(hospital.ok and hospital.overlay_id == 61, "Demolish fixture places a dynamic hospital")
	var demolition_random := Random.new(29)
	var building := Demolish.apply_path(city, 0, 0, [Vector2i(20, 20)], demolition_random)
	_check(building.ok and building.action_count == 1 and building.tile_indices.size() == 9, "Demolish removes a complete 3-by-3 building")
	_check(
		building.effect_events.size() == 27
		and building.sound_events == [504]
		and building.effect_events[0].point == Vector2i(19, 21)
		and building.effect_events[0].frame == 0
		and building.effect_events[9].frame == 1
		and building.effect_events[9].screen_offset == Vector2i(0, -8)
		and building.effect_events[26].point == Vector2i(21, 19)
		and building.effect_events[26].frame == 2
		and building.effect_events[26].screen_offset == Vector2i(0, -16),
		"Building demolition emits one native dust frame per footprint level",
	)
	var expected_demolition_random := Random.new(29)

	for _value in 63:
		expected_demolition_random.next_u15()

	_check(
		demolition_random.state == expected_demolition_random.state,
		"Building demolition consumes visual values before its nine rubble values",
	)

	for x in range(19, 22):
		for y in range(19, 22):
			_check(city.building_id(x, y) >= 1 and city.building_id(x, y) <= 4, "Demolished dry building becomes rubble")
			_check((city.zones[x * 128 + y] & 0xf0) == 0, "Demolish clears building corner bits")
			_check((city.tile_flags[x * 128 + y] & 0xc2) == 0, "Demolish clears flip, powered, and powerable flags")
			_check(city.text_overlay_id(x, y) == 0, "Demolish clears dynamic text overlays")

	_check(city.microsim(10).tile_id == 0 and city.label(61).is_empty(), "Demolish releases dynamic XMIC and XLAB records")
	_check(building.cost == 1 and city.funds() == 499, "One building demolition costs one dollar")
	_check(Demolish.undo(city, building, demolition_random).ok, "Building demolition can be undone")
	_check(city.building_id(20, 20) == 0xd1 and city.funds() == 500, "Demolish undo restores the building and funds")

	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0x02), "Reward demolition fixture grants City Hall")
	var city_hall := Buildings.apply(
		city, 5, 1, Vector2i(30, 30), placement_random, process_random
	)
	_check(
		city_hall.ok
		and document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0,
		"Reward placement consumes the City Hall grant",
	)
	var removed_city_hall := Demolish.apply_path(
		city, 0, 0, [Vector2i(30, 30)], demolition_random
	)
	_check(
		removed_city_hall.ok
		and document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x02,
		"Demolishing City Hall restores its saved reward bit",
	)
	_check(
		Demolish.undo(city, removed_city_hall, demolition_random).ok
		and document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0,
		"Reward demolition undo restores the consumed reward state",
	)
	_check(Buildings.undo(city, city_hall, placement_random, process_random).ok, "Reward demolition fixture removes City Hall")

	var simple_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			simple_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Simple demolish fixture clears %s" % chunk_id,
		)

	_check(simple_document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Simple demolish fixture clears XLAB")
	_check(simple_document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Simple demolish fixture clears XMIC")
	_check(simple_document.set_misc_i32(0x14, 10), "Simple demolish fixture sets funds")
	_check(simple_document.set_misc_u32(0x01f0, 16383), "Simple demolish fixture counts clear tiles")
	_check(simple_document.set_misc_u32(0x01f0 + 3 * 4, 1), "Simple demolish fixture counts rubble")
	var simple_city := CityModel.from_document(simple_document)
	_check(simple_city.set_building_id(10, 10, Tiles.RUBBLE_3), "Simple demolish fixture places rubble")
	var rubble := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(rubble.ok and simple_city.building_id(10, 10) == 0, "Demolish clears rubble")
	_check(rubble.cost == 1 and simple_city.funds() == 9, "Rubble demolition charges one dollar")
	_check(Demolish.undo(simple_city, rubble, demolition_random).ok, "Rubble demolition can be undone")
	_check(simple_city.set_building_id(12, 10, Tiles.ROAD_STRAIGHT_1), "Parallel demolish fixture places its first road")
	_check(simple_city.set_building_id(13, 10, Tiles.ROAD_STRAIGHT_1), "Parallel demolish fixture places its second road")
	_check(
		simple_document.set_misc_u32(0x01f0 + 0x1d * 4, 2),
		"Parallel demolish fixture counts both road tiles",
	)
	var parallel_demolition := Demolish.apply_path(
		simple_city,
		0,
		0,
		[Vector2i(12, 10), Vector2i(13, 10)],
		demolition_random,
	)
	var parallel_effects := true
	var first_effect_frames := PackedInt32Array()

	for effect in parallel_demolition.effect_events:
		var frame := int(effect.frame)
		parallel_effects = (
			parallel_effects
			and frame >= 0
			and frame <= Demolish.MAX_PARALLEL_EFFECT_OFFSET_FRAMES
		)
		first_effect_frames.append(frame)

	_check(
		parallel_demolition.ok
		and parallel_demolition.action_count == 2
		and parallel_demolition.sound_events == [Demolish.SOUND_EXPLODE]
		and parallel_effects
		and first_effect_frames.has(0)
		and (first_effect_frames.has(1) or first_effect_frames.has(2)),
		"A bulldozer rectangle starts all tile effects with small parallel offsets",
	)
	_check(
		Demolish.undo(simple_city, parallel_demolition, demolition_random).ok
		and simple_city.building_id(12, 10) == 0x1d
		and simple_city.building_id(13, 10) == 0x1d,
		"One Undo restores the complete parallel bulldozer rectangle",
	)
	_check(simple_city.set_building_id(12, 10, Tiles.EMPTY), "Parallel demolish fixture clears its first road")
	_check(simple_city.set_building_id(13, 10, Tiles.EMPTY), "Parallel demolish fixture clears its second road")
	_check(
		simple_document.set_misc_u32(0x01f0 + 0x1d * 4, 0),
		"Parallel demolish fixture clears its road count",
	)

	for story_slot in NewsQueue.QUEUE_COUNT:
		for story_field in NewsQueue.STORY_FIELD_COUNT:
			_check(
				simple_document.set_misc_u32(
					NewsQueue.STORY_OFFSET
					+ story_slot * NewsQueue.STORY_RECORD_SIZE
					+ story_field * 4,
					0,
				),
				"Forest protest fixture clears a newspaper story field",
			)

	_check(simple_city.set_building_id(10, 10, Tiles.TREES_1), "Forest protest fixture places a tree")
	var forest_random := Random.new(19)
	var forest_protest := Demolish.apply_path(
		simple_city, 0, 0, [Vector2i(10, 10)], forest_random
	)
	var protest_story := NewsQueue.story_record(
		simple_document.find_chunk("MISC").decoded_payload, 0
	)
	_check(
		forest_protest.ok
		and forest_protest.easter_events == 1
		and forest_protest.sound_events == [Demolish.SOUND_FOREST_PROTEST]
		and forest_protest.news_queue_updated
		and NewsEvent.same_arrays(forest_protest.news_items, [NewsEvent.new(0x28, 0)]),
		"The hidden tree branch reports its protest sound and newspaper story",
	)
	var copied_protest := forest_protest.copy() as DemolishEditResult
	_check(NewsEvent.same_arrays(copied_protest.news_items, forest_protest.news_items),
		"Copied demolition results retain every news field")
	copied_protest.news_items[0].argument = 7
	_check(forest_protest.news_items[0].argument == 0,
		"Copied demolition news owns independent event values")
	_check(
		simple_city.building_id(10, 10) == 0x06
		and simple_city.funds() == 9
		and protest_story.type == 0x28
		and protest_story.priority == NewsQueue.STORY_PRIORITIES[0x28],
		"The forest protest charges one dollar, keeps the tree, and updates MISC",
	)
	_check(
		Demolish.undo(simple_city, forest_protest, forest_random).ok
		and simple_city.building_id(10, 10) == 0x06
		and simple_city.funds() == 10
		and NewsQueue.story_record(
			simple_document.find_chunk("MISC").decoded_payload, 0
		).type == 0
		and forest_random.state == 19,
		"Forest protest undo restores funds, news, and process random state",
	)
	_check(simple_city.set_zone_id(10, 10, 7), "Protected demolish fixture sets military zone")
	var military := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(not military.ok and not military.error.is_empty(), "Demolish rejects military zones")
	_check(simple_city.set_zone_id(10, 10, 0), "Highway demolish fixture clears military zone")
	_check(simple_city.set_building_id(10, 10, Tiles.HIGHWAY_STRAIGHT_1), "Highway demolish fixture places highway")
	var highway := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(not highway.ok and not highway.error.is_empty(), "Demolish rejects a malformed highway section")
	_check(simple_city.set_building_id(10, 10, Tiles.EMPTY), "Highway demolition fixture removes its malformed tile")
	_check(simple_document.set_misc_i32(0x14, 500), "Highway demolition fixture sets funds")
	var placed_highway := Highways.apply(simple_city, 6, 1, Vector2i(10, 10), Vector2i(10, 10))
	_check(placed_highway.ok, "Highway demolition fixture builds one complete section")
	var removed_highway := Demolish.apply_path(simple_city, 0, 0, [Vector2i(11, 11)], demolition_random)
	_check(
		removed_highway.ok
		and removed_highway.tile_indices.size() == 4
		and removed_highway.effect_events.size() == 8
		and removed_highway.effect_events[0].frame == 0
		and removed_highway.effect_events[4].frame == 1,
		"Demolish removes a complete 2-by-2 highway section with two dust frames",
	)

	for x in range(10, 12):
		for y in range(10, 12):
			_check(simple_city.building_id(x, y) >= 1 and simple_city.building_id(x, y) <= 4, "Demolished highway becomes rubble")

	_check(Demolish.undo(simple_city, removed_highway, demolition_random).ok, "Highway demolition can be undone")
	_check(Highways.undo(simple_city, placed_highway).ok, "Highway fixture can be removed after demolition undo")

	var underground_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			underground_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(size, 0)
			),
			"Underground demolition fixture clears %s" % chunk_id,
		)

	_check(
		underground_document.find_chunk("XLAB").set_decoded_payload(
			_filled_bytes(6400, 0)
		),
		"Underground demolition fixture clears XLAB",
	)
	_check(
		underground_document.find_chunk("XMIC").set_decoded_payload(
			_filled_bytes(1200, 0)
		),
		"Underground demolition fixture clears XMIC",
	)
	_check(
		underground_document.set_misc_i32(0x14, 5000),
		"Underground demolition fixture sets funds",
	)
	_check(
		underground_document.set_misc_u32(0x01f0, 16384),
		"Underground demolition fixture counts clear tiles",
	)
	_check(
		underground_document.set_misc_u32(0x0fe8, 3),
		"Underground demolition fixture counts three subway tiles",
	)
	_check(
		underground_document.set_misc_u32(
			ToolAvailability.MISC_INVENTION_YEARS + 9 * 4,
			0,
		),
		"Underground demolition fixture unlocks subway stations",
	)
	var underground_city := CityModel.from_document(underground_document)

	for y in range(19, 22):
		_check(
			underground_city.set_underground_id(20, y, UnderTiles.SUBWAY_LR),
			"Underground demolition fixture places subway",
		)

	var underground_random := Random.new(101)
	var removed_subway := Demolish.apply_path(
		underground_city,
		0,
		0,
		[Vector2i(20, 20)],
		underground_random,
		true
	)
	_check(
		removed_subway.ok
		and removed_subway.underground_view
		and removed_subway.action_count == 1
		and removed_subway.cost == 1
		and underground_city.underground_id(20, 20) == 0
		and underground_document.misc_u32(0x0fe8) == 2,
		"Underground Demolish removes one subway tile and updates its count",
	)
	_check(
		underground_city.underground_id(20, 19) == 0x01
		and underground_city.underground_id(20, 21) == 0x01,
		"Underground Demolish reconnects the remaining subway ends",
	)
	_check(
		Demolish.undo(underground_city, removed_subway, underground_random).ok
		and underground_city.underground_id(20, 20) == 0x01
		and underground_document.misc_u32(0x0fe8) == 3,
		"Underground subway demolition can be undone with its saved count",
	)

	for y in range(29, 32):
		_check(
			underground_city.set_underground_id(30, y, UnderTiles.PIPE_LR),
			"Underground demolition fixture places pipe",
		)
		_check(
			underground_city.set_tile_flag(30, y, 0x20, true),
			"Underground demolition fixture marks pipe",
		)

	var removed_pipe := Demolish.apply_path(
		underground_city,
		0,
		0,
		[Vector2i(30, 30)],
		underground_random,
		true
	)
	_check(
		removed_pipe.ok
		and underground_city.underground_id(30, 30) == 0
		and not underground_city.is_piped(30, 30)
		and underground_document.misc_u32(0x0fe8) == 3,
		"Underground Demolish clears a pipe and its saved piped bit",
	)
	_check(
		underground_city.underground_id(30, 29) == 0x1e
		and underground_city.underground_id(30, 31) == 0x1e,
		"Underground Demolish reconnects the remaining pipe ends",
	)
	_check(
		Demolish.undo(underground_city, removed_pipe, underground_random).ok
		and underground_city.underground_id(30, 30) == 0x10
		and underground_city.is_piped(30, 30),
		"Underground pipe demolition can be undone",
	)
	var station_random := LfsrRandom.new(111)
	var station_process_random := Random.new(113)
	var placed_station := Buildings.apply(
		underground_city,
		7,
		3,
		Vector2i(40, 40),
		station_random,
		station_process_random
	)
	_check(
		placed_station.ok
		and underground_city.underground_id(40, 40) == 0x23
		and underground_document.misc_u32(0x0fe8) == 4,
		"Underground demolition fixture places and counts a subway station",
	)
	var removed_station := Demolish.apply_path(
		underground_city,
		0,
		0,
		[Vector2i(40, 40)],
		underground_random,
		true
	)
	_check(
		removed_station.ok
		and underground_city.underground_id(40, 40) == 0
		and underground_city.building_id(40, 40) >= 1
		and underground_city.building_id(40, 40) <= 4
		and underground_document.misc_u32(0x0fe8) == 3,
		"Underground Demolish removes a subway entrance and its surface station",
	)
	_check(
		Demolish.undo(underground_city, removed_station, underground_random).ok
		and underground_city.underground_id(40, 40) == 0x23
		and underground_city.building_id(40, 40) == 0xe9,
		"Underground subway-station demolition can be undone",
	)
	_check(
		Buildings.undo(
			underground_city,
			placed_station,
			station_random,
			station_process_random
		).ok,
		"Underground demolition fixture removes the restored station",
	)

	var special_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			special_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Special demolition fixture clears %s" % chunk_id,
		)

	_check(special_document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Special demolition fixture clears XLAB")
	_check(special_document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Special demolition fixture clears XMIC")
	_check(special_document.set_misc_i32(0x14, 100), "Special demolition fixture sets funds")
	_check(special_document.set_misc_u32(0x0e40, 0), "Special demolition fixture sets sea level")
	_check(special_document.set_misc_u32(0x01f0, 16384), "Special demolition fixture counts clear tiles")
	var special_city := CityModel.from_document(special_document)
	_check(special_city.set_building_id(30, 30, Tiles.TUNNEL_ENTRANCE_1), "Tunnel demolition fixture places its first entrance")
	_check(special_city.set_building_id(28, 30, Tiles.TUNNEL_ENTRANCE_3), "Tunnel demolition fixture places its second entrance")

	for x in range(28, 31):
		_check(special_city.set_tunnel_levels(x, 30, 3), "Tunnel demolition fixture stores tunnel depth")

	var tunnel := Demolish.apply_path(special_city, 0, 0, [Vector2i(30, 30)], demolition_random)
	_check(
		tunnel.ok
		and tunnel.tile_indices.size() == 3
		and tunnel.effect_events.size() == 2
		and tunnel.effect_events[0].point == Vector2i(30, 30)
		and tunnel.effect_events[1].point == Vector2i(28, 30),
		"Demolish follows a tunnel and emits dust at both entrances",
	)
	_check(special_city.building_id(30, 30) == 0 and special_city.building_id(28, 30) == 0, "Tunnel demolition clears both entrances")

	for x in range(28, 31):
		_check(special_city.tunnel_levels(x, 30) == 0, "Tunnel demolition clears each saved depth")

	_check(Demolish.undo(special_city, tunnel, demolition_random).ok, "Tunnel demolition can be undone")

	for point in [Vector2i(40, 40), Vector2i(41, 40), Vector2i(41, 41)]:
		_check(special_city.set_building_id(point.x, point.y, Tiles.RUNWAY), "Runway demolition fixture places a connected tile")

	_check(special_city.set_building_id(45, 45, Tiles.RUNWAY), "Runway demolition fixture places a separate tile")
	var runway := Demolish.apply_path(special_city, 0, 0, [Vector2i(40, 40)], demolition_random)
	_check(
		runway.ok and runway.tile_indices.size() == 3 and runway.effect_events.size() == 3,
		"Demolish removes one connected runway component with dust on each tile",
	)
	_check(special_city.building_id(45, 45) == 0xdd, "Runway demolition preserves a separate component")

	for point in [Vector2i(40, 40), Vector2i(41, 40), Vector2i(41, 41)]:
		_check(special_city.building_id(point.x, point.y) >= 1 and special_city.building_id(point.x, point.y) <= 4, "Demolished runway becomes rubble")

	_check(Demolish.undo(special_city, runway, demolition_random).ok, "Runway demolition can be undone")

	for point in [Vector2i(50, 50), Vector2i(50, 51)]:
		_check(special_city.set_building_id(point.x, point.y, Tiles.PIER), "Pier demolition fixture places a connected tile")

	var pier := Demolish.apply_path(special_city, 0, 0, [Vector2i(50, 50)], demolition_random)
	_check(
		pier.ok
		and special_city.building_id(50, 50) == 0
		and special_city.building_id(50, 51) == 0
		and pier.effect_events.size() == 2,
		"Demolish clears a connected pier component with dust on each tile",
	)
	_check(Demolish.undo(special_city, pier, demolition_random).ok, "Pier demolition can be undone")

	_check(special_document.set_misc_u32(0x0e40, 1), "Bridge demolition fixture sets sea level")

	for x in range(70, 73):
		_check(special_city.set_building_id(x, 70, Tiles.SUSPENSION_BRIDGE_1 + x - 70), "Bridge demolition fixture places a span tile")
		_check(special_city.set_terrain_id(x, 70, 0x30), "Bridge demolition fixture places water terrain")
		_check(special_city.set_tile_flag(x, 70, 0x04, true), "Bridge demolition fixture marks span water")
		_check(special_city.set_tile_flag(x, 70, 0x02, true), "Bridge demolition fixture sets a horizontal span")

	for x in [69, 73]:
		_check(special_city.set_land_altitude(x, 70, 1), "Bridge demolition fixture raises a bank")
		_check(special_city.set_building_id(x, 70, Tiles.ROAD_STRAIGHT_1), "Bridge demolition fixture places a bank road")

	var bridge := Demolish.apply_path(special_city, 0, 0, [Vector2i(71, 70)], demolition_random)
	_check(
		bridge.ok
		and bridge.tile_indices.size() == 5
		and bridge.effect_events.size() == 3
		and bridge.sound_events == [504],
		"Demolish clears one bridge span and requests its debris and sound",
	)

	for x in range(70, 73):
		_check(special_city.building_id(x, 70) == 0, "Bridge demolition clears each span tile")

	for x in [69, 73]:
		_check(special_city.land_altitude(x, 70) == 0, "Bridge demolition lowers each dry bank")
		_check((special_city.tile_flags[x * 128 + 70] & 0x04) != 0, "Bridge demolition restores bank water")

	_check(Demolish.undo(special_city, bridge, demolition_random).ok, "Bridge demolition can be undone")

	for section in 3:
		var reinforced_tile := 0x6b if section != 1 else 0x6a

		for x_offset in 2:
			for y_offset in 2:
				var point := Vector2i(80 + section * 2 + x_offset, 80 + y_offset)
				_check(special_city.set_building_id(point.x, point.y, reinforced_tile), "Reinforced demolition fixture places a span tile")
				_check(special_city.set_terrain_id(point.x, point.y, 0x30), "Reinforced demolition fixture places water terrain")
				_check(special_city.set_tile_flag(point.x, point.y, 0x04, true), "Reinforced demolition fixture marks span water")

	for bank_point in [Vector2i(78, 80), Vector2i(86, 80)]:
		_check(special_city.set_building_id(bank_point.x, bank_point.y, Tiles.HIGHWAY_STRAIGHT_1), "Reinforced demolition fixture places a bank")
		_check(special_city.set_land_altitude(bank_point.x, bank_point.y, 1), "Reinforced demolition fixture raises a bank")

	var reinforced_bridge := Demolish.apply_path(
		special_city, 0, 0, [Vector2i(80, 80)], demolition_random
	)
	_check(
		reinforced_bridge.ok
		and reinforced_bridge.tile_indices.size() == 13
		and reinforced_bridge.effect_events.size() == 12
		and reinforced_bridge.sound_events == [504],
		"Demolish clears a reinforced span and the original forward-bank cell",
	)

	for x in range(80, 86):
		for y in range(80, 82):
			_check(special_city.building_id(x, y) == 0, "Reinforced demolition clears each span tile")

	_check(special_city.building_id(78, 80) == 0x49, "Reinforced demolition preserves the rear bank")
	_check(special_city.building_id(86, 80) == 0, "Reinforced demolition clears the forward bank")
	_check(special_city.land_altitude(86, 80) == 0, "Reinforced demolition lowers the forward bank")
	_check((special_city.tile_flags[86 * 128 + 80] & 0x04) != 0, "Reinforced demolition restores forward-bank water")
	_check(Demolish.undo(special_city, reinforced_bridge, demolition_random).ok, "Reinforced bridge demolition can be undone")

	_check(special_city.set_terrain_id(60, 60, 0x3d), "Water demolition fixture sets water terrain")
	_check(special_city.set_tile_flag(60, 60, 0x04, true), "Water demolition fixture sets its water flag")
	var water_tile := Demolish.apply_path(special_city, 0, 0, [Vector2i(60, 60)], demolition_random)
	_check(water_tile.ok and special_city.terrain_id(60, 60) == 0, "Demolish removes surface water terrain")
	_check((special_city.tile_flags[60 * 128 + 60] & 0x04) == 0, "Water demolition clears the water flag")
	_check(Demolish.undo(special_city, water_tile, demolition_random).ok, "Water demolition can be undone")

	var deep_water_point := Vector2i(61, 60)
	_check(
		special_city.set_terrain_id(deep_water_point.x, deep_water_point.y, 0x10)
		and special_city.set_tile_flag(
			deep_water_point.x, deep_water_point.y, 0x04, true
		),
		"Deep-water demolition fixture sets submerged terrain",
	)
	var deep_water_funds := special_city.funds()
	var deep_water_random_state := demolition_random.state
	var deep_water := Demolish.apply_path(
		special_city, 0, 0, [deep_water_point], demolition_random
	)
	_check(
		not deep_water.ok
		and not deep_water.error.is_empty()
		and special_city.terrain_id(deep_water_point.x, deep_water_point.y) == 0x10
		and special_city.is_water(deep_water_point.x, deep_water_point.y)
		and special_city.funds() == deep_water_funds
		and demolition_random.state == deep_water_random_state,
		"Demolish protects deep water without charging funds or changing random state",
	)
