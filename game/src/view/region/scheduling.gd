class_name CityRegionScheduling
extends RefCounted
# schedule visible and prefetched regions and manage gpu worker results
# state remains owned by the cache; helpers do not retain a cache reference

@warning_ignore_start("integer_division")


static func update_viewport(cache: CityRegionCache, source_rect: Rect2) -> void:
	var rect := Rect2i(
		Vector2i((source_rect.position / cache.divisor).floor()),
		Vector2i((source_rect.size / cache.divisor).ceil()) + Vector2i.ONE,
	)
	rect = rect.intersection(Rect2i(Vector2i.ZERO, cache.native_size))

	if cache._viewport_valid and rect == cache.viewport_rect:
		return

	var movement := Vector2(rect.get_center() - cache.viewport_rect.get_center()) if cache._viewport_valid else Vector2.ZERO
	cache.viewport_rect = rect
	cache._viewport_valid = true
	cache._gpu_has_work = true
	cache._viewport_serial += 1
	var old_visible := cache.visible.duplicate()
	var old_keys := cache.visible_keys
	cache.visible.clear()
	cache.wanted.clear()
	cache.visible_keys = {}
	cache.wanted_keys = {}

	if not rect.has_area():
		cache._changed = cache._changed or not cache.entries.is_empty()
		if not cache.resident:
			cache.entries.clear()

		return

	var plan := NativeRegionPlan.plan(rect, cache.native_size, cache.region_edge, cache.gpu_enabled, movement)
	cache.visible.assign(plan.visible)
	var nearby: Array[Vector2i] = []
	nearby.assign(plan.nearby)

	if old_visible != cache.visible:
		cache._changed = true

		for key in cache.visible:
			if not old_keys.has(key):
				cache._visibility_changes.append(Rect2i(key * cache.region_edge * cache.divisor,
					Vector2i.ONE * cache.region_edge * cache.divisor))

	for key in cache.visible:
		cache.visible_keys[key] = true

	for key in cache._edit_priority.keys():
		if not cache.visible_keys.has(key):
			cache._edit_priority.erase(key)

	cache.wanted.append_array(cache.visible)
	cache.wanted.append_array(nearby.slice(0, CityRegionCache.GPU_PREFETCH_LIMIT if cache.gpu_enabled else CityRegionCache.OFFSCREEN_LIMIT))
	_index_wanted(cache)
	if cache.resident:
		# Retained offscreen regions also receive edits, before the camera returns.
		for key in cache.entries:
			if not cache.wanted_keys.has(key):
				cache.wanted.append(key)
				cache.wanted_keys[key] = true

	if cache.gpu_enabled:
		for key in cache.visible:
			if cache.entries.has(key):
				cache.entries[key].last_visible = cache._viewport_serial

		cache._trim_retained_regions()
	elif not cache.resident:
		for key in cache.entries.keys():
			if not cache.wanted_keys.has(key):
				cache.entries.erase(key)
				cache._changed = true


static func _index_wanted(cache: CityRegionCache) -> void:
	cache.wanted_keys = {}

	for key in cache.wanted:
		cache.wanted_keys[key] = true


static func _trim_retained_regions(cache: CityRegionCache) -> void:
	if cache.resident:
		return
	var excess := cache.entries.size() - cache.visible.size() - cache.offscreen_limit()

	if excess <= 0:
		return

	var ranked: Array[Vector3i] = []
	for key: Vector2i in cache.entries:
		if not cache.wanted_keys.has(key):
			ranked.append(Vector3i(cache.entries[key].last_visible, key.x, key.y))
	ranked.sort()

	for index in mini(excess, ranked.size()):
		cache.entries.erase(Vector2i(ranked[index].y, ranked[index].z))


static func _gpu_pending(cache: CityRegionCache) -> bool:
	for worker in cache.gpu_workers:
		if worker.task != null:
			return true

	return false


# true when an idle worker can start, or a current stream has used half its queue
static func _gpu_needs_keys(cache: CityRegionCache) -> bool:
	for worker in cache.gpu_workers:
		if worker.task == null or (_streams_current(cache, worker) and worker.queued() <= CityGpuRegionBatch.STREAM_QUEUE / 2):
			return true

	return false


static func _streams_current(cache: CityRegionCache, worker: CityRegionCache.RegionWorker) -> bool:
	return worker.layout == cache._layout_generation and worker.generation == cache.generation


static func _close_gpu_workers(cache: CityRegionCache) -> void:
	for worker in cache.gpu_workers:
		if worker.task != null:
			worker.cancel()
			worker.task.finish()

	cache.gpu_workers.clear()


static func _disable_gpu(cache: CityRegionCache, error: String) -> void:
	push_warning("GPU city renderer unavailable; using CPU: " + error)
	cache._close_gpu_workers()
	cache.gpu_enabled = false
	cache.wanted.resize(mini(cache.wanted.size(), cache.visible.size() + CityRegionCache.OFFSCREEN_LIMIT))
	_index_wanted(cache)
	cache._viewport_valid = false
	cache._foreground_reset = true
	cache.entries.clear()
	cache._published_source = null
	cache._layout_generation += 1


static func _tick_gpu(cache: CityRegionCache) -> bool:
	if cache.gpu_workers.is_empty() and not cache._gpu_has_work:
		var changed := cache._changed
		cache._changed = false
		return changed
	if cache.gpu_workers.is_empty():
		for index in mini(1 if cache.background_preparation else CityRegionCache.GPU_WORKERS, maxi(1, OS.get_processor_count() - 2)):
			cache.gpu_workers.append(CityRegionCache.RegionWorker.new())

	for worker in cache.gpu_workers:
		if worker.task == null:
			continue

		# Read the state first. A stopped stream has already sent every region.
		var running := worker.task.is_running()
		var current := worker.layout == cache._layout_generation

		if not current:
			worker.cancel()

		var regions := worker.take_regions(4 if cache.background_preparation and current else 0)

		if current:
			if not regions.is_empty() and worker.generation == cache.generation and not cache._prepared:
				worker.mutex.lock()
				cache._snapshot = worker.display_city
				worker.mutex.unlock()
				cache.display_city = cache._snapshot
				cache._prepared = true

			# Upload one atlas copy per texture. A later copy holds every sprite
			# of an earlier copy of the same size.
			var pending: Image = null

			for region in regions:
				if region.atlas_image != null:
					if worker.atlas == null or worker.atlas.get_size() != Vector2(region.atlas_image.get_size()):
						if pending != null:
							worker.atlas.update(pending)
							pending = null

						# Keep the old atlas texture with meshes whose UVs still use its size.
						worker.atlas = ImageTexture.create_from_image(region.atlas_image)
					else:
						pending = region.atlas_image

					worker.atlas_revision = int(region.atlas_revision)

				if region.emission_image != null:
					if worker.emission == null or worker.emission.get_size() != Vector2(region.emission_image.get_size()):
						worker.emission = ImageTexture.create_from_image(region.emission_image)
					else:
						worker.emission.update(region.emission_image)
				elif region.atlas_image != null:
					worker.emission = null
				if region.season_image != null:
					if worker.seasons == null or worker.seasons.get_size() != Vector2(region.season_image.get_size()):
						worker.seasons = ImageTexture.create_from_image(region.season_image)
					else:
						worker.seasons.update(region.season_image)
				elif region.atlas_image != null:
					worker.seasons = null
				_publish_region(cache, worker, region)

			if pending != null:
				worker.atlas.update(pending)
		else:
			cache.discarded_regions += regions.size()

		if not regions.is_empty():
			cache._gpu_has_work = true

		if running or worker.has_regions():
			continue

		var result: CityGpuRegionBatch.Result = worker.task.finish()
		worker.task = null
		worker.keys.clear()
		cache._gpu_has_work = true

		if not current:
			continue

		if not result.ok:
			_disable_gpu(cache, str(result.error))
			cache._changed = false

			return true

		if worker.generation == cache.generation and not cache._prepared:
			cache._snapshot = result.display_city
			cache.display_city = cache._snapshot
			cache._prepared = true

	cache._trim_retained_regions()
	var changed := cache._changed
	cache._changed = false

	if not cache._gpu_has_work or not _gpu_needs_keys(cache):
		return changed

	var active := {}
	var keep := func(key: Vector2i) -> bool: return cache.wanted_keys.has(key)

	for worker in cache.gpu_workers:
		if worker.task != null and worker.layout == cache._layout_generation:
			# a pan can leave queued keys outside the wanted regions
			for key in worker.prune(keep):
				worker.keys.erase(key)

			for key in worker.keys:
				active[key] = true

	var queue: Array[Vector2i] = []
	# fill holes first, then refresh the oldest visible versions. continuous
	# simulation updates must not repeatedly rebuild only the center regions
	var ranked: Array[Vector3i] = []

	for index in cache.visible.size():
		var key := cache.visible[index]
		if active.has(key) or (cache.entries.has(key) and cache.entries[key].generation == cache.generation):
			continue
		ranked.append(Vector3i((cache.entries[key].generation if cache.entries.has(key) else -1), index, (key.x << 16) | key.y))

	ranked.sort()

	for rank in ranked:
		queue.append(Vector2i(rank.z >> 16, rank.z & 0xffff))

	cache.gpu_schedule_serial += 1

	# reserve some work for missing look-ahead regions even when simulation
	# changes keep the visible regions continuously out of date
	if cache.covered() and cache.gpu_schedule_serial % 3 == 0:
		var missing_prefetch: Array[Vector2i] = []

		for key in cache.wanted.slice(cache.visible.size()):
			if not cache.entries.has(key):
				missing_prefetch.append(key)

		queue = missing_prefetch + queue

	queue.append_array(cache.wanted.slice(cache.visible.size()))
	var urgent: Array[Vector2i] = []
	for key: Vector2i in cache._edit_priority:
		if cache.visible_keys.has(key):
			urgent.append(key)
	queue = urgent + queue
	cache._gpu_has_work = false

	for worker_index in cache.gpu_workers.size():
		var worker := cache.gpu_workers[worker_index]

		if worker.task != null:
			# Top up a current stream. A stale stream finishes its queue, and
			# the worker then starts again with the new snapshot.
			var room := (8 - worker.keys.size() if cache.background_preparation
				else CityGpuRegionBatch.STREAM_QUEUE - worker.queued())

			if not _streams_current(cache, worker) or room <= 0:
				continue

			var more := _claim_gpu_keys(cache, queue, active, worker_index, room)

			if more.is_empty():
				continue

			cache._gpu_has_work = true

			if worker.offer(more, cache._edit_priority.has(more[0])):
				worker.keys.append_array(more)
			else:
				for key in more:
					active.erase(key)

			continue

		var keys := _claim_gpu_keys(cache, queue, active, worker_index, 8 if cache.background_preparation else CityGpuRegionBatch.STREAM_QUEUE)

		if keys.is_empty():
			continue

		cache._gpu_has_work = true

		if worker.layout != cache._layout_generation:
			worker.context = CityGpuBuildContext.new()
			worker.atlas = null
			worker.atlas_revision = -1

		worker.layout = cache._layout_generation
		worker.generation = cache.generation
		worker.keys = keys.duplicate()
		worker.inbox = keys
		worker.outbox = []
		worker.streaming = true
		worker.cancelled = false
		worker.display_city = null
		worker.task = CityRenderTask.new()
		var request := CityGpuRegionBatch.Request.new()
		request.city = cache._snapshot
		request.prepared = cache._prepared
		request.visibility = cache._visibility
		request.palette = cache._palette
		request.sprites = cache._sprites
		request.edge = cache.region_edge
		request.view = cache.view_size
		request.mode = cache.mode
		request.water_mains = cache._show_water_mains
		request.pipes = cache._show_pipes
		request.subways = cache._show_subways
		request.tunnels = cache._show_tunnels
		request.generation = cache.generation
		var error: Error = worker.task.start(CityGpuRegionBatch.stream.bind(request, worker, worker.atlas_revision))

		if error != OK:
			worker.task = null
			_disable_gpu(cache, error_string(error))

			return true

	return changed


# Accept one streamed region after its atlas copy is in `worker.atlas`. The
# caller keeps a copy even when the region is no longer wanted: the stream
# sends later sprites against that upload.
static func _publish_region(cache: CityRegionCache, worker: CityRegionCache.RegionWorker, region: CityGpuRegionResult) -> void:
	var key: Vector2i = region.key
	worker.keys.erase(key)

	if not cache.wanted_keys.has(key) or (cache.entries.has(key) and int(cache.entries[key].generation) > worker.generation):
		cache.discarded_regions += 1

		return

	var mesh := ArrayMesh.new()

	if not region.gpu_arrays[Mesh.ARRAY_VERTEX].is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, region.gpu_arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)

	region.mesh = mesh
	region.atlas_texture = worker.atlas
	region.emission_texture = worker.emission
	region.season_texture = worker.seasons
	region.season_image = null
	region.emission_image = null
	region.generation = worker.generation
	region.last_visible = (cache._viewport_serial if cache.visible_keys.has(key)
		else (cache.entries[key].last_visible if cache.entries.has(key) else 0))
	region.gpu_arrays = []
	region.atlas_image = null
	# Keep prepared water images in CPU memory. Only the visible water layer
	# uploads them; whole-city banks must not fill VRAM with hidden textures.
	cache.publish_changes(cache.entries.get(key), region)
	cache.entries[key] = region

	if cache._edit_priority.has(key) and worker.generation >= int(cache._edit_priority[key]):
		cache._edit_priority.erase(key)

	cache.completed_regions += 1
	cache.tile_builds += region.tile_builds
	cache.tile_reuses += region.tile_reuses
	cache.max_region_usec = maxi(cache.max_region_usec, int(region.usec))
	cache._changed = cache._changed or cache.visible_keys.has(key)


static func _claim_gpu_keys(cache: CityRegionCache, queue: Array[Vector2i], active: Dictionary,
		worker_index: int, limit: int) -> Array[Vector2i]:
	var visible: Array[Vector2i] = []
	var shared: Array[Vector2i] = []
	var background: Array[Vector2i] = []
	var seen := {}

	for key in queue:
		# the lists after these keys cannot contribute
		if visible.size() + shared.size() >= limit:
			break

		if seen.has(key) or active.has(key) or (cache.entries.has(key) and cache.entries[key].generation == cache.generation):
			continue

		seen[key] = true

		var missing := not cache.entries.has(key) and cache.visible_keys.has(key)
		var urgent := cache._edit_priority.has(key)
		# Prefer neighboring regions on the same worker to reuse tile geometry.
		# An uncovered edge can use both workers before either does background work.
		if not urgent and cache.visible.size() >= 32 and int(key.x / 8) % cache.gpu_workers.size() != worker_index:
			if missing:
				shared.append(key)
		elif missing or urgent:
			visible.append(key)
		else:
			background.append(key)

	var keys: Array[Vector2i] = []
	for key in visible + shared + background:
		if active.has(key):
			continue
		keys.append(key)
		active[key] = true
		if keys.size() >= limit:
			break

	return keys


static func _gpu_atlas_bytes(cache: CityRegionCache) -> int:
	var bytes := 0
	var seen := {}
	for entry: CityRegionResult in cache.entries.values():
		var gpu := entry as CityGpuRegionResult
		var texture: Texture2D = gpu.atlas_texture if gpu != null else null

		if texture != null and not seen.has(texture.get_instance_id()):
			seen[texture.get_instance_id()] = true
			bytes += texture.get_width() * texture.get_height() * 2

	for worker in cache.gpu_workers:
		if worker.atlas != null and not seen.has(worker.atlas.get_instance_id()):
			seen[worker.atlas.get_instance_id()] = true
			bytes += worker.atlas.get_width() * worker.atlas.get_height() * 2

	return bytes
