class_name IsometricDynamicCommands
extends IsometricConstants


@warning_ignore_start("integer_division")


static func moving_thing_draw_commands(
	city: CityState,
	sprites: Sc2SpriteArchive,
	view_size := VIEW_LARGE,
	animation_phase := 0
) -> Array[Dictionary]:
	var map_edge: int = city.map_size if city != null else 128
	var commands: Array[Dictionary] = []

	if city == null or not city.is_valid() or sprites == null or not sprites.is_valid():
		return commands

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return commands

	for diagonal in map_edge * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y

			if x >= map_edge or y >= map_edge:
				continue

			var visual := IsometricMovingVisuals.moving_thing_visual(
				city, x, y, view_size, animation_phase
			)

			if visual.is_empty():
				continue

			var visual_commands := moving_thing_draw_commands_for_visual(
				city, sprites, visual, configuration
			)
			var draw_order := (x + y) * map_edge + y

			for command in visual_commands:
				command.depth_order = draw_order
				command.record = int(visual.record)
				commands.append(command)

	return commands


static func dynamic_draw_commands(
	city: CityState,
	sprites: Sc2SpriteArchive,
	view_size := VIEW_LARGE,
	animation_phase := 0
) -> Array[Dictionary]:
	var map_edge: int = city.map_size if city != null else 128
	var commands: Array[Dictionary] = []

	if city == null or not city.is_valid() or sprites == null or not sprites.is_valid():
		return commands

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return commands

	var entries: Array[Dictionary] = []
	var things := city.document.find_chunk("XTHG")

	for record in city.thing_count():
		var offset := record * CityState.THING_RECORD_SIZE

		if things == null or offset >= things.decoded_payload.size() or things.decoded_payload[offset] == 0:
			continue

		# only the position is needed. the type byte is nonzero here
		var point := Vector2i(ThingData.read(things.decoded_payload, offset + 3), ThingData.read(things.decoded_payload, offset + 4))

		if (
			city.index_of(point.x, point.y) < 0
			or city.text_overlay_id(point.x, point.y) != OverlayData.thing_id(record)
		):
			continue

		entries.append({
			"order": (point.x + point.y) * map_edge + point.y,
			"record": record,
			"point": point,
			"special": false,
		})

	for overlay in SPECIAL_OVERLAY_SPRITE_OFFSETS:
		var found := OverlayData.find(city.text_overlays, int(overlay))

		while found >= 0:
			var point := Vector2i(
				int(found / map_edge), found % map_edge
			)
			entries.append({
				"order": (point.x + point.y) * map_edge + point.y,
				"record": city.thing_count(),
				"point": point,
				"special": true,
			})
			found = OverlayData.find(city.text_overlays, int(overlay), found + 1)

	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.order) == int(right.order):
			return int(left.record) < int(right.record)

		return int(left.order) < int(right.order)
	)

	for entry in entries:
		var point: Vector2i = entry.point

		if not city.tile_is_visible(point.x, point.y):
			continue

		var entry_commands: Array[Dictionary] = []

		if entry.special:
			var special_visual := IsometricStaticVisuals.special_overlay_visual(
				city, point.x, point.y, view_size, animation_phase
			)
			var special_command := special_overlay_draw_command(
				city, sprites, point, special_visual, configuration
			)

			if not special_command.is_empty():
				entry_commands.append(special_command)
		else:
			var moving_visual := IsometricMovingVisuals.moving_thing_visual(
				city, point.x, point.y, view_size, animation_phase
			)
			entry_commands = moving_thing_draw_commands_for_visual(
				city, sprites, moving_visual, configuration
			)

		for command in entry_commands:
			command.depth_order = int(entry.order)

			if not entry.special:
				command.record = int(entry.record)

			commands.append(command)

	return commands


static func special_overlay_draw_command(
	city: CityState,
	sprites: Sc2SpriteArchive,
	point: Vector2i,
	visual: Dictionary,
	configuration: CityViewConfiguration
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if visual.is_empty() or configuration == null:
		return {}

	var entry := sprites.find_sprite(int(visual.sprite_id))

	if entry == null:
		return {}

	var altitude := city.object_altitude(point.x, point.y)
	var screen_x := (
		int(configuration.side_margin)
		+ map_edge * int(configuration.half_width)
		+ (point.x - point.y) * int(configuration.half_width)
	)
	var base_y := (
		int(configuration.top_margin)
		+ (point.x + point.y) * int(configuration.half_height)
		- altitude * int(configuration.altitude_step)
	)

	return {
		"sprite_id": int(visual.sprite_id),
		"flip": bool(visual.flip),
		"position": Vector2i(
			screen_x + int(configuration.half_width) - int(entry.width / 2),
			base_y + int(configuration.tile_height) - entry.height,
		),
		"shadow": false,
		"overlay": int(visual.overlay),
		"static_occlusion": true,
	}


static func moving_thing_draw_commands_for_visual(
	city: CityState,
	sprites: Sc2SpriteArchive,
	visual: Dictionary,
	configuration: CityViewConfiguration
) -> Array[Dictionary]:
	var map_edge: int = city.map_size if city != null else 128
	var commands: Array[Dictionary] = []

	if visual.is_empty() or configuration == null:
		return commands

	if visual.monster:
		var monster_origin_x := (
			int(configuration.side_margin)
			+ map_edge * int(configuration.half_width)
		)
		var monster_origin_y: int = (
			int(configuration.top_margin) + int(configuration.tile_height)
		)
		var monster_has_shadow := city.building_id(visual.x, visual.y) < 0x71

		for layer in visual.layers:
			var destination := Vector2i(
				monster_origin_x + layer.screen_x,
				monster_origin_y + layer.screen_y
			)

			if monster_has_shadow:
				commands.append(_moving_draw_command(
					layer.sprite_id, layer.flip,
					destination + Vector2i(
						0, int(configuration.half_height) * visual.z
					),
					true
				))

			commands.append(_moving_draw_command(
				layer.sprite_id, layer.flip, destination, false
			))

		return commands

	var entry := sprites.find_sprite(visual.sprite_id)

	if entry == null:
		return commands

	var destination := Vector2i.ZERO

	if visual.tornado:
		var right_x: int = (
			int(configuration.side_margin)
			+ map_edge * int(configuration.half_width)
			+ (visual.x - visual.y) * int(configuration.half_width)
			+ int(configuration.half_width)
		)
		destination = Vector2i(
			right_x - entry.width,
			int(configuration.top_margin)
				+ (visual.x + visual.y) * int(configuration.half_height)
				+ int(configuration.tile_height)
				- visual.elevation - entry.height
		)
	elif visual.train:
		var center_x: int = (
			SIDE_MARGIN + map_edge * HALF_WIDTH
			+ (visual.x - visual.y) * HALF_WIDTH + HALF_WIDTH + visual.screen_x
		)
		destination = Vector2i(
			center_x - int(entry.width / 2),
			TOP_MARGIN + TILE_HEIGHT
				+ (visual.x + visual.y) * HALF_HEIGHT + visual.screen_y
				- visual.elevation - entry.height
		)
	else:
		var altitude := city.object_altitude(visual.x, visual.y)
		var view_size := int(configuration.view_size)
		var center_x: int = (
			int(configuration.side_margin)
			+ map_edge * int(configuration.half_width)
			+ (visual.x - visual.y) * int(configuration.half_width)
			+ int(configuration.half_width)
			+ int((visual.px - visual.py) / THING_X_DIVISOR[view_size])
		)
		destination = Vector2i(
			center_x - int(entry.width / 2),
			int(configuration.top_margin)
				+ (visual.x + visual.y) * int(configuration.half_height)
				+ int(configuration.tile_height)
				+ int((visual.px + visual.py) / THING_Y_DIVISOR[view_size])
				- altitude * int(configuration.altitude_step)
				- visual.z * int(configuration.half_height) - entry.height
		)

		if visual.type in [1, 2, 16] and city.building_id(visual.x, visual.y) < 0x71:
			commands.append(_moving_draw_command(
				visual.sprite_id, visual.flip,
				destination + Vector2i(
					0, int(configuration.half_height) * (visual.z - 2)
				),
				true
			))

	var main_command := _moving_draw_command(
		visual.sprite_id, visual.flip, destination, false
	)

	if visual.train:
		main_command.train = true

	commands.append(main_command)

	return commands


static func _moving_draw_command(
	sprite_id: int, flip: bool, position: Vector2i, shadow: bool
) -> Dictionary:
	return {
		"sprite_id": sprite_id,
		"flip": flip,
		"position": position,
		"shadow": shadow,
	}
