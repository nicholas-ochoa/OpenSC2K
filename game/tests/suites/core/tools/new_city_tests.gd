extends "res://tests/support/core_test_suite.gd"
## Tools: new city checks.

@warning_ignore_start("integer_division")

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const Water = preload("res://src/simulation/infrastructure/water_phase.gd")
const Bonds = preload("res://src/simulation/economy/bond_command.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")
const NewCity = preload("res://src/model/new_city_setup.gd")


func test_new_city_terrain(_reference_root: String) -> void:
	var template := EmptyCityTemplate.create()
	var original_altitude := template.find_chunk("ALTM").decoded_payload.duplicate()
	var options := NewCityTerrain.Options.new()
	options.ocean = NewCityTerrain.DEFAULT_OCEAN
	options.river = NewCityTerrain.DEFAULT_RIVER
	options.hills = NewCityTerrain.DEFAULT_HILLS
	options.water = NewCityTerrain.DEFAULT_WATER
	options.trees = NewCityTerrain.DEFAULT_TREES
	var process_random := Random.new(1)
	var game_random := GameRandom.new(1)
	var generated := NewCity.create(
		template, "Terrain City", "Terrain Mayor", 1, 1900,
		process_random, game_random, options
	)
	_check(generated.ok, "Default new-city terrain generates: %s" % generated.error)

	if generated.ok:
		var document: Sc2File = generated.document
		var city := CityModel.from_document(document)
		var terrain_result: NewCityTerrain.Result = generated.terrain
		_check(
			terrain_result.water_level == 4
			and document.misc_u32(NewCityTerrain.MISC_WATER_LEVEL) == 4
			and document.misc_u32(NewCityTerrain.MISC_HAS_OCEAN) == 0
			and document.misc_u32(NewCityTerrain.MISC_HAS_RIVER) == 1,
			"Default terrain stores its recovered water, ocean, and river values",
		)
		var water_tiles := 0
		var tree_tiles := 0

		for x in CityState.MAP_SIZE:
			for y in CityState.MAP_SIZE:
				var building := city.building_id(x, y)

				if city.is_water(x, y):
					water_tiles += 1

				if building >= 0x06 and building <= 0x0c:
					tree_tiles += 1

		var saved_count_total := 0

		for building_id in 256:
			saved_count_total += document.misc_u32(
				NewCityTerrain.MISC_TILE_COUNTS + building_id * 4
			)

		_check(
			water_tiles == terrain_result.water_tiles and water_tiles > 0,
			"Default terrain makes the recovered river and water paths",
		)
		_check(
			tree_tiles == terrain_result.tree_tiles and tree_tiles > 0,
			"Default terrain grows trees only on its dry tiles",
		)
		_check(
			saved_count_total == CityState.TILE_COUNT,
			"Generated terrain rebuilds all saved XBLD tile counts",
		)
		var direct_process := Random.new(1)
		var direct_game := GameRandom.new(1)
		var direct_document := template.duplicate_document()
		var direct := NewCityTerrain.generate(
			direct_document, options.ocean, options.river, options.hills, options.water, options.trees,
			direct_process, direct_game
		)
		_check(
			direct.ok
			and direct.water_tiles == 1456
			and direct.tree_tiles == 2009
			and direct.minimum_altitude == 2
			and direct.maximum_altitude == 11
			and direct_process.state == 981240924
			and direct_game.state == 1692766423,
			"Seed one preserves the recovered terrain pass and random-call order",
		)
		var direct_city := CityModel.from_document(direct_document)
		var cardinal_grade_is_valid := true

		for x in CityState.MAP_SIZE:
			for y in CityState.MAP_SIZE:
				if x < CityState.MAP_SIZE - 1:
					cardinal_grade_is_valid = cardinal_grade_is_valid and (
						absi(direct_city.land_altitude(x, y) - direct_city.land_altitude(x + 1, y)) <= 1
					)

				if y < CityState.MAP_SIZE - 1:
					cardinal_grade_is_valid = cardinal_grade_is_valid and (
						absi(direct_city.land_altitude(x, y) - direct_city.land_altitude(x, y + 1)) <= 1
					)

		_check(
			cardinal_grade_is_valid,
			"Seed one terrain keeps each cardinal height change to one level",
		)

		# the neighbors take their random values before the terrain
		var ordered_process := Random.new(1)
		var ordered_game := GameRandom.new(1)
		var ordered_document := template.duplicate_document()
		NewCity.draw_neighbors(ordered_document, ordered_process)
		var ordered := NewCityTerrain.generate(
			ordered_document, options.ocean, options.river, options.hills, options.water, options.trees,
			ordered_process, ordered_game
		)
		_check(
			ordered.ok
			and ordered_document.find_chunk("ALTM").decoded_payload == document.find_chunk("ALTM").decoded_payload
			and ordered_game.state == game_random.state,
			"New City draws the neighbors before it generates the terrain",
		)
		var serialized := document.serialize()
		var reparsed := Sc2Document.new()
		_check(
			serialized.ok and reparsed.parse(serialized.data),
			"Generated terrain serializes and reparses: %s" % reparsed.parse_error,
		)

	var repeated_process := Random.new(1)
	var repeated_game := GameRandom.new(1)
	var repeated := NewCity.create(
		template, "Terrain City", "Terrain Mayor", 1, 1900,
		repeated_process, repeated_game, options
	)
	_check(repeated.ok, "Repeated terrain generation succeeds: %s" % repeated.error)

	if generated.ok and repeated.ok:
		var same_maps := true

		for chunk_id in ["ALTM", "XTER", "XBLD", "XBIT"]:
			same_maps = same_maps and (
				generated.document.find_chunk(chunk_id).decoded_payload
				== repeated.document.find_chunk(chunk_id).decoded_payload
			)

		_check(
			same_maps
			and repeated_process.state == process_random.state
			and repeated_game.state == game_random.state,
			"Terrain generation is deterministic for both recovered random states",
		)

	_test_preview_random_cursors(options)
	_test_new_city_neighbors(template)

	var ocean_options := NewCityTerrain.Options.new()
	ocean_options.ocean = true
	ocean_options.river = false
	ocean_options.hills = 12
	ocean_options.water = 5
	ocean_options.trees = 0
	var ocean := NewCity.create(
		template, "Ocean City", "Ocean Mayor", 1, 1900,
		Random.new(1), GameRandom.new(1),
		ocean_options
	)
	_check(ocean.ok, "Ocean-only terrain generates: %s" % ocean.error)

	if ocean.ok:
		var ocean_city := CityModel.from_document(ocean.document)
		var wet_east_edge := 0

		for y in CityState.MAP_SIZE:
			if ocean_city.is_water(CityState.MAP_SIZE - 1, y):
				wet_east_edge += 1

		_check(
			ocean.terrain.salt_water_tiles > 0
			and wet_east_edge > (CityState.MAP_SIZE >> 1),
			"Ocean terrain makes a salt-water edge",
		)

	var rejected_process := Random.new(123)
	var rejected_game := GameRandom.new(456)
	var rejected := NewCityTerrain.generate(
		template.duplicate_document(), false, true, 48, 5, 15,
		rejected_process, rejected_game
	)
	_check(
		not rejected.ok
		and rejected_process.state == 123
		and rejected_game.state == 456
		and template.find_chunk("ALTM").decoded_payload == original_altitude,
		"Invalid terrain settings preserve both random states and the template",
	)


func test_new_city_setup(_reference_root: String) -> void:
	var template := EmptyCityTemplate.create()
	var original_name := template.city_name()
	var original_misc := template.find_chunk("MISC").decoded_payload.duplicate()
	var newspaper_session := _filled_bytes(NewsQueue.MISC_SIZE, 0)
	var newspaper_random := Random.new(1)
	_check(
		NewsQueue.initialize_session(newspaper_session, newspaper_random).ok,
		"New city fixture prepares the recovered newspaper session",
	)
	var easy_random := Random.new(1)
	var easy := NewCity.create(
		template,
		"  Test City  ",
		"  Test Mayor  ",
		1,
		1900,
		easy_random,
		null,
		null,
		newspaper_session,
	)
	_check(easy.ok, "Easy new city initializes: %s" % easy.error)

	if easy.ok:
		var document: Sc2File = easy.document
		var city := CityModel.from_document(document)
		_check(
			document.source_path.is_empty()
			and city.city_name() == "Test City"
			and city.mayor_name() == "Test Mayor",
			"New city trims and stores its names without a source path",
		)
		_check(
			city.city_mode() == 1
			and city.difficulty() == 1
			and city.founding_year() == 1900
			and city.funds() == 20000,
			"Easy new city stores its mode, difficulty, year, and funds",
		)
		_check(
			document.misc_u32(NewCity.MISC_BONDS) == 0
			and document.misc_u32(NewCity.MISC_NATIONAL_POPULATION) == 10000
			and document.misc_u32(NewCity.MISC_NATIONAL_FEDERAL_RATE) == 3
			and document.misc_u32(NewCity.MISC_NATIONAL_ECONOMY_TREND) == 0,
			"Easy new city stores its national settings without a bond",
		)
		_check(
			city.graph_series(NewCity.GRAPH_GNP).year[0] == 3
			and city.graph_series(NewCity.GRAPH_NATIONAL_POPULATION).year[0] == 10000,
			"New city seeds GNP and national-population history",
		)
		_check(
			easy.invention_years
			== PackedInt32Array([
				1941, 1957, 1994, 1970, 2029, 2054, 1938, 1938, 1912,
				1904, 1930, 1985, 1991, 2047, 2091, 2151, 2205,
			]),
			"New city uses the confirmed invention table and Microsoft random values",
		)
		var founding_story := NewsQueue.story_record(
			document.find_chunk("MISC").decoded_payload, 0
		)
		_check(
			founding_story.type == NewCity.FOUNDING_STORY_TYPE
			and founding_story.priority == 1000,
			"New city inserts the founding newspaper story",
		)
		var new_city_paper_state_valid := true

		for paper_index in NewsQueue.PAPER_COUNT:
			var actual_paper := NewsQueue.paper_record(document.find_chunk("MISC").decoded_payload, paper_index)
			var expected_paper := NewsQueue.paper_record(newspaper_session, paper_index)
			new_city_paper_state_valid = new_city_paper_state_valid and (
				actual_paper.name == expected_paper.name
				and actual_paper.layout == expected_paper.layout
				and actual_paper.price == expected_paper.price
				and actual_paper.opinion == expected_paper.opinion
				and actual_paper.weather == expected_paper.weather
			)

		var expected_story_types := PackedInt32Array([2, 11, 12, 13, 14, 15, 16, 18, 19])

		for slot in NewsQueue.STORY_RECORD_COUNT:
			new_city_paper_state_valid = new_city_paper_state_valid and (
				NewsQueue.story_record(
					document.find_chunk("MISC").decoded_payload, slot
				).type == expected_story_types[slot]
			)

		_check(
			new_city_paper_state_valid,
			"New city copies the session papers before it inserts the founding story",
		)
		var serialized := document.serialize()
		var reparsed := Sc2Document.new()
		_check(
			serialized.ok and reparsed.parse(serialized.data),
			"New city serializes and reparses: %s" % reparsed.parse_error,
		)

		if reparsed.is_valid():
			_check(
				reparsed.city_name() == "Test City"
				and reparsed.misc_u32(NewCity.MISC_START_YEAR) == 1900,
				"Reparsed new city preserves its identity and starting year",
			)

	var medium := NewCity.create(
		template, "123456789012345678901234567890EXTRA",
		"12345678901234567890123EXTRA", 2, 2000, Random.new(1)
	)
	_check(medium.ok, "Medium new city initializes: %s" % medium.error)

	if medium.ok:
		var medium_city := CityModel.from_document(medium.document)
		_check(
			medium_city.city_name() == "123456789012345678901234567890"
			and medium_city.mayor_name() == "12345678901234567890123",
			"New city applies the safe CNAM and XLAB limits",
		)
		_check(
			medium_city.difficulty() == 2
			and medium_city.funds() == 10000
			and medium.document.misc_u32(NewCity.MISC_NATIONAL_POPULATION) == 60000
			and medium.document.misc_u32(NewCity.MISC_NATIONAL_ECONOMY_TREND) == 1,
			"Medium year 2000 uses the recovered economy settings",
		)
		_check(
			medium.invention_years
			== PackedInt32Array([
				0, 0, 0, 0, 2029, 2054, 0, 0, 0, 0, 0, 0, 0,
				2047, 2091, 2151, 2205,
			]),
			"Year 2000 clears inventions that were already available",
		)

	var hard := NewCity.create(
		template, "", "", 3, 2050, Random.new(1)
	)
	_check(hard.ok, "Hard new city initializes: %s" % hard.error)

	if hard.ok:
		var hard_city := CityModel.from_document(hard.document)
		var bond_budget := (
			NewCity.MISC_BUDGETS + NewCity.BUDGET_BONDS * NewCity.BUDGET_RECORD_SIZE
		)
		_check(
			hard_city.city_name() == "New City"
			and hard_city.mayor_name() == "Mayor",
			"Blank new-city names use safe defaults",
		)
		_check(
			hard_city.difficulty() == 3
			and hard_city.funds() == 10000
			and hard.document.misc_u32(NewCity.MISC_BONDS) == 1
			and hard.document.misc_u32(NewCity.MISC_BOND_RATES) == 3,
			"Hard new city stores its 3 percent starting bond",
		)
		_check(
			hard.document.misc_i32(bond_budget + NewCity.BUDGET_CURRENT) == 1
			and hard.document.misc_i32(bond_budget + NewCity.BUDGET_FUNDING) == 30000
			and hard.document.misc_i32(bond_budget + NewCity.BUDGET_YEAR_TO_DATE) == 30000
			and hard.document.misc_i32(bond_budget + NewCity.BUDGET_COUNT_MONTH_0) == 1
			and hard.document.misc_i32(bond_budget + NewCity.BUDGET_FUND_MONTH_0) == 30000,
			"Hard new city initializes the saved Bonds budget record",
		)
		_check(
			hard.document.misc_u32(NewCity.MISC_NATIONAL_POPULATION) == 150000
			and hard.document.misc_u32(NewCity.MISC_NATIONAL_ECONOMY_TREND) == 2,
			"Hard year 2050 uses the recovered national settings",
		)

	var rejected_random := Random.new(123)
	_check(
		not NewCity.create(template, "X", "Y", 0, 1900, rejected_random).ok
		and rejected_random.state == 123,
		"New city rejects an invalid difficulty without consuming random state",
	)
	_check(
		not NewCity.create(template, "X", "Y", 1, 1975, Random.new(1)).ok,
		"New city rejects an unsupported starting year",
	)
	_check(
		template.city_name() == original_name
		and template.find_chunk("MISC").decoded_payload == original_misc,
		"New city setup never changes the supplied template",
	)


func test_map_edits(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_terrain_id(4, 5, 0x2a), "Terrain tile can change")
	_check(city.set_building_id(4, 5, Tiles.ABANDONED_1X1_1), "Building tile can change")
	_check(city.set_zone_id(4, 5, 0x05), "Zone can change")
	_check(city.set_building_corners(4, 5, 0xa0), "Building corners can change")
	_check(city.set_underground_id(4, 5, UnderTiles.MISSILE_SILO), "Underground tile can change")
	_check(city.set_text_overlay_id(4, 5, 0x31), "Text overlay can change")
	_check(city.set_tile_flag(4, 5, 0x40, true), "Tile powered flag can change")
	_check(city.set_land_altitude(4, 5, 17), "Land altitude can change")
	_check(city.set_water_altitude(4, 5, 19), "Water altitude can change")
	_check(city.set_tunnel_levels(4, 5, 41), "Tunnel depth can change")
	var serialized := document.serialize()
	_check(serialized.ok, "Map-edited city serializes")

	if not serialized.ok:
		return

	var reparsed := Sc2Document.new()
	_check(reparsed.parse(serialized.data), "Map-edited city parses")

	if not reparsed.is_valid():
		return

	var result := CityModel.from_document(reparsed)
	_check(result.terrain_id(4, 5) == 0x2a, "Terrain edit persists")
	_check(result.building_id(4, 5) == 0x8a, "Building edit persists")
	_check(result.zone_id(4, 5) == 0x05, "Zone edit persists")
	_check(result.building_corners(4, 5) == 0xa0, "Building corners persist")
	_check(result.underground_id(4, 5) == 0x22, "Underground edit persists")
	_check(result.text_overlay_id(4, 5) == 0x31, "Text overlay edit persists")
	_check(result.is_powered(4, 5), "Tile flag edit persists")
	_check(result.land_altitude(4, 5) == 17, "Land altitude edit persists")
	_check(result.water_altitude(4, 5) == 19, "Water altitude edit persists")
	_check(result.tunnel_levels(4, 5) == 41, "Tunnel depth edit persists")
	_check(not result.set_zone_id(-1, 0, 1), "Out-of-range map edits fail")
	_check(not result.set_land_altitude(0, 0, 32), "Out-of-range altitude fails")


func _test_new_city_neighbors(template: Sc2File) -> void:
	var drawn := template.duplicate_document()
	NewCity.draw_neighbors(drawn, Random.new(1))
	var expected := [[6, 3767, 1255], [29, 4178, 1392], [18, 1181, 590], [24, 3095, 3095]]
	_check(
		_neighbor_records(drawn) == expected,
		"Seed one draws the original neighbor names, populations, and values: %s" % [_neighbor_records(drawn)],
	)

	var inland_options := NewCityTerrain.Options.new()
	inland_options.ocean = false
	var inland := NewCity.create(template, "Inland", "Mayor", 1, 1900, Random.new(7), GameRandom.new(7), inland_options)
	var inland_names := PackedInt32Array()

	if inland.ok:
		for record in _neighbor_records(inland.document):
			if record[0] >= 1 and record[0] <= CityNeighbors.NAMES.size() and record[0] not in inland_names:
				inland_names.append(record[0])

	_check(inland.ok and inland_names.size() == CityNeighbors.COUNT, "A map without an ocean has four different named neighbors")

	var ocean_options := NewCityTerrain.Options.new()
	ocean_options.ocean = true
	var ocean := NewCity.create(template, "Coast", "Mayor", 1, 1900, Random.new(7), GameRandom.new(7), ocean_options)
	var ocean_records := _neighbor_records(ocean.document) if ocean.ok else []
	_check(
		ocean.ok
		and ocean_records[0] == [0, 0, 0]
		and ocean.document.misc_u32(Sc2MiscLayout.NEIGHBORS + NewCity.NEIGHBOR_FAME) == 0
		and ocean_records.slice(1).all(func(record: Array) -> bool: return record[0] > 0),
		"An ocean map makes only the first neighbor the ocean",
	)

	for layout in ["island", "islands"]:
		var island_options := NewCityTerrain.Options.new()
		island_options.ocean = false
		island_options.layout = layout
		var island := NewCity.create(template, "Isle", "Mayor", 1, 1900, Random.new(7), GameRandom.new(7), island_options)
		_check(
			island.ok and _neighbor_records(island.document) == [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]],
			"An %s map has the ocean on all four sides" % layout,
		)

	# the New City dialog founds its preview with the same neighbors
	var session := NewCityTerrainSession.new()
	session.begin(7, 7)
	var preview := session.generate_preview(ocean_options, false)
	var founded := session.create_city("Coast", "Mayor", 1, 1900, ocean_options, PackedByteArray())
	_check(
		preview.ok and founded.ok and ocean.ok
		and _neighbor_records(founded.document) == ocean_records
		and founded.invention_years == ocean.invention_years,
		"The New City dialog keeps the original random order for neighbors, terrain, and inventions",
	)


func _neighbor_records(document: Sc2File) -> Array:
	var records := []

	for slot in CityNeighbors.COUNT:
		var offset := Sc2MiscLayout.NEIGHBORS + slot * NewCity.NEIGHBOR_STRIDE
		records.append([
			document.misc_u32(offset), document.misc_u32(offset + NewCity.NEIGHBOR_POPULATION),
			document.misc_u32(offset + NewCity.NEIGHBOR_VALUE),
		])

	return records


func _test_preview_random_cursors(options: NewCityTerrain.Options) -> void:
	var terrain_session := NewCityTerrainSession.new()
	terrain_session.begin(1, 1)
	var session_preview := terrain_session.generate_preview(options, false)
	_check(
		session_preview.ok
		and terrain_session.matches(options)
		and terrain_session.preview_process_start == 1
		and terrain_session.preview_game_start == 1
		and terrain_session.preview_process_cursor == 353119329
		and terrain_session.preview_game_cursor == 1692766423,
		"New City terrain session owns the preview seeds and current options (%d, %d)"
		% [
			terrain_session.preview_process_cursor,
			terrain_session.preview_game_cursor,
		],
	)
	var repeated_preview := terrain_session.generate_preview(options, false)
	var repeated_preview_matches: bool = (
		bool(session_preview.ok) and bool(repeated_preview.ok)
	)

	if repeated_preview_matches:
		for chunk_id in ["ALTM", "XTER", "XBLD", "XBIT"]:
			repeated_preview_matches = repeated_preview_matches and (
				session_preview.document.find_chunk(chunk_id).decoded_payload
				== repeated_preview.document.find_chunk(chunk_id).decoded_payload
			)

	_check(
		repeated_preview_matches
		and terrain_session.preview_process_start == 1
		and terrain_session.preview_game_start == 1,
		"New City option previews reuse their initial random states",
	)
	var previous_process_cursor := terrain_session.preview_process_cursor
	var previous_game_cursor := terrain_session.preview_game_cursor
	var advanced_preview := terrain_session.generate_preview(options, true)
	_check(
		advanced_preview.ok
		and terrain_session.preview_process_start == previous_process_cursor
		and terrain_session.preview_game_start == previous_game_cursor,
		"Make New Terrain advances both preview random states",
	)
	terrain_session.clear()
	_check(
		not terrain_session.matches(options),
		"Closing New City clears its preview document",
	)
