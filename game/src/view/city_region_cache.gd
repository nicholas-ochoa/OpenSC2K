class_name CityRegionCache
extends RefCounted


@warning_ignore_start("integer_division")

const REGION_EDGE := 512
const OFFSCREEN_LIMIT := 12
const GPU_OFFSCREEN_LIMIT := 384
const GPU_PREFETCH_LIMIT := 256
const GPU_REGION_EDGE := 256
const GPU_WORKERS := 2
# chunks whose tile data the region renderers read
const SOURCE_CHUNKS: Array[String] = ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT", "XUND", "XTRF"]
# above this count, report the whole region as changed foreground geometry
const MAX_OCCLUDER_CHANGES := 32
class RegionWorker extends RefCounted:
	var task: CityRenderTask
	var context: CityGpuBuildContext
	var atlas: ImageTexture
	var atlas_revision := -1
	var layout := -1
	var generation := -1
	var keys: Array[Vector2i] = []


var region_edge := REGION_EDGE
var gpu_enabled := gpu_supported()
var _gpu_workers: Array[RegionWorker] = []
var entries: Dictionary[Vector2i, CityRegionResult] = {}
var wanted: Array[Vector2i] = []
var visible: Array[Vector2i] = []
var signature: Array = []
var view_size := 2
var mode := CityViewMode.Mode.CITY
var divisor := 1
var native_size := Vector2i.ZERO
var display_city: CityState
var generation := 0
var completed_regions := 0
var discarded_regions := 0
var max_region_usec := 0
var tile_builds := 0
var tile_reuses := 0
var last_error := ""
var _snapshot: CityState
var _palette: Sc2Palette
var _sprites: Sc2SpriteArchive
var _visibility: Dictionary
var _show_water_mains := true
var _show_pipes := true
var _show_subways := true
var _prepared := false
var _task: CityRenderTask
var _job_key := Vector2i.ZERO
var _job_generation := 0
var _layout_generation := 0
var _job_layout := 0
var _changed := false
var _viewport_rect := Rect2i()
var _viewport_valid := false
var foreground_changes: Array[Rect2i] = []
# the parts of `foreground_changes` where the static foreground silhouettes changed
var occluder_changes: Array[Rect2i] = []
# regions that became visible since the last tick. occlusion reads only visible
# regions, so a moving sprite cached beside the view lacks their silhouettes
var _visibility_changes: Array[Rect2i] = []
var sign_requests: Array[CitySignRequest] = []
var sign_layout_token: Array = []
var _foreground_reset := true
var _gpu_has_work := true
var _viewport_serial := 0
var _gpu_schedule_serial := 0
var _edit_priority: Dictionary[Vector2i, int] = {}
# decoded payloads of the configured city. a later configure compares them to
# find the changed tiles. packed arrays share data until the city writes again
var source_payloads: Dictionary[String, PackedByteArray] = {}


static func gpu_supported(preference := "gpu") -> bool:
	var requested := OS.get_environment("OPENSC2K_CITY_RENDERER").to_lower()

	return requested == "gpu" or (DisplayServer.get_name() != "headless" and requested != "cpu" and preference != "cpu")


# `dirty` and `changed` bound the changed screen areas. without them every region
# draws again, unless `changes_listed` tells that `changed` lists every change
func configure(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		new_signature: Array, new_view: int, new_mode: CityViewMode.Mode, visibility: Dictionary,
		show_pipes: bool, show_subways: bool, dirty := Rect2i(), show_water_mains := true,
		changed: Array[Rect2i] = [], changes_listed := false) -> void:
	if _snapshot == null:
		region_edge = GPU_REGION_EDGE if gpu_enabled else REGION_EDGE

	if (signature == new_signature and view_size == new_view and mode == new_mode and _snapshot != null and _show_pipes == show_pipes
			and _show_subways == show_subways and _show_water_mains == show_water_mains):
		return

	var reset := _needs_reset(
		city, new_view, new_mode, visibility, sprites, show_pipes, show_subways, show_water_mains
	)

	# no region shows the change, so the drawn snapshot still matches the city
	if not reset and changes_listed and changed.is_empty() and not dirty.has_area():
		signature = new_signature.duplicate()
		_keep_source_payloads(city)

		return

	generation += 1
	_gpu_has_work = true
	last_error = ""

	if not reset and (dirty.has_area() or changes_listed):
		var rects := changed.duplicate()

		if dirty.has_area():
			rects.append(dirty)

		var dirty_keys := _region_keys(rects)

		# Only player edits bypass missing-region work. Repeated simulation
		# changes must not keep newly visible regions at the back of the queue.
		if dirty.has_area():
			for key in visible:
				if dirty_keys.has(key):
					_edit_priority[key] = generation

		for key in entries:
			var entry := entries[key]

			if int(entry.generation) == generation - 1 and not dirty_keys.has(key):
				entry.generation = generation

	if reset:
		_edit_priority.clear()
		_foreground_reset = true
		_viewport_valid = false
		_layout_generation += 1
		entries.clear()
		_changed = true

	signature = new_signature.duplicate()
	view_size = new_view
	mode = new_mode
	divisor = CityIsometricRenderer.view_configuration(view_size).divisor
	native_size = CityIsometricRenderer.output_size_for_view(view_size, city.map_size)
	_snapshot = CityState.new()
	_snapshot.document = city.document.duplicate_document(true)
	_snapshot.map_size = city.map_size
	_snapshot.visible_altitude_levels = city.visible_altitude_levels

	city.copy_mirrors_to(_snapshot)
	_keep_source_payloads(city)
	display_city = _snapshot
	_palette = palette
	_sprites = sprites
	_visibility = visibility.duplicate()
	_show_water_mains = show_water_mains
	_show_pipes = show_pipes
	_show_subways = show_subways
	_prepared = mode == CityViewMode.Mode.UNDERGROUND


func _keep_source_payloads(city: CityState) -> void:
	source_payloads.clear()

	for chunk_id in SOURCE_CHUNKS:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk != null:
			source_payloads[chunk_id] = chunk.decoded_payload


func _region_keys(rects: Array[Rect2i]) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}

	for rect in rects:
		if not rect.has_area():
			continue

		var first := rect.position.maxi(0) / region_edge
		var last := (rect.end - Vector2i.ONE).maxi(0) / region_edge

		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				result[Vector2i(x, y)] = true

	return result


# true when the change invalidates every cached region: another city, map
# size, rotation, altitude cut, view scale, view mode, sprite set, or layer
# visibility. other changes keep the regions and mark only the dirty ones
func _needs_reset(
	city: CityState, new_view: int, new_mode: CityViewMode.Mode, visibility: Dictionary,
	sprites: Sc2SpriteArchive, show_pipes: bool, show_subways: bool, show_water_mains: bool
) -> bool:
	if _snapshot == null:
		return true

	return (
		_snapshot.map_size != city.map_size
		or view_size != new_view
		or mode != new_mode
		or _snapshot.document.source_path != city.document.source_path
		or _snapshot.compass_rotation() != city.compass_rotation()
		or _snapshot.visible_altitude_levels != city.visible_altitude_levels
		or _visibility != visibility
		or _sprites != sprites
		or _show_pipes != show_pipes
		or _show_subways != show_subways
		or _show_water_mains != show_water_mains
	)


func set_sign_requests(requests: Array[CitySignRequest]) -> void:
	var next: Array[CitySignRequest] = []

	for request in requests:
		var bounds: Rect2i = request.bounds.intersection(Rect2i(Vector2i.ZERO, native_size * divisor))

		if bounds.has_area():
			next.append(CitySignRequest.new(request.key, bounds, request.draw_order))

	sign_requests = next


func sign_foreground(key: int, bounds: Rect2i, order: int, texture_factor := 1) -> Image:
	var result := Image.create(bounds.size.x * texture_factor, bounds.size.y * texture_factor, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)

	for region_key in _keys_for_bounds(bounds):
		if not entries.has(region_key):
			return null

		var entry: CityRegionResult = entries[region_key]
		var gpu := entry as CityGpuRegionResult
		var patch: CitySignForegroundPatch = gpu.sign_foregrounds.get(key) if gpu != null else null

		if patch == null or patch.source_bounds != bounds or int(patch.draw_order) != order:
			return null

		var image: Image = patch.image

		if patch.texture_factor != divisor * texture_factor:
			image = image.duplicate()
			image.resize(patch.bounds.size.x * divisor * texture_factor, patch.bounds.size.y * divisor * texture_factor, Image.INTERPOLATE_NEAREST)

		var world := Rect2i(patch.bounds.position * divisor, patch.bounds.size * divisor)
		var overlap := bounds.intersection(world)
		result.blit_rect(image, Rect2i((overlap.position - world.position) * texture_factor, overlap.size * texture_factor),
				(overlap.position - bounds.position) * texture_factor)

	return result


func update_viewport(source_rect: Rect2) -> void:
	CityRegionScheduling.update_viewport(self, source_rect)


static func _sort_regions(keys: Array[Vector2i], center: Vector2, first: Vector2i, last: Vector2i, rings: bool) -> void:
	CityRegionScheduling._sort_regions(keys, center, first, last, rings)


func _trim_retained_regions() -> void:
	CityRegionScheduling._trim_retained_regions(self)


func tick() -> bool:
	foreground_changes.clear()
	foreground_changes.append_array(_visibility_changes)
	_visibility_changes.clear()

	if _foreground_reset:
		foreground_changes.append(Rect2i(Vector2i.ZERO, native_size * divisor))
		_foreground_reset = false

	occluder_changes.assign(foreground_changes)

	if gpu_enabled:
		return _tick_gpu()

	if _task != null and not _task.is_running():
		var result: CityRegionResult = _task.finish()
		_task = null

		if not result.ok:
			last_error = result.error
			_changed = true
		elif _job_layout == _layout_generation and _job_key in wanted and (not entries.has(_job_key) or int(entries[_job_key].generation) <= _job_generation):
			if _job_generation == generation:
				_snapshot = result.display_city
				display_city = _snapshot
				_prepared = true

			result.display_city = null
			result.texture = ImageTexture.create_from_image(result.image)
			result.generation = _job_generation
			publish_changes(entries.get(_job_key), result)
			entries[_job_key] = result
			completed_regions += 1
			max_region_usec = maxi(max_region_usec, int(result.usec))
			_changed = _changed or _job_key in visible
		else:
			discarded_regions += 1

	if _task == null and last_error.is_empty():
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
			_task = CityRenderTask.new()
			var bounds := Rect2i(key * region_edge, Vector2i(region_edge, region_edge))
			var error := _task.start(_render.bind(_snapshot, _palette, _sprites, bounds, view_size, mode, _visibility, _prepared, _show_pipes,
					_show_subways, _show_water_mains))

			if error != OK:
				_task = null
				last_error = error_string(error)
				_changed = true

			break

	var changed := _changed
	_changed = false

	return changed


# record the screen areas that change when `after` replaces `before`
func publish_changes(before: CityRegionResult, after: CityRegionResult) -> void:
	var region := Rect2i(after.bounds.position * divisor, after.bounds.size * divisor)
	foreground_changes.append(region)
	var changed: Array[Rect2i] = []

	if before != null:
		changed = changed_foreground(before, after)

	if before == null or changed.size() > MAX_OCCLUDER_CHANGES:
		occluder_changes.append(region)

		return

	for rect in changed:
		occluder_changes.append(Rect2i(rect.position * divisor, rect.size * divisor))


# return the native bounds of the foreground commands that differ between two results of one region
static func changed_foreground(before: CityRegionResult, after: CityRegionResult) -> Array[Rect2i]:
	var previous: Dictionary[int, CityStaticCommand] = {}
	var result: Array[Rect2i] = []

	for command in before.occlusion_commands:
		previous[command.region_order] = command

	for command in after.occlusion_commands:
		var old: CityStaticCommand = previous.get(command.region_order)

		if old != null:
			previous.erase(command.region_order)

			if _same_command(old, command):
				continue

			result.append(Rect2i(old.position, old.size))

		result.append(Rect2i(command.position, command.size))

	for command: CityStaticCommand in previous.values():
		result.append(Rect2i(command.position, command.size))

	return result


static func _same_command(left: CityStaticCommand, right: CityStaticCommand) -> bool:
	return (left.sprite_id == right.sprite_id and left.flip == right.flip and left.position == right.position
		and left.size == right.size and left.depth_order == right.depth_order and left.train_ignore == right.train_ignore
		and left.train_foreground_reference_sprite_id == right.train_foreground_reference_sprite_id
		and left.train_deck_thickness == right.train_deck_thickness
		and left.train_deck_reference_sprite_id == right.train_deck_reference_sprite_id
		and left.train_foreground_requires_depth == right.train_foreground_requires_depth)


func texture() -> CityMapSource:
	var output := CityMapSource.new(native_size * divisor)

	for key in visible:
		if not entries.has(key):
			continue

		var entry: CityRegionResult = entries[key]

		var gpu := entry as CityGpuRegionResult

		if gpu != null:
			output.meshes.append(CityMapSource.MeshEntry.new(Vector2(gpu.bounds.position * divisor), gpu.mesh, gpu.atlas_texture, divisor,
				gpu.depth_mesh, gpu.train_depth_mesh))
			continue

		output.tiles.append(CityMapSource.TileEntry.new(Vector2(entry.bounds.position * divisor), Vector2(entry.bounds.size * divisor), entry.texture))

	return output


func occlusion_candidates(bounds: Rect2i) -> Array[CityStaticCommand]:
	var found: Dictionary[int, CityStaticCommand] = {}
	var versions: Dictionary[int, int] = {}
	var native := Rect2(Vector2(bounds.position) / divisor, Vector2(bounds.size) / divisor)

	for key in _keys_for_bounds(bounds):
		if not entries.has(key) or key not in visible:
			continue

		var entry: CityRegionResult = entries[key]

		if not Rect2(entry.bounds).intersects(native):
			continue

		for index in CityIsometricRenderer.occlusion_candidate_indices(entry.occlusion_grid, bounds):
			var command: CityStaticCommand = entry.occlusion_commands[index]
			var order: int = command.region_order

			if int(versions.get(order, -1)) > int(entry.generation):
				continue

			found[order] = command
			versions[order] = entry.generation

	var ordered := found.keys()
	ordered.sort()
	var result: Array[CityStaticCommand] = []

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


func image_region(bounds: Rect2i, texture_factor := 1) -> Image:
	assert(texture_factor in [1, 2, 4])
	var output := Image.create(bounds.size.x * texture_factor, bounds.size.y * texture_factor, false, Image.FORMAT_LA8)
	output.fill(Color.TRANSPARENT)

	for key in _keys_for_bounds(bounds):
		if not entries.has(key):
			continue

		var entry: CityRegionResult = entries[key]
		var world := Rect2i(entry.bounds.position * divisor, entry.bounds.size * divisor)
		var overlap := world.intersection(bounds)

		if not overlap.has_area():
			continue

		var first := Vector2i((Vector2(overlap.position) / divisor).floor())
		var last := Vector2i((Vector2(overlap.end) / divisor).ceil())
		var native := Rect2i(first, last - first)
		var sample_factor := texture_factor if divisor == 1 else 1
		var gpu := entry as CityGpuRegionResult
		var image: Image = (CityGpuDrawList.paint(gpu.gpu_draws, native, gpu.background, gpu.gpu_draw_grid, sample_factor)
				if gpu != null else entry.image.get_region(Rect2i(native.position - entry.bounds.position, native.size)))
		image.convert(Image.FORMAT_LA8)
		var target_size := native.size * divisor * texture_factor

		if image.get_size() != target_size:
			image.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)

		output.blit_rect(image, Rect2i((overlap.position - first * divisor) * texture_factor, overlap.size * texture_factor),
				(overlap.position - bounds.position) * texture_factor)

	return output


func pixel(point: Vector2i) -> Color:
	if point.x < 0 or point.y < 0:
		return Color.TRANSPARENT

	var native := Vector2i(point / divisor)
	var key := Vector2i(native / region_edge)

	if not entries.has(key):
		return Color.TRANSPARENT

	var entry: CityRegionResult = entries[key]
	var local: Vector2i = native - entry.bounds.position

	var gpu := entry as CityGpuRegionResult

	if gpu != null:
		return CityGpuDrawList.paint(gpu.gpu_draws, Rect2i(native, Vector2i.ONE), gpu.background, gpu.gpu_draw_grid).get_pixel(0, 0)

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
	for entry: CityRegionResult in entries.values():
		if entry.image == null:
			continue

		bytes += entry.image.get_width() * entry.image.get_height() * (1 if entry.image.get_format() == Image.FORMAT_L8 else 2)

	return {"gpu": gpu_enabled, "atlas_bytes": _gpu_atlas_bytes(), "resident": entries.size(), "visible": visible.size(),
			"tile_builds": tile_builds, "tile_reuses": tile_reuses,
			"offscreen_limit": offscreen_limit(), "cpu_image_bytes": bytes, "texture_bytes_estimate": bytes, "completed": completed_regions,
			"discarded": discarded_regions, "max_region_usec": max_region_usec, "ready": ready(), "covered": covered(), "pending": _task != null or _gpu_pending()}


func close() -> void:
	_close_gpu_workers()

	if _task != null:
		_task.finish()

	_task = null
	entries.clear()
	source_payloads.clear()
	_snapshot = null
	display_city = null


static func _render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, bounds: Rect2i, view: int,
		render_mode: CityViewMode.Mode, visibility: Dictionary, prepared: bool, pipes: bool, subways: bool, water_mains: bool,
		gpu_context: CityGpuBuildContext = null, revision := 0, atlas_revision := -1, foreground_requests: Array[CitySignRequest] = []) -> CityRegionResult:
	var started := Time.get_ticks_usec()
	var display := city if prepared else CityViewFilter.surface_copy(city, visibility)
	var result: CityRegionResult = (CityGpuRegionRenderer.render(display, palette, sprites, bounds, view, render_mode, pipes, subways, gpu_context, revision,
			atlas_revision, true, water_mains) if gpu_context != null
			else CityRegionRenderer.render(display, palette, sprites, bounds, view, render_mode, pipes, subways, water_mains))

	if result.ok and gpu_context != null and render_mode == CityViewMode.Mode.CITY:
		var gpu := result as CityGpuRegionResult
		gpu.sign_foregrounds = CityGpuSignForegrounds.build(gpu, foreground_requests, palette, sprites, gpu_context,
				CityIsometricRenderer.view_configuration(view).divisor)

	result.display_city = display
	result.usec = Time.get_ticks_usec() - started

	return result


func _gpu_pending() -> bool:
	return CityRegionScheduling._gpu_pending(self)


func _close_gpu_workers() -> void:
	CityRegionScheduling._close_gpu_workers(self)


func _tick_gpu() -> bool:
	return CityRegionScheduling._tick_gpu(self)


func _gpu_atlas_bytes() -> int:
	return CityRegionScheduling._gpu_atlas_bytes(self)
