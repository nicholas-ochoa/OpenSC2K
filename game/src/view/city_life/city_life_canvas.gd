class_name CityLifeCanvas
extends Node2D
## Sparse artwork atlas. Tiny sprites are masked by cached silhouettes.

@warning_ignore_start("integer_division")

const SHADER := preload("res://src/view/city_life/city_life.gdshader")
const MAX_TEXTURE_EDGE := 4096
var atlas := CityLifeAtlas.new()
var image: Image:
	get: return atlas.image
var texture: ImageTexture:
	get: return atlas.texture
var source_bounds := Rect2i()
var lights := CityLifeLights.new()
var emission: Image:
	get: return atlas.emission
var emission_texture: ImageTexture:
	get: return atlas.emission_texture
var road_layer: Node2D
var _light_night := -1.0
var _light_occluders: Dictionary[Vector3i, Array] = {}
var _occluders: Dictionary[Vector3i, Array] = {}
var _occluder_bounds: Dictionary[Vector3i, Rect2i] = {}
var _occlusion_signature: Array = []
var _visible_regions: Array[Vector2i] = []
var _emission_active := false
var include_cached_regions := false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	show_behind_parent = true
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	material = shader_material


func _draw() -> void:
	if texture != null:
		for index in atlas.destinations.size():
			draw_texture_rect_region(texture, atlas.destinations[index], atlas.sources[index])


func render(app: CityApplication, figures: Array, sprites: CityLifeSprites) -> void:
	var map := app.map_view
	var bounds := Rect2i(map.visible_source_rect()).grow(32)
	if not supports_view(map.visible_source_rect()):
		hide()
		return
	var light_active := app.visual_environment.night > 0.0 and VisualEnhancementOptions.detail_lights_visible(app.preferences.visual_enhancements, map.zoom_factor)
	if road_layer == null:
		road_layer = CityLifeHeadlights.new()
		road_layer.show_behind_parent = true
		add_child(road_layer)
	if light_active != _emission_active:
		_emission_active = light_active
		(material as ShaderMaterial).set_shader_parameter("vehicle_has_emission", light_active)
	source_bounds = bounds
	var city := app.document_state.city
	if light_active:
		lights.sync_geometry(city)
	if lights.roads.size() > 4096:
		lights.roads.clear()
		lights.clear_surfaces()
	# Region publications also change while panning an unchanged city. Their
	# affected silhouettes are invalidated separately by the map renderer.
	var regions := app.render_caches.region_cache
	var source: RefCounted = regions if regions != null else map.city_source
	# Traffic revisions do not change silhouettes. Region publications report
	# the changed bounds; only a replacement layout needs a complete reset.
	var layout: Variant = regions._layout_generation if regions != null else app.render_caches.static_visual_signature
	var signature := [app.document_state.city.document.get_instance_id(), app.static_render_state.epoch,
		source, app.static_render.city_view_size(), layout]
	if signature != _occlusion_signature or _occluders.size() > 4096:
		_occluders.clear()
		_occluder_bounds.clear()
		_light_occluders.clear()
		lights.clear_surfaces()
		_occlusion_signature = signature
	_sync_visible_regions(app.render_caches.region_cache)
	figures.sort_custom(func(a: CityLifeController.Figure, b: CityLifeController.Figure) -> bool:
		return a.position.y < b.position.y)
	road_layer.visible = light_active
	if light_active:
		(road_layer as CityLifeHeadlights).render(city, figures, lights, source_bounds.position,
			func(tile: Vector2i, enter: int) -> Array: return _light_candidates(app, tile, enter))
	var entries: Array[Dictionary] = []
	for figure: CityLifeController.Figure in figures:
		var sprite := sprites.sprite(figure.walking, figure.variant, figure.direction, int(figure.distance * 8.0) % 2, figure.vehicle_kind)
		var origin := Vector2i(figure.position.round()) - Vector2i(sprite.get_width() / 2, sprite.get_height() - 1)
		if not source_bounds.intersects(Rect2i(origin, sprite.get_size())):
			continue
		var candidates := _candidates(app, figure.tile, figure.enter)
		var opacity := figure.opacity()
		var mask: Image = lights.lamp_mask(sprite, figure.vehicle_kind, figure.direction) if light_active and not figure.walking else null
		entries.append({"sprite": sprite, "origin": origin, "occluders": candidates, "opacity": opacity, "lamps": mask})
	atlas.compose(bounds, entries, light_active)
	if light_active:
		(material as ShaderMaterial).set_shader_parameter("vehicle_emission", emission_texture)
	sync_view(app)
	show()
	queue_redraw()


static func supports_view(bounds: Rect2) -> bool:
	var extent := bounds.size.ceil() + Vector2(64, 64)
	return extent.x > 0.0 and extent.y > 0.0 and extent.x <= MAX_TEXTURE_EDGE and extent.y <= MAX_TEXTURE_EDGE


func sync_view(app: CityApplication) -> void:
	var view_scale := app.map_view.camera._view_scale()
	position = Vector2(source_bounds.position) * view_scale + app.map_view.camera._draw_offset(view_scale)
	scale = Vector2(view_scale, view_scale)
	app.map_view.layers._apply_environment(material as ShaderMaterial)
	var allowed := VisualEnhancementOptions.detail_lights_visible(app.preferences.visual_enhancements, app.map_view.zoom_factor)
	(material as ShaderMaterial).set_shader_parameter("vehicle_has_emission", allowed and _emission_active)
	if road_layer != null:
		road_layer.visible = allowed and app.visual_environment.night > 0.0
	if road_layer != null and (app.visual_environment.night if allowed else 0.0) != _light_night:
		_light_night = app.visual_environment.night if allowed else 0.0
		(road_layer as CityLifeHeadlights).set_night(_light_night)


func _candidates(app: CityApplication, tile: Vector2i, enter: int = 0) -> Array:
	var city := app.document_state.city
	var key := Vector3i(tile.x, tile.y, enter % 2)
	if _occluders.has(key):
		return _occluders[key]
	var center := CityLifePaths.point(city, tile, enter, (enter + 2) % 4, 0.5, false)
	var bounds := Rect2i(Vector2i(center) - Vector2i(32, 28), Vector2i(64, 48))
	var view := app.static_render.city_view_size()
	var archive := app.static_render.sprite_archive_for_view(view)
	var divisor := IsometricGeometry.view_configuration(view).divisor
	var depth := (tile.x + tile.y) * city.map_size + tile.y
	var id := city.building_id(tile.x, tile.y)
	var tunnel := id in [BuildingTileIds.TUNNEL_ENTRANCE_1, BuildingTileIds.TUNNEL_ENTRANCE_2]
	var own_structure := tunnel or (id >= BuildingTileIds.SUSPENSION_BRIDGE_1 and id <= BuildingTileIds.RAISING_BRIDGE_CLOSED) \
		or (id >= BuildingTileIds.HIGHWAY_STRAIGHT_1 and id <= BuildingTileIds.HIGHWAY_POWER_CROSSING_2) \
		or (id >= BuildingTileIds.HIGHWAY_SLOPE_1 and id <= BuildingTileIds.REINFORCED_HIGHWAY_BRIDGE)
	var section := CityLifePaths.section_origin(city, tile)
	var lower_crossing := id in [BuildingTileIds.HIGHWAY_ROAD_CROSSING_1, BuildingTileIds.HIGHWAY_ROAD_CROSSING_2] \
		and CityLifePaths.edge_height(city, tile, enter) < city.land_altitude(tile.x, tile.y) + 1.0
	var candidates: Array = []
	var commands := app.moving_sprites.static_occlusion_candidates(bounds)
	if include_cached_regions and app.render_caches.region_cache != null:
		commands = app.render_caches.region_cache.occlusion_candidates(bounds, true)
	for command in commands:
		var command_tile := Vector2i(command.depth_order % city.map_size, 0)
		command_tile = Vector2i(int(command.depth_order / city.map_size) - command_tile.x, command_tile.x)
		var own := own_structure and (command_tile == tile or (id >= BuildingTileIds.HIGHWAY_SLOPE_1 \
			and command.sprite_id % 500 == id and CityLifePaths.section_origin(city, command_tile) == section))
		# A diagonal highway is an open deck on pillars. Its multi-tile sprite
		# can sort after the car's supporting tile, but remains beneath it.
		if own and CityLifePaths.diagonal(city, tile):
			continue
		if command.depth_order <= depth and not own:
			continue
		var resource := app.moving_sprites.dynamic_sprite_resource(archive, command.sprite_id, command.flip, divisor)
		if resource != null:
			var origin := Vector2i(command.position) * divisor
			var mask: Image = resource.image
			if own:
				if lower_crossing:
					mask = app.moving_sprites._dynamic_train_foreground_image(archive, command, divisor, mask)
				elif not tunnel:
					# The deck is beneath the car; its towers and rails remain foreground.
					var forward := Vector2(CityLifePaths.DIRECTIONS[enter])
					var opposite := (enter + 2) % 4
					var a := CityLifeLights._project(city, tile, forward * 0.5, CityLifePaths.edge_height(city, tile, enter))
					var b := CityLifeLights._project(city, tile, -forward * 0.5, CityLifePaths.edge_height(city, tile, opposite))
					mask = deck_foreground(mask, origin, (a + b) * 0.5, (b.y - a.y) / (b.x - a.x))
			candidates.append({"origin": origin, "image": mask})
	_occluder_bounds[key] = bounds
	_occluders[key] = merged_occluders(candidates)
	return _occluders[key]


func _sync_visible_regions(cache: CityRegionCache) -> void:
	if cache == null:
		_visible_regions.clear()
		return
	# Queries include visible regions only. Publications report arriving regions;
	# departing regions must also release their cached silhouettes.
	var departed: Array[Rect2i] = []
	for key in _visible_regions:
		if not cache.visible_keys.has(key):
			departed.append(Rect2i(key * cache.region_edge * cache.divisor,
				Vector2i.ONE * cache.region_edge * cache.divisor))
	invalidate_occlusion(departed)
	_visible_regions.assign(cache.visible)


func invalidate_occlusion(changes: Array[Rect2i]) -> void:
	if changes.is_empty() or _occluder_bounds.is_empty():
		return
	var invalidated := {}
	for key in _occluder_bounds:
		for changed in changes:
			if _occluder_bounds[key].intersects(changed):
				invalidated[key] = true
				break
	for key in invalidated:
		_occluders.erase(key)
		_occluder_bounds.erase(key)
		_light_occluders.erase(key)
		lights.visible_roads.erase(key)
		lights.visible_roads.erase(key + Vector3i(0, 0, 2))
	for key in lights.surfaces.keys():
		for dependency in lights.surfaces[key].occlusion_keys:
			if invalidated.has(dependency):
				lights.surfaces.erase(key)
				break


static func merged_occluders(candidates: Array) -> Array:
	if candidates.size() <= 1:
		return candidates
	# Keep the complete queried silhouettes, including pixels outside the query
	# rectangle. Cars on slopes and long buses can reach beyond that rectangle.
	var bounds := Rect2i(candidates[0].origin, candidates[0].image.get_size())
	for candidate: Dictionary in candidates:
		bounds = bounds.merge(Rect2i(candidate.origin, candidate.image.get_size()))
	var mask := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	for candidate: Dictionary in candidates:
		mask.blend_rect(candidate.image, Rect2i(Vector2i.ZERO, candidate.image.get_size()), candidate.origin - bounds.position)
	return [{"origin": bounds.position, "image": mask}]


func _light_candidates(app: CityApplication, tile: Vector2i, enter: int) -> Array:
	var key := Vector3i(tile.x, tile.y, enter % 2)
	if _light_occluders.has(key):
		return _light_occluders[key]
	var center := CityLifePaths.point(app.document_state.city, tile, enter, (enter + 2) % 4, 0.5, false)
	var bounds := Rect2i(Vector2i(center) - Vector2i(32, 32), Vector2i(64, 64))
	var mask := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for candidate: Dictionary in _candidates(app, tile, enter):
		var part := Rect2i(candidate.origin, candidate.image.get_size()).intersection(bounds)
		if part.has_area():
			mask.blend_rect(candidate.image, Rect2i(part.position - candidate.origin, part.size), part.position - bounds.position)
	var candidates: Array = [{"origin": bounds.position, "image": mask}]
	_light_occluders[key] = candidates
	return candidates


static func deck_foreground(source: Image, origin: Vector2i, surface: Vector2, slope: float) -> Image:
	var mask := source.duplicate() as Image
	for x in mask.get_width():
		var cutoff := surface.y + (origin.x + x - surface.x) * slope - 2.0
		for y in mask.get_height():
			if origin.y + y >= cutoff:
				mask.set_pixel(x, y, Color.TRANSPARENT)
	return mask


static func stamp(destination: Image, offset: Vector2i, sprite: Image, origin: Vector2i, occluders: Array,
		opacity: float = 1.0, lamp_destination: Image = null, lamps: Image = null, clip := Rect2i()) -> void:
	if not clip.has_area():
		clip = Rect2i(Vector2i.ZERO, destination.get_size())
	var area := Rect2i(origin - offset, sprite.get_size()).intersection(clip)
	if not area.has_area():
		return
	if opacity == 1.0:
		# Native image blits preserve replacement order and alpha without a
		# GDScript callback for every opaque sprite pixel. Fades keep their exact
		# per-pixel alpha rounding below.
		var visible := visible_sprite(sprite, origin, occluders)
		var rect := Rect2i(area.position - origin + offset, area.size)
		destination.blit_rect_mask(sprite, visible, rect, area.position)
		if lamp_destination != null:
			if lamps == null:
				lamps = Image.create(sprite.get_width(), sprite.get_height(), false, Image.FORMAT_RGBA8)
				lamps.fill(Color.TRANSPARENT)
			lamp_destination.blit_rect_mask(lamps, visible, rect, area.position)
		return
	for y in sprite.get_height():
		for x in sprite.get_width():
			var color := sprite.get_pixel(x, y)
			if color.a == 0.0:
				continue
			var point := origin + Vector2i(x, y)
			var local := point - offset
			if not clip.has_point(local):
				continue
			if not hidden_at(point, occluders):
				color.a *= opacity
				destination.set_pixelv(local, color)
				if lamp_destination != null:
					var lamp := lamps.get_pixel(x, y) if lamps != null else Color.TRANSPARENT
					lamp.a *= opacity
					lamp_destination.set_pixelv(local, lamp)


static func visible_sprite(sprite: Image, origin: Vector2i, occluders: Array) -> Image:
	var visible := sprite
	var bounds := Rect2i(origin, sprite.get_size())
	for occluder: Dictionary in occluders:
		var overlap := bounds.intersection(Rect2i(occluder.origin, occluder.image.get_size()))
		if not overlap.has_area():
			continue
		if visible == sprite:
			visible = sprite.duplicate()
		var mask: Image = occluder.image.get_region(Rect2i(overlap.position - occluder.origin, overlap.size))
		var clear := Image.create(overlap.size.x, overlap.size.y, false, sprite.get_format())
		visible.blit_rect_mask(clear, mask, Rect2i(Vector2i.ZERO, overlap.size), overlap.position - origin)
	return visible


static func hidden_at(point: Vector2i, occluders: Array) -> bool:
	for occluder: Dictionary in occluders:
		var mask: Image = occluder.image
		var sample: Vector2i = point - occluder.origin
		if sample.x >= 0 and sample.y >= 0 and sample.x < mask.get_width() and sample.y < mask.get_height() \
				and mask.get_pixel(sample.x, sample.y).a > 0.0:
			return true
	return false
