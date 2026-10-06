class_name CityNightGround
extends Node2D
## Cached, visible road receivers. Short entrance approaches never cross tiles
## other than the immediately adjacent street. No simulation state is written.

const SHADER := preload("res://src/view/environment/night_ground.gdshader")
const PROFILES := "res://src/view/environment/night_light_profiles.json"
const MAX_CACHED := 1024
const BUILD_BUDGET := 12
var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILES))
var roads := CityLifeLights.new()
var masker := CityLifeCanvas.new()
var cache: Dictionary[Vector2i, Dictionary] = {}
var visible_tiles: Array[Vector2i] = []
var signature: Array = []
var bounds := Rect2i()
var cursor := 0
var fixtures := Node2D.new()
var clock := 0.0


func _init() -> void:
	var shader := ShaderMaterial.new()
	shader.shader = SHADER
	material = shader
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(masker)
	masker.hide()
	fixtures.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(fixtures)
	fixtures.draw.connect(_draw_fixtures)


func reset() -> void:
	cache.clear()
	roads.roads.clear()
	masker._occluders.clear()
	visible_tiles.clear()
	signature.clear()
	bounds = Rect2i()
	cursor = 0
	queue_redraw()
	fixtures.queue_redraw()


func sync(app: CityApplication, strength: float, elapsed := 0.0) -> void:
	visible = strength > 0.001 and app.view_state.surface_visibility.networks and app.view_state.surface_visibility.buildings
	if not visible:
		return
	var previous_second := floori(clock)
	clock = fposmod(clock + maxf(elapsed, 0.0), 14.0)
	if floori(clock) != previous_second:
		fixtures.queue_redraw()
	fixtures.modulate.a = smoothstep(0.0, 0.25, strength)
	var map := app.map_view
	var city := app.document_state.city
	var revision := [city.document.get_instance_id(), app.static_render_state.epoch,
		map.city_source, city.chunk_revision("XBLD"), city.chunk_revision("ALTM"), city.chunk_revision("XTER"),
		app.static_render.city_view_size(), city.compass_rotation(), city.visible_altitude_levels,
		app.asset_state.large_sprites.visual_revision if app.asset_state.large_sprites != null else 0]
	if signature != revision:
		reset()
		signature = revision
	var next := Rect2i(map.visible_source_rect().grow(64))
	if not bounds.encloses(next.grow(-48)):
		bounds = next
		_collect(city)
	var built := 0
	while cursor < visible_tiles.size() and built < BUILD_BUDGET:
		var tile := visible_tiles[cursor]
		cursor += 1
		if not cache.has(tile):
			cache[tile] = _build(app, tile)
			built += 1
	if built > 0:
		queue_redraw()
		fixtures.queue_redraw()
	var scale_value := map.camera._view_scale()
	position = map.camera._draw_offset(scale_value)
	scale = Vector2.ONE * scale_value
	(material as ShaderMaterial).set_shader_parameter("strength", strength)


func _collect(city: CityState) -> void:
	visible_tiles.clear()
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
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var tile := Vector2i(x, y)
			if CityLifePaths.ports(city, tile) == 0 or city.land_altitude(x, y) >= city.visible_altitude_levels:
				continue
			var point := CityLifePaths.point(city, tile, 0, 2, 0.5, false)
			if bounds.has_point(Vector2i(point)) and not sources(city, tile).is_empty():
				visible_tiles.append(tile)
	if visible_tiles.size() > MAX_CACHED:
		var reduced: Array[Vector2i] = []
		for i in MAX_CACHED:
			reduced.append(visible_tiles[floori(float(i) * visible_tiles.size() / MAX_CACHED)])
		visible_tiles = reduced
	if cache.size() + visible_tiles.size() > MAX_CACHED:
		for tile: Vector2i in cache.keys():
			if not visible_tiles.has(tile):
				cache.erase(tile)
		roads.roads.clear()
		masker._occluders.clear()
	queue_redraw()
	fixtures.queue_redraw()


func sources(city: CityState, tile: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Stable placement, independent of both simulation and cosmetic RNGs.
	for fixture in CityNightFixtures.street_layout(city, tile, int(profiles.street.spacing)):
		var street: Dictionary = profiles.street.duplicate()
		street.position = Vector2(tile) + Vector2(fixture.offset) * 0.65
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
			entrance.position = Vector2(tile) + Vector2(CityLifePaths.DIRECTIONS[direction]) * 0.32
			result.append(entrance)
	return result


func _build(app: CityApplication, tile: Vector2i) -> Dictionary:
	var city := app.document_state.city
	var center := CityLifePaths.point(city, tile, 0, 2, 0.5, false)
	var origin := Vector2i(center) - Vector2i(32, 32)
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var lights := sources(city, tile)
	var seen := {}
	# Each approach/deck gets its own occlusion mask (including lower crossings).
	for enter in 4:
		if not CityLifePaths.ports(city, tile) & (1 << enter):
			continue
		var occluders := masker._candidates(app, tile, enter)
		for patch: Dictionary in roads._road_patches(city, tile, enter):
			for sample: Vector4 in patch.samples:
				var point := Vector2i(int(sample.x), int(sample.y))
				var local := point - origin
				if seen.has(point) or not Rect2i(0, 0, 64, 64).has_point(local) or CityLifeCanvas.hidden_at(point, occluders):
					continue
				seen[point] = true
				var color := Color(0, 0, 0, 1)
				for light in lights:
					var distance := Vector2(sample.z, sample.w).distance_to(light.position)
					var falloff := pow(maxf(0.0, 1.0 - distance / float(light.radius)), 1.6)
					color += Color(str(light.color)) * falloff * float(light.intensity)
				color.a = 1.0
				image.set_pixelv(local, color.clamp())
	var result := CityNightFixtures.build(app, tile, origin,
		CityNightFixtures.street_layout(city, tile, int(profiles.street.spacing)), masker)
	result.merge({"texture": ImageTexture.create_from_image(image), "origin": origin})
	return result


func _draw() -> void:
	for tile in visible_tiles:
		if cache.has(tile):
			draw_texture(cache[tile].texture, cache[tile].origin)


func _draw_fixtures() -> void:
	for tile in visible_tiles:
		if not cache.has(tile):
			continue
		var entry: Dictionary = cache[tile]
		fixtures.draw_texture(entry.fixtures, entry.origin)
		for signal_light: Dictionary in entry.signals:
			var lens := CityNightFixtures.signal_lens(tile, signal_light.axis, clock)
			fixtures.draw_texture(signal_light.lenses[lens], signal_light.origin)
