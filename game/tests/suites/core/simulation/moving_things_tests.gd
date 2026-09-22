extends "res://tests/support/core_test_suite.gd"

## Simulation: moving things checks.

@warning_ignore_start("integer_division")

const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const MovingThingTick = preload("res://src/simulation/moving_things/moving_thing_phase.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const ZeroRandom = TestRandoms.ZeroRandom
const ZeroLfsrRandom = TestRandoms.ZeroLfsrRandom
const NonzeroLfsrRandom = TestRandoms.NonzeroLfsrRandom
const SequenceLfsrRandom = TestRandoms.SequenceLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom
const AircraftShipTests = preload("res://tests/suites/core/simulation/aircraft_ship_tests.gd")
const HelicopterRailTests = preload("res://tests/suites/core/simulation/helicopter_rail_tests.gd")


func test_moving_thing_phase(reference_root: String) -> void:
	var explosion := _special_growth_fixture(reference_root)
	_set_explosion(explosion, 1, Vector2i(20, 20), 5, 0, 0)
	_check(explosion.city.set_building_id(20, 20, Tiles.NICE_APARTMENTS_2X2_2), "Explosion fixture places its center building")
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
		and first_explosion_frame.complete
		and first_explosion_frame.news_items.is_empty()
		and first_explosion_frame.sound_events[0].sound_id == 0x1f8
		and first_explosion_frame.sound_events[0].thing_type == 6
		and second_explosion_frame.ok
		and final_explosion_frame.ok,
		"Explosion record requests sound and advances through two animation frames",
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

	for point in [Vector2i(21, 20), Vector2i(20, 21), Vector2i(19, 20)]:
		_check(
			spreading_explosion.city.set_building_id(point.x, point.y, Tiles.TREES_1),
			"Spreading explosion fixture makes the target combustible",
		)

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
		spread_result.ok
		and spread_result.spread_explosion_fires == 3
		and spread_result.disaster_start_requests.size() == 1
		and spread_result.disaster_start_requests[0].type == DisasterStart.DISASTER_AIR_CRASH
		and spread_result.disaster_start_requests[0].point == Vector2i(20, 20)
		and spreading_explosion.city.disaster_type() == DisasterStart.DISASTER_AIR_CRASH,
		"A damaging airplane explosion stores its recovered Air Crash trigger",
	)
	_check(
		spreading_explosion.city.text_overlay_id(20, 20) == 0
		and spreading_explosion.city.text_overlay_id(21, 20) == 0xff
		and spreading_explosion.city.text_overlay_id(20, 21) == 0xff
		and spreading_explosion.city.text_overlay_id(19, 20) == 0xff,
		"Explosion damage rejects the cleared center and burns combustible neighbors",
	)
	_check(
		spreading_explosion.document.find_chunk("XTRF").decoded_payload[10 * 64 + 10] == 0,
		"Explosion fire clears coarse traffic",
	)

	var labeled_explosion := _special_growth_fixture(reference_root)
	_set_explosion(labeled_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(
		labeled_explosion.city.set_building_id(21, 20, Tiles.TREES_1),
		"Explosion fixture makes the labeled tile combustible",
	)
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
	_check(rubble_explosion.city.set_building_id(21, 20, Tiles.NICE_APARTMENTS_2X2_2), "Rubble explosion fixture places a building")
	_check(rubble_explosion.city.set_text_overlay_id(21, 20, 241), "Rubble explosion fixture places overlay 241")
	var rubble_result := MovingThingTick.run(
		rubble_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 0, 3, 2, 0, 3, 2, 0, 3, 2, 0])
	)
	_check(
		rubble_result.ok
		and rubble_result.rubble_explosion_hits == 1
		and rubble_explosion.city.building_id(21, 20) == 1
		and rubble_explosion.city.text_overlay_id(21, 20) == 241,
		"Explosion overlay 241 through 249 changes a combustible tile to LFSR-selected rubble once: %s %d %d"
		% [rubble_result, rubble_explosion.city.building_id(21, 20), rubble_explosion.city.text_overlay_id(21, 20)],
	)

	var facility_explosion := _special_growth_fixture(reference_root)
	_set_explosion(facility_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(facility_explosion.city.set_building_id(21, 20, Tiles.ABANDONED_1X1_2), "Facility explosion fixture places a building")
	_check(facility_explosion.document.set_misc_u32(0x01f0, 16383), "Facility explosion fixture counts occupied land")
	_check(facility_explosion.document.set_misc_u32(0x01f0 + 0x8b * 4, 1), "Facility explosion fixture counts its building")
	var facility_microsims: PackedByteArray = facility_explosion.document.find_chunk("XMIC").decoded_payload.duplicate()
	facility_microsims[10 * 8] = 0x8b
	_check(
		facility_explosion.document.find_chunk("XMIC").set_decoded_payload(facility_microsims),
		"Facility explosion fixture stores its XMIC record",
	)
	_check(facility_explosion.city.set_label(61, "Blast Facility"), "Facility explosion fixture sets its XLAB record")
	_check(facility_explosion.city.set_text_overlay_id(21, 20, 61), "Facility explosion fixture places XMIC overlay 61")
	var facility_result := MovingThingTick.run(
		facility_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 3, 2, 3, 2, 3, 2])
	)
	_check(
		facility_result.ok
		and facility_result.damaged_facilities == 1
		and facility_result.deferred_facility_explosion_hits == 0
		and facility_result.explosion_map_damage_complete,
		"Explosion applies the full linked-facility damage path once",
	)
	_check(
		facility_explosion.city.building_id(21, 20) == 2
		and facility_explosion.city.text_overlay_id(21, 20) == 0xff
		and facility_explosion.city.microsim(10).tile_id == 0
		and facility_explosion.city.label(61).is_empty(),
		"Facility blast creates rubble and fire and releases XMIC and XLAB",
	)

	var connection_explosion := _special_growth_fixture(reference_root)
	_set_explosion(connection_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(connection_explosion.city.set_building_id(21, 20, Tiles.ROAD_STRAIGHT_1), "Connection blast fixture places a road")
	_check(connection_explosion.city.set_text_overlay_id(21, 20, 250), "Connection blast fixture places a neighbor label")
	var connection_result := MovingThingTick.run(
		connection_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 3, 2, 3, 2, 3, 2])
	)
	_check(
		connection_result.ok
		and connection_result.connection_count_changes.size() == 1
		and connection_result.connection_count_changes[0].kind == "commerce"
		and connection_result.connection_count_changes[0].delta == -1
		and connection_result.connection_count_changes[0].point == Vector2i(21, 20)
		and connection_result.explosion_map_damage_complete,
		"Explosion damage reports the original commerce-connection decrement",
	)

	var tornado := _special_growth_fixture(reference_root)
	_set_tornado(tornado, 1, Vector2i(20, 20), 2)
	_check(tornado.city.set_building_id(20, 20, Tiles.ROAD_STRAIGHT_1), "Tornado fixture places a road")
	_check(tornado.document.set_misc_u32(0x01f0, 16383), "Tornado fixture counts occupied land")
	_check(tornado.document.set_misc_u32(0x01f0 + 0x1d * 4, 1), "Tornado fixture counts its road")
	var tornado_result := MovingThingTick.run(
		tornado.city,
		SequenceRandom.new([0, 1, 0, 1]),
		NonzeroLfsrRandom.new()
	)
	_check(
		tornado_result.ok
		and tornado_result.active_tornadoes == 1
		and tornado_result.tornado_demolitions == 1
		and tornado_result.moved_tornadoes == 1,
		"Tornado demolishes a structure and makes its first movement",
	)
	_check(
		tornado.city.building_id(20, 20) == 1
		and tornado.city.thing(1).px == 16
		and tornado.city.thing(1).py == 16,
		"Tornado stores rubble and its eight-unit sub-tile movement",
	)

	var fast_tornado := _special_growth_fixture(reference_root)
	_set_tornado(fast_tornado, 1, Vector2i(20, 20), 2)
	var fast_tornado_result := MovingThingTick.run(
		fast_tornado.city,
		SequenceRandom.new([0, 0, 1, 0, 0, 1]),
		NonzeroLfsrRandom.new()
	)
	_check(
		fast_tornado_result.ok
		and fast_tornado_result.moved_tornadoes == 2
		and fast_tornado.city.thing(1).x == 21
		and fast_tornado.city.thing(1).px == 8,
		"Tornado makes a second movement over a low tile",
	)

	var expired_tornado := _special_growth_fixture(reference_root)
	_set_tornado(expired_tornado, 1, Vector2i(20, 20), 2)
	var expired_tornado_result := MovingThingTick.run(
		expired_tornado.city,
		SequenceRandom.new([0, 0, 0]),
		NonzeroLfsrRandom.new()
	)
	_check(
		expired_tornado_result.ok
		and expired_tornado_result.removed_tornadoes == 1
		and expired_tornado.city.thing(1).type == 0
		and expired_tornado.city.text_overlay_id(20, 20) == 0,
		"Tornado expires on its recovered first low-byte random gate",
	)

	var maxis_man := _special_growth_fixture(reference_root)
	_set_maxis_man(maxis_man, 1, Vector2i(20, 20), 0, 241, Vector2i(30, 20))
	_check(maxis_man.city.set_text_overlay_id(30, 20, 241), "Maxis Man fixture places its fixed target")
	var maxis_result := MovingThingTick.run(
		maxis_man.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		maxis_result.ok
		and maxis_result.active_maxis_men == 1
		and maxis_result.moved_maxis_men == 2,
		"Maxis Man moves twice toward a clear fixed target",
	)
	_check(
		maxis_man.city.thing(1).x == 22
		and maxis_man.city.thing(1).y == 20
		and maxis_man.city.thing(1).direction == 2,
		"Maxis Man stores its pursuit direction and moved coordinates",
	)

	var firefighting_maxis := _special_growth_fixture(reference_root)
	_set_maxis_man(firefighting_maxis, 1, Vector2i(20, 20), 0, 241, Vector2i(21, 20))
	_check(firefighting_maxis.city.set_text_overlay_id(21, 20, 0xff), "Maxis Man fixture starts target fire")
	var firefighting_result := MovingThingTick.run(
		firefighting_maxis.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		firefighting_result.ok
		and firefighting_result.maxis_man_extinguished_fires == 1
		and firefighting_result.moved_maxis_men == 1
		and firefighting_maxis.city.thing(1).x == 21
		and firefighting_maxis.city.text_overlay_id(21, 20) == 202,
		"Maxis Man clears a fire and moves into its cell on an odd random bit",
	)

	var attacking_maxis := _special_growth_fixture(reference_root)
	_set_idle_thing(attacking_maxis, 1, Vector2i(21, 20), 14, 5)
	_set_maxis_man(attacking_maxis, 39, Vector2i(20, 20), 0, 1, Vector2i.ZERO)
	var attack_result := MovingThingTick.run(
		attacking_maxis.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		attack_result.ok
		and attack_result.maxis_man_destroyed_targets == 1
		and attack_result.maxis_man_explosions == 1
		and attack_result.news_items.is_empty()
		and attack_result.sound_events[0].sound_id == 0x1f8
		and attack_result.sound_events[0].thing_type == 16
		and attacking_maxis.city.thing(39).state == 2,
		"Maxis Man destroys its exact XTHG target on the recovered random gate",
	)
	_check(
		attacking_maxis.city.thing(1).type == 6
		and attacking_maxis.city.thing(1).direction == 0
		and attacking_maxis.city.thing(1).z == 5
		and attacking_maxis.city.text_overlay_id(21, 20) == 202,
		"Maxis Man replaces the target with a spreading explosion",
	)

	var monster := _special_growth_fixture(reference_root)
	_check(monster.document.set_misc_u32(0x1018, 30), "Monster fixture sets city-center X")
	_check(monster.document.set_misc_u32(0x101c, 20), "Monster fixture sets city-center Y")
	_set_monster(monster, 1, Vector2i(20, 20), 2, 0, 10, 0)
	var monster_result := MovingThingTick.run(
		monster.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		monster_result.ok
		and monster_result.active_monsters == 1
		and monster_result.moved_monsters == 1
		and monster.city.thing(1).z == 9
		and monster.city.thing(1).direction == 2,
		"Descending monster moves toward the saved city center",
	)

	var radioactive_monster := _special_growth_fixture(reference_root)
	_set_monster(radioactive_monster, 1, Vector2i(20, 20), 2, 1, 8, 1)
	_check(radioactive_monster.city.set_building_id(21, 21, Tiles.ABANDONED_1X1_2), "Monster damage fixture places a building")
	_check(radioactive_monster.document.set_misc_u32(0x01f0, 16383), "Monster damage fixture counts occupied land")
	_check(radioactive_monster.document.set_misc_u32(0x01f0 + 0x8b * 4, 1), "Monster damage fixture counts its building")
	var radioactive_result := MovingThingTick.run(
		radioactive_monster.city,
		SequenceRandom.new([1, 0, 0, 1, 0, 2]),
		NonzeroLfsrRandom.new()
	)
	_check(
		radioactive_result.ok
		and radioactive_result.monster_damage_hits == 1
		and radioactive_result.moved_monsters == 1
		and radioactive_result.news_items.is_empty()
		and radioactive_result.sound_events[0].sound_id == 0x202
		and radioactive_result.sound_events[0].thing_type == 5,
		"Goal-one monster demolishes its diagonal target and marks a damage effect",
	)
	_check(
		radioactive_monster.city.building_id(21, 21) == 11
		and radioactive_monster.city.thing(1).dx == 0x80,
		"Goal-one monster replaces the target with process-random radiation",
	)

	var military_monster := _special_growth_fixture(reference_root)
	_check(military_monster.document.set_misc_u32(0x1018, 30), "Monster collision fixture sets city-center X")
	_check(military_monster.document.set_misc_u32(0x101c, 20), "Monster collision fixture sets city-center Y")
	_set_monster(military_monster, 1, Vector2i(20, 20), 2, 0, 10, 0)
	_set_idle_thing(military_monster, 2, Vector2i(21, 20), 14, 0)
	var military_result := MovingThingTick.run(
		military_monster.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		military_result.ok
		and military_result.monster_military_collisions == 1
		and military_monster.city.thing(1).state == 3
		and military_monster.city.thing(1).x == 20,
		"Monster enters state three when a military unit blocks its next cell",
	)

	var fleeing_plane := _special_growth_fixture(reference_root)
	_set_airplane(fleeing_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 14)
	_set_monster(fleeing_plane, 2, Vector2i(30, 30), 2, 0, 10, 0)
	var fleeing_result := MovingThingTick.run(
		fleeing_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		fleeing_result.ok
		and fleeing_result.monster_forced_airplanes == 1
		and fleeing_plane.city.thing(1).state == 7,
		"Monster forces airplanes already scanned in the tick into falling state",
	)

	var expired_monster := _special_growth_fixture(reference_root)
	_set_monster(expired_monster, 1, Vector2i(20, 20), 2, 3, 10, 0)
	var expired_monster_result := MovingThingTick.run(
		expired_monster.city, ZeroRandom.new(), ZeroLfsrRandom.new()
	)
	_check(
		expired_monster_result.ok
		and expired_monster_result.removed_monsters == 1
		and expired_monster.city.thing(1).type == 0,
		"State-three monster expires on its LFSR modulo-100 gate",
	)
	AircraftShipTests.new(context).run(reference_root)
	HelicopterRailTests.new(context).run(reference_root)


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


func _set_tornado(
	fixture: Dictionary, record: int, point: Vector2i, direction: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 15
	things[offset + 1] = direction
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 6] = 8
	things[offset + 7] = 8
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Tornado fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Tornado fixture links its XTXT record")


func _set_maxis_man(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	state: int,
	goal: int,
	target: Vector2i
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 16
	things[offset + 1] = 2
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = 5
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = target.x
	things[offset + 9] = target.y
	things[offset + 11] = goal
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Maxis Man fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Maxis Man fixture links its XTXT record")


func _set_monster(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	direction: int,
	state: int,
	height: int,
	goal: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 5
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 11] = goal
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Monster fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Monster fixture links its XTXT record")


func _set_idle_thing(
	fixture: Dictionary, record: int, point: Vector2i, type: int, height: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = type
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Target fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Target fixture links its XTXT record")
