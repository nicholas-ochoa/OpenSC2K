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
const DISPATCH_SPRITES := {7: 1381, 8: 1382, 14: 1383}
const THING_SPRITES := [
	0, 1359, 1364, 1369, 1390, 1490, 1387, 1382, 1383,
	1380, 1374, 1374, 1374, 1374, 1384, 1497, 1495,
]
const SHIP_DIRECTION_POSITION := [1, 2, 3, 4, 3, 2, 1, 0]
const SHIP_DIRECTION_FLIP := [false, false, false, false, true, true, true, false]
const THING_DIRECTION_POSITION := [0, 1, 1, 0]
const THING_DIRECTION_FLIP := [false, false, true, true]
const TRAIN_TILE_VARIANT := [
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 50, 50, 50, 50, 50, 10,
	11, 12, 13, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
]
const TRAIN_TRANSITION_VARIANT := [0, 17, 1, 16, 0, 17, 1, 16]
const TRAIN_SPRITE_POSITION := [
	0, 0, 3, 3, 4, 4, 2, 1, 2, 1, 3, 3, 4, 4, 0, 0, 2, 1,
]
const TRAIN_SPRITE_FLIP := [
	false, true, true, false, false, true, false, false, false,
	false, true, false, false, true, false, true, false, false,
]
const TRAIN_SCREEN_X := [0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0]
const TRAIN_SCREEN_Y := [0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 8, 8, 6, 6, 0, 0, 0, 6]
const MONSTER_UPPER_FIRST_X := [-15, -3]
const MONSTER_UPPER_SECOND_X := [-24, 14]
const MONSTER_UPPER_FIRST_Y := [6, 52]
const MONSTER_UPPER_SECOND_Y := [43, 33]
const MONSTER_LOWER_FIRST_X := [-15, 2]
const MONSTER_LOWER_SECOND_X := [-20, 18]
const MONSTER_LOWER_FIRST_Y := [6, 32]
const MONSTER_LOWER_SECOND_Y := [49, 46]


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
			var dispatch_sprite := dispatch_sprite_id(city, x, y)
			if dispatch_sprite > 0 and sprites.find_sprite(dispatch_sprite) == null:
				missing[dispatch_sprite] = true
			var moving_visual := moving_thing_visual(city, x, y)
			if not moving_visual.is_empty():
				if moving_visual.get("monster", false):
					for layer in moving_visual.layers:
						if sprites.find_sprite(layer.sprite_id) == null:
							missing[layer.sprite_id] = true
				elif sprites.find_sprite(moving_visual.sprite_id) == null:
					missing[moving_visual.sprite_id] = true
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


static func bridge_effect_position(
	city: CityState, effect: Dictionary, sprite_height: int
) -> Vector2i:
	if city == null or not city.is_valid():
		return Vector2i(-1, -1)
	var point: Vector2i = effect.get("point", Vector2i(-1, -1))
	if city.index_of(point.x, point.y) < 0 or sprite_height < 0:
		return Vector2i(-1, -1)
	var offset: Vector2i = effect.get("screen_offset", Vector2i.ZERO)
	return Vector2i(
		SIDE_MARGIN + CityState.MAP_SIZE * HALF_WIDTH
			+ (point.x - point.y) * HALF_WIDTH + offset.x,
		TOP_MARGIN + (point.x + point.y) * HALF_HEIGHT
			- city.water_altitude(point.x, point.y) * ALTITUDE_STEP
			- sprite_height + offset.y
	)


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

	if building_id > 0 and _should_draw_building(city, x, y, building_id):
		var flip := city.is_flipped(x, y)
		if (city.compass_rotation() == 1 or city.compass_rotation() == 3) and not _fixed_rotation_tile(building_id):
			flip = not flip
		var building := _sprite_image(sprites, palette, cache, 1000 + building_id, flip)
		_blend_on_base(output, building, screen_x, base_y)
	var dispatch_sprite := dispatch_sprite_id(city, x, y)
	if dispatch_sprite > 0:
		var dispatch_image := _sprite_image(sprites, palette, cache, dispatch_sprite, false)
		_blend_on_base(output, dispatch_image, screen_x, base_y)
	var moving_visual := moving_thing_visual(city, x, y)
	if not moving_visual.is_empty():
		_draw_moving_thing(output, city, palette, sprites, cache, moving_visual)


static func dispatch_sprite_id(city: CityState, x: int, y: int) -> int:
	var overlay := city.text_overlay_id(x, y)
	if overlay < 202 or overlay > 240:
		return 0
	var thing := city.thing(overlay - 201)
	if thing.is_empty() or thing.x != x or thing.y != y:
		return 0
	return int(DISPATCH_SPRITES.get(thing.type, 0))


static func moving_thing_visual(city: CityState, x: int, y: int) -> Dictionary:
	var overlay := city.text_overlay_id(x, y)
	if overlay < 201 or overlay > 240:
		return {}
	var record := overlay - 201
	var thing := city.thing(record)
	if thing.is_empty():
		return {}
	var type := int(thing.type)
	if (thing.x != x or thing.y != y) and type != 10 and type != 11:
		return {}
	var sprite: Dictionary
	if type == 5:
		var layers := monster_layers(city, x, y, thing, record)
		if layers.is_empty():
			return {}
		sprite = {
			"sprite_id": layers[0].sprite_id,
			"flip": layers[0].flip,
			"monster": true,
			"layers": layers,
		}
	elif type == 10 or type == 11:
		sprite = train_sprite(city, x, y, thing)
	elif type == 15:
		sprite = tornado_sprite(city, x, y, thing, record)
	else:
		sprite = moving_thing_sprite(thing)
	if sprite.is_empty():
		return {}
	return {
		"sprite_id": sprite.sprite_id,
		"flip": sprite.flip,
		"record": record,
		"type": thing.type,
		"x": x,
		"y": y,
		"z": thing.z,
		"px": thing.px,
		"py": thing.py,
		"train": sprite.get("train", false),
		"screen_x": sprite.get("screen_x", 0),
		"screen_y": sprite.get("screen_y", 0),
		"elevation": sprite.get("elevation", 0),
		"tornado": sprite.get("tornado", false),
		"monster": sprite.get("monster", false),
		"layers": sprite.get("layers", []),
	}


static func moving_thing_sprite(thing: Dictionary) -> Dictionary:
	if thing.is_empty():
		return {}
	var type := int(thing.get("type", 0))
	var direction := int(thing.get("direction", 0))
	var state := int(thing.get("state", 0))
	if type < 1 or type >= THING_SPRITES.size():
		return {}
	var sprite_id: int = THING_SPRITES[type]
	var flip := false
	match type:
		1, 2, 3:
			if direction < 0 or direction >= SHIP_DIRECTION_POSITION.size():
				return {}
			sprite_id += SHIP_DIRECTION_POSITION[direction]
			flip = SHIP_DIRECTION_FLIP[direction]
		4:
			if direction < 0 or direction >= THING_DIRECTION_POSITION.size():
				return {}
			sprite_id += THING_DIRECTION_POSITION[direction]
			flip = THING_DIRECTION_FLIP[direction]
		6:
			if direction < 0 or direction > 2:
				return {}
			sprite_id += direction
		9:
			if state != 0:
				sprite_id = 1379
			elif direction < 0 or direction >= THING_DIRECTION_POSITION.size():
				return {}
			else:
				sprite_id += THING_DIRECTION_POSITION[direction]
				flip = THING_DIRECTION_FLIP[direction]
		16:
			if direction < 0 or direction > 7:
				return {}
			flip = direction > 3
		_:
			return {}
	return {"sprite_id": sprite_id, "flip": flip}


static func train_sprite(
	city: CityState, x: int, y: int, thing: Dictionary
) -> Dictionary:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return {}
	var type := int(thing.get("type", 0))
	if type != 10 and type != 11:
		return {}
	var tile := city.building_id(x, y)
	var variant := 0
	var elevation := 0
	if tile == 0x5a or tile == 0x5b:
		variant = 1 if city.is_flipped(x, y) else 0
		elevation = (city.water_altitude(x, y) + 1) * ALTITUDE_STEP
	else:
		var tile_index := tile - 0x2c
		if tile_index < 0 or tile_index > 0x22:
			return {}
		if tile_index > 0x12:
			tile_index -= 6
		if tile_index > 0x16:
			tile_index -= 4
		variant = TRAIN_TILE_VARIANT[tile_index]
		if variant == 50:
			var transition := int(thing.get("dx", 0))
			if transition < 0 or transition >= TRAIN_TRANSITION_VARIANT.size():
				return {}
			variant = TRAIN_TRANSITION_VARIANT[transition]
		elevation = city.land_altitude(x, y) * ALTITUDE_STEP
		if city.terrain_id(x, y) == 0x0d:
			elevation += ALTITUDE_STEP
	if variant < 0 or variant >= TRAIN_SPRITE_POSITION.size():
		return {}
	return {
		"sprite_id": THING_SPRITES[type] + TRAIN_SPRITE_POSITION[variant],
		"flip": TRAIN_SPRITE_FLIP[variant],
		"train": true,
		"screen_x": TRAIN_SCREEN_X[variant],
		"screen_y": TRAIN_SCREEN_Y[variant],
		"elevation": elevation,
		"variant": variant,
	}


static func tornado_sprite(
	city: CityState, x: int, y: int, thing: Dictionary, record: int
) -> Dictionary:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return {}
	if int(thing.get("type", 0)) != 15:
		return {}
	var phase := (
		int(thing.get("px", 0)) + int(thing.get("py", 0)) + x + y + record
	)
	var altitude := city.land_altitude(x, y)
	if city.is_water(x, y):
		altitude = city.water_altitude(x, y)
	return {
		"sprite_id": THING_SPRITES[15] + phase % 3,
		"flip": (phase & 1) != 0,
		"tornado": true,
		"elevation": altitude * ALTITUDE_STEP,
	}


# For monsters, dx stores body-part flags rather than velocity.
static func monster_layers(
	city: CityState, x: int, y: int, thing: Dictionary, record: int
) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return layers
	if int(thing.get("type", 0)) != 5:
		return layers
	var altitude := city.land_altitude(x, y)
	if city.is_water(x, y):
		altitude = city.water_altitude(x, y)
	var z := int(thing.get("z", 0))
	var dx := int(thing.get("dx", 0))
	var dy := int(thing.get("dy", 0))
	var body_x := (x - y - 3) * HALF_WIDTH
	var body_y := (x + y) * HALF_HEIGHT - (altitude + z) * ALTITUDE_STEP
	var upper_x := body_x - 20
	var upper_y := body_y - 75

	var dx_left_first := dx & 1
	var dx_left_second := (dx >> 1) & 1
	layers.append(_monster_layer(
		1482 + ((dx >> 2) & 1),
		upper_x + MONSTER_UPPER_FIRST_X[dx_left_first]
			+ MONSTER_UPPER_SECOND_X[dx_left_second],
		upper_y + MONSTER_UPPER_FIRST_Y[dx_left_first]
			+ MONSTER_UPPER_SECOND_Y[dx_left_second],
		false
	))
	layers.append(_monster_layer(
		1480 + dx_left_second,
		upper_x + MONSTER_UPPER_FIRST_X[dx_left_first],
		upper_y + MONSTER_UPPER_FIRST_Y[dx_left_first],
		false
	))
	layers.append(_monster_layer(1478 + dx_left_first, upper_x, upper_y, false))

	var dx_right_first := (dx >> 3) & 1
	var dx_right_second := (dx >> 4) & 1
	var right_upper_x: int = body_x + 82 - MONSTER_UPPER_FIRST_X[dx_right_first]
	layers.append(_monster_layer(
		1482 + ((dx >> 5) & 1),
		right_upper_x - MONSTER_UPPER_SECOND_X[dx_right_second],
		upper_y + MONSTER_UPPER_FIRST_Y[dx_right_first]
			+ MONSTER_UPPER_SECOND_Y[dx_right_second],
		true
	))
	layers.append(_monster_layer(
		1480 + dx_right_second,
		right_upper_x,
		upper_y + MONSTER_UPPER_FIRST_Y[dx_right_first],
		true
	))
	layers.append(_monster_layer(
		1478 + dx_right_first, body_x + 82, upper_y, true
	))

	if dx & 0x80:
		layers.append(_monster_layer(1385, body_x + 46, body_y - 18, false))
	var head_sprite := 1490
	if dy & 0x80:
		head_sprite += (
			int(thing.get("px", 0)) + int(thing.get("py", 0))
			+ x + y + record
		) & 1
	layers.append(_monster_layer(head_sprite, body_x, body_y - 110, false))
	layers.append(_monster_layer(head_sprite, body_x + 60, body_y - 110, true))

	var lower_x := body_x - 20
	var lower_y := body_y - 50
	var dy_left_first := dy & 1
	var dy_left_second := (dy >> 1) & 1
	var left_lower_x: int = lower_x + MONSTER_LOWER_FIRST_X[dy_left_first]
	var left_lower_y: int = lower_y + MONSTER_LOWER_FIRST_Y[dy_left_first]
	layers.append(_monster_layer(1484 + dy_left_first, lower_x, lower_y, false))
	layers.append(_monster_layer(
		1486 + dy_left_second, left_lower_x, left_lower_y, false
	))
	layers.append(_monster_layer(
		1488 + ((dy >> 2) & 1),
		left_lower_x + MONSTER_LOWER_SECOND_X[dy_left_second],
		left_lower_y + MONSTER_LOWER_SECOND_Y[dy_left_second],
		false
	))

	var dy_right_first := (dy >> 3) & 1
	var dy_right_second := (dy >> 4) & 1
	var right_lower_x: int = body_x + 80 - MONSTER_LOWER_FIRST_X[dy_right_first]
	var right_lower_y: int = lower_y + MONSTER_LOWER_FIRST_Y[dy_right_first]
	layers.append(_monster_layer(
		1484 + dy_right_first, body_x + 80, lower_y, true
	))
	layers.append(_monster_layer(
		1486 + dy_right_second, right_lower_x, right_lower_y, true
	))
	layers.append(_monster_layer(
		1488 + ((dy >> 5) & 1),
		right_lower_x - MONSTER_LOWER_SECOND_X[dy_right_second],
		right_lower_y + MONSTER_LOWER_SECOND_Y[dy_right_second],
		true
	))
	return layers


static func _monster_layer(
	sprite_id: int, screen_x: int, screen_y: int, flip: bool
) -> Dictionary:
	return {
		"sprite_id": sprite_id,
		"screen_x": screen_x,
		"screen_y": screen_y,
		"flip": flip,
	}


static func _draw_moving_thing(
	output: Image,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	visual: Dictionary
) -> void:
	if visual.monster:
		var monster_origin_x := SIDE_MARGIN + CityState.MAP_SIZE * HALF_WIDTH
		var monster_has_shadow := city.building_id(visual.x, visual.y) < 0x71
		for layer in visual.layers:
			var monster_part := _sprite_image(
				sprites, palette, cache, layer.sprite_id, layer.flip
			)
			var monster_destination := Vector2i(
				monster_origin_x + layer.screen_x,
				TOP_MARGIN + layer.screen_y
			)
			if monster_has_shadow:
				_blend_shadow(
					output, monster_part, palette,
					monster_destination + Vector2i(0, 8 * visual.z)
				)
			output.blend_rect(
				monster_part,
				Rect2i(Vector2i.ZERO, monster_part.get_size()),
				monster_destination
			)
		return
	var sprite := _sprite_image(
		sprites, palette, cache, visual.sprite_id, visual.flip
	)
	if visual.tornado:
		var tornado_right_x: int = (
			SIDE_MARGIN + CityState.MAP_SIZE * HALF_WIDTH
			+ (visual.x - visual.y) * HALF_WIDTH + HALF_WIDTH
		)
		var tornado_top_y: int = (
			TOP_MARGIN + (visual.x + visual.y) * HALF_HEIGHT
			- visual.elevation - sprite.get_height()
		)
		var tornado_destination := Vector2i(
			tornado_right_x - sprite.get_width(), tornado_top_y
		)
		output.blend_rect(
			sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), tornado_destination
		)
		return
	if visual.train:
		var train_center_x: int = (
			SIDE_MARGIN + CityState.MAP_SIZE * HALF_WIDTH
			+ (visual.x - visual.y) * HALF_WIDTH + HALF_WIDTH + visual.screen_x
		)
		var train_top_y: int = (
			TOP_MARGIN + (visual.x + visual.y) * HALF_HEIGHT + visual.screen_y
			- visual.elevation - sprite.get_height()
		)
		var train_destination := Vector2i(
			train_center_x - int(sprite.get_width() / 2), train_top_y
		)
		output.blend_rect(
			sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), train_destination
		)
		return
	var altitude := city.land_altitude(visual.x, visual.y)
	if city.is_water(visual.x, visual.y):
		altitude = city.water_altitude(visual.x, visual.y)
	var center_x: int = (
		SIDE_MARGIN + CityState.MAP_SIZE * HALF_WIDTH
		+ (visual.x - visual.y) * HALF_WIDTH + HALF_WIDTH
		+ visual.px - visual.py
	)
	var top_y: int = (
		TOP_MARGIN + (visual.x + visual.y) * HALF_HEIGHT
		+ int((visual.px + visual.py) / 2)
		- altitude * ALTITUDE_STEP - visual.z * 8 - sprite.get_height()
	)
	var destination := Vector2i(center_x - int(sprite.get_width() / 2), top_y)
	if visual.type in [1, 2, 16] and city.building_id(visual.x, visual.y) < 0x71:
		var shadow_destination := destination + Vector2i(0, 8 * (visual.z - 2))
		_blend_shadow(output, sprite, palette, shadow_destination)
	output.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), destination)


static func shadow_color(palette: Sc2Palette, destination: Color) -> Color:
	if palette == null or not palette.is_valid():
		return destination
	var packed := destination.to_rgba32()
	if packed == palette.color(0x5f).to_rgba32():
		return palette.color(0x64)
	for palette_index in range(0x74, 0x7f):
		if packed == palette.color(palette_index).to_rgba32():
			return palette.color(0x7e)
	return destination


static func _blend_shadow(
	output: Image, mask: Image, palette: Sc2Palette, destination: Vector2i
) -> void:
	for source_y in mask.get_height():
		var output_y := destination.y + source_y
		if output_y < 0 or output_y >= output.get_height():
			continue
		for source_x in mask.get_width():
			if mask.get_pixel(source_x, source_y).a == 0.0:
				continue
			var output_x := destination.x + source_x
			if output_x < 0 or output_x >= output.get_width():
				continue
			var current := output.get_pixel(output_x, output_y)
			var changed := shadow_color(palette, current)
			if changed != current:
				output.set_pixel(output_x, output_y, changed)


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
