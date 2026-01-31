extends SceneTree

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
	print("PASS: bounded wide-view prefetch, reduced holes, retained return coverage and stale revision detection")
	quit()

func _fill(cache: CityRegionCache) -> void:
	for key in cache.wanted:
		if not cache.entries.has(key):
			cache.entries[key] = {"generation": cache.generation, "last_visible": cache._viewport_serial if key in cache.visible else 0}
	cache._trim_retained_regions()
	assert(cache.entries.size() <= cache.visible.size() + cache.offscreen_limit())
	assert(cache.prefetch_ready())
