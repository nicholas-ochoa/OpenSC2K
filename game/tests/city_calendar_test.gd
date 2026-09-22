extends SceneTree


func _initialize() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	var cases := [
		[0, 1900, 1, 1], [24, 1900, 1, 25], [25, 1900, 2, 1],
		[299, 1900, 12, 25], [300, 1901, 1, 1], [4294967295, 14318457, 8, 21],
	]

	for entry in cases:
		assert(city.set_age_in_days(entry[0]))
		assert(city.current_year() == entry[1])
		assert(city.current_month() == entry[2])
		assert(city.current_day() == entry[3])
		var phase := SimulationClock.state_for_day(entry[0])
		assert(phase.elapsed_years == entry[1] - 1900)
		assert(phase.month == entry[2] - 1)
		assert(phase.month_day == entry[3] - 1)

	var before := city.document.find_chunk("MISC").decoded_payload.duplicate()
	assert(not city.set_age_in_days(-1))
	assert(city.document.find_chunk("MISC").decoded_payload == before)
	assert(SimulationClock.state_for_day(-1).city_days == 0)
	var month_end := SimulationClock.new(24).advance_day()
	assert(month_end.actions == PackedStringArray(["budget", "month_start"]))
	var year_end := SimulationClock.new(299).advance_day()
	assert(year_end.elapsed_years == 1 and year_end.month == 0 and year_end.month_day == 0)
	print("PASS: saved dates and simulation schedule at calendar boundaries")
	quit()
