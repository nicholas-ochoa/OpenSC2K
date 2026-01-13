class_name CityUndergroundView
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")

const TERRAIN_WIREFRAME_FIRST := 0x131
const SUBWAY_AND_PIPE_FIRST := 0x13e
const PIPED_TERRAIN := 0x15f
const DEEP_TUNNEL := 0x160
const WATERED_PIPE_OFFSET := 0x74
const WATERED_TERRAIN := 0x1d3
const WHITE_PALETTE_INDEX := 0xff


static func create_image(
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	view_size := Renderer.VIEW_LARGE,
	validate_required_assets := true,
	show_pipes := true,
	show_subways := true
) -> Dictionary:
	if city == null or not city.is_valid():
		return _failure("city is invalid")
	if palette == null or not palette.is_valid():
		return _failure("palette is invalid")
	if sprites == null or not sprites.is_valid():
		return _failure("sprite archive is invalid")
	var configuration := Renderer.view_configuration(view_size)
	if configuration.is_empty():
		return _failure("underground view size is invalid")
	if validate_required_assets:
		var asset_errors := validate_assets(city, sprites, view_size, show_pipes, show_subways)
		if not asset_errors.is_empty():
			return _failure(asset_errors[0])

	var output_size := Renderer.output_size_for_view(view_size)
	var output := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	output.fill(Color8(
		WHITE_PALETTE_INDEX,
		WHITE_PALETTE_INDEX,
		WHITE_PALETTE_INDEX,
		255,
	))
	var origin_x: int = (
		int(configuration.side_margin)
		+ CityState.MAP_SIZE * int(configuration.half_width)
	)
	var cache: Dictionary = {}
	for diagonal in CityState.MAP_SIZE * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y
			if x >= CityState.MAP_SIZE or y >= CityState.MAP_SIZE:
				continue
			_draw_tile(
				output, city, palette, sprites, cache, configuration, origin_x, x, y,
				show_pipes, show_subways
			)
	if palette.is_index_encoding:
		output.convert(Image.FORMAT_L8)
	return {"ok": true, "image": output, "error": ""}


static func validate_assets(
	city: CityState,
	sprites: Sc2SpriteArchive,
	view_size := Renderer.VIEW_LARGE,
	show_pipes := true,
	show_subways := true
) -> PackedStringArray:
	var errors := PackedStringArray()
	if city == null or not city.is_valid():
		errors.append("city is invalid")
		return errors
	if sprites == null or not sprites.is_valid():
		errors.append("sprite archive is invalid")
		return errors
	var configuration := Renderer.view_configuration(view_size)
	if configuration.is_empty():
		errors.append("underground view size is invalid")
		return errors
	var missing: Dictionary = {}
	for x in CityState.MAP_SIZE:
		for y in CityState.MAP_SIZE:
			for sprite_id in tile_sprite_ids(city, x, y, view_size, show_pipes, show_subways):
				if sprites.find_sprite(sprite_id) == null:
					missing[sprite_id] = true
			var tunnel_sprite := tunnel_sprite_id(city, x, y, view_size)
			if tunnel_sprite > 0 and sprites.find_sprite(tunnel_sprite) == null:
				missing[tunnel_sprite] = true
	var ids := missing.keys()
	ids.sort()
	for sprite_id in ids:
		errors.append("required underground sprite %d is missing" % sprite_id)
	return errors


static func tile_sprite_ids(
	city: CityState,
	x: int,
	y: int,
	view_size := Renderer.VIEW_LARGE,
	show_pipes := true,
	show_subways := true
) -> PackedInt32Array:
	var result := PackedInt32Array()
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return result
	var configuration := Renderer.view_configuration(view_size)
	if configuration.is_empty():
		return result
	var sprite_base := int(configuration.sprite_base)
	var underground := city.underground_id(x, y)
	if not show_subways:
		if underground == 0x1f:
			underground = 0x11
		elif underground == 0x20:
			underground = 0x10
		elif underground in range(1, 0x10) or underground == 0x23:
			underground = 0
	var is_pipe := (
		(underground >= 0x10 and underground <= 0x1e)
		or underground == 0x1f
		or underground == 0x20
	)
	if is_pipe:
		if not show_pipes:
			if underground == 0x1f:
				result.append(sprite_base + SUBWAY_AND_PIPE_FIRST + 0x01)
			elif underground == 0x20:
				result.append(sprite_base + SUBWAY_AND_PIPE_FIRST + 0x02)
			else:
				result.append(
					sprite_base + terrain_wireframe_offset(city.terrain_id(x, y))
				)
			return result
		if city.is_piped(x, y) and city.is_watered(x, y):
			underground += WATERED_PIPE_OFFSET
		result.append(sprite_base + SUBWAY_AND_PIPE_FIRST + underground)
		return result

	if underground == 0:
		if not show_pipes or not city.is_piped(x, y):
			result.append(
				sprite_base + terrain_wireframe_offset(city.terrain_id(x, y))
			)
		elif city.is_watered(x, y):
			result.append(sprite_base + WATERED_TERRAIN)
		else:
			result.append(sprite_base + PIPED_TERRAIN)
		return result

	result.append(sprite_base + SUBWAY_AND_PIPE_FIRST + underground)
	if show_pipes and city.is_piped(x, y):
		result.append(
			sprite_base + (WATERED_TERRAIN if city.is_watered(x, y) else PIPED_TERRAIN)
		)
	return result


static func terrain_wireframe_offset(terrain: int) -> int:
	if terrain >= 0x00 and terrain <= 0x0e:
		return TERRAIN_WIREFRAME_FIRST + mini(terrain, 0x0d)
	if terrain >= 0x10 and terrain <= 0x1e:
		return TERRAIN_WIREFRAME_FIRST + mini(terrain - 0x10, 0x0d)
	if terrain >= 0x20 and terrain <= 0x2e:
		return TERRAIN_WIREFRAME_FIRST + mini(terrain - 0x20, 0x0d)
	return TERRAIN_WIREFRAME_FIRST


static func tunnel_sprite_id(
	city: CityState, x: int, y: int, view_size := Renderer.VIEW_LARGE
) -> int:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return -1
	var configuration := Renderer.view_configuration(view_size)
	if configuration.is_empty():
		return -1
	var levels := city.tunnel_levels(x, y) & 0x1f
	if levels == 0:
		return -1
	if levels == 1:
		return int(configuration.sprite_base) + 0x3e + city.terrain_id(x, y)
	return int(configuration.sprite_base) + DEEP_TUNNEL


static func visual_signature(city: CityState, view_size: int, show_pipes := true, show_subways := true) -> Array:
	if city == null or not city.is_valid():
		return []
	return [
		"underground",
		city.visible_altitude_levels,
		view_size,
		show_pipes,
		show_subways,
		city.compass_rotation(),
		hash(city.altitude_words),
		hash(city.terrain),
		hash(city.underground),
		city.masked_tile_flag_signature(0x30),
	]


static func _draw_tile(
	output: Image,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	configuration: Dictionary,
	origin_x: int,
	x: int,
	y: int,
	show_pipes: bool,
	show_subways: bool
) -> void:
	if not city.tile_is_visible(x, y):
		return
	var screen_x := origin_x + (x - y) * int(configuration.half_width)
	var base_y := (
		int(configuration.top_margin)
		+ (x + y) * int(configuration.half_height)
		- city.land_altitude(x, y) * int(configuration.altitude_step)
	)
	var terrain_image := _sprite_image(
		sprites,
		palette,
		cache,
		int(configuration.sprite_base) + terrain_wireframe_offset(city.terrain_id(x, y)),
	)
	var terrain_top := base_y + int(configuration.tile_height) - terrain_image.get_height()

	var tunnel_sprite := tunnel_sprite_id(city, x, y, int(configuration.view_size))
	if tunnel_sprite > 0:
		var tunnel_image := _sprite_image(sprites, palette, cache, tunnel_sprite)
		var tunnel_y := base_y + int(configuration.tile_height) - tunnel_image.get_height()
		var levels := city.tunnel_levels(x, y) & 0x1f
		if levels > 1:
			tunnel_y += (levels - 1) * int(configuration.altitude_step)
		_blend(output, tunnel_image, Vector2i(screen_x, tunnel_y))

	for sprite_id in tile_sprite_ids(
		city, x, y, int(configuration.view_size), show_pipes, show_subways
	):
		var image := _sprite_image(sprites, palette, cache, sprite_id)
		_blend(output, image, Vector2i(screen_x, terrain_top))


static func _sprite_image(
	sprites: Sc2SpriteArchive,
	palette: Sc2Palette,
	cache: Dictionary,
	sprite_id: int
) -> Image:
	if cache.has(sprite_id):
		return cache[sprite_id]
	var entry := sprites.find_sprite(sprite_id)
	var rendered := entry.create_image(palette)
	var image: Image = rendered.image
	cache[sprite_id] = image
	return image


static func _blend(output: Image, sprite: Image, position: Vector2i) -> void:
	output.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), position)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "image": null, "error": message}
