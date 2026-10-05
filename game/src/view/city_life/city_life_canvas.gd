class_name CityLifeCanvas
extends Node2D
## One reusable viewport texture. Tiny sprites are masked by cached silhouettes.

@warning_ignore_start("integer_division")

const SHADER := preload("res://src/view/city_life/city_life.gdshader")
const MAX_TEXTURE_EDGE := 4096
var image: Image
var texture: ImageTexture
var source_bounds := Rect2i()
var lights := CityLifeLights.new()
var emission: Image
var emission_texture: ImageTexture
var road_layer: Node2D
var road_material: ShaderMaterial
var _light_night := -1.0
var _light_quads: Dictionary[int, Sprite2D] = {}
var _light_occluders: Dictionary[Vector3i, Array] = {}
var _occluders: Dictionary[Vector3i, Array] = {}
var _occlusion_signature: Array = []


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	show_behind_parent = true
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	material = shader_material


func _draw() -> void:
	if texture != null:
		draw_texture(texture, Vector2.ZERO)


func render(app: CityApplication, figures: Array, sprites: CityLifeSprites) -> void:
	var map := app.map_view
	var bounds := Rect2i(map.visible_source_rect()).grow(32)
	if not supports_view(map.visible_source_rect()):
		hide()
		return
	if image == null or source_bounds.size != bounds.size:
		image = Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
		texture = ImageTexture.create_from_image(image)
		emission = Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
		emission_texture = ImageTexture.create_from_image(emission)
		(material as ShaderMaterial).set_shader_parameter("vehicle_emission", emission_texture)
		(material as ShaderMaterial).set_shader_parameter("vehicle_has_emission", true)
		if road_layer == null:
			road_layer = Node2D.new()
			road_layer.show_behind_parent = true
			road_material = ShaderMaterial.new()
			road_material.shader = preload("res://src/view/city_life/city_life_road_light.gdshader")
			add_child(road_layer)
	source_bounds = bounds
	image.fill(Color.TRANSPARENT)
	emission.fill(Color.TRANSPARENT)
	var signature := [app.static_render_state.epoch, map.city_source, app.static_render.city_view_size()]
	if signature != _occlusion_signature or _occluders.size() > 4096:
		_occluders.clear()
		_light_occluders.clear()
		lights.roads.clear()
		lights.surfaces.clear()
		_occlusion_signature = signature
	figures.sort_custom(func(a: CityLifeController.Figure, b: CityLifeController.Figure) -> bool:
		return a.position.y < b.position.y)
	var light_active := app.visual_environment.night > 0.0
	road_layer.visible = light_active
	var seen: Dictionary[int, bool] = {}
	if lights.surfaces.size() > 1024:
		lights.surfaces.clear()
	if light_active:
		for figure: CityLifeController.Figure in figures:
			if figure.walking:
				continue
			seen[figure.id] = true
			var quad: Sprite2D = _light_quads.get(figure.id)
			if quad == null:
				quad = Sprite2D.new()
				quad.centered = false
				# Ordinary materials also support the full figure budget on Compatibility GPUs.
				quad.material = road_material.duplicate()
				(quad.material as ShaderMaterial).set_shader_parameter("night", app.visual_environment.night)
				road_layer.add_child(quad)
				_light_quads[figure.id] = quad
			var surface := lights.surface(app.document_state.city, figure.tile, figure.enter, figure.direction,
				func(tile: Vector2i, enter: int) -> Array: return _light_candidates(app, tile, enter))
			quad.texture = surface.texture
			quad.position = Vector2(surface.origin - source_bounds.position)
			var light_material := quad.material as ShaderMaterial
			light_material.set_shader_parameter("vehicle_world", CityLifeLights.vehicle_world(app.document_state.city, figure))
			light_material.set_shader_parameter("forward", CityLifeLights.FORWARD[figure.direction])
			light_material.set_shader_parameter("front", float([3, 4, 5][figure.vehicle_kind]))
			light_material.set_shader_parameter("opacity", figure.opacity())
	for id in _light_quads.keys():
		if not seen.has(id):
			_light_quads[id].queue_free()
			_light_quads.erase(id)
	for figure: CityLifeController.Figure in figures:
		var sprite := sprites.sprite(figure.walking, figure.variant, figure.direction, int(figure.distance * 8.0) % 2, figure.vehicle_kind)
		var origin := Vector2i(figure.position.round()) - Vector2i(sprite.get_width() / 2, sprite.get_height() - 1)
		if not source_bounds.intersects(Rect2i(origin, sprite.get_size())):
			continue
		var candidates := _candidates(app, figure.tile, figure.enter)
		var opacity := figure.opacity()
		var mask: Image = lights.lamp_mask(sprite, figure.vehicle_kind, figure.direction) if not figure.walking else null
		stamp(image, source_bounds.position, sprite, origin, candidates, opacity, emission, mask)
	texture.update(image)
	emission_texture.update(emission)
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
	if road_layer != null and app.visual_environment.night != _light_night:
		_light_night = app.visual_environment.night
		for quad: Sprite2D in _light_quads.values():
			(quad.material as ShaderMaterial).set_shader_parameter("night", _light_night)


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
	for command in app.moving_sprites.static_occlusion_candidates(bounds):
		var command_tile := Vector2i(command.depth_order % city.map_size, 0)
		command_tile = Vector2i(int(command.depth_order / city.map_size) - command_tile.x, command_tile.x)
		var own := own_structure and (command_tile == tile or (id >= BuildingTileIds.HIGHWAY_SLOPE_1 \
			and command.sprite_id % 500 == id and CityLifePaths.section_origin(city, command_tile) == section))
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
					mask = deck_foreground(mask, origin, center, -0.5 if enter % 2 == 0 else 0.5)
			candidates.append({"origin": origin, "image": mask})
	_occluders[key] = candidates
	return candidates


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
		opacity: float = 1.0, lamp_destination: Image = null, lamps: Image = null) -> void:
	for y in sprite.get_height():
		for x in sprite.get_width():
			var color := sprite.get_pixel(x, y)
			if color.a == 0.0:
				continue
			var point := origin + Vector2i(x, y)
			var local := point - offset
			if local.x < 0 or local.y < 0 or local.x >= destination.get_width() or local.y >= destination.get_height():
				continue
			if not hidden_at(point, occluders):
				color.a *= opacity
				destination.set_pixelv(local, color)
				if lamp_destination != null:
					var lamp := lamps.get_pixel(x, y) if lamps != null else Color.TRANSPARENT
					lamp.a *= opacity
					lamp_destination.set_pixelv(local, lamp)


static func hidden_at(point: Vector2i, occluders: Array) -> bool:
	for occluder: Dictionary in occluders:
		var mask: Image = occluder.image
		var sample: Vector2i = point - occluder.origin
		if sample.x >= 0 and sample.y >= 0 and sample.x < mask.get_width() and sample.y < mask.get_height() \
				and mask.get_pixel(sample.x, sample.y).a > 0.0:
			return true
	return false
