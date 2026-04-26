extends "res://tests/support/scene_case.gd"


func run() -> void:
	var scene := preload("res://src/ui/city_windows/city_population_window.tscn")
	var first := scene.instantiate() as CityPopulationWindow
	var second := scene.instantiate() as CityPopulationWindow
	root.add_child(first)
	root.add_child(second)
	assert(first.population_control.owner == first)
	first.mode_buttons[1].button_pressed = true
	first.mode_buttons[1].pressed.emit()
	assert(first.population_control.mode == PopulationWindowControl.Mode.HEALTH)
	assert(second.mode_buttons[0].button_pressed)
	assert(first.mode_buttons[0].button_group != second.mode_buttons[0].button_group)
	first.popup_centered()
	await process_frame
	first.close_requested.emit()
	assert(not first.visible)
	first.free()
	second.free()
	var industry := preload("res://src/ui/city_windows/city_industry_window.tscn").instantiate() as CityIndustryWindow
	root.add_child(industry)
	industry.mode_buttons[1].pressed.emit()
	assert(industry.industry_control.mode == IndustryWindowControl.Mode.TAX_RATES)
	assert(industry.industry_control.owner == industry)
	industry.free()
	var graph := preload("res://src/ui/city_windows/city_graph_window.tscn").instantiate() as CityGraphWindow
	root.add_child(graph)
	assert(graph.graph_control.owner == graph and graph.series_buttons.size() == 16)
	graph.series_buttons[0].toggled.emit(false)
	assert((graph.graph_control.selected_mask & 1) == 0)
	graph.series_buttons[0].toggled.emit(true)
	assert((graph.graph_control.selected_mask & 1) == 1)
	graph.get_node("Background/Margin/Column/Controls/TimeScales/Scale100Yrs").pressed.emit()
	assert(graph.graph_control.time_scale == 2)
	graph.free()
	var city_map := preload("res://src/ui/city_windows/city_map_window.tscn").instantiate() as CityMapDialog
	root.add_child(city_map)
	assert(city_map.map_control != null and city_map.map_control.owner == city_map)
	city_map.free()
	var budget := preload("res://src/ui/city_windows/budget_dialog.tscn").instantiate() as BudgetDialog
	root.add_child(budget)
	assert(not budget.visible, "Budget must stay closed until requested in game")
	assert(budget.controls.size() == 16 and budget.controls[0].owner == budget)
	assert(budget.get_ok_button().text == "Apply")
	assert(budget.bond_dialog.get_ok_button().text == "Yes" and budget.bond_dialog.get_cancel_button().text == "No")
	budget.free()
	print("PASS: City window scene controls, independent selections and close")
