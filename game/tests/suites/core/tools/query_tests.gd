extends "res://tests/support/core_test_suite.gd"

## Tools: query checks.

@warning_ignore_start("integer_division")

const Queries = preload("res://src/tools/city/query_info.gd")
const QueryFacilityActions = preload("res://src/tools/city/query_actions.gd")
const QueryPresentation = preload("res://src/view/query_presentation.gd")


func test_query_info(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XTXT", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Query fixture clears %s" % chunk_id,
		)

	_check(
		document.find_chunk("XTHG").set_decoded_payload(
			_filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)
		),
		"Query fixture clears XTHG",
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
	_check(city.set_building_id(10, 10, Tiles.ROAD_STRAIGHT_1), "Query fixture places a road")
	_check(city.set_zone_id(10, 10, 1), "Query fixture zones the road")
	_check(city.set_land_altitude(10, 10, 6), "Query fixture sets altitude")
	_check(city.set_tile_flag(10, 10, 0x40, true), "Query fixture powers the road")
	_check(city.set_underground_id(10, 10, UnderTiles.PIPE_TB_SUBWAY_LR), "Query fixture adds a pipe and subway crossover")
	var info := Queries.inspect(city, Vector2i(10, 10))
	_check(info.ok and info.kind == "general", "General query succeeds: %s" % info.error)
	_check(info.sound_events.is_empty(), "General query does not request a sound")
	_check(
		info.things.is_empty(),
		"Query hides XTHG fields when no moving object occupies the tile",
	)
	var things_data := document.find_chunk("XTHG").decoded_payload.duplicate()
	var thing_offset := CityState.THING_RECORD_SIZE
	var thing_values := [2, 5, 3, 42, 42, 6, 7, 8, 50, 51, 12, 13]

	for field in CityState.THING_RECORD_SIZE:
		things_data[thing_offset + field] = thing_values[field]

	_check(
		document.find_chunk("XTHG").set_decoded_payload(things_data),
		"Query fixture stores an XTHG helicopter",
	)
	var thing_info := Queries.inspect(city, Vector2i(42, 42))
	_check(
		thing_info.things.size() == 1
		and thing_info.things[0].record == 1
		and thing_info.things[0].type_name == Queries.THING_NAMES[2]
		and thing_info.things[0].sprite_id == 1366
		and thing_info.things[0].sprite_flip,
		"Query exposes the matching XTHG record and its native sprite",
	)
	var queried_values := PackedInt32Array()
	for field in ["type", "direction", "state", "x", "y", "z", "px", "py", "dx", "dy", "label", "goal"]:
		queried_values.append(int(thing_info.things[0][field]))
	_check(
		queried_values == PackedInt32Array(thing_values),
		"Query exposes all saved XTHG fields without changing their values",
	)
	var named_info := Queries.inspect(city, Vector2i(10, 10))
	_check(named_info.title == "Road", "General query applies the recovered road name indirection")
	_check(info.zone_name == "Residential" and info.zone_density == "low-density", "Query reports zone type and density")
	_check(info.traffic == 4, "Query reproduces adjacent road traffic calculation")
	_check(info.altitude_feet == 250 and not info.altitude_is_depth, "Query reproduces clear-terrain altitude")
	_check(info.land_value == 10, "Query reports land value in thousands per acre")
	_check(info.crime_level == QueryDetails.level_name(61), "Query uses the recovered crime thresholds")
	_check(info.pollution_level == QueryDetails.level_name(181), "Query uses the recovered pollution thresholds")
	_check(info.shows_utilities and info.powered, "Query reports utility state")
	_check(
		info.tile_id == 0x1d
		and info.sprite_id == 1029
		and info.altitude_raw == 6
		and info.zone_raw == 1,
		"Advanced query reports raw tile, sprite, altitude, and zone values",
	)
	_check(
		info.flags_raw == 0x40
		and info.flag_names == PackedStringArray(["powered"])
		and info.underground_name == "Crossover (PIPESTB_SUBWAYLR)",
		"Advanced query decodes XBIT and XUND values",
	)
	_check(city.set_tile_flag(40, 41, 0x08, true), "Advanced Query fixture sets XBIT xvalmask")
	_check(city.set_tile_flag(40, 41, 0x02, true), "Advanced Query fixture sets XBIT rotated")
	var flag_info := Queries.inspect(city, Vector2i(40, 41))
	_check(
		flag_info.flag_names == PackedStringArray(["xvalmask", "rotated"])
		and flag_info.underground_name == "None",
		"Advanced Query uses the SC2KFix XBIT and empty-XUND names",
	)
	var advanced_general_text := QueryText.format_text(info)
	_check(
		advanced_general_text.contains("29 / 0x1D")
		and advanced_general_text.contains("61 / 0x3D"),
		"General query formats the SC2KFix advanced data section",
	)
	for band in [[0, 0, "None"], [1, 59, "Low"], [60, 119, "Medium"], [120, 179, "High"], [180, 255, "Very High"]]:
		_check(
			QueryDetails.level_name(band[0]) == band[2] and QueryDetails.level_name(band[1]) == band[2],
			"Query level %s uses the executable threshold band" % band[2],
		)
	for traffic_tile in [Tiles.ROAD_POWER_CROSSING_1, Tiles.ROAD_RAIL_CROSSING_2, Tiles.HIGHWAY_STRAIGHT_1, Tiles.HIGHWAY_STRAIGHT_2]:
		_check(city.set_building_id(50, 50, traffic_tile), "Query traffic fixture places a road tile")
		_check(Queries.inspect(city, Vector2i(50, 50)).shows_traffic, "Query shows traffic for tile 0x%02X" % traffic_tile)
	_check(city.set_building_id(50, 50, Tiles.RAIL_POWER_CROSSING_1), "Query traffic fixture places a rail crossing")
	_check(not Queries.inspect(city, Vector2i(50, 50)).shows_traffic, "Query omits traffic for a rail and power crossing")
	_check(city.set_building_id(50, 50, Tiles.EMPTY), "Query traffic fixture clears its tile")
	for zone_name in [[10, "Seaport"], [11, "Airport"]]:
		_check(city.set_zone_id(50, 50, zone_name[0]), "Query fixture sets an unused zone")
		_check(Queries.inspect(city, Vector2i(50, 50)).zone_name == zone_name[1], "Query names zone %d" % zone_name[0])
	_check(city.set_zone_id(50, 50, 0), "Query fixture clears its zone")
	_check(city.set_land_altitude(50, 50, 2), "Query fixture puts land below the water level")
	var underwater := Queries.inspect(city, Vector2i(50, 50))
	_check(
		underwater.altitude_is_depth and not underwater.shows_land_value and not underwater.shows_utilities,
		"Query omits land value and utilities below the water level",
	)
	_check(city.set_building_id(40, 40, Tiles.EMPTY), "Query name fixture clears a terrain tile")
	_check(city.set_tile_flag(40, 40, 0x04, false), "Query name fixture clears its water flag")
	_check(
		QueryText.tile_name(city, Vector2i(40, 40)) == QueryStrings.CLEAR_TERRAIN,
		"General query selects the clear-terrain name",
	)
	_check(city.set_tile_flag(40, 40, 0x04, true), "Query name fixture sets its water flag")
	_check(city.set_tile_flag(40, 40, 0x01, true), "Query name fixture sets its salt-water flag")
	_check(
		QueryText.tile_name(city, Vector2i(40, 40)) == QueryStrings.SALT_WATER,
		"General query selects the salt-water tile name",
	)
	_check(city.set_tile_flag(40, 40, 0x01, false), "Query name fixture clears its salt-water flag")
	_check(
		QueryText.tile_name(city, Vector2i(40, 40)) == QueryStrings.FRESH_WATER,
		"General query selects the fresh-water tile name",
	)
	_check(city.set_building_id(41, 40, Tiles.LLAMA_DOME), "Query name fixture places an exact-name tile")
	_check(
		QueryText.tile_name(city, Vector2i(41, 40)) == "Braun Llama-dome",
		"General query gives tile FF its individual name",
	)
	_check(document.set_misc_u32(0x68, 8), "Query pump fixture sets rain")
	_check(city.set_building_id(20, 20, Tiles.WATER_PUMP), "Query pump fixture places a pump")
	_check(city.set_tile_flag(20, 20, 0x40, true), "Query pump fixture powers the pump")
	_check(city.set_tile_flag(19, 20, 0x04, true), "Query pump fixture places fresh water")
	var pump := Queries.inspect(city, Vector2i(20, 20))
	_check(pump.water_detail.contains("24480"), "Query reports recovered pump output")

	for tower_tile in [Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 29), Vector2i(31, 29)]:
		_check(city.set_building_id(tower_tile.x, tower_tile.y, Tiles.WATER_TOWER), "Query tower fixture places a tower tile")

	for watered_tile in [Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 29)]:
		_check(city.set_tile_flag(watered_tile.x, watered_tile.y, 0x10, true), "Query tower fixture stores water")

	var tower := Queries.inspect(city, Vector2i(31, 29))
	_check(tower.water_detail.contains("30000"), "Query counts stored tower water")

	var microsim_data := document.find_chunk("XMIC").decoded_payload.duplicate()
	microsim_data[0] = 0xd0
	microsim_data[1] = 7
	microsim_data[2] = 0x01
	microsim_data[3] = 0x02
	microsim_data[4] = 0x03
	microsim_data[5] = 0x04
	microsim_data[6] = 0x05
	microsim_data[7] = 0x06
	microsim_data[8] = 0
	microsim_data[9] = 9
	microsim_data[10] = 0x12
	microsim_data[11] = 0x34
	microsim_data[12] = 0x56
	microsim_data[13] = 0x78
	microsim_data[14] = 0x9a
	microsim_data[15] = 0xbc
	_check(document.find_chunk("XMIC").set_decoded_payload(microsim_data), "Query fixture sets microsim data")
	_check(city.set_label(52, "Dormant Link"), "Query fixture names a dormant microsim")
	_check(city.set_text_overlay_id(11, 10, 52), "Query fixture attaches a dormant microsim")
	var dormant := Queries.inspect(city, Vector2i(11, 10))
	var dormant_text := QueryText.format_text(dormant)
	_check(
		dormant.kind == "general"
		and dormant.microsim_id == 1
		and dormant.microsim.stat_3 == 0x9abc
		and dormant_text.contains(city.label(52))
		and dormant_text.contains("39612 / 0x9ABC"),
		"Advanced Query keeps XMIC details after the normal dialog falls back",
	)
	_check(city.set_label(51, "Civic Center"), "Query fixture names a microsim")
	_check(city.set_text_overlay_id(10, 10, 51), "Query fixture attaches a microsim")
	var specific := Queries.inspect(city, Vector2i(10, 10))
	_check(specific.ok and specific.kind == "specific", "Specific query follows XTXT to XMIC")
	_check(specific.title == "Civic Center" and specific.microsim.stat_0 == 7, "Specific query reports its label and rating")
	_check(specific.microsim.stat_1 == 0x0102, "Specific query reads big-endian statistic one")
	_check(specific.microsim.stat_2 == 0x0304, "Specific query reads big-endian statistic two")
	_check(specific.microsim.stat_3 == 0x0506, "Specific query reads big-endian statistic three")
	_check(specific.microsim_type == 2, "Specific query maps City Hall to facility type two")
	_check(specific.sound_events == [513], "City Hall query requests original sound 513")
	_check(
		specific.sprite_id == 1208
		and QueryText.format_text(specific).contains("1286 / 0x0506"),
		"Specific query shows its full-size sprite and raw XMIC data",
	)
	var renamed := QueryFacilityActions.rename_facility(city, specific, "New Civic Center")
	_check(
		renamed.ok and city.label(51) == "New Civic Center",
		"Specific query can rename its linked facility",
	)
	_check(
		QueryFacilityActions.rename_facility(city, specific, "12345678901234567890123456789").new_value.length() == 23,
		"Query rename uses the saved XLAB length limit",
	)
	_check(city.set_label(51, "Civic Center"), "Query fixture restores the facility name")
	_check(specific.action == "city_analysis", "City Hall query exposes its Analyze action")
	_check(
		specific.lines == PackedStringArray(["Employees : 258", "Built in : 772"]),
		"City Hall query expands its information rows",
	)

	microsim_data = document.find_chunk("XMIC").decoded_payload.duplicate()
	microsim_data[0] = 0xd7
	microsim_data[1] = 23
	microsim_data[2] = 0x46
	microsim_data[3] = 0x50
	microsim_data[4] = 0
	microsim_data[5] = 2
	microsim_data[6] = 0
	microsim_data[7] = 0xfd
	_check(document.find_chunk("XMIC").set_decoded_payload(microsim_data), "Query fixture sets Stadium data")
	_check(city.set_label(0xfd, "Camel City Flyers"), "Query fixture names a Stadium team")
	var stadium := Queries.inspect(city, Vector2i(10, 10))
	_check(stadium.microsim_type == 7 and stadium.lines.size() == 5, "Stadium query uses all five rows")
	_check(
		stadium.lines
		== PackedStringArray([
			"Capacity : 25000",
			"Attendance : 18000",
			"Local Team : Soccer",
			"Camel City Flyers",
			"Wins-Losses : 23-17",
		]),
		"Stadium query separates its sport, editable name, and record",
	)

	microsim_data[0] = 0xd1
	microsim_data[1] = 12
	microsim_data[2] = 0x01
	microsim_data[3] = 0xf4
	microsim_data[4] = 0
	microsim_data[5] = 40
	microsim_data[6] = 0x07
	microsim_data[7] = 0xd0
	_check(document.find_chunk("XMIC").set_decoded_payload(microsim_data), "Query fixture sets Hospital data")
	var hospital := Queries.inspect(city, Vector2i(10, 10))
	_check(hospital.lines[3] == "Grade : A+", "Specific query maps its rating byte to the grade scale")
	_check(hospital.lines[4] == "Annual Cost : $2000", "Specific query expands statistic three")
	var arcology := CityRecords.Microsim.new()
	arcology.tile_id = Tiles.PLYMOUTH_ARCOLOGY
	arcology.stat_1 = 7
	_check(
		QueryText.expand_specific_template(city, arcology, "Design Capacity : #1000")
		== "Design Capacity : 7000",
		"Specific query preserves suffix digits after a numeric placeholder",
	)

	microsim_data[0] = 0xf5
	_check(document.find_chunk("XMIC").set_decoded_payload(microsim_data), "Query fixture sets Library data")
	var library := Queries.inspect(city, Vector2i(10, 10))
	_check(library.action == "library_ruminate", "Library query exposes its Ruminate action")
	var arcology_info := Queries.inspect(city, Vector2i(10, 10))
	arcology_info.microsim = city.microsim(library.microsim_id)
	arcology_info.microsim.tile_id = Tiles.PLYMOUTH_ARCOLOGY
	_check(
		QueryPresentation.sprite_id(city, arcology_info) == 1251,
		"Query uses a full-size arcology sprite as corrected by SC2KFix",
	)
	_check(
		QueryText.specific_sound_events(0xfb, 3) == [526, 512]
		and QueryText.specific_sound_events(0xfb, 4) == [526]
		and QueryText.specific_sound_events(0xfb, 10) == [526, 513],
		"Arcology query keeps all three original age-dependent sound branches",
	)
	_check(
		QueryText.specific_sound_events(0xc8, 0) == [514]
		and QueryText.specific_sound_events(0xd1, 0) == [506]
		and QueryText.specific_sound_events(0xd3, 0) == [509]
		and QueryText.specific_sound_events(0xd6, 0) == [523]
		and QueryText.specific_sound_events(0xd8, 0) == [522]
		and QueryText.specific_sound_events(0xda, 0) == [527]
		and QueryText.specific_sound_events(0xec, 0) == [521]
		and QueryText.specific_sound_events(0xed, 0) == [524]
		and QueryText.specific_sound_events(0xf8, 0) == [511]
		and QueryText.specific_sound_events(0xf5, 0).is_empty(),
		"Specific query maps each recovered facility sound class",
	)

	var analysis_misc := document.find_chunk("MISC").decoded_payload.duplicate()

	for tile_id in range(QueryFacilityActions.FIRST_BUILDING, 0x100):
		_write_u32_be(
			analysis_misc,
			QueryFacilityActions.MISC_TILE_COUNTS + tile_id * 4,
			0,
		)

	var category_examples := [
		0x1d,
		0x0e,
		0xdc,
		0x70,
		0x7c,
		0x84,
		0xdd,
		0xd4,
		0xd0,
		0x0d,
		0xfb,
	]

	for tile_id in category_examples:
		_write_u32_be(
			analysis_misc,
			QueryFacilityActions.MISC_TILE_COUNTS + tile_id * 4,
			1,
		)

	_write_u32_be(
		analysis_misc,
		QueryFacilityActions.MISC_TILE_COUNTS + 0x88 * 4,
		1,
	)
	_write_u32_be(
		analysis_misc,
		QueryFacilityActions.MISC_TILE_COUNTS + 0xff * 4,
		1,
	)
	_check(
		document.find_chunk("MISC").set_decoded_payload(analysis_misc),
		"City analysis fixture sets saved tile counts",
	)
	var analysis := QueryFacilityActions.city_analysis(city)
	_check(analysis.ok, "City Hall analysis succeeds: %s" % analysis.error)
	_check(analysis.total == 11 and analysis.counts[0] == 1, "City Hall analysis excludes hidden and unmatched tiles from its total")

	for category_id in range(1, QueryFacilityActions.CATEGORY_COUNT):
		_check(
			analysis.counts[category_id] == 1
			and analysis.categories[category_id - 1].percent == 9,
			"City Hall analysis classifies category %d" % category_id,
		)

	_check(
		analysis.header == QueryFacilityActions.ANALYSIS_HEADER
		and analysis.categories[0].name == "Transportation",
		"City Hall analysis labels its table",
	)

	_check(
		QueryFacilityActions.format_city_analysis(analysis).contains("9%"),
		"City Hall analysis formats category percentages",
	)
