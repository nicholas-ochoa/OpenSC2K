extends SceneTree
## In the running application, a frozen city draws the same pixels on the GPU
## moving-object path (20 Hz) and on the original CPU path (5 Hz). This covers
## the region cache, window scale, graphics sizes and screen buffer placement.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: moving occlusion pixels need a native GPU window")
		quit()

		return

	OS.set_environment("OPENSC2K_CITY_RENDERER", "gpu")
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(main.city_session._activate_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/FLARANGE.SC2")))
	main.main_menu.hide()
	var compared := 0

	for record in main.city.thing_count():
		var thing: Dictionary = main.city.thing(record)

		if int(thing.type) not in [1, 2, 3, 9, 10]:
			continue

		for zoom in [0.5, 1.0, 2.0]:
			main.map_view.zoom_factor = zoom
			main.map_view.center_on_tile(Vector2i(int(thing.x), int(thing.y)))
			await _wait_for_regions(main)
			var original := await _capture(main, 5)
			var smooth := await _capture(main, 20)
			assert(main.map_view.moving_occlusion_active())
			var differences := _differences(original, smooth)
			assert(differences.is_empty(), "Record %d at %d%% differs at %d pixels, first %s" % [record, int(zoom * 100), differences.size(), differences.slice(0, 4)])
			compared += 1

	assert(compared >= 6, "Not enough visible moving objects in the test city")
	main.queue_free()
	await process_frame
	print("PASS: GPU and CPU moving-object paths draw identical application frames (%d views)" % compared)
	quit()


func _capture(main: Node, rate: int) -> Image:
	main.settings._set_moving_frame_rate(rate)
	main.moving_sprites._refresh_moving_things()

	for frame in 3:
		await RenderingServer.frame_post_draw

	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)

	return image


func _wait_for_regions(main: Node) -> void:
	var deadline := Time.get_ticks_msec() + 30000

	while (main.region_cache == null or not main.region_cache.ready()) and Time.get_ticks_msec() < deadline:
		main.map_render._poll_region_cache()
		await process_frame

	assert(main.region_cache != null and main.region_cache.ready())


func _differences(left: Image, right: Image) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if left.get_size() != right.get_size():
		return [Vector2i(-1, -1)]

	if left.get_data() == right.get_data():
		return result

	for y in left.get_height():
		for x in left.get_width():
			if left.get_pixel(x, y) != right.get_pixel(x, y):
				result.append(Vector2i(x, y))

	return result
