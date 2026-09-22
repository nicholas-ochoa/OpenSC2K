extends "res://tests/support/core_test_suite.gd"

## Simulation: growth checks.

@warning_ignore_start("integer_division")

const Growth = preload("res://src/simulation/growth/phase/constants.gd")
const MovingThings = preload("res://src/simulation/moving_things/moving_thing_spawner.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const ZeroRandom = TestRandoms.ZeroRandom
const ZeroLfsrRandom = TestRandoms.ZeroLfsrRandom
const NonzeroLfsrRandom = TestRandoms.NonzeroLfsrRandom
const MicrosimLfsrRandom = TestRandoms.MicrosimLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom
const ZeroGameRandom = TestRandoms.ZeroGameRandom
const NonzeroGameRandom = TestRandoms.NonzeroGameRandom
const InfrastructureTests = preload("res://tests/suites/core/simulation/infrastructure_tests.gd")


func test_growth_phase(reference_root: String) -> void:
	var normal := _growth_fixture(reference_root, Tiles.LARGE_APARTMENT_BUILDING_3X3_1, 1, 2000)
	var normal_result := GrowthScan.run(normal.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(normal_result.ok, "Normal growth scan completes: %s" % normal_result.error)
	_check(normal_result.scanned_tiles == 1024, "Growth scan processes one sixteenth of the map")
	_check(normal_result.rci_tiles == 1, "Growth scan processes the controlled RCI anchor")
	_check(normal.document.misc_u32(0x05f4) == 36, "Density four adds 36 residential units")
	_check(normal_result.successful_trips == 1, "Developed zone completes its transport trip")
	_check(normal.city.building_id(20, 20) == 0xae, "Stable density-four zone keeps its building")

	var bare := _growth_fixture(reference_root, Tiles.EMPTY, 1, 2000)
	var bare_result := GrowthScan.run(bare.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(bare_result.ok, "Bare-zone growth scan completes: %s" % bare_result.error)
	_check(bare_result.started_construction == 1, "Bare powered zone starts construction")
	_check(bare.city.building_id(20, 20) == 0x88, "Bare zone gets the first construction tile")
	_check(bare.city.building_corners(20, 20) == 0xf0, "One-tile construction sets all corner bits")
	_check(
		bare.city.tile_flags[20 * 128 + 20] & 0xe0 == 0xe0,
		"Construction sets utility flags",
	)

	var declining := _growth_fixture(reference_root, Tiles.LOWER_CLASS_HOMES_1X1_1, 1, -2000)
	var decline_result := GrowthScan.run(declining.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(decline_result.ok, "Declining-zone scan completes: %s" % decline_result.error)
	_check(decline_result.abandoned_buildings == 1, "Low demand abandons the controlled building")
	_check(declining.city.building_id(20, 20) == 0x8a, "Density-one zone uses an abandoned tile")
	_check(declining.document.misc_u32(0x05f4) == 1, "Population is counted before abandonment")

	var abandoned := _growth_fixture(reference_root, Tiles.ABANDONED_1X1_1, 1, 2000)
	var recovery_result := GrowthScan.run(abandoned.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(recovery_result.ok, "Abandoned-zone scan completes: %s" % recovery_result.error)
	_check(recovery_result.recovered_buildings == 1, "High demand recovers an abandoned building")
	_check(abandoned.city.building_id(20, 20) == 0x70, "Recovered residence uses value group zero")
	_check(abandoned.document.misc_u32(0x060c) == 1, "Abandoned population is counted before recovery")

	var construction := _growth_fixture(reference_root, Tiles.CONSTRUCTION_1X1_1, 1, 2000)
	var construction_result := GrowthScan.run(
		construction.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(construction_result.ok, "Construction completion scan completes: %s" % construction_result.error)
	_check(construction_result.completed_construction == 1, "Construction completes on the controlled roll")
	_check(construction.city.building_id(20, 20) == 0x70, "Residential construction becomes occupied")

	var church := _growth_fixture(reference_root, Tiles.CONSTRUCTION_2X2_1, 1, 2000)

	for point in [Vector2i(20, 19), Vector2i(21, 19), Vector2i(21, 20)]:
		_check(church.city.set_building_id(point.x, point.y, Tiles.CONSTRUCTION_2X2_1), "Church fixture fills construction footprint")
		_check(church.city.set_zone_id(point.x, point.y, 1), "Church fixture zones construction footprint")

	_check(church.document.set_misc_u32(0x01f0 + 0xa6 * 4, 4), "Church fixture counts construction tiles")
	_check(church.document.set_misc_u32(0x01f0 + 0xf7 * 4, 0), "Church fixture clears church count")
	_check(church.document.set_misc_u32(0x102c, 1000), "Church fixture sets city population")
	var church_result := GrowthScan.run(church.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(church_result.ok, "Church growth scan completes: %s" % church_result.error)
	_check(church_result.churches_built == 1, "Residential density construction can make a church")

	for point in [Vector2i(20, 19), Vector2i(21, 19), Vector2i(20, 20), Vector2i(21, 20)]:
		_check(church.city.building_id(point.x, point.y) == 0xf7, "Church fills its two-by-two footprint")
		_check(church.city.zone_id(point.x, point.y) == 0, "Church clears the RCI zone nibble")

	test_special_zone_growth(reference_root)
	InfrastructureTests.new(context).test_transport_maintenance(reference_root)


func test_special_zone_growth(reference_root: String) -> void:
	var airport := _special_growth_fixture(reference_root)

	for x in range(20, 25):
		_check(airport.city.set_zone_id(x, 21, 8), "Airport fixture zones its runway strip")

	_check(airport.city.set_tile_flag(20, 21, 0x40, true), "Airport fixture powers its origin")
	var airport_result := GrowthScan.run(
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
	var seaport_result := GrowthScan.run(
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
	var silo_result := GrowthScan.run(silos.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
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
	var army_result := GrowthScan.run(army.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(army_result.ok, "Army growth scan completes: %s" % army_result.error)
	_check(army_result.special_growth_attempts == 1, "Army growth attempts one controlled building")
	_check(army_result.special_tiles_placed == 4, "Military growth can develop its own zone")

	for x in range(20, 22):
		for y in range(20, 22):
			_check(army.city.building_id(x, y) == 0xef, "Military placement builds parking lots")
			_check(army.city.tile_flags[x * 128 + y] & 0xf0 == 0, "Win95 military placement clears utility flags")

	var air_force := _special_growth_fixture(reference_root)

	for x in range(21, 26):
		_check(air_force.city.set_zone_id(x, 21, 7), "Air Force fixture zones its runway strip")

	_check(air_force.city.set_building_id(10, 10, Tiles.RUNWAY), "Air Force fixture places one civilian runway")
	_check(air_force.city.set_building_id(23, 21, Tiles.ROAD_STRAIGHT_1), "Air Force fixture places a military road")
	_check(air_force.city.set_terrain_id(23, 21, 1), "Air Force fixture sets terrain under the road")
	_check(air_force.city.set_underground_id(23, 21, UnderTiles.SUBWAY_LR), "Air Force fixture sets a subway under the road")
	_check(air_force.document.set_misc_u32(0x0e4c, 3), "Air Force fixture selects an air base")
	_check(air_force.document.set_misc_u32(0x01f0, 16378), "Air Force fixture counts normal clear tiles")
	_check(air_force.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Air Force fixture counts its civilian runway")
	_check(air_force.document.set_misc_u32(0x0fa8, 5), "Air Force fixture counts military other tiles")
	var air_force_result := GrowthScan.run(
		air_force.city, ZeroRandom.new(), 1, 1, NonzeroLfsrRandom.new()
	)
	_check(air_force_result.ok, "Air Force growth scan completes: %s" % air_force_result.error)
	_check(air_force_result.special_tiles_placed == 0, "Military runway cannot cross roads, slopes or subway")
	_check(air_force.city.building_id(23, 21) == 0x1d, "Military runway preserves the road")
	_check(air_force.city.terrain_id(23, 21) == 1, "Military runway preserves terrain")
	_check(air_force.city.underground_id(23, 21) == 1, "Military runway preserves subway")
	_check(air_force.document.misc_u32(0x01f0 + 0xdd * 4) == 1, "Military runways keep civilian counts separate")

	var aircraft := _special_growth_fixture(reference_root)
	_check(aircraft.city.set_zone_id(20, 20, 8), "Aircraft fixture sets an airport zone")
	_check(aircraft.city.set_building_id(20, 20, Tiles.RUNWAY), "Aircraft fixture places a runway")
	_check(aircraft.city.set_tile_flag(20, 20, 0x40, true), "Aircraft fixture powers its runway")
	_check(aircraft.document.set_misc_u32(0x01f0, 16383), "Aircraft fixture counts clear tiles")
	_check(aircraft.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Aircraft fixture counts its runway")
	var aircraft_result := GrowthScan.run(
		aircraft.city, SequenceRandom.new([1, 0, 0]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(aircraft_result.ok, "Aircraft growth scan completes: %s" % aircraft_result.error)
	_check(aircraft_result.spawned_helicopters == 1, "Powered airport runway spawns a helicopter")
	_check(aircraft.city.text_overlay_id(20, 20) == 202, "Helicopter attaches record one to its runway")
	var helicopter: ThingRecord = aircraft.city.thing(1)
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
	_check(airplane.city.set_building_id(20, 20, Tiles.RUNWAY), "Airplane fixture places a runway")
	_check(airplane.city.set_tile_flag(20, 20, 0x40, true), "Airplane fixture powers its runway")
	_check(airplane.document.set_misc_u32(0x01f0, 16383), "Airplane fixture counts clear tiles")
	_check(airplane.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Airplane fixture counts its runway")
	var airplane_result := GrowthScan.run(
		airplane.city, SequenceRandom.new([1, 0, 4, 9]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(airplane_result.ok and airplane_result.spawned_airplanes == 1, "Airport spawns an airplane")
	var plane: ThingRecord = airplane.city.thing(1)
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
	var maxis_things := _filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)
	var maxis_text := _filled_bytes(CityState.TILE_COUNT, 0)
	maxis_text[30 * CityState.MAP_SIZE + 20] = 0xff
	var spawned_maxis := MovingThings.spawn_maxis_man(
		maxis_things,
		maxis_text,
		Vector2i(18, 20),
		Vector2i(30, 20),
		241,
		7,
	)
	_check(
		spawned_maxis.spawned
		and spawned_maxis.record == 1
		and maxis_things[12] == MovingThings.TYPE_MAXIS_MAN
		and maxis_things[12 + 1] == 2
		and maxis_things[12 + 3] == 18
		and maxis_things[12 + 4] == 20
		and maxis_things[12 + 5] == 7
		and maxis_things[12 + 8] == 30
		and maxis_things[12 + 9] == 20
		and maxis_things[12 + 11] == 241
		and maxis_text[18 * CityState.MAP_SIZE + 20] == 202,
		"Debug Maxis Man dispatch stores a linked moving-object record and target",
	)
	_check(
		not MovingThings.spawn_maxis_man(
			maxis_things,
			maxis_text,
			Vector2i(17, 20),
			Vector2i(30, 20),
			241,
			7,
		).spawned,
		"Maxis Man dispatch keeps one active hero",
	)

	var ship_fixture := _special_growth_fixture(reference_root)
	_check(ship_fixture.city.set_zone_id(20, 20, 9), "Ship fixture sets a seaport zone")
	_check(ship_fixture.city.set_building_id(20, 20, Tiles.CRANE), "Ship fixture places a crane")
	_check(ship_fixture.city.set_terrain_id(2, 10, 0x10), "Ship fixture places edge water")
	var stale_ship_record: PackedByteArray = ship_fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	stale_ship_record[12 + 8] = 77
	stale_ship_record[12 + 9] = 88
	_check(
		ship_fixture.document.find_chunk("XTHG").set_decoded_payload(stale_ship_record),
		"Ship fixture sets stale target bytes",
	)
	var ship_result := GrowthScan.run(
		ship_fixture.city, SequenceRandom.new([1, 0, 0]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(
		ship_result.ok
		and ship_result.spawned_ships == 1
		and ship_result.ship_home == Vector2i(2, 10)
		and ship_result.news_items.is_empty()
		and ship_result.sound_events.size() == 1
		and ship_result.sound_events[0].sound_id == 517
		and ship_result.sound_events[0].thing_type == 3,
		"Seaport crane spawns a cargo ship and requests its immediate sound",
	)
	var ship: ThingRecord = ship_fixture.city.thing(1)
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

	test_growth_microsimulations(reference_root)


func test_growth_microsimulations(reference_root: String) -> void:
	var station := _special_growth_fixture(reference_root)
	_check(station.city.set_building_id(20, 20, Tiles.RAIL_STATION), "Train fixture places a rail station")
	_check(station.city.set_tile_flag(20, 20, 0x40, true), "Train fixture powers its station")
	_check(station.city.set_building_id(20, 18, Tiles.RAIL_STRAIGHT_1), "Train fixture places its spawn rail")
	_check(station.city.set_building_id(19, 18, Tiles.RAIL_STRAIGHT_1), "Train fixture places its west route rail")
	_check(station.city.set_building_id(21, 18, Tiles.RAIL_STRAIGHT_1), "Train fixture places its east route rail")
	_check(station.document.set_misc_u32(0x01f0 + 0xed * 4, 4), "Train fixture sets the station count")
	var train_result := GrowthScan.run(
		station.city,
		ZeroRandom.new(),
		0,
		0,
		MicrosimLfsrRandom.new(),
		NonzeroGameRandom.new()
	)
	_check(train_result.ok and train_result.spawned_trains == 1, "Rail station spawns a train")
	_check(station.city.text_overlay_id(20, 18) == 202, "Train engine attaches to its rail tile")
	var engine: ThingRecord = station.city.thing(1)
	var first_car: ThingRecord = station.city.thing(2)
	var second_car: ThingRecord = station.city.thing(3)
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
	var full_buildings := _filled_bytes(128 * 128, Tiles.EMPTY)
	var full_things := _filled_bytes(40 * 12, 0)
	var full_text := _filled_bytes(128 * 128, 0)
	full_buildings[20 * 128 + 18] = Tiles.RAIL_STRAIGHT_1
	full_buildings[20 * 128 + 17] = Tiles.RAIL_STRAIGHT_1

	for record in range(1, 40):
		full_things[record * 12] = 7

	_check(
		MovingThings.spawn_train(
			full_buildings, full_things, full_text, Vector2i(20, 20),
			ZeroGameRandom.new(), ZeroLfsrRandom.new()
		),
		"Full-pool train creator keeps the supplied unchecked-allocation result",
	)
	_check(
		full_things[0] == 11 and full_text[20 * 128 + 18] == 201,
		"Full-pool train creator writes reserved record zero like the supplied executable",
	)

	var marina := _special_growth_fixture(reference_root)
	_check(marina.city.set_building_id(20, 20, Tiles.MARINA), "Sailboat fixture places a marina")
	_check(marina.city.set_tile_flag(20, 20, 0x40, true), "Sailboat fixture powers its marina")
	_check(marina.city.set_tile_flag(20, 19, 0x04, true), "Sailboat fixture marks north water")
	_check(marina.document.set_misc_u32(0x01f0 + 0xf8 * 4, 9), "Sailboat fixture sets the marina count")
	var sailboat_result := GrowthScan.run(
		marina.city, ZeroRandom.new(), 0, 0, MicrosimLfsrRandom.new()
	)
	_check(
		sailboat_result.ok and sailboat_result.spawned_sailboats == 1,
		"Marina spawns one sailboat on its valid adjacent water tile",
	)
	var sailboat: ThingRecord = marina.city.thing(1)
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
	_check(arcology.city.set_building_id(20, 20, Tiles.PLYMOUTH_ARCOLOGY), "Arcology fixture places an arcology tile")
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
	var arcology_result := GrowthScan.run(
		arcology.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(arcology_result.ok and arcology_result.arcologies_updated == 1, "Arcology updates its XMIC statistic")
	_check(arcology.city.microsim(10).stat_0 == 8, "Arcology rating uses land value, crime, pollution, power, and water")


func _growth_fixture(
	reference_root: String, origin_building: int, origin_zone: int, demand: int
) -> Dictionary:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var buildings := _filled_bytes(128 * 128, Tiles.EMPTY)

	for point in [Vector2i(20, 21), Vector2i(20, 22), Vector2i(20, 23), Vector2i(20, 24)]:
		buildings[point.x * 128 + point.y] = Tiles.ROAD_STRAIGHT_1

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
		["XUND", _filled_bytes(128 * 128, UnderTiles.EMPTY)],
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
