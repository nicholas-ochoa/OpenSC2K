extends SceneTree

@warning_ignore_start("integer_division")

const DocumentState = preload("res://tests/support/document_state.gd")
const TimingResults = preload("res://tests/support/timing_results.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const ZeroRandom = TestRandoms.ZeroRandom
const ZeroLfsrRandom = TestRandoms.ZeroLfsrRandom

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for edge in Sc2File.MAP_SIZES:
		check_format(edge)
		check_wide_counts(edge)
		if edge in [128, 512]:
			check_values(edge)
		if edge in [16, 32, 64, 128, 512]:
			await check_sliced(edge)
		print("PASS: native data maps at %d" % edge)

	check_legacy_upgrade()
	check_malformed()
	print("Native data maps: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func native_document(edge: int) -> Sc2File:
	var doc := EmptyCityTemplate.create(edge)
	check(doc.enable_full_resolution_maps(), "Enable native maps")

	return doc


func check_format(edge: int) -> void:
	var legacy := EmptyCityTemplate.create(edge)
	var loaded := Sc2File.new()
	var source := {}

	for id in Sc2File.HALF_MAP_CHUNKS + Sc2File.QUARTER_MAP_CHUNKS:
		var data := legacy.find_chunk(id).decoded_payload.duplicate()

		for index in data.size():
			data[index] = (index * 31 + (index / 17)) % 256

		legacy.find_chunk(id).set_decoded_payload(data)
		source[id] = data

	var unknown := Sc2Chunk.new()
	unknown.chunk_id = "TEST"
	unknown.set_decoded_payload(PackedByteArray([19, 27, 33, 84]))
	legacy.chunks.append(unknown)
	var retained := legacy.duplicate_document()
	check(legacy.enable_full_resolution_maps(), "Upgrade populated grids")
	check(legacy.is_extended() and legacy.large_version == 3, "SC2X version 3 at every edge")

	for id in source:
		var data := legacy.find_chunk(id).decoded_payload
		check(data.size() == edge * edge, "Full-sized " + id)
		var scale := 2 if id in Sc2File.HALF_MAP_CHUNKS else 4

		for point in [Vector2i.ZERO, Vector2i(1, 1), Vector2i(edge - 1, edge - 1), Vector2i(maxi(0, edge - 17), edge - 11)]:
			var expected: int = source[id][(point.x / scale) * (edge / scale) + point.y / scale]
			check(data[point.x * edge + point.y] == expected, "Migration value " + id)

		check(retained.find_chunk(id).decoded_payload == source[id], "Migration leaves independent source unchanged")

	# Interior sizes still migrate every map and check values. Format rebuilds
	# use minimum, original, and maximum dimensions; small-city tests cover 32/64.
	if edge not in [16, 128, 512]:
		check(legacy.resize_empty_map(128) and legacy.full_resolution_maps(), "Resize retains native mode")
		return

	var bytes: PackedByteArray = legacy.serialize().data
	check(bytes.slice(8, 12).get_string_from_ascii() == "SCLG", "Native maps have SCLG header")
	check(loaded.parse(bytes) and loaded.full_resolution_maps() and loaded.serialize(true).data == bytes, "Native exact rebuild")
	check(loaded.find_chunk("TEST").decoded_payload == PackedByteArray([19, 27, 33, 84]), "Unknown chunk survives conversion")
	check(loaded.enable_full_resolution_maps() and DocumentState.capture(loaded) == DocumentState.capture(legacy), "Idempotent migration")
	var city := CityState.from_document(loaded)

	if edge == 128:
		for turn in 4:
			check(CityRotationCommand.apply(city, false).ok, "Rotate every native grid")
		check(DocumentState.capture(loaded) == DocumentState.capture(legacy), "Rotation cycle retains all grid bytes")
	elif edge == 512:
		check(CityRotationCommand.apply(city, false).ok, "Rotate maximum native grids")
		for id in source:
			var expected := Image.create_from_data(edge, edge, false, Image.FORMAT_L8, legacy.find_chunk(id).decoded_payload)
			# Column-major map bytes are transposed relative to image coordinates.
			expected.rotate_90(COUNTERCLOCKWISE)
			check(loaded.find_chunk(id).decoded_payload == expected.get_data(), "Every rotated native value reaches its destination: " + id)

	if edge == 128:
		var blocked := CityFileStore.save_copy(loaded, "user://native-maps-blocked.SC2", "res://../references/SIMCITY2000")
		check(not blocked.ok and not FileAccess.file_exists("user://native-maps-blocked.SC2"), "Reject lossy SC2 save")
		var path := "user://native-maps-test-%d-%d" % [OS.get_process_id(), edge]
		var saved := CityFileStore.save_copy(loaded, path, "res://../references/SIMCITY2000")
		check(saved.ok and saved.path.ends_with(".sc2x"), "Native save extension")

		if saved.ok:
			check(Sc2File.load_path(saved.path).serialize().data == bytes, "Disk round trip")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(saved.path))

	check(legacy.resize_empty_map(256 if edge == 128 else 128) and legacy.full_resolution_maps(), "Empty resize keeps native grid mode")


func check_values(edge: int) -> void:
	var doc := native_document(edge)
	var city := CityState.from_document(doc)
	var point := Vector2i(edge - 32, edge - 32)
	var index := point.x * edge + point.y
	var land := doc.find_chunk("XVAL").decoded_payload.duplicate()
	land[index] = 255
	land[index + 1] = 0
	doc.find_chunk("XVAL").set_decoded_payload(land)
	city.set_building_id(point.x, point.y, 0x70)
	city.set_building_id(point.x, point.y + 1, 0x70)
	check(GrowthConstruction.can_advance_density(2, 2, 3, land, point.x, point.y, edge), "Growth reads selected tile land value")
	check(not GrowthConstruction.can_advance_density(2, 2, 3, land, point.x, point.y + 1, edge), "Neighbor has separate growth eligibility")
	var query := QueryInfo.inspect(city, point)
	check(query.ok and query.land_value == 256, "Query reads full-resolution value")
	query = QueryInfo.inspect(city, point + Vector2i.DOWN)
	check(query.ok and query.land_value == 1, "Query separates adjacent tiles")
	check(CityMinimap._coarse_value(city, "XVAL", edge / 2, 2, point.x, point.y) == 255,
		"Map view reads native value")
	check(CityMinimap._coarse_value(city, "XVAL", edge / 2, 2, point.x, point.y + 1) == 0,
		"Map view keeps adjacent values distinct")
	var traffic := doc.find_chunk("XTRF").decoded_payload.duplicate()
	traffic[index] = 200
	traffic[index + 1] = 40
	traffic[-1] = 80
	doc.find_chunk("XTRF").set_decoded_payload(traffic)
	check(city.traffic_density(point.x, point.y) == 200 and city.traffic_density(point.x, point.y + 1) == 40,
		"Renderer reads tile-specific traffic")
	check(QueryInfo._traffic(city, traffic, point, 0x1d) == 100, "Traffic query uses selected tile")
	check(TrafficPhase.run(city).ok, "Native traffic phase")
	check(doc.find_chunk("XTRF").decoded_payload[index] == 150
		and doc.find_chunk("XTRF").decoded_payload[index + 1] == 30
		and doc.find_chunk("XTRF").decoded_payload[-1] == 60, "Traffic decay preserves per-tile extent")
	# A fire clears only the affected tile, including inside one old coarse cell.
	var p := GrowthState.payloads(city)
	var labels := doc.find_chunk("XLAB").decoded_payload.duplicate()
	var damage := DisasterDamage.apply(city, p.ALTM, p.XBLD, p.XTER, p.XZON, p.XUND,
		p.XBIT, p.XTRF, p.XTXT, labels, p.XMIC, p.MISC, point, ZeroRandom.new(), ZeroLfsrRandom.new())
	check(damage != 0 and p.XTRF[index] == 0 and p.XTRF[index + 1] == 30, "Disaster clears only selected native traffic tile")
	# All adjacent consumer rules above retain far coordinates. Full-map native
	# phase parity at 512 is owned by check_sliced and native_data_map_optimization.
	if edge > 128:
		return
	# A single source changes adjacent tile values independently.
	doc = native_document(edge)
	city = CityState.from_document(doc)
	city.set_building_id(point.x, point.y, 0xc9)

	for dx in range(-5, 6):
		for dy in range(-5, 6):
			city.set_zone_id(point.x + dx, point.y + dy, 2)

	var station := point + Vector2i(8, 0)
	city.set_building_id(station.x, station.y, PollutionPhase.POLICE_STATION)
	city.zones[station.x * edge + station.y] |= 0x80
	doc.find_chunk("XZON").set_decoded_payload(city.zones)
	city.set_tile_flag(station.x, station.y, 0x40, true)
	var started := Time.get_ticks_usec()
	var result := PollutionPhase.run(city)
	print("Native map phase %d: %d us" % [edge, Time.get_ticks_usec() - started])
	check(result.ok, "Native map phase")
	var pollution := doc.find_chunk("XPLT").decoded_payload
	check(pollution[index] > pollution[index + 1] and pollution[index + 1] > 0, "Pollution source and neighbor differ")
	land = doc.find_chunk("XVAL").decoded_payload
	check(land[index] != land[index + 1], "Land value is calculated per tile")
	var police := doc.find_chunk("XPLC").decoded_payload
	var station_index := station.x * edge + station.y
	check(police[station_index] > police[station_index + 1] and police[station_index + 1] > police[station_index + 2], "Service coverage changes each tile")
	check(police[station_index + 16] == 0, "Service radius remains in physical tile units")
	# Run moving objects and disasters with full-size grids.
	check(MovingThingPhase.run(city, SimRandom.new(1), SimLfsrRandom.new(2), GameLcgRandom.new(3)).ok, "Native moving phase")
	check(WeatherDisasterPhase._toxic_spill_point(pollution, ZeroLfsrRandom.new(), edge).x == -1, "Low pollution is not a toxic source")
	pollution[index] = 200
	check(WeatherDisasterPhase._toxic_spill_point(pollution, ZeroLfsrRandom.new(), edge) == point - Vector2i(5, 5), "Toxic selector scans native coordinates")

	# Check population, growth, and crime values per tile in a dense district.
	doc = native_document(edge)
	city = CityState.from_document(doc)

	for dx in range(-3, 4):
		for dy in range(-3, 4):
			city.set_building_id(point.x + dx, point.y + dy, 0x93)
			city.set_zone_id(point.x + dx, point.y + dy, 4)

	var old_growth := doc.find_chunk("XROG").decoded_payload[index]
	var old_population := doc.find_chunk("XPOP").decoded_payload[index]
	check(PollutionPhase.run(city).ok, "Dense district native phase")
	var population := doc.find_chunk("XPOP").decoded_payload
	var growth := doc.find_chunk("XROG").decoded_payload
	var crime := doc.find_chunk("XCRM").decoded_payload
	check(population[index + 2] > population[index + 3], "Adjacent population cells differ")
	check(growth[index + 2] > growth[index + 3], "Adjacent growth cells differ")
	check(crime[index + 2] > crime[index + 3], "Adjacent crime cells differ")
	check(growth[index] == clampi((old_growth * 7 + (int(population[index]) - old_population) * 8 + 128) / 8, 0, 255),
		"Growth uses previous per-tile state")


func check_legacy_upgrade() -> void:
	var doc := EmptyCityTemplate.create(256)
	doc.large_version = 1

	for id in ["XTXT", "XMIC", "XLAB", "XTHG"]:
		var chunk := doc.find_chunk(id)
		chunk.expected_decoded_size = doc.decoded_size(id)
		var data := PackedByteArray()
		data.resize(chunk.expected_decoded_size)
		chunk.set_decoded_payload(data)

	check(doc.enable_full_resolution_maps() and doc.large_version == 3, "Direct v1 to v3 conversion")
	check(doc.find_chunk("XTHG").decoded_payload.size() == 160 * 24, "Direct conversion widens records")
	var loaded := Sc2File.new()
	check(loaded.parse(doc.serialize().data) and CityState.from_document(loaded).is_valid(), "Direct conversion reloads")


func check_wide_counts(edge: int) -> void:
	var doc := EmptyCityTemplate.create(edge)
	doc.set_misc_u32(MicrosimAnnualPhase.MISC_TILE_COUNTS + 0xd2 * 4, 40000)
	var misc := doc.find_chunk("MISC").decoded_payload
	var expected := -25536 if edge == 128 else 40000
	check(MicrosimAnnualPhase._tile_count(misc, 0xd2, edge) == expected, "Annual tile count width")
	check(WeatherDisasterPhase._tile_count(misc, 0xd2, edge) == expected, "Weather tile count width")
	doc.set_misc_u32(MicrosimAnnualPhase.MISC_NORMAL_POPULATION, 65536 * 900)
	misc = doc.find_chunk("MISC").decoded_payload
	expected = 0 if edge == 128 else 200
	check(MicrosimAnnualPhase._population_cap(misc, 200, 900, edge) == expected, "Annual population availability does not wrap")
	check(BuildingFacilities.population_cap(misc, 200, 900, edge) == expected, "Placement population availability does not wrap")
	doc.set_misc_u32(RciAftermathPhase.MISC_TILE_COUNTS + RciAftermathPhase.STADIUM_TILE * 4, 40000)
	doc.set_misc_u32(RciAftermathPhase.MISC_STADIUM_TEAMS, 1)
	var news: Array = []
	RciAftermathPhase._append_general_news(ZeroRandom.new(), doc.find_chunk("MISC").decoded_payload,
		doc.find_chunk("XGRP").decoded_payload, news, edge)
	check(news.has({"type": RciAftermathPhase.NEWS_SPORTS, "argument": 0}) == (edge != 128),
		"Sports news uses wide stadium count")
	var micro := doc.find_chunk("XMIC").decoded_payload.duplicate()
	BuildingFacilities.initialize_microsim(micro, misc, 10, 0xd0, 1900, SimRandom.new(1), false, false, edge)
	check((micro[10 * 8 + 2] * 256 + micro[10 * 8 + 3]) == expected, "Placement passes map size to population cap")


func check_sliced(edge: int) -> void:
	var doc := native_document(edge)
	var city := CityState.from_document(doc)
	city.set_age_in_days(1)
	city.set_building_id(edge - 16, edge - 16, 0xc9)
	city.set_no_disasters_enabled(true)
	city.set_auto_budget_enabled(true)
	var other := CityState.from_document(doc.duplicate_document())
	var sync := GameSpeedController.new(SimulationEngine.new(city, 123, 456, 789))
	var sliced := GameSpeedController.new(SimulationEngine.new(other, 123, 456, 789))
	sync.set_speed(GameSpeedController.Speed.CHEETAH)
	sliced.set_speed(GameSpeedController.Speed.CHEETAH)
	var runner := FrameSimulationRunner.new(sliced)
	runner.budget_usec = 16000
	var expected := sync.advance_time(200, 200)
	var actual := runner.advance_time(200, 200)
	var deadline := Time.get_ticks_msec() + 30000

	while runner.is_pending() and Time.get_ticks_msec() < deadline:
		await process_frame
		actual = runner.advance_time(0, 200)

	check(not runner.is_pending() and TimingResults.without_timings(actual) == TimingResults.without_timings(expected), "Native sliced events match synchronous events")
	check(DocumentState.capture(other.document) == DocumentState.capture(doc), "Native sliced bytes match synchronous bytes")
	runner.close()

	# Monthly dispatch is covered by large_city_simulation_test_native_maps.


func check_malformed() -> void:
	var doc := native_document(128)
	var bytes: PackedByteArray = doc.serialize().data
	var bad := bytes.duplicate()
	bad[23] = 2
	check(not Sc2File.new().parse(bad), "Reject SCLG v2 at edge 128")
	bad = bytes.duplicate()
	bad[23] = 4
	check(not Sc2File.new().parse(bad), "Reject unknown native version")
	var coarse := EmptyCityTemplate.create(256)
	bad = coarse.serialize().data
	bad[23] = 3
	check(not Sc2File.new().parse(bad), "Reject coarse payload sizes with native version header")
	var incomplete := EmptyCityTemplate.create(128)
	incomplete.chunks.erase(incomplete.find_chunk("XVAL"))
	var before: PackedByteArray = incomplete.serialize().data
	check(not incomplete.enable_full_resolution_maps() and incomplete.serialize().data == before, "Failed conversion is atomic")
	check(not CityDataGrid.valid(PackedByteArray([1, 2, 3]), 128), "Reject malformed grid")
