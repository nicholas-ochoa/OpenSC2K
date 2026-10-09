extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := VisualEnhancementOptions.normalize({})
	assert(options.detail_lights_min_zoom == 2)
	var zooms := [0.1, 0.25, 0.5, 1.0, 2.0, 4.0]
	for threshold in zooms.size():
		options.detail_lights_min_zoom = threshold
		for index in zooms.size():
			assert(VisualEnhancementOptions.detail_lights_visible(options, zooms[index]) == (index >= threshold))
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	main.map_view.city_source = CityMapSource.new(CityIsometricRenderer.output_size_for_view(2, 128))
	options.detail_lights_min_zoom = 2
	main.preferences.visual_enhancements = options
	var lights := main.visual_environment.night_lighting
	main.map_view.zoom_factor = 0.25
	lights.process(true, 1.0, options, 1.0, 1.0)
	assert(not lights.ground.visible and lights.ground.cache.is_empty() and lights.ground.pending.is_empty())
	assert(lights.output.visible, "Detail cutoff disabled building glow")
	lights.ground.pending.append(Vector2i(4, 4))
	var signal_clock := lights.ground.clock
	for frame in 3:
		lights.process(true, 1.0, options, 1.0, 1.0)
	assert(lights.ground.pending.size() == 1 and lights.ground.cache.is_empty(), "Disabled detail lights performed queued build work")
	assert(lights.ground.clock == signal_clock, "Disabled junctions still advanced")
	assert(not lights.moving.visible and not lights.life.visible)
	main.map_view.zoom_factor = 0.5
	lights.process(true, 1.0, options, 0.0, 0.0)
	assert(lights.ground.visible and lights.detail_enabled)
	main.map_view.zoom_factor = 0.1
	options.detail_lights_min_zoom = 0
	lights.process(true, 1.0, options, 0.0, 0.0)
	assert(lights.ground.visible, "Explicit all-zoom setting still blocks 10 percent")
	var tab := VisualEnhancementsTab.new()
	root.add_child(tab)
	await process_frame
	tab.show_values(options)
	var choice := tab.controls.detail_lights_min_zoom as OptionButton
	choice.select(4)
	choice.item_selected.emit(4)
	assert(tab.selected_values().detail_lights_min_zoom == 4)
	var saved := VisualEnhancementOptions.normalize(tab.selected_values())
	tab.show_values(saved)
	assert(choice.selected == 4)
	tab.queue_free()
	main.queue_free()
	await process_frame
	print("PASS: default50%, all threshold boundaries, no street build/signal work below cutoff, building glow preserved and menu round-trip")
	quit()
