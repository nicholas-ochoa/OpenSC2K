class_name CityLifeController
extends RefCounted
## Cosmetic figures read completed city data. Their time and RNG stay local.

@warning_ignore_start("integer_division")

const MAX_FIGURES := 600
const UPDATE_SECONDS := 0.08
const FADE_IN_SECONDS := 0.65
const FADE_OUT_SECONDS := 0.9
const BUS_RADIUS := 8
const TRUCK_SHARE := 0.06
const BUS_SHARE := 0.03
const EMPTY_BUCKET: Array = []
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
var _bus_signature: Array = []
var _bus_tiles: Dictionary[Vector2i, bool] = {}
var _path_signature: Array = []
var _paths: Dictionary[Vector3i, CityLifePaths.Segment] = {}
var _tile_cache := CityLifeTiles.new()


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
		and not app.tool_state.landscape_editor and bool(app.view_state.surface_visibility.networks) and map.zoom_factor >= 0.5 \
		and CityLifeCanvas.supports_view(map.visible_source_rect())
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
		var changed_view := _geometry_signature.is_empty() or geometry.slice(3) != _geometry_signature.slice(3)
		_geometry_signature = geometry
		_viewport = viewport.grow(96)
		_collect_tiles(city)
		if changed_view:
			# Rotations and altitude cutaways replace the coordinate space.
			figures.clear()
		elif changed_geometry:
			_revalidate_lanes(city)
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
	var fade_elapsed := elapsed
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
	_fade(fade_elapsed)
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
		if app.visual_preparation.ready or app.visual_preparation.busy:
			app.map_render.refresh_map(false)
			return
		app.map_render.close_region_cache()
		app.static_render.invalidate_rendered_city()
		app.map_render.refresh_map()


func _collect_tiles(city: CityState) -> void:
	tiles.assign(_tile_cache.collect(city, _viewport))
	figures = figures.filter(func(f: Figure) -> bool: return _viewport.has_point(Vector2i(f.position)))


func _spawn(city: CityState, options: Dictionary) -> void:
	_refresh_bus_area(city)
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
			if not walking:
				figure.vehicle_kind = _vehicle_kind(tile)
			figure.enter = entries[random.randi_range(0, entries.size() - 1)]
			figure.exit = _exit(city, figure)
			if figure.exit < 0:
				continue
			figure.progress = random.randf_range(0.0, 0.8)
			figure.speed = random.randf_range(0.17, 0.25) if walking else random.randf_range(0.7, 1.0)
			figure.variant = random.randi_range(0, 17)
			figure.lifetime = random.randf_range(25.0, 55.0)
			figure.position = CityLifePaths.point(city, tile, figure.enter, figure.exit, figure.progress, walking)
			figure.diagonal = CityLifePaths.diagonal(city, tile)
			figure.direction = figure.heading()
			if _crowded(figure, figure.position):
				continue
			_serial += 1
			figure.id = _serial
			figures.append(figure)
			_bucket_add(figure)
			counts[key] = count + 1


func _revalidate_lanes(city: CityState) -> void:
	# Simulation updates anywhere in the city must not reset all visible traffic.
	for figure in figures:
		if figure.retiring:
			continue
		var ports := CityLifePaths.ports(city, figure.tile)
		if not (ports & (1 << figure.enter)) or not (ports & (1 << figure.exit)) \
				or not CityLifePaths.can_turn(city, figure.tile, figure.enter, figure.exit) \
				or (figure.walking and not CityLifePaths.walkable(city, figure.tile)):
			figure.retiring = true
		elif not figure.position.is_equal_approx(CityLifePaths.point(city, figure.tile, figure.enter,
				figure.exit, figure.progress, figure.walking)):
			figure.retiring = true


func _fade(elapsed: float) -> void:
	# Wall-clock fades remain readable at African Swallow; pause still freezes them.
	for figure in figures:
		var duration := FADE_OUT_SECONDS if figure.retiring else FADE_IN_SECONDS
		figure.visibility = move_toward(figure.visibility, 0.0 if figure.retiring else 1.0, elapsed / duration)
	figures = figures.filter(func(f: Figure) -> bool: return not f.retiring or f.visibility > 0.0)


func _exit(city: CityState, figure: Figure) -> int:
	var choices: Array[int] = []
	for direction in 4:
		if direction != figure.enter and CityLifePaths.can_turn(city, figure.tile, figure.enter, direction) \
				and CityLifePaths.connected(city, figure.tile, direction, figure.walking):
			if figure.vehicle_kind == CityLifeSprites.Vehicle.BUS and not _bus_tiles.has(figure.tile + CityLifePaths.DIRECTIONS[direction]):
				continue
			choices.append(direction)
	if choices.is_empty():
		if city.building_id(figure.tile.x, figure.tile.y) in [BuildingTileIds.TUNNEL_ENTRANCE_1, BuildingTileIds.TUNNEL_ENTRANCE_2]:
			# Finish the visible lane inside the portal, then retire; do not simulate a tunnel route.
			return (figure.enter + 2) % 4
		return -1
	var straight := (figure.enter + 2) % 4
	if straight in choices and random.randf() < 0.7:
		return straight
	return choices[random.randi_range(0, choices.size() - 1)]


func _refresh_bus_area(city: CityState) -> void:
	var signature := [city.document.get_instance_id(), city.chunk_revision("XBLD"), city.compass_rotation()]
	if signature == _bus_signature:
		return
	_bus_signature = signature
	_bus_tiles.clear()
	# Station proximity is a display rule, independent of simulated bus service.
	for index in city.building_indices(PackedInt32Array([BuildingTileIds.BUS_DEPOT])):
		var depot := Vector2i(index / city.map_size, index % city.map_size)
		for dx in range(-BUS_RADIUS, BUS_RADIUS + 1):
			for dy in range(-BUS_RADIUS, BUS_RADIUS + 1):
				var tile := depot + Vector2i(dx, dy)
				if dx * dx + dy * dy <= BUS_RADIUS * BUS_RADIUS and CityLifePaths.ports(city, tile) != 0:
					_bus_tiles[tile] = true


func _vehicle_kind(tile: Vector2i) -> int:
	var roll := random.randf()
	if roll < TRUCK_SHARE:
		return CityLifeSprites.Vehicle.TRUCK
	if roll < TRUCK_SHARE + BUS_SHARE and _bus_tiles.has(tile):
		return CityLifeSprites.Vehicle.BUS
	return CityLifeSprites.Vehicle.CAR


func _advance(city: CityState, elapsed: float) -> void:
	var path_signature := [city.mirror_signature(["ALTM", "XBLD", "XTER", "XZON", "XBIT"]), city.compass_rotation()]
	if path_signature != _path_signature or _paths.size() > 4096:
		_paths.clear()
		_path_signature = path_signature
	_rebuild_buckets()
	for figure in figures:
		figure.age += elapsed
		if figure.age >= figure.lifetime:
			figure.retiring = true
		if figure.retiring:
			continue
		if figure.wait > 0.0:
			figure.wait = maxf(0.0, figure.wait - elapsed)
			continue
		var progress := minf(figure.progress + elapsed * figure.speed, 1.0)
		var key := Vector3i(figure.tile.x, figure.tile.y, figure.enter * 8 + figure.exit * 2 + int(figure.walking))
		var path: CityLifePaths.Segment = _paths.get(key)
		if path == null:
			path = CityLifePaths.Segment.new(city, figure.tile, figure.enter, figure.exit, figure.walking)
			_paths[key] = path
		var position := path.point(progress)
		if not figure.walking and _crowded(figure, position, false):
			continue
		figure.distance += progress - figure.progress
		figure.progress = progress
		var old_bucket := _bucket(figure.position)
		figure.position = position
		if old_bucket != _bucket(position):
			_buckets[old_bucket].erase(figure)
			_bucket_add(figure)
		figure.diagonal = CityLifePaths.diagonal(city, figure.tile)
		figure.direction = figure.heading()
		if progress < 1.0:
			continue
		var next: Vector2i = figure.tile + CityLifePaths.DIRECTIONS[figure.exit]
		if not CityLifePaths.connected(city, figure.tile, figure.exit, figure.walking) or not _viewport.has_point(Vector2i(position)):
			figure.retiring = true
			continue
		figure.enter = (figure.exit + 2) % 4
		figure.tile = next
		figure.exit = _exit(city, figure)
		figure.progress = 0.0
		figure.diagonal = CityLifePaths.diagonal(city, figure.tile)
		if figure.exit >= 0:
			figure.direction = figure.heading()
		if figure.exit < 0:
			figure.retiring = true
		elif figure.walking and random.randf() < 0.08:
			figure.wait = random.randf_range(0.4, 1.6)


func _crowded(figure: Figure, position: Vector2, spawning: bool = true) -> bool:
	var center := _bucket(position)
	var direction := figure.heading()
	var world := CityLifePaths.forward(direction)
	var forward := Vector2((world.x - world.y) * 16, (world.x + world.y) * 8)
	for x in range(-1, 2):
		for y in range(-1, 2):
			for other: Figure in _buckets.get(center + Vector2i(x, y), EMPTY_BUCKET):
				if other == figure or other.walking != figure.walking or other.age >= other.lifetime:
					continue
				var separation := other.position - position
				if not spawning:
					# Opposite lanes pass independently; following cars yield ahead.
					var other_direction := other.heading()
					if CityLifePaths.opposite(direction) == other_direction:
						continue
					if direction == other_direction and separation.dot(forward) <= 0.0:
						continue
					if direction != other_direction and figure.id < other.id:
						continue
				var spacing := 3.0 if spawning or figure.walking else 5.0
				if not figure.walking:
					spacing += figure.extra_spacing() + other.extra_spacing()
				if separation.length_squared() < spacing * spacing:
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
	var vehicle_kind := CityLifeSprites.Vehicle.CAR
	var tile := Vector2i.ZERO
	var enter := 0
	var exit := 0
	var direction := 0
	var diagonal := false
	var progress := 0.0
	var distance := 0.0
	var speed := 1.0
	var variant := 0
	var position := Vector2.ZERO
	var age := 0.0
	var lifetime := 40.0
	var wait := 0.0
	var retiring := false
	var visibility := 0.0


	func heading() -> int:
		return CityLifePaths.heading(enter, exit, progress, diagonal)


	func opacity() -> float:
		return smoothstep(0.0, 1.0, visibility)


	func extra_spacing() -> float:
		return 1.5 if vehicle_kind == CityLifeSprites.Vehicle.BUS else (1.0 if vehicle_kind == CityLifeSprites.Vehicle.TRUCK else 0.0)
