extends SceneTree
## Large SC2X budgets use monthly history before converting raw totals to cash.

@warning_ignore_start("integer_division")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	city.set_age_in_days(0)
	var values := PackedInt32Array()
	values.resize(Sc2BudgetLayout.COUNT)
	var costs := [100_000_000, 75_000_000, 50_000_000]
	for id in 3:
		_set_budget(city, id, Sc2BudgetLayout.CURRENT, costs[id])
		_set_budget(city, id, Sc2BudgetLayout.YEAR_TO_DATE, costs[id] * 7)
		_set_budget(city, id, Sc2BudgetLayout.MONTHS, costs[id])
		_set_budget(city, id, Sc2BudgetLayout.MONTHS + Sc2BudgetLayout.MONTH_FUNDING, 7)
	var before := city.document.serialize().data
	var previous := -1
	for rate in 23:
		for id in 3:
			values[id] = rate
		var report := BudgetReport.capture(city, values)
		var expected := 0
		for id in 3:
			var annual_raw: int = costs[id] * (7 + rate * 11)
			var amount := annual_raw / 900
			_check(report.estimated[id] == amount, "Tax forecast is correct at rate %d, category %d" % [rate, id])
			var history_total := 0
			for monthly_amount in report.history[id]:
				history_total += monthly_amount
			_check(history_total == amount, "Monthly history matches the tax forecast")
			expected += amount
		var grouped := BudgetReport.group_amount(report.estimated, 0)
		_check(grouped == expected and grouped > previous, "Increasing tax increases income")
		previous = grouped
	_check(city.document.serialize().data == before, "Proposed rates preserve saved data")
	# Dollar amounts and the cash-flow total can also exceed a 32-bit value.
	_set_budget(city, Sc2BudgetLayout.POLICE, Sc2BudgetLayout.CURRENT, 30_000_000)
	values[Sc2BudgetLayout.POLICE] = 100
	city.document.set_misc_u32(Sc2MiscLayout.YEAR_END, 1)
	var large_report := BudgetReport.capture(city, values)
	_check(large_report.estimated[Sc2BudgetLayout.POLICE] == -3_000_000_000, "Large service costs stay negative")
	_check(large_report.estimated_cash == -2_934_000_000, "The cash-flow total uses 64-bit arithmetic")
	_check(BudgetAdvice.select(city, large_report, 2, SimRandom.new(1), 0) == 0, "Large tax income does not produce false bond advice")
	_test_settlement_and_reload()
	_test_sc2_report()
	print("Budget overflow: %d failures" % failures)
	quit(1 if failures else 0)


func _test_settlement_and_reload() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	city.set_funds(0)
	city.document.set_misc_u32(Sc2MiscLayout.NO_DISASTERS, 1)
	var values := PackedInt32Array()
	values.resize(Sc2BudgetLayout.COUNT)
	var random := SimRandom.new(1)
	for month in 12:
		city.set_age_in_days(month * CityCalendar.DAYS_PER_MONTH)
		for id in 3:
			_set_budget(city, id, Sc2BudgetLayout.CURRENT, [90_000_000, 75_000_000, 60_000_000][id])
			values[id] = 10 + month
		_check(BudgetPhase.set_funding(city, values, true).ok, "Set monthly tax rates")
		_check(BudgetPhase.run(city, random).ok, "Record monthly income")
	_check(city.document.misc_i32(Sc2MiscLayout.BUDGETS + Sc2BudgetLayout.YEAR_TO_DATE) < 0, "Fixture crosses the legacy accumulator limit")
	var saved := city.document.serialize()
	_check(saved.ok, "Save the SC2X budget")
	var reloaded := Sc2File.new()
	_check(reloaded.parse(saved.data), "Reload the SC2X budget")
	city = CityState.from_document(reloaded)
	var report := BudgetReport.capture(city, values)
	_check(report.ytd_cash == 46_500_000, "Reload retains the full year-to-date income")
	_check(BudgetReport.group_amount(report.year_to_date, 0) == 46_500_000, "Grouped actual income is correct")
	city.set_age_in_days(CityCalendar.DAYS_PER_YEAR)
	var settlement := BudgetPhase.settle_year(city)
	_check(settlement.ok and settlement.settled_year, "Settle the reloaded budget")
	_check(city.funds() == 46_500_000, "Actual settlement uses the full income")
	_check(not BudgetPhase.settle_year(city).settled_year, "Settlement cannot pay twice")
	city.set_age_in_days(CityCalendar.DAYS_PER_YEAR)
	_check(BudgetPhase.run(city, random).ok, "Start the next budget year")
	var next := BudgetReport.capture(city, values)
	_check(next.ytd_cash == 5_250_000, "January excludes the previous year's history")


func _test_sc2_report() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create())
	city.document.set_misc_u32(Sc2MiscLayout.YEAR_END, 1)
	var values := PackedInt32Array()
	values.resize(Sc2BudgetLayout.COUNT)
	for id in 3:
		_set_budget(city, id, Sc2BudgetLayout.CURRENT, [90_000_000, 75_000_000, 60_000_000][id])
		values[id] = 18
	var report := BudgetReport.capture(city, values)
	_check(BudgetReport.group_amount(report.estimated, 0) == -3_266_230, "SC2 retains the original forecast wrapping")


func _set_budget(city: CityState, id: int, field: int, value: int) -> void:
	city.document.set_misc_i32(Sc2MiscLayout.BUDGETS + id * Sc2BudgetLayout.RECORD_SIZE + field, value)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
