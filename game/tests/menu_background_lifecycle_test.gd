extends SceneTree
## Hidden menu buffers are released, late workers are drained, and reopening works.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sprites := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var palette := Sc2Palette.index_encoding()
	var background := MainMenuCityBackground.new()
	root.add_child(background)
	background.demo_city = CityState.from_document(EmptyCityTemplate.create(128))
	background.demo_palette = palette
	background.demo_sprites = sprites
	background.controller = GameSpeedController.new(SimulationEngine.new(background.demo_city))
	background.controller.set_speed(GameSpeedController.Speed.PAUSED)
	background.configure("", palette, sprites)
	await _drain(background)
	assert(background.static_image != null and background.demo_texture != null)
	var expected := background.static_image.get_data()
	var image_reference: WeakRef = weakref(background.static_image)
	var texture_reference: WeakRef = weakref(background.demo_texture)
	var city := background.demo_city
	var elapsed := background.elapsed

	background.hide()
	background.release_render_data()
	await process_frame
	assert(image_reference.get_ref() == null and texture_reference.get_ref() == null,
		"The hidden menu must not retain its CPU image or GPU texture")
	assert(background.static_layer.texture == null and background.occlusion_commands.is_empty()
		and background.occlusion_grid.is_empty() and background.sprite_cache.is_empty() and background.dynamic_visuals.is_empty())
	assert(background.demo_city == city and background.elapsed == elapsed)
	background.replace_graphics(palette, sprites)
	assert(background.render_thread == null, "Replacing hidden menu artwork must not restart rendering")

	background.configure("", palette, sprites)
	background.show()
	await _drain(background)
	assert(background.static_image.get_data() == expected, "Reopened menu must redraw the same private city")
	assert(background.demo_city == city)

	# Hiding while a worker is running must return without joining it. Its result
	# must not recreate the released buffers when _process later collects it.
	background._start_render()
	var pending := background.render_thread
	background.hide()
	background.release_render_data()
	assert(background.render_thread == pending)
	await _drain(background)
	assert(background.demo_texture == null and background.static_image == null and background.occlusion_commands.is_empty())
	background.configure("", palette, sprites)
	background.show()
	await _drain(background)
	assert(background.static_image.get_data() == expected)
	background.queue_free()
	await process_frame
	print("PASS: hidden menu buffer release, private city retention, late worker disposal and redraw on return")
	quit()


func _drain(background: MainMenuCityBackground) -> void:
	var deadline := Time.get_ticks_msec() + 15000

	while background.render_thread != null and Time.get_ticks_msec() < deadline:
		await process_frame

	assert(background.render_thread == null, "Menu rendering did not finish")
