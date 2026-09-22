extends "res://tests/support/core_test_suite.gd"

## Simulation: helicopter rail checks.

@warning_ignore_start("integer_division")

const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const Traffic = preload("res://src/simulation/infrastructure/traffic_phase.gd")
const MovingThingTick = preload("res://src/simulation/moving_things/moving_thing_phase.gd")
const ThingAudio = preload("res://src/audio/moving_thing_audio.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const ZeroRandom = TestRandoms.ZeroRandom
const NonzeroLfsrRandom = TestRandoms.NonzeroLfsrRandom
const SequenceLfsrRandom = TestRandoms.SequenceLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom
const ZeroGameRandom = TestRandoms.ZeroGameRandom


func run(reference_root: String) -> void:
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

	var traffic_helicopter := _special_growth_fixture(reference_root)
	_set_helicopter(traffic_helicopter, 1, Vector2i(20, 20), Vector2i(40, 20), 2, 2, 10)
	_check(
		traffic_helicopter.document.find_chunk("XTRF").set_decoded_payload(_filled_bytes(64 * 64, 200)),
		"Traffic-news fixture fills the traffic map",
	)
	var first_traffic_news := MovingThingTick.run(
		traffic_helicopter.city, ZeroRandom.new(), NonzeroLfsrRandom.new(), null,
		Vector2i(-1, -1), true, 1000, 0
	)
	var throttled_traffic_news := MovingThingTick.run(
		traffic_helicopter.city, ZeroRandom.new(), NonzeroLfsrRandom.new(), null,
		Vector2i(-1, -1), true, 6000, first_traffic_news.traffic_news_deadline_msec
	)
	var resumed_traffic_news := MovingThingTick.run(
		traffic_helicopter.city, ZeroRandom.new(), NonzeroLfsrRandom.new(), null,
		Vector2i(-1, -1), true, 6001, throttled_traffic_news.traffic_news_deadline_msec
	)
	_check(
		first_traffic_news.ok
		and first_traffic_news.news_items.is_empty()
		and first_traffic_news.sound_events[0].sound_id == 0x1fe
		and first_traffic_news.sound_events[0].thing_type == 2
		and first_traffic_news.traffic_news_deadline_msec == 6000
		and throttled_traffic_news.sound_events.is_empty()
		and resumed_traffic_news.sound_events.size() == 1,
		"Helicopter sound uses the recovered strict five-second deadline",
	)
	_check(
		ThingAudio.event_sound_id(
			first_traffic_news.sound_events[0], CityViewMode.Mode.CITY, IsometricRenderer.VIEW_MEDIUM
		) == -1
		and ThingAudio.event_sound_id(
			first_traffic_news.sound_events[0], CityViewMode.Mode.UNDERGROUND, IsometricRenderer.VIEW_LARGE
		) == -1
		and ThingAudio.event_sound_id(
			first_traffic_news.sound_events[0], CityViewMode.Mode.CITY, IsometricRenderer.VIEW_LARGE
		) == 510,
		"Moving-object sound follows the object's minimum zoom and surface view",
	)

	var avoiding := _special_growth_fixture(reference_root)
	_set_helicopter(avoiding, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 10)
	_check(avoiding.city.set_building_id(23, 20, Tiles.PLYMOUTH_ARCOLOGY), "Helicopter obstacle fixture places an arcology")
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
	_check(building_crash.city.set_building_id(20, 20, Tiles.PLYMOUTH_ARCOLOGY), "Helicopter crash fixture places an arcology")
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
	var moved_sailboat: ThingRecord = moving.city.thing(1)
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
		and distress_result.news_items.is_empty()
		and distress_result.sound_events[0].sound_id == 0x20f
		and distress_result.sound_events[0].thing_type == 9,
		"Sailboat distress sets its state and requests sound 0x20f",
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
	_check(marina.city.set_building_id(21, 20, Tiles.MARINA), "Sailboat destination fixture places a marina")
	var marina_result := MovingThingTick.run(
		marina.city, ZeroRandom.new(), SequenceLfsrRandom.new([1])
	)
	_check(marina_result.ok and marina_result.removed_sailboats == 1, "Sailboat disappears when it reaches a marina")
	_check(marina.city.thing(1).type == 0, "Marina arrival releases the sailboat record")
	_check(marina.city.text_overlay_id(20, 20) == 0, "Marina arrival clears the sailboat link")

	var train := _special_growth_fixture(reference_root)

	for x in range(20, 23):
		_check(train.city.set_building_id(x, 20, Tiles.RAIL_STRAIGHT_1), "Moving train fixture places surface rail")

	_set_train(train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var train_result := MovingThingTick.run(
		train.city, ZeroRandom.new(), SequenceLfsrRandom.new([0, 1]), ZeroGameRandom.new()
	)
	_check(train_result.ok and train_result.moved_trains == 1, "Train tick advances a clear consist")
	var moved_engine: ThingRecord = train.city.thing(1)
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
	_check(station.city.set_building_id(20, 20, Tiles.RAIL_STRAIGHT_1), "Pausing train fixture places current rail")
	_check(station.city.set_building_id(21, 20, Tiles.RAIL_STRAIGHT_1), "Pausing train fixture places destination rail")
	_check(station.city.set_building_id(20, 19, Tiles.RAIL_STATION), "Pausing train fixture places an adjacent station")
	_set_train(station, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var pause_result := MovingThingTick.run(
		station.city, ZeroRandom.new(), SequenceLfsrRandom.new([1]), ZeroGameRandom.new()
	)
	_check(pause_result.ok and pause_result.paused_trains == 1, "Surface train pauses beside a station")
	_check(
		station.city.thing(1).x == 20 and station.city.thing(1).px == 21,
		"Station pause keeps the train position and destination",
	)

	var turning_train := _special_growth_fixture(reference_root)
	_check(turning_train.city.set_building_id(20, 20, Tiles.RAIL_STRAIGHT_1), "Turning train fixture places current rail")
	_check(turning_train.city.set_building_id(21, 20, Tiles.RAIL_STRAIGHT_1), "Turning train fixture places destination rail")
	_check(turning_train.city.set_building_id(21, 19, Tiles.RAIL_STRAIGHT_1), "Turning train fixture places north rail")
	_set_train(turning_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var train_turn_result := MovingThingTick.run(
		turning_train.city,
		SequenceRandom.new([0]),
		SequenceLfsrRandom.new([0, 0, 0]),
		ZeroGameRandom.new()
	)
	_check(
		train_turn_result.ok
		and train_turn_result.turned_trains == 1
		and train_turn_result.news_items.is_empty()
		and train_turn_result.sound_events[0].sound_id == 0x20c
		and train_turn_result.sound_events[0].thing_type == 10,
		"Train side turn returns the recovered random sound",
	)
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
	_check(subway_train.city.set_building_id(20, 20, Tiles.RAIL_STRAIGHT_1), "Subway train fixture places current rail")
	_check(subway_train.city.set_building_id(21, 20, Tiles.RAIL_SUBWAY_ENTRANCE_1), "Subway train fixture places a transition tile")
	_check(subway_train.city.set_underground_id(22, 20, UnderTiles.SUBWAY_LR), "Subway train fixture places its next subway")
	_set_train(subway_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var subway_train_result := MovingThingTick.run(
		subway_train.city,
		ZeroRandom.new(),
		SequenceLfsrRandom.new([0, 1]),
		ZeroGameRandom.new()
	)
	_check(subway_train_result.ok and subway_train_result.moved_trains == 1, "Train enters a subway transition")
	_check(
		subway_train.city.thing(1).type == 12
		and subway_train.city.thing(1).x == 21
		and subway_train.city.thing(1).px == 22,
		"Surface engine becomes a subway engine and plans an underground route",
	)

	var reversing_train := _special_growth_fixture(reference_root)
	_check(reversing_train.city.set_building_id(20, 20, Tiles.RAIL_STRAIGHT_1), "Reversing train fixture places its old rail")
	_check(reversing_train.city.set_building_id(21, 20, Tiles.RAIL_STRAIGHT_1), "Reversing train fixture places its current rail")
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
		ZeroGameRandom.new()
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
		ZeroGameRandom.new()
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
