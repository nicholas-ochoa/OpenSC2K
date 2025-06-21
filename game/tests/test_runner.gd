extends SceneTree

const RleCodec = preload("res://src/formats/maxis_rle.gd")
const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const ScenarioModel = preload("res://src/model/scenario_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const MapControl = preload("res://src/view/city_map_control.gd")
const Clock = preload("res://src/simulation/simulation_clock.gd")
const Random = preload("res://src/simulation/sim_random.gd")
const Power = preload("res://src/simulation/power_phase.gd")
const Water = preload("res://src/simulation/water_phase.gd")
const Traffic = preload("res://src/simulation/traffic_phase.gd")
const Pollution = preload("res://src/simulation/pollution_phase.gd")
const Graphs = preload("res://src/simulation/graph_history.gd")
const RciDemand = preload("res://src/simulation/rci_demand_phase.gd")
const Simulation = preload("res://src/simulation/simulation_engine.gd")
const Tools = preload("res://src/tools/tool_catalog.gd")
const Zones = preload("res://src/tools/zone_command.gd")
const Signs = preload("res://src/tools/sign_command.gd")
const Queries = preload("res://src/tools/query_info.gd")
const Landscapes = preload("res://src/tools/landscape_command.gd")
const Buildings = preload("res://src/tools/building_command.gd")
const GameRandom = preload("res://src/simulation/game_lcg_random.gd")
const Networks = preload("res://src/tools/network_command.gd")
const Hydro = preload("res://src/tools/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/onramp_command.gd")
const Tunnels = preload("res://src/tools/tunnel_command.gd")
const Highways = preload("res://src/tools/highway_command.gd")

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
	_test_rci_demand(reference_root)
	_test_simulation_engine(reference_root)
	_test_modified_save(reference_root)
	_test_map_edits(reference_root)
	_test_tool_catalog()
	_test_zone_command(reference_root)
	_test_sign_command(reference_root)
	_test_query_info(reference_root)
	_test_landscape_command(reference_root)
	_test_building_command(reference_root)
	_test_network_command(reference_root)
	_test_hydro_command(reference_root)
	_test_subway_to_rail_command(reference_root)
	_test_onramp_command(reference_root)
	_test_tunnel_command(reference_root)
	_test_highway_command(reference_root)

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
	_check(
		starter_document.find_chunk("ALTM").set_decoded_payload(_filled_bytes(128 * 128 * 2, 0)),
		"Isometric lookup fixture clears altitude",
	)
	_check(
		starter_document.find_chunk("XTER").set_decoded_payload(_filled_bytes(128 * 128, 0)),
		"Isometric lookup fixture clears terrain",
	)
	starter = CityModel.from_document(starter_document)
	for expected in [Vector2i.ZERO, Vector2i(24, 93), Vector2i(64, 64), Vector2i(127, 127)]:
		var polygon := IsometricRenderer.tile_polygon(starter, expected.x, expected.y)
		var center := (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
		_check(
			IsometricRenderer.screen_to_tile(starter, center) == expected,
			"Isometric screen lookup finds tile %s" % expected,
		)
	var map_control := MapControl.new()
	map_control.city = starter
	var center_tile := Vector2i(64, 64)
	var center_polygon := IsometricRenderer.tile_polygon(starter, center_tile.x, center_tile.y)
	var expected_center := (
		center_polygon[0] + center_polygon[1] + center_polygon[2] + center_polygon[3]
	) * 0.25
	_check(map_control.center_on_tile(center_tile), "Center tool accepts a city tile")
	_check(map_control.source_center == expected_center, "Center tool uses the altitude-aware tile center")
	_check(not map_control.center_on_tile(Vector2i(-1, 0)), "Center tool rejects an invalid tile")
	map_control.free()


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
	latest = engine.advance_day()
	_check(
		latest.applied == PackedStringArray(["rci_demand", "graphs"]),
		"Simulation engine applies demand and graphs on day 21",
	)
	_check(
		latest.pending == PackedStringArray(["education_health"]),
		"Day 21 reports only education and health as pending",
	)


func _test_rci_demand(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for index in 8:
		_check(document.set_misc_i32(0x05f0 + index * 4, 0), "RCI fixture clears zone population")
	for entry in [[1, 100], [2, 50], [3, 40], [4, 10], [5, 20], [6, 5]]:
		_check(
			document.set_misc_i32(0x05f0 + entry[0] * 4, entry[1]),
			"RCI fixture sets zone population %d" % entry[0],
		)
	for offset in [0x0718, 0x071c, 0x0720, 0x0fa0, 0x1030]:
		_check(document.set_misc_i32(offset, 0), "RCI fixture clears MISC 0x%x" % offset)
	for tile_id in [0xd5, 0xd7, 0xda, 0xdd, 0xde, 0xe0, 0xf8]:
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
	buildings[0] = 0x1d
	buildings[1] = 0x2c
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
	_check(city.set_building_id(10, 10, 3), "De-zone test places rubble")
	var dezone := Zones.apply_rectangle(city, 0, 4, Vector2i(10, 10), Vector2i(12, 12))
	_check(dezone.ok and dezone.cost == 6, "De-zone removes six zones for one dollar each")
	_check(city.zone_id(10, 10) == 0, "De-zone clears the zone nibble")
	_check(city.building_id(10, 10) == 0, "De-zone clears rubble tile IDs one through four")
	var undo_dezone := Zones.undo(city, dezone)
	_check(undo_dezone.ok, "De-zone command can be undone")
	_check(city.zone_id(10, 10) == 6, "De-zone undo restores the zone")
	_check(city.building_id(10, 10) == 3, "De-zone undo restores rubble")
	_check(city.set_funds(3), "Insufficient-funds fixture sets city funds")
	var zones_before_failure := city.zones.duplicate()
	var buildings_before_failure := city.buildings.duplicate()
	var rejected := Zones.apply_rectangle(city, 10, 0, Vector2i(10, 10), Vector2i(12, 12))
	_check(not rejected.ok and rejected.cost == 30, "Zone command reports insufficient funds")
	_check(city.funds() == 3, "Rejected zone command preserves funds")
	_check(
		city.zones == zones_before_failure and city.buildings == buildings_before_failure,
		"Rejected zone command preserves map data",
	)


func _test_sign_command(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(
		document.find_chunk("XTXT").set_decoded_payload(_filled_bytes(128 * 128, 0)),
		"Sign fixture clears text overlays",
	)
	var city := CityModel.from_document(document)
	_check(city.set_label(1, ""), "Sign fixture clears first user label")
	var created := Signs.set_sign(city, Vector2i(4, 5), "Harbor District")
	_check(created.ok, "Sign command creates a sign: %s" % created.error)
	_check(created.label_id == 1, "Sign command allocates the first free user label")
	_check(city.text_overlay_id(4, 5) == 1, "Sign command stores the XTXT label ID")
	_check(city.label(1) == "Harbor District", "Sign command stores XLAB text")
	var edited := Signs.set_sign(city, Vector2i(4, 5), "New Harbor")
	_check(edited.ok and edited.label_id == 1, "Sign command edits its existing label")
	_check(Signs.undo(city, edited).ok, "Sign edit can be undone")
	_check(city.label(1) == "Harbor District", "Sign undo restores the exact text")
	var removed := Signs.set_sign(city, Vector2i(4, 5), "")
	_check(removed.ok, "Empty sign text removes the sign")
	_check(city.text_overlay_id(4, 5) == 0 and city.label(1).is_empty(), "Sign removal clears XTXT and XLAB")
	_check(Signs.undo(city, removed).ok, "Sign removal can be undone")
	_check(city.text_overlay_id(4, 5) == 1 and city.label(1) == "Harbor District", "Sign removal undo restores both chunks")
	_check(city.set_text_overlay_id(9, 9, 51), "Sign fixture sets a protected label")
	var protected := Signs.set_sign(city, Vector2i(9, 9), "Blocked")
	_check(not protected.ok, "Sign command rejects a protected simulation label")


func _test_query_info(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XTXT", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Query fixture clears %s" % chunk_id,
		)
	var traffic := _filled_bytes(64 * 64, 0)
	traffic[4 * 64 + 5] = 8
	traffic[5 * 64 + 4] = 8
	traffic[5 * 64 + 5] = 8
	_check(document.find_chunk("XTRF").set_decoded_payload(traffic), "Query fixture sets traffic")
	for entry in [["XVAL", 9], ["XCRM", 61], ["XPLT", 181]]:
		var values := _filled_bytes(64 * 64, 0)
		values[5 * 64 + 5] = entry[1]
		_check(document.find_chunk(entry[0]).set_decoded_payload(values), "Query fixture sets %s" % entry[0])
	_check(document.set_misc_u32(0x0e40, 4), "Query fixture sets water level")
	var city := CityModel.from_document(document)
	_check(city.set_building_id(10, 10, 0x1d), "Query fixture places a road")
	_check(city.set_zone_id(10, 10, 1), "Query fixture zones the road")
	_check(city.set_land_altitude(10, 10, 6), "Query fixture sets altitude")
	_check(city.set_tile_flag(10, 10, 0x40, true), "Query fixture powers the road")
	var info := Queries.inspect(city, Vector2i(10, 10))
	_check(info.ok and info.kind == "general", "General query succeeds: %s" % info.error)
	_check(info.title == "Road", "General query classifies the tile")
	_check(info.zone_name == "Residential" and info.zone_density == "low-density", "Query reports zone type and density")
	_check(info.traffic == 4, "Query reproduces adjacent road traffic calculation")
	_check(info.altitude_feet == 250 and not info.altitude_is_depth, "Query reproduces clear-terrain altitude")
	_check(info.land_value == 10, "Query reports land value in thousands per acre")
	_check(info.crime_level == "Medium", "Query uses the recovered crime thresholds")
	_check(info.pollution_level == "Very High", "Query uses the recovered pollution thresholds")
	_check(info.shows_utilities and info.powered, "Query reports utility state")
	_check(Queries._level_name(1) == "None", "Query threshold one is None")
	_check(Queries._level_name(2) == "Low", "Query threshold two is Low")
	_check(Queries._level_name(60) == "Low", "Query threshold sixty is Low")
	_check(Queries._level_name(61) == "Medium", "Query threshold sixty-one is Medium")
	_check(Queries._level_name(120) == "Medium", "Query threshold one-twenty is Medium")
	_check(Queries._level_name(121) == "High", "Query threshold one-twenty-one is High")
	_check(Queries._level_name(180) == "High", "Query threshold one-eighty is High")
	_check(Queries._level_name(181) == "Very High", "Query threshold one-eighty-one is Very High")
	_check(document.set_misc_u32(0x68, 8), "Query pump fixture sets rain")
	_check(city.set_building_id(20, 20, 0xdc), "Query pump fixture places a pump")
	_check(city.set_tile_flag(20, 20, 0x40, true), "Query pump fixture powers the pump")
	_check(city.set_tile_flag(19, 20, 0x04, true), "Query pump fixture places fresh water")
	var pump := Queries.inspect(city, Vector2i(20, 20))
	_check(pump.title == "Water pump", "Query identifies a water pump")
	_check(pump.water_detail == "Water: 24480 gallons per month", "Query reports recovered pump output")
	for tower_tile in [Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 29), Vector2i(31, 29)]:
		_check(city.set_building_id(tower_tile.x, tower_tile.y, 0xeb), "Query tower fixture places a tower tile")
	for watered_tile in [Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 29)]:
		_check(city.set_tile_flag(watered_tile.x, watered_tile.y, 0x10, true), "Query tower fixture stores water")
	var tower := Queries.inspect(city, Vector2i(31, 29))
	_check(tower.title == "Water tower", "Query identifies a water tower")
	_check(tower.water_detail == "Water: 30000 stored gallons", "Query counts stored tower water")

	var microsim_data := document.find_chunk("XMIC").decoded_payload.duplicate()
	microsim_data[0] = 0xd0
	microsim_data[1] = 7
	microsim_data[2] = 0x01
	microsim_data[3] = 0x02
	microsim_data[4] = 0x03
	microsim_data[5] = 0x04
	microsim_data[6] = 0x05
	microsim_data[7] = 0x06
	_check(document.find_chunk("XMIC").set_decoded_payload(microsim_data), "Query fixture sets microsim data")
	_check(city.set_label(51, "Civic Center"), "Query fixture names a microsim")
	_check(city.set_text_overlay_id(10, 10, 51), "Query fixture attaches a microsim")
	var specific := Queries.inspect(city, Vector2i(10, 10))
	_check(specific.ok and specific.kind == "specific", "Specific query follows XTXT to XMIC")
	_check(specific.title == "Civic Center" and specific.microsim.stat_0 == 7, "Specific query reports its label and rating")
	_check(specific.microsim.stat_1 == 0x0102, "Specific query reads big-endian statistic one")
	_check(specific.microsim.stat_2 == 0x0304, "Specific query reads big-endian statistic two")
	_check(specific.microsim.stat_3 == 0x0506, "Specific query reads big-endian statistic three")


func _test_landscape_command(reference_root: String) -> void:
	var tree_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
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

	var water_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XTXT", "XBIT"]:
		_check(
			water_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Water fixture clears %s" % chunk_id,
		)
	_check(water_document.set_misc_i32(0x14, 500), "Water fixture sets funds")
	_check(water_document.set_misc_u32(0x01f0, 16383), "Water fixture counts clear tiles")
	_check(water_document.set_misc_u32(0x01f0 + 6 * 4, 1), "Water fixture counts one tree")
	var water_city := CityModel.from_document(water_document)
	_check(water_city.set_building_id(10, 10, 6), "Water fixture places a tree")
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
	_check(not unaffordable_water.ok and unaffordable_water.error == "insufficient funds", "Water tool reports insufficient funds")


func _test_building_command(reference_root: String) -> void:
	_check(Buildings.tile_for_tool(3, 2) == 0xcf, "Building table maps coal power")
	_check(Buildings.tile_for_tool(14, 4) == 0xf8, "Building table maps the marina")
	_check(Buildings.supports_tool(13, 0), "Building command supports police stations")
	_check(not Buildings.supports_tool(3, 3), "Hydroelectric power remains a special tool")
	_check(Buildings.footprint(Vector2i(20, 20), 1) == Rect2i(20, 20, 1, 1), "One-tile footprint starts at the pointer")
	_check(Buildings.footprint(Vector2i(20, 20), 2) == Rect2i(20, 20, 2, 2), "Two-tile footprint starts at the pointer")
	_check(Buildings.footprint(Vector2i(20, 20), 4) == Rect2i(19, 19, 4, 4), "Four-tile footprint starts one tile before the pointer")

	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Building fixture clears %s" % chunk_id,
		)
	_check(document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Building fixture clears XLAB")
	_check(document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Building fixture clears XMIC")
	_check(document.set_misc_i32(0x14, 20000), "Building fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Building fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0xcf * 4, 0), "Building fixture clears coal count")
	_check(document.set_misc_u32(0x077c + 5 * 0x6c, 2), "Building fixture sets police count")
	var city := CityModel.from_document(document)
	var random := GameRandom.new(1)
	var process_random := Random.new(1)
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
	_check(city.label(61) == "Coal Power", "Coal plant gets the original default label")
	_check(city.microsim(10).tile_id == 0xcf and city.microsim(10).stat_1 == 200, "Coal plant initializes its XMIC capacity")
	_check(document.misc_u32(0x01f0) == 16368, "Coal plant decrements clear tile count")
	_check(document.misc_u32(0x01f0 + 0xcf * 4) == 16, "Coal plant increments its tile count")
	_check(Buildings.undo(city, coal, random, process_random).ok, "Coal plant placement can be undone")
	_check(city.funds() == 20000 and city.building_id(19, 19) == 0, "Building undo restores funds and tiles")
	_check(city.text_overlay_id(19, 19) == 0 and city.microsim(10).tile_id == 0, "Building undo restores XTXT and XMIC")

	var police := Buildings.apply(city, 13, 0, Vector2i(30, 30), random, process_random)
	_check(police.ok, "Police station placement succeeds")
	_check(document.misc_u32(0x077c + 5 * 0x6c) == 3, "Police station increments the current budget count")
	_check(Buildings.undo(city, police, random, process_random).ok, "Police station placement can be undone")
	var park := Buildings.apply(city, 14, 0, Vector2i(40, 40), random, process_random)
	_check(park.ok, "Small park placement succeeds")
	_check(city.tile_flags[40 * 128 + 40] & 0xe0 == 0x20, "Small park gets only the piped structure flag")
	_check(city.building_corners(40, 40) == 0xf0, "One-tile building gets all corner bits")
	_check(Buildings.undo(city, park, random, process_random).ok, "Small park placement can be undone")
	var first_bus := Buildings.apply(city, 6, 4, Vector2i(70, 70), random, process_random)
	var second_bus := Buildings.apply(city, 6, 4, Vector2i(73, 70), random, process_random)
	_check(first_bus.ok and second_bus.ok, "Bus depots use the shared placement command")
	_check(first_bus.overlay_id == 52 and second_bus.overlay_id == 52, "Bus depots share fixed microsim record one")
	_check(city.label(52) == "SimBus System", "Fixed bus microsim gets its default system label")
	_check(city.microsim(1).tile_id == 0xec and city.microsim(1).stat_1 == 2, "Fixed bus microsim aggregates two depots")
	_check(Buildings.undo(city, second_bus, random, process_random).ok, "Fixed microsim aggregation can be undone")
	_check(city.microsim(1).stat_1 == 1, "Fixed microsim undo restores the prior aggregate")
	var mayor_random_before := process_random.state
	var mayor_house := Buildings.apply(city, 5, 0, Vector2i(80, 80), random, process_random)
	_check(mayor_house.ok and mayor_house.overlay_id == 61, "Mayor house allocates a dynamic microsim")
	_check(city.label(61) == "Mayor's House", "Mayor house gets its default label")
	_check(city.microsim(10).stat_1 == city.current_year(), "Mayor house stores its construction year")
	_check(city.microsim(10).stat_2 >= 10 and city.microsim(10).stat_2 <= 39, "Mayor house initializes the recovered age statistic")
	_check(Buildings.undo(city, mayor_house, random, process_random).ok, "Mayor house placement can be undone")
	_check(process_random.state == mayor_random_before, "Building undo restores the process random state")

	_check(city.set_underground_id(59, 60, 0x1e), "Pump fixture places an adjacent isolated pipe")
	var pump := Buildings.apply(city, 4, 1, Vector2i(60, 60), random, process_random)
	_check(pump.ok, "Water pump placement succeeds")
	_check(city.underground_id(59, 60) == 0x11 and city.underground_id(60, 60) == 0x11, "Water pump reconnects its adjacent pipe")
	_check(city.is_piped(60, 60), "Water pump keeps the piped flag")
	_check(Buildings.undo(city, pump, random, process_random).ok, "Water pump underground changes can be undone")
	_check(city.underground_id(59, 60) == 0x1e and city.underground_id(60, 60) == 0, "Pump undo restores both underground tiles")

	_check(city.set_underground_id(64, 65, 0x0f), "Subway fixture places an adjacent isolated subway")
	var subway_station := Buildings.apply(city, 7, 3, Vector2i(65, 65), random, process_random)
	_check(subway_station.ok, "Subway station placement succeeds")
	_check(city.underground_id(65, 65) == 0x23, "Subway station writes the underground entrance")
	_check(city.underground_id(64, 65) == 0x02, "Subway station reconnects its adjacent subway")
	_check(not city.is_piped(65, 65) and city.is_powered(65, 65) and city.is_powerable(65, 65), "Subway station clears only the piped structure flag")
	_check(Buildings.undo(city, subway_station, random, process_random).ok, "Subway station underground changes can be undone")

	var statue := Buildings.apply(city, 5, 2, Vector2i(68, 68), random, process_random)
	_check(statue.ok, "Statue placement succeeds")
	_check(city.is_piped(68, 68) and city.is_powered(68, 68) and not city.is_powerable(68, 68), "Statue clears the powerable flag")
	_check(Buildings.undo(city, statue, random, process_random).ok, "Statue placement can be undone")

	var edge := Buildings.apply(city, 3, 2, Vector2i(1, 1), random, process_random)
	_check(not edge.ok and edge.error.contains("fit"), "Four-tile building rejects the inner map edge")
	_check(city.set_building_id(20, 20, 0x1d), "Blocked-site fixture places a road")
	var blocked := Buildings.apply(city, 3, 2, Vector2i(20, 20), random, process_random)
	_check(not blocked.ok and blocked.error.contains("protected"), "Building placement rejects a road")
	_check(city.set_building_id(20, 20, 0), "Blocked-site fixture removes the road")
	_check(city.set_zone_id(20, 20, 7), "Military fixture sets a military zone")
	var military := Buildings.apply(city, 3, 2, Vector2i(20, 20), random, process_random)
	_check(not military.ok and military.error.contains("military"), "Building placement rejects military zones")
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
	_check(not dry_marina.ok and dry_marina.error.contains("land and water"), "Marina rejects an all-dry site")

	_check(city.set_funds(3999), "Building funds fixture sets insufficient funds")
	var unaffordable := Buildings.apply(city, 3, 2, Vector2i(60, 60), random, process_random)
	_check(not unaffordable.ok and unaffordable.error == "insufficient funds", "Building command reports insufficient funds")


func _test_network_command(reference_root: String) -> void:
	_check(Networks.supports_tool(6, 0), "Network command supports roads")
	_check(Networks.supports_tool(7, 1), "Network command supports subways")
	_check(not Networks.supports_tool(6, 1), "Highways remain a separate network tool")
	_check(
		Networks.route(Vector2i(10, 10), Vector2i(13, 12))
		== [Vector2i(10, 10), Vector2i(11, 10), Vector2i(11, 11), Vector2i(12, 11), Vector2i(12, 12), Vector2i(13, 12)],
		"Network route follows the recovered dominant-axis rule",
	)

	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Network fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_i32(0x14, 10000), "Network fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Network fixture counts clear tiles")
	var city := CityModel.from_document(document)

	var road := Networks.apply(city, 6, 0, Vector2i(10, 10), Vector2i(14, 10))
	_check(road.ok and road.points.size() == 5, "Road drag builds five tiles")
	_check(road.cost == 50 and city.funds() == 9950, "Road drag charges ten dollars per route tile")
	for x in range(10, 15):
		_check(city.building_id(x, 10) == 0x1e, "Road drag stores a connected road shape")
	_check(Networks.undo(city, road).ok, "Road drag can be undone")
	_check(city.funds() == 10000 and city.building_id(12, 10) == 0, "Road undo restores funds and tiles")

	_check(city.set_building_id(20, 20, 0x1d), "Rail crossover fixture places a road")
	var rail_crossing := Networks.apply(city, 7, 0, Vector2i(20, 20), Vector2i(21, 20))
	_check(rail_crossing.ok and city.building_id(20, 20) == 0x45, "Rail tool creates the recovered road crossover")
	_check(Networks.undo(city, rail_crossing).ok, "Rail crossover can be undone")

	var pipes := Networks.apply(city, 4, 0, Vector2i(10, 30), Vector2i(12, 30))
	_check(pipes.ok and pipes.cost == 9, "Pipe drag charges three dollars per tile")
	for x in range(10, 13):
		_check(city.underground_id(x, 30) == 0x11, "Pipe drag stores connected pipe shapes")
		_check(city.is_piped(x, 30), "Pipe drag sets the piped flag")
	_check(Networks.undo(city, pipes).ok, "Pipe drag can be undone")

	var subway := Networks.apply(city, 7, 1, Vector2i(30, 30), Vector2i(30, 32))
	_check(subway.ok and subway.cost == 300, "Subway drag charges one hundred dollars per tile")
	for y in range(30, 33):
		_check(city.underground_id(30, y) == 0x01, "Subway drag stores connected subway shapes")
	_check(Networks.undo(city, subway).ok, "Subway drag can be undone")

	_check(city.set_building_id(42, 40, 0x51), "Partial-route fixture places an obstruction")
	var partial := Networks.apply(city, 6, 0, Vector2i(40, 40), Vector2i(44, 40))
	_check(partial.ok and partial.stopped_early, "Road route stops at an obstruction")
	_check(partial.points == [Vector2i(40, 40), Vector2i(41, 40)], "Road route keeps the clear prefix")
	_check(partial.cost == 20, "Partial road route charges only its planned prefix")
	_check(Networks.undo(city, partial).ok, "Partial road route can be undone")

	_check(city.set_funds(1), "Network funds fixture sets insufficient funds")
	var unaffordable := Networks.apply(city, 3, 0, Vector2i(50, 50), Vector2i(51, 50))
	_check(not unaffordable.ok and unaffordable.error == "insufficient funds", "Network command reports insufficient funds")


func _test_hydro_command(reference_root: String) -> void:
	_check(Hydro.supports_tool(3, 3), "Hydroelectric command supports the hydro tool")
	_check(not Hydro.supports_tool(3, 2), "Hydroelectric command rejects coal power")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
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
	var city := CityModel.from_document(document)
	_check(city.set_terrain_id(20, 20, 0x2e), "Hydroelectric fixture places a waterfall")
	_check(city.set_land_altitude(20, 20, 5), "Hydroelectric fixture sets waterfall altitude")
	_check(city.set_land_altitude(20, 19, 6), "Hydroelectric fixture sets a higher north tile")
	var process_random := Random.new(33)
	var command := Hydro.apply(city, 3, 3, Vector2i(20, 20), process_random)
	_check(command.ok, "Hydroelectric placement succeeds: %s" % command.error)
	_check(command.tile_id == 0xc7 and city.building_id(20, 20) == 0xc7, "Hydroelectric tile follows the recovered slope orientation")
	_check(city.funds() == 600 and city.is_powerable(20, 20), "Hydroelectric placement charges cost and sets powerable")
	_check(city.zones[20 * 128 + 20] == 0xf0, "Hydroelectric placement sets all corner bits")
	_check(command.overlay_id == 56 and city.label(56) == "Hydro Power", "Hydroelectric placement uses fixed XMIC record five")
	_check(city.microsim(5).stat_1 == 1 and city.microsim(5).stat_2 == 20, "Hydroelectric placement increments fixed XMIC totals")
	_check(Hydro.undo(city, command, process_random).ok, "Hydroelectric placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.funds() == 1000, "Hydroelectric undo restores the tile and funds")
	var wrong_terrain := Hydro.apply(city, 3, 3, Vector2i(21, 21), process_random)
	_check(not wrong_terrain.ok and wrong_terrain.error.contains("waterfall"), "Hydroelectric placement requires waterfall terrain")


func _test_subway_to_rail_command(reference_root: String) -> void:
	_check(SubwayToRail.supports_tool(7, 4), "Subway-to-rail command supports its catalog tool")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Subway-to-rail fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_i32(0x14, 0), "Subway-to-rail fixture clears funds")
	_check(document.set_misc_u32(0x01f0, 16383), "Subway-to-rail fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0x2c * 4, 1), "Subway-to-rail fixture counts rail")
	var city := CityModel.from_document(document)
	_check(city.set_building_id(21, 20, 0x2c), "Subway-to-rail fixture places adjacent rail")
	_check(city.set_zone_id(20, 20, 3), "Subway-to-rail fixture places a commercial zone")
	var surface := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(surface.ok, "Subway-to-rail placement beside surface rail succeeds: %s" % surface.error)
	_check(surface.tile_id == 0x6c and city.building_id(20, 20) == 0x6c, "East rail selects connector orientation zero")
	_check(city.underground_id(20, 20) == 0x23, "Subway-to-rail placement writes underground entrance 0x23")
	_check(city.zones[20 * 128 + 20] == 0xf3, "Subway-to-rail placement preserves the zone and sets all corners")
	_check(city.funds() == 0 and surface.cost == 0 and surface.listed_cost == 250, "Subway-to-rail reproduces the executable's missing cost deduction")
	_check(SubwayToRail.undo(city, surface).ok, "Subway-to-rail placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.underground_id(20, 20) == 0, "Subway-to-rail undo restores surface and underground maps")

	_check(city.set_building_id(21, 20, 0), "Underground connection fixture removes surface rail")
	_check(city.set_underground_id(21, 20, 0x01), "Underground connection fixture places adjacent subway")
	var underground := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(underground.ok and underground.tile_id == 0x6e, "East subway selects the opposite connector orientation")
	_check(SubwayToRail.undo(city, underground).ok, "Underground-oriented connector can be undone")
	_check(city.set_underground_id(21, 20, 0), "Missing-neighbor fixture removes adjacent subway")
	var no_neighbor := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(not no_neighbor.ok and no_neighbor.error.contains("adjacent"), "Subway-to-rail placement requires an adjacent network")


func _test_onramp_command(reference_root: String) -> void:
	_check(Onramps.supports_tool(6, 3), "On-ramp command supports its catalog tool")
	_check(not Onramps.supports_tool(6, 1), "On-ramp command rejects the highway tool")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
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
	_check(city.set_building_id(21, 20, 0x49), "On-ramp fixture places east highway")
	_check(city.set_building_id(20, 19, 0x1d), "On-ramp fixture places north road")
	var north := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(north.ok, "North-road on-ramp succeeds: %s" % north.error)
	_check(north.tile_id == 0x5f and city.building_id(20, 20) == 0x5f, "East highway and north road select ramp 0x5f")
	_check(city.building_id(20, 19) == 0x2b, "On-ramp converts its adjacent road to tile 0x2b")
	_check((city.tile_flags[20 * 128 + 20] & 0x02) != 0, "North-road on-ramp sets the flipped flag")
	_check(city.funds() == 75 and north.cost == 25, "On-ramp charges the catalog cost")
	_check(Onramps.undo(city, north).ok, "On-ramp placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.building_id(20, 19) == 0x1d, "On-ramp undo restores both surface tiles")
	_check(city.funds() == 100, "On-ramp undo restores funds")

	_check(city.set_building_id(21, 20, 0), "Second on-ramp fixture removes east highway")
	_check(city.set_building_id(20, 19, 0), "Second on-ramp fixture removes north road")
	_check(city.set_building_id(20, 19, 0x49), "Second on-ramp fixture places north highway")
	_check(city.set_building_id(21, 20, 0x1d), "Second on-ramp fixture places east road")
	var east := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(east.ok and east.tile_id == 0x5d, "North highway and east road select ramp 0x5d")
	_check(Onramps.undo(city, east).ok, "East-road on-ramp can be undone")
	_check(city.set_building_id(20, 19, 0), "Invalid arrangement fixture removes north highway")
	_check(city.set_building_id(21, 20, 0), "Invalid arrangement fixture removes east road")
	_check(city.set_building_id(21, 20, 0x49), "Invalid arrangement fixture places east highway")
	_check(city.set_building_id(19, 20, 0x1d), "Invalid arrangement fixture places west road")
	var parallel := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(not parallel.ok and parallel.error.contains("perpendicular"), "On-ramp rejects a road parallel to the highway")
	_check(city.set_funds(24), "On-ramp funds fixture sets insufficient funds")
	_check(city.set_building_id(19, 20, 0), "On-ramp funds fixture removes west road")
	_check(city.set_building_id(20, 19, 0x1d), "On-ramp funds fixture places north road")
	var unaffordable := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(not unaffordable.ok and unaffordable.error == "insufficient funds", "On-ramp command reports insufficient funds")


func _test_tunnel_command(reference_root: String) -> void:
	_check(Tunnels.supports_tool(6, 2), "Tunnel command supports its catalog tool")
	_check(not Tunnels.supports_tool(6, 1), "Tunnel command rejects the highway tool")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT"]:
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
	_check(city.set_building_id(19, 20, 0x1d), "Tunnel fixture places an adjacent road")
	var command := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
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
	_check(not conflict.ok and conflict.error.contains("another tunnel"), "Tunnel rejects an existing ALTM tunnel path")
	_check(city.set_tunnel_levels(21, 20, 0), "Tunnel conflict fixture removes existing tunnel")
	_check(city.set_underground_id(21, 20, 0x10), "Tunnel conflict fixture places a pipe at depth two")
	var pipe_conflict := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not pipe_conflict.ok and pipe_conflict.error.contains("underground"), "Tunnel rejects a pipe at the matching depth")
	_check(city.set_underground_id(21, 20, 0), "Tunnel conflict fixture removes pipe")
	_check(city.set_terrain_id(22, 20, 2), "Tunnel exit fixture changes the opposite slope")
	var no_exit := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not no_exit.ok and no_exit.error.contains("opposite slope"), "Tunnel requires the recovered opposite exit slope")
	_check(city.set_terrain_id(22, 20, 1), "Tunnel funds fixture restores the exit slope")
	_check(city.set_funds(449), "Tunnel funds fixture sets insufficient funds")
	var unaffordable := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not unaffordable.ok and unaffordable.error == "insufficient funds", "Tunnel command reports insufficient funds")


func _test_highway_command(reference_root: String) -> void:
	_check(Highways.supports_tool(6, 1), "Highway command supports its catalog tool")
	_check(not Highways.supports_tool(6, 0), "Highway command rejects the road tool")
	_check(Highways.snap_anchor(Vector2i(11, 13)) == Vector2i(10, 12), "Highway pointer snaps to even coordinates")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
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
	_check(Highways.undo(city, straight).ok, "Straight highway can be undone")
	_check(city.funds() == 1000 and city.building_id(12, 10) == 0, "Highway undo restores funds and tiles")

	var turn := Highways.apply(city, 6, 1, Vector2i(10, 10), Vector2i(12, 12))
	_check(turn.ok and turn.sections == [Vector2i(10, 10), Vector2i(10, 12), Vector2i(12, 12)], "Highway route follows the recovered dominant-axis rule")
	_check(city.building_id(10, 10) == 0x49, "Highway turn starts with a vertical section")
	_check(city.building_id(10, 12) == 0x65, "North-east highway turn uses shaped tile 0x65")
	_check(city.building_id(12, 12) == 0x4a, "Highway turn ends with a horizontal section")
	_check((city.zones[10 * 128 + 12] & 0xf0) != 0xf0, "Shaped highway stores a 2-by-2 corner mask")
	_check(Highways.undo(city, turn).ok, "Turning highway can be undone")

	_check(city.set_building_id(10, 10, 0x1e), "Highway crossing fixture places a horizontal road")
	_check(document.set_misc_u32(0x01f0, 16383), "Highway crossing fixture updates clear count")
	_check(document.set_misc_u32(0x01f0 + 0x1e * 4, 1), "Highway crossing fixture counts road")
	var crossing_city := CityModel.from_document(document)
	var crossing := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(10, 12))
	_check(crossing.ok, "Highway can cross a perpendicular road: %s" % crossing.error)
	_check(crossing_city.building_id(10, 10) == 0x4b, "Vertical highway and horizontal road use crossover 0x4b")
	_check(Highways.undo(crossing_city, crossing).ok, "Highway crossover can be undone")
	_check(crossing_city.set_building_id(10, 10, 0), "Highway obstruction fixture removes road")
	_check(crossing_city.set_building_id(14, 10, 0xd0), "Highway obstruction fixture places a building")
	var partial := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(16, 10))
	_check(partial.ok and partial.stopped_early, "Highway route stops at an obstruction")
	_check(partial.sections == [Vector2i(10, 10), Vector2i(12, 10)], "Highway route keeps its clear prefix")
	_check(partial.cost == 200, "Partial highway charges only its clear sections")
	_check(Highways.undo(crossing_city, partial).ok, "Partial highway can be undone")
	_check(crossing_city.set_tile_flag(10, 10, 0x04, true), "Highway water fixture sets water")
	var water := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(10, 10))
	_check(not water.ok and water.error.contains("bridges"), "Highway reports its unimplemented bridge path")


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
