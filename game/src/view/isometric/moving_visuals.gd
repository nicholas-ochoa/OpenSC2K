class_name IsometricMovingVisuals
extends IsometricConstants


@warning_ignore_start("integer_division")


class Layer extends CitySpriteVisual:
	var screen_x: int
	var screen_y: int


class Sprite extends CitySpriteVisual:
	var train := false
	var screen_x := 0
	var screen_y := 0
	var elevation := 0
	var variant := 0
	var tornado := false
	var monster := false
	var layers: Array[Layer] = []


class Visual extends Sprite:
	var record: int
	var type: int
	var x: int
	var y: int
	var z: int
	var px: int
	var py: int
	var view_size: int


class Position extends RefCounted:
	var anchor: Vector2
	var order: int


class Anchor extends Position:
	var type: int
	var x: int
	var y: int

	func _init(kind := 0, point := Vector2i.ZERO) -> void:
		type = kind
		x = point.x
		y = point.y


static func moving_thing_visual(
	city: CityState,
	x: int,
	y: int,
	view_size := VIEW_LARGE,
	animation_phase := 0
) -> Visual:
	var overlay := city.text_overlay_id(x, y)

	if not OverlayData.is_thing(overlay):
		return null

	var record := OverlayData.thing_record(overlay)
	var thing := city.thing(record)

	if thing == null:
		return null

	var type := thing.type

	if type < 0 or type >= THING_MINIMUM_VIEW.size():
		return null

	if view_size < THING_MINIMUM_VIEW[type]:
		return null

	if (thing.x != x or thing.y != y) and type != 10 and type != 11:
		return null

	var sprite: Sprite

	if type == 5:
		var layers := monster_layers(city, x, y, thing, record, view_size)

		if layers.is_empty():
			return null

		sprite = Sprite.new()
		sprite.sprite_id = layers[0].sprite_id
		sprite.flip = layers[0].flip
		sprite.monster = true
		sprite.layers = layers
	elif type == 10 or type == 11:
		sprite = train_sprite(city, x, y, thing)
	elif type == 15:
		sprite = tornado_sprite(city, x, y, thing, record, view_size)
	else:
		sprite = moving_thing_sprite(thing, view_size)

		if type == 6 and sprite != null:
			sprite.flip = ((animation_phase + record + x + y) & 1) != 0

	if sprite == null:
		return null

	var result := Visual.new()
	result.sprite_id = sprite.sprite_id
	result.flip = sprite.flip
	result.record = record
	result.type = thing.type
	result.x = x
	result.y = y
	result.z = thing.z
	result.px = thing.px
	result.py = thing.py
	result.train = sprite.train
	result.screen_x = sprite.screen_x
	result.screen_y = sprite.screen_y
	result.elevation = sprite.elevation
	result.tornado = sprite.tornado
	result.monster = sprite.monster
	result.layers = sprite.layers
	result.view_size = view_size

	return result


# return the display anchor of one xthg record for display interpolation
# the anchor uses the same placement terms as the draw commands, without the
# sprite size. the result is in common large logical pixels. it is null for
# an unused record and for a type that the moving-object path does not move
static func moving_thing_anchor(
	city: CityState, record: int, view_size := VIEW_LARGE
) -> Anchor:
	if city == null or not city.is_valid():
		return null

	var thing := city.thing(record)

	if thing == null:
		return null

	var type := thing.type
	var x := thing.x
	var y := thing.y

	if type <= 0 or type >= THING_MINIMUM_VIEW.size() or city.index_of(x, y) < 0:
		return null

	if type in [7, 8, 12, 13, 14]:
		return null

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return null

	var half_width := configuration.half_width
	var half_height := configuration.half_height
	var step := configuration.altitude_step
	var divisor := configuration.divisor
	var anchor := Vector2i.ZERO

	match type:
		10, 11:
			var sprite := train_sprite(city, x, y, thing)

			if sprite == null:
				return null

			# Trains use the large-view art and placement constants.
			anchor = Vector2i(
				(x - y) * HALF_WIDTH + int(sprite.screen_x),
				(x + y) * HALF_HEIGHT + int(sprite.screen_y) - int(sprite.elevation)
			)
			divisor = 1
		15:
			anchor = Vector2i(
				(x - y) * half_width,
				(x + y) * half_height - city.object_altitude(x, y) * step
			)
		5:
			anchor = Vector2i(
				(x - y) * half_width,
				(x + y) * half_height - (city.object_altitude(x, y) + thing.z) * step
			)
		_:
			var px := thing.px
			var py := thing.py
			anchor = Vector2i(
				(x - y) * half_width
					+ int((px - py) / THING_X_DIVISOR[view_size]),
				(x + y) * half_height
					+ int((px + py) / THING_Y_DIVISOR[view_size])
					- city.object_altitude(x, y) * step
					- thing.z * half_height
			)

	var result := Anchor.new()
	result.type = type
	result.x = x
	result.y = y
	result.anchor = Vector2(anchor * divisor)
	result.order = (x + y) * city.map_size + y

	return result


static func moving_thing_sprite(thing: ThingRecord, view_size := VIEW_LARGE) -> Sprite:
	if thing == null:
		return null

	var type := thing.type
	var direction := thing.direction
	var state := thing.state

	if type < 1 or type >= THING_SPRITES.size():
		return null

	if view_size < VIEW_SMALL or view_size > VIEW_LARGE:
		return null

	if view_size < THING_MINIMUM_VIEW[type]:
		return null

	var sprite_id: int = THING_SPRITES[type] + (view_size - VIEW_LARGE) * 500
	var flip := false

	match type:
		1, 2, 3:
			if direction < 0 or direction >= SHIP_DIRECTION_POSITION.size():
				return null

			sprite_id += SHIP_DIRECTION_POSITION[direction]
			flip = SHIP_DIRECTION_FLIP[direction]
		4:
			if direction < 0 or direction >= THING_DIRECTION_POSITION.size():
				return null

			sprite_id += THING_DIRECTION_POSITION[direction]
			flip = THING_DIRECTION_FLIP[direction]
		6:
			if direction < 0 or direction > 2:
				return null

			sprite_id += direction
		9:
			if state != 0:
				sprite_id = 379 + view_size * 500
			elif direction < 0 or direction >= THING_DIRECTION_POSITION.size():
				return null
			else:
				sprite_id += THING_DIRECTION_POSITION[direction]
				flip = THING_DIRECTION_FLIP[direction]
		16:
			if direction < 0 or direction > 7:
				return null

			flip = direction > 3
		_:
			return null

	var result := Sprite.new()
	result.sprite_id = sprite_id
	result.flip = flip

	return result


static func train_sprite(
	city: CityState, x: int, y: int, thing: ThingRecord
) -> Sprite:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return null

	var type := thing.type

	if type != 10 and type != 11:
		return null

	var tile := city.building_id(x, y)
	var variant := 0
	var elevation := 0

	if tile == 0x5a or tile == 0x5b:
		variant = 1 if city.is_flipped(x, y) else 0
		elevation = (city.water_altitude(x, y) + 1) * ALTITUDE_STEP
	else:
		var tile_index := tile - 0x2c

		if tile_index < 0 or tile_index > 0x22:
			return null

		if tile_index > 0x12:
			tile_index -= 6

		if tile_index > 0x16:
			tile_index -= 4

		variant = TRAIN_TILE_VARIANT[tile_index]

		if variant == 50:
			var transition := thing.dx

			if transition < 0 or transition >= TRAIN_TRANSITION_VARIANT.size():
				return null

			variant = TRAIN_TRANSITION_VARIANT[transition]

		elevation = city.land_altitude(x, y) * ALTITUDE_STEP

		if city.terrain_id(x, y) == 0x0d:
			elevation += ALTITUDE_STEP

	if variant < 0 or variant >= TRAIN_SPRITE_POSITION.size():
		return null

	var result := Sprite.new()
	result.sprite_id = THING_SPRITES[type] + TRAIN_SPRITE_POSITION[variant]
	result.flip = TRAIN_SPRITE_FLIP[variant]
	result.train = true
	result.screen_x = TRAIN_SCREEN_X[variant]
	result.screen_y = TRAIN_SCREEN_Y[variant]
	result.elevation = elevation
	result.variant = variant

	return result


static func tornado_sprite(
	city: CityState,
	x: int,
	y: int,
	thing: ThingRecord,
	record: int,
	view_size := VIEW_LARGE
) -> Sprite:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return null

	if thing.type != 15:
		return null

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return null

	var phase := (
		thing.px + thing.py + x + y + record
	)
	var altitude := city.object_altitude(x, y)

	var result := Sprite.new()
	result.sprite_id = (
		THING_SPRITES[15] + (view_size - VIEW_LARGE) * 500 + phase % 3
	)
	result.flip = (phase & 1) != 0
	result.tornado = true
	result.elevation = altitude * configuration.altitude_step

	return result


static func monster_layers(
	city: CityState,
	x: int,
	y: int,
	thing: ThingRecord,
	record: int,
	view_size := VIEW_LARGE
) -> Array[Layer]:
	var layers: Array[Layer] = []

	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return layers

	if thing.type != 5:
		return layers

	if IsometricGeometry.view_configuration(view_size) == null:
		return layers

	var altitude := city.object_altitude(x, y)
	var z := thing.z
	var dx := thing.dx
	var dy := thing.dy
	var body_x := (x - y - 3) * HALF_WIDTH
	var body_y := (x + y) * HALF_HEIGHT - (altitude + z) * ALTITUDE_STEP
	var head_frame := 0

	if dy & 0x80:
		head_frame = (thing.px + thing.py + x + y + record) & 1

	return monster_pose_layers(Vector2i(body_x, body_y), dx, dy, head_frame, view_size)


# For monsters, dx stores body-part flags rather than velocity.
static func monster_pose_layers(
	body_position: Vector2i, dx: int, dy: int, head_frame := 0, view_size := VIEW_LARGE
) -> Array[Layer]:
	# shared native sprite geometry. callers supply display coordinates and pose bits
	var layers: Array[Layer] = []
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
) -> Layer:
	var result := Layer.new()
	result.sprite_id = sprite_id
	result.screen_x = screen_x
	result.screen_y = screen_y
	result.flip = flip

	return result
