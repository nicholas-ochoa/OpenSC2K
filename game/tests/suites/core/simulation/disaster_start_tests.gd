extends "res://tests/support/core_test_suite.gd"

## Simulation: disaster start checks.

@warning_ignore_start("integer_division")

const Pollution = preload("res://src/simulation/data_maps/pollution_phase.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const SequenceLfsrRandom = TestRandoms.SequenceLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom
const PowerDisasterTests = preload("res://tests/suites/core/simulation/power_disaster_tests.gd")
const WidespreadDisasterTests = preload("res://tests/suites/core/simulation/widespread_disaster_tests.gd")


func test_disaster_start_phase(reference_root: String) -> void:
	var monster_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var things := _filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)
	things[CityState.THING_RECORD_SIZE] = 14
	things[CityState.THING_RECORD_SIZE + 3] = 20
	things[CityState.THING_RECORD_SIZE + 4] = 20
	things[CityState.THING_RECORD_SIZE + 10] = 42
	_check(monster_document.find_chunk("XTHG").set_decoded_payload(things), "Monster start fixture installs an occupied record")
	var text := _filled_bytes(CityState.TILE_COUNT, 0)
	text[20 * CityState.MAP_SIZE + 20] = 202
	_check(monster_document.find_chunk("XTXT").set_decoded_payload(text), "Monster start fixture links the occupied record")
	var monster_city := CityModel.from_document(monster_document)
	var monster_random := SequenceRandom.new([3, 4, 0, 2])
	var monster := DisasterStart.start(monster_city, DisasterStart.DISASTER_MONSTER, Vector2i(20, 20), monster_random)
	_check(
		monster.ok
		and monster.started
		and monster.complete
		and monster.record == 1
		and SoundEvent.same_arrays(monster.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and monster.view_center_requests == [Vector2i(20, 20)],
		"Monster disaster replaces an occupied moving object and reports runtime effects",
	)
	var monster_thing := monster_city.thing(1)
	_check(
		monster_thing.type == 5
		and monster_thing.direction == 2
		and monster_thing.state == 0
		and monster_thing.x == 20
		and monster_thing.y == 20
		and monster_thing.z == 15
		and monster_thing.px == 8
		and monster_thing.py == 8,
		"Monster disaster stores its fixed initial XTHG fields",
	)
	_check(
		monster_thing.dx == 3
		and monster_thing.dy == 4
		and monster_thing.label == 42
		and monster_thing.goal == 3
		and monster_city.text_overlay_id(20, 20) == 202,
		"Monster disaster stores its random fields, prior label, goal, and XTXT link",
	)
	_check(DisasterStartObjectsState.has_active_object(monster_city, DisasterStart.DISASTER_MONSTER), "Monster activity is visible to the disaster controller")

	var fire_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var fire_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	var fire_point := Vector2i(60, 69)
	fire_buildings[fire_point.x * CityState.MAP_SIZE + fire_point.y] = Tiles.LOWER_CLASS_HOMES_1X1_1
	_check(
		fire_document.find_chunk("XBLD").set_decoded_payload(fire_buildings)
		and fire_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and fire_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and fire_document.find_chunk("XTRF").set_decoded_payload(_filled_bytes(64 * 64, 9))
		and fire_document.set_misc_u32(DisasterStart.MISC_CITY_CENTER_X, 60)
		and fire_document.set_misc_u32(DisasterStart.MISC_CITY_CENTER_Y, 70),
		"Fire start fixture installs a building north of the city center",
	)
	var fire_city := CityModel.from_document(fire_document)
	var fire_random := SequenceRandom.new([20, 20])
	var fire_lfsr := SequenceLfsrRandom.new([])
	var fire := DisasterStart.start(
		fire_city, DisasterStart.DISASTER_FIRE, Vector2i.ZERO, fire_random, fire_lfsr
	)
	_check(
		fire.ok
		and fire.started
		and fire.complete
		and fire.point == fire_point
		and SoundEvent.same_arrays(fire.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and fire.view_center_requests == [fire_point],
		"Fire starts at the first suitable point in the center spiral",
	)
	_check(
		fire_city.building_id(fire_point.x, fire_point.y) == 0x70
		and fire_city.text_overlay_id(fire_point.x, fire_point.y) == 0xff
		and fire_document.find_chunk("XTRF").decoded_payload[30 * 64 + 34] == 0,
		"Fire marks XTXT, clears coarse traffic, and preserves the source building",
	)
	_check(
		fire_random.position == 2 and fire_lfsr.position == 0,
		"A first-point fire consumes only the two process-random center offsets",
	)

	var flood_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var flood_terrain := _filled_bytes(CityState.TILE_COUNT, 0)
	var flood_source := Vector2i(20, 20)
	flood_terrain[flood_source.x * CityState.MAP_SIZE + flood_source.y] = 0x20
	_check(
		flood_document.find_chunk("XTER").set_decoded_payload(flood_terrain)
		and flood_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and flood_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"Flood start fixture installs one shoreline terrain cell",
	)
	var flood_city := CityModel.from_document(flood_document)
	var flood_lfsr := SequenceLfsrRandom.new([])
	var flood := DisasterStart.start(
		flood_city,
		DisasterStart.DISASTER_FLOOD,
		flood_source,
		SequenceRandom.new([]),
		flood_lfsr
	)
	_check(
		flood.ok
		and flood.started
		and flood.point == flood_source
		and flood.map_counter == 60
		and SoundEvent.same_arrays(flood.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_FLOOD, DisasterStart.SOUND_SIREN]))
		and flood.view_center_requests == [flood_source],
		"Flood starts on the first shoreline terrain cell and reports its runtime state",
	)
	_check(
		flood_city.text_overlay_id(19, 20) == 0
		and flood_city.text_overlay_id(20, 19) == 0
		and flood_city.text_overlay_id(21, 20) == 0xfc
		and flood_city.text_overlay_id(20, 21) == 0xfc
		and flood_lfsr.position == 0,
		"A radius-zero flood preserves the supplied east-and-south seeding asymmetry",
	)

	var toxic_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(
		toxic_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"Toxic-spill start fixture clears XTXT",
	)
	var toxic_city := CityModel.from_document(toxic_document)
	var toxic_point := Vector2i(30, 31)
	var toxic_start := DisasterStart.start(
		toxic_city,
		DisasterStart.DISASTER_TOXIC_SPILL,
		toxic_point,
		SequenceRandom.new([]),
	)
	_check(
		toxic_start.ok
		and toxic_start.started
		and toxic_start.complete
		and toxic_start.point == toxic_point
		and SoundEvent.same_arrays(toxic_start.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and toxic_start.view_center_requests == [toxic_point]
		and toxic_city.text_overlay_id(toxic_point.x, toxic_point.y) == DisasterMap.TOXIC_OVERLAY,
		"Toxic Spill writes XTXT 0xFB directly at the requested point",
	)
	var outside_toxic := DisasterStart.start(
		toxic_city,
		DisasterStart.DISASTER_TOXIC_SPILL,
		Vector2i(-1, 31),
		SequenceRandom.new([]),
	)
	_check(
		outside_toxic.ok and not outside_toxic.started and outside_toxic.complete,
		"Toxic Spill rejects an out-of-map compatibility API point",
	)

	var pollution_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var pollution_text := _filled_bytes(CityState.TILE_COUNT, 0)
	var pollution_point := Vector2i(10, 10)
	pollution_text[pollution_point.x * CityState.MAP_SIZE + pollution_point.y] = 201
	_check(
		pollution_document.find_chunk("XTXT").set_decoded_payload(pollution_text)
		and pollution_document.set_misc_u32(DisasterStart.MISC_NORMAL_POPULATION, 30000),
		"Pollution start fixture sets its population and an occupied overlay",
	)
	var pollution_city := CityModel.from_document(pollution_document)
	var pollution_values: Array[int] = [
		4, 4, 7, 4, 0, 0, 4, 4,
		4, 4, 4, 4, 4, 4, 4, 4,
	]
	var pollution_random := SequenceRandom.new(pollution_values)
	var pollution_start := DisasterStart.start(
		pollution_city,
		DisasterStart.DISASTER_POLLUTION,
		pollution_point,
		pollution_random,
	)
	_check(
		pollution_start.ok
		and pollution_start.started
		and pollution_start.complete
		and pollution_start.counters.attempt_count == 8
		and pollution_start.counters.seed_writes == 8
		and SoundEvent.same_arrays(pollution_start.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and pollution_start.view_center_requests == [pollution_point],
		"Pollution uses normal population for its seed count and reports a start",
	)
	_check(
		pollution_city.text_overlay_id(10, 10) == DisasterMap.TOXIC_OVERLAY
		and pollution_city.text_overlay_id(13, 10) == DisasterMap.TOXIC_OVERLAY
		and pollution_city.text_overlay_id(6, 6) == DisasterMap.TOXIC_OVERLAY
		and pollution_random.position == 16,
		"Pollution consumes two random values per attempt and overwrites valid XTXT cells",
	)
	var missed_pollution_random := SequenceRandom.new([
		4, 4, 4, 4, 4, 4, 4, 4,
		4, 4, 4, 4, 4, 4, 4, 4,
	])
	var missed_pollution := DisasterStart.start(
		pollution_city,
		DisasterStart.DISASTER_POLLUTION,
		Vector2i(-10, -10),
		missed_pollution_random,
	)
	_check(
		missed_pollution.ok
		and not missed_pollution.started
		and missed_pollution.complete
		and missed_pollution.counters.attempt_count == 8
		and missed_pollution.counters.seed_writes == 0
		and missed_pollution.sound_events.is_empty()
		and missed_pollution_random.position == 16,
		"Pollution consumes all attempts but does not start when every seed is outside the map: %s pos=%d"
		% [missed_pollution, missed_pollution_random.position],
	)

	var riot_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var riot_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)

	for y in [19, 18, 17]:
		riot_buildings[20 * CityState.MAP_SIZE + y] = Tiles.ROAD_STRAIGHT_1

	_check(
		riot_document.find_chunk("XBLD").set_decoded_payload(riot_buildings)
		and riot_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and riot_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"Riot start fixture installs three northbound road cells",
	)
	var riot_city := CityModel.from_document(riot_document)
	var riot_random := SequenceRandom.new([0, 1, 0])
	var riot_start := DisasterStart.start(
		riot_city, DisasterStart.DISASTER_RIOT, Vector2i(20, 20), riot_random
	)
	_check(
		riot_start.ok
		and riot_start.started
		and riot_start.complete
		and riot_start.counters.seed_writes == 3
		and riot_start.seed_points == [Vector2i(20, 19), Vector2i(20, 18), Vector2i(20, 17)]
		and riot_start.point == Vector2i(20, 17)
		and riot_start.view_center_requests == [Vector2i(20, 17)],
		"Riot makes three spiral starts and keeps the last successful point",
	)
	_check(
		riot_city.text_overlay_id(20, 19) == DisasterStart.RIOT_OVERLAY_FORWARD
		and riot_city.text_overlay_id(20, 18) == DisasterStart.RIOT_OVERLAY_REVERSE
		and riot_city.text_overlay_id(20, 17) == DisasterStart.RIOT_OVERLAY_FORWARD
		and SoundEvent.same_arrays(riot_start.sound_events, SoundEvent.from_ids([
			DisasterStart.SOUND_RIOT,
			DisasterStart.SOUND_RIOT,
			DisasterStart.SOUND_RIOT,
			DisasterStart.SOUND_SIREN,
		]))
		and riot_random.position == 3,
		"Riot uses one orientation bit and sound request for each seeded marker",
	)

	var rejected_riot_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	var rejected_riot_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	rejected_riot_buildings[20 * CityState.MAP_SIZE + 20] = Tiles.ROAD_STRAIGHT_1
	rejected_riot_buildings[20 * CityState.MAP_SIZE + 19] = Tiles.POWER_LINE_CROSSROADS
	_check(
		rejected_riot_document.find_chunk("XBLD").set_decoded_payload(
			rejected_riot_buildings
		)
		and rejected_riot_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and rejected_riot_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"Rejected riot fixture keeps only the origin and a tile below the supported range",
	)
	var rejected_riot_random := SequenceRandom.new([1])
	var rejected_riot := DisasterStart.start(
		CityModel.from_document(rejected_riot_document),
		DisasterStart.DISASTER_RIOT,
		Vector2i(20, 20),
		rejected_riot_random,
	)
	_check(
		rejected_riot.ok
		and not rejected_riot.started
		and rejected_riot.complete
		and rejected_riot.counters.seed_writes == 0
		and rejected_riot_random.position == 0,
		"Riot excludes its origin and XBLD below 0x1D without consuming random state",
	)

	var mass_riot_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	_check(
		mass_riot_document.find_chunk("XBLD").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0x1d)
		)
		and mass_riot_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and mass_riot_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and mass_riot_document.set_misc_u32(DisasterStart.MISC_NORMAL_POPULATION, 20000),
		"Mass-riot fixture installs a dry road map and normal population",
	)
	var mass_riot_values: Array[int] = []

	for x_value in [16, 20, 24, 28, 0, 4, 8]:
		mass_riot_values.append_array([x_value, 16, x_value & 1])

	var mass_riot_random := SequenceRandom.new(mass_riot_values)
	var mass_riot_city := CityModel.from_document(mass_riot_document)
	var mass_riot_start := DisasterStart.start(
		mass_riot_city,
		DisasterStart.DISASTER_MASS_RIOTS,
		Vector2i(64, 64),
		mass_riot_random,
	)
	_check(
		mass_riot_start.ok
		and mass_riot_start.started
		and mass_riot_start.counters.attempt_count == 7
		and mass_riot_start.counters.seed_writes == 7
		and mass_riot_start.point == Vector2i(56, 63)
		and mass_riot_random.position == 21,
		"Mass Riots uses population plus five attempts and three random values per successful seed",
	)
	_check(
		mass_riot_city.text_overlay_id(64, 63) == DisasterStart.RIOT_OVERLAY_FORWARD
		and mass_riot_city.text_overlay_id(68, 63) == DisasterStart.RIOT_OVERLAY_FORWARD
		and mass_riot_city.text_overlay_id(56, 63) == DisasterStart.RIOT_OVERLAY_FORWARD
		and mass_riot_start.sound_events.size() == 8
		and mass_riot_start.sound_events[-1].equals(SoundEvent.new(DisasterStart.SOUND_SIREN)),
		"Mass Riots stores each marker and appends the common siren after riot sounds",
	)

	var earthquake_point := Vector2i(64, 64)
	var earthquake_damage_point := Vector2i(32, 32)
	var earthquake_fixture := _fire_map_fixture(
		reference_root, earthquake_damage_point, Tiles.ROAD_STRAIGHT_1
	)
	_check(
		earthquake_fixture.city != null
		and earthquake_fixture.city.set_text_overlay_id(
			earthquake_damage_point.x, earthquake_damage_point.y, 0
		),
		"Earthquake fixture installs one eligible tile at its first offset",
	)
	var earthquake_values: Array[int] = [0, 0]

	for _gate in 4224:
		earthquake_values.append(1)

	var earthquake_random := SequenceRandom.new(earthquake_values)
	var earthquake_start := DisasterStart.start(
		earthquake_fixture.city,
		DisasterStart.DISASTER_EARTHQUAKE,
		earthquake_point,
		earthquake_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		earthquake_start.ok
		and earthquake_start.started
		and earthquake_start.complete
		and earthquake_start.counters.gate_attempts == 4225
		and earthquake_start.counters.gate_hits == 1
		and earthquake_start.counters.eligible_targets == 1
		and earthquake_start.counters.fire_damage_attempts == 1
		and earthquake_start.counters.structure_damage_attempts == 0
		and earthquake_start.map_changed,
		"Earthquake scans all 65 by 65 offsets and selects fire damage with the next random value",
	)
	_check(
		earthquake_random.position == 4226
		and earthquake_fixture.city.text_overlay_id(
			earthquake_damage_point.x, earthquake_damage_point.y
		) == DisasterMap.FIRE_OVERLAY,
		"Earthquake consumes one gate per offset and starts fire on its selected cell",
	)
	_check(
		earthquake_start.effect_events.size() == 1
		and earthquake_start.effect_events[0].type == "earthquake"
		and earthquake_start.effect_events[0].frames == 24
		and earthquake_start.effect_events[0].frame_msec == 5
		and earthquake_start.effect_events[0].distance == 4
		and earthquake_start.sound_events.size() == 25
		and earthquake_start.sound_events[0].equals(SoundEvent.new(DisasterStart.SOUND_EARTHQUAKE))
		and earthquake_start.sound_events[23].equals(SoundEvent.new(DisasterStart.SOUND_EARTHQUAKE))
		and earthquake_start.sound_events[24].equals(SoundEvent.new(DisasterStart.SOUND_SIREN))
		and earthquake_start.view_center_requests == [earthquake_point],
		"Earthquake reports its 24 shake frames, repeated sound, siren, and view center",
	)

	var empty_earthquake_fixture := _fire_map_fixture(
		reference_root, Vector2i(20, 20), Tiles.EMPTY
	)
	_check(
		empty_earthquake_fixture.city.set_text_overlay_id(20, 20, 0),
		"Empty earthquake fixture clears its inherited fire marker",
	)
	var empty_earthquake_values: Array[int] = [0]

	for _gate in 4224:
		empty_earthquake_values.append(1)

	var empty_earthquake_random := SequenceRandom.new(empty_earthquake_values)
	var empty_earthquake := DisasterStart.start(
		empty_earthquake_fixture.city,
		DisasterStart.DISASTER_EARTHQUAKE,
		Vector2i.ZERO,
		empty_earthquake_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		empty_earthquake.ok
		and empty_earthquake.started
		and not empty_earthquake.map_changed
		and empty_earthquake.counters.gate_hits == 1
		and empty_earthquake.counters.eligible_targets == 0
		and empty_earthquake_random.position == 4225,
		"Earthquake consumes its random gate before it rejects an out-of-map offset",
	)
	PowerDisasterTests.new(context).run(reference_root)
	WidespreadDisasterTests.new(context).run(reference_root)
