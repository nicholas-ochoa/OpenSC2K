extends "res://tests/support/core_test_suite.gd"

## Simulation: weather checks.

@warning_ignore_start("integer_division")

const WeatherDisaster = preload("res://src/simulation/disasters/weather_disaster_phase.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const ZeroLfsrRandom = TestRandoms.ZeroLfsrRandom
const SequenceLfsrRandom = TestRandoms.SequenceLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom


func test_weather_disaster_phase(reference_root: String) -> void:
	var power_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 1],
		[0x006c, 1],
		[0x1000, 1],
	]:
		_check(
			power_document.set_misc_u32(setting[0], setting[1]),
			"City-status fixture sets MISC 0x%x" % setting[0],
		)

	var power_random := SequenceRandom.new([])
	var power_result := WeatherDisaster.run(
		CityModel.from_document(power_document),
		power_random,
		ZeroLfsrRandom.new(),
		99,
		0,
		0,
		0,
	)
	_check(power_result.ok, "City-status phase completes: %s" % power_result.error)

	if power_result.ok:
		_check(
			power_result.status_index == WeatherDisaster.STATUS_POWER
			and power_result.status_news_type == 46
			and NewsEvent.same_arrays(power_result.news_items, [NewsEvent.new(46, 0)]),
			"A fully used power system requests more power with story type 46",
		)
		_check(
			power_result.disaster_type == WeatherDisaster.DISASTER_NONE
			and power_random.position == 0,
			"No Disasters suppresses the natural-disaster roll",
		)

	var stable_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 1],
		[0x006c, 1],
		[0x1000, 1],
		[0x1020, 0],
		[0x102c, 1000],
		[0x01f0 + WeatherDisaster.TILE_POLICE * 4, 9],
		[0x01f0 + WeatherDisaster.TILE_PRISON * 4, 0],
		[0x01f0 + WeatherDisaster.TILE_FIRE * 4, 9],
		[0x077c + WeatherDisaster.BUDGET_ROAD * 0x006c, 11],
	]:
		_check(
			stable_document.set_misc_u32(setting[0], setting[1]),
			"Stable city fixture sets MISC 0x%x" % setting[0],
		)

	var stable_result := WeatherDisaster.run(
		CityModel.from_document(stable_document),
		SequenceRandom.new([]),
		ZeroLfsrRandom.new(),
		0,
		0,
		0,
		0,
	)
	_check(
		stable_result.ok
		and stable_result.status_index == WeatherDisaster.STATUS_NONE
		and stable_result.news_items.is_empty(),
		"A supplied small city does not request an unnecessary service",
	)

	var hospital_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 1],
		[0x006c, 1],
		[0x1000, 1],
		[0x1020, 0],
		[0x102c, 25000],
		[0x01f0 + WeatherDisaster.TILE_POLICE * 4, 18],
		[0x01f0 + WeatherDisaster.TILE_PRISON * 4, 0],
		[0x01f0 + WeatherDisaster.TILE_FIRE * 4, 18],
		[0x01f0 + WeatherDisaster.TILE_HOSPITAL * 4, 0],
		[0x077c + WeatherDisaster.BUDGET_ROAD * 0x006c, 251],
	]:
		_check(
			hospital_document.set_misc_u32(setting[0], setting[1]),
			"Hospital-demand fixture sets MISC 0x%x" % setting[0],
		)

	var hospital_result := WeatherDisaster.run(
		CityModel.from_document(hospital_document),
		SequenceRandom.new([]),
		ZeroLfsrRandom.new(),
		0,
		0,
		0,
		0,
	)
	_check(
		hospital_result.ok
		and hospital_result.status_index == WeatherDisaster.STATUS_HOSPITAL
		and hospital_result.status_news_type == 51,
		"The recovered hierarchy requests a hospital after power, transit, police, fire, and water",
	)

	var wait_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(wait_document.set_misc_u32(0x001c, 1), "Disaster wait fixture selects Easy")
	_check(wait_document.set_misc_u32(0x006c, 9), "Disaster wait fixture selects severe weather text")
	_check(wait_document.set_misc_u32(0x1000, 0), "Disaster wait fixture enables disasters")
	var wait_city := CityModel.from_document(wait_document)
	_check(wait_city.set_age_in_days(99 * 25), "Disaster wait fixture selects month 99")
	var wait_random := SequenceRandom.new([])
	var wait_result := WeatherDisaster.run(
		wait_city, wait_random, ZeroLfsrRandom.new(), 0, 0, 0, 0
	)
	_check(
		wait_result.ok
		and wait_result.wait_months == 100
		and wait_result.disaster_type == WeatherDisaster.DISASTER_NONE
		and wait_random.position == 0,
		"Easy cities cannot receive a natural disaster before month 100",
	)

	var hurricane_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 3],
		[0x006c, 10],
		[0x0e44, 1],
		[0x1000, 0],
	]:
		_check(
			hurricane_document.set_misc_u32(setting[0], setting[1]),
			"Hurricane fixture sets MISC 0x%x" % setting[0],
		)

	var hurricane_city := CityModel.from_document(hurricane_document)
	_check(hurricane_city.set_age_in_days(30 * 25), "Hurricane fixture reaches Hard wait age")
	var hurricane_random := SequenceRandom.new([14])
	var hurricane_result := WeatherDisaster.run(
		hurricane_city, hurricane_random, ZeroLfsrRandom.new(), 0, 0, 0, 0
	)
	_check(
		hurricane_result.ok
		and hurricane_result.disaster_type == WeatherDisaster.DISASTER_HURRICANE
		and hurricane_result.disaster_roll == 14
		and hurricane_random.position == 1,
		"Ocean weather type 10 schedules a Hurricane on rolls below 15",
	)

	var tornado_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 3],
		[0x006c, 11],
		[0x1000, 0],
	]:
		_check(
			tornado_document.set_misc_u32(setting[0], setting[1]),
			"Tornado fixture sets MISC 0x%x" % setting[0],
		)

	var tornado_city := CityModel.from_document(tornado_document)
	_check(tornado_city.set_age_in_days(30 * 25), "Tornado fixture reaches Hard wait age")
	var tornado_random := SequenceRandom.new([14, 5, 7])
	var tornado_result := WeatherDisaster.run(
		tornado_city, tornado_random, ZeroLfsrRandom.new(), 0, 0, 0, 0
	)
	_check(
		tornado_result.ok
		and tornado_result.disaster_type == WeatherDisaster.DISASTER_TORNADO
		and tornado_result.disaster_point == Vector2i(8, 6)
		and tornado_random.position == 3,
		"Weather type 11 schedules a Tornado and keeps the original Y-then-X random order",
	)

	var fire_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 3],
		[0x0060, 255],
		[0x006c, 9],
		[0x1000, 0],
	]:
		_check(
			fire_document.set_misc_u32(setting[0], setting[1]),
			"Fire selector fixture sets MISC 0x%x" % setting[0],
		)

	var fire_city := CityModel.from_document(fire_document)
	_check(fire_city.set_age_in_days(30 * 25), "Fire selector fixture reaches Hard wait age")
	var fire_random := SequenceRandom.new([0, 1, 0, 4, 6])
	var fire_result := WeatherDisaster.run(
		fire_city, fire_random, ZeroLfsrRandom.new(), 0, 0, 0, 0
	)
	_check(
		fire_result.ok
		and fire_result.candidate_type == WeatherDisaster.DISASTER_FIRE
		and fire_result.disaster_type == WeatherDisaster.DISASTER_FIRE
		and fire_result.disaster_point == Vector2i(7, 5)
		and fire_random.position == 5,
		"A zero monthly roll can pass the Fire heat gate and select a map point",
	)

	var toxic_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 3],
		[0x006c, 9],
		[0x1000, 0],
	]:
		_check(
			toxic_document.set_misc_u32(setting[0], setting[1]),
			"Toxic selector fixture sets MISC 0x%x" % setting[0],
		)

	var pollution := PackedByteArray()
	pollution.resize(64 * 64)
	pollution.fill(0)
	pollution[10 * 64 + 20] = 200
	_check(
		toxic_document.find_chunk("XPLT").set_decoded_payload(pollution),
		"Toxic selector fixture stores one polluted coarse tile",
	)
	var toxic_city := CityModel.from_document(toxic_document)
	_check(toxic_city.set_age_in_days(30 * 25), "Toxic selector fixture reaches Hard wait age")
	var toxic_random := SequenceRandom.new([0, 4])
	var toxic_lfsr := SequenceLfsrRandom.new([0, 2, 3])
	var toxic_result := WeatherDisaster.run(
		toxic_city, toxic_random, toxic_lfsr, 0, 0, 0, 0
	)
	_check(
		toxic_result.ok
		and toxic_result.candidate_type == WeatherDisaster.DISASTER_TOXIC_SPILL
		and toxic_result.disaster_type == WeatherDisaster.DISASTER_TOXIC_SPILL
		and toxic_result.disaster_point == Vector2i(17, 38)
		and toxic_random.position == 2
		and toxic_lfsr.position == 3,
		"Toxic Spill selects a record-high polluted tile with the LFSR gates and jitter",
	)

	var invalid_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(invalid_document.set_misc_u32(0x001c, 0), "Invalid disaster fixture clears difficulty")
	_check(invalid_document.set_misc_u32(0x1000, 1), "Invalid disaster fixture first disables disasters")
	var invalid_suppressed := WeatherDisaster.run(
		CityModel.from_document(invalid_document),
		SequenceRandom.new([]),
		ZeroLfsrRandom.new(),
		0,
		0,
		0,
		0,
	)
	_check(
		invalid_suppressed.ok
		and invalid_suppressed.disaster_type == WeatherDisaster.DISASTER_NONE,
		"No Disasters returns before the original difficulty-table access",
	)
	_check(invalid_document.set_misc_u32(0x1000, 0), "Invalid disaster fixture enables disasters")
	var invalid_result := WeatherDisaster.run(
		CityModel.from_document(invalid_document),
		SequenceRandom.new([]),
		ZeroLfsrRandom.new(),
		0,
		0,
		0,
		0,
	)
	_check(
		not invalid_result.ok and not invalid_result.error.is_empty(),
		"The natural-disaster selector rejects an invalid saved difficulty",
	)
