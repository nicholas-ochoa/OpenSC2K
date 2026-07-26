class_name CityRegionScheduling
extends RefCounted
# schedule visible and prefetched regions and manage gpu worker results
# state remains owned by the cache; helpers do not retain a cache reference

@warning_ignore_start("integer_division")



static func update_viewport(cache: CityRegionCache, source_rect: Rect2) -> void:
	var rect := Rect2i(Vector2i((source_rect.position / cache.divisor).floor()), Vector2i((source_rect.size / cache.divisor).ceil()) + Vector2i.ONE)
	rect = rect.intersection(Rect2i(Vector2i.ZERO, cache.native_size))

	if cache._viewport_valid and rect == cache._viewport_rect:
		return

	var movement := Vector2(rect.get_center() - cache._viewport_rect.get_center()) if cache._viewport_valid else Vector2.ZERO
	cache._viewport_rect = rect
	cache._viewport_valid = true
	cache._gpu_has_work = true
	cache._viewport_serial += 1
	var old_visible := cache.visible.duplicate()
	cache.visible.clear()
	cache.wanted.clear()

	if not rect.has_area():
		cache._changed = cache._changed or not cache.entries.is_empty()
		cache.entries.clear()

		return

	var first := Vector2i(rect.position / cache.region_edge)
	var last := Vector2i((rect.end - Vector2i.ONE) / cache.region_edge)
	var margin := clampi(ceili(minf(rect.size.x, rect.size.y) / (3.0 * cache.region_edge)), 1, 4) if cache.gpu_enabled else 1
	var side_margin := margin
	var top_margin := maxi(1, ceili(margin / 2.0)) if cache.gpu_enabled else 1
	var bottom_margin := top_margin

	if cache.gpu_enabled and absf(movement.y) > absf(movement.x):
		side_margin = top_margin

		if movement.y < 0:
			top_margin = margin
		else:
			bottom_margin = margin

	var nearby: Array[Vector2i] = []

	for y in range(maxi(0, first.y - top_margin), mini(ceili(float(cache.native_size.y) / cache.region_edge), last.y + bottom_margin + 1)):
		for x in range(maxi(0, first.x - side_margin), mini(ceili(float(cache.native_size.x) / cache.region_edge), last.x + side_margin + 1)):
			var key := Vector2i(x, y)

			if x >= first.x and x <= last.x and y >= first.y and y <= last.y:
				cache.visible.append(key)
			else:
				nearby.append(key)

	var center := Vector2(rect.get_center()) / cache.region_edge - Vector2(0.5, 0.5)
	cache._sort_regions(cache.visible, center, first, last, false)
	var ahead := center + movement.limit_length(cache.region_edge * margin) / cache.region_edge if cache.gpu_enabled else center
	cache._sort_regions(nearby, ahead, first, last, cache.gpu_enabled)

	if old_visible != cache.visible:
		cache._changed = true

		for key in cache.visible:
			if key not in old_visible:
				cache._visibility_changes.append(Rect2i(key * cache.region_edge * cache.divisor, Vector2i.ONE * cache.region_edge * cache.divisor))

	for key in cache._edit_priority.keys():
		if key not in cache.visible:
			cache._edit_priority.erase(key)

	cache.wanted.append_array(cache.visible)
	cache.wanted.append_array(nearby.slice(0, CityRegionCache.GPU_PREFETCH_LIMIT if cache.gpu_enabled else CityRegionCache.OFFSCREEN_LIMIT))

	if cache.gpu_enabled:
		for key in cache.visible:
			if cache.entries.has(key):
				cache.entries[key].last_visible = cache._viewport_serial

		cache._trim_retained_regions()
	else:
		for key in cache.entries.keys():
			if key not in cache.wanted:
				cache.entries.erase(key)
				cache._changed = true


static func _sort_regions(keys: Array[Vector2i], center: Vector2, first: Vector2i, last: Vector2i, rings: bool) -> void:
	# sort native integer tuples instead of calling gdscript for every comparison
	var ranked: Array[Vector3i] = []

	for key in keys:
		var ring := maxi(maxi(first.x - key.x, key.x - last.x), maxi(first.y - key.y, key.y - last.y)) if rings else 0
		ranked.append(Vector3i(ring, roundi(Vector2(key).distance_squared_to(center) * 1024), (key.x << 16) | key.y))

	ranked.sort()
	keys.clear()

	for rank in ranked:
		keys.append(Vector2i(rank.z >> 16, rank.z & 0xffff))


static func _trim_retained_regions(cache: CityRegionCache) -> void:
	var excess := cache.entries.size() - cache.visible.size() - cache.offscreen_limit()

	if excess <= 0:
		return

	var ranked: Array[Vector3i] = []
	for key: Vector2i in cache.entries:
		if key not in cache.wanted:
			ranked.append(Vector3i(int(cache.entries[key].get("last_visible", 0)), key.x, key.y))
	ranked.sort()

	for index in mini(excess, ranked.size()):
		cache.entries.erase(Vector2i(ranked[index].y, ranked[index].z))


static func _gpu_pending(cache: CityRegionCache) -> bool:
	for worker in cache._gpu_workers:
		if worker.thread != null:
			return true

	return false


static func _close_gpu_workers(cache: CityRegionCache) -> void:
	for worker in cache._gpu_workers:
		if worker.thread != null:
			worker.thread.wait_to_finish()

	cache._gpu_workers.clear()


static func _tick_gpu(cache: CityRegionCache) -> bool:
	if cache._gpu_workers.is_empty():
		for index in mini(CityRegionCache.GPU_WORKERS, maxi(1, OS.get_processor_count() - 2)):
			cache._gpu_workers.append({"thread": null, "context": null, "atlas": null, "atlas_revision": -1, "layout": -1, "generation": -1, "keys": []})

	for worker in cache._gpu_workers:
		if worker.thread == null or worker.thread.is_alive():
			continue

		var result: Dictionary = worker.thread.wait_to_finish()
		worker.thread = null
		cache._gpu_has_work = true

		if int(worker.layout) != cache._layout_generation:
			cache.discarded_regions += worker.keys.size()
			continue

		if not result.ok:
			push_warning("GPU city renderer unavailable; using CPU: " + str(result.error))
			cache._close_gpu_workers()
			cache.gpu_enabled = false
			cache.wanted.resize(mini(cache.wanted.size(), cache.visible.size() + CityRegionCache.OFFSCREEN_LIMIT))
			cache._viewport_valid = false
			cache._foreground_reset = true
			cache.entries.clear()
			cache._layout_generation += 1
			cache._changed = false

			return true

		if int(worker.generation) == cache.generation and not cache._prepared:
			cache._snapshot = result.display_city
			cache.display_city = cache._snapshot
			cache._prepared = true

		if result.atlas_image != null:
			if worker.atlas == null or worker.atlas.get_size() != Vector2(result.atlas_image.get_size()):
				# Keep the old atlas texture with meshes whose UVs still use its size.
				worker.atlas = ImageTexture.create_from_image(result.atlas_image)
			else:
				worker.atlas.update(result.atlas_image)

			worker.atlas_revision = int(result.atlas_revision)
		for region: Dictionary in result.regions:
			var key: Vector2i = region.key

			if key not in cache.wanted or (cache.entries.has(key) and int(cache.entries[key].generation) > int(worker.generation)):
				cache.discarded_regions += 1
				continue

			var mesh := ArrayMesh.new()

			if not region.gpu_arrays[Mesh.ARRAY_VERTEX].is_empty():
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, region.gpu_arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)

			region.mesh = mesh
			region.depth_mesh = _depth_mesh(region.get("depth_arrays", []))
			region.train_depth_mesh = _depth_mesh(region.get("train_depth_arrays", []))
			region.erase("depth_arrays")
			region.erase("train_depth_arrays")
			region.atlas_texture = worker.atlas
			region.generation = int(worker.generation)
			region.last_visible = cache._viewport_serial if key in cache.visible else int(cache.entries.get(key, {}).get("last_visible", 0))
			region.erase("gpu_arrays")
			region.erase("atlas_image")
			cache.entries[key] = region

			if cache._edit_priority.has(key) and int(worker.generation) >= int(cache._edit_priority[key]):
				cache._edit_priority.erase(key)

			cache.foreground_changes.append(Rect2i(region.bounds.position * cache.divisor, region.bounds.size * cache.divisor))
			cache.completed_regions += 1
			cache.max_region_usec = maxi(cache.max_region_usec, int(region.usec))
			cache._changed = cache._changed or key in cache.visible

	cache._trim_retained_regions()
	var changed := cache._changed
	cache._changed = false

	if not cache._gpu_has_work or cache._gpu_workers.all(func(worker: Dictionary) -> bool:
		return worker.thread != null):
		return changed

	var active := {}

	for worker in cache._gpu_workers:
		if worker.thread != null and int(worker.layout) == cache._layout_generation:
			for key in worker.keys:
				active[key] = true

	var queue: Array[Vector2i] = []
	queue.assign(cache.visible)
	# fill holes first, then refresh the oldest visible versions. continuous
	# simulation updates must not repeatedly rebuild only the center regions
	var ranked: Array[Vector3i] = []

	for index in queue.size():
		var key := queue[index]
		ranked.append(Vector3i(int(cache.entries.get(key, {}).get("generation", -1)), index, (key.x << 16) | key.y))

	ranked.sort()
	queue.clear()

	for rank in ranked:
		queue.append(Vector2i(rank.z >> 16, rank.z & 0xffff))

	cache._gpu_schedule_serial += 1

	# reserve some work for missing look-ahead regions even when simulation
	# changes keep the visible regions continuously out of date
	if cache.covered() and cache._gpu_schedule_serial % 3 == 0:
		var missing_prefetch: Array[Vector2i] = []

		for key in cache.wanted.slice(cache.visible.size()):
			if not cache.entries.has(key):
				missing_prefetch.append(key)

		queue = missing_prefetch + queue

	queue.append_array(cache.wanted.slice(cache.visible.size()))
	var urgent: Array[Vector2i] = []
	for key: Vector2i in cache._edit_priority:
		if key in cache.visible:
			urgent.append(key)
	queue = urgent + queue
	cache._gpu_has_work = false

	for worker in cache._gpu_workers:
		if worker.thread != null:
			continue

		var keys: Array[Vector2i] = []
		var worker_index := cache._gpu_workers.find(worker)
		# keep the first result quick. warm workers then run bounded batches
		var limit := CityGpuRegionBatch.MAX_REGIONS if int(worker.layout) == cache._layout_generation else 1

		for key in queue:
			if active.has(key) or (cache.entries.has(key) and int(cache.entries[key].generation) == cache.generation):
				continue

			# keep neighboring wide-view regions on the same worker so their tile
			# geometry and bounds are prepared once. small views use either worker
			if not cache._edit_priority.has(key) and cache.visible.size() >= 32 and int(key.x / 8) % cache._gpu_workers.size() != worker_index:
				continue

			keys.append(key)
			active[key] = true

			if keys.size() >= limit:
				break

		if keys.is_empty():
			continue

		cache._gpu_has_work = true

		if int(worker.layout) != cache._layout_generation:
			worker.context = CityGpuBuildContext.new()
			worker.atlas = null
			worker.atlas_revision = -1

		worker.layout = cache._layout_generation
		worker.generation = cache.generation
		worker.keys = keys
		worker.thread = Thread.new()
		var request := {"city": cache._snapshot, "prepared": cache._prepared, "visibility": cache._visibility,
			"palette": cache._palette, "sprites": cache._sprites, "keys": keys, "edge": cache.region_edge,
			"view": cache.view_size, "mode": cache.mode, "water_mains": cache._show_water_mains, "pipes": cache._show_pipes, "subways": cache._show_subways,
			"generation": cache.generation, "signs": cache.sign_requests}
		var error: Error = worker.thread.start(CityGpuRegionBatch.build.bind(request, worker.context, worker.atlas_revision), Thread.PRIORITY_LOW)

		if error != OK:
			worker.thread = null
			cache._close_gpu_workers()
			cache.gpu_enabled = false
			cache.wanted.resize(mini(cache.wanted.size(), cache.visible.size() + CityRegionCache.OFFSCREEN_LIMIT))
			cache._viewport_valid = false
			cache.entries.clear()
			cache._layout_generation += 1

			return true

	return changed


# return null for underground regions, which have no moving-object depth
static func _depth_mesh(arrays: Array) -> ArrayMesh:
	if arrays.is_empty():
		return null

	var mesh := ArrayMesh.new()

	if not arrays[Mesh.ARRAY_VERTEX].is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)

	return mesh


static func _gpu_atlas_bytes(cache: CityRegionCache) -> int:
	var bytes := 0
	var seen := {}
	for entry: Dictionary in cache.entries.values():
		var texture: Texture2D = entry.get("atlas_texture")

		if texture != null and not seen.has(texture.get_instance_id()):
			seen[texture.get_instance_id()] = true
			bytes += texture.get_width() * texture.get_height() * 2

	for worker in cache._gpu_workers:
		if worker.atlas != null and not seen.has(worker.atlas.get_instance_id()):
			seen[worker.atlas.get_instance_id()] = true
			bytes += worker.atlas.get_width() * worker.atlas.get_height() * 2

	return bytes
