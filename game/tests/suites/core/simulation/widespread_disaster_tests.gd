extends "res://tests/support/core_test_suite.gd"

## Simulation: widespread disaster checks.

@warning_ignore_start("integer_division")

const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const SequenceLfsrRandom = TestRandoms.SequenceLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom
const SparseRandom = TestRandoms.SparseRandom


func run(reference_root: String) -> void:
	var volcano_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			volcano_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Volcano fixture clears %s" % chunk_id,
		)

	_check(
		volcano_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and volcano_document.set_misc_i32(0x14, 12345)
		and volcano_document.set_misc_u32(0x0e40, 0),
		"Volcano fixture clears altitude and sets city funds and sea level",
	)
	var volcano_city := CityModel.from_document(volcano_document)
	var volcano_random := SparseRandom.new({}, 0)
	var volcano := DisasterStart.start(
		volcano_city,
		DisasterStart.DISASTER_VOLCANO,
		Vector2i(64, 64),
		volcano_random,
	)
	_check(
		volcano.ok
		and volcano.started
		and volcano.complete
		and volcano.point == Vector2i(64, 64)
		and volcano.counters.successful_raises > 0
		and volcano.counters.rejected_raises == 0
		and volcano.counters.temporary_budget_spent == DisasterStart.VOLCANO_BUDGET
		and volcano.map_changed
		and volcano_city.funds() == 12345,
		"Volcano spends its separate terrain budget and preserves city funds",
	)
	_check(
		volcano_city.land_altitude(62, 62) > 0
		and volcano_city.text_overlay_id(62, 62) == DisasterMap.TOXIC_OVERLAY
		and volcano_city.text_overlay_id(48, 48) == DisasterMap.FIRE_OVERLAY
		and volcano.counters.near_toxic_writes == volcano.counters.iterations
		and volcano.counters.distant_fire_writes == volcano.counters.iterations,
		"Volcano raises its five-by-five core and writes the two recovered marker classes",
	)
	_check(
		volcano_random.position == volcano.counters.iterations * 6
		and SoundEvent.same_arrays(volcano.sound_events, SoundEvent.from_ids([
			DisasterStart.SOUND_VOLCANO,
			DisasterStart.SOUND_SIREN,
		]))
		and volcano.view_center_requests == [Vector2i(64, 64)],
		"Volcano preserves the per-iteration random order, sound gate, and view center",
	)

	var wet_volcano_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XTXT"]:
		_check(
			wet_volcano_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Wet Volcano fixture clears %s" % chunk_id,
		)

	_check(
		wet_volcano_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and wet_volcano_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0x04)
		),
		"Wet Volcano fixture clears altitude and marks every cell as water",
	)
	var wet_volcano_city := CityModel.from_document(wet_volcano_document)
	var wet_volcano_random := SparseRandom.new({}, 0)
	var wet_volcano := DisasterStart.start(
		wet_volcano_city,
		DisasterStart.DISASTER_VOLCANO,
		Vector2i(64, 64),
		wet_volcano_random,
	)
	_check(
		wet_volcano.ok
		and wet_volcano.started
		and wet_volcano.counters.iterations == 25
		and wet_volcano.counters.successful_raises == 0
		and wet_volcano.counters.rejected_raises == 25
		and wet_volcano.counters.temporary_budget_spent == DisasterStart.VOLCANO_BUDGET
		and wet_volcano_city.land_altitude(62, 62) == 0
		and wet_volcano_city.text_overlay_id(48, 48) == DisasterMap.TOXIC_OVERLAY
		and wet_volcano_random.position == 150,
		"Volcano charges 1,000 temporary dollars for each rejected water raise",
	)

	var firestorm_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			firestorm_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Firestorm fixture clears %s" % chunk_id,
		)

	_check(
		firestorm_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and firestorm_document.find_chunk("XTRF").set_decoded_payload(
			_filled_bytes(64 * 64, 9)
		),
		"Firestorm fixture clears altitude and fills traffic",
	)
	var firestorm_city := CityModel.from_document(firestorm_document)
	var firestorm_random := SparseRandom.new({})
	var firestorm_lfsr := SequenceLfsrRandom.new([])
	var firestorm := DisasterStart.start(
		firestorm_city,
		DisasterStart.DISASTER_FIRESTORM,
		Vector2i(64, 64),
		firestorm_random,
		firestorm_lfsr,
	)
	_check(
		firestorm.ok
		and firestorm.started
		and firestorm.complete
		and firestorm.counters.successful_cells == 65
		and firestorm.counters.remaining_cells == 0
		and firestorm.counters.scan_steps == 65
		and firestorm.counters.attempted_in_map == 65
		and firestorm.scan_finish == Vector2i(67, 68)
		and firestorm.map_changed,
		"Firestorm stops after 65 accepted cells on its clockwise square spiral",
	)
	_check(
		firestorm.accepted_points.size() == 65
		and firestorm.accepted_points[0] == Vector2i(64, 63)
		and firestorm.accepted_points[-1] == Vector2i(67, 68)
		and firestorm.result_codes.size() == 65
		and firestorm.result_codes.count(1) == 65
		and firestorm_city.text_overlay_id(64, 63) == DisasterMap.FIRE_OVERLAY
		and firestorm_city.text_overlay_id(67, 68) == DisasterMap.FIRE_OVERLAY,
		"Firestorm uses the shared small-tile damage option for every accepted cell",
	)
	_check(
		SoundEvent.same_arrays(firestorm.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and firestorm.view_center_requests == [Vector2i(67, 68)]
		and firestorm_random.position == 0
		and firestorm_lfsr.position == 0,
		"Clear Firestorm cells consume no random state and center the view on the last scan cell",
	)

	var blocked_firestorm_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	_check(
		blocked_firestorm_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0x04)
		),
		"Blocked Firestorm fixture marks every cell as water",
	)
	var blocked_firestorm := DisasterStart.start(
		CityModel.from_document(blocked_firestorm_document),
		DisasterStart.DISASTER_FIRESTORM,
		Vector2i(64, 64),
		SparseRandom.new({}),
		SequenceLfsrRandom.new([]),
	)
	_check(
		blocked_firestorm.ok
		and not blocked_firestorm.started
		and blocked_firestorm.complete
		and blocked_firestorm.counters.successful_cells == 0
		and blocked_firestorm.counters.scan_steps == 16256
		and blocked_firestorm.counters.attempted_in_map == 16255
		and blocked_firestorm.scan_finish == Vector2i(128, 0)
		and not blocked_firestorm.map_changed
		and blocked_firestorm.sound_events.is_empty()
		and blocked_firestorm.view_center_requests.is_empty(),
		"Firestorm reports failure after its full run-length-127 spiral finds no dry cell",
	)

	var mass_flood_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			mass_flood_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Mass Floods fixture clears %s" % chunk_id,
		)

	_check(
		mass_flood_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and mass_flood_document.find_chunk("XTRF").set_decoded_payload(
			_filled_bytes(64 * 64, 9)
		)
		and mass_flood_document.set_misc_u32(DisasterStart.MISC_NORMAL_POPULATION, 0),
		"Mass Floods fixture clears altitude and population and fills traffic",
	)
	var mass_flood_terrain := _filled_bytes(CityState.TILE_COUNT, 0)
	mass_flood_terrain[64 * CityState.MAP_SIZE + 64] = 0x20
	_check(
		mass_flood_document.find_chunk("XTER").set_decoded_payload(mass_flood_terrain),
		"Mass Floods fixture places one shoreline cell",
	)
	var mass_flood_city := CityModel.from_document(mass_flood_document)
	var mass_flood_random := SparseRandom.new({}, 16)
	var mass_flood_lfsr := SequenceLfsrRandom.new([])
	var mass_flood := DisasterStart.start(
		mass_flood_city,
		DisasterStart.DISASTER_MASS_FLOODS,
		Vector2i(64, 64),
		mass_flood_random,
		mass_flood_lfsr,
	)
	_check(
		mass_flood.ok
		and mass_flood.started
		and mass_flood.complete
		and mass_flood.counters.attempt_count == 5
		and mass_flood.counters.valid_candidates == 5
		and mass_flood.counters.seed_writes == 5
		and mass_flood.counters.delay_frames == 5
		and mass_flood.map_counter == 60
		and mass_flood.map_changed,
		"Mass Floods runs five ordinary Flood starts for a zero-population city",
	)
	_check(
		mass_flood.candidate_points.size() == 5
		and mass_flood.candidate_points.count(Vector2i(64, 64)) == 5
		and mass_flood.seed_points.size() == 5
		and mass_flood.seed_points.count(Vector2i(64, 64)) == 5
		and mass_flood_city.text_overlay_id(65, 64) == DisasterMap.FLOOD_OVERLAY
		and mass_flood_city.text_overlay_id(64, 65) == DisasterMap.FLOOD_OVERLAY,
		"Each valid Mass Floods candidate uses the ordinary shoreline and asymmetric seed rules",
	)
	_check(
		mass_flood.sound_events.size() == 6
		and SoundEvent.count_plain(mass_flood.sound_events, DisasterStart.SOUND_FLOOD) == 5
		and mass_flood.sound_events[-1].equals(SoundEvent.new(DisasterStart.SOUND_SIREN))
		and mass_flood.view_center_requests == [Vector2i(64, 64)]
		and mass_flood_random.position == 10
		and mass_flood_lfsr.position == 0,
		"Mass Floods preserves candidate random order, flood sounds, and the original view center",
	)

	var invalid_mass_flood_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	_check(
		invalid_mass_flood_document.set_misc_u32(
			DisasterStart.MISC_NORMAL_POPULATION, 0
		),
		"Invalid Mass Floods fixture clears normal population",
	)
	var invalid_mass_flood_random := SparseRandom.new({}, 0)
	var invalid_mass_flood_lfsr := SequenceLfsrRandom.new([])
	var invalid_mass_flood := DisasterStart.start(
		CityModel.from_document(invalid_mass_flood_document),
		DisasterStart.DISASTER_MASS_FLOODS,
		Vector2i.ZERO,
		invalid_mass_flood_random,
		invalid_mass_flood_lfsr,
	)
	_check(
		invalid_mass_flood.ok
		and not invalid_mass_flood.started
		and invalid_mass_flood.complete
		and invalid_mass_flood.counters.attempt_count == 5
		and invalid_mass_flood.counters.valid_candidates == 0
		and invalid_mass_flood.counters.seed_writes == 0
		and invalid_mass_flood.map_counter == 0
		and not invalid_mass_flood.map_changed
		and invalid_mass_flood.sound_events.is_empty()
		and invalid_mass_flood.view_center_requests.is_empty()
		and invalid_mass_flood_random.position == 10
		and invalid_mass_flood_lfsr.position == 0,
		"Mass Floods consumes point values but skips the Flood helper for invalid candidates",
	)

	var hurricane_cases := [
		{"rotation": 3, "direction": 0, "damage": 20, "flood": 50, "lfsr": 70},
		{"rotation": 0, "direction": 1, "damage": 20, "flood": 100, "lfsr": 120},
		{"rotation": 1, "direction": 2, "damage": 10, "flood": 100, "lfsr": 110},
		{"rotation": 2, "direction": 3, "damage": 20, "flood": 50, "lfsr": 70},
	]

	for hurricane_case in hurricane_cases:
		var hurricane_document := _load_fixture(
			reference_root.path_join("DEFAULT.SC2")
		)

		for chunk_id in ["XTER", "XZON", "XUND", "XBIT", "XTXT"]:
			_check(
				hurricane_document.find_chunk(chunk_id).set_decoded_payload(
					_filled_bytes(CityState.TILE_COUNT, 0)
				),
				"Hurricane direction %d clears %s" % [hurricane_case.direction, chunk_id],
			)

		_check(
			hurricane_document.find_chunk("XBLD").set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0x1d)
			)
			and hurricane_document.find_chunk("ALTM").set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT * 2, 0)
			)
			and hurricane_document.find_chunk("XTRF").set_decoded_payload(
				_filled_bytes(64 * 64, 9)
			)
			and hurricane_document.set_misc_u32(0x08, hurricane_case.rotation),
			"Hurricane direction %d installs a uniform edge target map"
			% hurricane_case.direction,
		)
		var hurricane_values: Array[int] = []

		for value in hurricane_case.lfsr:
			hurricane_values.append(value)

		var hurricane_lfsr := SequenceLfsrRandom.new(hurricane_values)
		var hurricane_random := SequenceRandom.new([])
		var hurricane_city := CityModel.from_document(hurricane_document)
		var hurricane := DisasterStart.start(
			hurricane_city,
			DisasterStart.DISASTER_HURRICANE,
			Vector2i(64, 64),
			hurricane_random,
			hurricane_lfsr,
		)
		_check(
			hurricane.ok
			and hurricane.started
			and hurricane.complete
			and hurricane.direction == hurricane_case.direction
			and hurricane.counters.damage_scans == hurricane_case.damage
			and hurricane.counters.damage_attempts == hurricane_case.damage
			and hurricane.counters.flood_attempts == hurricane_case.flood
			and hurricane.counters.flood_writes == hurricane_case.flood
			and hurricane.map_counter == 60
			and hurricane.hurricane_counter == 50
			and hurricane.map_changed,
			"Hurricane direction %d preserves its damage and flood budgets"
			% hurricane_case.direction,
		)
		_check(
			hurricane_lfsr.position == hurricane_case.lfsr
			and hurricane.view_center_requests.is_empty()
			and hurricane.sound_events[0].equals(SoundEvent.new(DisasterStart.SOUND_HURRICANE))
			and hurricane.sound_events[-2].equals(SoundEvent.new(DisasterStart.SOUND_HURRICANE))
			and hurricane.sound_events[-1].equals(SoundEvent.new(DisasterStart.SOUND_SIREN)),
			"Hurricane direction %d preserves random use, sound order, and no view center"
			% hurricane_case.direction,
		)
		var expected_effects: int = 20 if hurricane_case.direction in [0, 3] else 0
		var last_effect_frame := (
			int(hurricane.effect_events[-1].frame)
			if not hurricane.effect_events.is_empty()
			else -1
		)
		_check(
			hurricane.effect_events.size() == expected_effects
			and SoundEvent.count_plain(hurricane.sound_events, DisasterStart.SOUND_EARTHQUAKE)
			== expected_effects
			and last_effect_frame == expected_effects - 1,
			"Hurricane direction %d emits sequential source-enabled edge damage effects"
			% hurricane_case.direction,
		)

	var fallback_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var fallback_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	fallback_buildings[12 * CityState.MAP_SIZE + 13] = Tiles.TREES_1
	_check(
		fallback_document.find_chunk("XBLD").set_decoded_payload(fallback_buildings)
		and fallback_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and fallback_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and fallback_document.set_misc_u32(DisasterStart.MISC_CITY_CENTER_X, 64)
		and fallback_document.set_misc_u32(DisasterStart.MISC_CITY_CENTER_Y, 64),
		"Fire fallback fixture installs one non-building surface tile",
	)
	var fallback_city := CityModel.from_document(fallback_document)
	var fallback_lfsr := SequenceLfsrRandom.new([12, 13])
	var fallback := DisasterStart.start(
		fallback_city,
		DisasterStart.DISASTER_FIRE,
		Vector2i(99, 99),
		SequenceRandom.new([20, 20]),
		fallback_lfsr
	)
	_check(
		fallback.ok
		and fallback.started
		and fallback.point == Vector2i(12, 13)
		and fallback_city.text_overlay_id(12, 13) == 0xff
		and fallback_lfsr.position == 2,
		"Fire falls back to two game-LFSR coordinates after the spiral fails",
	)

	var tornado_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(tornado_document.find_chunk("XTHG").set_decoded_payload(_filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)), "Tornado start fixture clears XTHG")
	_check(tornado_document.find_chunk("XTXT").set_decoded_payload(_filled_bytes(CityState.TILE_COUNT, 0)), "Tornado start fixture clears XTXT")
	var tornado_city := CityModel.from_document(tornado_document)
	_check(tornado_city.set_land_altitude(127, 0, 11), "Tornado start fixture raises the clamped point")
	var tornado := DisasterStart.start(tornado_city, DisasterStart.DISASTER_TORNADO, Vector2i(200, -3), SequenceRandom.new([5, 6, 7]))
	var tornado_thing := tornado_city.thing(1)
	_check(
		tornado.ok
		and tornado.started
		and tornado.point == Vector2i(127, 0)
		and tornado_thing.type == 15
		and tornado_thing.direction == 5
		and tornado_thing.z == 11,
		"Tornado disaster clamps its target and stores direction and terrain height",
	)
	_check(
		tornado_thing.dx == 6
		and tornado_thing.dy == 7
		and tornado_city.text_overlay_id(127, 0) == 202,
		"Tornado disaster stores its random animation fields and XTXT link",
	)

	var wrapper_before: PackedByteArray = tornado_document.find_chunk("XTHG").decoded_payload.duplicate()
	var air_wrapper := DisasterStart.start(
		tornado_city,
		DisasterStart.DISASTER_AIR_CRASH,
		Vector2i(10, 10),
		SequenceRandom.new([])
	)
	var helicopter_wrapper := DisasterStart.start(
		tornado_city,
		DisasterStart.DISASTER_HELICOPTER_CRASH,
		Vector2i(11, 11),
		SequenceRandom.new([])
	)
	_check(
		air_wrapper.ok
		and air_wrapper.started
		and air_wrapper.view_center_requests.is_empty()
		and helicopter_wrapper.ok
		and helicopter_wrapper.started
		and helicopter_wrapper.view_center_requests.is_empty(),
		"The two original no-op crash wrappers start without moving the view",
	)
	_check(
		tornado_document.find_chunk("XTHG").decoded_payload == wrapper_before,
		"The two crash wrappers preserve the supplied moving objects",
	)

	var plane_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var plane_things := _filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)
	plane_things[CityState.THING_RECORD_SIZE + 1] = 6
	plane_things[CityState.THING_RECORD_SIZE + 8] = 11
	plane_things[CityState.THING_RECORD_SIZE + 9] = 12
	plane_things[CityState.THING_RECORD_SIZE + 11] = 13
	var plane_text := _filled_bytes(CityState.TILE_COUNT, 0)
	plane_text[35 * CityState.MAP_SIZE + 36] = 50
	_check(
		plane_document.find_chunk("XTHG").set_decoded_payload(plane_things)
		and plane_document.find_chunk("XTXT").set_decoded_payload(plane_text),
		"Plane crash fixture installs one occupied random point and a stale free record",
	)
	var plane_city := CityModel.from_document(plane_document)
	var plane_lfsr := SequenceLfsrRandom.new([3, 4, 7, 8])
	var plane_crash := DisasterStart.start(
		plane_city,
		DisasterStart.DISASTER_PLANE_CRASH,
		Vector2i(99, 99),
		SequenceRandom.new([]),
		plane_lfsr
	)
	var crashing_plane := plane_city.thing(1)
	_check(
		plane_crash.ok
		and plane_crash.started
		and plane_crash.point == Vector2i(39, 40)
		and plane_crash.view_center_requests == [Vector2i(39, 40)]
		and plane_lfsr.position == 4,
		"Plane Crash retries an occupied central point and centers on the accepted point",
	)
	_check(
		crashing_plane.type == 1
		and crashing_plane.direction == 6
		and crashing_plane.state == 7
		and crashing_plane.x == 39
		and crashing_plane.y == 40
		and crashing_plane.z == 16
		and crashing_plane.px == 8
		and crashing_plane.py == 8
		and crashing_plane.dx == 11
		and crashing_plane.dy == 12
		and crashing_plane.label == 0
		and crashing_plane.goal == 13,
		"Plane Crash writes only the recovered XTHG fields and preserves stale free fields",
	)
	_check(
		plane_city.text_overlay_id(35, 36) == 50
		and plane_city.text_overlay_id(39, 40) == 202
		and DisasterStartObjectsState.has_active_object(plane_city, DisasterStart.DISASTER_PLANE_CRASH),
		"Plane Crash preserves the rejected label and links an active falling plane",
	)
