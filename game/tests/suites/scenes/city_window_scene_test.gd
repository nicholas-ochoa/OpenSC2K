extends "res://tests/support/scene_case.gd"


func run() -> void:
	var scene := preload("res://src/ui/city_windows/city_population_window.tscn")
	var first := scene.instantiate() as CityPopulationWindow
	var second := scene.instantiate() as CityPopulationWindow
	root.add_child(first)
	root.add_child(second)
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
	industry.free()
	var graph := preload("res://src/ui/city_windows/city_graph_window.tscn").instantiate() as CityGraphWindow
	root.add_child(graph)
	assert(graph.series_buttons.size() == 16)
	graph.series_buttons[0].toggled.emit(false)
	assert((graph.graph_control.selected_mask & 1) == 0)
	graph.series_buttons[0].toggled.emit(true)
	assert((graph.graph_control.selected_mask & 1) == 1)
	graph.get_node("Background/Margin/Column/Controls/TimeScales/Scale100Yrs").pressed.emit()
	assert(graph.graph_control.time_scale == 2)
	graph.free()
	var city_map := preload("res://src/ui/city_windows/city_map_window.tscn").instantiate() as CityMapDialog
	root.add_child(city_map)
	await process_frame
	var map_control := city_map.map_control
	assert(map_control.mode_buttons.size() == 2 and map_control.mode_buttons[0].button_pressed)
	var requested: Array[CityViewMode.Mode] = []
	city_map.isometric_view_requested.connect(func(mode: CityViewMode.Mode) -> void: requested.append(mode))
	map_control.mode_buttons[1].pressed.emit()
	assert(requested.is_empty(), "Map modes leave the city view alone until the checkbox is on")
	map_control.isometric_check.button_pressed = true
	assert(requested == [CityViewMode.Mode.CITY], "Zones has no data view")
	map_control.tab_bar.current_tab = 6
	assert(map_control.current_mode() == "pollution" and requested[-1] == CityViewMode.Mode.POLLUTION)
	map_control.tab_bar.current_tab = 5
	map_control.mode_buttons[1].pressed.emit()
	assert(map_control.current_mode() == "police_power" and requested[-1] == CityViewMode.Mode.POLICE_POWER)
	city_map.sync_view_mode(CityViewMode.Mode.POLICE_POWER)
	assert(map_control.isometric_check.button_pressed, "The window keeps the box while it drives the view")
	city_map.sync_view_mode(CityViewMode.Mode.HEIGHT)
	assert(not map_control.isometric_check.button_pressed, "Another view clears the box")
	city_map.free()
	print("PASS: City window scene controls, independent selections and close")
