class_name CityLifeCanvas
extends Node2D
## One reusable viewport texture. Tiny sprites are masked by cached silhouettes.

@warning_ignore_start("integer_division")

const SHADER := preload("res://src/view/city_life/city_life.gdshader")
const MAX_TEXTURE_EDGE := 4096
var image: Image
var texture: ImageTexture
var source_bounds := Rect2i()
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
	var bounds := Rect2i(map.visible_source_rect()).grow(12)
	if not supports_view(map.visible_source_rect()):
		hide()
		return
	if image == null or source_bounds.size != bounds.size:
		image = Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
		texture = ImageTexture.create_from_image(image)
	source_bounds = bounds
	image.fill(Color.TRANSPARENT)
	var signature := [app.static_render_state.epoch, map.city_source, app.static_render.city_view_size()]
	if signature != _occlusion_signature or _occluders.size() > 4096:
		_occluders.clear()
		_occlusion_signature = signature
	figures.sort_custom(func(a: CityLifeController.Figure, b: CityLifeController.Figure) -> bool:
		return a.position.y < b.position.y)
	for figure: CityLifeController.Figure in figures:
		var sprite := sprites.sprite(figure.walking, figure.variant, figure.direction, int(figure.distance * 8.0) % 2, figure.vehicle_kind)
		var origin := Vector2i(figure.position.round()) - Vector2i(sprite.get_width() / 2, sprite.get_height() - 1)
		if not source_bounds.intersects(Rect2i(origin, sprite.get_size())):
			continue
		var candidates := _candidates(app, figure.tile, figure.enter)
		var opacity := clampf(minf(figure.age / 0.3, (figure.lifetime - figure.age) / 0.5), 0.0, 1.0)
		stamp(image, source_bounds.position, sprite, origin, candidates, opacity)
	texture.update(image)
	sync_view(app)
	show()
	queue_redraw()


static func supports_view(bounds: Rect2) -> bool:
	var extent := bounds.size.ceil() + Vector2(24, 24)
	return extent.x > 0.0 and extent.y > 0.0 and extent.x <= MAX_TEXTURE_EDGE and extent.y <= MAX_TEXTURE_EDGE


func sync_view(app: CityApplication) -> void:
	var view_scale := app.map_view.camera._view_scale()
	position = Vector2(source_bounds.position) * view_scale + app.map_view.camera._draw_offset(view_scale)
	scale = Vector2(view_scale, view_scale)
	app.map_view.layers._apply_environment(material as ShaderMaterial)


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


static func deck_foreground(source: Image, origin: Vector2i, surface: Vector2, slope: float) -> Image:
	var mask := source.duplicate() as Image
	for x in mask.get_width():
		var cutoff := surface.y + (origin.x + x - surface.x) * slope - 2.0
		for y in mask.get_height():
			if origin.y + y >= cutoff:
				mask.set_pixel(x, y, Color.TRANSPARENT)
	return mask


static func stamp(destination: Image, offset: Vector2i, sprite: Image, origin: Vector2i, occluders: Array, opacity: float = 1.0) -> void:
	for y in sprite.get_height():
		for x in sprite.get_width():
			var color := sprite.get_pixel(x, y)
			if color.a == 0.0:
				continue
			var point := origin + Vector2i(x, y)
			var local := point - offset
			if local.x < 0 or local.y < 0 or local.x >= destination.get_width() or local.y >= destination.get_height():
				continue
			var hidden := false
			for occluder: Dictionary in occluders:
				var mask: Image = occluder.image
				var sample: Vector2i = point - occluder.origin
				if sample.x >= 0 and sample.y >= 0 and sample.x < mask.get_width() and sample.y < mask.get_height() \
						and mask.get_pixel(sample.x, sample.y).a > 0.0:
					hidden = true
					break
			if not hidden:
				color.a *= opacity
				destination.set_pixelv(local, color)
