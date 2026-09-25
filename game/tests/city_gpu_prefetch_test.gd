extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	var cache := CityRegionCache.new()
	cache.gpu_enabled = true
	cache.region_edge = 256
	cache.native_size = Vector2i(33000, 17000)
	var bounds := Rect2(Vector2(12000, 6000), Vector2(1909, 733) / 0.25)
	cache.update_viewport(bounds)
	var first := cache.visible.duplicate()
	assert(cache.wanted.size() <= cache.visible.size() + cache.GPU_PREFETCH_LIMIT)
	_fill(cache)
	cache.update_viewport(Rect2(bounds.position + Vector2(1024, 0), bounds.size))
	var missing := 0

	for key in cache.visible:
		if not cache.entries.has(key):
			missing += 1

	assert(missing < 48, "Too many missing regions after quarter-zoom pan")
	_fill(cache)
	cache.update_viewport(Rect2(bounds.position + Vector2(2048, 0), bounds.size))
	_fill(cache)
	cache.update_viewport(bounds)

	for key in first:
		assert(cache.entries.has(key), "Prefetch evicted a recently viewed region")

	assert(cache.covered())
	cache.update_viewport(Rect2(bounds.position - Vector2(0, 512), bounds.size))
	var first_key := Vector2i(cache._viewport_rect.position / cache.region_edge)
	var last_key := Vector2i((cache._viewport_rect.end - Vector2i.ONE) / cache.region_edge)
	assert(Vector2i((first_key.x + last_key.x) / 2, first_key.y - 4) in cache.wanted, "No prefetched regions ahead of vertical camera motion")
	_fill(cache)
	# Retained old revisions provide coverage but still need an update.
	cache.generation += 1
	assert(cache.covered() and not cache.ready() and not cache.prefetch_ready())
	cache.close()
	_check_worker_sharing()
	print("PASS: bounded wide-view prefetch, reduced holes, retained return coverage and stale revision detection")
	quit()


func _check_worker_sharing() -> void:
	var cache := CityRegionCache.new()
	cache.generation = 1
	cache._gpu_workers = [CityRegionCache.RegionWorker.new(), CityRegionCache.RegionWorker.new()]
	for x in 32:
		var key := Vector2i(x, 1)
		cache.visible.append(key)
		if x not in [8, 9]:
			var entry := CityGpuRegionResult.new()
			entry.generation = cache.generation
			cache.entries[key] = entry
	var queue: Array[Vector2i] = [Vector2i(8, 1), Vector2i(9, 1), Vector2i(0, 2)]
	var active := {}
	var first := CityRegionScheduling._claim_gpu_keys(cache, queue, active, 0, 1)
	assert(first == [Vector2i(8, 1)], "A worker must fill visible gaps before its own offscreen regions")
	var second := CityRegionScheduling._claim_gpu_keys(cache, queue, active, 1, 1)
	assert(second == [Vector2i(9, 1)], "Workers must share gaps without requesting the same region")
	assert(CityRegionScheduling._claim_gpu_keys(cache, queue, active, 0, 4) == [Vector2i(0, 2)])
	cache.close()


func _fill(cache: CityRegionCache) -> void:
	for key in cache.wanted:
		if not cache.entries.has(key):
			var entry := CityGpuRegionResult.new()
			entry.generation = cache.generation
			entry.last_visible = cache._viewport_serial if key in cache.visible else 0
			cache.entries[key] = entry

	cache._trim_retained_regions()
	assert(cache.entries.size() <= cache.visible.size() + cache.offscreen_limit())
	assert(cache.prefetch_ready())
