extends SceneTree
## Moving objects publish their saved position once per 200 ms simulation tick.


class FrozenCommands extends CityDynamicCommandCache:
	func get_commands(city: CityState, sprites: Sc2SpriteArchive, view: int, _phase: int) -> Array[CityDynamicCommand]:
		return super.get_commands(city, sprites, view, 0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("OPENSC2K_CITY_RENDERER", "gpu")
	var main: CityApplication = (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	main.render_caches.dynamic_command_cache = FrozenCommands.new()
	assert(main.city_session.activate_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2")))
	main.main_menu.hide()
	main.map_view.zoom_factor = 1.0
	var airplane := -1
	for record in main.document_state.city.thing_count():
		if main.document_state.city.thing(record).type == 1:
			airplane = record
			break
	assert(airplane >= 0, "The fixture needs an airplane")
	var thing := main.document_state.city.thing(airplane)
	main.map_view.center_on_tile(Vector2i(thing.x, thing.y))
	await _wait_for_regions(main)
	main.moving_sprites.refresh_moving_things()
	var controller := main.simulation_state.speed_controller
	assert(controller.set_speed(GameSpeedController.Speed.TURTLE))
	controller.accumulator_msec = 0.0
	var ticks := 0
	var moved := false
	var before := _airplane_position(main, airplane)
	var shown := _visual_positions(main)
	assert(not shown.is_empty(), "The fixture needs visible moving objects")
	for frame in 40:
		var result := controller.advance_time(25.0, 100000 + (frame + 1) * 25)
		assert(result.ok)
		main.frame.consume_simulation_result(result)
		if (frame + 1) % 8 != 0:
			assert(result.moving_results.is_empty(), "Movement must wait for the next 200 ms tick")
			assert(_airplane_position(main, airplane) == before)
			assert(_visual_positions(main) == shown, "Sprites must hold their position between ticks")
		else:
			assert(result.moving_results.size() == 1)
			ticks += 1
			var after := _airplane_position(main, airplane)
			moved = moved or after != before
			var found := false
			for visual in main.map_view._dynamic_canvas.visuals:
				if visual.position == after and not visual.shadow:
					found = true
			assert(found, "The tick must immediately display the saved airplane position")
			before = after
			shown = _visual_positions(main)
	assert(ticks == 5 and moved, "One second must produce five moving-object ticks")
	assert(controller.set_speed(GameSpeedController.Speed.PAUSED))
	for frame in 8:
		var result := controller.advance_time(25.0, 101000 + (frame + 1) * 25)
		assert(result.ok and result.moving_results.is_empty())
		main.frame.consume_simulation_result(result)
		assert(_airplane_position(main, airplane) == before)
		assert(_visual_positions(main) == shown, "Pausing must hold moving objects still")
	main.queue_free()
	await process_frame
	print("PASS: moving objects update at 5 Hz, hold between ticks, and stop when paused")
	quit()


func _airplane_position(main: CityApplication, record: int) -> Vector2:
	var view := main.static_render.city_view_size()
	var sprites := main.static_render.sprite_archive_for_view(view)
	var commands := main.render_caches.dynamic_command_cache.get_commands(main.document_state.city, sprites, view, 0)
	for command in commands:
		if command.record == record and not command.shadow:
			return Vector2(command.position * CityIsometricRenderer.view_configuration(view).divisor)
	assert(false, "The airplane needs a draw command")
	return Vector2.INF


func _visual_positions(main: CityApplication) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for visual in main.map_view._dynamic_canvas.visuals:
		positions.append(visual.position)
	return positions


func _wait_for_regions(main: CityApplication) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	main.map_render.poll_region_cache()
	while (main.render_caches.region_cache == null or not main.render_caches.region_cache.ready()) and Time.get_ticks_msec() < deadline:
		await process_frame
		main.map_render.poll_region_cache()
	assert(main.render_caches.region_cache != null and main.render_caches.region_cache.ready())
