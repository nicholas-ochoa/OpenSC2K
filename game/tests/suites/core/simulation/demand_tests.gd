extends "res://tests/support/core_test_suite.gd"

## Simulation: demand checks.

@warning_ignore_start("integer_division")

const RciDemand = preload("res://src/simulation/growth/rci_demand_phase.gd")
const RciAftermath = preload("res://src/simulation/growth/rci_aftermath_phase.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const SequenceRandom = TestRandoms.SequenceRandom


func test_rci_demand(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for index in 8:
		_check(document.set_misc_i32(0x05f0 + index * 4, 0), "RCI fixture clears zone population")

	for entry in [[1, 100], [2, 50], [3, 40], [4, 10], [5, 20], [6, 5]]:
		_check(
			document.set_misc_i32(0x05f0 + entry[0] * 4, entry[1]),
			"RCI fixture sets zone population %d" % entry[0],
		)

	for offset in [0x0718, 0x071c, 0x0720, 0x0fa0, 0x1030]:
		_check(document.set_misc_i32(offset, 0), "RCI fixture clears MISC 0x%x" % offset)

	for tile_id in [Tiles.BIG_PARK, Tiles.STADIUM, Tiles.ZOO, Tiles.RUNWAY, Tiles.RUNWAY_CROSSING, Tiles.CRANE, Tiles.MARINA]:
		_check(
			document.set_misc_i32(0x01f0 + tile_id * 4, 0),
			"RCI fixture clears tile count %d" % tile_id,
		)

	for category in 3:
		_check(document.set_misc_i32(0x077c + category * 0x6c + 4, 0), "RCI fixture clears tax rate")

	_check(document.set_misc_i32(0x0074, 100), "RCI fixture sets old residential population")
	_check(document.set_misc_i32(0x0040, 10), "RCI fixture sets garbage")
	_check(document.set_misc_i32(0x1020, 120), "RCI fixture sets arcology population")
	_check(document.set_misc_i32(0x102c, 1000), "RCI fixture sets old total population")
	_check(document.set_misc_i32(0x001c, 1), "RCI fixture sets difficulty")
	var text_overlays := _filled_bytes(128 * 128, 0)
	text_overlays[0] = 0xfa
	text_overlays[1] = 0xfa
	_check(document.find_chunk("XTXT").set_decoded_payload(text_overlays), "RCI fixture sets connection labels")
	var buildings := document.find_chunk("XBLD").decoded_payload.duplicate()
	buildings[0] = Tiles.ROAD_STRAIGHT_1
	buildings[1] = Tiles.RAIL_STRAIGHT_1
	_check(document.find_chunk("XBLD").set_decoded_payload(buildings), "RCI fixture sets road and rail connections")
	var city := CityModel.from_document(document)
	var result := RciDemand.run(city)
	_check(result.ok, "RCI demand phase completes: %s" % result.error)

	if not result.ok:
		return

	_check(result.tax_population == PackedInt64Array([150, 50, 25]), "RCI phase combines light and dense populations")
	_check(result.normal_population == 2250, "RCI phase calculates normal population")
	_check(result.commerce_connections == 1, "RCI phase counts road neighbor connections")
	_check(result.industry_connections == 1, "RCI phase counts rail neighbor connections")
	_check(
		result.demands == PackedInt32Array([-90, -265, 510]),
		"RCI phase reproduces controlled demand changes: %s" % result.demands,
	)
	_check(document.misc_i32(0x05f0) == 225, "RCI phase stores the total zone population")
	_check(document.misc_i32(0x102c) == 2250, "RCI phase stores normal population")
	_check(document.misc_i32(0x0040) == 2260, "RCI phase accumulates garbage")
	_check(document.misc_i32(0x0074) == 150, "RCI phase stores residential tax population")
	_check(document.misc_i32(0x077c) == 1520, "RCI phase stores residential budget population")
	_check(document.misc_i32(0x07e8) == 510, "RCI phase stores commercial budget population")
	_check(document.misc_i32(0x0854) == 260, "RCI phase stores industrial budget population")


func test_rci_aftermath(reference_root: String) -> void:
	_check(
		RciAftermath.WEATHER_TRANSITIONS.size() == 384
		and RciAftermath.weather_transition(0, 0, 7) == 8
		and RciAftermath.weather_transition(8, 2, 7) == 11
		and RciAftermath.weather_transition(11, 3, 3) == 8,
		"Weather transitions use all 384 bytes of the supplied four-season table",
	)

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var source := Vector2i(10, 20)
	var neighbor := Vector2i(11, 20)
	var source_index := source.x * CityModel.MAP_SIZE + source.y
	var neighbor_index := neighbor.x * CityModel.MAP_SIZE + neighbor.y
	var buildings: PackedByteArray = document.find_chunk("XBLD").decoded_payload.duplicate()
	var zones: PackedByteArray = document.find_chunk("XZON").decoded_payload.duplicate()
	var flags: PackedByteArray = document.find_chunk("XBIT").decoded_payload.duplicate()
	buildings[source_index] = Tiles.TREES_1
	buildings[neighbor_index] = Tiles.EMPTY
	zones[source_index] &= 0xf0
	zones[neighbor_index] &= 0xf0
	flags[source_index] &= ~0x04
	flags[neighbor_index] &= ~0x04
	_check(document.find_chunk("XBLD").set_decoded_payload(buildings), "RCI aftermath fixture stores a young tree")
	_check(document.find_chunk("XZON").set_decoded_payload(zones), "RCI aftermath fixture clears military zones")
	_check(document.find_chunk("XBIT").set_decoded_payload(flags), "RCI aftermath fixture clears water flags")

	for setting in [
		[0x01f0 + 0 * 4, 100],
		[0x01f0 + 6 * 4, 1],
		[0x01f0 + 7 * 4, 0],
		[0x01f0 + 0xd7 * 4, 0],
		[0x0048, 60],
		[0x004c, 80],
		[0x0060, 100],
		[0x0064, 20],
		[0x0068, 10],
		[0x006c, 0],
		[0x0fa4, 0],
	]:
		_check(document.set_misc_u32(setting[0], setting[1]), "RCI aftermath fixture sets MISC 0x%x" % setting[0])

	var graphs: PackedByteArray = document.find_chunk("XGRP").decoded_payload.duplicate()

	for series in [4, 5, 7]:
		_write_u32_be(graphs, series * CityModel.GRAPH_VALUE_COUNT * 4, 0)

	_check(document.find_chunk("XGRP").set_decoded_payload(graphs), "RCI aftermath fixture stores quiet graph values")
	var tree_random := SequenceRandom.new([
		10, 20, 0,
		1,
		127, 0, 127, 0, 127, 0,
		0, 0,
		0, 0,
		1,
		7,
	])
	var city := CityModel.from_document(document)
	var result := RciAftermath.run(city, tree_random, 0)
	_check(result.ok, "RCI aftermath phase completes: %s" % result.error)

	if result.ok:
		_check(
			city.building_id(source.x, source.y) == 7
			and city.building_id(neighbor.x, neighbor.y) == 6,
			"Monthly ecology matures one tree and seeds its selected neighbor",
		)
		_check(
			document.misc_u32(0x01f0) == 99
			and document.misc_u32(0x01f0 + 6 * 4) == 1
			and document.misc_u32(0x01f0 + 7 * 4) == 1,
			"Monthly ecology updates the saved tile counts",
		)
		_check(
			result.weather_trend == 8
			and result.heat == 137
			and result.wind == 40
			and result.rain == 20,
			"Weather uses the recovered transition and target averages",
		)
		_check(
			document.misc_u32(0x0060) == 137
			and document.misc_u32(0x0064) == 40
			and document.misc_u32(0x0068) == 20
			and document.misc_u32(0x006c) == 8,
			"Weather stores all four save-visible MISC fields",
		)
		_check(
			NewsEvent.same_arrays(result.news_items, [
				NewsEvent.new(RciAftermath.NEWS_JUNK, 0),
				NewsEvent.new(0x0b, 0),
			]),
			"The ordinary monthly news branch keeps its original order",
		)
		_check(tree_random.position == 16, "Tree, news, invention, and weather checks consume 16 random values")

	var news_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(news_document.set_misc_u32(0x000c, 1900), "News fixture sets the founding year")
	_check(news_document.set_misc_u32(0x0048, 50), "News fixture sets low health")
	_check(news_document.set_misc_u32(0x004c, 50), "News fixture sets low education")
	_check(news_document.set_misc_u32(0x005c, 2), "News fixture sets the national trend")
	_check(news_document.set_misc_u32(0x0060, 100), "News fixture sets heat")
	_check(news_document.set_misc_u32(0x0064, 10), "News fixture sets wind")
	_check(news_document.set_misc_u32(0x0068, 20), "News fixture sets rain")
	_check(news_document.set_misc_u32(0x006c, 1), "News fixture sets clear weather")
	_check(news_document.set_misc_u32(0x01f0 + 0xd7 * 4, 1), "News fixture counts a stadium")
	_check(news_document.set_misc_u32(0x0738 + 7 * 4, 1901), "News fixture schedules an innovation")
	_check(news_document.set_misc_u32(0x0fa4, 10), "News fixture sets unemployment")
	_check(news_document.set_misc_u32(0x1028, 1 << 2), "News fixture enables sports team 2")
	var news_flags: PackedByteArray = news_document.find_chunk("XBIT").decoded_payload.duplicate()
	var news_point := Vector2i(40, 40)
	news_flags[news_point.x * CityModel.MAP_SIZE + news_point.y] |= 0x04
	_check(news_document.find_chunk("XBIT").set_decoded_payload(news_flags), "News fixture makes the ecology point water")
	var news_graphs: PackedByteArray = news_document.find_chunk("XGRP").decoded_payload.duplicate()

	for series in [4, 5, 7]:
		_write_u32_be(news_graphs, series * CityModel.GRAPH_VALUE_COUNT * 4, 20)

	_check(news_document.find_chunk("XGRP").set_decoded_payload(news_graphs), "News fixture stores high graph values")
	var news_misc: PackedByteArray = news_document.find_chunk("MISC").decoded_payload.duplicate()

	for slot in NewsQueue.STORY_RECORD_COUNT:
		var offset := NewsQueue.STORY_OFFSET + slot * NewsQueue.STORY_RECORD_SIZE
		_write_u32_be(news_misc, offset, 11 + slot)
		_write_u32_be(news_misc, offset + 4, 0)
		_write_u32_be(news_misc, offset + 8, 0)

		for field in range(3, NewsQueue.STORY_FIELD_COUNT):
			_write_u32_be(news_misc, offset + field * 4, 0xff)

	_check(
		news_document.find_chunk("MISC").set_decoded_payload(news_misc),
		"News fixture clears the saved priority queue",
	)
	var news_city := CityModel.from_document(news_document)
	_check(news_city.set_age_in_days(300), "News fixture selects 1901")
	var news_random := SequenceRandom.new([
		40, 40,
		0, 0, 0,
		2,
		0, 15, 0, 15, 0, 15,
		0, 3,
		79, 59,
		0,
		0,
	])
	var news_result := RciAftermath.run(news_city, news_random, 2)
	_check(news_result.ok, "Controlled RCI news phase completes: %s" % news_result.error)

	if news_result.ok:
		var news_types := PackedInt32Array()

		for item in news_result.news_items:
			news_types.append(int(item.type))

		_check(
			news_types == PackedInt32Array([1, 6, 7, 8, 17, 18, 16, 21, 19, 20, 5]),
			"RCI news checks emit the recovered ordered story types: %s" % news_types,
		)
		_check(
			news_result.news_items[2].argument == 2
			and news_result.news_items[3].argument == 2,
			"Market and sports stories retain their native arguments",
		)
		_check(news_result.invention_index == 7, "The first due innovation is released")
		_check(news_document.misc_u32(0x0738 + 7 * 4) == 0, "A released innovation clears its saved year")
		_check(news_random.position == 18, "The full controlled news path consumes 18 random values")
		var queued_types := PackedInt32Array()
		var queued_priorities := PackedInt32Array()
		var saved_misc: PackedByteArray = news_document.find_chunk("MISC").decoded_payload

		for slot in NewsQueue.QUEUE_COUNT:
			var record := NewsQueue.story_record(saved_misc, slot)
			queued_types.append(record.type)
			queued_priorities.append(record.priority)

		_check(
			news_result.news_queue_updated
			and queued_types == PackedInt32Array([5, 6, 20, 19, 21, 16, 18]),
			"The monthly RCI phase stores its seven highest-priority stories",
		)
		_check(
			queued_priorities == PackedInt32Array([1000, 360, 200, 200, 200, 200, 200]),
			"The monthly RCI phase stores source-table priorities",
		)

	var arcology_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(arcology_document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 6), "Arcology release fixture sets metropolis progression")
	_check(arcology_document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0), "Arcology release fixture clears rewards")
	_check(arcology_document.set_misc_u32(0x000c, 1900), "Arcology release fixture sets the founding year")
	_check(arcology_document.set_misc_u32(0x006c, 1), "Arcology release fixture sets valid weather")
	_check(arcology_document.set_misc_u32(0x01f0 + 0xd7 * 4, 0), "Arcology release fixture clears stadiums")

	for invention_index in ToolAvailability.INVENTION_COUNT:
		_check(
			arcology_document.set_misc_u32(
				ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
				1902,
			),
			"Arcology release fixture schedules invention %d" % invention_index,
		)

	_check(
		arcology_document.set_misc_u32(
			ToolAvailability.MISC_INVENTION_YEARS + 12 * 4,
			1901,
		),
		"Arcology release fixture schedules its first arcology",
	)
	var arcology_flags: PackedByteArray = arcology_document.find_chunk("XBIT").decoded_payload.duplicate()
	arcology_flags[40 * CityState.MAP_SIZE + 40] |= 0x04
	_check(arcology_document.find_chunk("XBIT").set_decoded_payload(arcology_flags), "Arcology release fixture makes its ecology point water")
	var arcology_city := CityModel.from_document(arcology_document)
	_check(arcology_city.set_age_in_days(300), "Arcology release fixture selects 1901")
	var arcology_release := RciAftermath.run(
		arcology_city,
		SequenceRandom.new([
			40, 40,
			1,
			127, 0, 127, 0, 127, 0,
			0, 127,
			79, 59,
			0,
			0,
		]),
		0,
	)
	_check(
		arcology_release.ok
		and arcology_release.invention_index == 12
		and arcology_document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x10,
		"A released arcology rebuild enables its saved chooser bit",
	)

	var radioactive_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var radioactive_buildings: PackedByteArray = radioactive_document.find_chunk("XBLD").decoded_payload.duplicate()
	var radioactive_flags: PackedByteArray = radioactive_document.find_chunk("XBIT").decoded_payload.duplicate()
	var radioactive_zones: PackedByteArray = radioactive_document.find_chunk("XZON").decoded_payload.duplicate()
	var radioactive_point := Vector2i(50, 50)
	var radioactive_neighbor := Vector2i(51, 50)
	var radioactive_index := radioactive_point.x * CityModel.MAP_SIZE + radioactive_point.y
	var radioactive_neighbor_index := radioactive_neighbor.x * CityModel.MAP_SIZE + radioactive_neighbor.y
	radioactive_buildings[radioactive_index] = Tiles.RADIOACTIVE_WASTE
	radioactive_buildings[radioactive_neighbor_index] = Tiles.EMPTY
	radioactive_flags[radioactive_index] &= ~0x04
	radioactive_flags[radioactive_neighbor_index] &= ~0x04
	radioactive_zones[radioactive_index] &= 0xf0
	radioactive_zones[radioactive_neighbor_index] &= 0xf0
	_check(radioactive_document.find_chunk("XBLD").set_decoded_payload(radioactive_buildings), "Ecology fixture stores radioactivity")
	_check(radioactive_document.find_chunk("XBIT").set_decoded_payload(radioactive_flags), "Ecology fixture stores dry land")
	_check(radioactive_document.find_chunk("XZON").set_decoded_payload(radioactive_zones), "Ecology fixture stores normal zones")
	_check(radioactive_document.set_misc_u32(0x006c, 0), "Ecology fixture sets valid weather")
	var radioactive_result := RciAftermath.run(
		CityModel.from_document(radioactive_document),
		SequenceRandom.new([50, 50, 0, 0, 0]),
		0
	)
	_check(radioactive_result.ok, "Radioactivity ecology path completes: %s" % radioactive_result.error)

	if radioactive_result.ok:
		_check(
			radioactive_document.find_chunk("XBLD").decoded_payload[radioactive_index] == 0
			and radioactive_document.find_chunk("XBLD").decoded_payload[radioactive_neighbor_index] == 6,
			"Radioactivity can decay before the independent tree-spread gate",
		)
