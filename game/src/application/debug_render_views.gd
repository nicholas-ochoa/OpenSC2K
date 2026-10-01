class_name ApplicationDebugRenderViews
extends RefCounted
## Render debug views: region bounds and repaints, occlusion rectangles, sprite
## bounds and moving thing paths. The lists change after a pan, a zoom or a
## region publish, at most a few times a second. The overlay node draws each
## list in one call.

const RENDER_INTERVAL_MSEC := 150
const THING_INTERVAL_MSEC := 250
# the most sprite or occluder rectangles in one view
const MAX_OUTLINES := 30000
# the most things to draw in one refresh
const MAX_THINGS := 2000
# thing labels appear at this zoom and closer
const THING_LABEL_ZOOM := 1.0
const REGION_READY := Color(0.2, 0.9, 0.35, 0.9)
const REGION_STALE := Color(1.0, 0.8, 0.1, 0.9)
const REGION_BUILDING := Color(0.2, 0.8, 1.0, 0.9)
const REGION_MISSING := Color(1.0, 0.25, 0.25, 0.9)
const PREFETCH_ALPHA := 0.35
const OCCLUDER_COLOR := Color(1.0, 0.2, 0.8, 0.8)
const SPRITE_COLOR := Color(0.3, 0.95, 1.0, 0.55)
const MOVING_SPRITE_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const PATH_COLOR := Color(1.0, 0.6, 0.1, 0.9)
const THING_COLOR := Color(1.0, 0.95, 0.3, 0.95)
const THING_RADIUS := 3.0
const RENDER_SETS := ["regions", "occluders", "sprites", "moving"]

var app: CityApplication
var state: DebugViewState
# named lists of [point pairs, color]
var line_sets: Dictionary[String, Array] = {}
var thing_dots: Array = []
var thing_labels: Array = []
var outline_count := 0
var region_count := 0
var thing_count := 0
var last_render_usec := 0
var last_thing_usec := 0
var _render_due := 0
var _render_dirty := true
var _thing_due := 0


func _init(application: CityApplication, view_state: DebugViewState) -> void:
	app = application
	state = view_state


func mark_dirty() -> void:
	_render_dirty = true


func clear() -> void:
	line_sets.clear()
	thing_dots.clear()
	thing_labels.clear()
	_render_dirty = true

	if app.render_caches.region_cache != null:
		app.render_caches.region_cache.log_publishes = false
		app.render_caches.region_cache.published_log.clear()


# true when the lines or labels changed
func process(now: int) -> bool:
	var changed := _take_repaints()
	var cache := app.render_caches.region_cache

	if cache != null and not cache.published_log.is_empty():
		cache.published_log.clear()

	if (state.region_bounds or state.occluders or state.sprite_bounds) and _render_dirty and now >= _render_due:
		_render_due = now + RENDER_INTERVAL_MSEC
		_render_dirty = false
		var started := Time.get_ticks_usec()
		_build_render_lines()
		last_render_usec = Time.get_ticks_usec() - started
		changed = true
	elif not (state.region_bounds or state.occluders or state.sprite_bounds) and _has_any(RENDER_SETS):
		for key in RENDER_SETS:
			line_sets.erase(key)

		changed = true

	if state.thing_paths and now >= _thing_due:
		_thing_due = now + THING_INTERVAL_MSEC
		var started := Time.get_ticks_usec()
		_build_thing_paths()
		last_thing_usec = Time.get_ticks_usec() - started
		changed = true
	elif not state.thing_paths and (line_sets.has("paths") or not thing_dots.is_empty()):
		line_sets.erase("paths")
		thing_dots.clear()
		thing_labels.clear()
		changed = true

	return changed


func _has_any(keys: Array) -> bool:
	return keys.any(func(key: String) -> bool: return line_sets.has(key))


# region publishes become short highlights
func _take_repaints() -> bool:
	var cache := app.render_caches.region_cache

	if cache == null:
		return false

	cache.log_publishes = state.region_repaints

	if not state.region_repaints or cache.published_log.is_empty():
		return false

	var overlay := app.map_view.debug_view.overlay

	for rect in cache.published_log:
		overlay.add_flash(Rect2(rect))

	cache.published_log.clear()
	_render_dirty = true

	return true


func _build_render_lines() -> void:
	var cache := app.render_caches.region_cache

	for key in RENDER_SETS:
		line_sets.erase(key)

	outline_count = 0
	region_count = 0

	if state.sprite_bounds:
		_add_moving_sprite_bounds()

	if cache == null:
		return

	if state.region_bounds:
		_add_region_bounds(cache)

	if state.occluders or state.sprite_bounds:
		_add_draw_outlines(cache)


# one line list for each region state
func _add_region_bounds(cache: CityRegionCache) -> void:
	var building: Dictionary[Vector2i, bool] = {}

	for worker in cache.gpu_workers:
		for key in worker.keys:
			building[key] = true

	var by_color: Dictionary[Color, PackedVector2Array] = {}
	var edge := cache.region_edge * cache.divisor

	for key: Vector2i in cache.wanted_keys:
		var color := REGION_MISSING

		if building.has(key):
			color = REGION_BUILDING
		elif cache.entries.has(key):
			color = REGION_READY if int(cache.entries[key].generation) >= cache.generation else REGION_STALE

		if not cache.visible_keys.has(key):
			color.a = PREFETCH_ALPHA

		if not by_color.has(color):
			by_color[color] = PackedVector2Array()

		by_color[color].append_array(rect_segments(Rect2(Vector2(key * edge), Vector2(edge, edge)).grow(-1)))
		region_count += 1

	var sets := []

	for color in by_color:
		sets.append([by_color[color], color])

	line_sets["regions"] = sets


func _add_draw_outlines(cache: CityRegionCache) -> void:
	var visible := app.map_view.visible_source_rect()
	var bounds := Rect2i(Vector2i(visible.position.floor()), Vector2i(visible.size.ceil()))
	var occluders := PackedVector2Array()
	var sprites := PackedVector2Array()

	for key: Vector2i in cache.visible_keys:
		var entry := cache.entries.get(key) as CityRegionResult

		if entry == null or outline_count >= MAX_OUTLINES:
			continue

		var gpu := entry as CityGpuRegionResult

		if gpu != null and gpu.draws != null:
			if state.occluders:
				var found := gpu.draws.outline_segments(bounds, gpu.command_scale, true, MAX_OUTLINES - outline_count)
				occluders.append_array(found)
				outline_count += found.size() / 8

			if state.sprite_bounds:
				var found := gpu.draws.outline_segments(bounds, gpu.command_scale, false, MAX_OUTLINES - outline_count)
				sprites.append_array(found)
				outline_count += found.size() / 8
		elif state.occluders:
			for command in entry.occlusion_commands:
				var rect := Rect2(Vector2(command.position * cache.divisor), Vector2(command.size * cache.divisor))

				if rect.intersects(visible) and outline_count < MAX_OUTLINES:
					occluders.append_array(rect_segments(rect))
					outline_count += 1

	if state.sprite_bounds:
		line_sets["sprites"] = [[sprites, SPRITE_COLOR]]

	if state.occluders:
		line_sets["occluders"] = [[occluders, OCCLUDER_COLOR]]


func _add_moving_sprite_bounds() -> void:
	var points := PackedVector2Array()

	for sprite in app.map_view.dynamic_sprites:
		if sprite != null:
			points.append_array(rect_segments(Rect2(sprite.position, sprite.size)))

	line_sets["moving"] = [[points, MOVING_SPRITE_COLOR]]


# the things in and near the view, from one native scan of XTHG
func _build_thing_paths() -> void:
	var city := app.document_state.city
	var paths := PackedVector2Array()
	thing_dots.clear()
	thing_labels.clear()
	thing_count = 0
	var chunk := city.document.find_chunk("XTHG") if city != null else null

	if chunk == null:
		line_sets.erase("paths")

		return

	var labels := app.map_view.zoom_factor >= THING_LABEL_ZOOM
	var window := CityDebugTileLayer.visible_window(app.map_view.visible_tile_outline(), city.map_size)
	var rows := NativeDebugTiles.thing_rows(chunk.decoded_payload, city.map_size, window)
	var row_size := NativeDebugTiles.THING_ROW

	for at in range(0, mini(rows.size(), MAX_THINGS * row_size), row_size):
		var id := rows[at]
		var type := rows[at + 1]
		var tile := Vector2i(rows[at + 2], rows[at + 3])
		var target := Vector2i(rows[at + 4], rows[at + 5])
		var center := CityMapDebugView.tile_center(city, tile)
		thing_dots.append([center, THING_RADIUS, THING_COLOR])
		thing_count += 1

		if labels:
			thing_labels.append([center - Vector2(0, 10), "#%d %s" % [id, DebugObjectFields.type_name(type)], THING_COLOR])

		if _has_target(type) and target != tile and city.index_of(target.x, target.y) >= 0:
			var end := CityMapDebugView.tile_center(city, target)
			paths.append_array(PackedVector2Array([center, end]))
			paths.append_array(arrow_head(center, end))

	line_sets["paths"] = [[paths, PATH_COLOR]]


# aircraft, helicopters, ships and Maxis Man keep a target tile in dx and dy
static func _has_target(type: int) -> bool:
	return type in [1, 2, 3, 16]


static func rect_segments(rect: Rect2) -> PackedVector2Array:
	var a := rect.position
	var b := Vector2(rect.end.x, rect.position.y)
	var c := rect.end
	var d := Vector2(rect.position.x, rect.end.y)

	return PackedVector2Array([a, b, b, c, c, d, d, a])


static func arrow_head(from: Vector2, to: Vector2, length := 8.0) -> PackedVector2Array:
	var direction := (to - from).normalized()

	if direction == Vector2.ZERO:
		return PackedVector2Array()

	var left := to - direction.rotated(0.5) * length
	var right := to - direction.rotated(-0.5) * length

	return PackedVector2Array([to, left, to, right])


func metrics() -> Dictionary:
	return {"regions": region_count, "outlines": outline_count, "things": thing_count, "last_render_usec": last_render_usec,
		"last_thing_usec": last_thing_usec}
