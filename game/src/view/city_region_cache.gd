class_name CityRegionCache
extends RefCounted

const REGION_EDGE := 512
const OFFSCREEN_LIMIT := 12
const GPU_OFFSCREEN_LIMIT := 384
const GPU_PREFETCH_LIMIT := 256
const GPU_REGION_EDGE := 256
const GPU_WORKERS := 2
var region_edge := REGION_EDGE
var gpu_enabled := gpu_supported()
var _gpu_workers: Array[Dictionary] = []
var entries: Dictionary = {}
var wanted: Array[Vector2i] = []
var visible: Array[Vector2i] = []
var signature: Array = []
var view_size := 2
var mode := "city"
var divisor := 1
var native_size := Vector2i.ZERO
var display_city: CityState
var generation := 0
var completed_regions := 0
var discarded_regions := 0
var max_region_usec := 0
var last_error := ""
var _snapshot: CityState
var _palette: Sc2Palette
var _sprites: Sc2SpriteArchive
var _visibility: Dictionary
var _show_pipes := true
var _show_subways := true
var _prepared := false
var _thread: Thread
var _job_key := Vector2i.ZERO
var _job_generation := 0
var _layout_generation := 0
var _job_layout := 0
var _changed := false
var _viewport_rect := Rect2i()
var _viewport_valid := false
var foreground_changes: Array[Rect2i] = []
var sign_requests: Array[Dictionary] = []
var sign_layout_token: Array = []
var _foreground_reset := true
var _gpu_has_work := true
var _viewport_serial := 0
var _gpu_schedule_serial := 0

static func gpu_supported(preference := "gpu") -> bool:
	var requested := OS.get_environment("OPENSC2K_CITY_RENDERER").to_lower()
	return requested == "gpu" or (DisplayServer.get_name() != "headless" and requested != "cpu" and preference != "cpu")

func configure(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		new_signature: Array, new_view: int, new_mode: String, visibility: Dictionary,
		show_pipes: bool, show_subways: bool, dirty := Rect2i()) -> void:
	if _snapshot == null:
		region_edge = GPU_REGION_EDGE if gpu_enabled else REGION_EDGE
	if signature == new_signature and view_size == new_view and mode == new_mode and _snapshot != null:
		return
	var reset := _snapshot == null or _snapshot.map_size != city.map_size or view_size != new_view or mode != new_mode or _snapshot.document.source_path != city.document.source_path or _snapshot.compass_rotation() != city.compass_rotation() or _snapshot.visible_altitude_levels != city.visible_altitude_levels or _visibility != visibility or _sprites != sprites or _show_pipes != show_pipes or _show_subways != show_subways
	generation += 1
	_gpu_has_work = true
	last_error = ""
	if not reset and dirty.has_area():
		for entry: Dictionary in entries.values():
			if int(entry.generation) == generation - 1 and not entry.bounds.intersects(dirty):
				entry.generation = generation
	if reset:
		_foreground_reset = true
		_viewport_valid = false
		_layout_generation += 1
		entries.clear()
		_changed = true
	signature = new_signature.duplicate()
	view_size = new_view
	mode = new_mode
	divisor = int(CityIsometricRenderer.view_configuration(view_size).divisor)
	native_size = CityIsometricRenderer.output_size_for_view(view_size, city.map_size)
	_snapshot = CityState.new()
	_snapshot.document = city.document.duplicate_document()
	_snapshot.map_size = city.map_size
	_snapshot.visible_altitude_levels = city.visible_altitude_levels
	for field in ["altitude_words", "terrain", "buildings", "zones", "underground", "text_overlays", "tile_flags"]:
		_snapshot.set(field, city.get(field).duplicate())
	display_city = _snapshot
	_palette = palette
	_sprites = sprites
	_visibility = visibility.duplicate()
	_show_pipes = show_pipes
	_show_subways = show_subways
	_prepared = mode == "underground"

func set_sign_requests(requests: Array[Dictionary]) -> void:
	var next: Array[Dictionary] = []
	for request in requests:
		var bounds: Rect2i = request.bounds.intersection(Rect2i(Vector2i.ZERO, native_size * divisor))
		if bounds.has_area():
			next.append({"key": int(request.key), "bounds": bounds, "draw_order": int(request.draw_order)})
	sign_requests = next

func sign_foreground(key: int, bounds: Rect2i, order: int) -> Image:
	var result := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for region_key in _keys_for_bounds(bounds):
		if not entries.has(region_key):
			return null
		var entry: Dictionary = entries[region_key]
		var patch: Dictionary = entry.get("sign_foregrounds", {}).get(key, {})
		if patch.is_empty() or patch.source_bounds != bounds or int(patch.draw_order) != order:
			return null
		var image: Image = patch.image
		if divisor > 1:
			image = image.duplicate()
			image.resize(image.get_width() * divisor, image.get_height() * divisor, Image.INTERPOLATE_NEAREST)
		var world := Rect2i(patch.bounds.position * divisor, patch.bounds.size * divisor)
		var overlap := bounds.intersection(world)
		result.blit_rect(image, Rect2i(overlap.position - world.position, overlap.size), overlap.position - bounds.position)
	return result

func update_viewport(source_rect: Rect2) -> void:
	var rect := Rect2i(Vector2i((source_rect.position / divisor).floor()), Vector2i((source_rect.size / divisor).ceil()) + Vector2i.ONE)
	rect = rect.intersection(Rect2i(Vector2i.ZERO, native_size))
	if _viewport_valid and rect == _viewport_rect:
		return
	var movement := Vector2(rect.get_center() - _viewport_rect.get_center()) if _viewport_valid else Vector2.ZERO
	_viewport_rect = rect
	_viewport_valid = true
	_gpu_has_work = true
	_viewport_serial += 1
	var old_visible := visible.duplicate()
	visible.clear()
	wanted.clear()
	if not rect.has_area():
		_changed = _changed or not entries.is_empty()
		entries.clear()
		return
	var first := Vector2i(rect.position / region_edge)
	var last := Vector2i((rect.end - Vector2i.ONE) / region_edge)
	var margin := clampi(ceili(minf(rect.size.x, rect.size.y) / (3.0 * region_edge)), 1, 4) if gpu_enabled else 1
	var side_margin := margin
	var top_margin := maxi(1, ceili(margin / 2.0)) if gpu_enabled else 1
	var bottom_margin := top_margin
	if gpu_enabled and absf(movement.y) > absf(movement.x):
		side_margin = top_margin
		if movement.y < 0:
			top_margin = margin
		else:
			bottom_margin = margin
	var nearby: Array[Vector2i] = []
	for y in range(maxi(0, first.y - top_margin), mini(ceili(float(native_size.y) / region_edge), last.y + bottom_margin + 1)):
		for x in range(maxi(0, first.x - side_margin), mini(ceili(float(native_size.x) / region_edge), last.x + side_margin + 1)):
			var key := Vector2i(x, y)
			if x >= first.x and x <= last.x and y >= first.y and y <= last.y:
				visible.append(key)
			else:
				nearby.append(key)
	var center := Vector2(rect.get_center()) / region_edge - Vector2(0.5, 0.5)
	_sort_regions(visible, center, first, last, false)
	var ahead := center + movement.limit_length(region_edge * margin) / region_edge if gpu_enabled else center
	_sort_regions(nearby, ahead, first, last, gpu_enabled)
	if old_visible != visible:
		_changed = true
	wanted.append_array(visible)
	wanted.append_array(nearby.slice(0, GPU_PREFETCH_LIMIT if gpu_enabled else OFFSCREEN_LIMIT))
	if gpu_enabled:
		for key in visible:
			if entries.has(key):
				entries[key].last_visible = _viewport_serial
		_trim_retained_regions()
	else:
		for key in entries.keys():
			if key not in wanted:
				entries.erase(key)
				_changed = true

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

func _trim_retained_regions() -> void:
	var excess := entries.size() - visible.size() - offscreen_limit()
	if excess <= 0:
		return
	var ranked: Array[Vector3i] = []
	for key: Vector2i in entries:
		if key not in wanted:
			ranked.append(Vector3i(int(entries[key].get("last_visible", 0)), key.x, key.y))
	ranked.sort()
	for index in mini(excess, ranked.size()):
		entries.erase(Vector2i(ranked[index].y, ranked[index].z))

func tick() -> bool:
	foreground_changes.clear()
	if _foreground_reset:
		foreground_changes.append(Rect2i(Vector2i.ZERO, native_size * divisor))
		_foreground_reset = false
	if gpu_enabled:
		return _tick_gpu()
	if _thread != null and not _thread.is_alive():
		var result: Dictionary = _thread.wait_to_finish()
		_thread = null
		if not result.ok:
			last_error = result.error
			_changed = true
		elif _job_layout == _layout_generation and _job_key in wanted and (not entries.has(_job_key) or int(entries[_job_key].generation) <= _job_generation):
			if _job_generation == generation:
				_snapshot = result.display_city
				display_city = _snapshot
				_prepared = true
			result.erase("display_city")
			result.texture = ImageTexture.create_from_image(result.image)
			result.generation = _job_generation
			entries[_job_key] = result
			foreground_changes.append(Rect2i(result.bounds.position * divisor, result.bounds.size * divisor))
			completed_regions += 1
			max_region_usec = maxi(max_region_usec, int(result.usec))
			_changed = _changed or _job_key in visible
		else:
			discarded_regions += 1
	if _thread == null and last_error.is_empty():
		var queue: Array[Vector2i] = []
		for key in visible:
			if not entries.has(key):
				queue.append(key)
		queue.append_array(wanted)
		for key in queue:
			if entries.has(key) and int(entries[key].generation) == generation:
				continue
			_job_key = key
			_job_generation = generation
			_job_layout = _layout_generation
			_thread = Thread.new()
			var bounds := Rect2i(key * region_edge, Vector2i(region_edge, region_edge))
			var error := _thread.start(_render.bind(_snapshot, _palette, _sprites, bounds, view_size, mode, _visibility, _prepared, _show_pipes, _show_subways), Thread.PRIORITY_LOW)
			if error != OK:
				_thread = null
				last_error = error_string(error)
				_changed = true
			break
	var changed := _changed
	_changed = false
	return changed

func texture() -> Texture2D:
	var output := PlaceholderTexture2D.new()
	output.size = Vector2(native_size * divisor)
	var tiles: Array[Dictionary] = []
	var meshes: Array[Dictionary] = []
	for key in visible:
		if not entries.has(key):
			continue
		var entry: Dictionary = entries[key]
		if entry.has("mesh"):
			meshes.append({"position": Vector2(entry.bounds.position * divisor), "mesh": entry.mesh, "texture": entry.atlas_texture, "divisor": divisor})
			continue
		tiles.append({"position": Vector2(entry.bounds.position * divisor), "size": Vector2(entry.bounds.size * divisor), "texture": entry.texture})
	output.set_meta("map_tiles", tiles)
	output.set_meta("map_meshes", meshes)
	return output

func occlusion_candidates(bounds: Rect2i) -> Array[Dictionary]:
	var found := {}
	var versions := {}
	var native := Rect2(Vector2(bounds.position) / divisor, Vector2(bounds.size) / divisor)
	for key in _keys_for_bounds(bounds):
		if not entries.has(key) or key not in visible:
			continue
		var entry: Dictionary = entries[key]
		if not Rect2(entry.bounds).intersects(native):
			continue
		for index in CityIsometricRenderer.occlusion_candidate_indices(entry.occlusion_grid, bounds):
			var command: Dictionary = entry.occlusion_commands[index]
			var order: int = command.region_order
			if int(versions.get(order, -1)) > int(entry.generation):
				continue
			found[order] = command
			versions[order] = entry.generation
	var ordered := found.keys()
	ordered.sort()
	var result: Array[Dictionary] = []
	for order in ordered:
		result.append(found[order])
	return result

func _keys_for_bounds(bounds: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not bounds.has_area():
		return result
	var edge := float(region_edge * divisor)
	var first := Vector2i(floori(bounds.position.x / edge), floori(bounds.position.y / edge))
	var last := Vector2i(floori((bounds.end.x - 1) / edge), floori((bounds.end.y - 1) / edge))
	for y in range(maxi(0, first.y), mini(ceili(float(native_size.y) / region_edge) - 1, last.y) + 1):
		for x in range(maxi(0, first.x), mini(ceili(float(native_size.x) / region_edge) - 1, last.x) + 1):
			result.append(Vector2i(x, y))
	return result

func image_region(bounds: Rect2i) -> Image:
	var output := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_LA8)
	output.fill(Color.TRANSPARENT)
	for key in _keys_for_bounds(bounds):
		if not entries.has(key):
			continue
		var entry: Dictionary = entries[key]
		var world := Rect2i(entry.bounds.position * divisor, entry.bounds.size * divisor)
		var overlap := world.intersection(bounds)
		if not overlap.has_area():
			continue
		var first := Vector2i((Vector2(overlap.position) / divisor).floor())
		var last := Vector2i((Vector2(overlap.end) / divisor).ceil())
		var native := Rect2i(first, last - first)
		var image: Image = CityGpuDrawList.paint(entry.gpu_draws, native, entry.background, entry.gpu_draw_grid) if entry.has("gpu_draws") else entry.image.get_region(Rect2i(native.position - entry.bounds.position, native.size))
		image.convert(Image.FORMAT_LA8)
		if divisor > 1:
			image.resize(native.size.x * divisor, native.size.y * divisor, Image.INTERPOLATE_NEAREST)
		output.blit_rect(image, Rect2i(overlap.position - first * divisor, overlap.size), overlap.position - bounds.position)
	return output

func pixel(point: Vector2i) -> Color:
	if point.x < 0 or point.y < 0:
		return Color.TRANSPARENT
	var native := Vector2i(point / divisor)
	var key := Vector2i(native / region_edge)
	if not entries.has(key):
		return Color.TRANSPARENT
	var entry: Dictionary = entries[key]
	var local: Vector2i = native - entry.bounds.position
	if entry.has("gpu_draws"):
		return CityGpuDrawList.paint(entry.gpu_draws, Rect2i(native, Vector2i.ONE), entry.background, entry.gpu_draw_grid).get_pixel(0, 0)
	return entry.image.get_pixelv(local) if Rect2i(Vector2i.ZERO, entry.image.get_size()).has_point(local) else Color.TRANSPARENT

func covered() -> bool:
	for key in visible:
		if not entries.has(key):
			return false
	return not visible.is_empty()

func ready() -> bool:
	for key in visible:
		if not entries.has(key) or entries[key].generation != generation:
			return false
	return not visible.is_empty()

func offscreen_limit() -> int:
	return GPU_OFFSCREEN_LIMIT if gpu_enabled else OFFSCREEN_LIMIT

func prefetch_ready() -> bool:
	for key in wanted:
		if not entries.has(key) or entries[key].generation != generation:
			return false
	return not wanted.is_empty()

func metrics() -> Dictionary:
	var bytes := 0
	for entry: Dictionary in entries.values():
		if not entry.has("image"):
			continue
		bytes += entry.image.get_width() * entry.image.get_height() * (1 if entry.image.get_format() == Image.FORMAT_L8 else 2)
	return {"gpu": gpu_enabled, "atlas_bytes": _gpu_atlas_bytes(), "resident": entries.size(), "visible": visible.size(), "offscreen_limit": offscreen_limit(), "cpu_image_bytes": bytes, "texture_bytes_estimate": bytes, "completed": completed_regions, "discarded": discarded_regions, "max_region_usec": max_region_usec, "ready": ready(), "covered": covered(), "pending": _thread != null or _gpu_pending()}

func close() -> void:
	_close_gpu_workers()
	if _thread != null:
		_thread.wait_to_finish()
	_thread = null
	entries.clear()
	_snapshot = null
	display_city = null

static func _render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, bounds: Rect2i, view: int, render_mode: String, visibility: Dictionary, prepared: bool, pipes: bool, subways: bool, gpu_context: CityGpuBuildContext = null, revision := 0, atlas_revision := -1, foreground_requests: Array[Dictionary] = []) -> Dictionary:
	var started := Time.get_ticks_usec()
	var display := city if prepared else CityViewFilter.surface_copy(city, visibility)
	var result := CityGpuRegionRenderer.render(display, palette, sprites, bounds, view, render_mode, pipes, subways, gpu_context, revision, atlas_revision) if gpu_context != null else CityRegionRenderer.render(display, palette, sprites, bounds, view, render_mode, pipes, subways)
	if result.ok and gpu_context != null and render_mode == "city":
		result.sign_foregrounds = CityGpuSignForegrounds.build(result, foreground_requests, palette, sprites, gpu_context, int(CityIsometricRenderer.view_configuration(view).divisor))
	result.display_city = display
	result.usec = Time.get_ticks_usec() - started
	return result


func _gpu_pending() -> bool:
	for worker in _gpu_workers:
		if worker.thread != null:
			return true
	return false

func _close_gpu_workers() -> void:
	for worker in _gpu_workers:
		if worker.thread != null:
			worker.thread.wait_to_finish()
	_gpu_workers.clear()

func _tick_gpu() -> bool:
	if _gpu_workers.is_empty():
		for index in mini(GPU_WORKERS, maxi(1, OS.get_processor_count() - 2)):
			_gpu_workers.append({"thread": null, "context": null, "atlas": null, "atlas_revision": -1, "layout": -1, "generation": -1, "keys": []})
	for worker in _gpu_workers:
		if worker.thread == null or worker.thread.is_alive():
			continue
		var result: Dictionary = worker.thread.wait_to_finish()
		worker.thread = null
		_gpu_has_work = true
		if int(worker.layout) != _layout_generation:
			discarded_regions += worker.keys.size()
			continue
		if not result.ok:
			push_warning("GPU city renderer unavailable; using CPU: " + str(result.error))
			_close_gpu_workers()
			gpu_enabled = false
			wanted.resize(mini(wanted.size(), visible.size() + OFFSCREEN_LIMIT))
			_viewport_valid = false
			_foreground_reset = true
			entries.clear()
			_layout_generation += 1
			_changed = false
			return true
		if int(worker.generation) == generation and not _prepared:
			_snapshot = result.display_city
			display_city = _snapshot
			_prepared = true
		if result.atlas_image != null:
			if worker.atlas == null:
				worker.atlas = ImageTexture.create_from_image(result.atlas_image)
			else:
				worker.atlas.update(result.atlas_image)
			worker.atlas_revision = int(result.atlas_revision)
		for region: Dictionary in result.regions:
			var key: Vector2i = region.key
			if key not in wanted or (entries.has(key) and int(entries[key].generation) > int(worker.generation)):
				discarded_regions += 1
				continue
			var mesh := ArrayMesh.new()
			if not region.gpu_arrays[Mesh.ARRAY_VERTEX].is_empty():
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, region.gpu_arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
			region.mesh = mesh
			region.atlas_texture = worker.atlas
			region.generation = int(worker.generation)
			region.last_visible = _viewport_serial if key in visible else int(entries.get(key, {}).get("last_visible", 0))
			region.erase("gpu_arrays")
			region.erase("atlas_image")
			entries[key] = region
			foreground_changes.append(Rect2i(region.bounds.position * divisor, region.bounds.size * divisor))
			completed_regions += 1
			max_region_usec = maxi(max_region_usec, int(region.usec))
			_changed = _changed or key in visible
	_trim_retained_regions()
	var changed := _changed
	_changed = false
	if not _gpu_has_work or _gpu_workers.all(func(worker: Dictionary) -> bool: return worker.thread != null):
		return changed
	var active := {}
	for worker in _gpu_workers:
		if worker.thread != null and int(worker.layout) == _layout_generation:
			for key in worker.keys:
				active[key] = true
	var queue: Array[Vector2i] = []
	queue.assign(visible)
	# fill holes first, then refresh the oldest visible versions. continuous
	# simulation updates must not repeatedly rebuild only the center regions
	var ranked: Array[Vector3i] = []
	for index in queue.size():
		var key := queue[index]
		ranked.append(Vector3i(int(entries.get(key, {}).get("generation", -1)), index, (key.x << 16) | key.y))
	ranked.sort()
	queue.clear()
	for rank in ranked:
		queue.append(Vector2i(rank.z >> 16, rank.z & 0xffff))
	_gpu_schedule_serial += 1
	# reserve some work for missing look-ahead regions even when simulation
	# changes keep the visible regions continuously out of date
	if covered() and _gpu_schedule_serial % 3 == 0:
		var missing_prefetch: Array[Vector2i] = []
		for key in wanted.slice(visible.size()):
			if not entries.has(key):
				missing_prefetch.append(key)
		queue = missing_prefetch + queue
	queue.append_array(wanted.slice(visible.size()))
	_gpu_has_work = false
	for worker in _gpu_workers:
		if worker.thread != null:
			continue
		var keys: Array[Vector2i] = []
		var worker_index := _gpu_workers.find(worker)
		# keep the first result quick. warm workers then run bounded batches
		var limit := CityGpuRegionBatch.MAX_REGIONS if int(worker.layout) == _layout_generation else 1
		for key in queue:
			if active.has(key) or (entries.has(key) and int(entries[key].generation) == generation):
				continue
			# keep neighboring wide-view regions on the same worker so their tile
			# geometry and bounds are prepared once. small views use either worker
			if visible.size() >= 32 and int(key.x / 8) % _gpu_workers.size() != worker_index:
				continue
			keys.append(key)
			active[key] = true
			if keys.size() >= limit:
				break
		if keys.is_empty():
			continue
		_gpu_has_work = true
		if int(worker.layout) != _layout_generation:
			worker.context = CityGpuBuildContext.new()
			worker.atlas = null
			worker.atlas_revision = -1
		worker.layout = _layout_generation
		worker.generation = generation
		worker.keys = keys
		worker.thread = Thread.new()
		var request := {"city": _snapshot, "prepared": _prepared, "visibility": _visibility,
			"palette": _palette, "sprites": _sprites, "keys": keys, "edge": region_edge,
			"view": view_size, "mode": mode, "pipes": _show_pipes, "subways": _show_subways,
			"generation": generation, "signs": sign_requests}
		var error: Error = worker.thread.start(CityGpuRegionBatch.build.bind(request, worker.context, worker.atlas_revision), Thread.PRIORITY_LOW)
		if error != OK:
			worker.thread = null
			_close_gpu_workers()
			gpu_enabled = false
			wanted.resize(mini(wanted.size(), visible.size() + OFFSCREEN_LIMIT))
			_viewport_valid = false
			entries.clear()
			_layout_generation += 1
			return true
	return changed


func _gpu_atlas_bytes() -> int:
	var bytes := 0
	for worker in _gpu_workers:
		if worker.atlas != null:
			bytes += CityGpuBuildContext.ATLAS_EDGE * CityGpuBuildContext.ATLAS_EDGE * 2
	return bytes
