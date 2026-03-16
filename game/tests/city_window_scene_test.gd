extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	print("PASS: City window scene controls, independent selections and close")
	quit()
