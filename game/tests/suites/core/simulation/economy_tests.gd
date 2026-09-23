extends "res://tests/support/core_test_suite.gd"

## Simulation: economy checks.

@warning_ignore_start("integer_division")

const MonthStart = preload("res://src/simulation/core/month_start_phase.gd")
const CityValue = preload("res://src/simulation/economy/city_value_phase.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const SequenceRandom = TestRandoms.SequenceRandom


func test_month_start(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var original_values := PackedInt32Array()

	for index in 8:
		var value := (index + 1) * 13
		original_values.append(value)
		_check(
			document.set_misc_i32(0x05f0 + index * 4, value),
			"Month-start fixture sets zone population %d" % index,
		)

	_check(document.set_misc_i32(0x05ec, 0x12345678), "Month-start fixture sets preceding data")
	_check(document.set_misc_i32(0x0610, 0x23456789), "Month-start fixture sets following data")
	var city := CityModel.from_document(document)
	var result := MonthStart.run(city)
	_check(result.ok, "Month-start phase completes: %s" % result.error)
	_check(result.cleared_population_fields == 8, "Month-start phase reports eight cleared fields")

	for index in 8:
		_check(document.misc_i32(0x05f0 + index * 4) == 0, "Month-start clears zone population %d" % index)

	_check(document.misc_i32(0x05ec) == 0x12345678, "Month-start preserves preceding MISC data")
	_check(document.misc_i32(0x0610) == 0x23456789, "Month-start preserves following MISC data")


func test_city_value_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)

	for tile_id in 256:
		_check(
			document.set_misc_i32(0x01f0 + tile_id * 4, 0),
			"City-value fixture clears tile count 0x%02X" % tile_id,
		)

	_check(document.set_misc_u32(0x0fe8, 3), "City-value fixture sets subway count")

	for entry in [
		[0x0e, 2], [0x1d, 3], [0x2c, 4], [0x3f, 5], [0x51, 6],
		[0x61, 7], [0x6c, 8], [0xc6, 2], [0xc9, 32], [0xd1, 18],
		[0xd4, 9], [0xd5, 9], [0xd7, 16], [0xdc, 3], [0xdd, 2],
		[0xdf, 2], [0xe9, 2], [0xeb, 8], [0xec, 8], [0xed, 8],
		[0xf4, 9], [0xf5, 8], [0xf8, 9], [0xfa, 9], [0xfb, 16],
	]:
		_check(
			document.set_misc_u32(0x01f0 + int(entry[0]) * 4, int(entry[1])),
			"City-value fixture sets tile count 0x%02X" % int(entry[0]),
		)

	_check(document.set_misc_u32(0x01f0 + 0x0d * 4, 99), "City-value fixture sets small parks")
	_check(document.set_misc_u32(0x01f0 + 0xd0 * 4, 99), "City-value fixture sets city halls")
	var before := document.misc_i32(0x0024)
	var calculated := CityValue.calculate(city)
	_check(calculated.ok and calculated.city_value == 136956, "City value uses all recovered rules")
	_check(document.misc_i32(0x0024) == before, "City-value calculation is read-only")
	var result := CityValue.run(city)
	_check(result.ok and result.city_value == 136956, "City-value phase completes")
	_check(document.misc_i32(0x0024) == 136956, "City-value phase stores MISC city value")

	_check(document.set_misc_u32(0x01f0 + 0x0e * 4, 0xffff), "City-value fixture sets signed count")
	_check(document.set_misc_u32(0x0fe8, 0xffff), "City-value fixture sets signed subway count")
	var signed_result := CityValue.calculate(city)
	_check(
		signed_result.ok and signed_result.city_value == 136954,
		"City value sign-extends the supplied runtime counters",
	)


func test_budget_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_age_in_days(0), "Budget fixture selects January")
	var cleared_counts := true

	for tile_id in 256:
		cleared_counts = (
			document.set_misc_i32(0x01f0 + tile_id * 4, 0)
			and cleared_counts
		)

	_check(cleared_counts, "Budget fixture clears all tile counts")
	_check(document.set_misc_u32(0x0fe8, 4), "Budget fixture sets the subway count")

	for budget_id in 16:
		_check(
			document.set_misc_i32(0x077c + budget_id * 0x6c, 0)
			and document.set_misc_i32(0x077c + budget_id * 0x6c + 4, 0)
			and document.set_misc_i32(0x077c + budget_id * 0x6c + 8, 0),
			"Budget fixture clears record %d" % budget_id,
		)

	_check(document.set_misc_i32(0x077c, 900), "Budget fixture sets residential population")
	_check(document.set_misc_i32(0x0780, 7), "Budget fixture sets residential tax")
	_check(document.set_misc_i32(0x0bb4, 123), "Budget fixture sets prior road costs")
	_check(document.set_misc_i32(0x0bb8, 80), "Budget fixture sets road funding")
	_check(document.set_misc_u32(0x0fa0, (1 << 0) | (1 << 4)), "Budget fixture enables ordinances")

	for entry in [
		[0x1d, 2], [0x3f, 3], [0x45, 5], [0x51, 7], [0x61, 11], [0x6a, 13],
		[0x6c, 17], [0xd1, 18], [0xd2, 27], [0xd3, 36], [0xd6, 45], [0xd9, 32],
		[0xe9, 19], [0xec, 8], [0xed, 6],
	]:
		_check(
			document.set_misc_i32(0x01f0 + int(entry[0]) * 4, int(entry[1])),
			"Budget fixture sets tile count 0x%02X" % int(entry[0]),
		)

	var result := Budget.run(city, SequenceRandom.new([1]))
	_check(result.ok, "Budget phase completes: %s" % result.error)
	_check(document.misc_i32(0x0788) == 900, "Budget stores January residential count")
	_check(document.misc_i32(0x078c) == 7, "Budget stores January residential tax")
	_check(document.misc_i32(0x0784) == 6300, "Budget accumulates funded residential tax")
	_check(document.misc_i32(0x0bc0) == 123, "Budget stores prior January road costs")
	_check(document.misc_i32(0x0bc4) == 80, "Budget stores prior January road funding")
	_check(document.misc_i32(0x0bbc) == 9840, "Budget accumulates funded road costs")
	_check(result.current_costs[3] == -300, "Budget calculates active ordinance cost")
	_check(result.current_costs[4] == document.misc_i32(0x18), "Budget copies the bond count")
	_check(
		result.current_costs.slice(5, 10) == PackedInt32Array([3, 4, 2, 5, 2]),
		"Budget rebuilds service counts with the recovered footprint divisors",
	)
	_check(
		result.current_costs.slice(10, 16) == PackedInt32Array([510, 24, 20, 28, 23, 3]),
		"Budget rebuilds road, highway, bridge, rail, subway, and tunnel costs",
	)
	_check(document.misc_u32(0x0e3c) == 0, "January does not set the year-end flag")

	var december_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var december_city := CityModel.from_document(december_document)
	_check(december_city.set_age_in_days(275), "December budget fixture selects month 12")
	_check(december_document.set_misc_u32(0x0e3c, 0), "December budget fixture clears year end")
	var december := Budget.run(december_city, SequenceRandom.new([1]))
	_check(december.ok and december.month == 11, "December budget phase completes")
	_check(december_document.misc_u32(0x0e3c) == 1, "December sets the year-end flag")

	var annual_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var annual_city := CityModel.from_document(annual_document)
	_check(annual_city.set_age_in_days(300), "Annual budget fixture selects next January")
	_check(annual_city.set_funds(0), "Annual budget fixture clears funds")
	_check(annual_document.set_misc_u32(0x0e3c, 1), "Annual budget fixture sets year end")
	_check(annual_document.set_misc_u32(0x0ff0, 1), "Annual budget fixture enables auto budget")

	for budget_id in 16:
		_check(
			annual_document.set_misc_i32(0x077c + budget_id * 0x6c, 0)
			and annual_document.set_misc_i32(0x077c + budget_id * 0x6c + 4, 0)
			and annual_document.set_misc_i32(0x077c + budget_id * 0x6c + 8, 0),
			"Annual budget fixture clears record %d" % budget_id,
		)

	for entry in [[0, 900], [3, 900], [4, 1200], [5, 12], [10, 12000]]:
		_check(
			annual_document.set_misc_i32(0x077c + int(entry[0]) * 0x6c + 8, int(entry[1])),
			"Annual budget fixture sets year-to-date record %d" % int(entry[0]),
		)

	var annual := Budget.run(annual_city, SequenceRandom.new([1]))
	_check(annual.ok and annual.settled_year, "Budget settles the prior year in January")
	_check(annual_city.funds() == -1, "Budget applies the recovered annual divisors")
	_check(annual_document.misc_u32(0x0e3c) == 0, "Annual settlement clears year end")
	_check(
		annual.auto_budget_disabled and annual_document.misc_u32(0x0ff0) == 0,
		"Negative annual funds disable auto budget",
	)
	_check(annual.notice_ids == PackedInt32Array([292]), "Negative annual funds request the fiscal crisis notice")
	_check(
		annual.annual_microsim_update_pending and not annual.complete,
		"Annual microsimulation work stays visible",
	)

	var manual_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var manual_city := CityModel.from_document(manual_document)
	_check(manual_city.set_age_in_days(300), "Manual budget fixture selects January")
	_check(manual_document.set_misc_u32(0x0e3c, 1), "Manual budget fixture sets year end")
	_check(manual_document.set_misc_u32(0x0ff0, 0), "Manual budget fixture disables Auto Budget")
	var manual_before: PackedByteArray = manual_document.find_chunk("MISC").decoded_payload.duplicate()
	var manual := Budget.run(manual_city, SequenceRandom.new([1]))
	_check(
		manual.ok and manual.requires_annual_budget and not manual.complete,
		"Budget phase requests manual annual funding",
	)
	_check(
		manual_document.find_chunk("MISC").decoded_payload == manual_before,
		"A pending manual annual budget preserves MISC",
	)
	var funding_values := PackedInt32Array([
		8, 7, 6, 0, 0, 100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50,
	])
	var stored_funding := Budget.set_funding(manual_city, funding_values, true)
	_check(stored_funding.ok, "Budget stores all funding values")
	_check(
		Budget.funding_values(manual_city) == funding_values,
		"Budget reads back all stored funding values",
	)
	_check(manual_document.misc_u32(0x0ff0) == 1, "Budget stores Auto Budget")
	var stored_misc: PackedByteArray = manual_document.find_chunk("MISC").decoded_payload.duplicate()
	var short_values := funding_values.duplicate()
	short_values.resize(15)
	var invalid_funding := Budget.set_funding(manual_city, short_values, false)
	_check(not invalid_funding.ok, "Budget rejects an incomplete funding array")
	_check(
		manual_document.find_chunk("MISC").decoded_payload == stored_misc,
		"A rejected funding update preserves MISC",
	)

	var ordinance_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var ordinance_city := CityModel.from_document(ordinance_document)
	_check(ordinance_city.set_age_in_days(25), "Ordinance fixture selects February")
	_check(ordinance_city.set_funds(60000), "Ordinance fixture sets sufficient funds")
	_check(ordinance_document.set_misc_u32(0x0fa0, 0), "Ordinance fixture clears ordinances")
	_check(ordinance_document.set_misc_u32(0x1000, 0), "Ordinance fixture enables random events")
	var ordinance := Budget.run(ordinance_city, SequenceRandom.new([0, 0, 5]))
	_check(ordinance.ok and ordinance.news_items.size() == 1, "Budget emits a random ordinance event")
	_check(
		ordinance_document.misc_u32(0x0fa0) == 1 << 5
		and ordinance.news_items[0].type == 0x29
		and ordinance.news_items[0].argument == 5,
		"Budget stores and reports the selected ordinance",
	)


# the annual facility update runs between the settlement and the monthly work
func test_january_budget_order(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_age_in_days(299), "January order fixture selects the last December day")
	_check(document.set_misc_u32(0x0e3c, 1), "January order fixture sets year end")
	_check(document.set_misc_u32(0x0ff0, 1), "January order fixture enables Auto Budget")
	_check(document.set_misc_u32(0x1000, 1), "January order fixture stops random ordinances")
	_check(document.set_misc_u32(0x0fa0, 1 << 16), "January order fixture enables Energy Conservation")
	_check(document.set_misc_u32(0x1020, 0), "January order fixture clears arcology population")
	_check(document.set_misc_u32(0x102c, 100000), "January order fixture sets normal population")
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	microsims[8] = Tiles.PLYMOUTH_ARCOLOGY
	microsims[8 + 3] = 10
	microsims[8 + 4] = 0x13
	microsims[8 + 5] = 0x88
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "January order fixture installs one arcology")
	var engine := SimulationEngine.new(city, 1, 1, 1)
	engine.power_usage_percent = 50
	engine.water_usage_percent = 50
	var day := engine.advance_day()
	_check(day.ok and day.complete, "January order fixture completes the day: %s" % day.error)
	var arcology_population := document.misc_u32(0x1020)
	_check(arcology_population > 0, "The annual update stores the arcology population")
	_check(
		document.misc_i32(0x077c + 3 * 0x6c) == -(arcology_population + 100000),
		"The January ordinance cost uses the new arcology population: %d" % document.misc_i32(0x077c + 3 * 0x6c),
	)
	_check(
		day.phase_results.keys().find("annual_microsim") < day.phase_results.keys().find("budget"),
		"The annual update events come before the monthly budget events",
	)


# after a load, the annual update measures unknown power and water use on a copy
func test_january_unknown_utilities(_reference_root: String) -> void:
	var samples := []

	for known in [false, true]:
		var city := CityModel.from_document(EmptyCityTemplate.create())
		_check(city.set_age_in_days(299), "Utility fixture selects the last December day")
		_check(city.document.set_misc_u32(0x0e3c, 1), "Utility fixture sets year end")
		_check(city.document.set_misc_u32(0x0ff0, 1), "Utility fixture enables Auto Budget")
		city.set_building_id(10, 10, Tiles.COAL_POWER)
		city.set_building_id(10, 11, Tiles.WATER_PUMP)
		city.set_building_id(10, 12, Tiles.LOWER_CLASS_HOMES_1X1_1)

		for y in range(10, 13):
			city.set_tile_flag(10, y, 0xe0, true)

		var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
		microsims[8] = Tiles.COAL_POWER
		_check(city.document.find_chunk("XMIC").set_decoded_payload(microsims), "Utility fixture installs one plant record")
		var flags_before := city.tile_flags.duplicate()
		var engine := SimulationEngine.new(city, 7, 7, 7)

		if known:
			engine.power_usage_percent = samples[0][0]
			engine.water_usage_percent = samples[0][1]

		var day := engine.advance_day()
		_check(day.ok and day.complete, "The annual update completes with unknown utilities: %s" % [day.pending])
		_check(city.tile_flags == flags_before, "The utility measurement does not change XBIT")
		samples.append([
			engine.power_usage_percent, engine.water_usage_percent, city.microsim(1).stat_2,
			engine.random.state, engine.lfsr_random.state,
		])

	_check(samples[0][0] >= 0 and samples[0][1] >= 0, "The annual update measures power and water use")
	_check(samples[0] == samples[1], "A measured value gives the same annual result and random state: %s" % [samples])


# the speed controller passes the fiscal crisis notice to the interface
func test_fiscal_crisis_notice(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_age_in_days(299), "Notice fixture selects the last December day")
	_check(city.set_funds(0), "Notice fixture clears funds")
	_check(document.set_misc_u32(0x0e3c, 1), "Notice fixture sets year end")
	_check(document.set_misc_u32(0x0ff0, 1), "Notice fixture enables Auto Budget")
	_check(document.set_misc_i32(0x077c + 10 * 0x6c + 8, 12000), "Notice fixture sets a road cost")
	var engine := SimulationEngine.new(city, 1, 1, 1)
	engine.power_usage_percent = 50
	engine.water_usage_percent = 50
	var controller := GameSpeedController.new(engine)
	_check(controller.set_speed(GameSpeedController.Speed.CHEETAH), "Notice fixture selects Cheetah")
	var tick := controller.advance_time(GameSpeedController.BASE_TICK_MSEC)
	_check(tick.ok and tick.day_results.size() == 1, "Notice fixture runs the January day: %s" % tick.error)
	_check(city.funds() < 0 and not city.auto_budget_enabled(), "Notice fixture turns off Auto Budget")
	_check(tick.notice_ids == PackedInt32Array([292]), "The tick result contains the fiscal crisis notice: %s" % tick.notice_ids)


# an old power plant in January opens an extra edition through the controller
func test_power_plant_extra_edition(_reference_root: String) -> void:
	for extras in [0, 1]:
		var city := CityModel.from_document(EmptyCityTemplate.create())
		_check(city.set_age_in_days(299), "Extra-edition fixture selects the last December day")
		_check(city.document.set_misc_u32(0x0e3c, 1), "Extra-edition fixture sets year end")
		_check(city.document.set_misc_u32(0x0ff0, 1), "Extra-edition fixture enables Auto Budget")
		_check(city.document.set_misc_u32(0x1008, extras), "Extra-edition fixture sets the option")
		var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
		microsims[8] = Tiles.COAL_POWER
		microsims[8 + 1] = 48
		_check(city.document.find_chunk("XMIC").set_decoded_payload(microsims), "Extra-edition fixture installs an old plant")
		var engine := SimulationEngine.new(city, 1, 1, 1)
		engine.power_usage_percent = 50
		engine.water_usage_percent = 50
		var controller := GameSpeedController.new(engine)
		_check(controller.set_speed(GameSpeedController.Speed.CHEETAH), "Extra-edition fixture selects Cheetah")
		var tick := controller.advance_time(GameSpeedController.BASE_TICK_MSEC)
		_check(tick.ok and NewsEvent.contains(tick.news_items, 0x24, 0xcf + 0x37), "The old plant reports its age")
		_check(
			tick.newspaper_requested == (extras != 0),
			"The power plant story opens the newspaper only with extra editions: %s" % tick.newspaper_requested,
		)
