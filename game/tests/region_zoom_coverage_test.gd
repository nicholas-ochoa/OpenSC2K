extends SceneTree
## Zooming out must fill missing regions while simulation updates continue.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2"))
	var sprites := FixtureGraphics.pack().large_sprites
	var palette := Sc2Palette.index_encoding()
	var cache := CityRegionCache.new()
	cache.gpu_enabled = true
	cache.configure(city, palette, sprites, [0], 2, CityViewMode.Mode.CITY, {}, true, true)
	var center := Vector2(cache.native_size) * 0.5
	cache.update_viewport(Rect2(center - Vector2(400, 250), Vector2(800, 500)))
	var revision := 0

	while not cache.covered():
		cache.tick()
		await _finish_workers(cache)

	# Expand the view without changing the selected artwork size. Keep publishing
	# simulation changes before each batch completes, as a fast simulation can do.
	var overview := Rect2(center - Vector2(1280, 512), Vector2(2560, 1024))
	cache.update_viewport(overview)
	assert(cache.visible.size() >= 32 and not cache.covered())
	var changes: Array[Rect2i] = [Rect2i(overview)]
	var waves := cache.visible.size() + 2

	for wave in waves:
		revision += 1
		cache.configure(city, palette, sprites, [revision], 2, CityViewMode.Mode.CITY, {}, true, true,
			Rect2i(), true, changes, true)
		cache.tick()

		if cache.covered():
			break

		await _finish_workers(cache)

	assert(cache.covered(), "Simulation refreshes starved newly visible regions after zooming out")
	assert(cache.texture().meshes.size() == cache.visible.size(), "Every visible region must be published")
	cache.close()
	print("PASS: zoomed-out regions fill during continuous localized simulation refreshes")
	quit()


func _finish_workers(cache: CityRegionCache) -> void:
	var deadline := Time.get_ticks_msec() + 10000

	for worker in cache._gpu_workers:
		while worker.task != null and worker.task.is_running():
			assert(Time.get_ticks_msec() < deadline, "Region worker did not finish")
			await process_frame
