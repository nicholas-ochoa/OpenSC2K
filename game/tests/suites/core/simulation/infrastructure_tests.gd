extends "res://tests/support/core_test_suite.gd"

## Simulation: infrastructure checks.

@warning_ignore_start("integer_division")

const Random = preload("res://src/simulation/random/sim_random.gd")
const LfsrRandom = preload("res://src/simulation/random/sim_lfsr_random.gd")
const Power = preload("res://src/simulation/infrastructure/power_phase.gd")
const Water = preload("res://src/simulation/infrastructure/water_phase.gd")
const Traffic = preload("res://src/simulation/infrastructure/traffic_phase.gd")
const Transport = preload("res://src/simulation/infrastructure/transport_trip.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const Hydro = preload("res://src/tools/city/hydro_command.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const ZeroRandom = TestRandoms.ZeroRandom
const ZeroLfsrRandom = TestRandoms.ZeroLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom


func test_random_and_power(reference_root: String) -> void:
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

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_building_id(10, 10, Tiles.HYDRO_POWER_1), "Power test places a hydro plant")
	_check(city.set_building_id(10, 11, Tiles.POWER_LINE_STRAIGHT_1), "Power test places a power line")
	_check(city.set_building_id(10, 12, Tiles.LOWER_CLASS_HOMES_1X1_1), "Power test places a consumer")
	_check(city.set_building_id(20, 20, Tiles.LOWER_CLASS_HOMES_1X1_1), "Power test places a disconnected consumer")

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


func test_water(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_building_id(30, 30, Tiles.WATER_PUMP), "Water test places a pump")
	_check(city.set_building_id(30, 31, Tiles.EMPTY), "Water test clears a pipe tile")
	_check(city.set_building_id(30, 32, Tiles.LOWER_CLASS_HOMES_1X1_1), "Water test places a consumer")
	_check(city.set_building_id(40, 40, Tiles.LOWER_CLASS_HOMES_1X1_1), "Water test places a disconnected consumer")

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
		_check(
			result.treatment_capacity == 0
			and not result.treatment_sufficient
			and document.misc_u32(0x104c) == 0,
			"Untreated served demand clears the saved treatment state",
		)
		_check(city.is_watered(30, 30), "Powered pump is marked watered")
		_check(city.is_watered(30, 31), "Connected pipe is marked watered")
		_check(city.is_watered(30, 32), "Connected consumer is marked watered")
		_check(not city.is_watered(40, 40), "Disconnected consumer is not watered")
		_check(
			document.set_misc_u32(0x01f0 + 0xf4 * 4, 4),
			"Water test records one complete treatment plant",
		)
		var treated := Water.run(city)
		_check(
			treated.ok
			and treated.treatment_capacity == 2000
			and treated.treatment_sufficient
			and document.misc_u32(0x104c) == 1,
			"One treatment plant covers 2,000 served demand units",
		)


func test_traffic(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
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


func test_transport_trip(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
		_check(city.set_building_id(point.x, point.y, Tiles.ROAD_STRAIGHT_1), "Transport fixture places a road")

	_check(city.set_zone_id(20, 20, 1), "Transport fixture sets the origin zone")
	_check(city.set_zone_id(20, 26, 3), "Transport fixture sets a job destination")
	var result := Transport.run(city, Vector2i(20, 20), 1, 2, Random.new(1))
	_check(result.ok and result.reached_destination, "Road trip reaches a compatible zone")
	_check(result.path_length == 3, "Road trip records the three-tile path")
	var traffic := document.find_chunk("XTRF").decoded_payload
	_check(traffic[10 * 64 + 10] == 2, "Road trip adds traffic to its first coarse cell")
	_check(traffic[10 * 64 + 11] == 4, "Road trip accumulates two tiles in one coarse cell")

	_check(city.set_zone_id(20, 26, 1), "Transport fixture changes the destination to residential")
	var before_failed_trip: PackedByteArray = document.find_chunk("XTRF").decoded_payload.duplicate()
	var failed := Transport.run(city, Vector2i(20, 20), 1, 2, Random.new(1))
	_check(failed.ok and not failed.reached_destination, "Trip rejects an incompatible destination")
	_check(document.find_chunk("XTRF").decoded_payload == before_failed_trip, "Failed trip preserves XTRF")

	_check(city.set_building_id(1, 0, Tiles.ROAD_STRAIGHT_1), "Connection fixture places an edge road")
	_check(city.set_text_overlay_id(1, 0, 0xfa), "Connection fixture marks a city connection")
	var connection := Transport.run(city, Vector2i(1, 1), 5, 1, Random.new(7))
	_check(connection.ok and connection.reached_destination, "Trip can leave through a city connection")
	_check(
		document.find_chunk("XTRF").decoded_payload[0] == 1,
		"Connection trip adds its density to the edge traffic cell",
	)


func test_transport_maintenance(reference_root: String) -> void:
	var road := _maintenance_fixture(reference_root, Tiles.ROAD_STRAIGHT_1, UnderTiles.EMPTY)
	_check(road.city.set_tile_flag(20, 20, 0x80, true), "Road decay fixture sets powerable")
	_check(road.document.set_misc_i32(0x077c + 10 * 0x6c + 4, 0), "Road decay fixture removes funding")
	var road_result := GrowthScan.run(road.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(road_result.ok and road_result.decayed_roads == 1, "Unfunded road decays on the rare check")
	_check(road.city.building_id(20, 20) == 1, "Road decay makes process-selected rubble")
	_check(road.city.tile_flags[20 * 128 + 20] & 0x80 == 0, "Road decay clears powerable")

	var rail := _maintenance_fixture(reference_root, Tiles.RAIL_STRAIGHT_1, UnderTiles.EMPTY)
	_check(rail.city.set_tile_flag(20, 20, 0x80, true), "Rail decay fixture sets powerable")
	_check(rail.document.set_misc_i32(0x077c + 13 * 0x6c + 4, 0), "Rail decay fixture removes funding")
	var rail_result := GrowthScan.run(rail.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(rail_result.ok and rail_result.decayed_rails == 1, "Unfunded rail decays on the rare check")
	_check(rail.city.building_id(20, 20) == 1, "Rail decay makes process-selected rubble")
	_check(rail.city.tile_flags[20 * 128 + 20] & 0x80 == 0, "Rail decay clears powerable")

	var highway := _maintenance_fixture(reference_root, Tiles.HIGHWAY_STRAIGHT_1, UnderTiles.EMPTY)

	for point in [Vector2i(21, 20), Vector2i(20, 21), Vector2i(21, 21)]:
		_check(highway.city.set_building_id(point.x, point.y, Tiles.HIGHWAY_STRAIGHT_1), "Highway decay fixture fills its section")

	_check(highway.city.set_tile_flag(21, 20, 0x04, true), "Highway decay fixture sets one water tile")
	_check(highway.document.set_misc_u32(0x01f0 + 0x49 * 4, 4), "Highway decay fixture counts its tiles")
	_check(highway.document.set_misc_i32(0x077c + 11 * 0x6c + 4, 0), "Highway decay fixture removes funding")
	var highway_result := GrowthScan.run(highway.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(highway_result.ok and highway_result.decayed_highway_tiles == 4, "Unfunded highway decays as one section")
	_check(highway.city.building_id(21, 20) == 0, "Highway decay clears a water tile")

	for point in [Vector2i(20, 20), Vector2i(20, 21), Vector2i(21, 21)]:
		_check(highway.city.building_id(point.x, point.y) == 1, "Highway decay makes rubble on dry land")

	var subway := _maintenance_fixture(reference_root, Tiles.EMPTY, UnderTiles.SUBWAY_LR)
	_check(subway.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Subway decay fixture removes funding")
	var subway_result := GrowthScan.run(subway.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(subway_result.ok and subway_result.decayed_subway_tiles == 1, "Unfunded subway decays on the rare check")
	_check(subway.city.underground_id(20, 20) == 0, "Subway decay clears a subway tile")
	_check(subway.document.misc_u32(0x0fe8) == 0, "Subway decay decrements the saved XUND count")

	var crossover := _maintenance_fixture(reference_root, Tiles.EMPTY, UnderTiles.PIPE_TB_SUBWAY_LR)
	_check(crossover.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Crossover decay fixture removes funding")
	var crossover_result := GrowthScan.run(crossover.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(crossover_result.ok and crossover_result.decayed_subway_tiles == 1, "Subway crossover loses its rail layer")
	_check(crossover.city.underground_id(20, 20) == 0x11, "Subway crossover preserves its pipe layer")
	_check(crossover.document.misc_u32(0x0fe8) == 0, "Crossover decay decrements the saved XUND count")

	var station := _maintenance_fixture(reference_root, Tiles.SUBWAY_STATION, UnderTiles.SUBWAY_ENTRANCE)
	_check(station.city.set_text_overlay_id(20, 20, 54), "Station decay fixture sets its microsim label")
	_check(station.city.set_tile_flag(20, 20, 0xe2, true), "Station decay fixture sets utility and flip flags")
	_check(station.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Station decay fixture removes funding")
	var station_result := GrowthScan.run(station.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
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
	test_subway_station_record_cleanup(reference_root)

	var bridge := _maintenance_fixture(reference_root, Tiles.SUSPENSION_BRIDGE_1, UnderTiles.EMPTY)

	for x in range(18, 25):
		for y in range(19, 22):
			_check(bridge.city.set_land_altitude(x, y, 0), "Bridge decay fixture levels the waterbed")

	for x in range(20, 23):
		_check(bridge.city.set_building_id(x, 20, Tiles.SUSPENSION_BRIDGE_1), "Bridge decay fixture places a span tile")
		_check(bridge.city.set_terrain_id(x, 20, 0x30), "Bridge decay fixture places water terrain")
		_check(bridge.city.set_tile_flag(x, 20, 0x06, true), "Bridge decay fixture marks horizontal water")

	for x in [19, 23]:
		_check(bridge.city.set_building_id(x, 20, Tiles.ROAD_STRAIGHT_1), "Bridge decay fixture places a bank road")
		_check(bridge.city.set_land_altitude(x, 20, 1), "Bridge decay fixture raises a bank")

	_check(bridge.document.set_misc_u32(0x01f0, 16379), "Bridge decay fixture counts clear tiles")
	_check(bridge.document.set_misc_u32(0x01f0 + 0x51 * 4, 3), "Bridge decay fixture counts span tiles")
	_check(bridge.document.set_misc_u32(0x01f0 + 0x1d * 4, 2), "Bridge decay fixture counts bank roads")
	_check(bridge.document.set_misc_u32(0x0e40, 1), "Bridge decay fixture sets sea level")
	_check(bridge.document.set_misc_i32(0x077c + 12 * 0x6c + 4, 0), "Bridge decay fixture removes funding")
	var bridge_random := SequenceRandom.new([0, 2, 1, 3, 0, 1, 1])
	var bridge_result := GrowthScan.run(bridge.city, bridge_random, 0, 0, ZeroLfsrRandom.new())
	_check(bridge_result.ok and bridge_result.collapsed_bridges == 1, "Unfunded bridge span collapses")
	_check(
		bridge_result.deferred_bridge_effects == 0
		and bridge_result.bridge_effects.size() == 3
		and bridge_random.position == 7,
		"Bridge collapse creates debris and consumes its process-random values",
	)
	_check(
		bridge_result.bridge_effects[0].sprite_id == 1394
		and bridge_result.bridge_effects[0].flip
		and bridge_result.bridge_effects[1].sprite_id == 1395
		and not bridge_result.bridge_effects[1].flip
		and bridge_result.bridge_effects[2].sprite_id == 1393
		and bridge_result.bridge_effects[2].flip,
		"Bridge collapse selects each debris sprite and mirror in original order",
	)
	_check(
		bridge_result.view_center_requests == [Vector2i(20, 20)]
		and SoundEvent.same_arrays(bridge_result.sound_events, SoundEvent.from_ids([504]))
		and bridge_result.news_items.size() == 1
		and bridge_result.news_items[0].type == 39
		and bridge_result.news_items[0].argument == 0,
		"Bridge collapse requests view centering, sound, and newspaper type 39",
	)

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

	var reinforced := _maintenance_fixture(reference_root, Tiles.HIGHWAY_BRIDGE, UnderTiles.EMPTY)
	_check(reinforced.document.set_misc_i32(0x077c + 12 * 0x6c + 4, 0), "Reinforced bridge fixture removes funding")
	var reinforced_result := GrowthScan.run(
		reinforced.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new()
	)
	_check(reinforced_result.ok and reinforced_result.deferred_bridge_collapses == 1, "Reinforced bridge collapse stays explicit")
	_check(reinforced.city.building_id(20, 20) == 0x6a, "Malformed reinforced bridge stays unchanged")

	var reinforced_span := _maintenance_fixture(reference_root, Tiles.EMPTY, UnderTiles.EMPTY)

	for x in range(18, 29):
		for y in range(19, 23):
			_check(
				reinforced_span.city.set_land_altitude(x, y, 0),
				"Reinforced collapse fixture levels the waterbed",
			)

	for section in 3:
		var section_tile := 0x6b if section != 1 else 0x6a

		for x_offset in 2:
			for y_offset in 2:
				var point := Vector2i(20 + section * 2 + x_offset, 20 + y_offset)
				_check(
					reinforced_span.city.set_building_id(point.x, point.y, section_tile),
					"Reinforced collapse fixture places a span tile",
				)
				_check(
					reinforced_span.city.set_terrain_id(point.x, point.y, 0x30),
					"Reinforced collapse fixture places water terrain",
				)
				_check(
					reinforced_span.city.set_tile_flag(point.x, point.y, 0x06, true),
					"Reinforced collapse fixture marks span water",
				)

	_check(reinforced_span.city.set_land_altitude(26, 20, 1), "Reinforced collapse fixture raises its forward bank")
	_check(reinforced_span.document.set_misc_u32(0x01f0, 16372), "Reinforced collapse fixture counts clear tiles")
	_check(reinforced_span.document.set_misc_u32(0x01f0 + 0x6a * 4, 4), "Reinforced collapse fixture counts pylons")
	_check(reinforced_span.document.set_misc_u32(0x01f0 + 0x6b * 4, 8), "Reinforced collapse fixture counts normal spans")
	_check(reinforced_span.document.set_misc_u32(0x0e40, 1), "Reinforced collapse fixture sets sea level")
	_check(reinforced_span.document.set_misc_i32(0x077c + 12 * 0x6c + 4, 0), "Reinforced collapse fixture removes funding")
	var reinforced_span_random := SequenceRandom.new([
		0,
		3, 1, 0, 1, 0,
		2, 0, 1, 0, 1,
		1, 1, 1, 0, 0,
	])
	var reinforced_span_result := GrowthScan.run(
		reinforced_span.city, reinforced_span_random, 0, 0, ZeroLfsrRandom.new()
	)
	_check(
		reinforced_span_result.ok
		and reinforced_span_result.collapsed_bridges == 1
		and reinforced_span_result.deferred_bridge_collapses == 0,
		"A valid unfunded reinforced span collapses",
	)
	_check(
		reinforced_span_result.bridge_effects.size() == 12
		and reinforced_span_random.position == 16,
		"Reinforced collapse creates four debris effects per section",
	)
	_check(
		reinforced_span_result.bridge_effects[0].sprite_id == 1395
		and reinforced_span_result.bridge_effects[4].sprite_id == 1394
		and reinforced_span_result.bridge_effects[8].sprite_id == 1393
		and reinforced_span_result.bridge_effects[1].screen_offset == Vector2i(16, -8)
		and reinforced_span_result.bridge_effects[3].screen_offset == Vector2i(16, 8),
		"Reinforced collapse shares one sprite across each recovered four-part layout",
	)

	for x in range(20, 26):
		for y in range(20, 22):
			_check(
				reinforced_span.city.building_id(x, y) == 0,
				"Reinforced collapse clears each two-wide span tile",
			)

	_check(reinforced_span.city.building_id(26, 20) == 0, "Reinforced collapse keeps the empty forward-bank cell")
	_check(reinforced_span.city.land_altitude(26, 20) == 1, "Reinforced collapse preserves the forward-bank height")
	_check(
		reinforced_span.city.tile_flags[26 * 128 + 20] & 0x04 == 0,
		"Reinforced collapse leaves the raised forward bank dry",
	)
	_check(reinforced_span.document.misc_u32(0x01f0 + 0x6a * 4) == 0, "Reinforced collapse clears its pylon count")
	_check(reinforced_span.document.misc_u32(0x01f0 + 0x6b * 4) == 0, "Reinforced collapse clears its normal-span count")

	var funded := _maintenance_fixture(reference_root, Tiles.ROAD_STRAIGHT_1, UnderTiles.EMPTY)
	var funded_result := GrowthScan.run(funded.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(funded_result.ok and funded_result.decayed_roads == 0, "Full road funding prevents decay")
	_check(funded.city.building_id(20, 20) == 0x1d, "Full road funding preserves the road")


func test_subway_station_record_cleanup(reference_root: String) -> void:
	var fixture := _maintenance_fixture(reference_root, Tiles.EMPTY, UnderTiles.EMPTY)
	var document: Sc2File = fixture.document
	var city: CityState = fixture.city
	var overlays := [0, 1, 50, 51, 60, 61, 200, 201, 240, 241, 250, 255]
	var labels := _filled_bytes(Sc2LabelLayout.ORIGINAL_SIZE, 22)
	var microsims := _filled_bytes(Sc2MicrosimLayout.ORIGINAL_SIZE, 0xa5)
	var things := _filled_bytes(Sc2ThingLayout.ORIGINAL_SIZE, 3)
	_check(document.find_chunk("XLAB").set_decoded_payload(labels), "Station cleanup sets label records")
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Station cleanup sets facility records")
	_check(document.find_chunk("XTHG").set_decoded_payload(things), "Station cleanup sets moving-thing records")

	for slot in overlays.size():
		var x := 3 + slot * 4
		_check(city.set_building_id(x, 1, Tiles.SUBWAY_STATION), "Station cleanup places a station")
		_check(city.set_underground_id(x, 1, UnderTiles.SUBWAY_ENTRANCE), "Station cleanup places an entrance")
		_check(city.set_text_overlay_id(x, 1, overlays[slot]), "Station cleanup sets an overlay")

	var funded := GrowthScan.run(city, ZeroRandom.new(), 3, 1, ZeroLfsrRandom.new())
	_check(funded.ok and funded.removed_subway_stations == 0, "Funded stations keep their records")
	_check(document.find_chunk("XLAB").decoded_payload == labels, "Funded stations preserve label bytes")
	_check(document.find_chunk("XMIC").decoded_payload == microsims, "Funded stations preserve facility bytes")
	_check(document.find_chunk("XTHG").decoded_payload == things, "Funded stations preserve moving-thing bytes")
	_check(document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Station cleanup removes subway funding")
	var result := GrowthScan.run(city, ZeroRandom.new(), 3, 1, ZeroLfsrRandom.new())
	_check(result.ok and result.removed_subway_stations == overlays.size(), "Station cleanup removes the selected stations")

	# The original clears only record markers. Keep all other bytes, including
	# the shared facility records for overlays 51 through 60.
	var expected_labels := labels.duplicate()
	var expected_microsims := microsims.duplicate()
	var expected_things := things.duplicate()

	for label in [1, 50, 61, 200]:
		expected_labels[label * Sc2LabelLayout.RECORD_SIZE] = 0

	for record in [10, 149]:
		expected_microsims[record * Sc2MicrosimLayout.RECORD_SIZE] = 0

	for record in [0, 39]:
		expected_things[record * Sc2ThingLayout.RECORD_SIZE + Sc2ThingLayout.Field.LABEL] = 0

	_check(document.find_chunk("XLAB").decoded_payload == expected_labels, "Station cleanup clears sign and custom facility label markers only")
	_check(document.find_chunk("XMIC").decoded_payload == expected_microsims, "Station cleanup clears custom facility types and preserves shared records")
	_check(document.find_chunk("XTHG").decoded_payload == expected_things, "Station cleanup clears moving-thing attachments without deleting the things")
	var expected_overlays := [0, 0, 0, 0, 0, 0, 0, 201, 240, 241, 0, 255]

	for slot in overlays.size():
		_check(city.text_overlay_id(3 + slot * 4, 1) == expected_overlays[slot], "Station cleanup preserves moving-thing and reserved tile overlays")


func _maintenance_fixture(reference_root: String, surface_tile: int, underground_tile: int) -> Dictionary:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var buildings := _filled_bytes(128 * 128, Tiles.EMPTY)
	var zones := _filled_bytes(128 * 128, 0)
	var underground := _filled_bytes(128 * 128, UnderTiles.EMPTY)
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
