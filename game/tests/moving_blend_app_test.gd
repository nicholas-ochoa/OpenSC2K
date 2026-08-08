extends SceneTree
## A moving-object tick starts a display blend in the city view. The blend
## ends at the saved position, and 5 Hz keeps the CPU path without a blend.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("OPENSC2K_CITY_RENDERER", "gpu")
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	main.preferences.moving_frame_rate = 20
	assert(main.city_session._activate_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/FLARANGE.SC2")))
	main.map_view.zoom_factor = 1.0
	var airplane := _first_record(main.city, [1])
	assert(airplane >= 0, "The test city needs an airplane")
	var thing: ThingRecord = main.city.thing(airplane)
	main.map_view.center_on_tile(Vector2i(int(thing.x), int(thing.y)))
	await _wait_for_regions(main)
	main.moving_sprites.refresh_moving_things()
	assert(main.map_view.moving_occlusion_active(), "GPU regions enable moving-object occlusion")
	assert(_gpu_visuals(main).size() > 0, "Moving objects use the GPU visual path")

	# Several ticks move the objects. Each tick starts a new blend.
	var start := 100000
	var moved := false
	# The first tick has no earlier position to blend from.
	main.moving_sprites.note_moving_tick(start - 200)
	main.moving_sprites.advance_blend(start)

	for tick in 6:
		var now := start + tick * 200
		var before := CityIsometricRenderer.moving_thing_anchor(main.city, airplane, 2)
		assert(main.simulation_engine.advance_moving_things(now).ok)
		main.moving_sprites.note_moving_tick(now)
		main.moving_sprites.refresh_moving_things()
		var after := CityIsometricRenderer.moving_thing_anchor(main.city, airplane, 2)
		var canvas: CityDynamicSpriteCanvas = main.map_view._dynamic_canvas

		if before.is_empty() or after.is_empty() or not ApplicationMovingSprites.can_blend(before, after) or before.anchor == after.anchor:
			main.moving_sprites.advance_blend(now + 200)
			continue

		moved = true
		# The new tick shows the previous position first.
		assert(canvas.blend_offsets.get(airplane, Vector2.ZERO) == _screen_round(main, before.anchor - after.anchor), "A blend starts at the displayed position")
		main.moving_sprites.advance_blend(now + 49)
		assert(canvas.blend_offsets.get(airplane) == _screen_round(main, before.anchor - after.anchor), "20 Hz waits 50 ms between positions")
		main.moving_sprites.advance_blend(now + 100)
		assert(canvas.blend_offsets.get(airplane) == _screen_round(main, (before.anchor - after.anchor) * 0.5), "The blend is half done after 100 ms")
		assert(canvas.blend_orders.get(airplane) == maxi(int(before.order), int(after.order)), "A blend uses the later draw order of its two tiles")
		main.moving_sprites.advance_blend(now + 200)
		assert(canvas.blend_offsets.get(airplane) == Vector2.ZERO, "The blend ends at the saved position")

	assert(moved, "Airplane did not move during the test")

	# 5 Hz keeps the original steps and the exact CPU occlusion path.
	main.settings._set_moving_frame_rate(5)
	assert(not main.map_view.moving_occlusion_active())
	assert(_gpu_visuals(main).is_empty(), "5 Hz uses the CPU visual path")
	main.moving_sprites.note_moving_tick(start + 2000)
	assert(main.map_view._dynamic_canvas.blend_offsets.is_empty(), "5 Hz does not blend")
	main.settings._set_moving_frame_rate(30)
	assert(main.map_view.moving_occlusion_active() and _gpu_visuals(main).size() > 0)
	main.queue_free()
	await process_frame
	print("PASS: moving-object ticks blend at the selected rate and 5 Hz keeps the original steps")
	quit()


func _wait_for_regions(main: Node) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	# This test stops the frame loop that polls the cache every frame. Only a
	# poll moves the cache to the new camera, so poll before trusting ready():
	# otherwise ready() answers for the previous view.
	main.map_render.poll_region_cache()

	while (main.render_caches.region_cache == null or not main.render_caches.region_cache.ready()) and Time.get_ticks_msec() < deadline:
		await process_frame
		main.map_render.poll_region_cache()

	assert(main.render_caches.region_cache != null and main.render_caches.region_cache.ready())


## The display keeps whole render-target pixels.
func _screen_round(main: Node, offset: Vector2) -> Vector2:
	var scale: float = main.map_view.screen_pixels_per_source_pixel()

	return (offset * scale).round() / scale


func _first_record(city: CityState, types: Array) -> int:
	for record in city.thing_count():
		if int(city.thing(record).type) in types:
			return record

	return -1


func _gpu_visuals(main: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for visual: Dictionary in main.map_view._dynamic_canvas.visuals:
		if visual.has("gpu_mode"):
			result.append(visual)

	return result
