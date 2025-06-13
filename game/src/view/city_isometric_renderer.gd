class_name CityIsometricRenderer
extends RefCounted

const TILE_WIDTH := 32
# 17 pixels of art on a 16-pixel diamond, keep the shared edge
const TILE_HEIGHT := 17
const HALF_WIDTH := 16
const HALF_HEIGHT := 8
const ALTITUDE_STEP := 12
const TOP_MARGIN := 512
const SIDE_MARGIN := 32


static func create_image(
	city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive
) -> Dictionary:
	if city == null or not city.is_valid():
		return _failure("city is invalid")
	if palette == null or not palette.is_valid():
		return _failure("palette is invalid")
	if sprites == null or not sprites.is_valid():
		return _failure("large sprite archive is invalid")

	var asset_errors := validate_assets(city, sprites)
	if not asset_errors.is_empty():
		return _failure(asset_errors[0])

	var image_width := CityState.MAP_SIZE * TILE_WIDTH + SIDE_MARGIN * 2
	var image_height := CityState.MAP_SIZE * TILE_HEIGHT + TOP_MARGIN + 256
	var output := Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	output.fill(Color("18242c"))
	var origin_x := SIDE_MARGIN + CityState.MAP_SIZE * HALF_WIDTH
	var cache: Dictionary = {}

	for diagonal in CityState.MAP_SIZE * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y
			if x >= CityState.MAP_SIZE or y >= CityState.MAP_SIZE:
				continue
			_draw_tile(output, city, palette, sprites, cache, origin_x, x, y)

	return {"ok": true, "image": output, "error": ""}


static func validate_assets(city: CityState, sprites: Sc2SpriteArchive) -> PackedStringArray:
	var errors := PackedStringArray()
	var missing: Dictionary = {}
	for x in CityState.MAP_SIZE:
		for y in CityState.MAP_SIZE:
			var terrain_sprite := terrain_sprite_id(city.terrain_id(x, y), city.is_water(x, y))
			if sprites.find_sprite(terrain_sprite) == null:
				missing[terrain_sprite] = true
			var zone := city.zone_id(x, y)
			if zone > 0 and city.building_id(x, y) == 0:
				var zone_sprite := 1290 + zone
				if sprites.find_sprite(zone_sprite) == null:
					missing[zone_sprite] = true
			var building := city.building_id(x, y)
			if building > 0 and _should_draw_building(city, x, y, building):
				var building_sprite := 1000 + building
				if sprites.find_sprite(building_sprite) == null:
					missing[building_sprite] = true
	var ids := missing.keys()
	ids.sort()
	for sprite_id in ids:
		errors.append("required large sprite %d is missing" % sprite_id)
	return errors


static func terrain_sprite_id(terrain: int, water_flag: bool) -> int:
	var tile_id := 256
	if terrain >= 0x00 and terrain <= 0x0e:
		tile_id = 256 + terrain
	elif terrain >= 0x20 and terrain <= 0x2e:
		tile_id = 256 + terrain - 18
	elif terrain >= 0x30 and terrain <= 0x3e:
		tile_id = 256 + terrain - 34
	elif terrain >= 0x40 and terrain <= 0x45:
		tile_id = 256 + terrain - 35
	elif water_flag or (terrain >= 0x10 and terrain <= 0x1e):
		tile_id = 270
	return 1000 + tile_id


static func tile_polygon(city: CityState, x: int, y: int) -> PackedVector2Array:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return PackedVector2Array()
	var altitude := city.land_altitude(x, y)
	if city.terrain_id(x, y) >= 0x10:
		altitude = city.water_altitude(x, y)
	var origin_x := SIDE_MARGIN + CityState.MAP_SIZE * HALF_WIDTH
	var left := Vector2(
		origin_x + (x - y) * HALF_WIDTH,
		TOP_MARGIN + (x + y) * HALF_HEIGHT - altitude * ALTITUDE_STEP
	)
	return PackedVector2Array([
		left + Vector2(HALF_WIDTH, 0),
		left + Vector2(TILE_WIDTH, HALF_HEIGHT),
		left + Vector2(HALF_WIDTH, TILE_HEIGHT - 1),
		left + Vector2(0, HALF_HEIGHT),
	])


static func screen_to_tile(city: CityState, point: Vector2) -> Vector2i:
	if city == null or not city.is_valid():
		return Vector2i(-1, -1)
	var result := Vector2i(-1, -1)
	for diagonal in CityState.MAP_SIZE * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y
			if x >= CityState.MAP_SIZE or y >= CityState.MAP_SIZE:
				continue
			var polygon := tile_polygon(city, x, y)
			if Geometry2D.is_point_in_polygon(point, polygon):
				result = Vector2i(x, y)
	return result


static func _draw_tile(
	output: Image,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	origin_x: int,
	x: int,
	y: int
) -> void:
	var terrain_id := city.terrain_id(x, y)
	var building_id := city.building_id(x, y)
	var terrain_altitude := city.land_altitude(x, y)
	if terrain_id >= 0x10:
		terrain_altitude = city.water_altitude(x, y)

	var screen_x := origin_x + (x - y) * HALF_WIDTH
	var base_y := TOP_MARGIN + (x + y) * HALF_HEIGHT - terrain_altitude * ALTITUDE_STEP

	if building_id < 108:
		var terrain := _sprite_image(sprites, palette, cache, terrain_sprite_id(terrain_id, city.is_water(x, y)), false)
		_blend_on_base(output, terrain, screen_x, base_y)

	var zone := city.zone_id(x, y)
	if zone > 0 and building_id == 0:
		var zone_image := _sprite_image(sprites, palette, cache, 1290 + zone, false)
		_blend_on_base(output, zone_image, screen_x, base_y)

	if building_id == 0 or not _should_draw_building(city, x, y, building_id):
		return
	var flip := city.is_flipped(x, y)
	if (city.compass_rotation() == 1 or city.compass_rotation() == 3) and not _fixed_rotation_tile(building_id):
		flip = not flip
	var building := _sprite_image(sprites, palette, cache, 1000 + building_id, flip)
	_blend_on_base(output, building, screen_x, base_y)


# four occupied corners, one sprite, compass picks the winner
static func _should_draw_building(city: CityState, x: int, y: int, building_id: int) -> bool:
	if building_id <= 0x60:
		return true
	var anchor_masks := [0x80, 0x10, 0x20, 0x40]
	return (city.building_corners(x, y) & anchor_masks[city.compass_rotation()]) != 0


static func _fixed_rotation_tile(building_id: int) -> bool:
	return (building_id >= 0x49 and building_id <= 0x50) or (
		building_id >= 0x61 and building_id <= 0x69
	)


static func _sprite_image(
	sprites: Sc2SpriteArchive,
	palette: Sc2Palette,
	cache: Dictionary,
	sprite_id: int,
	flip: bool
) -> Image:
	var key := "%d:%d" % [sprite_id, int(flip)]
	if cache.has(key):
		return cache[key]
	var entry := sprites.find_sprite(sprite_id)
	var rendered := entry.create_image(palette)
	var image: Image = rendered.image
	if flip:
		image.flip_x()
	cache[key] = image
	return image


static func _blend_on_base(output: Image, sprite: Image, x: int, base_y: int) -> void:
	var destination := Vector2i(x, base_y + TILE_HEIGHT - sprite.get_height())
	output.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), destination)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
