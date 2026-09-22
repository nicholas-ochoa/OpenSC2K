extends "res://tests/support/core_test_suite.gd"

## Simulation: aircraft ship checks.

@warning_ignore_start("integer_division")

const MovingThingTick = preload("res://src/simulation/moving_things/moving_thing_phase.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const ZeroLfsrRandom = TestRandoms.ZeroLfsrRandom
const NonzeroLfsrRandom = TestRandoms.NonzeroLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom


func run(reference_root: String) -> void:
	var airplane := _special_growth_fixture(reference_root)
	_set_airplane(airplane, 1, Vector2i(20, 20), Vector2i(20, 20), 2, 0, 0)
	_check(airplane.city.set_building_id(20, 20, Tiles.RUNWAY), "Airplane takeoff fixture places a runway")
	_check(airplane.city.set_zone_id(20, 20, 8), "Airplane takeoff fixture sets the airport zone")
	var takeoff_plane_result := MovingThingTick.run(
		airplane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		takeoff_plane_result.ok
		and takeoff_plane_result.active_airplanes == 1
		and takeoff_plane_result.moved_airplanes == 1
		and takeoff_plane_result.news_items.is_empty()
		and takeoff_plane_result.sound_events[0].sound_id == 0x206
		and takeoff_plane_result.sound_events[0].thing_type == 1
		and airplane.city.thing(1).x == 21
		and airplane.city.thing(1).z == 1,
		"Airplane takeoff moves at sixteen sub-tiles, gains height, and requests sound",
	)

	var cruising_plane := _special_growth_fixture(reference_root)
	_set_airplane(cruising_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 14)
	_check(cruising_plane.city.set_building_id(23, 20, Tiles.PLYMOUTH_ARCOLOGY), "Airplane obstacle fixture places an arcology")
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
	_check(landing_plane.city.set_building_id(21, 20, Tiles.RUNWAY), "Landing airplane fixture places its destination runway")
	var landing_plane_result := MovingThingTick.run(
		landing_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		landing_plane_result.ok
		and landing_plane_result.landed_airplanes == 1
		and landing_plane_result.news_items.is_empty()
		and landing_plane_result.sound_events[0].sound_id == 0x207
		and landing_plane_result.sound_events[0].thing_type == 1
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
	_check(low_plane.city.set_building_id(20, 20, Tiles.CORPORATE_HEADQUARTERS_3X3), "Low airplane fixture places the tallest small-map building sprite")
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
	_check(arcology_plane.city.set_building_id(20, 20, Tiles.PLYMOUTH_ARCOLOGY), "Airplane crash fixture places an arcology")
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
		and falling_result.news_items.is_empty()
		and falling_result.sound_events[0].sound_id == 0x203
		and falling_result.sound_events[0].thing_type == 1
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
	_check(docking_ship.city.set_building_id(22, 20, Tiles.PIER), "Docking ship places a pier two cells away")
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
		and depart_result.news_items.is_empty()
		and depart_result.sound_events[0].sound_id == 0x205
		and depart_result.sound_events[0].thing_type == 3
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
