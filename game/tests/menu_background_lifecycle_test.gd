extends "res://tests/support/scene_test_case.gd"
## Hiding the menu frees its private city and buffers, late workers are drained, and reopening loads a city again.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sprites := FixtureGraphics.pack().large_sprites
	var palette := Sc2Palette.index_encoding()
	var folder := "user://menu-background-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join("DEFAULT.SC2"), FileAccess.WRITE)
	file.store_buffer(EmptyCityTemplate.create(128).serialize().data)
	file.close()

	var background := MainMenuCityBackground.new()
	root.add_child(background)
	background.configure(folder, palette, sprites)
	assert(background.demo_city != null and background.source_path.ends_with("DEFAULT.SC2"))
	await _drain(background)
	assert(background.static_image != null and background.demo_texture != null)
	var expected := background.static_image.get_data()
	var city_reference: WeakRef = weakref(background.demo_city)
	var engine_reference: WeakRef = weakref(background.controller.engine)
	var image_reference: WeakRef = weakref(background.static_image)
	var texture_reference: WeakRef = weakref(background.demo_texture)

	background.hide()
	background.release_city()
	await process_frame
	assert(city_reference.get_ref() == null and engine_reference.get_ref() == null,
		"The hidden menu must not retain its private city or simulation")
	assert(image_reference.get_ref() == null and texture_reference.get_ref() == null,
		"The hidden menu must not retain its CPU image or GPU texture")
	assert(background.demo_city == null and background.controller == null and background.source_path.is_empty())
	assert(background.demo_palette == null and background.demo_sprites == null and background.elapsed == 0.0)
	assert(background.static_layer.texture == null and background.occlusion_commands.is_empty()
		and background.occlusion_grid.is_empty() and background.sprite_cache.is_empty() and background.dynamic_visuals.is_empty())
	background.replace_graphics(palette, sprites)
	assert(background.render_thread == null and background.demo_sprites == null,
		"Replacing hidden menu artwork must not restart rendering or keep graphics")

	background.configure(folder, palette, sprites)
	background.show()
	assert(background.demo_city != null and background.demo_sprites == sprites)
	await _drain(background)
	assert(background.static_image.get_data() == expected, "Reopened menu must draw a newly loaded city")

	# Hiding while a worker is running must return without joining it. Its result
	# must not recreate the released buffers when _process later collects it.
	background._start_render()
	var pending := background.render_thread
	background.hide()
	background.release_city()
	assert(background.render_thread == pending)
	await _drain(background)
	assert(background.demo_texture == null and background.static_image == null and background.occlusion_commands.is_empty())

	# Reopening before the released city's worker finishes must discard its image
	# and render the new city after the worker is drained.
	background.configure(folder, palette, sprites)
	pending = background.render_thread
	background.release_city()
	background.configure(folder, palette, sprites)
	var city := background.demo_city
	assert(city != null and background.render_thread == pending)
	await _drain(background)
	assert(background.demo_city == city and background.static_image.get_data() == expected)

	background.queue_free()
	await process_frame
	DirAccess.remove_absolute(folder.path_join("DEFAULT.SC2"))
	DirAccess.remove_absolute(folder)
	print("PASS: hidden menu city and buffer release, late worker disposal and new city on return")
	quit()


func _drain(background: MainMenuCityBackground) -> void:
	var deadline := Time.get_ticks_msec() + 15000

	while background.render_thread != null and Time.get_ticks_msec() < deadline:
		await process_frame

	assert(background.render_thread == null, "Menu rendering did not finish")
