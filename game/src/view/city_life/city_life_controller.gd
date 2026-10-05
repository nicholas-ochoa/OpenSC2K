class_name CityLifeController
extends RefCounted
## Cosmetic figures read completed city data. Their time and RNG stay local.

const MAX_FIGURES := 600
const UPDATE_SECONDS := 0.08
var app: CityApplication
var random := RandomNumberGenerator.new()
var figures: Array[Figure] = []
var sprites := CityLifeSprites.new()
var canvas: CityLifeCanvas
var tiles: Array[Vector2i] = []
var _city_id := 0
var _geometry_signature: Array = []
var _activity_signature: Array = []
var _viewport := Rect2i()
var _elapsed := 0.0
var _spawn_elapsed := 0.0
var _serial := 0
var _render_elapsed := 1.0
var _buckets: Dictionary[Vector2i, Array] = {}


func _init(application: CityApplication) -> void:
	app = application
	random.seed = 0x5343324b


func process(delta: float) -> void:
	var map := app.map_view
	if map == null:
		return
	var city := app.document_state.city
	var options := app.preferences.visual_enhancements
	var active := city != null and map.city_source != null and app.view_state.overlay_mode == CityViewMode.Mode.CITY \
		and not app.tool_state.landscape_editor and bool(app.view_state.surface_visibility.networks) and map.zoom_factor >= 0.5
	_sync_traffic(active and bool(options.life_cars_enabled))
	if not active or (not options.life_cars_enabled and not options.life_people_enabled):
		if canvas != null:
			canvas.hide()
		return
	if canvas == null:
		canvas = CityLifeCanvas.new()
		canvas.name = "CityLife"
		map.add_child(canvas)
	if city.document.get_instance_id() != _city_id:
		_city_id = city.document.get_instance_id()
		figures.clear()
		_geometry_signature.clear()
		_serial = 0
		random.seed = 0x5343324b
	var geometry := [city.chunk_revision("XBLD"), city.chunk_revision("ALTM"), city.chunk_revision("XTER"),
		city.compass_rotation(), city.visible_altitude_levels]
	var viewport := Rect2i(map.visible_source_rect().grow(96))
	if geometry != _geometry_signature or not _viewport.encloses(viewport):
		var changed_geometry := geometry != _geometry_signature
		_geometry_signature = geometry
		_viewport = viewport.grow(96)
		_collect_tiles(city)
		if changed_geometry:
			# Geometry edits and rotations invalidate lane positions, not the city.
			figures.clear()
		_activity_signature.clear()
	var activity := [city.chunk_revision("XPOP"), city.chunk_revision("XTRF"), options.life_cars_enabled,
		options.life_people_enabled, options.life_car_amount, options.life_people_amount, app.view_state.show_vehicles]
	if activity != _activity_signature:
		_activity_signature = activity
		_spawn_elapsed = 1.0
	figures = figures.filter(func(f: Figure) -> bool:
		return (options.life_people_enabled if f.walking else options.life_cars_enabled and app.view_state.show_vehicles))
	var elapsed := maxf(delta, 0.0)
	var speed := app.simulation_state.speed_controller.speed if app.simulation_state.speed_controller != null else 1
	if options.pause_freezes and (speed == 1 or app.frame._simulation_suspended()):
		elapsed = 0.0
	if options.speed_link and speed > 1:
		elapsed *= VisualEnhancementOptions.speed_factor(speed)
	_elapsed += elapsed
	_spawn_elapsed += elapsed
	if _spawn_elapsed >= 0.8:
		_spawn_elapsed = 0.0
		_spawn(city, options)
	if _elapsed >= UPDATE_SECONDS:
		# Catch up in bounded steps so a slow frame cannot jump across junctions.
		var remaining := minf(_elapsed, 0.5)
		while remaining > 0.0:
			var step := minf(remaining, UPDATE_SECONDS)
			_advance(city, step)
			remaining -= step
		_elapsed = 0.0
	_render_elapsed += maxf(delta, 0.0)
	if _render_elapsed >= UPDATE_SECONDS or canvas.texture == null:
		_render_elapsed = 0.0
		canvas.render(app, figures, sprites)
	else:
		canvas.sync_view(app)


func _sync_traffic(enhanced: bool) -> void:
	var changed := false
	for archive: Sc2SpriteArchive in [app.asset_state.large_sprites, app.asset_state.small_medium_sprites]:
		if archive != null and archive.visual_city_life_traffic != enhanced:
			archive.visual_city_life_traffic = enhanced
			archive.visual_revision += 1
			changed = true
	if changed and app.document_state.city != null:
		app.map_render.close_region_cache()
		app.static_render.invalidate_rendered_city()
		app.map_render.refresh_map()


func _collect_tiles(city: CityState) -> void:
	tiles.clear()
	var first := Vector2i(city.map_size, city.map_size)
	var last := Vector2i.ZERO
	for corner in [_viewport.position, _viewport.position + Vector2i(_viewport.size.x, 0),
		_viewport.end, _viewport.position + Vector2i(0, _viewport.size.y)]:
		for altitude in [0, 31]:
			var difference: float = (corner.x - 32 - city.map_size * 16 - 16) / 16.0
			var total: float = (corner.y - 512 - 8 + altitude * 12) / 8.0
			var point := Vector2i(floori((total + difference) * 0.5), floori((total - difference) * 0.5))
			first = first.min(point - Vector2i(2, 2))
			last = last.max(point + Vector2i(2, 2))
	first = first.max(Vector2i.ZERO)
	last = last.min(Vector2i(city.map_size - 1, city.map_size - 1))
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var tile := Vector2i(x, y)
			if CityLifePaths.ports(city, tile) == 0 or city.land_altitude(x, y) >= city.visible_altitude_levels:
				continue
			if _viewport.has_point(Vector2i(CityLifePaths.point(city, tile, 0, 2, 0.5, false))):
				tiles.append(tile)
	figures = figures.filter(func(f: Figure) -> bool: return _viewport.has_point(Vector2i(f.position)))


func _spawn(city: CityState, options: Dictionary) -> void:
	_rebuild_buckets()
	var counts: Dictionary[String, int] = {}
	for figure in figures:
		var key := "%d:%d:%d" % [figure.tile.x, figure.tile.y, int(figure.walking)]
		counts[key] = counts.get(key, 0) + 1
	if tiles.is_empty():
		return
	var start := random.randi_range(0, tiles.size() - 1)
	for index in tiles.size():
		if figures.size() >= MAX_FIGURES:
			break
		var tile := tiles[(start + index) % tiles.size()]
		for walking in [false, true]:
			if (walking and not options.life_people_enabled) or (not walking and (not options.life_cars_enabled or not app.view_state.show_vehicles)):
				continue
			if walking and not CityLifePaths.walkable(city, tile):
				continue
			var strength: float = options.life_people_amount if walking else options.life_car_amount
			var expected := CityLifePaths.target(CityLifePaths.density(city, tile, walking), strength, walking)
			var key := "%d:%d:%d" % [tile.x, tile.y, int(walking)]
			var count: int = counts.get(key, 0)
			if count >= ceili(expected) or random.randf() >= clampf(expected - count, 0.0, 1.0) * 0.35:
				continue
			var entries: Array[int] = []
			for direction in 4:
				if CityLifePaths.connected(city, tile, direction, walking):
					entries.append(direction)
			if entries.is_empty():
				continue
			var figure := Figure.new()
			figure.walking = walking
			figure.tile = tile
			figure.enter = entries[random.randi_range(0, entries.size() - 1)]
			figure.exit = _exit(city, figure)
			if figure.exit < 0:
				continue
			figure.progress = random.randf_range(0.0, 0.8)
			figure.speed = random.randf_range(0.17, 0.25) if walking else random.randf_range(0.7, 1.0)
			figure.variant = random.randi_range(0, 17)
			figure.lifetime = random.randf_range(25.0, 55.0)
			figure.position = CityLifePaths.point(city, tile, figure.enter, figure.exit, figure.progress, walking)
			figure.direction = figure.exit
			if _crowded(figure, figure.position):
				continue
			_serial += 1
			figure.id = _serial
			figures.append(figure)
			_bucket_add(figure)
			counts[key] = count + 1


func _exit(city: CityState, figure: Figure) -> int:
	var choices: Array[int] = []
	for direction in 4:
		if direction != figure.enter and CityLifePaths.connected(city, figure.tile, direction, figure.walking):
			choices.append(direction)
	if choices.is_empty():
		return -1
	var straight := (figure.enter + 2) % 4
	if straight in choices and random.randf() < 0.7:
		return straight
	return choices[random.randi_range(0, choices.size() - 1)]


func _advance(city: CityState, elapsed: float) -> void:
	_rebuild_buckets()
	for figure in figures:
		figure.age += elapsed
		if figure.age >= figure.lifetime or figure.retiring:
			continue
		if figure.wait > 0.0:
			figure.wait = maxf(0.0, figure.wait - elapsed)
			continue
		var progress := minf(figure.progress + elapsed * figure.speed, 1.0)
		var position := CityLifePaths.point(city, figure.tile, figure.enter, figure.exit, progress, figure.walking)
		if not figure.walking and _crowded(figure, position, false):
			continue
		figure.distance += progress - figure.progress
		figure.progress = progress
		var old_bucket := _bucket(figure.position)
		figure.position = position
		if old_bucket != _bucket(position):
			_buckets[old_bucket].erase(figure)
			_bucket_add(figure)
		figure.direction = figure.enter + 2 if progress < 0.5 else figure.exit
		figure.direction %= 4
		if progress < 1.0:
			continue
		var next: Vector2i = figure.tile + CityLifePaths.DIRECTIONS[figure.exit]
		if not CityLifePaths.connected(city, figure.tile, figure.exit, figure.walking) or not _viewport.has_point(Vector2i(position)):
			figure.lifetime = figure.age + 0.5
			figure.retiring = true
			continue
		figure.enter = (figure.exit + 2) % 4
		figure.tile = next
		figure.exit = _exit(city, figure)
		figure.progress = 0.0
		if figure.exit < 0:
			figure.lifetime = figure.age + 0.5
			figure.retiring = true
		elif figure.walking and random.randf() < 0.08:
			figure.wait = random.randf_range(0.4, 1.6)
	figures = figures.filter(func(f: Figure) -> bool: return f.age < f.lifetime)


func _crowded(figure: Figure, position: Vector2, spawning: bool = true) -> bool:
	var center := _bucket(position)
	for x in range(-1, 2):
		for y in range(-1, 2):
			for other: Figure in _buckets.get(center + Vector2i(x, y), []):
				if other == figure or other.walking != figure.walking or other.age >= other.lifetime:
					continue
				var separation := other.position - position
				if not spawning:
					# Opposite lanes pass independently; following cars yield ahead.
					var direction := (figure.enter + 2) % 4 if figure.progress < 0.5 else figure.exit
					var other_direction := (other.enter + 2) % 4 if other.progress < 0.5 else other.exit
					if (direction + 2) % 4 == other_direction:
						continue
					var forward: Vector2 = [Vector2(16, -8), Vector2(16, 8), Vector2(-16, 8), Vector2(-16, -8)][direction]
					if direction == other_direction and separation.dot(forward) <= 0.0:
						continue
					if direction != other_direction and figure.id < other.id:
						continue
				if separation.length_squared() < (9.0 if spawning or figure.walking else 25.0):
					return true
	return false


static func _bucket(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / 16.0), floori(position.y / 16.0))


func _bucket_add(figure: Figure) -> void:
	var key := _bucket(figure.position)
	if not _buckets.has(key):
		_buckets[key] = []
	_buckets[key].append(figure)


func _rebuild_buckets() -> void:
	_buckets.clear()
	for figure in figures:
		_bucket_add(figure)


class Figure extends RefCounted:
	var id := 0
	var walking := false
	var tile := Vector2i.ZERO
	var enter := 0
	var exit := 0
	var direction := 0
	var progress := 0.0
	var distance := 0.0
	var speed := 1.0
	var variant := 0
	var position := Vector2.ZERO
	var age := 0.0
	var lifetime := 40.0
	var wait := 0.0
	var retiring := false
