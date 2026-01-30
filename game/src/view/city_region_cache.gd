class_name CityRegionCache
extends RefCounted

const REGION_EDGE := 512
const OFFSCREEN_LIMIT := 12
const GPU_REGION_EDGE := 256
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

static func gpu_supported() -> bool:
	var requested := OS.get_environment("OPENSC2K_CITY_RENDERER").to_lower()
	return requested == "gpu" or (DisplayServer.get_name() != "headless" and requested != "cpu")

func configure(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		new_signature: Array, new_view: int, new_mode: String, visibility: Dictionary,
		show_pipes: bool, show_subways: bool, dirty := Rect2i()) -> void:
	if _snapshot == null:
		region_edge = GPU_REGION_EDGE if gpu_enabled else REGION_EDGE
	if signature == new_signature and view_size == new_view and mode == new_mode and _snapshot != null:
		return
	var reset := _snapshot == null or _snapshot.map_size != city.map_size or view_size != new_view or mode != new_mode or _snapshot.document.source_path != city.document.source_path or _snapshot.compass_rotation() != city.compass_rotation() or _snapshot.visible_altitude_levels != city.visible_altitude_levels or _visibility != visibility or _sprites != sprites or _show_pipes != show_pipes or _show_subways != show_subways
	generation += 1
	last_error = ""
	if not reset and dirty.has_area():
		for entry: Dictionary in entries.values():
			if int(entry.generation) == generation - 1 and not entry.bounds.intersects(dirty):
				entry.generation = generation
	if reset:
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

func update_viewport(source_rect: Rect2) -> void:
	var rect := Rect2i(Vector2i((source_rect.position / divisor).floor()), Vector2i((source_rect.size / divisor).ceil()) + Vector2i.ONE)
	rect = rect.intersection(Rect2i(Vector2i.ZERO, native_size))
	var old_visible := visible.duplicate()
	visible.clear()
	wanted.clear()
	if not rect.has_area():
		_changed = _changed or not entries.is_empty()
		entries.clear()
		return
	var first := Vector2i(rect.position / region_edge)
	var last := Vector2i((rect.end - Vector2i.ONE) / region_edge)
	var nearby: Array[Vector2i] = []
	for y in range(maxi(0, first.y - 1), mini(ceili(float(native_size.y) / region_edge), last.y + 2)):
		for x in range(maxi(0, first.x - 1), mini(ceili(float(native_size.x) / region_edge), last.x + 2)):
			var key := Vector2i(x, y)
			if x >= first.x and x <= last.x and y >= first.y and y <= last.y:
				visible.append(key)
			else:
				nearby.append(key)
	var center := Vector2(rect.get_center()) / region_edge - Vector2(0.5, 0.5)
	var closer := func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center)
	visible.sort_custom(closer)
	nearby.sort_custom(closer)
	if old_visible != visible:
		_changed = true
	wanted.append_array(visible)
	wanted.append_array(nearby.slice(0, OFFSCREEN_LIMIT))
	for key in entries.keys():
		if key not in wanted:
			entries.erase(key)
			_changed = true

func tick() -> bool:
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
	for key in visible:
		if not entries.has(key):
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

func image_region(bounds: Rect2i) -> Image:
	var output := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_LA8)
	output.fill(Color.TRANSPARENT)
	for entry: Dictionary in entries.values():
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

func metrics() -> Dictionary:
	var bytes := 0
	for entry: Dictionary in entries.values():
		if not entry.has("image"):
			continue
		bytes += entry.image.get_width() * entry.image.get_height() * (1 if entry.image.get_format() == Image.FORMAT_L8 else 2)
	return {"gpu": gpu_enabled, "atlas_bytes": _gpu_atlas_bytes(), "resident": entries.size(), "visible": visible.size(), "offscreen_limit": OFFSCREEN_LIMIT, "cpu_image_bytes": bytes, "texture_bytes_estimate": bytes, "completed": completed_regions, "discarded": discarded_regions, "max_region_usec": max_region_usec, "ready": ready(), "covered": covered(), "pending": _thread != null or _gpu_pending()}

func close() -> void:
	_close_gpu_workers()
	if _thread != null:
		_thread.wait_to_finish()
	_thread = null
	entries.clear()
	_snapshot = null
	display_city = null

static func _render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, bounds: Rect2i, view: int, render_mode: String, visibility: Dictionary, prepared: bool, pipes: bool, subways: bool, gpu_context: CityGpuBuildContext = null, revision := 0, atlas_revision := -1) -> Dictionary:
	var started := Time.get_ticks_usec()
	var display := city if prepared else CityViewFilter.surface_copy(city, visibility)
	var result := CityGpuRegionRenderer.render(display, palette, sprites, bounds, view, render_mode, pipes, subways, gpu_context, revision, atlas_revision) if gpu_context != null else CityRegionRenderer.render(display, palette, sprites, bounds, view, render_mode, pipes, subways)
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
		for index in mini(2, maxi(1, OS.get_processor_count() - 2)):
			_gpu_workers.append({"thread": null, "context": null, "atlas": null, "atlas_revision": -1, "layout": -1, "generation": -1, "key": Vector2i.ZERO})
	for worker in _gpu_workers:
		if worker.thread == null or worker.thread.is_alive():
			continue
		var result: Dictionary = worker.thread.wait_to_finish()
		worker.thread = null
		if int(worker.layout) != _layout_generation:
			discarded_regions += 1
			continue
		if not result.ok:
			push_warning("GPU city renderer unavailable; using CPU: " + str(result.error))
			_close_gpu_workers()
			gpu_enabled = false
			entries.clear()
			_layout_generation += 1
			_changed = false
			return true
		var key: Vector2i = worker.key
		if key not in wanted or (entries.has(key) and int(entries[key].generation) > int(worker.generation)):
			discarded_regions += 1
			continue
		if int(worker.generation) == generation:
			_snapshot = result.display_city
			display_city = _snapshot
			_prepared = true
		result.erase("display_city")
		if result.atlas_image != null:
			if worker.atlas == null:
				worker.atlas = ImageTexture.create_from_image(result.atlas_image)
			else:
				worker.atlas.update(result.atlas_image)
			worker.atlas_revision = int(result.atlas_revision)
		var mesh := ArrayMesh.new()
		if not result.gpu_arrays[Mesh.ARRAY_VERTEX].is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result.gpu_arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		result.mesh = mesh
		result.atlas_texture = worker.atlas
		result.generation = int(worker.generation)
		result.erase("gpu_arrays")
		result.erase("atlas_image")
		entries[key] = result
		completed_regions += 1
		max_region_usec = maxi(max_region_usec, int(result.usec))
		_changed = _changed or key in visible
	var active := {}
	for worker in _gpu_workers:
		if worker.thread != null and int(worker.layout) == _layout_generation:
			active[worker.key] = true
	var queue: Array[Vector2i] = []
	for key in visible:
		if not entries.has(key):
			queue.append(key)
	queue.append_array(wanted)
	for worker in _gpu_workers:
		if worker.thread != null:
			continue
		for key in queue:
			if active.has(key) or (entries.has(key) and int(entries[key].generation) == generation):
				continue
			if int(worker.layout) != _layout_generation:
				worker.context = CityGpuBuildContext.new()
				worker.atlas = null
				worker.atlas_revision = -1
			worker.layout = _layout_generation
			worker.generation = generation
			worker.key = key
			worker.thread = Thread.new()
			var bounds := Rect2i(key * region_edge, Vector2i(region_edge, region_edge))
			var error: Error = worker.thread.start(_render.bind(_snapshot, _palette, _sprites, bounds, view_size, mode, _visibility, _prepared, _show_pipes, _show_subways, worker.context, generation, worker.atlas_revision), Thread.PRIORITY_LOW)
			if error != OK:
				worker.thread = null
				_close_gpu_workers()
				gpu_enabled = false
				entries.clear()
				_layout_generation += 1
				return true
			active[key] = true
			break
	var changed := _changed
	_changed = false
	return changed


func _gpu_atlas_bytes() -> int:
	var bytes := 0
	for worker in _gpu_workers:
		if worker.atlas != null:
			bytes += CityGpuBuildContext.ATLAS_EDGE * CityGpuBuildContext.ATLAS_EDGE * 2
	return bytes
