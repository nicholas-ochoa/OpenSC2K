class_name CityNightGround
extends Node2D
## Cached, visible road receivers. Short entrance approaches never cross tiles
## other than the immediately adjacent street. No simulation state is written.
@warning_ignore_start("integer_division")

const SHADER := preload("res://src/view/environment/night_ground.gdshader")
const FIXTURE_SHADER := preload("res://src/view/environment/night_fixture.gdshader")
const PROFILES := "res://src/view/environment/night_light_profiles.json"
const MAX_CACHED := 32768
const MAX_TEXTURE_BYTES := 96 * 1024 * 1024
const BUFFER_MARGIN := 160.0
const BUILD_BUDGET := 128
var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILES))
var roads := CityLifeLights.new()
var masker := CityLifeCanvas.new()
var cache: Dictionary[Vector2i, Dictionary] = {}
var visible_tiles: Array[Vector2i] = []
var signature: Array = []
var bounds := Rect2i()
var cursor := 0
var pending: Array[Vector2i] = []
var queued: Dictionary[Vector2i, bool] = {}
var visible_keys: Dictionary[Vector2i, bool] = {}
var templates := CityNightTemplates.new()
var geometry: Array = []
var dirty: Dictionary[Vector2i, bool] = {}
var last_used: Dictionary[Vector2i, int] = {}
var collection := 0
var texture_users: Dictionary[int, Dictionary] = {}
var texture_bytes := 0
var texture_budget := MAX_TEXTURE_BYTES
var fixtures := Node2D.new()
var signals := Node2D.new()
var signal_tiles: Array[Vector2i] = []
var clock := 0.0
var resident := false
var prepare_entire_city := false
var fades: CityLightFade
var fade_edge := 128
var fade_rotation := 0
var unseen: Dictionary[Vector2i, bool] = {}
var fade_view := Rect2()
var fade_revision := -1
var fade_pending := false


func _init() -> void:
	var shader := ShaderMaterial.new()
	shader.shader = SHADER
	material = shader
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	masker.include_cached_regions = true
	add_child(masker)
	masker.hide()
	fixtures.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fixture_material := ShaderMaterial.new()
	fixture_material.shader = FIXTURE_SHADER
	fixtures.material = fixture_material
	add_child(fixtures)
	fixtures.draw.connect(_draw_fixtures)
	fixtures.add_child(signals)
	signals.use_parent_material = true
	signals.draw.connect(_draw_signals)


func reset() -> void:
	unseen.clear()
	fade_revision = -1
	cache.clear()
	texture_users.clear()
	texture_bytes = 0
	dirty.clear()
	last_used.clear()
	geometry.clear()
	roads.roads.clear()
	masker._occluders.clear()
	masker._occluder_bounds.clear()
	visible_tiles.clear()
	visible_keys.clear()
	pending.clear()
	queued.clear()
	signal_tiles.clear()
	templates.clear()
	signature.clear()
	bounds = Rect2i()
	cursor = 0
	queue_redraw()
	fixtures.queue_redraw()
	signals.queue_redraw()


func sync(app: CityApplication, strength: float, elapsed := 0.0, prepare := false, budget_usec := 4000) -> void:
	visible = strength > 0.001 and app.view_state.surface_visibility.networks and app.view_state.surface_visibility.buildings
	if not visible and not prepare:
		return
	var previous_second := floori(clock)
	clock = fposmod(clock + maxf(elapsed, 0.0), 14.0)
	if floori(clock) != previous_second:
		signals.queue_redraw()
	fixtures.modulate.a = smoothstep(0.0, 0.25, strength)
	var map := app.map_view
	var city := app.document_state.city
	fade_edge = city.map_size
	fade_rotation = city.compass_rotation()
	sync_fade_clock()
	# Source publications and traffic repaints do not change world coordinates.
	# visual_revision also changes when decorative traffic switches at 25/50%.
	# It must not discard completed receivers. Foreground publications refresh
	# affected masks in place; replacement artwork still changes archive identity.
	var archive := app.static_render.original_archive_for_view(app.static_render.city_view_size())
	var revision := [city.document.get_instance_id(), city.map_size,
		app.static_render.city_view_size(), city.compass_rotation(), city.visible_altitude_levels,
		archive.get_instance_id() if archive != null else 0]
	if signature != revision:
		reset()
		signature = revision
	var changed := roads.sync_geometry(city)
	var shape := [app.view_state.surface_visibility.duplicate()]
	if roads.geometry_reset or geometry != shape:
		geometry = shape
		invalidate_all()
		bounds = Rect2i()
		if resident and not prepare_entire_city:
			# Large replacements can exceed the geometry tracker's local delta.
			# Only that reset needs another city-wide discovery pass.
			bounds = _city_bounds(city)
			_collect(city)
	elif not changed.is_empty():
		_update_tiles(city, changed)
	var next := Rect2i(map.visible_source_rect().grow(BUFFER_MARGIN))
	if prepare_entire_city:
		next = _city_bounds(city)
	if not bounds.encloses(next.grow(-BUFFER_MARGIN * 0.5)) or bounds.get_area() > next.get_area() * 2:
		bounds = next
		_collect(city)
	var built := 0
	var attempts := mini(BUILD_BUDGET, pending.size())
	var started := Time.get_ticks_usec()
	# Refresh in place: an old complete texture remains until its replacement is ready.
	while attempts > 0:
		var tile := pending[cursor]
		cursor += 1
		attempts -= 1
		if not _regions_ready(app, tile):
			pending.append(tile)
			continue
		queued.erase(tile)
		var occlusion := _occlusion_inputs(app, tile)
		if not cache.has(tile) or cache[tile].get("occlusion") != occlusion:
			_forget_helpers(tile)
			var entry := _build(app, tile)
			entry.occlusion = occlusion
			_store(tile, entry)
			# Finished textures own their output; release temporary masks.
			_forget_helpers(tile)
			built += 1
		dirty.erase(tile)
		if Time.get_ticks_usec() - started > budget_usec:
			break
	if cursor > 0:
		pending = pending.slice(cursor)
		cursor = 0
	if built > 0:
		_trim_cache()
		queue_redraw()
		fixtures.queue_redraw()
		_refresh_signals()
	var scale_value := map.camera._view_scale()
	position = map.camera._draw_offset(scale_value)
	scale = Vector2.ONE * scale_value
	(material as ShaderMaterial).set_shader_parameter("strength", strength)
	start_visible_fades(map.visible_source_rect())


func _city_bounds(city: CityState) -> Rect2i:
	return Rect2i(Vector2i.ZERO, CityIsometricRenderer.output_size_for_view(2, city.map_size)).grow(160)


func _update_tiles(city: CityState, changed: Dictionary[Vector2i, bool]) -> void:
	for tile in changed:
		if cache.has(tile):
			_mark_dirty(tile, true)
		var has_fixture := (city.index_of(tile.x, tile.y) >= 0 and CityLifePaths.ports(city, tile) != 0
			and city.land_altitude(tile.x, tile.y) < city.visible_altitude_levels and not sources(city, tile).is_empty())
		var in_view := has_fixture and bounds.has_point(Vector2i(CityLifePaths.point(city, tile, 0, 2, 0.5, false)))
		if in_view and not visible_keys.has(tile):
			visible_tiles.append(tile)
			visible_keys[tile] = true
		elif not in_view and visible_keys.has(tile):
			visible_tiles.erase(tile)
			visible_keys.erase(tile)
		if has_fixture and (resident or in_view):
			last_used[tile] = collection
			if not cache.has(tile) or dirty.has(tile):
				_enqueue(tile)
	queue_redraw()
	fixtures.queue_redraw()
	_refresh_signals()


func _collect(city: CityState) -> void:
	for tile in visible_tiles:
		if not cache.has(tile):
			last_used.erase(tile)
	visible_tiles.clear()
	visible_keys.clear()
	if not resident:
		pending.clear()
		queued.clear()
	cursor = 0
	var first := Vector2i(city.map_size, city.map_size)
	var last := Vector2i.ZERO
	for corner in [bounds.position, bounds.end, Vector2i(bounds.end.x, bounds.position.y), Vector2i(bounds.position.x, bounds.end.y)]:
		for altitude in [0, 31]:
			var difference: float = (corner.x - 48.0 - city.map_size * 16.0) / 16.0
			var total: float = (corner.y - 520.0 + altitude * 12.0) / 8.0
			var point := Vector2i(floori((total + difference) * 0.5), floori((total - difference) * 0.5))
			first = first.min(point - Vector2i(2, 2))
			last = last.max(point + Vector2i(2, 2))
	first = first.max(Vector2i.ZERO)
	last = last.min(Vector2i.ONE * (city.map_size - 1))
	var points: Dictionary[Vector2i, Vector2] = {}
	for index in CityLifePaths.candidate_indices(city, first, last):
		var tile := Vector2i(index / city.map_size, index % city.map_size)
		# Collect every fixture in this area at every zoom. The cache budget may
		# evict offscreen receivers, but must never change the street layout.
		if CityLifePaths.ports(city, tile) == 0 or city.land_altitude(tile.x, tile.y) >= city.visible_altitude_levels:
			continue
		var point := CityLifePaths.point(city, tile, 0, 2, 0.5, false)
		if bounds.has_point(Vector2i(point)) and not sources(city, tile).is_empty():
			visible_tiles.append(tile)
			visible_keys[tile] = true
			points[tile] = point
	collection += 1
	for tile in visible_tiles:
		last_used[tile] = collection
	_trim_cache()
	# New visible receivers take priority over the prefetch border.
	var center := Vector2(bounds.get_center())
	visible_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return points[a].distance_squared_to(center) < points[b].distance_squared_to(center))
	for tile in visible_tiles:
		if not cache.has(tile) or dirty.has(tile):
			_enqueue(tile)
	queue_redraw()
	fixtures.queue_redraw()
	_refresh_signals()


func _entry_textures(entry: Dictionary) -> Dictionary:
	var result := {}
	for texture: Texture2D in [entry.texture, entry.fixtures]:
		result[texture.get_instance_id()] = texture
	for signal_light: Dictionary in entry.signals:
		for texture: Texture2D in signal_light.lenses:
			result[texture.get_instance_id()] = texture
	return result


func _store(tile: Vector2i, entry: Dictionary) -> void:
	_release(tile)
	cache[tile] = entry
	if fades != null and fades.peek(tile, fade_edge, fade_rotation) == CityLightFade.UNSEEN:
		unseen[tile] = true
		fade_pending = true
	var textures := _entry_textures(entry)
	for id: int in textures:
		if texture_users.has(id):
			texture_users[id].count += 1
		else:
			var texture: Texture2D = textures[id]
			var bytes := texture.get_width() * texture.get_height() * 4
			texture_users[id] = {"count": 1, "bytes": bytes}
			texture_bytes += bytes


func _release(tile: Vector2i) -> void:
	unseen.erase(tile)
	if not cache.has(tile):
		return
	for id: int in _entry_textures(cache[tile]):
		if not texture_users.has(id):
			continue
		texture_users[id].count -= 1
		if texture_users[id].count == 0:
			texture_bytes -= int(texture_users[id].bytes)
			texture_users.erase(id)
	cache.erase(tile)


func _trim_cache() -> void:
	if resident:
		return
	if cache.size() <= MAX_CACHED and texture_bytes <= texture_budget:
		return
	# Repeated street patterns share textures. Count their bytes once, rather
	# than discarding thousands of cheap receivers at a fixed 4096-tile limit.
	var retained := cache.keys()
	retained.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(last_used.get(a, 0)) < int(last_used.get(b, 0)))
	for tile: Vector2i in retained:
		if cache.size() <= MAX_CACHED and texture_bytes <= texture_budget:
			break
		if visible_keys.has(tile):
			continue
		_release(tile)
		dirty.erase(tile)
		last_used.erase(tile)
		_forget_helpers(tile)


func _enqueue(tile: Vector2i) -> void:
	if (resident or visible_keys.has(tile)) and not queued.has(tile):
		pending.append(tile)
		queued[tile] = true


func _mark_dirty(tile: Vector2i, geometry_changed := false) -> void:
	if geometry_changed and cache.has(tile):
		cache[tile].erase("occlusion")
	dirty[tile] = true
	_enqueue(tile)


func invalidate_all() -> void:
	for tile in cache:
		_mark_dirty(tile, true)


func invalidate_regions(changes: Array[Rect2i]) -> void:
	if changes.is_empty():
		return
	for tile in cache:
		var receiver := Rect2i(cache[tile].origin, Vector2i(64, 64))
		for changed in changes:
			if receiver.intersects(changed):
				_mark_dirty(tile)
				break


func _forget_helpers(tile: Vector2i) -> void:
	for axis in 4:
		var key := Vector3i(tile.x, tile.y, axis)
		roads.roads.erase(key)
		masker._occluders.erase(key)
		masker._occluder_bounds.erase(key)


func _regions_ready(app: CityApplication, tile: Vector2i) -> bool:
	var regions := app.render_caches.region_cache
	if regions == null:
		return true
	var center := CityLifePaths.point(app.document_state.city, tile, 0, 2, 0.5, false)
	for key in regions._keys_for_bounds(Rect2i(Vector2i(center) - Vector2i(40, 40), Vector2i(80, 80))):
		if not regions.entries.has(key):
			return false
	return true


func _occlusion_inputs(app: CityApplication, tile: Vector2i) -> PackedInt64Array:
	# Region publications also happen after zoom/traffic repaints. Compare the
	# actual silhouettes before rebuilding masks, with exact values rather than
	# a hash. Cover every approach used by the shared foreground-mask helper.
	var city := app.document_state.city
	var area := Rect2i()
	for enter in 4:
		var center := CityLifePaths.point(city, tile, enter, (enter + 2) % 4, 0.5, false)
		var bounds_for_axis := Rect2i(Vector2i(center) - Vector2i(32, 28), Vector2i(64, 48))
		area = area.merge(bounds_for_axis) if area.has_area() else bounds_for_axis
	var regions := app.render_caches.region_cache
	var commands := (regions.occlusion_candidates(area, true) if regions != null
		else app.moving_sprites.static_occlusion_candidates(area))
	var result := PackedInt64Array()
	for command in commands:
		result.append_array(PackedInt64Array([command.sprite_id, int(command.flip), command.position.x,
			command.position.y, command.depth_order, command.train_foreground_reference_sprite_id,
			command.train_deck_thickness, command.train_deck_reference_sprite_id, int(command.train_foreground_requires_depth)]))
	return result


func sources(city: CityState, tile: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Stable placement, independent of both simulation and cosmetic RNGs.
	for fixture in CityNightFixtures.street_layout(city, tile, int(profiles.street.spacing)):
		var street: Dictionary = profiles.street.duplicate()
		street.enter = fixture.enter
		var center: Vector2 = fixture.get("center", Vector2.ZERO)
		street.offset = center + (Vector2(fixture.offset) - center) * 0.65
		street.position = Vector2(tile) + street.offset
		result.append(street)
	# Only short, street-facing approaches for the explicitly listed shops.
	# No guess at facade height and no illumination across unrelated buildings.
	for direction in 4:
		var neighbor: Vector2i = tile + CityLifePaths.DIRECTIONS[direction]
		if city.index_of(neighbor.x, neighbor.y) < 0:
			continue
		var id := str(city.building_id(neighbor.x, neighbor.y))
		if profiles.entrances.has(id) and city.land_altitude(tile.x, tile.y) == city.land_altitude(neighbor.x, neighbor.y):
			var entrance: Dictionary = profiles.entrances[id].duplicate()
			entrance.offset = Vector2(CityLifePaths.DIRECTIONS[direction]) * 0.32
			entrance.position = Vector2(tile) + entrance.offset
			result.append(entrance)
	return result


func _build(app: CityApplication, tile: Vector2i) -> Dictionary:
	var city := app.document_state.city
	var center := CityLifePaths.point(city, tile, 0, 2, 0.5, false)
	var origin := Vector2i(center) - Vector2i(32, 32)
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var parts := templates.receiver(city, tile, origin, sources(city, tile), roads)
	# Earlier approaches own overlapping pixels, unless their own deck is hidden.
	# Clip each approach before composition to preserve stacked road crossings.
	for index in range(parts.size() - 1, -1, -1):
		var part: Dictionary = parts[index]
		var visible := CityLifeCanvas.visible_sprite(part.image, origin, masker._candidates(app, tile, part.enter))
		image.blit_rect_mask(visible, visible, Rect2i(0, 0, 64, 64), Vector2i.ZERO)
	var result := CityNightFixtures.build(app, tile, origin,
		CityNightFixtures.street_layout(city, tile, int(profiles.street.spacing)), masker, templates.texture)
	result.merge({"texture": templates.texture(image), "origin": origin})
	return result


func _draw() -> void:
	for tile in visible_tiles:
		if cache.has(tile):
			draw_texture(cache[tile].texture, cache[tile].origin, _fade_color(tile))


func _draw_fixtures() -> void:
	for tile in visible_tiles:
		if not cache.has(tile):
			continue
		var entry: Dictionary = cache[tile]
		fixtures.draw_texture(entry.fixtures, entry.origin, _fade_color(tile))


func _refresh_signals() -> void:
	signal_tiles.clear()
	for tile in visible_tiles:
		if cache.has(tile) and not cache[tile].signals.is_empty():
			signal_tiles.append(tile)
	signals.queue_redraw()


func _draw_signals() -> void:
	for tile in signal_tiles:
		for signal_light: Dictionary in cache[tile].signals:
			var lens := CityNightFixtures.signal_lens(tile, signal_light.axis, clock)
			signals.draw_texture(signal_light.lenses[lens], signal_light.origin, _fade_color(tile))


func sync_fade_clock() -> void:
	for shader: ShaderMaterial in [material, fixtures.material]:
		shader.set_shader_parameter("fade_clock", fades.clock if fades != null else -1.0)
		shader.set_shader_parameter("fade_duration", CityLightFade.DURATION)


func _fade_color(tile: Vector2i) -> Color:
	# Commands retain their timestamps. Advancing the fade only updates two
	# uniforms, with no texture rebuild or per-frame redraw of every street.
	return Color(fades.peek(tile, fade_edge, fade_rotation), 1, 1, 1) if fades != null else Color.WHITE


func start_visible_fades(view: Rect2) -> void:
	# Hidden banks and the prefetch border must not consume a light's fade.
	# Only unseen entries need examination; stable frames never redraw lights.
	if fades == null or not is_visible_in_tree() or unseen.is_empty():
		return
	if not fade_pending and fade_view == view and fade_revision == fades.revision:
		return
	fade_view = view
	fade_pending = false
	var started := false
	for tile: Vector2i in unseen.keys():
		if fades.peek(tile, fade_edge, fade_rotation) != CityLightFade.UNSEEN:
			unseen.erase(tile)
			started = true
		elif Rect2(cache[tile].origin, Vector2(64, 64)).intersects(view):
			fades.birth(tile, fade_edge, fade_rotation)
			unseen.erase(tile)
			started = true
	if started:
		queue_redraw()
		fixtures.queue_redraw()
		signals.queue_redraw()
	fade_revision = fades.revision
