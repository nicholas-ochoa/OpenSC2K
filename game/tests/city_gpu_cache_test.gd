extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-512.sc2x"))
	var sprites := FixtureGraphics.pack().large_sprites
	var palette := Sc2Palette.index_encoding()
	var cache := CityRegionCache.new()
	cache.gpu_enabled = true
	cache.configure(city, palette, sprites, [1], 2, CityViewMode.Mode.CITY, {}, true, true)
	var bounds := Rect2i((cache.native_size / 2) - Vector2i(400, 250), Vector2i(800, 500))
	cache.update_viewport(Rect2(bounds))
	await _drain(cache)
	assert(cache.gpu_enabled and cache.ready())
	assert(cache.texture().meshes.size() == cache.visible.size())
	var first_source := cache.texture()
	var repeated_source := cache.texture()
	assert(first_source == repeated_source, "Unchanged publication must return the same source snapshot")

	for index in first_source.meshes.size():
		assert(first_source.meshes[index] == repeated_source.meshes[index] and first_source.meshes[index].immutable,
			"Publishing unchanged regions must retain their immutable mesh descriptors")
	# Replacing one region must not mutate a retained snapshot or scan all entries.
	var changed_key := cache.visible[0]
	var prior_region: CityGpuRegionResult = cache.entries[changed_key]
	var replacement := CityGpuRegionResult.new()
	replacement.bounds = prior_region.bounds
	replacement.mesh = ArrayMesh.new()
	replacement.atlas_texture = prior_region.atlas_texture
	cache.publish_changes(prior_region, replacement)
	cache.entries[changed_key] = replacement
	var updated := cache.texture()
	assert(updated != first_source and updated.mesh_updates_from == first_source.get_instance_id())
	assert(updated.mesh_updates.size() == 1)
	var changed_index := updated.mesh_updates[0]
	assert(first_source.meshes[changed_index].mesh == prior_region.mesh)
	assert(updated.meshes[changed_index].mesh == replacement.mesh)
	cache.publish_changes(replacement, prior_region)
	cache.entries[changed_key] = prior_region
	cache.texture()
	var previous_source: WeakRef = weakref(first_source)
	first_source = null
	repeated_source = null
	assert(previous_source.get_ref() == null, "Incremental snapshots must not retain their predecessors")
	var expected := CityRegionRenderer.render(city, palette, sprites, bounds, 2)
	assert(expected.ok)
	var sampled := cache.image_region(bounds)
	assert(sampled.get_data() == expected.image.get_data(), "GPU sample differs from CPU at a region border")

	for x in range(bounds.position.x, bounds.end.x, 29):
		for y in range(bounds.position.y, bounds.end.y, 31):
			assert(cache.pixel(Vector2i(x, y)) == sampled.get_pixel(x - bounds.position.x, y - bounds.position.y))

	for offset in [Vector2i(1700, 900), Vector2i(-900, 1200), Vector2i.ZERO]:
		cache.update_viewport(Rect2(bounds.position + offset, bounds.size))
		await _drain(cache)
		assert(cache.entries.size() <= cache.visible.size() + cache.offscreen_limit())

		for worker in cache._gpu_workers:
			assert(worker.context.tiles.size() <= CityGpuBuildContext.TILE_CACHE_LIMIT)

	# Player edits take the next available worker ahead of stale background work.
	var edited: Vector2i = cache.visible[-1]
	for entry: CityRegionResult in cache.entries.values():
		entry.generation = 0
	cache.configure(city, palette, sprites, [2], 2, CityViewMode.Mode.CITY, {}, true, true,
		Rect2i(edited * cache.region_edge, Vector2i.ONE * cache.region_edge))
	cache.tick()
	assert(cache._gpu_workers[0].keys[0] == edited, "Background region ran before the player edit")
	await _drain(cache)
	assert(cache._edit_priority.is_empty(), "Completed edit still has render priority")
	# Keep updating while waiting for previously missing regions.
	cache.entries.clear()
	var revision := 2
	var deadline := Time.get_ticks_msec() + 15000

	while not cache.covered() and Time.get_ticks_msec() < deadline:
		revision += 1
		cache.configure(city, palette, sprites, [revision], 2, CityViewMode.Mode.CITY, {}, true, true)
		cache.tick()
		await process_frame

	assert(cache.covered())
	var oldest := revision
	deadline = Time.get_ticks_msec() + 20000
	var refreshed := false

	while not refreshed and Time.get_ticks_msec() < deadline:
		revision += 1
		cache.configure(city, palette, sprites, [revision], 2, CityViewMode.Mode.CITY, {}, true, true)
		cache.tick()
		refreshed = true

		for key in cache.wanted:
			if not cache.entries.has(key) or (key in cache.visible and int(cache.entries[key].generation) <= oldest):
				refreshed = false

		await process_frame

	assert(refreshed, "Visible or prefetched region never finished during continuous updates")
	await _drain(cache)
	# Replace the layout while old surface jobs are still running.
	cache.configure(city, palette, sprites, [revision + 1], 2, CityViewMode.Mode.CITY, {}, true, true)
	cache.tick()
	cache.configure(city, palette, sprites, [revision + 2], 2, CityViewMode.Mode.UNDERGROUND, {}, true, true)
	cache.update_viewport(Rect2(bounds))
	await _drain(cache)
	var underground := CityRegionRenderer.render(city, palette, sprites, bounds, 2, CityViewMode.Mode.UNDERGROUND)
	assert(underground.ok)
	underground.image.convert(Image.FORMAT_LA8)
	assert(cache.image_region(bounds).get_data() == underground.image.get_data(), "Surface job overwrote an underground region")
	revision += 2

	# Artwork changes also change region size. Old jobs must not publish keys
	# from the previous grid, and local samples must still cross exact borders.
	var small := FixtureGraphics.pack().small_medium_sprites
	cache.configure(city, palette, sprites, [revision + 1], 2, CityViewMode.Mode.UNDERGROUND, {}, true, true)
	cache.tick()
	cache.configure(city, palette, small, [revision + 2], 0, CityViewMode.Mode.CITY, {}, true, true)
	assert(cache.region_edge == CityRegionCache.GPU_SMALL_REGION_EDGE)
	var native_bounds := Rect2i(cache.native_size / 2 - Vector2i(60, 40), Vector2i(120, 80))
	cache.update_viewport(Rect2(native_bounds.position * 4, native_bounds.size * 4))
	await _drain(cache)
	var overview := CityRegionRenderer.render(city, palette, small, native_bounds, 0)
	assert(overview.ok)
	overview.image.resize(native_bounds.size.x * 4, native_bounds.size.y * 4, Image.INTERPOLATE_NEAREST)
	assert(cache.image_region(Rect2i(native_bounds.position * 4, native_bounds.size * 4)).get_data() == overview.image.get_data())
	cache.configure(city, palette, sprites, [revision + 3], 2, CityViewMode.Mode.UNDERGROUND, {}, true, true)
	assert(cache.region_edge == CityRegionCache.GPU_REGION_EDGE)
	cache.update_viewport(Rect2(bounds))
	await _drain(cache)
	assert(cache.image_region(bounds).get_data() == underground.image.get_data())
	revision += 3

	# Force GPU preparation to fail and check the CPU fallback.
	for worker in cache._gpu_workers:
		worker.context.error = "Test atlas failure"

	cache.configure(city, palette, sprites, [revision + 1], 2, CityViewMode.Mode.UNDERGROUND, {}, true, true)
	await _drain(cache)
	assert(not cache.gpu_enabled and cache.ready())
	cache.close()
	print("PASS: GPU mesh publication, exact local sampling, bounded pans, continuous updates, layout replacement and CPU fallback")
	quit()


func _drain(cache: CityRegionCache) -> void:
	var deadline := Time.get_ticks_msec() + 30000

	while Time.get_ticks_msec() < deadline:
		cache.tick()
		assert(cache.last_error.is_empty(), cache.last_error)

		if cache.ready() and cache.prefetch_ready() and not cache.metrics().pending:
			return

		await process_frame

	assert(false, "GPU cache did not finish")
