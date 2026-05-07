class_name IsometricMovingVisuals
extends IsometricConstants



static func moving_thing_visual(
	city: CityState,
	x: int,
	y: int,
	view_size := VIEW_LARGE,
	animation_phase := 0
) -> Dictionary:
	var overlay := city.text_overlay_id(x, y)

	if not OverlayData.is_thing(overlay):
		return {}

	var record := OverlayData.thing_record(overlay)
	var thing := city.thing(record)

	if thing.is_empty():
		return {}

	var type := int(thing.type)

	if type < 0 or type >= THING_MINIMUM_VIEW.size():
		return {}

	if view_size < THING_MINIMUM_VIEW[type]:
		return {}

	if (thing.x != x or thing.y != y) and type != 10 and type != 11:
		return {}

	var sprite: Dictionary

	if type == 5:
		var layers := monster_layers(city, x, y, thing, record, view_size)

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
		sprite = tornado_sprite(city, x, y, thing, record, view_size)
	else:
		sprite = moving_thing_sprite(thing, view_size)

		if type == 6 and not sprite.is_empty():
			sprite.flip = ((animation_phase + record + x + y) & 1) != 0

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
		"view_size": view_size,
	}


static func moving_thing_sprite(thing: Dictionary, view_size := VIEW_LARGE) -> Dictionary:
	if thing.is_empty():
		return {}

	var type := int(thing.get("type", 0))
	var direction := int(thing.get("direction", 0))
	var state := int(thing.get("state", 0))

	if type < 1 or type >= THING_SPRITES.size():
		return {}

	if view_size < VIEW_SMALL or view_size > VIEW_LARGE:
		return {}

	if view_size < THING_MINIMUM_VIEW[type]:
		return {}

	var sprite_id: int = THING_SPRITES[type] + (view_size - VIEW_LARGE) * 500
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
				sprite_id = 379 + view_size * 500
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
	city: CityState,
	x: int,
	y: int,
	thing: Dictionary,
	record: int,
	view_size := VIEW_LARGE
) -> Dictionary:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return {}

	if int(thing.get("type", 0)) != 15:
		return {}

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration.is_empty():
		return {}

	var phase := (
		int(thing.get("px", 0)) + int(thing.get("py", 0)) + x + y + record
	)
	var altitude := city.object_altitude(x, y)

	return {
		"sprite_id": (
			THING_SPRITES[15] + (view_size - VIEW_LARGE) * 500 + phase % 3
		),
		"flip": (phase & 1) != 0,
		"tornado": true,
		"elevation": altitude * int(configuration.altitude_step),
	}


static func monster_layers(
	city: CityState,
	x: int,
	y: int,
	thing: Dictionary,
	record: int,
	view_size := VIEW_LARGE
) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []

	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return layers

	if int(thing.get("type", 0)) != 5:
		return layers

	if IsometricGeometry.view_configuration(view_size).is_empty():
		return layers

	var altitude := city.object_altitude(x, y)
	var z := int(thing.get("z", 0))
	var dx := int(thing.get("dx", 0))
	var dy := int(thing.get("dy", 0))
	var body_x := (x - y - 3) * HALF_WIDTH
	var body_y := (x + y) * HALF_HEIGHT - (altitude + z) * ALTITUDE_STEP
	var head_frame := 0

	if dy & 0x80:
		head_frame = (int(thing.get("px", 0)) + int(thing.get("py", 0)) + x + y + record) & 1

	return monster_pose_layers(Vector2i(body_x, body_y), dx, dy, head_frame, view_size)


# For monsters, dx stores body-part flags rather than velocity.
static func monster_pose_layers(
	body_position: Vector2i, dx: int, dy: int, head_frame := 0, view_size := VIEW_LARGE
) -> Array[Dictionary]:
	# shared native sprite geometry. callers supply display coordinates and pose bits
	var layers: Array[Dictionary] = []
	var body_x := body_position.x
	var body_y := body_position.y
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

	var head_sprite := 1490 + (head_frame & 1)

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

	if view_size != VIEW_LARGE:
		var divisor := 4 if view_size == VIEW_SMALL else 2

		for layer in layers:
			layer.sprite_id += (view_size - VIEW_LARGE) * 500
			layer.screen_x = int(layer.screen_x / divisor)
			layer.screen_y = int(layer.screen_y / divisor)

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
