extends SceneTree

var preview_requests := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dialog := preload("res://src/ui/startup/new_city_terrain_dialog.tscn").instantiate() as NewCityTerrainDialog
	root.add_child(dialog)
	await process_frame
	dialog.preview_requested.connect(func() -> void: preview_requests += 1)
	dialog.size_input.select(dialog.size_input.get_item_index(256))
	dialog.reset_fields("Test Mayor")
	var setup := dialog.setup_options()
	assert(setup.mayor_name == "Test Mayor" and setup.difficulty == 1 and setup.starting_year == 1900)
	var terrain := dialog.terrain_options()
	assert(terrain.size == 256 and terrain.native_maps and terrain.smooth_slopes)
	assert(terrain.features.is_empty())

	dialog.city_name_input.text = "  Test City  "
	dialog.mayor_name_input.text = "  Second Mayor  "
	dialog.difficulty_input.select(2)
	dialog.year_input.select(3)
	setup = dialog.setup_options()
	assert(setup.city_name == "  Test City  " and setup.mayor_name == "  Second Mayor  ")
	assert(setup.difficulty == 3 and setup.starting_year == 2050)
	dialog.hills_input.value = 7
	dialog.water_input.value = 13
	dialog.trees_input.value = 21
	dialog.feature_inputs.branch.button_pressed = true
	dialog.feature_inputs.bay.button_pressed = true
	terrain = dialog.terrain_options()
	assert(terrain.hills == 7 and terrain.water == 13 and terrain.trees == 21)
	assert(terrain.ocean and terrain.river and terrain.features == ["branch", "bay"])
	terrain.features.clear()
	setup.city_name = "Changed copy"
	assert(dialog.terrain_options().features == ["branch", "bay"])
	assert(dialog.setup_options().city_name == "  Test City  ")
	assert(preview_requests > 0)

	dialog.compatibility_input.button_pressed = true
	terrain = dialog.terrain_options()
	assert(terrain.size == 128 and not terrain.native_maps)
	assert(dialog.size_input.disabled and dialog.native_maps_input.disabled)
	assert(terrain.features == ["branch", "bay"])
	var revision := dialog.generation_revision
	var landscape := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var minimap := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	dialog.show_preview(landscape, minimap, "Ready")
	assert(dialog.candidate_valid and not dialog.done_button.disabled)
	assert(dialog.preview_view.texture != null and dialog.landscape_background.texture != null)
	dialog.invalidate()
	assert(not dialog.candidate_valid and dialog.done_button.disabled)
	assert(dialog.generation_revision == revision + 1)
	dialog.reset_fields("Reset Mayor")
	assert(dialog.preview_view.texture == null and dialog.landscape_background.texture == null)
	assert(dialog.terrain_options().features.is_empty())
	assert(not dialog.size_input.disabled and not dialog.native_maps_input.disabled)
	dialog.free()
	print("PASS: New City setup options, terrain options, compatibility, and preview state")
	quit()
