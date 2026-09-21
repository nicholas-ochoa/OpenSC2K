class_name IsometricStaticOcclusion
extends IsometricConstants


@warning_ignore_start("integer_division")


static func static_occlusion_commands(
	city: CityState, sprites: Sc2SpriteArchive, view_size := VIEW_LARGE
) -> Array[CityStaticCommand]:
	var map_edge: int = city.map_size if city != null else 128
	var commands: Array[CityStaticCommand] = []

	if city == null or not city.is_valid() or sprites == null or not sprites.is_valid():
		return commands

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return commands

	var origin_x: int = (
		configuration.side_margin
		+ map_edge * configuration.half_width
	)

	for diagonal in map_edge * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y

			if x >= map_edge or y >= map_edge:
				continue

			var order := (x + y) * map_edge + y
			commands.append_array(tile_occlusion_commands(
				city, sprites, configuration, origin_x, x, y, order
			))

	return commands


static func patch_static_occlusion_commands(
	base_commands: Array[CityStaticCommand],
	city: CityState,
	sprites: Sc2SpriteArchive,
	dirty_indices: PackedInt32Array,
	view_size := VIEW_LARGE
) -> Array[CityStaticCommand]:
	var map_edge: int = city.map_size if city != null else 128

	if (
		base_commands.is_empty()
		or city == null
		or not city.is_valid()
		or sprites == null
		or not sprites.is_valid()
	):
		return static_occlusion_commands(city, sprites, view_size)

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return []

	var origin_x: int = (
		configuration.side_margin
		+ map_edge * configuration.half_width
	)
	var replacements: Dictionary[int, Array] = {}

	for value in dirty_indices:
		var index := int(value)

		if index < 0 or index >= (map_edge * map_edge):
			continue

		var x := int(index / map_edge)
		var y := index % map_edge
		var order := (x + y) * map_edge + y
		replacements[order] = tile_occlusion_commands(
			city, sprites, configuration, origin_x, x, y, order
		)

	if replacements.is_empty():
		return base_commands.duplicate()

	var commands: Array[CityStaticCommand] = []
	var inserted: Dictionary[int, bool] = {}

	for command in base_commands:
		var order := int(command.depth_order)

		if not replacements.has(order):
			commands.append(command)
			continue

		if not inserted.has(order):
			commands.append_array(replacements[order])
			inserted[order] = true

	if inserted.size() != replacements.size():
		# every valid surface tile has an occluder. rebuild if the supplied base
		# list is incomplete instead of risking a bad command order
		return static_occlusion_commands(city, sprites, view_size)

	return commands


# return the foreground occluder commands of one tile
# this is the per-tile form of `static_occlusion_commands`. a caller that
# paints tiles with `IsometricImageRender.draw_tile` uses this for the
# foreground of the same tile, with the same `draw_order` rule
static func tile_occlusion_commands(
	city: CityState,
	sprites: Sc2SpriteArchive,
	configuration: CityViewConfiguration,
	origin_x: int,
	x: int,
	y: int,
	draw_order: int
) -> Array[CityStaticCommand]:
	var map_edge: int = city.map_size if city != null else 128
	var commands: Array[CityStaticCommand] = []

	if not city.tile_is_visible(x, y):
		return commands

	var terrain_id := IsometricGeometry.surface_terrain_id(city, x, y)
	var building_id := city.building_id(x, y)
	var terrain_altitude := city.land_altitude(x, y)

	if terrain_id >= 0x10:
		terrain_altitude = city.water_altitude(x, y)

	var screen_x := origin_x + (x - y) * configuration.half_width
	var flat_base_y := (
		configuration.top_margin + (x + y) * configuration.half_height
	)

	if x == map_edge - 1 or y == map_edge - 1:
		for visual in IsometricStaticVisuals.edge_stack_visuals(city, x, y, configuration.view_size):
			_append_occluder(
				commands, sprites, visual.sprite_id, false,
				Vector2i(
					screen_x,
					flat_base_y - visual.elevation + configuration.tile_height
				),
				draw_order
			)

	var base_y := flat_base_y - terrain_altitude * configuration.altitude_step
	var is_highway_composite := building_id >= 0x61 and building_id <= 0x6b

	if building_id < Tiles.DEVELOPED_FIRST and not is_highway_composite:
		_append_occluder(
			commands, sprites,
			IsometricGeometry.terrain_sprite_id(terrain_id, city.is_water(x, y), configuration.sprite_base),
			false, Vector2i(screen_x, base_y + configuration.tile_height), draw_order
		)

	var zone := city.zone_id(x, y)

	if zone > 0 and building_id == 0:
		_append_occluder(
			commands, sprites, configuration.sprite_base + 290 + zone, false,
			Vector2i(screen_x, base_y + configuration.tile_height), draw_order
		)

	if building_id > 0 and IsometricStaticVisuals._should_draw_building(city, x, y, building_id):
		if is_highway_composite:
			for visual in IsometricStaticVisuals.highway_ground_visuals(
				city, x, y, configuration.view_size, sprites.redraw_small_highway_ground
			):
				_append_occluder(
					commands, sprites, visual.sprite_id,
					false,
					Vector2i(screen_x, base_y + configuration.tile_height)
						+ Vector2i(visual.offset),
					draw_order
				)

		var building_flip := IsometricStaticVisuals.building_sprite_flip(city, x, y, building_id)
		var building_sprite_id := configuration.sprite_base + building_id
		var building_entry = sprites.find_sprite(building_sprite_id)

		if building_entry != null:
			var building_base_y := (
				flat_base_y
				- city.object_altitude(x, y) * configuration.altitude_step
			) + IsometricStaticVisuals.building_baseline_offset(
				building_id, terrain_id, building_entry.width, configuration.view_size
			)
			_append_occluder(
				commands, sprites, building_sprite_id, building_flip,
				Vector2i(screen_x, building_base_y + configuration.tile_height),
				draw_order,
				train_power_foreground_reference_sprite_id(
					building_id, configuration.sprite_base
				)
			)

			if not commands.is_empty():
				configure_train_foreground(commands[-1], building_id, configuration)

			var power_marker := IsometricStaticVisuals.power_marker_visual(city, x, y, configuration.view_size)

			if power_marker != null:
				var marker_entry = sprites.find_sprite(power_marker.sprite_id)

				if marker_entry != null:
					_append_occluder(
						commands, sprites, power_marker.sprite_id, false,
						Vector2i(
							screen_x + int(building_entry.width / 2)
								- int(marker_entry.width / 2),
							building_base_y + configuration.tile_height
						),
						draw_order
					)

	var dispatch_sprite := IsometricStaticVisuals.dispatch_sprite_id(city, x, y, configuration.view_size)

	if dispatch_sprite > 0:
		var dispatch_entry = sprites.find_sprite(dispatch_sprite)

		if dispatch_entry != null:
			_append_occluder(
				commands, sprites, dispatch_sprite, false,
				Vector2i(
					screen_x + configuration.half_width
						- int(dispatch_entry.width / 2),
					flat_base_y
						- city.land_altitude(x, y) * configuration.altitude_step
						+ configuration.tile_height
				),
				draw_order
			)

	return commands


static func _append_occluder(
	commands: Array[CityStaticCommand],
	sprites: Sc2SpriteArchive,
	sprite_id: int,
	flip: bool,
	base_position: Vector2i,
	draw_order: int,
	train_foreground_reference_sprite_id := 0
) -> void:
	var entry = sprites.find_sprite(sprite_id)

	if entry == null:
		return

	var command := CityStaticCommand.new()
	command.sprite_id = sprite_id
	command.flip = flip
	command.position = base_position - Vector2i(0, entry.height)
	command.size = Vector2i(entry.width, entry.height)
	command.depth_order = draw_order

	if train_foreground_reference_sprite_id != 0:
		command.train_foreground_reference_sprite_id = (
			train_foreground_reference_sprite_id
		)

	commands.append(command)


static func configure_train_foreground(command: CityStaticCommand, building_id: int, configuration: CityViewConfiguration) -> void:
	var reference := train_power_foreground_reference_sprite_id(building_id, configuration.sprite_base)

	if reference != 0:
		command.train_foreground_reference_sprite_id = reference

	command.train_ignore = (building_id >= 0x0e and building_id <= 0x1c) or building_id in [0x43, 0x44, 0x47, 0x48]

	if (building_id >= 0x49 and building_id <= 0x50) or (building_id >= 0x61 and building_id <= 0x6b):
		command.train_deck_thickness = configuration.view_size + 1

		if building_id in [0x4f, 0x50]:
			command.train_deck_reference_sprite_id = reference

		command.train_foreground_requires_depth = true


# subtract the ground rail, keep the raised deck in front of the train
static func train_power_foreground_reference_sprite_id(
	building_id: int, sprite_base := 1000
) -> int:
	if building_id >= 0x0e and building_id <= 0x1c:
		return -1

	# rail/highway crossings need their raised deck in front of a train on
	# the same tile. subtract only the ground-level rail sprite
	if building_id == 0x4d:
		return sprite_base + 0x2d

	if building_id == 0x4e:
		return sprite_base + 0x2c

	var reference_tile := int(POWER_CROSSING_BASE_TILE.get(building_id, -1))

	return 0 if reference_tile < 0 else sprite_base + reference_tile
