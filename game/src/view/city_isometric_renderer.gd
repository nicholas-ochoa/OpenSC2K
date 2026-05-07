class_name CityIsometricRenderer
extends IsometricConstants



static func create_image(
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	view_size := VIEW_LARGE,
	animation_phase := 0,
	include_moving_things := true,
	transparent_background := false,
	validate_required_assets := true,
	include_special_overlays := true
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return _failure("city is invalid")

	if palette == null or not palette.is_valid():
		return _failure("palette is invalid")

	if sprites == null or not sprites.is_valid():
		return _failure("large sprite archive is invalid")

	var configuration := view_configuration(view_size)

	if configuration.is_empty():
		return _failure("city view size is invalid")

	if validate_required_assets:
		var asset_errors := validate_assets(city, sprites, view_size)

		if not asset_errors.is_empty():
			return _failure(asset_errors[0])

	var output_size := output_size_for_view(view_size, map_edge)
	var output := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT if transparent_background else Color("18242c"))
	var origin_x: int = configuration.side_margin + map_edge * configuration.half_width
	var cache: Dictionary = {}

	for diagonal in map_edge * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y

			if x >= map_edge or y >= map_edge:
				continue

			_draw_tile(
				output, city, palette, sprites, cache, configuration,
				origin_x, x, y, animation_phase, include_moving_things,
				include_special_overlays
			)

	if palette.is_index_encoding:
		output.convert(Image.FORMAT_LA8 if transparent_background else Image.FORMAT_L8)

	return {"ok": true, "image": output, "error": ""}


static func patch_static_image(
	base_image: Image,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	dirty_indices: PackedInt32Array,
	view_size := VIEW_LARGE,
	animation_phase := 0,
	copy_image := true
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if base_image == null or base_image.is_empty():
		return _failure("base city image is invalid")

	if city == null or not city.is_valid():
		return _failure("city is invalid")

	if palette == null or not palette.is_valid() or not palette.is_index_encoding:
		return _failure("indexed palette is invalid")

	if sprites == null or not sprites.is_valid():
		return _failure("sprite archive is invalid")

	var configuration := view_configuration(view_size)

	if configuration.is_empty():
		return _failure("city view size is invalid")

	var native_size := output_size_for_view(view_size, map_edge)
	var output_scale := 1

	if base_image.get_size() == output_size_for_view(VIEW_LARGE, map_edge):
		output_scale = int(configuration.divisor)
	elif base_image.get_size() != native_size:
		return _failure("base city image has the wrong size")

	var sprite_limit := _maximum_sprite_size(sprites)
	var native_rect := dirty_screen_rect(
		dirty_indices, sprites, view_size, sprite_limit, map_edge
	)

	if native_rect.get_area() <= 0:
		return _failure("dirty city region is empty")

	var local_configuration := configuration.duplicate()
	local_configuration.top_margin = (
		int(configuration.top_margin) - native_rect.position.y
	)
	var origin_x := (
		int(configuration.side_margin)
		+ map_edge * int(configuration.half_width)
		- native_rect.position.x
	)
	var region := Image.create(
		native_rect.size.x, native_rect.size.y, false, Image.FORMAT_RGBA8
	)
	region.fill(Color.TRANSPARENT)
	var cache: Dictionary = {}
	var tiles_drawn := 0
	# bound both x+y and x-y before walking the painter order. keep the exact
	# rectangle test below, including the full altitude and sprite allowance
	var half_width := int(configuration.half_width)
	var half_height := int(configuration.half_height)
	var full_origin_x := int(configuration.side_margin) + map_edge * half_width
	var top_margin := int(configuration.top_margin)
	var bottom_extra := int(configuration.tile_height) + int(IntegerMath.div_trunc(sprite_limit.x, 4)) + 1
	var top_extra := 32 * int(configuration.altitude_step) + sprite_limit.y
	var first_diagonal := maxi(0, floori(float(native_rect.position.y - top_margin - bottom_extra) / half_height))
	var last_diagonal := mini(2 * (map_edge - 1), ceili(float(native_rect.end.y - top_margin + top_extra) / half_height))
	var first_difference := floori(float(native_rect.position.x - full_origin_x - sprite_limit.x - int(configuration.tile_width) - 1) / half_width)
	var last_difference := ceili(float(native_rect.end.x - full_origin_x + sprite_limit.x) / half_width)

	for diagonal in range(first_diagonal, last_diagonal + 1):
		var first_y := maxi(maxi(0, diagonal - (map_edge - 1)), ceili(float(diagonal - last_difference) / 2.0))
		var last_y := mini(mini(map_edge - 1, diagonal), floori(float(diagonal - first_difference) / 2.0))

		for y in range(first_y, last_y + 1):
			var x := diagonal - y

			if not _potential_tile_bounds(
				configuration, sprite_limit, x, y, map_edge
			).intersects(native_rect):
				continue

			_draw_tile(
				region, city, palette, sprites, cache, local_configuration,
				origin_x, x, y, animation_phase, false, false
			)
			tiles_drawn += 1

	region.convert(Image.FORMAT_LA8)
	var output_rect := native_rect

	if output_scale > 1:
		region.resize(
			region.get_width() * output_scale,
			region.get_height() * output_scale,
			Image.INTERPOLATE_NEAREST
		)
		output_rect = Rect2i(
			native_rect.position * output_scale,
			native_rect.size * output_scale
		)

	var patched := base_image.duplicate() if copy_image else base_image

	if patched.get_format() != region.get_format():
		region.convert(patched.get_format())

	patched.blit_rect(
		region, Rect2i(Vector2i.ZERO, region.get_size()), output_rect.position
	)

	return {
		"ok": true,
		"image": patched,
		"native_rect": native_rect,
		"output_rect": output_rect,
		"tiles_drawn": tiles_drawn,
		"error": "",
	}


static func dirty_screen_rect(
	dirty_indices: PackedInt32Array,
	sprites: Sc2SpriteArchive,
	view_size := VIEW_LARGE,
	sprite_limit := Vector2i.ZERO,
	map_edge: int = 128,
) -> Rect2i:
	return IsometricGeometry.dirty_screen_rect(dirty_indices, sprites, view_size, sprite_limit, map_edge)


static func _maximum_sprite_size(sprites: Sc2SpriteArchive) -> Vector2i:
	return IsometricGeometry._maximum_sprite_size(sprites)


static func _potential_tile_bounds(
	configuration: Dictionary, sprite_limit: Vector2i, x: int, y: int,
	map_edge: int = 128,
) -> Rect2i:
	return IsometricGeometry._potential_tile_bounds(configuration, sprite_limit, x, y, map_edge)


static func validate_assets(
	city: CityState, sprites: Sc2SpriteArchive, view_size := VIEW_LARGE
) -> PackedStringArray:
	return IsometricStaticVisuals.validate_assets(city, sprites, view_size)


static func surface_terrain_id(city: CityState, x: int, y: int) -> int:
	return IsometricGeometry.surface_terrain_id(city, x, y)


static func terrain_sprite_id(terrain: int, water_flag: bool, sprite_base := 1000) -> int:
	return IsometricGeometry.terrain_sprite_id(terrain, water_flag, sprite_base)


static func view_configuration(view_size: int) -> Dictionary:
	return IsometricGeometry.view_configuration(view_size)


static func output_size_for_view(view_size: int, map_edge: int = 128) -> Vector2i:
	return IsometricGeometry.output_size_for_view(view_size, map_edge)


static func tile_polygon(city: CityState, x: int, y: int, land_surface := false) -> PackedVector2Array:
	return IsometricGeometry.tile_polygon(city, x, y, land_surface)


static func terrain_surface_polygon(
	city: CityState, x: int, y: int, land_surface := false
) -> PackedVector2Array:
	return IsometricGeometry.terrain_surface_polygon(city, x, y, land_surface)


static func screen_to_tile(city: CityState, point: Vector2, land_surface := false) -> Vector2i:
	return IsometricGeometry.screen_to_tile(city, point, land_surface)


static func transient_effect_position(
	city: CityState,
	effect: Dictionary,
	sprite_height: int,
	view_size := VIEW_LARGE
) -> Vector2i:
	return IsometricGeometry.transient_effect_position(city, effect, sprite_height, view_size)


static func bridge_effect_position(
	city: CityState,
	effect: Dictionary,
	sprite_height: int,
	view_size := VIEW_LARGE
) -> Vector2i:
	return IsometricGeometry.bridge_effect_position(city, effect, sprite_height, view_size)


static func effect_sprite_id(large_sprite_id: int, view_size := VIEW_LARGE) -> int:
	return IsometricGeometry.effect_sprite_id(large_sprite_id, view_size)


static func _draw_tile(
	output: Variant,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	configuration: Dictionary,
	origin_x: int,
	x: int,
	y: int,
	animation_phase: int,
	include_moving_things: bool,
	include_special_overlays: bool
) -> void:
	if not city.tile_is_visible(x, y):
		CityUndergroundView._draw_tile(
			output, city, palette, sprites, cache, configuration, origin_x,
			x, y, false, true
		)

		return

	var terrain_id := surface_terrain_id(city, x, y)
	var building_id := city.building_id(x, y)
	var terrain_altitude := city.land_altitude(x, y)

	if terrain_id >= 0x10:
		terrain_altitude = city.water_altitude(x, y)

	var screen_x: int = origin_x + (x - y) * int(configuration.half_width)
	var flat_base_y: int = (
		int(configuration.top_margin) + (x + y) * int(configuration.half_height)
	)
	_draw_edge_stacks(
		output, city, palette, sprites, cache, configuration,
		screen_x, flat_base_y, x, y
	)
	var base_y: int = (
		flat_base_y
		- terrain_altitude * int(configuration.altitude_step)
	)

	var is_highway_composite := building_id >= 0x61 and building_id <= 0x6b

	if building_id < 0x70 and not is_highway_composite:
		var terrain := _sprite_image(
			sprites, palette, cache,
			terrain_sprite_id(terrain_id, city.is_water(x, y), configuration.sprite_base),
			false
		)
		_blend_on_base(output, terrain, screen_x, base_y, configuration.tile_height)

	var zone := city.zone_id(x, y)

	if zone > 0 and building_id == 0:
		var zone_image := _sprite_image(
			sprites, palette, cache, int(configuration.sprite_base) + 290 + zone, false
		)
		_blend_on_base(output, zone_image, screen_x, base_y, configuration.tile_height)

	var building_image: Image

	if building_id > 0 and _should_draw_building(city, x, y, building_id):
		var building_base_y := (
			flat_base_y
			- city.object_altitude(x, y) * int(configuration.altitude_step)
		)

		if is_highway_composite:
			_draw_highway_ground(
				output, city, palette, sprites, cache, configuration,
				screen_x, base_y, x, y
			)

		var flip := building_sprite_flip(city, x, y, building_id)
		building_image = _sprite_image(
			sprites, palette, cache, int(configuration.sprite_base) + building_id, flip
		)
		building_base_y += building_baseline_offset(
			building_id, terrain_id, building_image.get_width(), configuration.view_size
		)
		_blend_on_base(
			output, building_image, screen_x, building_base_y, configuration.tile_height
		)
		var traffic_visual := traffic_overlay_visual(city, x, y, configuration.view_size)

		if not traffic_visual.is_empty():
			var traffic_image := _sprite_image(
				sprites, palette, cache, traffic_visual.sprite_id, traffic_visual.flip
			)
			var masked_traffic := _traffic_masked_image(
				traffic_image, building_image, palette, cache,
				"traffic:%d:%d:%d:%d" % [
					traffic_visual.sprite_id, int(traffic_visual.flip),
					building_id, int(flip),
				]
			)
			_blend_on_base(
				output, masked_traffic, screen_x, building_base_y,
				configuration.tile_height
			)

		var power_marker := power_marker_visual(city, x, y, configuration.view_size)

		if not power_marker.is_empty():
			var marker_image := _sprite_image(
				sprites, palette, cache, power_marker.sprite_id, false
			)
			var marker_x := (
				screen_x + int(IntegerMath.div_trunc(building_image.get_width(), 2))
				- int(IntegerMath.div_trunc(marker_image.get_width(), 2))
			)
			_blend_on_base(
				output, marker_image, marker_x, building_base_y, configuration.tile_height
			)

	var dispatch_sprite := dispatch_sprite_id(city, x, y, configuration.view_size)

	if dispatch_sprite > 0:
		var dispatch_image := _sprite_image(
			sprites, palette, cache, dispatch_sprite, false
		)
		var dispatch_x := (
			screen_x + int(configuration.half_width)
			- int(IntegerMath.div_trunc(dispatch_image.get_width(), 2))
		)
		var dispatch_base_y := (
			flat_base_y - city.land_altitude(x, y) * int(configuration.altitude_step)
		)
		_blend_on_base(
			output, dispatch_image, dispatch_x, dispatch_base_y,
			configuration.tile_height
		)

	if include_moving_things:
		var moving_visual := moving_thing_visual(
			city, x, y, configuration.view_size, animation_phase
		)

		if not moving_visual.is_empty():
			_draw_moving_thing(
				output, city, palette, sprites, cache, moving_visual, configuration
			)

	if include_special_overlays:
		var special_visual := special_overlay_visual(
			city, x, y, configuration.view_size, animation_phase
		)

		if not special_visual.is_empty():
			var special_image := _sprite_image(
				sprites, palette, cache, special_visual.sprite_id, special_visual.flip
			)
			var special_x := (
				screen_x + int(configuration.half_width)
				- int(IntegerMath.div_trunc(special_image.get_width(), 2))
			)
			var special_altitude := city.object_altitude(x, y)
			var special_base_y := (
				int(configuration.top_margin)
				+ (x + y) * int(configuration.half_height)
				- special_altitude * int(configuration.altitude_step)
			)
			_blend_on_base(
				output, special_image, special_x, special_base_y,
				configuration.tile_height
			)


static func edge_stack_visuals(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE
) -> Array[Dictionary]:
	return IsometricStaticVisuals.edge_stack_visuals(city, x, y, view_size)


static func _draw_edge_stacks(
	output: Variant,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	configuration: Dictionary,
	screen_x: int,
	flat_base_y: int,
	x: int,
	y: int
) -> void:
	for visual in edge_stack_visuals(city, x, y, configuration.view_size):
		var edge_image := _sprite_image(
			sprites, palette, cache, visual.sprite_id, false
		)
		_blend_on_base(
			output, edge_image, screen_x, flat_base_y - visual.elevation,
			configuration.tile_height
		)


static func _draw_highway_ground(
	output: Variant,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	configuration: Dictionary,
	screen_x: int,
	base_y: int,
	x: int,
	y: int
) -> void:
	for visual in highway_ground_visuals(city, x, y, configuration.view_size, sprites.redraw_small_highway_ground):
		var terrain := _sprite_image(
			sprites, palette, cache, visual.sprite_id, false
		)
		var position: Vector2i = visual.offset
		_blend_on_base(
			output, terrain, screen_x + position.x, base_y + position.y,
			configuration.tile_height
		)


static func highway_ground_visuals(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE,
	redraw_small := false
) -> Array[Dictionary]:
	return IsometricStaticVisuals.highway_ground_visuals(city, x, y, view_size, redraw_small)


static func traffic_overlay_visual(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE
) -> Dictionary:
	return IsometricStaticVisuals.traffic_overlay_visual(city, x, y, view_size)


static func power_marker_visual(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE
) -> Dictionary:
	return IsometricStaticVisuals.power_marker_visual(city, x, y, view_size)


static func fire_overlay_visual(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE, animation_phase := 0
) -> Dictionary:
	return IsometricStaticVisuals.fire_overlay_visual(city, x, y, view_size, animation_phase)


static func special_overlay_visual(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE, animation_phase := 0
) -> Dictionary:
	return IsometricStaticVisuals.special_overlay_visual(city, x, y, view_size, animation_phase)


static func dispatch_sprite_id(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE
) -> int:
	return IsometricStaticVisuals.dispatch_sprite_id(city, x, y, view_size)


static func moving_thing_visual(
	city: CityState,
	x: int,
	y: int,
	view_size := VIEW_LARGE,
	animation_phase := 0
) -> Dictionary:
	return IsometricMovingVisuals.moving_thing_visual(city, x, y, view_size, animation_phase)


static func moving_thing_sprite(thing: Dictionary, view_size := VIEW_LARGE) -> Dictionary:
	return IsometricMovingVisuals.moving_thing_sprite(thing, view_size)


static func train_sprite(
	city: CityState, x: int, y: int, thing: Dictionary
) -> Dictionary:
	return IsometricMovingVisuals.train_sprite(city, x, y, thing)


static func tornado_sprite(
	city: CityState,
	x: int,
	y: int,
	thing: Dictionary,
	record: int,
	view_size := VIEW_LARGE
) -> Dictionary:
	return IsometricMovingVisuals.tornado_sprite(city, x, y, thing, record, view_size)


static func monster_layers(
	city: CityState,
	x: int,
	y: int,
	thing: Dictionary,
	record: int,
	view_size := VIEW_LARGE
) -> Array[Dictionary]:
	return IsometricMovingVisuals.monster_layers(city, x, y, thing, record, view_size)


# For monsters, dx stores body-part flags rather than velocity.
static func monster_pose_layers(
	body_position: Vector2i, dx: int, dy: int, head_frame := 0, view_size := VIEW_LARGE
) -> Array[Dictionary]:
	return IsometricMovingVisuals.monster_pose_layers(body_position, dx, dy, head_frame, view_size)


static func _monster_layer(
	sprite_id: int, screen_x: int, screen_y: int, flip: bool
) -> Dictionary:
	return IsometricMovingVisuals._monster_layer(sprite_id, screen_x, screen_y, flip)


static func _draw_moving_thing(
	output: Variant,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	visual: Dictionary,
	configuration: Dictionary
) -> void:
	for command in moving_thing_draw_commands_for_visual(
		city, sprites, visual, configuration
	):
		var sprite := _sprite_image(
			sprites, palette, cache, command.sprite_id, command.flip
		)

		if command.shadow:
			_blend_shadow(output, sprite, palette, command.position)
		else:
			output.blend_rect(
				sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), command.position
			)


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

	var configuration := view_configuration(view_size)

	if configuration.is_empty():
		return commands

	for diagonal in map_edge * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y

			if x >= map_edge or y >= map_edge:
				continue

			var visual := moving_thing_visual(
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

	var configuration := view_configuration(view_size)

	if configuration.is_empty():
		return commands

	var entries: Array[Dictionary] = []
	var things := city.document.find_chunk("XTHG")

	for record in city.thing_count():
		var offset := record * CityState.THING_RECORD_SIZE

		if things == null or offset >= things.decoded_payload.size() or things.decoded_payload[offset] == 0:
			continue

		var thing := city.thing(record)
		var point := Vector2i(int(thing.get("x", -1)), int(thing.get("y", -1)))

		if (
			int(thing.get("type", 0)) == 0
			or city.index_of(point.x, point.y) < 0
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
				int(IntegerMath.div_trunc(found, map_edge)), found % map_edge
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
			var special_visual := special_overlay_visual(
				city, point.x, point.y, view_size, animation_phase
			)
			var special_command := special_overlay_draw_command(
				city, sprites, point, special_visual, configuration
			)

			if not special_command.is_empty():
				entry_commands.append(special_command)
		else:
			var moving_visual := moving_thing_visual(
				city, point.x, point.y, view_size, animation_phase
			)
			entry_commands = moving_thing_draw_commands_for_visual(
				city, sprites, moving_visual, configuration
			)

		for command in entry_commands:
			command.depth_order = int(entry.order)
			commands.append(command)

	return commands


static func special_overlay_draw_command(
	city: CityState,
	sprites: Sc2SpriteArchive,
	point: Vector2i,
	visual: Dictionary,
	configuration: Dictionary
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if visual.is_empty() or configuration.is_empty():
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
			screen_x + int(configuration.half_width) - int(IntegerMath.div_trunc(entry.width, 2)),
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
	configuration: Dictionary
) -> Array[Dictionary]:
	var map_edge: int = city.map_size if city != null else 128
	var commands: Array[Dictionary] = []

	if visual.is_empty() or configuration.is_empty():
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
			center_x - int(IntegerMath.div_trunc(entry.width, 2)),
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
			center_x - int(IntegerMath.div_trunc(entry.width, 2)),
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


static func static_occlusion_commands(
	city: CityState, sprites: Sc2SpriteArchive, view_size := VIEW_LARGE
) -> Array[Dictionary]:
	var map_edge: int = city.map_size if city != null else 128
	var commands: Array[Dictionary] = []

	if city == null or not city.is_valid() or sprites == null or not sprites.is_valid():
		return commands

	var configuration := view_configuration(view_size)

	if configuration.is_empty():
		return commands

	var origin_x: int = (
		int(configuration.side_margin)
		+ map_edge * int(configuration.half_width)
	)

	for diagonal in map_edge * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y

			if x >= map_edge or y >= map_edge:
				continue

			var order := (x + y) * map_edge + y
			commands.append_array(_tile_occlusion_commands(
				city, sprites, configuration, origin_x, x, y, order
			))

	return commands


static func patch_static_occlusion_commands(
	base_commands: Array[Dictionary],
	city: CityState,
	sprites: Sc2SpriteArchive,
	dirty_indices: PackedInt32Array,
	view_size := VIEW_LARGE
) -> Array[Dictionary]:
	var map_edge: int = city.map_size if city != null else 128

	if (
		base_commands.is_empty()
		or city == null
		or not city.is_valid()
		or sprites == null
		or not sprites.is_valid()
	):
		return static_occlusion_commands(city, sprites, view_size)

	var configuration := view_configuration(view_size)

	if configuration.is_empty():
		return []

	var origin_x: int = (
		int(configuration.side_margin)
		+ map_edge * int(configuration.half_width)
	)
	var replacements := {}

	for value in dirty_indices:
		var index := int(value)

		if index < 0 or index >= (map_edge * map_edge):
			continue

		var x := int(IntegerMath.div_trunc(index, map_edge))
		var y := index % map_edge
		var order := (x + y) * map_edge + y
		replacements[order] = _tile_occlusion_commands(
			city, sprites, configuration, origin_x, x, y, order
		)

	if replacements.is_empty():
		return base_commands.duplicate()

	var commands: Array[Dictionary] = []
	var inserted := {}

	for command in base_commands:
		var order := int(command.get("depth_order", -1))

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


static func _tile_occlusion_commands(
	city: CityState,
	sprites: Sc2SpriteArchive,
	configuration: Dictionary,
	origin_x: int,
	x: int,
	y: int,
	draw_order: int
) -> Array[Dictionary]:
	var map_edge: int = city.map_size if city != null else 128
	var commands: Array[Dictionary] = []

	if not city.tile_is_visible(x, y):
		return commands

	var terrain_id := surface_terrain_id(city, x, y)
	var building_id := city.building_id(x, y)
	var terrain_altitude := city.land_altitude(x, y)

	if terrain_id >= 0x10:
		terrain_altitude = city.water_altitude(x, y)

	var screen_x := origin_x + (x - y) * int(configuration.half_width)
	var flat_base_y := (
		int(configuration.top_margin) + (x + y) * int(configuration.half_height)
	)

	if x == map_edge - 1 or y == map_edge - 1:
		for visual in edge_stack_visuals(city, x, y, configuration.view_size):
			_append_occluder(
				commands, sprites, visual.sprite_id, false,
				Vector2i(
					screen_x,
					flat_base_y - visual.elevation + int(configuration.tile_height)
				),
				draw_order
			)

	var base_y := flat_base_y - terrain_altitude * int(configuration.altitude_step)
	var is_highway_composite := building_id >= 0x61 and building_id <= 0x6b

	if building_id < 0x70 and not is_highway_composite:
		_append_occluder(
			commands, sprites,
			terrain_sprite_id(terrain_id, city.is_water(x, y), configuration.sprite_base),
			false, Vector2i(screen_x, base_y + int(configuration.tile_height)), draw_order
		)

	var zone := city.zone_id(x, y)

	if zone > 0 and building_id == 0:
		_append_occluder(
			commands, sprites, int(configuration.sprite_base) + 290 + zone, false,
			Vector2i(screen_x, base_y + int(configuration.tile_height)), draw_order
		)

	if building_id > 0 and _should_draw_building(city, x, y, building_id):
		if is_highway_composite:
			for visual in highway_ground_visuals(
				city, x, y, configuration.view_size, sprites.redraw_small_highway_ground
			):
				_append_occluder(
					commands, sprites, visual.sprite_id,
					false,
					Vector2i(screen_x, base_y + int(configuration.tile_height))
						+ Vector2i(visual.offset),
					draw_order
				)

		var building_flip := building_sprite_flip(city, x, y, building_id)
		var building_sprite_id := int(configuration.sprite_base) + building_id
		var building_entry = sprites.find_sprite(building_sprite_id)

		if building_entry != null:
			var building_base_y := (
				flat_base_y
				- city.object_altitude(x, y) * int(configuration.altitude_step)
			) + building_baseline_offset(
				building_id, terrain_id, building_entry.width, configuration.view_size
			)
			_append_occluder(
				commands, sprites, building_sprite_id, building_flip,
				Vector2i(screen_x, building_base_y + int(configuration.tile_height)),
				draw_order,
				train_power_foreground_reference_sprite_id(
					building_id, int(configuration.sprite_base)
				)
			)

			if not commands.is_empty():
				configure_train_foreground(commands[-1], building_id, configuration)

			var power_marker := power_marker_visual(city, x, y, configuration.view_size)

			if not power_marker.is_empty():
				var marker_entry = sprites.find_sprite(power_marker.sprite_id)

				if marker_entry != null:
					_append_occluder(
						commands, sprites, power_marker.sprite_id, false,
						Vector2i(
							screen_x + int(building_entry.width / 2)
								- int(marker_entry.width / 2),
							building_base_y + int(configuration.tile_height)
						),
						draw_order
					)

	var dispatch_sprite := dispatch_sprite_id(city, x, y, configuration.view_size)

	if dispatch_sprite > 0:
		var dispatch_entry = sprites.find_sprite(dispatch_sprite)

		if dispatch_entry != null:
			_append_occluder(
				commands, sprites, dispatch_sprite, false,
				Vector2i(
					screen_x + int(configuration.half_width)
						- int(dispatch_entry.width / 2),
					flat_base_y
						- city.land_altitude(x, y) * int(configuration.altitude_step)
						+ int(configuration.tile_height)
				),
				draw_order
			)

	return commands


static func _append_occluder(
	commands: Array[Dictionary],
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

	var command := {
		"sprite_id": sprite_id,
		"flip": flip,
		"position": base_position - Vector2i(0, entry.height),
		"size": Vector2i(entry.width, entry.height),
		"depth_order": draw_order,
	}

	if train_foreground_reference_sprite_id != 0:
		command.train_foreground_reference_sprite_id = (
			train_foreground_reference_sprite_id
		)

	commands.append(command)


static func configure_train_foreground(command: Dictionary, building_id: int, configuration: Dictionary) -> void:
	var reference := train_power_foreground_reference_sprite_id(building_id, int(configuration.sprite_base))

	if reference != 0:
		command.train_foreground_reference_sprite_id = reference

	command.train_ignore = (building_id >= 0x0e and building_id <= 0x1c) or building_id in [0x43, 0x44, 0x47, 0x48]

	if (building_id >= 0x49 and building_id <= 0x50) or (building_id >= 0x61 and building_id <= 0x6b):
		command.train_deck_thickness = int(configuration.view_size) + 1

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


static func foreground_difference_mask(sprite: Image, background: Image) -> Image:
	return IsometricPixelOperations.foreground_difference_mask(sprite, background)


static func build_occlusion_grid(
	commands: Array[Dictionary], divisor: int
) -> Dictionary:
	return IsometricPixelOperations.build_occlusion_grid(commands, divisor)


static func occlusion_candidate_indices(
	grid: Dictionary, bounds: Rect2i
) -> Array[int]:
	return IsometricPixelOperations.occlusion_candidate_indices(grid, bounds)


static func occlude_dynamic_with_mask(
	sprite: Image,
	occluder_mask: Image,
	position: Vector2i,
	index_image: Image = null,
	same_tile_foreground_indices := PackedInt32Array(),
	index_reader := Callable()
) -> Dictionary:
	return IsometricPixelOperations.occlude_dynamic_with_mask(
		sprite, occluder_mask, position, index_image, same_tile_foreground_indices, index_reader
	)


static func static_visual_signature(city: CityState, view_size := VIEW_LARGE) -> Array:
	return IsometricStaticVisuals.static_visual_signature(city, view_size)


static func _static_text_overlay_signature(city: CityState) -> int:
	return IsometricStaticVisuals._static_text_overlay_signature(city)


static func shadow_color(palette: Sc2Palette, destination: Color) -> Color:
	return IsometricPixelOperations.shadow_color(palette, destination)


static func shadow_palette_index(index: int) -> int:
	return IsometricPixelOperations.shadow_palette_index(index)


static func _blend_shadow(
	output: Image, mask: Image, palette: Sc2Palette, destination: Vector2i
) -> void:
	IsometricPixelOperations._blend_shadow(output, mask, palette, destination)


# four occupied corners, one sprite, compass picks the winner
static func _should_draw_building(city: CityState, x: int, y: int, building_id: int) -> bool:
	return IsometricStaticVisuals._should_draw_building(city, x, y, building_id)


# for buildings, flipped means unflipped every other compass turn
static func building_sprite_flip(
	city: CityState, x: int, y: int, building_id: int
) -> bool:
	return IsometricStaticVisuals.building_sprite_flip(city, x, y, building_id)


# These sprites use their width to set the vertical offset.
static func building_baseline_offset(
	building_id: int, terrain_id: int, sprite_width: int, view_size := VIEW_LARGE
) -> int:
	return IsometricStaticVisuals.building_baseline_offset(building_id, terrain_id, sprite_width, view_size)


static func _sprite_image(
	sprites: Sc2SpriteArchive,
	palette: Sc2Palette,
	cache: Dictionary,
	sprite_id: int,
	flip: bool
) -> Image:
	return IsometricPixelOperations._sprite_image(sprites, palette, cache, sprite_id, flip)


static func _blend_on_base(
	output: Variant,
	sprite: Image,
	x: int,
	base_y: int,
	tile_height := TILE_HEIGHT
) -> void:
	IsometricPixelOperations._blend_on_base(output, sprite, x, base_y, tile_height)


static func _traffic_masked_image(
	sprite: Image,
	surface: Image,
	palette: Sc2Palette,
	cache: Dictionary = {},
	cache_key := ""
) -> Image:
	return IsometricPixelOperations._traffic_masked_image(sprite, surface, palette, cache, cache_key)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func highway_train_deck_mask(surface: Image, thickness: int) -> Image:
	return IsometricPixelOperations.highway_train_deck_mask(surface, thickness)
