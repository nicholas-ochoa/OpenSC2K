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
const LfsrRandom = preload("res://src/simulation/sim_lfsr_random.gd")
const Power = preload("res://src/simulation/power_phase.gd")
const Water = preload("res://src/simulation/water_phase.gd")
const Traffic = preload("res://src/simulation/traffic_phase.gd")
const Pollution = preload("res://src/simulation/pollution_phase.gd")
const Graphs = preload("res://src/simulation/graph_history.gd")
const RciDemand = preload("res://src/simulation/rci_demand_phase.gd")
const EducationHealth = preload("res://src/simulation/education_health_phase.gd")
const MonthStart = preload("res://src/simulation/month_start_phase.gd")
const Transport = preload("res://src/simulation/transport_trip.gd")
const Growth = preload("res://src/simulation/growth_phase.gd")
const MovingThings = preload("res://src/simulation/moving_thing_spawner.gd")
const MovingThingTick = preload("res://src/simulation/moving_thing_phase.gd")
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
const Demolish = preload("res://src/tools/demolish_command.gd")
const TerrainTools = preload("res://src/tools/terrain_command.gd")
const Dispatch = preload("res://src/tools/dispatch_command.gd")

var failures := 0
var checks := 0


class ZeroRandom:
	extends RefCounted

	func next_u15() -> int:
		return 0


class ZeroLfsrRandom:
	extends RefCounted

	func next_mask(_mask: int) -> int:
		return 0

	func next_mod(_divisor: int) -> int:
		return 0


class NonzeroLfsrRandom:
	extends RefCounted

	func next_mask(_mask: int) -> int:
		return 1

	func next_mod(divisor: int) -> int:
		return 1 % divisor


class MicrosimLfsrRandom:
	extends RefCounted

	func next_mask(mask: int) -> int:
		return 0 if mask == 3 else 1

	func next_mod(_divisor: int) -> int:
		return 0


class SequenceLfsrRandom:
	extends RefCounted

	var values := PackedInt32Array()
	var position := 0

	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)

	func next_mask(mask: int) -> int:
		return _next() & mask

	func next_mod(divisor: int) -> int:
		return _next() % divisor

	func _next() -> int:
		if position >= values.size():
			return 1
		var value := int(values[position])
		position += 1
		return value


class SequenceRandom:
	extends RefCounted

	var values := PackedInt32Array()
	var position := 0

	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)

	func next_u15() -> int:
		if position >= values.size():
			return 1
		var value := int(values[position])
		position += 1
		return value


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
	_test_education_health(reference_root)
	_test_month_start(reference_root)
	_test_transport_trip(reference_root)
	_test_growth_phase(reference_root)
	_test_moving_thing_phase(reference_root)
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
	_test_demolish_command(reference_root)
	_test_terrain_command(reference_root)
	_test_dispatch_command(reference_root)

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
	var plane_visual := IsometricRenderer.moving_thing_sprite({
		"type": 1, "direction": 4, "state": 2,
	})
	_check(
		plane_visual.sprite_id == 1362 and plane_visual.flip,
		"Airplane view uses the recovered direction offset and mirror",
	)
	var ship_visual := IsometricRenderer.moving_thing_sprite({
		"type": 3, "direction": 7, "state": 0,
	})
	_check(
		ship_visual.sprite_id == 1369 and not ship_visual.flip,
		"Cargo-ship view uses the recovered north-west sprite",
	)
	var sail_visual := IsometricRenderer.moving_thing_sprite({
		"type": 9, "direction": 2, "state": 0,
	})
	_check(
		sail_visual.sprite_id == 1381 and sail_visual.flip,
		"Sailboat view uses the recovered cardinal offset and mirror",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 9, "direction": 2, "state": 1,
		}).sprite_id == 1379,
		"A distressed sailboat uses the Nessie sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 6, "direction": 2, "state": 0,
		}).sprite_id == 1389,
		"Explosion frame two uses the third recovered sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 10, "direction": 0, "state": 0,
		}).is_empty(),
		"The generic view defers trains to their custom renderer",
	)
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
	var lfsr := LfsrRandom.new(1)
	var lfsr_sequence := PackedInt32Array()
	for unused in 16:
		lfsr_sequence.append(lfsr.next_word())
	_check(
		lfsr_sequence == PackedInt32Array([
			2, 4, 8, 16, 32, 64, 128, 256,
			512, 1024, 2048, 4096, 8192, 16384, 32768, 7157,
		]),
		"Simulation LFSR sequence matches the executable",
	)
	_check(LfsrRandom.new(1).next_mask(0x03) == 2, "LFSR mask returns the low requested bits")

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
	var engine := Simulation.new(city, 1, 7)
	_check(engine.lfsr_random.state == 7, "Simulation engine accepts an explicit LFSR seed")
	var day_one := engine.advance_day()
	_check(day_one.ok, "Simulation engine advances day one")
	_check(day_one.day == 1 and city.age_in_days() == 1, "Simulation engine stores the new day")
	_check(day_one.applied == PackedStringArray(["power"]), "Simulation engine applies power on day one")
	_check(day_one.pending.is_empty(), "Day one has no unimplemented scheduled phase")
	_check(engine.lfsr_random.state == 7, "Non-growth phases preserve the LFSR state")
	var day_two := engine.advance_day()
	_check(day_two.ok, "Simulation engine advances day two")
	_check(
		day_two.applied == PackedStringArray(["pollution_terrain_land_value"]),
		"Simulation engine applies the combined day-two scan"
	)
	_check(day_two.pending.is_empty(), "Day two has no unimplemented scheduled phase")
	_check(engine.developed_tiles >= 0, "Simulation engine retains the developed-tile count")
	var day_three := engine.advance_day()
	_check(day_three.ok, "Simulation engine advances the first growth day")
	_check(day_three.phase_results.has("growth"), "Simulation engine runs the RCI growth core")
	_check(day_three.pending == PackedStringArray(["growth"]), "Incomplete non-RCI growth stays pending")
	_check(engine.lfsr_random.state != 7, "Growth continues the engine LFSR sequence")
	var latest := day_three
	while latest.day < 19:
		latest = engine.advance_day()
	_check(latest.applied == PackedStringArray(["traffic"]), "Simulation engine applies traffic on day 19")
	_check(latest.pending.is_empty(), "Day 19 has no unimplemented scheduled phase")
	latest = engine.advance_day()
	_check(latest.applied == PackedStringArray(["water"]), "Simulation engine applies water on day 20")
	_check(latest.pending.is_empty(), "Day 20 has no unimplemented scheduled phase")
	latest = engine.advance_day()
	_check(
		latest.applied == PackedStringArray(["rci_demand", "education_health", "graphs"]),
		"Simulation engine applies demand, demographics, and graphs on day 21",
	)
	_check(latest.pending.is_empty(), "Day 21 has no unimplemented scheduled phase")


func _test_month_start(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var original_values := PackedInt32Array()
	for index in 8:
		var value := (index + 1) * 13
		original_values.append(value)
		_check(
			document.set_misc_i32(0x05f0 + index * 4, value),
			"Month-start fixture sets zone population %d" % index,
		)
	_check(document.set_misc_i32(0x05ec, 0x12345678), "Month-start fixture sets preceding data")
	_check(document.set_misc_i32(0x0610, 0x23456789), "Month-start fixture sets following data")
	var city := CityModel.from_document(document)
	var result := MonthStart.run(city)
	_check(result.ok, "Month-start phase completes: %s" % result.error)
	_check(result.cleared_population_fields == 8, "Month-start phase reports eight cleared fields")
	for index in 8:
		_check(document.misc_i32(0x05f0 + index * 4) == 0, "Month-start clears zone population %d" % index)
	_check(document.misc_i32(0x05ec) == 0x12345678, "Month-start preserves preceding MISC data")
	_check(document.misc_i32(0x0610) == 0x23456789, "Month-start preserves following MISC data")


func _test_transport_trip(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XZON", "XUND", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Transport fixture clears %s" % chunk_id,
		)
	_check(
		document.find_chunk("XTRF").set_decoded_payload(_filled_bytes(64 * 64, 0)),
		"Transport fixture clears XTRF",
	)
	var city := CityModel.from_document(document)
	for point in [Vector2i(20, 21), Vector2i(20, 22), Vector2i(20, 23)]:
		_check(city.set_building_id(point.x, point.y, 0x1d), "Transport fixture places a road")
	_check(city.set_zone_id(20, 20, 1), "Transport fixture sets the origin zone")
	_check(city.set_zone_id(20, 24, 3), "Transport fixture sets a job destination")
	var result := Transport.run(city, Vector2i(20, 20), 1, 2, Random.new(1))
	_check(result.ok and result.reached_destination, "Road trip reaches a compatible zone")
	_check(result.path_length == 3, "Road trip records the three-tile path")
	var traffic := document.find_chunk("XTRF").decoded_payload
	_check(traffic[10 * 64 + 10] == 2, "Road trip adds traffic to its first coarse cell")
	_check(traffic[10 * 64 + 11] == 4, "Road trip accumulates two tiles in one coarse cell")

	_check(city.set_zone_id(20, 24, 1), "Transport fixture changes the destination to residential")
	var before_failed_trip: PackedByteArray = document.find_chunk("XTRF").decoded_payload.duplicate()
	var failed := Transport.run(city, Vector2i(20, 20), 1, 2, Random.new(1))
	_check(failed.ok and not failed.reached_destination, "Trip rejects an incompatible destination")
	_check(document.find_chunk("XTRF").decoded_payload == before_failed_trip, "Failed trip preserves XTRF")

	_check(city.set_building_id(1, 0, 0x1d), "Connection fixture places an edge road")
	_check(city.set_text_overlay_id(1, 0, 0xfa), "Connection fixture marks a city connection")
	var connection := Transport.run(city, Vector2i(1, 1), 5, 1, Random.new(7))
	_check(connection.ok and connection.reached_destination, "Trip can leave through a city connection")
	_check(
		document.find_chunk("XTRF").decoded_payload[0] == 1,
		"Connection trip adds its density to the edge traffic cell",
	)


func _test_growth_phase(reference_root: String) -> void:
	var normal := _growth_fixture(reference_root, 0xae, 1, 2000)
	var normal_result := Growth.run(normal.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(normal_result.ok, "Normal growth scan completes: %s" % normal_result.error)
	_check(normal_result.scanned_tiles == 1024, "Growth scan processes one sixteenth of the map")
	_check(normal_result.rci_tiles == 1, "Growth scan processes the controlled RCI anchor")
	_check(normal.document.misc_u32(0x05f4) == 36, "Density four adds 36 residential units")
	_check(normal_result.successful_trips == 1, "Developed zone completes its transport trip")
	_check(normal.city.building_id(20, 20) == 0xae, "Stable density-four zone keeps its building")

	var bare := _growth_fixture(reference_root, 0, 1, 2000)
	var bare_result := Growth.run(bare.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(bare_result.ok, "Bare-zone growth scan completes: %s" % bare_result.error)
	_check(bare_result.started_construction == 1, "Bare powered zone starts construction")
	_check(bare.city.building_id(20, 20) == 0x88, "Bare zone gets the first construction tile")
	_check(bare.city.building_corners(20, 20) == 0xf0, "One-tile construction sets all corner bits")
	_check(
		bare.city.tile_flags[20 * 128 + 20] & 0xe0 == 0xe0,
		"Construction sets utility flags",
	)

	var declining := _growth_fixture(reference_root, 0x70, 1, -2000)
	var decline_result := Growth.run(declining.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(decline_result.ok, "Declining-zone scan completes: %s" % decline_result.error)
	_check(decline_result.abandoned_buildings == 1, "Low demand abandons the controlled building")
	_check(declining.city.building_id(20, 20) == 0x8a, "Density-one zone uses an abandoned tile")
	_check(declining.document.misc_u32(0x05f4) == 1, "Population is counted before abandonment")

	var abandoned := _growth_fixture(reference_root, 0x8a, 1, 2000)
	var recovery_result := Growth.run(abandoned.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(recovery_result.ok, "Abandoned-zone scan completes: %s" % recovery_result.error)
	_check(recovery_result.recovered_buildings == 1, "High demand recovers an abandoned building")
	_check(abandoned.city.building_id(20, 20) == 0x70, "Recovered residence uses value group zero")
	_check(abandoned.document.misc_u32(0x060c) == 1, "Abandoned population is counted before recovery")

	var construction := _growth_fixture(reference_root, 0x88, 1, 2000)
	var construction_result := Growth.run(
		construction.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(construction_result.ok, "Construction completion scan completes: %s" % construction_result.error)
	_check(construction_result.completed_construction == 1, "Construction completes on the controlled roll")
	_check(construction.city.building_id(20, 20) == 0x70, "Residential construction becomes occupied")

	var church := _growth_fixture(reference_root, 0xa6, 1, 2000)
	for point in [Vector2i(20, 19), Vector2i(21, 19), Vector2i(21, 20)]:
		_check(church.city.set_building_id(point.x, point.y, 0xa6), "Church fixture fills construction footprint")
		_check(church.city.set_zone_id(point.x, point.y, 1), "Church fixture zones construction footprint")
	_check(church.document.set_misc_u32(0x01f0 + 0xa6 * 4, 4), "Church fixture counts construction tiles")
	_check(church.document.set_misc_u32(0x01f0 + 0xf7 * 4, 0), "Church fixture clears church count")
	_check(church.document.set_misc_u32(0x102c, 1000), "Church fixture sets city population")
	var church_result := Growth.run(church.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(church_result.ok, "Church growth scan completes: %s" % church_result.error)
	_check(church_result.churches_built == 1, "Residential density construction can make a church")
	for point in [Vector2i(20, 19), Vector2i(21, 19), Vector2i(20, 20), Vector2i(21, 20)]:
		_check(church.city.building_id(point.x, point.y) == 0xf7, "Church fills its two-by-two footprint")
		_check(church.city.zone_id(point.x, point.y) == 0, "Church clears the RCI zone nibble")

	_test_special_zone_growth(reference_root)
	_test_transport_maintenance(reference_root)


func _test_special_zone_growth(reference_root: String) -> void:
	var airport := _special_growth_fixture(reference_root)
	for x in range(20, 25):
		_check(airport.city.set_zone_id(x, 21, 8), "Airport fixture zones its runway strip")
	_check(airport.city.set_tile_flag(20, 21, 0x40, true), "Airport fixture powers its origin")
	var airport_result := Growth.run(
		airport.city, ZeroRandom.new(), 0, 1, NonzeroLfsrRandom.new()
	)
	_check(airport_result.ok, "Airport growth scan completes: %s" % airport_result.error)
	_check(airport_result.special_tiles_placed == 5, "Airport growth places a five-tile runway")
	for x in range(20, 25):
		_check(airport.city.building_id(x, 21) == 0xdd, "Airport runway uses tile 0xdd")
		_check(airport.city.building_corners(x, 21) == 0xf0, "Airport runway sets all corner bits")
		_check(
			airport.city.tile_flags[x * 128 + 21] & 0xc0 == 0xc0,
			"Civilian runway tiles are powered and powerable",
		)
	_check(airport.document.misc_u32(0x01f0 + 0xdd * 4) == 5, "Airport growth counts runway tiles")

	var seaport := _special_growth_fixture(reference_root)
	_check(seaport.city.set_zone_id(20, 20, 9), "Seaport fixture zones its crane origin")
	_check(seaport.city.set_tile_flag(20, 20, 0x40, true), "Seaport fixture powers its origin")
	for y in range(21, 26):
		_check(seaport.city.set_tile_flag(20, y, 0x04, true), "Seaport fixture marks pier water")
	_check(seaport.city.set_land_altitude(20, 25, 0), "Seaport fixture lowers the last water tile")
	_check(seaport.city.set_water_altitude(20, 25, 2), "Seaport fixture makes the last tile deep")
	var seaport_result := Growth.run(
		seaport.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(seaport_result.ok, "Seaport growth scan completes: %s" % seaport_result.error)
	_check(seaport_result.special_tiles_placed == 5, "Seaport growth places one crane and four piers")
	_check(seaport.city.building_id(20, 20) == 0xe0, "Seaport growth places its crane")
	_check(seaport.city.zone_id(20, 20) == 9, "Seaport crane stays in the seaport zone")
	for y in range(21, 25):
		_check(seaport.city.building_id(20, y) == 0xdf, "Seaport growth places a pier tile")
		_check(seaport.city.building_corners(20, y) == 0xf0, "Seaport pier sets all corner bits")
	_check(seaport.city.building_id(20, 25) == 0, "Seaport growth keeps the depth-check tile clear")
	_check(seaport.document.misc_u32(0x01f0 + 0xe0 * 4) == 1, "Seaport growth counts its crane")
	_check(seaport.document.misc_u32(0x01f0 + 0xdf * 4) == 4, "Seaport growth counts its piers")

	var silos := _special_growth_fixture(reference_root)
	for x in range(18, 21):
		for y in range(18, 21):
			_check(silos.city.set_zone_id(x, y, 7), "Missile fixture zones its military plot")
	_check(silos.document.set_misc_u32(0x0e4c, 5), "Missile fixture selects a missile base")
	_check(silos.document.set_misc_u32(0x01f0, 16375), "Missile fixture excludes military tiles from the normal count")
	_check(silos.document.set_misc_u32(0x0fa8, 9), "Missile fixture counts military other tiles")
	var silo_result := Growth.run(silos.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(silo_result.ok, "Missile growth scan completes: %s" % silo_result.error)
	_check(silo_result.special_tiles_placed == 9, "Missile growth places a three-by-three silo")
	for x in range(18, 21):
		for y in range(18, 21):
			_check(silos.city.building_id(x, y) == 0xf9, "Missile growth fills the surface plot")
			_check(silos.city.underground_id(x, y) == 0x22, "Missile growth fills the underground plot")
	_check(silos.document.misc_u32(0x0fa8) == 0, "Missile growth consumes military other tiles")
	_check(silos.document.misc_u32(0x0fa8 + 15 * 4) == 9, "Missile growth counts silo tiles")
	_check(silos.document.misc_u32(0x0fe8) == 0, "Military silo subway tiles do not change the city subway count")

	var army := _special_growth_fixture(reference_root)
	for x in range(20, 22):
		for y in range(20, 22):
			_check(army.city.set_zone_id(x, y, 7), "Army fixture zones its building plot")
			_check(army.city.set_tile_flag(x, y, 0xe0, true), "Army fixture sets utility flags")
	_check(army.document.set_misc_u32(0x0e4c, 2), "Army fixture selects an army base")
	_check(army.document.set_misc_u32(0x01f0, 16380), "Army fixture excludes military tiles from the normal count")
	_check(army.document.set_misc_u32(0x0fa8, 4), "Army fixture counts military other tiles")
	var army_result := Growth.run(army.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(army_result.ok, "Army growth scan completes: %s" % army_result.error)
	_check(army_result.special_growth_attempts == 1, "Army growth attempts one controlled building")
	_check(army_result.special_tiles_placed == 0, "Win95 military item placement rejects its own zone")
	for x in range(20, 22):
		for y in range(20, 22):
			_check(army.city.building_id(x, y) == 0, "Win95 military placement leaves the plot clear")
			_check(army.city.tile_flags[x * 128 + y] & 0xf0 == 0, "Win95 military placement clears utility flags")

	var air_force := _special_growth_fixture(reference_root)
	for x in range(21, 26):
		_check(air_force.city.set_zone_id(x, 21, 7), "Air Force fixture zones its runway strip")
	_check(air_force.city.set_building_id(10, 10, 0xdd), "Air Force fixture places one civilian runway")
	_check(air_force.city.set_building_id(23, 21, 0x1d), "Air Force fixture places a military road")
	_check(air_force.city.set_terrain_id(23, 21, 1), "Air Force fixture sets terrain under the road")
	_check(air_force.city.set_underground_id(23, 21, 1), "Air Force fixture sets a subway under the road")
	_check(air_force.document.set_misc_u32(0x0e4c, 3), "Air Force fixture selects an air base")
	_check(air_force.document.set_misc_u32(0x01f0, 16378), "Air Force fixture counts normal clear tiles")
	_check(air_force.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Air Force fixture counts its civilian runway")
	_check(air_force.document.set_misc_u32(0x0fa8, 5), "Air Force fixture counts military other tiles")
	var air_force_result := Growth.run(
		air_force.city, ZeroRandom.new(), 1, 1, NonzeroLfsrRandom.new()
	)
	_check(air_force_result.ok, "Air Force growth scan completes: %s" % air_force_result.error)
	_check(air_force_result.special_tiles_placed == 5, "Air Force growth places a five-tile runway")
	for x in range(21, 26):
		_check(air_force.city.building_id(x, 21) == 0xdd, "Air Force growth follows normal-runway parity")
	_check(air_force.city.terrain_id(23, 21) == 1, "Win95 military runway growth preserves underlying terrain")
	_check(air_force.city.underground_id(23, 21) == 1, "Win95 military runway growth preserves its subway")
	_check(air_force.document.misc_u32(0x01f0 + 0xdd * 4) == 1, "Military runways do not change the normal runway count")
	_check(air_force.document.misc_u32(0x0fa8) == 0, "Air Force growth consumes military other tiles")
	_check(air_force.document.misc_u32(0x0fa8 + 4) == 5, "Air Force growth counts military runway tiles")

	var aircraft := _special_growth_fixture(reference_root)
	_check(aircraft.city.set_zone_id(20, 20, 8), "Aircraft fixture sets an airport zone")
	_check(aircraft.city.set_building_id(20, 20, 0xdd), "Aircraft fixture places a runway")
	_check(aircraft.city.set_tile_flag(20, 20, 0x40, true), "Aircraft fixture powers its runway")
	_check(aircraft.document.set_misc_u32(0x01f0, 16383), "Aircraft fixture counts clear tiles")
	_check(aircraft.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Aircraft fixture counts its runway")
	var aircraft_result := Growth.run(
		aircraft.city, SequenceRandom.new([1, 0, 0]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(aircraft_result.ok, "Aircraft growth scan completes: %s" % aircraft_result.error)
	_check(aircraft_result.spawned_helicopters == 1, "Powered airport runway spawns a helicopter")
	_check(aircraft.city.text_overlay_id(20, 20) == 202, "Helicopter attaches record one to its runway")
	var helicopter: Dictionary = aircraft.city.thing(1)
	_check(
		helicopter.type == 2
		and helicopter.direction == 2
		and helicopter.state == 0
		and helicopter.x == 20
		and helicopter.y == 20,
		"Helicopter stores its recovered type, direction, state, and position",
	)
	_check(
		helicopter.px == 8
		and helicopter.py == 8
		and helicopter.dx == 1
		and helicopter.dy == 1,
		"Helicopter stores its recovered sub-tile and random destination fields",
	)

	var airplane := _special_growth_fixture(reference_root)
	_check(airplane.city.set_zone_id(20, 20, 8), "Airplane fixture sets an airport zone")
	_check(airplane.city.set_building_id(20, 20, 0xdd), "Airplane fixture places a runway")
	_check(airplane.city.set_tile_flag(20, 20, 0x40, true), "Airplane fixture powers its runway")
	_check(airplane.document.set_misc_u32(0x01f0, 16383), "Airplane fixture counts clear tiles")
	_check(airplane.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Airplane fixture counts its runway")
	var airplane_result := Growth.run(
		airplane.city, SequenceRandom.new([1, 0, 4, 9]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(airplane_result.ok and airplane_result.spawned_airplanes == 1, "Airport spawns an airplane")
	var plane: Dictionary = airplane.city.thing(1)
	_check(
		plane.type == 1
		and plane.direction == 0
		and plane.state == 0
		and plane.x == 20
		and plane.y == 20
		and plane.z == 0,
		"Local airplane stores its recovered position and runway direction",
	)
	_check(
		plane.px == 8 and plane.py == 8 and plane.dx == 20 and plane.dy == 20,
		"Local airplane stores its recovered sub-tile and destination fields",
	)
	_check(airplane.city.text_overlay_id(20, 20) == 202, "Airplane attaches its XTHG record")
	var edge_things := _filled_bytes(40 * 12, 0)
	var edge_text := _filled_bytes(128 * 128, 0)
	var edge_result := MovingThings.spawn_airplane(
		edge_things, edge_text, Vector2i(20, 20), 2, SequenceRandom.new([0, 2, 7])
	)
	_check(edge_result.spawned, "Airplane creator accepts an empty moving-thing pool")
	_check(
		edge_things[12 + 1] == 7
		and edge_things[12 + 2] == 0x23
		and edge_things[12 + 3] == 127
		and edge_things[12 + 4] == 17
		and edge_things[12 + 5] == 16,
		"Map-edge airplane stores its selected edge, direction, height, and runway state",
	)
	_check(
		edge_things[12 + 8] == 4
		and edge_things[12 + 9] == 20
		and edge_text[127 * 128 + 17] == 202,
		"Map-edge airplane stores its runway target and attached XTXT record",
	)

	var ship_fixture := _special_growth_fixture(reference_root)
	_check(ship_fixture.city.set_zone_id(20, 20, 9), "Ship fixture sets a seaport zone")
	_check(ship_fixture.city.set_building_id(20, 20, 0xe0), "Ship fixture places a crane")
	_check(ship_fixture.city.set_terrain_id(2, 10, 0x10), "Ship fixture places edge water")
	var stale_ship_record: PackedByteArray = ship_fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	stale_ship_record[12 + 8] = 77
	stale_ship_record[12 + 9] = 88
	_check(
		ship_fixture.document.find_chunk("XTHG").set_decoded_payload(stale_ship_record),
		"Ship fixture sets stale target bytes",
	)
	var ship_result := Growth.run(
		ship_fixture.city, SequenceRandom.new([1, 0, 0]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(
		ship_result.ok
		and ship_result.spawned_ships == 1
		and ship_result.ship_home == Vector2i(2, 10),
		"Seaport crane spawns a cargo ship and reports its process-local home",
	)
	var ship: Dictionary = ship_fixture.city.thing(1)
	_check(
		ship.type == 3
		and ship.direction == 3
		and ship.x == 2
		and ship.y == 10
		and ship.z == 1,
		"Cargo ship uses the last water tile on its selected edge",
	)
	_check(ship.px == 8 and ship.py == 8, "Cargo ship stores its recovered sub-tile position")
	_check(ship.dx == 77 and ship.dy == 88, "Cargo-ship creation keeps stale target bytes")
	_check(ship_fixture.city.text_overlay_id(2, 10) == 202, "Cargo ship attaches its XTHG record")

	_test_growth_microsimulations(reference_root)


func _test_growth_microsimulations(reference_root: String) -> void:
	var station := _special_growth_fixture(reference_root)
	_check(station.city.set_building_id(20, 20, 0xed), "Train fixture places a rail station")
	_check(station.city.set_tile_flag(20, 20, 0x40, true), "Train fixture powers its station")
	_check(station.city.set_building_id(20, 18, 0x2c), "Train fixture places its spawn rail")
	_check(station.city.set_building_id(19, 18, 0x2c), "Train fixture places its west route rail")
	_check(station.city.set_building_id(21, 18, 0x2c), "Train fixture places its east route rail")
	_check(station.document.set_misc_u32(0x01f0 + 0xed * 4, 4), "Train fixture sets the station count")
	var train_result := Growth.run(
		station.city,
		ZeroRandom.new(),
		0,
		0,
		MicrosimLfsrRandom.new(),
		NonzeroLfsrRandom.new()
	)
	_check(train_result.ok and train_result.spawned_trains == 1, "Rail station spawns a train")
	_check(station.city.text_overlay_id(20, 18) == 202, "Train engine attaches to its rail tile")
	var engine: Dictionary = station.city.thing(1)
	var first_car: Dictionary = station.city.thing(2)
	var second_car: Dictionary = station.city.thing(3)
	_check(
		engine.type == 10
		and engine.direction == 1
		and engine.state == 2
		and engine.x == 20
		and engine.y == 18
		and engine.px == 21
		and engine.py == 18,
		"Train engine links its first car and follows the game-LCG search order",
	)
	_check(
		first_car.type == 11
		and first_car.state == 3
		and second_car.type == 11
		and first_car.px == 20
		and first_car.py == 18,
		"Train stores two linked car records at its initial tile",
	)
	var full_buildings := _filled_bytes(128 * 128, 0)
	var full_things := _filled_bytes(40 * 12, 0)
	var full_text := _filled_bytes(128 * 128, 0)
	full_buildings[20 * 128 + 18] = 0x2c
	full_buildings[20 * 128 + 17] = 0x2c
	for record in range(1, 40):
		full_things[record * 12] = 7
	_check(
		MovingThings.spawn_train(
			full_buildings, full_things, full_text, Vector2i(20, 20),
			ZeroLfsrRandom.new(), ZeroLfsrRandom.new()
		),
		"Full-pool train creator keeps the supplied unchecked-allocation result",
	)
	_check(
		full_things[0] == 11 and full_text[20 * 128 + 18] == 201,
		"Full-pool train creator writes reserved record zero like the supplied executable",
	)

	var marina := _special_growth_fixture(reference_root)
	_check(marina.city.set_building_id(20, 20, 0xf8), "Sailboat fixture places a marina")
	_check(marina.city.set_tile_flag(20, 20, 0x40, true), "Sailboat fixture powers its marina")
	_check(marina.city.set_tile_flag(20, 19, 0x04, true), "Sailboat fixture marks north water")
	_check(marina.document.set_misc_u32(0x01f0 + 0xf8 * 4, 9), "Sailboat fixture sets the marina count")
	var sailboat_result := Growth.run(
		marina.city, ZeroRandom.new(), 0, 0, MicrosimLfsrRandom.new()
	)
	_check(
		sailboat_result.ok and sailboat_result.spawned_sailboats == 1,
		"Marina spawns one sailboat on its valid adjacent water tile",
	)
	var sailboat: Dictionary = marina.city.thing(1)
	_check(
		sailboat.type == 9
		and sailboat.direction == 0
		and sailboat.x == 20
		and sailboat.y == 19
		and sailboat.px == 4
		and sailboat.py == 4,
		"Sailboat stores its recovered direction and sub-tile position",
	)
	_check(marina.city.text_overlay_id(20, 19) == 202, "Sailboat attaches its XTHG record")

	var arcology := _special_growth_fixture(reference_root)
	_check(arcology.city.set_building_id(20, 20, 0xfb), "Arcology fixture places an arcology tile")
	_check(arcology.city.set_building_corners(20, 20, 0x80), "Arcology fixture sets the absolute anchor bit")
	_check(arcology.city.set_text_overlay_id(20, 20, 61), "Arcology fixture attaches dynamic XMIC record ten")
	_check(arcology.city.set_tile_flag(20, 20, 0x40, true), "Arcology fixture powers the tile")
	_check(arcology.document.set_misc_u32(0x0008, 3), "Arcology fixture rotates the city")
	var microsims: PackedByteArray = arcology.document.find_chunk("XMIC").decoded_payload.duplicate()
	microsims[10 * 8] = 0xfb
	_check(arcology.document.find_chunk("XMIC").set_decoded_payload(microsims), "Arcology fixture sets its XMIC type")
	var coarse_index := 10 * 64 + 10
	var land_value: PackedByteArray = arcology.document.find_chunk("XVAL").decoded_payload.duplicate()
	land_value[coarse_index] = 224
	_check(arcology.document.find_chunk("XVAL").set_decoded_payload(land_value), "Arcology fixture sets land value")
	var crime: PackedByteArray = arcology.document.find_chunk("XCRM").decoded_payload.duplicate()
	crime[coarse_index] = 64
	_check(arcology.document.find_chunk("XCRM").set_decoded_payload(crime), "Arcology fixture sets crime")
	var pollution: PackedByteArray = arcology.document.find_chunk("XPLT").decoded_payload.duplicate()
	pollution[coarse_index] = 32
	_check(arcology.document.find_chunk("XPLT").set_decoded_payload(pollution), "Arcology fixture sets pollution")
	var arcology_result := Growth.run(
		arcology.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(arcology_result.ok and arcology_result.arcologies_updated == 1, "Arcology updates its XMIC statistic")
	_check(arcology.city.microsim(10).stat_0 == 8, "Arcology rating uses land value, crime, pollution, power, and water")


func _test_moving_thing_phase(reference_root: String) -> void:
	var explosion := _special_growth_fixture(reference_root)
	_set_explosion(explosion, 1, Vector2i(20, 20), 5, 0, 0)
	_check(explosion.city.set_building_id(20, 20, 0x90), "Explosion fixture places its center building")
	var first_explosion_frame := MovingThingTick.run(
		explosion.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	var second_explosion_frame := MovingThingTick.run(
		explosion.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	var final_explosion_frame := MovingThingTick.run(
		explosion.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		first_explosion_frame.ok
		and first_explosion_frame.deferred_news == 1
		and second_explosion_frame.ok
		and final_explosion_frame.ok,
		"Explosion record requests news and advances through two animation frames",
	)
	_check(
		explosion.city.thing(1).type == 0
		and explosion.city.building_id(20, 20) == 0
		and explosion.city.text_overlay_id(20, 20) == 0,
		"Finished non-spreading explosion removes its record, center building, and link: %s %d %d"
		% [explosion.city.thing(1), explosion.city.building_id(20, 20), explosion.city.text_overlay_id(20, 20)],
	)

	var spreading_explosion := _special_growth_fixture(reference_root)
	_set_explosion(spreading_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	var spreading_traffic: PackedByteArray = spreading_explosion.document.find_chunk("XTRF").decoded_payload.duplicate()
	spreading_traffic[10 * 64 + 10] = 200
	_check(
		spreading_explosion.document.find_chunk("XTRF").set_decoded_payload(spreading_traffic),
		"Spreading explosion fixture sets traffic",
	)
	var spread_result := MovingThingTick.run(
		spreading_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([2, 2, 3, 2, 2, 3, 1, 2])
	)
	_check(
		spread_result.ok and spread_result.spread_explosion_fires == 4,
		"Spreading explosion applies four LFSR-selected fire attempts",
	)
	_check(
		spreading_explosion.city.text_overlay_id(20, 20) == 0xff
		and spreading_explosion.city.text_overlay_id(21, 20) == 0xff
		and spreading_explosion.city.text_overlay_id(20, 21) == 0xff
		and spreading_explosion.city.text_overlay_id(19, 20) == 0xff,
		"Explosion damage writes fire overlays at the recovered positions",
	)
	_check(
		spreading_explosion.document.find_chunk("XTRF").decoded_payload[10 * 64 + 10] == 0,
		"Explosion fire clears coarse traffic",
	)

	var labeled_explosion := _special_growth_fixture(reference_root)
	_set_explosion(labeled_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(labeled_explosion.city.set_label(1, "Blast Zone"), "Explosion fixture sets a user label")
	_check(labeled_explosion.city.set_text_overlay_id(21, 20, 1), "Explosion fixture places a user label")
	var label_damage := MovingThingTick.run(
		labeled_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 3, 2, 3, 2, 3, 2])
	)
	_check(
		label_damage.ok
		and labeled_explosion.city.label(1).is_empty()
		and labeled_explosion.city.text_overlay_id(21, 20) == 0xff,
		"Explosion damage releases a user label before it starts fire",
	)

	var rubble_explosion := _special_growth_fixture(reference_root)
	_set_explosion(rubble_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(rubble_explosion.city.set_building_id(21, 20, 0x90), "Rubble explosion fixture places a building")
	_check(rubble_explosion.city.set_text_overlay_id(21, 20, 241), "Rubble explosion fixture places overlay 241")
	var rubble_result := MovingThingTick.run(
		rubble_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 0, 3, 2, 0, 3, 2, 0, 3, 2, 0])
	)
	_check(
		rubble_result.ok
		and rubble_result.rubble_explosion_hits == 4
		and rubble_explosion.city.building_id(21, 20) == 1
		and rubble_explosion.city.text_overlay_id(21, 20) == 241,
		"Explosion overlay 241 through 249 changes the building to LFSR-selected rubble: %s %d %d"
		% [rubble_result, rubble_explosion.city.building_id(21, 20), rubble_explosion.city.text_overlay_id(21, 20)],
	)

	var facility_explosion := _special_growth_fixture(reference_root)
	_set_explosion(facility_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(facility_explosion.city.set_text_overlay_id(21, 20, 51), "Facility explosion fixture places XMIC overlay 51")
	var facility_result := MovingThingTick.run(
		facility_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 3, 2, 3, 2, 3, 2])
	)
	_check(
		facility_result.ok
		and facility_result.deferred_facility_explosion_hits == 4
		and not facility_result.explosion_map_damage_complete,
		"Explosion reports linked-facility demolition until that full damage path is implemented",
	)

	var airplane := _special_growth_fixture(reference_root)
	_set_airplane(airplane, 1, Vector2i(20, 20), Vector2i(20, 20), 2, 0, 0)
	_check(airplane.city.set_building_id(20, 20, 0xdd), "Airplane takeoff fixture places a runway")
	_check(airplane.city.set_zone_id(20, 20, 8), "Airplane takeoff fixture sets the airport zone")
	var takeoff_plane_result := MovingThingTick.run(
		airplane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		takeoff_plane_result.ok
		and takeoff_plane_result.active_airplanes == 1
		and takeoff_plane_result.moved_airplanes == 1
		and takeoff_plane_result.deferred_news == 1
		and airplane.city.thing(1).x == 21
		and airplane.city.thing(1).z == 1,
		"Airplane takeoff moves at sixteen sub-tiles, gains height, and requests news",
	)

	var cruising_plane := _special_growth_fixture(reference_root)
	_set_airplane(cruising_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 14)
	_check(cruising_plane.city.set_building_id(23, 20, 0xfb), "Airplane obstacle fixture places an arcology")
	var cruise_plane_result := MovingThingTick.run(
		cruising_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		cruise_plane_result.ok
		and cruising_plane.city.thing(1).direction == 3
		and cruising_plane.city.thing(1).x == 21
		and cruising_plane.city.thing(1).y == 21,
		"Airplane cruise avoids an arcology and moves one diagonal tile",
	)

	var approaching_plane := _special_growth_fixture(reference_root)
	_set_airplane(approaching_plane, 1, Vector2i(10, 20), Vector2i(12, 20), 2, 3, 16)
	var approach_result := MovingThingTick.run(
		approaching_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		approach_result.ok
		and approaching_plane.city.thing(1).x == 11
		and approaching_plane.city.thing(1).state == 4
		and approaching_plane.city.thing(1).direction == 1,
		"Inbound airplane enters alignment when it reaches its runway target",
	)
	var alignment_result := MovingThingTick.run(
		approaching_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		alignment_result.ok
		and approaching_plane.city.thing(1).x == 12
		and approaching_plane.city.thing(1).state == 1
		and approaching_plane.city.thing(1).direction == 0,
		"Inbound airplane completes alignment and starts descent",
	)

	var landing_plane := _special_growth_fixture(reference_root)
	_set_airplane(landing_plane, 1, Vector2i(20, 20), Vector2i(21, 20), 2, 1, 1)
	_check(landing_plane.city.set_building_id(21, 20, 0xdd), "Landing airplane fixture places its destination runway")
	var landing_plane_result := MovingThingTick.run(
		landing_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		landing_plane_result.ok
		and landing_plane_result.landed_airplanes == 1
		and landing_plane.city.thing(1).type == 0
		and landing_plane.city.text_overlay_id(21, 20) == 0,
		"Airplane completes descent and releases its record on a runway",
	)

	var missed_runway := _special_growth_fixture(reference_root)
	_set_airplane(missed_runway, 1, Vector2i(20, 20), Vector2i(21, 20), 2, 1, 1)
	var missed_result := MovingThingTick.run(
		missed_runway.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		missed_result.ok
		and missed_result.crashed_airplanes == 1
		and missed_runway.city.thing(1).type == 6
		and missed_runway.city.thing(1).state == 5
		and missed_runway.city.thing(1).goal == 1
		and missed_runway.city.text_overlay_id(21, 20) == 0,
		"Airplane landing outside a runway becomes an unlinked spreading explosion",
	)

	var low_plane := _special_growth_fixture(reference_root)
	_set_airplane(low_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 11)
	_check(low_plane.city.set_building_id(20, 20, 0xbb), "Low airplane fixture places the tallest small-map building sprite")
	var low_plane_result := MovingThingTick.run(
		low_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		low_plane_result.ok
		and low_plane_result.crashed_airplanes == 1
		and low_plane.city.thing(1).type == 6
		and low_plane.city.thing(1).goal == 1,
		"Airplane collision uses one third of the recovered building sprite height",
	)

	var arcology_plane := _special_growth_fixture(reference_root)
	_set_airplane(arcology_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 16)
	_check(arcology_plane.city.set_building_id(20, 20, 0xfb), "Airplane crash fixture places an arcology")
	var arcology_plane_result := MovingThingTick.run(
		arcology_plane.city, SequenceRandom.new([1]), ZeroLfsrRandom.new()
	)
	_check(
		arcology_plane_result.ok
		and arcology_plane.city.thing(1).type == 6
		and arcology_plane.city.thing(1).goal == 1,
		"Airplane arcology collision selects a spreading explosion on its LFSR gate",
	)

	var falling_plane := _special_growth_fixture(reference_root)
	_set_airplane(falling_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 7, 9)
	var falling_result := MovingThingTick.run(
		falling_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		falling_result.ok
		and falling_result.deferred_news == 1
		and falling_plane.city.thing(1).z == 8
		and falling_plane.city.thing(1).direction == 3
		and falling_plane.city.thing(1).x == 21
		and falling_plane.city.thing(1).y == 20,
		"Falling airplane rotates its saved direction but moves in its prior direction",
	)

	var ship := _special_growth_fixture(reference_root)
	_set_ship(ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 0)
	_check(ship.city.set_tile_flag(20, 20, 0x04, true), "Cargo-ship fixture marks current water")
	_check(ship.city.set_tile_flag(24, 20, 0x04, true), "Cargo-ship fixture marks look-ahead water")
	var first_ship_move := MovingThingTick.run(
		ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	var second_ship_move := MovingThingTick.run(
		ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		first_ship_move.ok
		and second_ship_move.ok
		and first_ship_move.moved_ships == 1
		and second_ship_move.moved_ships == 1,
		"Cargo ship advances on a valid four-cell look-ahead route",
	)
	_check(
		ship.city.thing(1).x == 21
		and ship.city.thing(1).y == 20
		and ship.city.thing(1).px == 4
		and ship.city.thing(1).py == 8,
		"Cargo ship uses the recovered twelve-unit sub-tile grid",
	)
	_check(ship.city.text_overlay_id(20, 20) == 0, "Cargo ship clears its old XTXT cell")
	_check(ship.city.text_overlay_id(21, 20) == 202, "Cargo ship links its new XTXT cell")

	var docking_ship := _special_growth_fixture(reference_root)
	_set_ship(docking_ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 0)
	_check(docking_ship.city.set_tile_flag(20, 20, 0x04, true), "Docking ship marks current water")
	_check(docking_ship.city.set_tile_flag(24, 20, 0x04, true), "Docking ship marks route water")
	_check(docking_ship.city.set_building_id(22, 20, 0xdf), "Docking ship places a pier two cells away")
	var dock_result := MovingThingTick.run(
		docking_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		dock_result.ok
		and dock_result.docked_ships == 1
		and docking_ship.city.thing(1).state == 3,
		"Cargo ship enters dock wait beside a pier",
	)
	var depart_result := MovingThingTick.run(
		docking_ship.city,
		SequenceRandom.new([1]),
		ZeroLfsrRandom.new(),
		null,
		Vector2i(2, 10)
	)
	_check(
		depart_result.ok
		and depart_result.departing_ships == 1
		and depart_result.deferred_news == 1
		and docking_ship.city.thing(1).state == 4
		and docking_ship.city.thing(1).dx == 2
		and docking_ship.city.thing(1).dy == 10,
		"Cargo ship leaves dock toward its process-local home coordinates",
	)

	var blocked_ship := _special_growth_fixture(reference_root)
	_set_ship(blocked_ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 0)
	_check(blocked_ship.city.set_tile_flag(20, 20, 0x04, true), "Blocked ship marks current water")
	var block_result := MovingThingTick.run(
		blocked_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		block_result.ok and blocked_ship.city.thing(1).state == 1,
		"Cargo ship starts a target turn when its look-ahead route is blocked",
	)
	_check(blocked_ship.city.set_tile_flag(24, 20, 0x04, true), "Turning ship opens its target route")
	MovingThingTick.run(blocked_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new())
	MovingThingTick.run(blocked_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new())
	_check(
		blocked_ship.city.thing(1).direction == 2 and blocked_ship.city.thing(1).state == 0,
		"Cargo ship turns one step per tick and resumes travel when its target route opens",
	)

	var escaping_ship := _special_growth_fixture(reference_root)
	_set_ship(escaping_ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2)
	_check(escaping_ship.city.set_tile_flag(20, 20, 0x04, true), "Escaping ship marks current water")
	_check(escaping_ship.city.set_tile_flag(23, 23, 0x04, true), "Escaping ship opens its diagonal route")
	var escape_result := MovingThingTick.run(
		escaping_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		escape_result.ok
		and escaping_ship.city.thing(1).direction == 3
		and escaping_ship.city.thing(1).state == 0,
		"Cargo ship escape search selects the first valid recovered direction",
	)

	var trapped_ship := _special_growth_fixture(reference_root)
	_set_ship(trapped_ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2)
	_check(trapped_ship.city.set_tile_flag(20, 20, 0x04, true), "Trapped ship marks current water")
	var trapped_result := MovingThingTick.run(
		trapped_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		trapped_result.ok
		and trapped_result.removed_ships == 1
		and trapped_ship.city.thing(1).type == 0,
		"Cargo ship releases its record when all eight escape routes fail",
	)

	var grounded_ship := _special_growth_fixture(reference_root)
	_set_ship(grounded_ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 0)
	var grounded_result := MovingThingTick.run(
		grounded_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		grounded_result.ok
		and grounded_result.crashed_ships == 1
		and grounded_ship.city.thing(1).type == 6
		and grounded_ship.city.thing(1).state == 0
		and grounded_ship.city.thing(1).goal == 0,
		"Cargo ship on dry land becomes the recovered explosion record",
	)

	var helicopter := _special_growth_fixture(reference_root)
	_set_helicopter(helicopter, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 0, 0)
	var takeoff_result := MovingThingTick.run(
		helicopter.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		takeoff_result.ok
		and takeoff_result.active_helicopters == 1
		and helicopter.city.thing(1).direction == 3
		and helicopter.city.thing(1).z == 1,
		"Helicopter takeoff rotates and gains one height unit",
	)

	var flight := _special_growth_fixture(reference_root)
	_set_helicopter(flight, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 10)
	var first_flight := MovingThingTick.run(
		flight.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	var second_flight := MovingThingTick.run(
		flight.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		first_flight.ok
		and second_flight.ok
		and first_flight.moved_helicopters == 1
		and second_flight.moved_helicopters == 1,
		"Cruising helicopter advances on each off-cycle tick",
	)
	_check(
		flight.city.thing(1).x == 21
		and flight.city.thing(1).y == 20
		and flight.city.thing(1).px == 8
		and flight.city.thing(1).py == 8,
		"Helicopter uses the recovered eight-unit sub-tile speed",
	)
	_check(flight.city.text_overlay_id(20, 20) == 0, "Helicopter clears its old XTXT cell")
	_check(flight.city.text_overlay_id(21, 20) == 202, "Helicopter links its new XTXT cell")

	var avoiding := _special_growth_fixture(reference_root)
	_set_helicopter(avoiding, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 10)
	_check(avoiding.city.set_building_id(23, 20, 0xfb), "Helicopter obstacle fixture places an arcology")
	var avoid_result := MovingThingTick.run(
		avoiding.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		avoid_result.ok and avoiding.city.thing(1).direction == 3,
		"Helicopter selects the first clear recovered obstacle-avoidance direction",
	)

	var retargeting := _special_growth_fixture(reference_root)
	_check(retargeting.document.set_misc_u32(0x1018, 50), "Helicopter fixture sets city-center X")
	_check(retargeting.document.set_misc_u32(0x101c, 60), "Helicopter fixture sets city-center Y")
	_set_helicopter(retargeting, 1, Vector2i(20, 20), Vector2i(20, 20), 2, 2, 10)
	var retarget_result := MovingThingTick.run(
		retargeting.city, SequenceRandom.new([32, 32, 1]), NonzeroLfsrRandom.new()
	)
	_check(
		retarget_result.ok
		and retargeting.city.thing(1).dx == 50
		and retargeting.city.thing(1).dy == 60
		and retargeting.city.thing(1).state == 3,
		"Helicopter selects a city-center target and can start landing on clear ground",
	)

	var landing := _special_growth_fixture(reference_root)
	_set_helicopter(landing, 1, Vector2i(20, 20), Vector2i(20, 20), 2, 3, 3)
	MovingThingTick.run(landing.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new())
	MovingThingTick.run(landing.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new())
	_check(
		landing.city.thing(1).state == 4 and landing.city.thing(1).z == 2,
		"Helicopter landing rotates, descends, and enters its ground wait state",
	)
	MovingThingTick.run(landing.city, ZeroRandom.new(), NonzeroLfsrRandom.new())
	_check(landing.city.thing(1).state == 0, "Helicopter ground wait restarts on its process-random gate")

	var forced_crash := _special_growth_fixture(reference_root)
	_set_helicopter(forced_crash, 1, Vector2i(20, 20), Vector2i(20, 20), 2, 5, 2)
	var forced_crash_result := MovingThingTick.run(
		forced_crash.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		forced_crash_result.ok
		and forced_crash_result.crashed_helicopters == 1
		and forced_crash.city.thing(1).type == 6
		and forced_crash.city.thing(1).state == 0x11
		and forced_crash.city.thing(1).goal == 1,
		"Helicopter emergency descent becomes the recovered explosion record",
	)

	var building_crash := _special_growth_fixture(reference_root)
	_set_helicopter(building_crash, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 10)
	_check(building_crash.city.set_building_id(20, 20, 0xfb), "Helicopter crash fixture places an arcology")
	var building_crash_result := MovingThingTick.run(
		building_crash.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		building_crash_result.ok
		and building_crash.city.thing(1).type == 6
		and building_crash.city.thing(1).state == 5
		and building_crash.city.thing(1).goal == 0,
		"Helicopter collision with an arcology becomes a non-spreading explosion",
	)

	var moving := _special_growth_fixture(reference_root)
	_set_sailboat(moving, 1, Vector2i(20, 20), 1)
	_check(moving.city.set_tile_flag(20, 20, 0x04, true), "Moving sailboat fixture marks its current water")
	_check(moving.city.set_tile_flag(21, 20, 0x04, true), "Moving sailboat fixture marks its next water")
	var move_result := MovingThingTick.run(
		moving.city, ZeroRandom.new(), SequenceLfsrRandom.new([1])
	)
	_check(move_result.ok and move_result.moved_sailboats == 1, "Sailboat tick moves on a clear water route")
	var moved_sailboat: Dictionary = moving.city.thing(1)
	_check(
		moved_sailboat.x == 21
		and moved_sailboat.y == 20
		and moved_sailboat.px == 4
		and moved_sailboat.py == 4,
		"Sailboat movement advances one tile and keeps its recovered sub-tile position",
	)
	_check(moving.city.text_overlay_id(20, 20) == 0, "Sailboat movement clears its old XTXT cell")
	_check(moving.city.text_overlay_id(21, 20) == 202, "Sailboat movement links its new XTXT cell")

	var turning := _special_growth_fixture(reference_root)
	_set_sailboat(turning, 1, Vector2i(20, 20), 1)
	_check(turning.city.set_tile_flag(20, 20, 0x04, true), "Turning sailboat fixture marks water")
	var turn_result := MovingThingTick.run(
		turning.city, SequenceRandom.new([2]), SequenceLfsrRandom.new([0, 1])
	)
	_check(turn_result.ok and turn_result.turned_sailboats == 1, "Sailboat turns on its LFSR gate")
	_check(
		turning.city.thing(1).direction == 2
		and turning.city.thing(1).x == 20
		and turning.city.thing(1).y == 20,
		"Sailboat turn uses the process generator and stays on its tile",
	)

	var distress := _special_growth_fixture(reference_root)
	_set_sailboat(distress, 1, Vector2i(20, 20), 0)
	_check(distress.city.set_tile_flag(20, 20, 0x04, true), "Distress fixture marks water")
	var distress_result := MovingThingTick.run(
		distress.city, ZeroRandom.new(), SequenceLfsrRandom.new([0, 0])
	)
	_check(
		distress_result.ok
		and distress_result.distressed_sailboats == 1
		and distress_result.deferred_news == 1,
		"Sailboat distress sets its state and reports the pending news item",
	)
	_check(distress.city.thing(1).state == 1, "Distressed sailboat stores state one")
	var removal_result := MovingThingTick.run(
		distress.city, ZeroRandom.new(), SequenceLfsrRandom.new([0])
	)
	_check(removal_result.ok and removal_result.removed_sailboats == 1, "Distressed sailboat expires on its LFSR gate")
	_check(distress.city.thing(1).type == 0, "Expired sailboat releases its XTHG record")
	_check(distress.city.text_overlay_id(20, 20) == 0, "Expired sailboat clears its XTXT cell")

	var marina := _special_growth_fixture(reference_root)
	_set_sailboat(marina, 1, Vector2i(20, 20), 1)
	_check(marina.city.set_building_id(21, 20, 0xf8), "Sailboat destination fixture places a marina")
	var marina_result := MovingThingTick.run(
		marina.city, ZeroRandom.new(), SequenceLfsrRandom.new([1])
	)
	_check(marina_result.ok and marina_result.removed_sailboats == 1, "Sailboat disappears when it reaches a marina")
	_check(marina.city.thing(1).type == 0, "Marina arrival releases the sailboat record")
	_check(marina.city.text_overlay_id(20, 20) == 0, "Marina arrival clears the sailboat link")

	var train := _special_growth_fixture(reference_root)
	for x in range(20, 23):
		_check(train.city.set_building_id(x, 20, 0x2c), "Moving train fixture places surface rail")
	_set_train(train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var train_result := MovingThingTick.run(
		train.city, ZeroRandom.new(), SequenceLfsrRandom.new([0, 1]), ZeroLfsrRandom.new()
	)
	_check(train_result.ok and train_result.moved_trains == 1, "Train tick advances a clear consist")
	var moved_engine: Dictionary = train.city.thing(1)
	_check(
		moved_engine.x == 21
		and moved_engine.y == 20
		and moved_engine.px == 22
		and moved_engine.py == 20
		and moved_engine.direction == 1
		and moved_engine.dx == 2,
		"Train engine moves and plans its next straight rail cell",
	)
	_check(
		train.city.thing(2).x == 20
		and train.city.thing(2).px == 21
		and train.city.thing(3).x == 20
		and train.city.thing(3).px == 20,
		"Train cars copy the prior engine and first-car states in order",
	)
	_check(train.city.text_overlay_id(20, 20) == 0, "Train movement restores the tail XTXT value")
	_check(train.city.text_overlay_id(21, 20) == 202, "Train movement attaches the engine at its new cell")

	var station := _special_growth_fixture(reference_root)
	_check(station.city.set_building_id(20, 20, 0x2c), "Pausing train fixture places current rail")
	_check(station.city.set_building_id(21, 20, 0x2c), "Pausing train fixture places destination rail")
	_check(station.city.set_building_id(20, 19, 0xed), "Pausing train fixture places an adjacent station")
	_set_train(station, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var pause_result := MovingThingTick.run(
		station.city, ZeroRandom.new(), SequenceLfsrRandom.new([1]), ZeroLfsrRandom.new()
	)
	_check(pause_result.ok and pause_result.paused_trains == 1, "Surface train pauses beside a station")
	_check(
		station.city.thing(1).x == 20 and station.city.thing(1).px == 21,
		"Station pause keeps the train position and destination",
	)

	var turning_train := _special_growth_fixture(reference_root)
	_check(turning_train.city.set_building_id(20, 20, 0x2c), "Turning train fixture places current rail")
	_check(turning_train.city.set_building_id(21, 20, 0x2c), "Turning train fixture places destination rail")
	_check(turning_train.city.set_building_id(21, 19, 0x2c), "Turning train fixture places north rail")
	_set_train(turning_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var train_turn_result := MovingThingTick.run(
		turning_train.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([0, 0, 0]),
		ZeroLfsrRandom.new()
	)
	_check(train_turn_result.ok and train_turn_result.turned_trains == 1, "Train takes its random side route")
	_check(
		turning_train.city.thing(1).x == 21
		and turning_train.city.thing(1).y == 20
		and turning_train.city.thing(1).px == 21
		and turning_train.city.thing(1).py == 19
		and turning_train.city.thing(1).direction == 1
		and turning_train.city.thing(1).dx == 0,
		"Random train turn keeps the supplied prior-direction field quirk",
	)

	var subway_train := _special_growth_fixture(reference_root)
	_check(subway_train.city.set_building_id(20, 20, 0x2c), "Subway train fixture places current rail")
	_check(subway_train.city.set_building_id(21, 20, 0x6c), "Subway train fixture places a transition tile")
	_check(subway_train.city.set_underground_id(22, 20, 1), "Subway train fixture places its next subway")
	_set_train(subway_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var subway_train_result := MovingThingTick.run(
		subway_train.city,
		ZeroRandom.new(),
		SequenceLfsrRandom.new([0, 1]),
		ZeroLfsrRandom.new()
	)
	_check(subway_train_result.ok and subway_train_result.moved_trains == 1, "Train enters a subway transition")
	_check(
		subway_train.city.thing(1).type == 12
		and subway_train.city.thing(1).x == 21
		and subway_train.city.thing(1).px == 22,
		"Surface engine becomes a subway engine and plans an underground route",
	)

	var reversing_train := _special_growth_fixture(reference_root)
	_check(reversing_train.city.set_building_id(20, 20, 0x2c), "Reversing train fixture places its old rail")
	_check(reversing_train.city.set_building_id(21, 20, 0x2c), "Reversing train fixture places its current rail")
	_set_train(reversing_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var reversing_things: PackedByteArray = reversing_train.document.find_chunk("XTHG").decoded_payload.duplicate()
	reversing_things[2 * 12 + 10] = 7
	reversing_things[3 * 12 + 10] = 201
	_check(
		reversing_train.document.find_chunk("XTHG").set_decoded_payload(reversing_things),
		"Reversing train fixture sets its preserved tail labels",
	)
	var reverse_result := MovingThingTick.run(
		reversing_train.city,
		ZeroRandom.new(),
		SequenceLfsrRandom.new([0, 1]),
		ZeroLfsrRandom.new()
	)
	_check(reverse_result.ok and reverse_result.reversed_trains == 1, "Train reverses when no next route is open")
	_check(
		reversing_train.city.thing(1).x == 20
		and reversing_train.city.thing(1).px == 20
		and reversing_train.city.thing(1).direction == 3
		and reversing_train.city.thing(1).dx == 7
		and reversing_train.city.thing(1).label == 7,
		"Dead-end reversal moves the engine to the tail and faces it backward",
	)
	_check(
		reversing_train.city.thing(3).x == 21
		and reversing_train.city.thing(3).px == 21,
		"Dead-end reversal moves the tail record to the prior engine position",
	)

	var crashed_train := _special_growth_fixture(reference_root)
	_set_train(crashed_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var crash_result := MovingThingTick.run(
		crashed_train.city,
		ZeroRandom.new(),
		SequenceLfsrRandom.new([0]),
		ZeroLfsrRandom.new()
	)
	_check(
		crash_result.ok
		and crash_result.removed_trains == 1
		and crash_result.created_train_crash_explosions == 1,
		"Train without a route removes its consist and creates a crash explosion",
	)
	_check(
		crashed_train.city.thing(1).type == 6
		and crashed_train.city.thing(1).direction == 0
		and crashed_train.city.thing(1).state == 0
		and crashed_train.city.thing(1).z == 0
		and crashed_train.city.thing(1).px == 8
		and crashed_train.city.thing(1).py == 8
		and crashed_train.city.thing(1).goal == 0
		and crashed_train.city.thing(2).type == 0
		and crashed_train.city.thing(3).type == 0,
		"Train crash reuses the first released record for a non-spreading explosion",
	)
	_check(crashed_train.city.text_overlay_id(20, 20) == 202, "Train crash links its explosion to XTXT")


func _set_sailboat(
	fixture: Dictionary, record: int, point: Vector2i, direction: int, state := 0
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 9
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 6] = 4
	things[offset + 7] = 4
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Sailboat fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Sailboat fixture links its XTXT record")


func _set_helicopter(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	target: Vector2i,
	direction: int,
	state: int,
	height: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 2
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = target.x
	things[offset + 9] = target.y
	things[offset + 10] = fixture.city.text_overlay_id(point.x, point.y)
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Helicopter fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Helicopter fixture links its XTXT record")


func _set_ship(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	target: Vector2i,
	direction: int,
	state: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 3
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = 1
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = target.x
	things[offset + 9] = target.y
	things[offset + 10] = fixture.city.text_overlay_id(point.x, point.y)
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Cargo-ship fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Cargo-ship fixture links its XTXT record")


func _set_airplane(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	target: Vector2i,
	direction: int,
	state: int,
	height: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 1
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = target.x
	things[offset + 9] = target.y
	things[offset + 10] = fixture.city.text_overlay_id(point.x, point.y)
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Airplane fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Airplane fixture links its XTXT record")


func _set_explosion(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	state: int,
	goal: int,
	frame: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 6
	things[offset + 1] = frame
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 10] = fixture.city.text_overlay_id(point.x, point.y)
	things[offset + 11] = goal
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Explosion fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Explosion fixture links its XTXT record")


func _set_train(
	fixture: Dictionary,
	current: Vector2i,
	destination: Vector2i,
	direction: int,
	engine_type: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	for record in range(1, 4):
		var offset := record * 12
		things[offset] = engine_type if record == 1 else engine_type + 1
		things[offset + 1] = direction
		things[offset + 2] = record + 1 if record < 3 else 0
		things[offset + 3] = current.x
		things[offset + 4] = current.y
		things[offset + 6] = destination.x if record == 1 else current.x
		things[offset + 7] = destination.y if record == 1 else current.y
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Train fixture stores its linked XTHG records")
	_check(fixture.city.set_text_overlay_id(current.x, current.y, 202), "Train fixture links its engine XTXT record")


func _test_transport_maintenance(reference_root: String) -> void:
	var road := _maintenance_fixture(reference_root, 0x1d, 0)
	_check(road.city.set_tile_flag(20, 20, 0x80, true), "Road decay fixture sets powerable")
	_check(road.document.set_misc_i32(0x077c + 10 * 0x6c + 4, 0), "Road decay fixture removes funding")
	var road_result := Growth.run(road.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(road_result.ok and road_result.decayed_roads == 1, "Unfunded road decays on the rare check")
	_check(road.city.building_id(20, 20) == 1, "Road decay makes process-selected rubble")
	_check(road.city.tile_flags[20 * 128 + 20] & 0x80 == 0, "Road decay clears powerable")

	var rail := _maintenance_fixture(reference_root, 0x2c, 0)
	_check(rail.city.set_tile_flag(20, 20, 0x80, true), "Rail decay fixture sets powerable")
	_check(rail.document.set_misc_i32(0x077c + 13 * 0x6c + 4, 0), "Rail decay fixture removes funding")
	var rail_result := Growth.run(rail.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(rail_result.ok and rail_result.decayed_rails == 1, "Unfunded rail decays on the rare check")
	_check(rail.city.building_id(20, 20) == 1, "Rail decay makes process-selected rubble")
	_check(rail.city.tile_flags[20 * 128 + 20] & 0x80 == 0, "Rail decay clears powerable")

	var highway := _maintenance_fixture(reference_root, 0x49, 0)
	for point in [Vector2i(21, 20), Vector2i(20, 21), Vector2i(21, 21)]:
		_check(highway.city.set_building_id(point.x, point.y, 0x49), "Highway decay fixture fills its section")
	_check(highway.city.set_tile_flag(21, 20, 0x04, true), "Highway decay fixture sets one water tile")
	_check(highway.document.set_misc_u32(0x01f0 + 0x49 * 4, 4), "Highway decay fixture counts its tiles")
	_check(highway.document.set_misc_i32(0x077c + 11 * 0x6c + 4, 0), "Highway decay fixture removes funding")
	var highway_result := Growth.run(highway.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(highway_result.ok and highway_result.decayed_highway_tiles == 4, "Unfunded highway decays as one section")
	_check(highway.city.building_id(21, 20) == 0, "Highway decay clears a water tile")
	for point in [Vector2i(20, 20), Vector2i(20, 21), Vector2i(21, 21)]:
		_check(highway.city.building_id(point.x, point.y) == 1, "Highway decay makes rubble on dry land")

	var subway := _maintenance_fixture(reference_root, 0, 0x01)
	_check(subway.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Subway decay fixture removes funding")
	var subway_result := Growth.run(subway.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(subway_result.ok and subway_result.decayed_subway_tiles == 1, "Unfunded subway decays on the rare check")
	_check(subway.city.underground_id(20, 20) == 0, "Subway decay clears a subway tile")
	_check(subway.document.misc_u32(0x0fe8) == 0, "Subway decay decrements the saved XUND count")

	var crossover := _maintenance_fixture(reference_root, 0, 0x1f)
	_check(crossover.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Crossover decay fixture removes funding")
	var crossover_result := Growth.run(crossover.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(crossover_result.ok and crossover_result.decayed_subway_tiles == 1, "Subway crossover loses its rail layer")
	_check(crossover.city.underground_id(20, 20) == 0x11, "Subway crossover preserves its pipe layer")
	_check(crossover.document.misc_u32(0x0fe8) == 0, "Crossover decay decrements the saved XUND count")

	var station := _maintenance_fixture(reference_root, 0xe9, 0x23)
	_check(station.city.set_text_overlay_id(20, 20, 54), "Station decay fixture sets its microsim label")
	_check(station.city.set_tile_flag(20, 20, 0xe2, true), "Station decay fixture sets utility and flip flags")
	_check(station.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Station decay fixture removes funding")
	var station_result := Growth.run(station.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(station_result.ok and station_result.removed_subway_stations == 1, "Unfunded subway station is removed")
	_check(station_result.decayed_subway_tiles == 1, "Station removal counts one decayed subway tile")
	_check(station.city.building_id(20, 20) == 1, "Station decay makes process-selected rubble")
	_check(station.city.underground_id(20, 20) == 0, "Station decay clears its entrance")
	_check(station.city.text_overlay_id(20, 20) == 0, "Station decay clears its fixed microsim overlay")
	_check(
		station.city.tile_flags[20 * 128 + 20] == 0x20,
		"Station decay clears powered, powerable, and flip flags",
	)
	_check(station.document.misc_u32(0x0fe8) == 0, "Station decay decrements the subway count")

	var bridge := _maintenance_fixture(reference_root, 0x51, 0)
	for x in range(18, 25):
		for y in range(19, 22):
			_check(bridge.city.set_land_altitude(x, y, 0), "Bridge decay fixture levels the waterbed")
	for x in range(20, 23):
		_check(bridge.city.set_building_id(x, 20, 0x51), "Bridge decay fixture places a span tile")
		_check(bridge.city.set_terrain_id(x, 20, 0x30), "Bridge decay fixture places water terrain")
		_check(bridge.city.set_tile_flag(x, 20, 0x06, true), "Bridge decay fixture marks horizontal water")
	for x in [19, 23]:
		_check(bridge.city.set_building_id(x, 20, 0x1d), "Bridge decay fixture places a bank road")
		_check(bridge.city.set_land_altitude(x, 20, 1), "Bridge decay fixture raises a bank")
	_check(bridge.document.set_misc_u32(0x01f0, 16379), "Bridge decay fixture counts clear tiles")
	_check(bridge.document.set_misc_u32(0x01f0 + 0x51 * 4, 3), "Bridge decay fixture counts span tiles")
	_check(bridge.document.set_misc_u32(0x01f0 + 0x1d * 4, 2), "Bridge decay fixture counts bank roads")
	_check(bridge.document.set_misc_u32(0x0e40, 1), "Bridge decay fixture sets sea level")
	_check(bridge.document.set_misc_i32(0x077c + 12 * 0x6c + 4, 0), "Bridge decay fixture removes funding")
	var bridge_result := Growth.run(bridge.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(bridge_result.ok and bridge_result.collapsed_bridges == 1, "Unfunded bridge span collapses")
	_check(bridge_result.deferred_bridge_effects == 1, "Bridge collapse reports pending news and visual effects")
	for x in range(20, 23):
		_check(bridge.city.building_id(x, 20) == 0, "Bridge collapse clears each span tile")
	for x in [19, 23]:
		_check(bridge.city.building_id(x, 20) == 0, "Bridge collapse clears a bank road")
		_check(
			bridge.city.land_altitude(x, 20) == 0,
			"Bridge collapse lowers a dry bank: %d" % bridge.city.land_altitude(x, 20),
		)
		_check(
			bridge.city.tile_flags[x * 128 + 20] & 0x04 != 0,
			"Bridge collapse restores bank water: 0x%02x" % bridge.city.tile_flags[x * 128 + 20],
		)
	_check(bridge.document.misc_u32(0x01f0 + 0x51 * 4) == 0, "Bridge collapse clears its tile count")

	var reinforced := _maintenance_fixture(reference_root, 0x6a, 0)
	_check(reinforced.document.set_misc_i32(0x077c + 12 * 0x6c + 4, 0), "Reinforced bridge fixture removes funding")
	var reinforced_result := Growth.run(
		reinforced.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new()
	)
	_check(reinforced_result.ok and reinforced_result.deferred_bridge_collapses == 1, "Reinforced bridge collapse stays explicit")
	_check(reinforced.city.building_id(20, 20) == 0x6a, "Deferred reinforced bridge stays unchanged")

	var funded := _maintenance_fixture(reference_root, 0x1d, 0)
	var funded_result := Growth.run(funded.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(funded_result.ok and funded_result.decayed_roads == 0, "Full road funding prevents decay")
	_check(funded.city.building_id(20, 20) == 0x1d, "Full road funding preserves the road")


func _maintenance_fixture(reference_root: String, surface_tile: int, underground_tile: int) -> Dictionary:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var buildings := _filled_bytes(128 * 128, 0)
	var zones := _filled_bytes(128 * 128, 0)
	var underground := _filled_bytes(128 * 128, 0)
	var flags := _filled_bytes(128 * 128, 0)
	var index := 20 * 128 + 20
	buildings[index] = surface_tile
	underground[index] = underground_tile
	for entry in [
		["XBLD", buildings],
		["XZON", zones],
		["XUND", underground],
		["XBIT", flags],
		["XTRF", _filled_bytes(64 * 64, 0)],
		["XVAL", _filled_bytes(64 * 64, 0)],
	]:
		_check(document.find_chunk(entry[0]).set_decoded_payload(entry[1]), "Maintenance fixture sets %s" % entry[0])
	for budget_index in range(10, 16):
		_check(
			document.set_misc_i32(0x077c + budget_index * 0x6c + 4, 100),
			"Maintenance fixture fully funds budget %d" % budget_index,
		)
	_check(document.set_misc_u32(0x01f0, 16384 - int(surface_tile != 0)), "Maintenance fixture counts clear tiles")
	if surface_tile != 0:
		_check(document.set_misc_u32(0x01f0 + surface_tile * 4, 1), "Maintenance fixture counts its surface tile")
	_check(document.set_misc_u32(0x0fe8, int(underground_tile != 0)), "Maintenance fixture counts its subway tile")
	return {"document": document, "city": CityModel.from_document(document)}


func _special_growth_fixture(reference_root: String) -> Dictionary:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for entry in [
		["XBLD", _filled_bytes(128 * 128, 0)],
		["XZON", _filled_bytes(128 * 128, 0)],
		["XUND", _filled_bytes(128 * 128, 0)],
		["XTXT", _filled_bytes(128 * 128, 0)],
		["XBIT", _filled_bytes(128 * 128, 0)],
		["XTER", _filled_bytes(128 * 128, 0)],
		["XTRF", _filled_bytes(64 * 64, 0)],
		["XPLT", _filled_bytes(64 * 64, 0)],
		["XVAL", _filled_bytes(64 * 64, 0)],
		["XCRM", _filled_bytes(64 * 64, 0)],
		["XMIC", _filled_bytes(150 * 8, 0)],
		["XTHG", _filled_bytes(40 * 12, 0)],
	]:
		_check(
			document.find_chunk(entry[0]).set_decoded_payload(entry[1]),
			"Special growth fixture sets %s" % entry[0],
		)
	for tile in 256:
		_check(document.set_misc_u32(0x01f0 + tile * 4, 0), "Special growth fixture clears tile count")
	_check(document.set_misc_u32(0x01f0, 16384), "Special growth fixture counts clear tiles")
	for military_index in 16:
		_check(
			document.set_misc_u32(0x0fa8 + military_index * 4, 0),
			"Special growth fixture clears military tile count",
		)
	for budget_index in range(10, 16):
		_check(
			document.set_misc_i32(0x077c + budget_index * 0x6c + 4, 100),
			"Special growth fixture fully funds transport",
		)
	_check(document.set_misc_u32(0x0008, 0), "Special growth fixture sets compass rotation")
	_check(document.set_misc_u32(0x0e4c, 0), "Special growth fixture clears military base type")
	_check(document.set_misc_u32(0x0fe8, 0), "Special growth fixture clears the subway count")
	return {"document": document, "city": CityModel.from_document(document)}


func _growth_fixture(
	reference_root: String, origin_building: int, origin_zone: int, demand: int
) -> Dictionary:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var buildings := _filled_bytes(128 * 128, 0)
	for point in [Vector2i(20, 21), Vector2i(20, 22), Vector2i(20, 23), Vector2i(20, 24)]:
		buildings[point.x * 128 + point.y] = 0x1d
	buildings[20 * 128 + 20] = origin_building
	var zones := _filled_bytes(128 * 128, 0)
	zones[20 * 128 + 20] = 0x80 | origin_zone
	zones[20 * 128 + 25] = 3
	var flags := _filled_bytes(128 * 128, 0)
	flags[20 * 128 + 20] = 0x40
	for entry in [
		["XBLD", buildings],
		["XZON", zones],
		["XBIT", flags],
		["XUND", _filled_bytes(128 * 128, 0)],
		["XTXT", _filled_bytes(128 * 128, 0)],
		["XTRF", _filled_bytes(64 * 64, 0)],
		["XVAL", _filled_bytes(64 * 64, 0)],
	]:
		_check(
			document.find_chunk(entry[0]).set_decoded_payload(entry[1]),
			"Growth fixture sets %s" % entry[0],
		)
	for index in 8:
		_check(document.set_misc_u32(0x05f0 + index * 4, 0), "Growth fixture clears population %d" % index)
	_check(document.set_misc_i32(0x0718, demand), "Growth fixture sets residential demand")
	_check(document.set_misc_i32(0x071c, 0), "Growth fixture clears commercial demand")
	_check(document.set_misc_i32(0x0720, 0), "Growth fixture clears industrial demand")
	_check(document.set_misc_u32(0x0008, 0), "Growth fixture sets compass rotation")
	_check(document.set_misc_u32(0x102c, 0), "Growth fixture clears normal population")
	_check(document.set_misc_u32(0x01f0, 16379), "Growth fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + origin_building * 4, 1), "Growth fixture counts origin tile")
	return {"document": document, "city": CityModel.from_document(document)}


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


func _test_education_health(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for cohort in 20:
		for field in [0, 4, 8]:
			_check(
				document.set_misc_u32(0x007c + cohort * 12 + field, 0),
				"Demographic fixture clears cohort %d field %d" % [cohort, field],
			)
	for setting in [
		[0x102c, 600],
		[0x0034, 0],
		[0x0044, 0],
		[0x0048, 0],
		[0x004c, 60],
		[0x060c, 0],
		[0x077c, 400],
		[0x0fa0, 0x0760],
		[0x01f0 + 0xd1 * 4, 9],
		[0x01f0 + 0xd6 * 4, 9],
		[0x01f0 + 0xd9 * 4, 16],
		[0x077c + 7 * 0x006c + 4, 100],
		[0x077c + 8 * 0x006c + 4, 100],
		[0x077c + 9 * 0x006c + 4, 100],
		[0x007c + 2 * 12, 300],
		[0x0080 + 2 * 12, 18000],
		[0x0084 + 2 * 12, 24000],
		[0x007c + 10 * 12, 300],
		[0x0080 + 10 * 12, 18000],
		[0x0084 + 10 * 12, 24000],
	]:
		_check(
			document.set_misc_u32(setting[0], setting[1]),
			"Demographic fixture sets MISC 0x%x" % setting[0],
		)
	var city := CityModel.from_document(document)
	var result := EducationHealth.run(city, Random.new(1))
	_check(result.ok, "Education and health phase completes: %s" % result.error)
	if not result.ok:
		return
	_check(result.population == 600, "Demographic phase preserves the controlled population")
	_check(result.deaths == 0 and result.births == 0, "Healthy fixture has no deaths or births")
	_check(result.immigrants == 0 and result.emigrants == 0, "Balanced fixture needs no migration")
	_check(result.health_capacity == 26, "Hospitals and free clinics calculate health capacity")
	_check(result.school_capacity == 15, "Funded schools calculate education capacity")
	_check(result.college_capacity == 50, "Funded colleges calculate education capacity")
	_check(result.newborn_life_expectancy == 100, "Health ordinances raise newborn life expectancy")
	_check(document.misc_u32(0x007c + 2 * 12) == 295, "One sixtieth of a cohort ages each month")
	_check(document.misc_u32(0x007c + 3 * 12) == 5, "Aged residents enter the next cohort")
	_check(document.misc_u32(0x0080 + 2 * 12) == 17700, "Aging transfers source education points")
	_check(document.misc_u32(0x0080 + 3 * 12) == 450, "College capacity increases transferred education")
	_check(document.misc_u32(0x0084 + 2 * 12) == 23600, "Aging transfers source life points")
	_check(document.misc_u32(0x0084 + 3 * 12) == 400, "The next cohort receives life points")
	_check(result.workforce_population == 295, "Workforce uses cohorts four through ten")
	_check(document.misc_u32(0x0044) == 49, "Demographic phase stores workforce percentage")
	_check(document.misc_u32(0x0048) == 80, "Demographic phase stores workforce life expectancy")
	_check(document.misc_u32(0x004c) == 60, "Demographic phase stores workforce education quotient")

	var empty_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(empty_document.set_misc_u32(0x102c, 0), "Empty demographic fixture clears city population")
	_check(empty_document.set_misc_u32(0x007c, 99), "Empty demographic fixture installs a stale cohort")
	var empty_result := EducationHealth.run(CityModel.from_document(empty_document), Random.new(1))
	_check(empty_result.ok and empty_result.empty_city, "Zero population takes the empty-city path")
	_check(empty_document.misc_u32(0x007c) == 0, "Empty-city path clears demographic tables")

	var mortality_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for cohort in 20:
		for field in [0, 4, 8]:
			_check(
				mortality_document.set_misc_u32(0x007c + cohort * 12 + field, 0),
				"Mortality fixture clears cohort %d field %d" % [cohort, field],
			)
	_check(mortality_document.set_misc_u32(0x102c, 230), "Mortality fixture sets city population")
	_check(mortality_document.set_misc_u32(0x007c + 19 * 12, 240), "Mortality fixture sets oldest population")
	_check(mortality_document.set_misc_u32(0x0080 + 19 * 12, 24000), "Mortality fixture sets education points")
	var mortality_result := EducationHealth.run(
		CityModel.from_document(mortality_document), Random.new(1)
	)
	_check(mortality_result.ok, "Mortality fixture completes: %s" % mortality_result.error)
	if mortality_result.ok:
		_check(mortality_result.deaths == 10, "Mortality uses the recovered two-stage divisor")
		_check(mortality_document.misc_u32(0x007c + 19 * 12) == 230, "Mortality removes residents")
		_check(mortality_document.misc_u32(0x0080 + 19 * 12) == 23000, "Mortality removes education in proportion")

	var migration_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for cohort in 20:
		for field in [0, 4, 8]:
			_check(
				migration_document.set_misc_u32(0x007c + cohort * 12 + field, 0),
				"Migration fixture clears cohort %d field %d" % [cohort, field],
			)
	_check(migration_document.set_misc_u32(0x102c, 16), "Migration fixture sets city population")
	var migration_result := EducationHealth.run(
		CityModel.from_document(migration_document), Random.new(1)
	)
	_check(migration_result.ok, "Migration fixture completes: %s" % migration_result.error)
	if migration_result.ok:
		_check(migration_result.immigrants == 16, "Demographic phase adds missing residents")
		for cohort in range(0, 8):
			_check(
				migration_document.misc_u32(0x007c + cohort * 12) == 2,
				"Migration uses recovered cohort order at cohort %d" % cohort,
			)
		_check(migration_document.misc_u32(0x0044) == 47, "Migration updates workforce percentage")
		_check(migration_document.misc_u32(0x0048) == 59, "Migration installs default workforce life points")
		_check(migration_document.misc_u32(0x004c) == 84, "Migration installs default workforce education points")


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


func _test_demolish_command(reference_root: String) -> void:
	_check(Demolish.supports_tool(0, 0), "Demolish command supports its catalog tool")
	_check(not Demolish.supports_tool(0, 4), "Demolish command rejects De-zone")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
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
	var placement_random := GameRandom.new(11)
	var process_random := Random.new(17)
	var hospital := Buildings.apply(city, 13, 2, Vector2i(20, 20), placement_random, process_random)
	_check(hospital.ok and hospital.overlay_id == 61, "Demolish fixture places a dynamic hospital")
	var demolition_random := Random.new(29)
	var building := Demolish.apply_path(city, 0, 0, [Vector2i(20, 20)], demolition_random)
	_check(building.ok and building.action_count == 1 and building.tile_indices.size() == 9, "Demolish removes a complete 3-by-3 building")
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

	var simple_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
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
	_check(simple_city.set_building_id(10, 10, 3), "Simple demolish fixture places rubble")
	var rubble := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(rubble.ok and simple_city.building_id(10, 10) == 0, "Demolish clears rubble")
	_check(rubble.cost == 1 and simple_city.funds() == 9, "Rubble demolition charges one dollar")
	_check(Demolish.undo(simple_city, rubble, demolition_random).ok, "Rubble demolition can be undone")
	_check(simple_city.set_zone_id(10, 10, 7), "Protected demolish fixture sets military zone")
	var military := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(not military.ok and military.error.contains("eligible"), "Demolish rejects military zones")
	_check(simple_city.set_zone_id(10, 10, 0), "Highway demolish fixture clears military zone")
	_check(simple_city.set_building_id(10, 10, 0x49), "Highway demolish fixture places highway")
	var highway := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(not highway.ok and highway.error.contains("malformed"), "Demolish rejects a malformed highway section")
	_check(simple_city.set_building_id(10, 10, 0), "Highway demolition fixture removes its malformed tile")
	_check(simple_document.set_misc_i32(0x14, 500), "Highway demolition fixture sets funds")
	var placed_highway := Highways.apply(simple_city, 6, 1, Vector2i(10, 10), Vector2i(10, 10))
	_check(placed_highway.ok, "Highway demolition fixture builds one complete section")
	var removed_highway := Demolish.apply_path(simple_city, 0, 0, [Vector2i(11, 11)], demolition_random)
	_check(removed_highway.ok and removed_highway.tile_indices.size() == 4, "Demolish removes a complete 2-by-2 highway section")
	for x in range(10, 12):
		for y in range(10, 12):
			_check(simple_city.building_id(x, y) >= 1 and simple_city.building_id(x, y) <= 4, "Demolished highway becomes rubble")
	_check(Demolish.undo(simple_city, removed_highway, demolition_random).ok, "Highway demolition can be undone")
	_check(Highways.undo(simple_city, placed_highway).ok, "Highway fixture can be removed after demolition undo")

	var special_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
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
	_check(special_city.set_building_id(30, 30, 0x3f), "Tunnel demolition fixture places its first entrance")
	_check(special_city.set_building_id(28, 30, 0x41), "Tunnel demolition fixture places its second entrance")
	for x in range(28, 31):
		_check(special_city.set_tunnel_levels(x, 30, 3), "Tunnel demolition fixture stores tunnel depth")
	var tunnel := Demolish.apply_path(special_city, 0, 0, [Vector2i(30, 30)], demolition_random)
	_check(tunnel.ok and tunnel.tile_indices.size() == 3, "Demolish follows a tunnel to its paired entrance")
	_check(special_city.building_id(30, 30) == 0 and special_city.building_id(28, 30) == 0, "Tunnel demolition clears both entrances")
	for x in range(28, 31):
		_check(special_city.tunnel_levels(x, 30) == 0, "Tunnel demolition clears each saved depth")
	_check(Demolish.undo(special_city, tunnel, demolition_random).ok, "Tunnel demolition can be undone")

	for point in [Vector2i(40, 40), Vector2i(41, 40), Vector2i(41, 41)]:
		_check(special_city.set_building_id(point.x, point.y, 0xdd), "Runway demolition fixture places a connected tile")
	_check(special_city.set_building_id(45, 45, 0xdd), "Runway demolition fixture places a separate tile")
	var runway := Demolish.apply_path(special_city, 0, 0, [Vector2i(40, 40)], demolition_random)
	_check(runway.ok and runway.tile_indices.size() == 3, "Demolish removes one connected runway component")
	_check(special_city.building_id(45, 45) == 0xdd, "Runway demolition preserves a separate component")
	for point in [Vector2i(40, 40), Vector2i(41, 40), Vector2i(41, 41)]:
		_check(special_city.building_id(point.x, point.y) >= 1 and special_city.building_id(point.x, point.y) <= 4, "Demolished runway becomes rubble")
	_check(Demolish.undo(special_city, runway, demolition_random).ok, "Runway demolition can be undone")

	for point in [Vector2i(50, 50), Vector2i(50, 51)]:
		_check(special_city.set_building_id(point.x, point.y, 0xdf), "Pier demolition fixture places a connected tile")
	var pier := Demolish.apply_path(special_city, 0, 0, [Vector2i(50, 50)], demolition_random)
	_check(pier.ok and special_city.building_id(50, 50) == 0 and special_city.building_id(50, 51) == 0, "Demolish clears a connected pier component")
	_check(Demolish.undo(special_city, pier, demolition_random).ok, "Pier demolition can be undone")

	_check(special_document.set_misc_u32(0x0e40, 1), "Bridge demolition fixture sets sea level")
	for x in range(70, 73):
		_check(special_city.set_building_id(x, 70, 0x51 + x - 70), "Bridge demolition fixture places a span tile")
		_check(special_city.set_terrain_id(x, 70, 0x30), "Bridge demolition fixture places water terrain")
		_check(special_city.set_tile_flag(x, 70, 0x04, true), "Bridge demolition fixture marks span water")
		_check(special_city.set_tile_flag(x, 70, 0x02, true), "Bridge demolition fixture sets a horizontal span")
	for x in [69, 73]:
		_check(special_city.set_land_altitude(x, 70, 1), "Bridge demolition fixture raises a bank")
		_check(special_city.set_building_id(x, 70, 0x1d), "Bridge demolition fixture places a bank road")
	var bridge := Demolish.apply_path(special_city, 0, 0, [Vector2i(71, 70)], demolition_random)
	_check(bridge.ok and bridge.tile_indices.size() == 5, "Demolish clears one bridge span and its banks")
	for x in range(70, 73):
		_check(special_city.building_id(x, 70) == 0, "Bridge demolition clears each span tile")
	for x in [69, 73]:
		_check(special_city.land_altitude(x, 70) == 0, "Bridge demolition lowers each dry bank")
		_check((special_city.tile_flags[x * 128 + 70] & 0x04) != 0, "Bridge demolition restores bank water")
	_check(Demolish.undo(special_city, bridge, demolition_random).ok, "Bridge demolition can be undone")

	_check(special_city.set_terrain_id(60, 60, 0x3d), "Water demolition fixture sets water terrain")
	_check(special_city.set_tile_flag(60, 60, 0x04, true), "Water demolition fixture sets its water flag")
	var water_tile := Demolish.apply_path(special_city, 0, 0, [Vector2i(60, 60)], demolition_random)
	_check(water_tile.ok and special_city.terrain_id(60, 60) == 0, "Demolish removes surface water terrain")
	_check((special_city.tile_flags[60 * 128 + 60] & 0x04) == 0, "Water demolition clears the water flag")
	_check(Demolish.undo(special_city, water_tile, demolition_random).ok, "Water demolition can be undone")


func _test_terrain_command(reference_root: String) -> void:
	_check(TerrainTools.supports_tool(0, 1), "Terrain command supports Level Terrain")
	_check(TerrainTools.supports_tool(0, 2), "Terrain command supports Raise Terrain")
	_check(TerrainTools.supports_tool(0, 3), "Terrain command supports Lower Terrain")
	_check(not TerrainTools.supports_tool(0, 0), "Terrain command rejects Demolish")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Terrain fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_i32(0x14, 200), "Terrain fixture sets funds")
	_check(document.set_misc_u32(0x0e40, 0), "Terrain fixture sets sea level")
	_check(document.set_misc_u32(0x01f0, 16384), "Terrain fixture counts clear tiles")
	var city := CityModel.from_document(document)
	var raised := TerrainTools.apply_path(city, 0, 2, Vector2i(20, 20), [Vector2i(20, 20)])
	_check(raised.ok and city.land_altitude(20, 20) == 1, "Raise Terrain increases the selected altitude")
	_check(raised.cost == 25 and city.funds() == 175, "Raise Terrain charges each raised dependency")
	_check(city.terrain_id(20, 19) == 4 and city.terrain_id(21, 20) == 1, "Raise Terrain uses the recovered terrain shape table")
	_check(TerrainTools.undo(city, raised).ok, "Raise Terrain can be undone")
	_check(city.land_altitude(20, 20) == 0 and city.funds() == 200, "Raise undo restores altitude and funds")

	_check(city.set_land_altitude(20, 20, 1), "Lower Terrain fixture raises the selected tile")
	var lowered := TerrainTools.apply_path(city, 0, 3, Vector2i(20, 20), [Vector2i(20, 20)])
	_check(lowered.ok and city.land_altitude(20, 20) == 0, "Lower Terrain decreases the selected altitude")
	_check(lowered.cost == 25 and city.funds() == 175, "Lower Terrain charges the selected height change")
	_check(TerrainTools.undo(city, lowered).ok, "Lower Terrain can be undone")

	_check(city.set_land_altitude(30, 30, 5), "Level Terrain fixture sets the source height")
	_check(city.set_land_altitude(31, 30, 3), "Level Terrain fixture sets a lower path height")
	_check(city.set_land_altitude(31, 29, 3), "Level Terrain fixture sets the north dependency height")
	_check(city.set_land_altitude(32, 30, 3), "Level Terrain fixture sets the east dependency height")
	_check(city.set_land_altitude(31, 31, 3), "Level Terrain fixture sets the south dependency height")
	var leveled := TerrainTools.apply_path(
		city, 0, 1, Vector2i(30, 30), [Vector2i(30, 30), Vector2i(31, 30)]
	)
	_check(leveled.ok and leveled.target_altitude == 5, "Level Terrain captures the drag-start altitude")
	_check(city.land_altitude(31, 30) == 4, "Level Terrain moves a path tile one level toward its target")
	_check(TerrainTools.undo(city, leveled).ok, "Level Terrain can be undone")
	_check(city.set_land_altitude(50, 50, 1), "Lower propagation fixture sets the selected height")
	_check(city.set_land_altitude(51, 50, 3), "Lower propagation fixture sets a high neighbor")
	var propagated := TerrainTools.apply_path(city, 0, 3, Vector2i(50, 50), [Vector2i(50, 50)])
	_check(propagated.ok and city.land_altitude(50, 50) == 0, "Lower Terrain applies its selected change before propagation")
	_check(city.land_altitude(51, 50) == 2 and propagated.cost == 50, "Lower Terrain lowers a neighbor more than one level higher")
	_check(TerrainTools.undo(city, propagated).ok, "Propagated Lower Terrain can be undone")
	_check(city.set_building_id(40, 40, 0x1d), "Terrain conflict fixture places a road")
	var conflict := TerrainTools.apply_path(city, 0, 2, Vector2i(40, 40), [Vector2i(40, 40)])
	_check(not conflict.ok and conflict.error.contains("structure"), "Terrain command reports unimplemented structure conflicts")


func _test_dispatch_command(reference_root: String) -> void:
	_check(Dispatch.supports_tool(2, 0), "Dispatch command supports Police")
	_check(Dispatch.supports_tool(2, 1), "Dispatch command supports Fire")
	_check(Dispatch.supports_tool(2, 2), "Dispatch command supports Military")
	_check(not Dispatch.supports_tool(3, 0), "Dispatch command rejects another tool group")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBIT", "XTXT", "XTHG"]:
		var size := 480 if chunk_id == "XTHG" else 128 * 128
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Dispatch fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_u32(0x01f0 + 0xd2 * 4, 9), "Dispatch fixture counts one police station")
	_check(document.set_misc_u32(0x01f0 + 0xd3 * 4, 18), "Dispatch fixture counts two fire stations")
	_check(document.set_misc_u32(0x0e4c, 4), "Dispatch fixture selects a navy base")
	var things: PackedByteArray = document.find_chunk("XTHG").decoded_payload.duplicate()
	things[5 * 12] = 7
	things[5 * 12 + 3] = 5
	things[5 * 12 + 4] = 5
	_check(document.find_chunk("XTHG").set_decoded_payload(things), "Dispatch fixture stores an old police unit")
	var text: PackedByteArray = document.find_chunk("XTXT").decoded_payload.duplicate()
	text[5 * 128 + 5] = 206
	_check(document.find_chunk("XTXT").set_decoded_payload(text), "Dispatch fixture labels the old police unit")
	var city := CityModel.from_document(document)
	var available := Dispatch.availability(city)
	_check(available.ok and available.police == 1, "Police availability is station tile count divided by eight")
	_check(available.fire == 2, "Fire availability is station tile count divided by eight")
	_check(available.military == 3, "A navy base supplies three military units")

	var police := Dispatch.apply(city, 2, 0, Vector2i(10, 10), 0, true)
	_check(police.ok and police.slot_index == 1 and police.thing_index == 1, "Police dispatch resets old units and uses the first record")
	_check(city.thing(1).type == 7 and city.thing(1).x == 10 and city.thing(1).y == 10, "Police dispatch stores the XTHG unit")
	_check(city.text_overlay_id(10, 10) == 202 and city.text_overlay_id(5, 5) == 0, "Police dispatch moves the XTXT unit marker")
	_check(IsometricRenderer.dispatch_sprite_id(city, 10, 10) == 1381, "Police dispatch selects the recovered large sprite")
	_check(Dispatch.undo(city, police).ok, "Police dispatch can be undone")
	_check(city.thing(5).type == 7 and city.text_overlay_id(5, 5) == 206, "Dispatch undo restores units cleared at session start")
	police = Dispatch.apply(city, 2, 0, Vector2i(10, 10), 0, true)
	var moved_police := Dispatch.apply(city, 2, 0, Vector2i(11, 10), police.slot_index, false)
	_check(moved_police.ok and moved_police.slot_index == 1, "A second Police action wraps its one-unit cycle")
	_check(city.text_overlay_id(10, 10) == 0 and city.text_overlay_id(11, 10) == 202, "Wrapped Police dispatch relocates its unit")
	_check(Dispatch.undo(city, moved_police).ok, "Relocated Police dispatch can be undone")

	var fire := Dispatch.apply(city, 2, 1, Vector2i(20, 20), 0, false)
	_check(fire.ok and fire.available == 2 and city.thing(fire.thing_index).type == 8, "Fire dispatch adds an XTHG fire unit")
	var military := Dispatch.apply(city, 2, 2, Vector2i(21, 20), 0, false)
	_check(military.ok and military.available == 3 and city.thing(military.thing_index).type == 14, "Military dispatch adds an XTHG military unit")
	_check(Dispatch.undo(city, military).ok, "Military dispatch can be undone")
	_check(city.set_tile_flag(30, 30, 0x04, true), "Dispatch water fixture marks a water tile")
	var water := Dispatch.apply(city, 2, 1, Vector2i(30, 30), fire.slot_index, false)
	_check(not water.ok and water.error.contains("water"), "Dispatch rejects a water target")
	_check(document.set_misc_u32(0x01f0 + 0xd2 * 4, 0), "Dispatch unavailable fixture removes police capacity")
	var no_police := Dispatch.apply(city, 2, 0, Vector2i(31, 30), police.slot_index, false)
	_check(not no_police.ok and no_police.error.contains("available"), "Dispatch rejects an unavailable unit type")


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
