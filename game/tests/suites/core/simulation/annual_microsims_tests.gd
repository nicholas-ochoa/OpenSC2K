extends "res://tests/support/core_test_suite.gd"

## Simulation: annual microsims checks.

@warning_ignore_start("integer_division")

const Random = preload("res://src/simulation/random/sim_random.gd")
const LfsrRandom = preload("res://src/simulation/random/sim_lfsr_random.gd")
const AnnualMicrosims = preload("res://src/simulation/civic/microsim_annual_phase.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const ZeroRandom = TestRandoms.ZeroRandom
const SequenceLfsrRandom = TestRandoms.SequenceLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom
const CountingRandom = TestRandoms.CountingRandom
const SequenceGameRandom = TestRandoms.SequenceGameRandom


func test_annual_microsim_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	microsims[1 * 8] = 0xec
	microsims[2 * 8] = 0xed
	microsims[2 * 8 + 4] = 0x12
	microsims[2 * 8 + 5] = 0x34
	microsims[3 * 8] = 0xe9
	microsims[3 * 8 + 4] = 0x56
	microsims[3 * 8 + 5] = 0x78
	microsims[4 * 8] = 0xc6
	microsims[5 * 8] = 0xc8
	microsims[6 * 8] = 0xd0
	microsims[7 * 8] = 0xd4
	microsims[8 * 8] = 0xd5
	microsims[8 * 8 + 4] = 0x00
	microsims[8 * 8 + 5] = 0x64
	microsims[9 * 8] = 0xf5
	microsims[9 * 8 + 4] = 0x03
	microsims[9 * 8 + 5] = 0xe8
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Annual XMIC fixture installs facility records")
	_check(document.set_misc_u32(0x01f0 + 0xec * 4, 12), "Annual XMIC fixture counts bus tiles")
	_check(document.set_misc_u32(0x01f0 + 0xed * 4, 20), "Annual XMIC fixture counts rail tiles")
	_check(document.set_misc_u32(0x01f0 + 0xe9 * 4, 9), "Annual XMIC fixture counts subway tiles")
	_check(document.set_misc_u32(0x01f0 + 0xc6 * 4, 3), "Annual XMIC fixture counts first hydro tiles")
	_check(document.set_misc_u32(0x01f0 + 0xc7 * 4, 4), "Annual XMIC fixture counts second hydro tiles")
	_check(document.set_misc_u32(0x01f0 + 0xc8 * 4, 5), "Annual XMIC fixture counts wind tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd4 * 4, 4), "Annual XMIC fixture counts museum tiles")
	_check(document.set_misc_u32(0x01f0 + 0x0d * 4, 18), "Annual XMIC fixture counts small park tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd5 * 4, 9), "Annual XMIC fixture counts big park tiles")
	_check(document.set_misc_u32(0x01f0 + 0xf5 * 4, 2), "Annual XMIC fixture counts library tiles")
	_check(document.set_misc_u32(0x1020, 10000), "Annual XMIC fixture sets arcology population")
	_check(document.set_misc_u32(0x102c, 90000), "Annual XMIC fixture sets normal population")
	_check(document.set_misc_u32(0x077c + 8 * 0x006c + 4, 75), "Annual XMIC fixture sets school funding")
	_check(document.set_misc_u32(0x077c + 9 * 0x006c + 4, 80), "Annual XMIC fixture sets college funding")
	var result := AnnualMicrosims.run(city, 70000, 123, 456)
	_check(result.ok, "Annual microsimulation statistics complete: %s" % result.error)
	_check(
		result.updated_bus_records == 1
		and result.updated_rail_records == 1
		and result.updated_subway_records == 1,
		"Annual transit statistics report all updated records",
	)
	_check(
		result.updated_hydro_records == 1
		and result.updated_wind_records == 1
		and result.updated_city_hall_records == 1
		and result.updated_museum_records == 1
		and result.updated_park_records == 1
		and result.updated_library_records == 1,
		"Annual facility statistics report all deterministic records",
	)
	var bus := city.microsim(1)
	_check(
		bus.stat_1 == 3 and bus.stat_2 == 12 and bus.stat_3 == (70000 & 0xffff),
		"Annual bus statistics store depots and wrapped passengers",
	)
	var rail := city.microsim(2)
	_check(
		rail.stat_1 == 5 and rail.stat_2 == 0x1234 and rail.stat_3 == 123,
		"Annual rail statistics preserve statistic two",
	)
	var subway := city.microsim(3)
	_check(
		subway.stat_1 == 9 and subway.stat_2 == 0x5678 and subway.stat_3 == 456,
		"Annual subway statistics preserve statistic two",
	)
	var hydro := city.microsim(4)
	_check(hydro.stat_1 == 7 and hydro.stat_2 == 140, "Annual hydro statistics store capacity")
	var wind := city.microsim(5)
	_check(wind.stat_1 == 5 and wind.stat_2 == 20, "Annual wind statistics store capacity")
	_check(city.microsim(6).stat_1 == 111, "Annual city hall statistics apply the population cap")
	var museum := city.microsim(7)
	_check(museum.stat_1 == 1280 and museum.stat_2 == 32, "Annual museum statistics use college funding")
	var park := city.microsim(8)
	_check(
		park.stat_1 == 15000 and park.stat_2 == 27 and park.stat_3 == 3,
		"Annual big park statistics store capped visitors and park counts",
	)
	var library := city.microsim(9)
	_check(
		library.stat_0 == 0 and library.stat_1 == 600 and library.stat_2 == 1050,
		"Annual library statistics use school funding and population",
	)
	var before_invalid: PackedByteArray = document.find_chunk("XMIC").decoded_payload.duplicate()
	var invalid := AnnualMicrosims.run(city, -1, 0, 0)
	_check(not invalid.ok, "Annual microsimulation statistics reject a negative passenger count")
	_check(
		document.find_chunk("XMIC").decoded_payload == before_invalid,
		"A rejected annual transit update preserves XMIC",
	)


func test_annual_service_microsim_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	var service_tiles := [Tiles.HOSPITAL, Tiles.POLICE_STATION, Tiles.FIRE_STATION, Tiles.SCHOOL, Tiles.STADIUM, Tiles.PRISON, Tiles.COLLEGE]

	for index in service_tiles.size():
		microsims[(index + 1) * 8] = service_tiles[index]

	microsims[1 * 8 + 1] = 10
	microsims[4 * 8 + 1] = 8
	microsims[6 * 8 + 2] = 0x1f
	microsims[6 * 8 + 3] = 0x40
	microsims[7 * 8 + 1] = 7
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Annual service fixture installs XMIC records")
	_check(document.set_misc_u32(0x002c, 900), "Annual service fixture sets crime")
	_check(document.set_misc_u32(0x007c + 1 * 12, 1000), "Annual service fixture sets first student cohort")
	_check(document.set_misc_u32(0x007c + 2 * 12, 2000), "Annual service fixture sets second student cohort")
	_check(document.set_misc_u32(0x007c + 3 * 12, 4000), "Annual service fixture sets college cohort")
	_check(document.set_misc_u32(0x01f0 + 0xd1 * 4, 18), "Annual service fixture counts hospital tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd2 * 4, 9), "Annual service fixture counts police tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd6 * 4, 18), "Annual service fixture counts school tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd7 * 4, 16), "Annual service fixture counts stadium tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd8 * 4, 16), "Annual service fixture counts prison tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd9 * 4, 16), "Annual service fixture counts college tiles")
	_check(document.set_misc_u32(0x1020, 10000), "Annual service fixture sets arcology population")
	_check(document.set_misc_u32(0x102c, 90000), "Annual service fixture sets normal population")
	_check(document.set_misc_u32(0x1038, 400), "Annual service fixture sets old arrests")
	_check(document.set_misc_u32(0x103c, 1), "Annual service fixture sets prison bonus")
	_check(document.set_misc_u32(0x077c + 5 * 0x006c + 4, 80), "Annual service fixture sets police funding")
	_check(document.set_misc_u32(0x077c + 6 * 0x006c + 4, 60), "Annual service fixture sets fire funding")
	_check(document.set_misc_u32(0x077c + 7 * 0x006c + 4, 70), "Annual service fixture sets health funding")
	_check(document.set_misc_u32(0x077c + 8 * 0x006c + 4, 80), "Annual service fixture sets school funding")
	_check(document.set_misc_u32(0x077c + 9 * 0x006c + 4, 90), "Annual service fixture sets college funding")
	var random := SequenceRandom.new([5, 7, 3, 4, 9, 3, 7, 5, 10, 3, 11, 6])
	var result := AnnualMicrosims.run(city, 0, 0, 0, random)
	_check(result.ok, "Annual service statistics complete: %s" % result.error)
	_check(
		result.updated_hospital_records == 1
		and result.updated_police_records == 1
		and result.updated_fire_records == 1
		and result.updated_school_records == 1
		and result.updated_stadium_records == 1
		and result.updated_prison_records == 1
		and result.updated_college_records == 1,
		"Annual service statistics report each updated record",
	)
	var hospital := city.microsim(1)
	_check(
		hospital.stat_0 == 0
		and hospital.stat_1 == 1007
		and hospital.stat_2 == 69
		and hospital.stat_3 == 35,
		"Annual hospital statistics use population, health funding, and three random values",
	)
	var police := city.microsim(2)
	_check(
		police.stat_0 == 80 and police.stat_1 == 160 and police.stat_2 == 100 and police.stat_3 == 29,
		"Annual police statistics use crime, funding, and the old prison bonus",
	)
	var fire := city.microsim(3)
	_check(
		fire.stat_0 == 60 and fire.stat_1 == 30 and fire.stat_2 == 2 and fire.stat_3 == 11,
		"Annual fire statistics use funding and the process random value",
	)
	var school := city.microsim(4)
	_check(
		school.stat_0 == 7 and school.stat_1 == 1507 and school.stat_2 == 49 and school.stat_3 == 20,
		"Annual school statistics use student cohorts and school funding",
	)
	var stadium := city.microsim(5)
	_check(
		stadium.stat_0 == 12 and stadium.stat_1 == 6260,
		"Annual stadium statistics use adjusted population and two random values",
	)
	var prison := city.microsim(6)
	_check(
		prison.stat_0 == 0 and prison.stat_1 == 5000 and prison.stat_2 == 240 and prison.stat_3 == 64,
		"Annual prison statistics use old arrests and police funding",
	)
	var college := city.microsim(7)
	_check(
		college.stat_0 == 6 and college.stat_1 == 3333 and college.stat_2 == 166 and college.stat_3 == 90,
		"Annual college statistics use its cohort and college funding",
	)
	_check(document.misc_u32(0x1038) == 29, "Annual police statistics replace old arrests")
	_check(document.misc_u32(0x103c) == 1, "Annual prison statistics rebuild the prison bonus")
	_check(random.position == 12, "Annual services consume process random values in record order")



func test_annual_prison_overcrowding(reference_root: String) -> void:
	for case in [[700, 107, true], [500, 105, false]]:
		var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
		var city := CityModel.from_document(document)
		var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
		microsims[8] = Tiles.PRISON
		microsims[8 + 2] = 0xff
		microsims[8 + 3] = 0xff
		_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Prison fixture installs one prison record")
		_check(document.set_misc_u32(0x01f0 + 0xd8 * 4, 16), "Prison fixture counts one prison")
		_check(document.set_misc_u32(0x1038, 0), "Prison fixture clears old arrests")
		_check(document.set_misc_u32(0x102c, 90000), "Prison fixture sets normal population")
		_check(document.set_misc_u32(0x077c + 5 * 0x006c + 4, 80), "Prison fixture sets police funding")
		var random := SequenceRandom.new([case[0], 0])
		var result := AnnualMicrosims.run(city, 0, 0, 0, random)
		_check(result.ok, "Prison fixture completes: %s" % result.error)
		_check(city.microsim(1).stat_3 == case[1], "The 10,000 prisoner limit adds a random value: %d" % city.microsim(1).stat_3)
		var expected: Array[NewsEvent] = []

		if case[2]:
			expected.append(NewsEvent.new(0x25, 0))

		_check(
			NewsEvent.same_arrays(result.news_items, expected),
			"Only more than 105 hundred prisoners reports prison overcrowding: %s" % [result.news_items],
		)

func test_annual_special_microsim_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	var special_tiles := [Tiles.GAS_POWER, Tiles.ZOO, Tiles.STATUE, Tiles.MAYOR_HOUSE, Tiles.WATER_TREATMENT, Tiles.MARINA, Tiles.PLYMOUTH_ARCOLOGY, Tiles.LAUNCH_ARCOLOGY, Tiles.LLAMA_DOME]

	for index in special_tiles.size():
		microsims[(index + 1) * 8] = special_tiles[index]

	microsims[1 * 8 + 1] = 10
	microsims[4 * 8 + 1] = 3
	microsims[4 * 8 + 4] = 0x12
	microsims[4 * 8 + 5] = 0x34
	microsims[4 * 8 + 6] = 0
	microsims[4 * 8 + 7] = 2
	microsims[7 * 8 + 1] = 12
	microsims[7 * 8 + 2] = 0
	microsims[7 * 8 + 3] = 10
	microsims[7 * 8 + 4] = 0
	microsims[7 * 8 + 5] = 100
	microsims[8 * 8 + 1] = 10
	microsims[8 * 8 + 2] = 0
	microsims[8 * 8 + 3] = 20
	microsims[8 * 8 + 4] = 0
	microsims[8 * 8 + 5] = 200
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Annual special fixture installs XMIC records")
	_check(document.set_misc_u32(0x01f0 + 0xf8 * 4, 9), "Annual special fixture counts marina tiles")
	_check(document.set_misc_u32(0x01f0 + 0xfb * 4, 16), "Annual special fixture counts first arcology tiles")
	_check(document.set_misc_u32(0x01f0 + 0xfe * 4, 16), "Annual special fixture counts launch arcology tiles")
	_check(document.set_misc_u32(0x077c + 0 * 0x006c + 4, 7), "Annual special fixture sets residential tax")
	_check(document.set_misc_u32(0x077c + 1 * 0x006c + 4, 7), "Annual special fixture sets commercial tax")
	_check(document.set_misc_u32(0x077c + 2 * 0x006c + 4, 7), "Annual special fixture sets industrial tax")
	_check(document.set_misc_u32(0x1020, 10000), "Annual special fixture sets arcology population")
	_check(document.set_misc_u32(0x102c, 90000), "Annual special fixture sets normal population")
	var process_random := SequenceRandom.new([6, 43, 5, 123, 31, 0xaa, 0x3ff, 0x7f, 0x3f])
	var lfsr := SequenceLfsrRandom.new([5, 7, 9])
	var game_lcg := SequenceGameRandom.new([101, 202, 303, 404])
	var result := AnnualMicrosims.run(
		city, 0, 0, 0, process_random, lfsr, game_lcg, 80, 70
	)
	_check(result.ok, "Annual special statistics complete: %s" % result.error)
	var power := city.microsim(1)
	_check(
		power.stat_0 == 11 and power.stat_2 == 86,
		"Annual power statistics age the plant and use the power percentage",
	)
	var zoo := city.microsim(2)
	_check(
		zoo.stat_0 == 1 and zoo.stat_1 == 2 and zoo.stat_2 == 3 and zoo.stat_3 == 4,
		"Annual zoo statistics use four game LCG values",
	)
	_check(city.microsim(3).stat_2 == 1, "Annual statue statistics use one process random value")
	var mayor_house := city.microsim(4)
	_check(
		mayor_house.stat_0 == 4 and mayor_house.stat_2 == 0 and mayor_house.stat_3 == 1,
		"Annual mayor house statistics advance the term and store process approval",
	)
	var water_facility := city.microsim(5)
	_check(
		water_facility.stat_0 == 75 and water_facility.stat_1 == 23 and water_facility.stat_2 == 166,
		"Annual water-facility statistics use water demand and three process random values",
	)
	_check(city.microsim(6).stat_1 == 77, "Annual marina statistics use tile count and one LFSR value")
	_check(city.microsim(7).stat_2 == 1109, "Annual first arcology statistics apply tax growth")
	_check(city.microsim(8).stat_2 == 1413, "Annual launch arcology statistics apply tax growth")
	_check(document.misc_u32(0x1020) == 2522, "Annual arcology statistics replace arcology population")
	var dome := city.microsim(9)
	_check(
		dome.stat_0 == 0xaa and dome.stat_1 == 12273 and dome.stat_2 == 1661 and dome.stat_3 == 830,
		"Annual Llama Dome statistics use four process random values",
	)
	_check(process_random.position == 9, "Annual special facilities consume process random values in order")
	_check(lfsr.position == 3, "Annual marinas and arcologies consume LFSR values in order")
	_check(game_lcg.position == 4, "Annual zoos consume game LCG values in order")
	_check(result.random_records_pending == 0, "Annual special statistics have all required random sources")

	var renewal_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var renewal_city := CityModel.from_document(renewal_document)
	var renewal_microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	renewal_microsims[8] = 0xc9
	renewal_microsims[9] = 50
	_check(renewal_document.find_chunk("XMIC").set_decoded_payload(renewal_microsims), "Annual renewal fixture installs an old power plant")
	var renewal_text: PackedByteArray = renewal_document.find_chunk("XTXT").decoded_payload.duplicate()
	renewal_text[1 * CityState.MAP_SIZE + 2] = 52
	_check(renewal_document.find_chunk("XTXT").set_decoded_payload(renewal_text), "Annual renewal fixture links the power plant")
	_check(renewal_document.set_misc_u32(0x0014, 3000), "Annual renewal fixture sets funds")
	_check(renewal_document.set_misc_u32(0x1000, 1), "Annual renewal fixture disables disasters")
	var renewal := AnnualMicrosims.run(renewal_city, 0, 0, 0, ZeroRandom.new(), null, null, 80, -1)
	_check(renewal.ok, "Annual power renewal completes: %s" % renewal.error)
	_check(renewal_city.microsim(1).stat_0 == 0, "Annual power renewal resets plant age")
	_check(renewal_city.funds() == 1000, "Annual gas-power renewal deducts the original cost")
	_check(renewal.expired_power_records.is_empty(), "A paid annual power renewal does not request demolition")

	var expiry_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			expiry_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Annual expiry fixture clears %s" % chunk_id,
		)

	_check(expiry_document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Annual expiry fixture clears XLAB")
	_check(expiry_document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Annual expiry fixture clears XMIC")
	_check(expiry_document.set_misc_i32(0x14, 10000), "Annual expiry fixture sets funds")
	_check(expiry_document.set_misc_u32(0x01f0, 16384), "Annual expiry fixture counts clear tiles")
	_check(expiry_document.set_misc_u32(0x01f0 + 0xc9 * 4, 0), "Annual expiry fixture clears gas count")
	_check(expiry_document.set_misc_u32(0x1000, 0), "Annual expiry fixture enables disasters")
	_check(
		expiry_document.set_misc_u32(ToolAvailability.MISC_INVENTION_YEARS, 0),
		"Annual expiry fixture unlocks gas power",
	)
	var expiry_city := CityModel.from_document(expiry_document)
	var gas := Buildings.apply(
		expiry_city, 3, 5, Vector2i(20, 20), LfsrRandom.new(1), Random.new(1)
	)
	_check(gas.ok and gas.overlay_id == 61, "Annual expiry fixture builds a gas plant")
	var old_power: PackedByteArray = expiry_document.find_chunk("XMIC").decoded_payload.duplicate()
	old_power[10 * 8 + 1] = 50
	_check(expiry_document.find_chunk("XMIC").set_decoded_payload(old_power), "Annual expiry fixture sets plant age 50")
	var expiry_random := CountingRandom.new()
	var expired := AnnualMicrosims.run(
		expiry_city, 0, 0, 0, expiry_random, null, null, 80, -1
	)
	_check(expired.ok, "Annual expired-power update completes: %s" % expired.error)
	_check(
		expired.demolished_power_records.size() == 1 and expired.expired_power_records.is_empty()
		and expired.demolished_power_records[0].record == 10
		and expired.demolished_power_records[0].tile == 0xc9
		and expired.demolished_power_records[0].x == 19
		and expired.demolished_power_records[0].y == 19,
		"Annual expired power completes its demolition",
	)
	_check(expiry_city.microsim(10).tile_id == 0, "Annual power demolition releases the XMIC record")
	_check(expiry_city.label(61).is_empty(), "Annual power demolition releases the facility label")
	_check(expiry_city.text_overlay_id(19, 19) == 0, "Annual power demolition clears XTXT")
	_check(
		expiry_city.building_id(19, 19) >= 1
		and expiry_city.building_id(19, 19) <= 4
		and expiry_city.building_id(22, 22) >= 1
		and expiry_city.building_id(22, 22) <= 4,
		"Annual power demolition changes the full plant to rubble",
	)
	_check(expiry_document.misc_u32(0x01f0 + 0xc9 * 4) == 0, "Annual power demolition clears the gas tile count")
	_check(expiry_random.position == 145, "Annual power demolition consumes plant and visual random values in order")
	_check(
		expired.effect_events.size() == 64
		and expired.effect_events[0].frame == 0
		and expired.effect_events[16].frame == 1
		and expired.effect_events[63].frame == 3,
		"Annual power demolition returns four ordered native dust frames",
	)
	_check(not NewsEvent.contains(expired.news_items, 0x1f8, 0), "Annual power demolition does not report sound as news")
	_check(SoundEvent.same_arrays(expired.sound_events, SoundEvent.from_ids([504])), "Annual power demolition reports the explosion sound")

	var aus_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var aus_city := CityModel.from_document(aus_document)
	var aus_microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	aus_microsims[8] = 0xff
	aus_microsims[14] = 0x12
	aus_microsims[15] = 0x34
	_check(aus_document.find_chunk("XMIC").set_decoded_payload(aus_microsims), "Annual AUS fixture installs a Llama Dome")
	_check(aus_document.set_misc_u32(0x102c, 8000), "Annual AUS fixture sets normal population")
	var aus_random := SequenceRandom.new([1, 2, 3])
	var aus_result := AnnualMicrosims.run(
		aus_city, 0, 0, 0, aus_random, null, null, -1, -1, true
	)
	_check(aus_result.ok, "Annual AUS Llama Dome update completes: %s" % aus_result.error)
	var aus_dome := aus_city.microsim(1)
	_check(
		aus_dome.stat_0 == 2
		and aus_dome.stat_1 == 1001
		and aus_dome.stat_2 == 13
		and aus_dome.stat_3 == 0x1234,
		"The Australian Llama Dome path uses three values and preserves statistic three",
	)
	_check(aus_random.position == 3, "The Australian Llama Dome path consumes three process random values")


func test_arcology_launch_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Arcology launch fixture clears %s" % chunk_id,
		)

	_check(document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Arcology launch fixture clears XLAB")
	_check(document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Arcology launch fixture clears XMIC")
	_check(document.set_misc_i32(0x14, 20000000), "Arcology launch fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Arcology launch fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0xfe * 4, 0), "Arcology launch fixture clears launch count")
	_check(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 6), "Arcology launch fixture sets metropolis progression")

	for invention_index in range(12, 16):
		_check(
			document.set_misc_u32(
				ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
				0,
			),
			"Arcology launch fixture unlocks arcology %d" % invention_index,
		)

	var city := CityModel.from_document(document)
	var launch := Buildings.apply(
		city, 5, 8, Vector2i(20, 20), LfsrRandom.new(1), Random.new(1)
	)
	_check(launch.ok and launch.site == Rect2i(19, 19, 4, 4), "Arcology launch fixture builds a launch arcology")
	var text_overlays: PackedByteArray = document.find_chunk("XTXT").decoded_payload.duplicate()

	for index in launch.tile_indices:
		text_overlays[index] = 0xfe

	# Install the markers through the city so its XTXT mirror matches the chunk.
	# Writing the chunk alone leaves the mirror stale before the phase even runs.
	_check(city.replace_text_overlays(text_overlays), "Arcology launch fixture installs launch markers")
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)

	for record_id in range(1, 101):
		var offset := record_id * CityState.MICROSIM_RECORD_SIZE
		microsims[offset] = 0xfe
		microsims[offset + 1] = 12
		microsims[offset + 2] = 0
		microsims[offset + 3] = 65
		microsims[offset + 4] = 0xea
		microsims[offset + 5] = 0x60

	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Arcology launch fixture installs one hundred records")
	_check(document.set_misc_u32(0x01f0 + 0xfe * 4, 4816), "Arcology launch fixture crosses the tile threshold")
	_check(document.set_misc_u32(0x1020, 6000000), "Arcology launch fixture sets old arcology population")
	_check(document.set_misc_u32(0x102c, 20000000), "Arcology launch fixture sets normal population")

	for budget_id in 3:
		_check(document.set_misc_u32(0x077c + budget_id * 0x006c + 4, 0), "Arcology launch fixture clears tax %d" % budget_id)

	var lfsr_values: Array[int] = []

	for _index in 100:
		lfsr_values.append(0)

	var lfsr := SequenceLfsrRandom.new(lfsr_values)
	var process_random := CountingRandom.new()
	var result := AnnualMicrosims.run(city, 0, 0, 0, process_random, lfsr)
	_check(result.ok, "Arcology launch completes: %s" % result.error)
	_check(result.arcology_launched and not result.arcology_launch_pending, "Arcology launch resolves its threshold event")
	_check(result.launch_arcology_records == 100, "Arcology launch counts XMIC launch records")
	_check(
		result.launched_structures == 1,
		"Arcology launch demolishes each marked structure once: %s" % result.launched_structures,
	)
	_check(document.misc_u32(0x1020) == 6360000, "Arcology launch stores the new arcology population")
	_check(city.funds() == 29800000, "Arcology launch awards one hundred thousand dollars per record")
	_check(
		city.building_id(19, 19) >= 1
		and city.building_id(19, 19) <= 4
		and city.building_id(22, 22) >= 1
		and city.building_id(22, 22) <= 4,
		"Arcology launch changes the marked structure to rubble: %d, %d"
		% [city.building_id(19, 19), city.building_id(22, 22)],
	)
	_check(city.text_overlay_id(19, 19) == 0xfe, "Arcology launch preserves its special XTXT marker")
	_check(document.misc_u32(0x01f0 + 0xfe * 4) == 4800, "Arcology launch decrements demolished tile counts")
	_check(process_random.position == 144, "Arcology launch consumes visual and rubble random values")
	_check(
		result.effect_events.size() == 64
		and result.effect_events[0].frame == 0
		and result.effect_events[63].frame == 3,
		"Arcology launch returns its four ordered native dust frames",
	)
	_check(lfsr.position == 100, "Arcology launch consumes one LFSR value per record")
	_check(result.news_items.is_empty(), "Arcology launch adds no newspaper stories: %s" % [result.news_items])
	_check(
		result.notice_ids == PackedInt32Array([529, 530]),
		"Arcology launch requests the start and completion notices: %s" % result.notice_ids,
	)
	_check(SoundEvent.same_arrays(result.sound_events, SoundEvent.from_ids([504])), "Arcology launch reports one explosion sound: %s" % [result.sound_events])
	_check(result.complete, "Arcology launch completes the annual microsimulation action")
