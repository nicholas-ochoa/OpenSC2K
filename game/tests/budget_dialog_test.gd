extends SceneTree

const Budget = preload("res://src/simulation/economy/budget_phase.gd")
var city: CityState
var values: PackedInt32Array


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.gui_embed_subwindows = true
	city = CityState.from_document(EmptyCityTemplate.create())
	city.set_age_in_days(250)
	city.set_funds(50000)
	values = Budget.funding_values(city)
	values.fill(100)
	values[0] = 2
	values[1] = 3
	values[2] = 4
	values[3] = 1
	values[4] = 80000
	values[8] = 60
	values[9] = 90
	for id in Budget.BUDGET_COUNT:
		_set_budget(id, Budget.BUDGET_CURRENT, 1200)
		_set_budget(id, Budget.BUDGET_YEAR_TO_DATE, 24000)
		for month in 12:
			_set_budget(id, Budget.BUDGET_MONTHS + month * 8, 100)
			_set_budget(id, Budget.BUDGET_MONTHS + month * 8 + 4, 10)
	city.document.set_misc_u32(Budget.MISC_YEAR_END, 0)
	var before := city.document.serialize().data
	var report := BudgetReport.capture(city, values)
	assert(report.actual_months == 11)
	assert(report.year_to_date[0] == 26)
	assert(report.estimated[0] == 29)
	assert(report.year_to_date[5] == -2000)
	assert(report.estimated[5] == -12000)
	assert(report.history[0][0] == 1)
	assert(report.history[0][11] == 2)
	assert(report.history_rates[0][0] == 10)
	assert(report.history_rates[0][11] == 2)
	assert(city.document.serialize().data == before, "Opening reports changed saved data")
	for month in 12:
		city.set_age_in_days(month * 25)
		assert(BudgetReport.capture(city, values).actual_months == month + 1)
	city.document.set_misc_u32(Budget.MISC_YEAR_END, 1)
	report = BudgetReport.capture(city, values)
	assert(report.actual_months == 12 and report.estimated[0] == 32)
	city.document.set_misc_u32(Budget.MISC_YEAR_END, 0)
	city.set_age_in_days(250)
	var dialog := preload("res://src/ui/city_windows/budget_dialog.tscn").instantiate() as BudgetDialog
	root.add_child(dialog)
	var sounds: Array[int] = []
	dialog.sound_requested.connect(func(ids: Array[int]) -> void: sounds.append_array(ids))
	dialog.set_city(city)
	before = city.document.serialize().data
	dialog.open_budget(values, false, false)
	await process_frame
	assert(dialog.funding_values() == values)
	assert(sounds.is_empty(), "Opening the budget played a tax-change sound")
	dialog.size = Vector2i(940, 660)
	dialog.tabs.current_tab = 3
	await process_frame
	await process_frame
	var ordinance_bounds := dialog.tabs.get_global_rect()
	for field: Control in dialog.ordinance_control.ordinance_checks + dialog.ordinance_control.ordinance_amounts + dialog.ordinance_control.category_amounts:
		assert(ordinance_bounds.encloses(field.get_global_rect()), "Ordinance control clipped at minimum window size")
	dialog.tabs.current_tab = 2
	await process_frame
	assert(dialog.tabs.get_global_rect().encloses(dialog.bond_summary_label.get_global_rect()), "Bond summary clipped")
	dialog.tabs.current_tab = 0
	dialog.detail_toggle.button_pressed = true
	dialog.detail_toggle.button_pressed = false
	assert(dialog.funding_values() == values, "Switching views changed the funding rates")
	dialog.group_controls[0].value = 7
	assert(dialog.funding_values().slice(0, 3) == PackedInt32Array([7, 7, 7]))
	dialog.controls[1].value = 9
	assert(dialog.funding_values().slice(0, 3) == PackedInt32Array([7, 9, 7]))
	dialog._group_text_changed("7", 0)
	dialog._commit_group_edit(0)
	assert(dialog.funding_values().slice(0, 3) == PackedInt32Array([7, 7, 7]), "Entering the first rate still consolidates mixed rates")
	dialog.group_controls[6].value = 75
	assert(dialog.funding_values().slice(8, 10) == PackedInt32Array([75, 75]))
	dialog.group_controls[7].value = 80
	assert(dialog.funding_values().slice(10, 16) == PackedInt32Array([80, 80, 80, 80, 80, 80]))
	assert(sounds == [512, 512, 513], "Wrong sounds for tax and funding changes")
	dialog._group_changed(7, 0)
	assert(sounds.size() == 3, "Setting the same value played another sound")
	dialog.controls[0].value = 6
	assert(sounds == [512, 512, 513, 513], "Individual tax decreases also cheer")
	for button in dialog.action_buttons:
		assert(button.icon != null and not button.tooltip_text.is_empty())
		# Oversized artwork keeps a scaled interface sharp; the drawn icon stays small.
		assert(button.icon.get_width() > BudgetDialog.ICON_WIDTH)
		assert(button.get_theme_constant("icon_max_width") == BudgetDialog.ICON_WIDTH)
		assert(not button.has_theme_stylebox_override("normal"), "Actions keep the normal button background")
	assert(city.document.serialize().data == before, "Editing proposed funding changed saved data")
	dialog.history_category.select(7)
	dialog._refresh_history()
	assert(dialog.history_table.get_root().get_child_count() == 12)
	assert(dialog.history_table.columns == 9)
	dialog.set_bond_state(50, 10000, 80000, 8)
	assert(dialog.issue_bond_button.disabled and not dialog.repay_bond_button.disabled)
	dialog.set_bond_state(0, 9999, 0, 0)
	assert(dialog.repay_bond_button.disabled)
	dialog.hide()
	dialog.open_budget(values, true, true)
	assert(dialog.get_cancel_button().disabled and dialog.exclusive)
	dialog.open_bond_confirmation("issue", 8)
	assert(dialog.bond_confirmation_visible())
	dialog.bond_dialog.hide()
	dialog.show_advice(0, 294, null)
	assert(dialog.advisor_dialog.visible)
	dialog.reset_dialogs()
	assert(not dialog.visible and not dialog.advisor_dialog.visible and not dialog.bond_confirmation_visible())
	dialog.queue_free()
	await process_frame
	var cape := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/CAPEQUES.SC2"))
	var cape_before := cape.document.serialize().data
	var cape_report := BudgetReport.capture(cape, Budget.funding_values(cape))
	assert(CityValuePhase.calculate(cape).city_value == 221135, "CapeQuest city value: %d" % CityValuePhase.calculate(cape).city_value)
	assert(cape_report.ytd_cash == -4508 and cape_report.estimated_cash == -5389)
	assert(BudgetReport.group_amount(cape_report.year_to_date, 0) == 2081)
	assert(BudgetReport.group_amount(cape_report.estimated, 0) == 2506)
	var ordinances := OrdinanceCommand.snapshot(cape)
	assert(ordinances.item_amounts.slice(0, 4) == PackedInt32Array([405, 680, 810, 340]))
	assert(ordinances.estimated_amount == -1922)
	var transport_ytd := 0
	var transport_estimate := 0
	for id in range(10, 16):
		for month in 12:
			transport_estimate += cape_report.history[id][month]
			if month < 10:
				transport_ytd += cape_report.history[id][month]
	assert(transport_ytd == -683 and transport_estimate == -820)
	assert(cape.document.serialize().data == cape_before)
	var valuation_city := CityState.from_document(EmptyCityTemplate.create())
	for entry in [[0xc6, 1, 4000], [0xc7, 1, 400], [0xc8, 1, 6600], [0xc9, 16, 6600],
			[0xca, 16, 2000], [0xcb, 16, 15000], [0xcc, 16, 100], [0xcd, 16, 1300],
			[0xce, 16, 28000], [0xcf, 16, 40000], [0xd7, 16, 3000], [0xda, 16, 5000]]:
		valuation_city.document.set_misc_u32(0x1f0 + entry[0] * 4, entry[1])
		assert(CityValuePhase.calculate(valuation_city).city_value == entry[2])
		valuation_city.document.set_misc_u32(0x1f0 + entry[0] * 4, 0)
	_test_advice()
	print("PASS: Budget reports, mixed rates, group edits, history, bond controls, annual state and advisors")
	quit()


func _set_budget(id: int, field: int, value: int) -> void:
	assert(city.document.set_misc_u32(Budget.MISC_BUDGETS + id * Budget.BUDGET_RECORD_SIZE + field, value & 0xffffffff))


func _graph(id: int, value: int) -> void:
	var chunk := city.document.find_chunk("XGRP")
	var data := chunk.decoded_payload.duplicate()
	var offset := id * 52 * 4
	data[offset] = (value >> 24) & 255
	data[offset + 1] = (value >> 16) & 255
	data[offset + 2] = (value >> 8) & 255
	data[offset + 3] = value & 255
	assert(chunk.set_decoded_payload(data))


func _advice(advisor: int, power := 0, seed_value := 1) -> int:
	return BudgetAdvice.select(city, BudgetReport.capture(city, values), advisor, SimRandom.new(seed_value), power) - 294


func _test_advice() -> void:
	city = CityState.from_document(EmptyCityTemplate.create())
	values = Budget.funding_values(city)
	values.fill(100)
	values[0] = 7
	values[1] = 7
	values[2] = 7
	city.set_funds(10000)
	city.document.set_misc_u32(0x102c, 1000)
	city.document.set_misc_u32(0x0fa0, 0)
	for index in 3:
		city.document.set_misc_u32(0x718 + index * 4, 0)
	assert(_advice(0) == 0)
	city.document.set_misc_u32(0x718, (-667) & 0xffffffff)
	assert(_advice(0) == 11)
	city.document.set_misc_u32(0x718, (-666) & 0xffffffff)
	assert(_advice(0) == 0)
	city.set_funds(999)
	assert(_advice(0) == 13)
	city.document.set_misc_u32(0x718, 667)
	assert(_advice(0) == 12)
	_graph(5, 31)
	assert(_advice(1, 100) == 14)
	city.document.set_misc_u32(0xfa0, 0x80000)
	assert(_advice(1, 99) == 15)
	_graph(5, 0)
	_graph(7, 31)
	assert(_advice(1) == 16 and _advice(3) == 16)
	city.document.set_misc_u32(0xfa0, 0x800)
	assert(_advice(1) == 17)
	city.document.set_misc_u32(0xfa0, 0xa04)
	assert(_advice(1) == 18)
	_graph(7, 0)
	city.document.set_misc_u32(0xfa0, 2)
	city.document.set_misc_u32(0x718, (-667) & 0xffffffff)
	assert(_advice(1) == 19)
	city.document.set_misc_u32(0xfa0, 1)
	city.document.set_misc_u32(0x71c, (-667) & 0xffffffff)
	assert(_advice(1) == 20)
	for test in [[19, 5], [20, 6], [30, 6], [40, 16], [41, 7]]:
		_graph(7, test[0])
		assert(_advice(3) == test[1])
	city.set_funds(-1001)
	assert(_advice(2) == 1)
	city.set_funds(-1000)
	assert(_advice(2) == 4)
	city.set_funds(0)
	city.document.set_misc_u32(0x58, 2)
	city.document.set_misc_u32(0x18, 0)
	assert(_advice(2) == 2)
	city.document.set_misc_u32(0x58, 7)
	_set_budget(4, Budget.BUDGET_CURRENT, 10)
	assert(_advice(2) == 3)
	_set_budget(4, Budget.BUDGET_CURRENT, 0)
	assert(_advice(2) == 0)
	city.document.set_misc_u32(0x1f0 + 0xd3 * 4, 9)
	city.document.set_misc_u32(0x102c, 15001)
	assert(_advice(4) == 10)
	city.document.set_misc_u32(0x102c, 10000)
	assert(_advice(4) == 9)
	city.document.set_misc_u32(0x102c, 9999)
	assert(_advice(4) == 8)
	city.document.set_misc_u32(0x1f0 + 0xd1 * 4, 9)
	city.document.set_misc_u32(0x102c, 25001)
	assert(_advice(5) == 22)
	city.document.set_misc_u32(0x102c, 1000)
	assert(_advice(5) == 21)
	city.document.set_misc_u32(0x102c, 20000)
	city.document.set_misc_u32(0xfa0, 0)
	var seen := {}
	for seed_value in range(1, 20):
		seen[_advice(5, 0, seed_value)] = true
	assert(seen.has(23) and seen.has(24) and seen.has(25))
	city.document.set_misc_u32(0xfa0, 0x460)
	assert(_advice(5) == 26)
	var random := SimRandom.new(123)
	var expected := SimRandom.new(123)
	expected.next_u15()
	BudgetAdvice.select(city, BudgetReport.capture(city, values), 5, random, 0)
	assert(random.state == expected.state, "Expected one process-random draw for health advice")
	city.document.set_misc_u32(0x7c + 12, 1)
	assert(_advice(6) == 28)
	city.document.set_misc_u32(0x1f0 + 0xd6 * 4, 9)
	city.document.set_misc_u32(0x7c + 36, 1)
	assert(_advice(6) == 29)
	city.document.set_misc_u32(0x1f0 + 0xd9 * 4, 16)
	assert(_advice(6) == 27)
	values[10] = 99
	assert(_advice(7) == 30)
	values[10] = 100
	assert(_advice(7) == 31)
	_set_budget(10, Budget.BUDGET_CURRENT, 200)
	assert(_advice(7) == 0)
	_set_budget(10, Budget.BUDGET_CURRENT, 2001)
	assert(_advice(7) == 32)
