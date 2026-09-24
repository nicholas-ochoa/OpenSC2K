extends "res://tests/support/core_test_suite.gd"

## Simulation: data maps checks.

@warning_ignore_start("integer_division")

const GraphView = preload("res://src/view/city_graph_control.gd")
const Pollution = preload("res://src/simulation/data_maps/pollution_phase.gd")
const Graphs = preload("res://src/simulation/reports/graph_history.gd")
const Growth = preload("res://src/simulation/growth/phase/constants.gd")


func test_pollution(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var buildings := PackedByteArray()
	buildings.resize(CityModel.TILE_COUNT)
	buildings[20 * CityModel.MAP_SIZE + 20] = Tiles.GAS_POWER
	buildings[20 * CityModel.MAP_SIZE + 21] = Tiles.NUCLEAR_POWER
	buildings[21 * CityModel.MAP_SIZE + 20] = Tiles.RADIOACTIVE_WASTE
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
	_check(document.set_misc_u32(0x104c, 0), "Pollution test clears the treatment state")
	_check(document.set_misc_u32(0x1050, 99), "Pollution test installs ignored trailing data")
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
	_check(
		document.find_chunk("XPLT").set_decoded_payload(previous)
		and document.set_misc_u32(0x104c, 1),
		"Pollution test enables sufficient water treatment",
	)
	var treated_result := Pollution.run(city)
	_check(
		treated_result.ok
		and document.find_chunk("XPLT").decoded_payload[10 * 64 + 10] == 56
		and treated_result.pollution_total == 168,
		"Sufficient treatment increases the pollution smoothing divisor",
	)

	var clean_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	clean_buildings[40 * 128 + 40] = Tiles.ROAD_STRAIGHT_1
	_check(
		clean_document.find_chunk("XBLD").set_decoded_payload(clean_buildings),
		"Combined scan test places one road tile"
	)

	for offset in [0x0fa0, 0x1034, 0x103c, 0x104c]:
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


func test_graph_history(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var data := PackedByteArray()
	data.resize(CityModel.GRAPH_COUNT * CityModel.GRAPH_VALUE_COUNT * 4)

	for series in CityModel.GRAPH_COUNT:
		for index in CityModel.GRAPH_VALUE_COUNT:
			_write_u32_be(data, (series * CityModel.GRAPH_VALUE_COUNT + index) * 4, series * 1000 + index)

	_check(document.find_chunk("XGRP").set_decoded_payload(data), "Graph test installs known history")
	_check(city.set_age_in_days(150), "Graph test selects July")
	var year_history := GraphView.history_for_scale(city, 2, GraphView.TIME_YEAR)
	var decade_history := GraphView.history_for_scale(city, 2, GraphView.TIME_DECADE)
	var century_history := GraphView.history_for_scale(city, 2, GraphView.TIME_CENTURY)
	_check(
		year_history.size() == 12
		and year_history[0] == 2011
		and year_history[-1] == 2000,
		"Graph window orders monthly history from oldest to newest",
	)
	_check(
		decade_history.size() == 20
		and decade_history[0] == 2031
		and decade_history[-1] == 2012,
		"Graph window orders half-year history from oldest to newest",
	)
	_check(
		century_history.size() == 20
		and century_history[0] == 2051
		and century_history[-1] == 2032,
		"Graph window orders five-year history from oldest to newest",
	)
	var display_maxima := GraphView.display_maxima(city)
	_check(
		display_maxima[0] == 51
		and display_maxima[1] == 51
		and display_maxima[3] == 51,
		"Graph window shares the City Size maximum with RCI series",
	)
	_check(
		display_maxima[4] == 7051 and display_maxima[7] == 7051,
		"Graph window shares the traffic through crime maximum",
	)
	_check(
		display_maxima[13] == 14051 and display_maxima[14] == 14051,
		"Graph window raises the GNP maximum to national population",
	)
	_check(
		GraphView.DEFAULT_SELECTED_MASK == 0x000f
		and GraphView.SERIES_MARKERS[15] == "%",
		"Graph window uses the recovered defaults and Federal Rate marker",
	)
	_check(
		GraphView.format_value(0, 9999) == "9999"
		and GraphView.format_value(0, 10000) == "10k"
		and GraphView.format_value(0, 1000000) == "1m",
		"Graph window uses the recovered compact number thresholds",
	)

	for example in [
		[0, "0k"], [999, "999k"], [1000, "1m"], [250000, "250m"],
		[999999, "999m"], [1000000, "1b"], [4294967295, "4294b"],
	]:
		_check(
			GraphView.format_value(14, example[0]) == example[1],
			"National-population graph expands thousands at %d" % example[0],
		)

	_test_graph_time_labels(city)
	var month_labels := GraphView.time_labels(city, GraphView.TIME_YEAR)
	_check(
		month_labels.size() == 12
		and month_labels[0] == "Aug"
		and month_labels[-1] == "Jul",
		"Graph window aligns the one-year labels to the current month",
	)

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


func _test_graph_time_labels(city: CityState) -> void:
	var start_year := city.founding_year()
	var age := city.age_in_days()

	# Check both sides of each label-position change. The last two cases
	# distinguish elapsed years from calendar years for a non-decade start.
	for example in [
		[1900, 30125, GraphView.TIME_DECADE, ["", "'91", "", "'00"]],
		[1900, 30150, GraphView.TIME_DECADE, ["'91", "", "'00", ""]],
		[1900, 30299, GraphView.TIME_DECADE, ["'91", "", "'00", ""]],
		[1900, 30300, GraphView.TIME_DECADE, ["", "'92", "", "'01"]],
		[1900, 31499, GraphView.TIME_CENTURY, ["", "'10", "", "'00"]],
		[1900, 31500, GraphView.TIME_CENTURY, ["'10", "", "'00", ""]],
		[1900, 32999, GraphView.TIME_CENTURY, ["'10", "", "'00", ""]],
		[1900, 33000, GraphView.TIME_CENTURY, ["", "'20", "", "'10"]],
		[1903, 31200, GraphView.TIME_CENTURY, ["", "'10", "", "'00"]],
		[1903, 31500, GraphView.TIME_CENTURY, ["'10", "", "'00", ""]],
	]:
		city.document.set_misc_u32(Sc2MiscLayout.START_YEAR, example[0])
		city.set_age_in_days(example[1])
		var labels := GraphView.time_labels(city, example[2])
		var endpoints := PackedStringArray([labels[0], labels[1], labels[18], labels[19]])
		_check(
			labels.size() == 20 and endpoints == PackedStringArray(example[3]),
			"Graph date labels match scale %d at start %d, age %d" % [example[2], example[0], example[1]],
		)

	city.document.set_misc_u32(Sc2MiscLayout.START_YEAR, start_year)
	city.set_age_in_days(age)
