extends SceneTree

func _initialize() -> void:
	call_deferred("run_check")

func run_check() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.new_city_session.independent_template = true
	main._open_new_city_dialog()
	for selection in range(1, 4):
		var edge: int = Sc2File.MAP_SIZES[selection]
		main.new_city_dialog.size_input.select(selection)
		main.new_city_dialog.size_input.item_selected.emit(selection)
		await create_timer(0.3).timeout
		assert(main.new_city_session.preview_document.map_size == edge)
		assert(main.new_city_session.preview_options.get("size") == edge)
		assert(main.new_city_dialog.preview_view.texture.get_width() == edge)
	main._cancel_new_city()
	main.app_zoom_graphics = AppSettingsStore.normalize_zoom_graphics([0, 1, 2, 2, 2, 2])
	main.map_view.zoom_factor = 0.25
	main.overlay_mode = "underground"
	for edge in [256, 384, 512, 128]:
		assert(main._activate_document(EmptyCityTemplate.create(edge)))
		assert(main.map_view.city.map_size == edge)
		assert((main.frame_simulation != null) == (edge > 128))
		assert(main.map_view.city_texture.get_size() == Vector2(CityIsometricRenderer.output_size_for_view(2, edge)))
		if edge > 128:
			main.speed_controller.set_speed(GameSpeedController.Speed.CHEETAH)
			main.frame_simulation.advance_time(200, 200)
			assert(main.frame_simulation.is_pending())
	main.queue_free()
	await process_frame
	print("PASS: automatic size preview and underground city replacement with pending simulation across map sizes")
	quit()
