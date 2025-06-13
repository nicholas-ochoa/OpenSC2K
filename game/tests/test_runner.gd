extends SceneTree

const RleCodec = preload("res://src/formats/maxis_rle.gd")
const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const ScenarioModel = preload("res://src/model/scenario_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const Clock = preload("res://src/simulation/simulation_clock.gd")
const Random = preload("res://src/simulation/sim_random.gd")
const Power = preload("res://src/simulation/power_phase.gd")
const Water = preload("res://src/simulation/water_phase.gd")
const Traffic = preload("res://src/simulation/traffic_phase.gd")
const Pollution = preload("res://src/simulation/pollution_phase.gd")
const Graphs = preload("res://src/simulation/graph_history.gd")
const Simulation = preload("res://src/simulation/simulation_engine.gd")
const Tools = preload("res://src/tools/tool_catalog.gd")
const Zones = preload("res://src/tools/zone_command.gd")

var failures := 0
var checks := 0


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var reference_root := ProjectSettings.globalize_path("res://../references")
	if not arguments.is_empty():
		reference_root = arguments[0]

	_test_rle()
	_test_invalid_rle()
	_test_palette_and_minimap(reference_root)
	_test_sprite_archives(reference_root)
	_test_reference_corpus(reference_root)
	_test_scenarios(reference_root)
	_test_simulation_clock()
	_test_random_and_power(reference_root)
	_test_water(reference_root)
	_test_traffic(reference_root)
	_test_pollution(reference_root)
	_test_graph_history(reference_root)
	_test_simulation_engine(reference_root)
	_test_modified_save(reference_root)
	_test_map_edits(reference_root)
	_test_tool_catalog()
	_test_zone_command(reference_root)

	if failures == 0:
		print("PASS: %d checks" % checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d checks failed" % [failures, checks])
		quit(1)


func _test_rle() -> void:
	var cases: Array[PackedByteArray] = [
		PackedByteArray(),
		PackedByteArray([1]),
		PackedByteArray([7, 7]),
		PackedByteArray([1, 2, 3, 4, 5]),
		_filled_bytes(128, 0xaa),
		_filled_bytes(300, 0x00),
	]
	for original in cases:
		var encoded := RleCodec.encode(original)
		var result := RleCodec.decode(encoded, original.size())
		_check(result.ok, "RLE round trip decodes")
		if result.ok:
			_check(result.data == original, "RLE round trip preserves bytes")


func _test_invalid_rle() -> void:
	_check(not RleCodec.decode(PackedByteArray([0x80])).ok, "RLE rejects 0x80")
	_check(not RleCodec.decode(PackedByteArray([2, 1])).ok, "RLE rejects short literal")
	_check(not RleCodec.decode(PackedByteArray([0x81])).ok, "RLE rejects short run")
	_check(
		not RleCodec.decode(PackedByteArray([0x82, 4]), 2).ok,
		"RLE rejects output overflow"
	)


func _test_reference_corpus(reference_root: String) -> void:
	var paths := PackedStringArray([reference_root.path_join("DEFAULT.SC2")])
	paths.append_array(_files_with_extension(reference_root.path_join("CITIES"), "SC2"))
	paths.append_array(_files_with_extension(reference_root.path_join("SCENARIO"), "SCN"))
	_check(paths.size() >= 80, "Reference corpus contains at least 80 city and scenario files")

	for path in paths:
		var document := Sc2Document.load_path(path)
		_check(document.is_valid(), "%s parses: %s" % [path.get_file(), document.parse_error])
		if not document.is_valid():
			continue

		var rebuilt := document.serialize(true)
		_check(rebuilt.ok, "%s rebuilds" % path.get_file())
		if rebuilt.ok:
			_check(
				rebuilt.data == FileAccess.get_file_as_bytes(path),
				"%s rebuild is byte-identical" % path.get_file()
			)

		var city := CityModel.from_document(document)
		_check(city.is_valid(), "%s creates a city model: %s" % [path.get_file(), city.load_error])
		if city.is_valid():
			_check(city.index_of(0, 0) == 0, "%s map origin is stable" % path.get_file())
			_check(
				city.index_of(127, 127) == 16383,
				"%s map end is stable" % path.get_file()
			)
			_check(
				city.current_month() >= 1 and city.current_month() <= 12,
				"%s month is in range" % path.get_file()
			)
			_check(city.label(0).length() <= 23, "%s mayor label is bounded" % path.get_file())
			_check(city.microsim(149).size() == 5, "%s has 150 microsim records" % path.get_file())
			_check(city.thing(39).size() == 12, "%s has 40 thing records" % path.get_file())
			var graph := city.graph_series(15)
			_check(graph.year.size() == 12, "%s graph has 12 monthly values" % path.get_file())
			_check(graph.decade.size() == 20, "%s graph has 20 decade values" % path.get_file())
			_check(graph.century.size() == 20, "%s graph has 20 century values" % path.get_file())

		for chunk in document.chunks:
			if not chunk.is_compressed:
				continue
			var reencoded := RleCodec.encode(chunk.decoded_payload)
			var decoded := RleCodec.decode(reencoded, chunk.expected_decoded_size)
			_check(decoded.ok, "%s %s re-encodes" % [path.get_file(), chunk.chunk_id])
			if decoded.ok:
				_check(
					decoded.data == chunk.decoded_payload,
					"%s %s re-encode preserves bytes" % [path.get_file(), chunk.chunk_id]
				)

	var default_city := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(default_city.is_valid(), "Default city parses")
	if default_city.is_valid():
		_check(default_city.city_name() == "New City", "Default city name is New City")
		_check(default_city.misc_u32(0) == 0x122, "Default MISC marker is 0x122")
		var default_model := CityModel.from_document(default_city)
		_check(default_model.land_altitude(0, 0) == 4, "Default origin land altitude is 4")
		_check(default_model.water_altitude(0, 0) == 4, "Default origin water level is 4")
		_check(default_model.tunnel_levels(0, 0) == 0, "Default origin tunnel depth is 0")


func _test_palette_and_minimap(reference_root: String) -> void:
	var loaded_palette := Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MSTR.BMP"))
	_check(loaded_palette.is_valid(), "Master Windows palette loads")
	if not loaded_palette.is_valid():
		return

	var document := Sc2Document.load_path(reference_root.path_join("CITIES/STARTER.SC2"))
	var loaded_city := CityModel.from_document(document)
	_check(loaded_city.is_valid(), "Starter city loads for minimap test")
	if not loaded_city.is_valid():
		return
	for mode in ["structures", "zones", "power", "water"]:
		var image := Minimap.create_image(loaded_city, loaded_palette, mode)
		_check(image.get_width() == 128, "%s minimap width is 128" % mode)
		_check(image.get_height() == 128, "%s minimap height is 128" % mode)


func _test_sprite_archives(reference_root: String) -> void:
	var expected_counts := {
		"LARGE.DAT": 501,
		"SMALLMED.DAT": 904,
		"SPECIAL.DAT": 50,
	}
	for filename in expected_counts:
		var archive := SpriteArchive.load_path(reference_root.path_join("DATA").path_join(filename))
		_check(archive.is_valid(), "%s parses: %s" % [filename, archive.parse_error])
		if not archive.is_valid():
			continue
		_check(archive.entries.size() == expected_counts[filename], "%s entry count matches" % filename)
		for entry in archive.entries:
			var decoded := entry.decode_indices()
			_check(decoded.ok, "%s sprite %d decodes: %s" % [filename, entry.sprite_id, decoded.error])

	var palette := Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MSTR.BMP"))
	var large := SpriteArchive.load_path(reference_root.path_join("DATA/LARGE.DAT"))
	var terrain := large.find_sprite(1256)
	_check(terrain != null, "Large terrain sprite 1256 is present")
	if terrain != null:
		_check(terrain.width == 32 and terrain.height == 17, "Large terrain sprite is 32 by 17")
		var rendered := terrain.create_image(palette)
		_check(rendered.ok, "Large terrain sprite renders: %s" % rendered.error)
		if rendered.ok:
			_check(rendered.image.get_width() == 32, "Rendered terrain sprite width is 32")
			_check(rendered.image.get_height() == 17, "Rendered terrain sprite height is 17")

	var starter_document := Sc2Document.load_path(reference_root.path_join("CITIES/STARTER.SC2"))
	var starter := CityModel.from_document(starter_document)
	var asset_errors := IsometricRenderer.validate_assets(starter, large)
	_check(asset_errors.is_empty(), "Starter city has every required large sprite: %s" % asset_errors)
	_check(IsometricRenderer.terrain_sprite_id(0x00, false) == 1256, "Flat land uses sprite 1256")
	_check(IsometricRenderer.terrain_sprite_id(0x10, true) == 1270, "Submerged land uses sprite 1270")
	_check(IsometricRenderer.terrain_sprite_id(0x45, true) == 1290, "Last water tile uses sprite 1290")


func _test_simulation_clock() -> void:
	var clock := Clock.new(0)
	var phases: Array[Dictionary] = []
	for unused in 25:
		phases.append(clock.advance_day())
	_check(phases[0].month_day == 1, "First simulation tick advances to day 1")
	_check(phases[0].actions == PackedStringArray(["power"]), "Day 1 schedules power")
	for month_day in range(3, 19):
		var phase := phases[month_day - 1]
		_check(phase.actions == PackedStringArray(["growth"]), "Day %d schedules growth" % month_day)
		_check(
			phase.growth_step == int((month_day - 3) / 4) % 4,
			"Day %d has the correct growth step" % month_day
		)
		_check(
			phase.growth_substep == (month_day + 1) % 4,
			"Day %d has the correct growth substep" % month_day
		)
	_check(phases[18].actions == PackedStringArray(["traffic"]), "Day 19 schedules traffic")
	_check(phases[19].actions == PackedStringArray(["water"]), "Day 20 schedules water")
	_check(phases[24].month_day == 0, "The 25th tick starts the next month")
	_check(
		phases[24].actions == PackedStringArray(["month_start", "budget"]),
		"Month start schedules budget work"
	)


func _test_scenarios(reference_root: String) -> void:
	var paths := _files_with_extension(reference_root.path_join("SCENARIO"), "SCN")
	_check(paths.size() == 18, "Supplied scenario count is 18")
	var legacy_count := 0
	var extended_count := 0
	for path in paths:
		var document := Sc2Document.load_path(path)
		var scenario := ScenarioModel.from_document(document)
		_check(scenario.is_valid(), "%s scenario model loads: %s" % [path.get_file(), scenario.load_error])
		if not scenario.is_valid():
			continue
		if scenario.format_size == ScenarioModel.LEGACY_SIZE:
			legacy_count += 1
		else:
			extended_count += 1
		_check(scenario.time_limit_months > 0, "%s has a positive time limit" % path.get_file())
		_check(not scenario.selection_description().is_empty(), "%s has selection text" % path.get_file())
		_check(not scenario.opening_description().is_empty(), "%s has opening text" % path.get_file())
		var picture := scenario.picture_indices()
		_check(picture.ok, "%s picture parses: %s" % [path.get_file(), picture.error])
		if picture.ok:
			_check(picture.width == 65, "%s picture width is 65" % path.get_file())
			_check(picture.height == 65 or picture.height == 66, "%s picture height is 65 or 66" % path.get_file())
			_check(
				picture.pixels.size() == picture.width * picture.height,
				"%s picture has the declared pixel count" % path.get_file()
			)
	_check(legacy_count == 15, "Fifteen supplied scenarios use the 52-byte SCEN layout")
	_check(extended_count == 3, "Three supplied scenarios use the 56-byte SCEN layout")

	var city_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(city_document)
	var goals := ScenarioModel.new()
	var all_disabled := goals.evaluate_goals(city)
	_check(all_disabled.ok and all_disabled.met, "Zero scenario goals are met")
	goals.cash_goal = all_disabled.values.cash_after_bonds + 1
	var cash_failure := goals.evaluate_goals(city)
	_check(not cash_failure.met, "Cash goal detects an insufficient city balance")
	_check(cash_failure.unmet == PackedStringArray(["cash"]), "Cash goal reports its exact failure")
	goals.cash_goal = 0
	goals.pollution_limit = maxi(city_document.misc_u32(0x34) - 1, 1)
	if city_document.misc_u32(0x34) > goals.pollution_limit:
		_check(
			goals.evaluate_goals(city).unmet.has("pollution"),
			"Pollution upper limit detects an excess"
		)


func _test_random_and_power(reference_root: String) -> void:
	var random := Random.new(1)
	var sequence := PackedInt32Array()
	for unused in 5:
		sequence.append(random.next_u15())
	_check(
		sequence == PackedInt32Array([41, 18467, 6334, 26500, 19169]),
		"Simulation random sequence matches the executable runtime"
	)

	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_building_id(10, 10, 0xc6), "Power test places a hydro plant")
	_check(city.set_building_id(10, 11, 0x0e), "Power test places a power line")
	_check(city.set_building_id(10, 12, 0x70), "Power test places a consumer")
	_check(city.set_building_id(20, 20, 0x70), "Power test places a disconnected consumer")
	for point in [Vector2i(10, 10), Vector2i(10, 11), Vector2i(10, 12), Vector2i(20, 20)]:
		_check(city.set_tile_flag(point.x, point.y, 0x80, true), "Power test tile is powerable")
	var result := Power.run(city, Random.new(1))
	_check(result.ok, "Power phase completes: %s" % result.error)
	if result.ok:
		_check(result.generation == 40, "Hydro plant generates 40 power units")
		_check(result.consumers == 1, "Connected component has one consumer")
		_check(result.supplied_consumers == 1, "Connected consumer receives power")
		_check(result.usage_percent == 2, "Power usage percentage uses integer division")
		_check(city.is_powered(10, 10), "Power source is marked powered")
		_check(city.is_powered(10, 11), "Power line is marked powered")
		_check(city.is_powered(10, 12), "Connected consumer is marked powered")
		_check(not city.is_powered(20, 20), "Disconnected consumer is not powered")


func _test_water(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_building_id(30, 30, 0xdc), "Water test places a pump")
	_check(city.set_building_id(30, 31, 0x00), "Water test clears a pipe tile")
	_check(city.set_building_id(30, 32, 0x70), "Water test places a consumer")
	_check(city.set_building_id(40, 40, 0x70), "Water test places a disconnected consumer")
	for point in [Vector2i(30, 30), Vector2i(30, 31), Vector2i(30, 32), Vector2i(40, 40)]:
		_check(city.set_tile_flag(point.x, point.y, 0x20, true), "Water test tile is piped")
	_check(city.set_tile_flag(30, 30, 0x40, true), "Water pump is powered")
	_check(city.set_tile_flag(29, 30, 0x04, true), "Fresh water is next to the pump")
	_check(city.set_tile_flag(29, 30, 0x01, false), "Pump water is not salt water")
	var expected_supply := int((document.misc_u32(0x68) & 0xff) / 2) + (
		document.misc_u32(0x0e40) * 5
	) + 10
	var result := Water.run(city)
	_check(result.ok, "Water phase completes: %s" % result.error)
	if result.ok:
		_check(result.supply == expected_supply, "Pump supply uses rain, water level, and fresh water")
		_check(result.consumers == 1, "Water component has one consumer")
		_check(result.watered_consumers == 1, "Connected consumer receives water")
		_check(city.is_watered(30, 30), "Powered pump is marked watered")
		_check(city.is_watered(30, 31), "Connected pipe is marked watered")
		_check(city.is_watered(30, 32), "Connected consumer is marked watered")
		_check(not city.is_watered(40, 40), "Disconnected consumer is not watered")


func _test_simulation_engine(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_age_in_days(0), "Simulation engine test resets the city day")
	var engine := Simulation.new(city, 1)
	var day_one := engine.advance_day()
	_check(day_one.ok, "Simulation engine advances day one")
	_check(day_one.day == 1 and city.age_in_days() == 1, "Simulation engine stores the new day")
	_check(day_one.applied == PackedStringArray(["power"]), "Simulation engine applies power on day one")
	_check(day_one.pending.is_empty(), "Day one has no unimplemented scheduled phase")
	var day_two := engine.advance_day()
	_check(day_two.ok, "Simulation engine advances day two")
	_check(
		day_two.applied == PackedStringArray(["pollution_terrain_land_value"]),
		"Simulation engine applies the combined day-two scan"
	)
	_check(day_two.pending.is_empty(), "Day two has no unimplemented scheduled phase")
	_check(engine.developed_tiles >= 0, "Simulation engine retains the developed-tile count")
	var latest := day_two
	while latest.day < 19:
		latest = engine.advance_day()
	_check(latest.applied == PackedStringArray(["traffic"]), "Simulation engine applies traffic on day 19")
	_check(latest.pending.is_empty(), "Day 19 has no unimplemented scheduled phase")
	latest = engine.advance_day()
	_check(latest.applied == PackedStringArray(["water"]), "Simulation engine applies water on day 20")
	_check(latest.pending.is_empty(), "Day 20 has no unimplemented scheduled phase")


func _test_traffic(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("CITIES/STARTER.SC2"))
	var city := CityModel.from_document(document)
	var original := document.find_chunk("XTRF").decoded_payload.duplicate()
	var expected_total := 0
	for value in original:
		expected_total += int(value) - (int(value) >> 2)
	var result := Traffic.run(city)
	_check(result.ok, "Traffic phase completes: %s" % result.error)
	if not result.ok:
		return
	_check(result.traffic_count == expected_total, "Traffic phase returns the decayed total")
	_check(document.misc_u32(0x30) == expected_total, "Traffic phase stores the city traffic count")
	var changed := document.find_chunk("XTRF").decoded_payload
	for index in original.size():
		_check(
			changed[index] == int(original[index]) - (int(original[index]) >> 2),
			"Traffic value %d decays by one quarter" % index
		)


func _test_pollution(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var buildings := PackedByteArray()
	buildings.resize(CityModel.TILE_COUNT)
	buildings[20 * CityModel.MAP_SIZE + 20] = 0xc9
	buildings[20 * CityModel.MAP_SIZE + 21] = 0xcb
	buildings[21 * CityModel.MAP_SIZE + 20] = 0x05
	_check(document.find_chunk("XBLD").set_decoded_payload(buildings), "Pollution test installs buildings")
	var traffic := PackedByteArray()
	traffic.resize(64 * 64)
	traffic[10 * 64 + 10] = 100
	_check(document.find_chunk("XTRF").set_decoded_payload(traffic), "Pollution test installs traffic")
	var previous := PackedByteArray()
	previous.resize(64 * 64)
	previous[10 * 64 + 10] = 20
	_check(document.find_chunk("XPLT").set_decoded_payload(previous), "Pollution test installs old pollution")
	_check(document.set_misc_u32(0x0fa0, 0), "Pollution test clears ordinances")
	_check(document.set_misc_u32(0x1034, 0), "Pollution test clears the pollution bonus")
	_check(document.set_misc_u32(0x1050, 0), "Pollution test clears the sewer bonus")
	var city := CityModel.from_document(document)
	var result := Pollution.run(city)
	_check(result.ok, "Pollution map phase completes: %s" % result.error)
	if not result.ok:
		return
	var pollution := document.find_chunk("XPLT").decoded_payload
	_check(pollution[10 * 64 + 10] == 63, "Pollution source uses traffic, history, and tile weights")
	for point in [Vector2i(9, 10), Vector2i(11, 10), Vector2i(10, 9), Vector2i(10, 11)]:
		_check(pollution[point.x * 64 + point.y] == 31, "Pollution spreads to a direct neighbor")
	var nonzero_count := 0
	for value in pollution:
		if value != 0:
			nonzero_count += 1
	_check(nonzero_count == 5, "Pollution smoothing changes only the source and direct neighbors")
	_check(result.pollution_total == 187, "Pollution phase returns the smoothed total")
	_check(document.misc_u32(0x34) == 187, "Pollution phase stores the city pollution total")

	var clean_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XBIT"]:
		_check(
			clean_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Combined scan test clears %s" % chunk_id
		)
	for chunk_id in ["XTRF", "XPLT", "XVAL", "XCRM"]:
		_check(
			clean_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(64 * 64, 0)),
			"Combined scan test clears %s" % chunk_id
		)
	for chunk_id in ["XPLC", "XFIR", "XPOP", "XROG"]:
		_check(
			clean_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(32 * 32, 0)),
			"Combined scan test clears %s" % chunk_id
		)
	var clean_buildings := clean_document.find_chunk("XBLD").decoded_payload.duplicate()
	clean_buildings[40 * 128 + 40] = 0x1d
	_check(
		clean_document.find_chunk("XBLD").set_decoded_payload(clean_buildings),
		"Combined scan test places one road tile"
	)
	for offset in [0x0fa0, 0x1034, 0x103c, 0x1050]:
		_check(clean_document.set_misc_u32(offset, 0), "Combined scan test clears MISC 0x%x" % offset)
	var clean_city := CityModel.from_document(clean_document)
	var clean_result := Pollution.run(clean_city)
	_check(clean_result.ok, "Combined day-two scan completes: %s" % clean_result.error)
	if not clean_result.ok:
		return
	_check(clean_result.developed_tiles == 1, "Combined scan counts one developed tile")
	_check(clean_result.city_center == Vector2i.ZERO, "Roads do not enter the city-center average")
	_check(clean_result.pollution_total == 0, "Clean road fixture has no pollution")
	_check(clean_result.land_value_total == 96, "Land-value scan stores the exact fixture total")
	_check(
		clean_document.find_chunk("XVAL").decoded_payload[20 * 64 + 20] == 96,
		"Land-value scan uses quarter-map smoothing and center distance"
	)
	_check(clean_city.tile_flags[20 * 128 + 20] & 0x08, "Developed area sets the temporary mark")
	_check(clean_document.find_chunk("XPOP").decoded_payload[10 * 32 + 10] == 0, "Road adds no population")
	_check(clean_document.find_chunk("XROG").decoded_payload[10 * 32 + 10] == 16, "Growth map uses the recovered bias")
	_check(clean_result.crime_total == 0, "Negative crime pressure clamps to zero")
	_check(clean_document.misc_u32(0x28) == 96, "Combined scan stores the land-value total")
	_check(clean_document.misc_u32(0x2c) == 0, "Combined scan stores the crime total")


func _test_graph_history(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var data := PackedByteArray()
	data.resize(CityModel.GRAPH_COUNT * CityModel.GRAPH_VALUE_COUNT * 4)
	for series in CityModel.GRAPH_COUNT:
		for index in CityModel.GRAPH_VALUE_COUNT:
			_write_u32_be(data, (series * CityModel.GRAPH_VALUE_COUNT + index) * 4, series * 1000 + index)
	_check(document.find_chunk("XGRP").set_decoded_payload(data), "Graph test installs known history")
	_check(city.set_age_in_days(150), "Graph test selects July")
	for index in 8:
		_check(
			document.set_misc_u32(0x05f0 + index * 4, [0, 10, 20, 5, 7, 3, 4, 9][index]),
			"Graph test installs zone population %d" % index
		)
	for tile_id in range(0xfb, 0xff):
		_check(
			document.set_misc_u32(0x01f0 + tile_id * 4, 600),
			"Graph test installs arcology tile count %d" % tile_id
		)
	for setting in [
		[0x1020, 1000],
		[0x0030, 1000],
		[0x0bb4, 9],
		[0x0c20, 10],
		[0x0c8c, 5],
		[0x0048, 78],
		[0x004c, 91],
		[0x0050, 54321],
		[0x0054, 98765],
		[0x0058, 8],
	]:
		_check(
			document.set_misc_u32(setting[0], setting[1]),
			"Graph test installs MISC value 0x%x" % setting[0]
		)
	var developed_tiles := 400
	var developed_divisor := int(developed_tiles / 4) + 1
	_check(document.set_misc_u32(0x0034, developed_divisor * 11), "Graph test installs pollution")
	_check(document.set_misc_u32(0x0028, developed_divisor * 22), "Graph test installs land value")
	_check(document.set_misc_u32(0x002c, developed_divisor * 33), "Graph test installs crime")
	var expected := PackedInt64Array(
		[
			201490,
			100800,
			50370,
			50320,
			40,
			11,
			22,
			33,
			77,
			55,
			78,
			91,
			15,
			98765,
			54321,
			8,
		]
	)
	var result := Graphs.run(city, developed_tiles, 23, 45)
	_check(result.ok, "Graph statistics and history advance: %s" % result.error)
	if not result.ok:
		return
	_check(result.values == expected, "Graph phase calculates all sixteen current values")
	_check(result.unemployment == 15, "Graph phase calculates unemployment")
	_check(document.misc_u32(0x0fa4) == 15, "Graph phase stores unemployment in MISC")
	for series in CityModel.GRAPH_COUNT:
		var values := city.graph_series(series)
		_check(values.year[0] == expected[series], "Graph %d stores its current month" % series)
		_check(values.year[1] == series * 1000, "Graph %d shifts monthly history" % series)
		_check(values.decade[0] == expected[series], "Graph %d stores its July half-year value" % series)
		_check(values.decade[1] == series * 1000 + 12, "Graph %d shifts half-year history" % series)
		_check(values.century[0] == series * 1000 + 32, "Graph %d leaves century history in July" % series)


func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff


func _test_modified_save(reference_root: String) -> void:
	var source_path := reference_root.path_join("DEFAULT.SC2")
	var document := Sc2Document.load_path(source_path)
	var loaded_city := CityModel.from_document(document)
	_check(loaded_city.set_age_in_days(311), "City age can change")
	_check(loaded_city.set_funds(-12345), "City funds can change")
	_check(loaded_city.set_label(0, "Test Mayor"), "Mayor label can change")
	var serialized := document.serialize()
	_check(serialized.ok, "Modified city serializes")
	if not serialized.ok:
		return
	_check(serialized.data != FileAccess.get_file_as_bytes(source_path), "Modified save bytes change")

	var reparsed := Sc2Document.new()
	_check(reparsed.parse(serialized.data), "Modified save parses again: %s" % reparsed.parse_error)
	if reparsed.is_valid():
		_check(reparsed.misc_u32(0x10) == 311, "Modified city age is preserved")
		_check(reparsed.misc_i32(0x14) == -12345, "Modified city funds are preserved")
		var reparsed_city := CityModel.from_document(reparsed)
		_check(reparsed_city.mayor_name() == "Test Mayor", "Modified mayor label is preserved")

	var original := Sc2Document.load_path(source_path)
	for original_chunk in original.chunks:
		if original_chunk.chunk_id == "MISC" or original_chunk.chunk_id == "XLAB":
			continue
		var modified_chunk := reparsed.find_chunk(original_chunk.chunk_id)
		_check(modified_chunk != null, "%s stays present after edit" % original_chunk.chunk_id)
		if modified_chunk != null:
			_check(
				modified_chunk.stored_payload == original_chunk.stored_payload,
				"%s stored bytes stay unchanged after MISC edit" % original_chunk.chunk_id
			)


func _test_map_edits(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_terrain_id(4, 5, 0x2a), "Terrain tile can change")
	_check(city.set_building_id(4, 5, 0x8a), "Building tile can change")
	_check(city.set_zone_id(4, 5, 0x05), "Zone can change")
	_check(city.set_building_corners(4, 5, 0xa0), "Building corners can change")
	_check(city.set_underground_id(4, 5, 0x22), "Underground tile can change")
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


func _test_tool_catalog() -> void:
	_check(Tools.GROUPS.size() == 18, "Tool catalog has all eighteen original groups")
	_check(Tools.all_tools().size() == 69, "Tool catalog has all sixty-nine original entries")
	var coal := Tools.tool(3, 2)
	_check(coal.name == "Coal Power Plant", "Tool catalog preserves the coal plant position")
	_check(coal.cost == 4000 and coal.area == 4, "Coal plant uses the executable cost and area")
	var road := Tools.tool(6, 0)
	_check(road.cost == 10 and road.area == 1, "Road uses the executable cost and area")
	var college := Tools.tool(12, 1)
	_check(college.cost == 1000 and college.area == 4, "College uses the executable cost and area")
	var prison := Tools.tool(13, 3)
	_check(prison.cost == 3000 and prison.area == 4, "Prison uses the executable cost and area")
	var marina := Tools.tool(14, 4)
	_check(marina.cost == 1000 and marina.area == 3, "Marina uses the executable cost and area")
	_check(Tools.tool(-1, 0).is_empty(), "Tool catalog rejects an invalid group")
	_check(Tools.tool(0, 12).is_empty(), "Tool catalog rejects an invalid subtool")


func _test_zone_command(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Zone command test clears %s" % chunk_id
		)
	var buildings := document.find_chunk("XBLD").decoded_payload.duplicate()
	buildings[11 * 128 + 11] = 0x1d
	_check(document.find_chunk("XBLD").set_decoded_payload(buildings), "Zone test places a road")
	var flags := document.find_chunk("XBIT").decoded_payload.duplicate()
	flags[12 * 128 + 12] = 0x04
	_check(document.find_chunk("XBIT").set_decoded_payload(flags), "Zone test places water")
	var zones := document.find_chunk("XZON").decoded_payload.duplicate()
	zones[10 * 128 + 10] = 0xa0
	zones[12 * 128 + 11] = 0x07
	_check(document.find_chunk("XZON").set_decoded_payload(zones), "Zone test installs corner and military bits")
	_check(document.set_misc_i32(0x14, 100), "Zone test sets city funds")
	var city := CityModel.from_document(document)
	var command := Zones.apply_rectangle(city, 9, 0, Vector2i(10, 10), Vector2i(12, 12))
	_check(command.ok, "Residential zone rectangle applies: %s" % command.error)
	if not command.ok:
		return
	_check(command.zone_type == 1, "Light residential maps to zone type one")
	_check(command.tile_indices.size() == 6, "Zone command skips road, water, and military tiles")
	_check(command.cost == 30 and city.funds() == 70, "Zone command charges per changed tile")
	_check(city.zones[10 * 128 + 10] == 0xa1, "Zone command preserves building-corner bits")
	_check(city.zone_id(11, 11) == 0, "Zone command leaves a road unchanged")
	_check(city.zone_id(12, 12) == 0, "Zone command leaves water unchanged")
	_check(city.zone_id(12, 11) == 7, "Zone command leaves a military zone unchanged")
	var undo := Zones.undo(city, command)
	_check(undo.ok and undo.restored_tiles == 6, "Zone command undo restores all changed tiles")
	_check(city.funds() == 100, "Zone command undo restores funds")
	_check(city.zones[10 * 128 + 10] == 0xa0, "Zone command undo restores original XZON bytes")
	var later := Zones.apply_rectangle(city, 11, 1, Vector2i(10, 10), Vector2i(12, 12))
	_check(later.ok, "Later zoning command succeeds")
	_check(later.cost == 60, "Later zoning command uses changed-tile cost")
	var stale := Zones.undo(city, command)
	_check(not stale.ok, "Undo rejects a command after later zone changes")


func _files_with_extension(directory: String, extension: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension().to_upper() == extension:
			paths.append(directory.path_join(filename))
	paths.sort()
	return paths


func _filled_bytes(size: int, value: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(size)
	result.fill(value)
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: %s" % message)
