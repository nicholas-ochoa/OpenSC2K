class_name IsometricImageRender
extends IsometricConstants


@warning_ignore_start("integer_division")


class PatchResult extends AssetImageResult:
	var native_rect := Rect2i()
	var output_rect := Rect2i()
	var tiles_drawn := 0

	static func rejected(message: String) -> PatchResult:
		var result := PatchResult.new()
		result.error = message

		return result


static func create_image(
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	view_size := VIEW_LARGE,
	animation_phase := 0,
	include_moving_things := true,
	transparent_background := false,
	validate_required_assets := true,
	include_special_overlays := true,
	progress := Callable()
) -> AssetImageResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return AssetImageResult.failure("city is invalid")

	if palette == null or not palette.is_valid():
		return AssetImageResult.failure("palette is invalid")

	if sprites == null or not sprites.is_valid():
		return AssetImageResult.failure("large sprite archive is invalid")

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return AssetImageResult.failure("city view size is invalid")

	if validate_required_assets:
		var asset_errors := IsometricStaticVisuals.validate_assets(city, sprites, view_size)

		if not asset_errors.is_empty():
			return AssetImageResult.failure(asset_errors[0])

	var output_size := IsometricGeometry.output_size_for_view(view_size, map_edge)
	var output := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT if transparent_background else Color("18242c"))
	var origin_x: int = configuration.side_margin + map_edge * configuration.half_width
	var cache: Dictionary = {}

	for diagonal in map_edge * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y

			if x >= map_edge or y >= map_edge:
				continue

			draw_tile(
				output, city, palette, sprites, cache, configuration,
				origin_x, x, y, animation_phase, include_moving_things,
				include_special_overlays
			)

		if progress.is_valid():
			progress.call(float(diagonal + 1) / float(map_edge * 2 - 1))

	if palette.is_index_encoding:
		output.convert(Image.FORMAT_LA8 if transparent_background else Image.FORMAT_L8)

	var result := AssetImageResult.new()
	result.ok = true
	result.image = output
	result.error = ""

	return result


static func patch_static_image(
	base_image: Image,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	dirty_indices: PackedInt32Array,
	view_size := VIEW_LARGE,
	animation_phase := 0,
	copy_image := true
) -> PatchResult:
	var map_edge: int = city.map_size if city != null else 128

	if base_image == null or base_image.is_empty():
		return PatchResult.rejected("base city image is invalid")

	if city == null or not city.is_valid():
		return PatchResult.rejected("city is invalid")

	if palette == null or not palette.is_valid() or not palette.is_index_encoding:
		return PatchResult.rejected("indexed palette is invalid")

	if sprites == null or not sprites.is_valid():
		return PatchResult.rejected("sprite archive is invalid")

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return PatchResult.rejected("city view size is invalid")

	var native_size := IsometricGeometry.output_size_for_view(view_size, map_edge)
	var output_scale := 1

	if base_image.get_size() == IsometricGeometry.output_size_for_view(VIEW_LARGE, map_edge):
		output_scale = int(configuration.divisor)
	elif base_image.get_size() != native_size:
		return PatchResult.rejected("base city image has the wrong size")

	var sprite_limit := IsometricGeometry.maximum_sprite_size(sprites)
	var native_rect := IsometricGeometry.dirty_screen_rect(
		dirty_indices, sprites, view_size, sprite_limit, map_edge
	)

	if native_rect.get_area() <= 0:
		return PatchResult.rejected("dirty city region is empty")

	var local_configuration := configuration.copy()
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
	var bottom_extra := int(configuration.tile_height) + int(sprite_limit.x / 4) + 1
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

			if not IsometricGeometry.potential_tile_bounds(
				configuration, sprite_limit, x, y, map_edge
			).intersects(native_rect):
				continue

			draw_tile(
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

	var result := PatchResult.new()
	result.ok = true
	result.image = patched
	result.native_rect = native_rect
	result.output_rect = output_rect
	result.tiles_drawn = tiles_drawn
	result.error = ""

	return result


# paint one map tile into `output`, in back-to-front order
# `output` is an `Image` or any recorder with the same `blend_rect` call
# `origin_x` is the screen column of tile (0, 0). shift it, or shift
# `configuration.top_margin`, to paint into a sub-rectangle of the map
# `cache` holds decoded sprites and belongs to the caller
# the tile order and the painted pixels are the same for every caller
static func draw_tile(
	output: Variant,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	configuration: CityViewConfiguration,
	origin_x: int,
	x: int,
	y: int,
	animation_phase: int,
	include_moving_things: bool,
	include_special_overlays: bool
) -> void:
	if not city.tile_is_visible(x, y):
		CityUndergroundView.draw_tile(
			output, city, palette, sprites, cache, configuration, origin_x,
			x, y, false, true
		)

		return

	var terrain_id := IsometricGeometry.surface_terrain_id(city, x, y)
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
		var terrain := IsometricPixelOperations.sprite_image(
			sprites, palette, cache,
			IsometricGeometry.terrain_sprite_id(terrain_id, city.is_water(x, y), configuration.sprite_base),
			false
		)
		IsometricPixelOperations._blend_on_base(output, terrain, screen_x, base_y, configuration.tile_height)

	var zone := city.zone_id(x, y)

	if zone > 0 and building_id == 0:
		var zone_image := IsometricPixelOperations.sprite_image(
			sprites, palette, cache, int(configuration.sprite_base) + 290 + zone, false
		)
		IsometricPixelOperations._blend_on_base(output, zone_image, screen_x, base_y, configuration.tile_height)

	var building_image: Image

	if building_id > 0 and IsometricStaticVisuals._should_draw_building(city, x, y, building_id):
		var building_base_y := (
			flat_base_y
			- city.object_altitude(x, y) * int(configuration.altitude_step)
		)

		if is_highway_composite:
			_draw_highway_ground(
				output, city, palette, sprites, cache, configuration,
				screen_x, base_y, x, y
			)

		var flip := IsometricStaticVisuals.building_sprite_flip(city, x, y, building_id)
		building_image = IsometricPixelOperations.sprite_image(
			sprites, palette, cache, int(configuration.sprite_base) + building_id, flip
		)
		building_base_y += IsometricStaticVisuals.building_baseline_offset(
			building_id, terrain_id, building_image.get_width(), configuration.view_size
		)
		IsometricPixelOperations._blend_on_base(
			output, building_image, screen_x, building_base_y, configuration.tile_height
		)
		var traffic_visual := IsometricStaticVisuals.traffic_overlay_visual(city, x, y, configuration.view_size)

		if traffic_visual != null:
			var traffic_image := IsometricPixelOperations.sprite_image(
				sprites, palette, cache, traffic_visual.sprite_id, traffic_visual.flip
			)
			var masked_traffic := IsometricPixelOperations._traffic_masked_image(
				traffic_image, building_image, palette, cache,
				"traffic:%d:%d:%d:%d" % [
					traffic_visual.sprite_id, int(traffic_visual.flip),
					building_id, int(flip),
				]
			)
			IsometricPixelOperations._blend_on_base(
				output, masked_traffic, screen_x, building_base_y,
				configuration.tile_height
			)

		var power_marker := IsometricStaticVisuals.power_marker_visual(city, x, y, configuration.view_size)

		if power_marker != null:
			var marker_image := IsometricPixelOperations.sprite_image(
				sprites, palette, cache, power_marker.sprite_id, false
			)
			var marker_x := (
				screen_x + int(building_image.get_width() / 2)
				- int(marker_image.get_width() / 2)
			)
			IsometricPixelOperations._blend_on_base(
				output, marker_image, marker_x, building_base_y, configuration.tile_height
			)

	var dispatch_sprite := IsometricStaticVisuals.dispatch_sprite_id(city, x, y, configuration.view_size)

	if dispatch_sprite > 0:
		var dispatch_image := IsometricPixelOperations.sprite_image(
			sprites, palette, cache, dispatch_sprite, false
		)
		var dispatch_x := (
			screen_x + int(configuration.half_width)
			- int(dispatch_image.get_width() / 2)
		)
		var dispatch_base_y := (
			flat_base_y - city.land_altitude(x, y) * int(configuration.altitude_step)
		)
		IsometricPixelOperations._blend_on_base(
			output, dispatch_image, dispatch_x, dispatch_base_y,
			configuration.tile_height
		)

	if include_moving_things:
		var moving_visual := IsometricMovingVisuals.moving_thing_visual(
			city, x, y, configuration.view_size, animation_phase
		)

		if moving_visual != null:
			draw_moving_thing(
				output, city, palette, sprites, cache, moving_visual, configuration
			)

	if include_special_overlays:
		var special_visual := IsometricStaticVisuals.special_overlay_visual(
			city, x, y, configuration.view_size, animation_phase
		)

		if special_visual != null:
			var special_image := IsometricPixelOperations.sprite_image(
				sprites, palette, cache, special_visual.sprite_id, special_visual.flip
			)
			var special_x := (
				screen_x + int(configuration.half_width)
				- int(special_image.get_width() / 2)
			)
			var special_altitude := city.object_altitude(x, y)
			var special_base_y := (
				int(configuration.top_margin)
				+ (x + y) * int(configuration.half_height)
				- special_altitude * int(configuration.altitude_step)
			)
			IsometricPixelOperations._blend_on_base(
				output, special_image, special_x, special_base_y,
				configuration.tile_height
			)


static func _draw_edge_stacks(
	output: Variant,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	configuration: CityViewConfiguration,
	screen_x: int,
	flat_base_y: int,
	x: int,
	y: int
) -> void:
	for visual in IsometricStaticVisuals.edge_stack_visuals(city, x, y, configuration.view_size):
		var edge_image := IsometricPixelOperations.sprite_image(
			sprites, palette, cache, visual.sprite_id, false
		)
		IsometricPixelOperations._blend_on_base(
			output, edge_image, screen_x, flat_base_y - visual.elevation,
			configuration.tile_height
		)


static func _draw_highway_ground(
	output: Variant,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	configuration: CityViewConfiguration,
	screen_x: int,
	base_y: int,
	x: int,
	y: int
) -> void:
	for visual in IsometricStaticVisuals.highway_ground_visuals(city, x, y, configuration.view_size, sprites.redraw_small_highway_ground):
		var terrain := IsometricPixelOperations.sprite_image(
			sprites, palette, cache, visual.sprite_id, false
		)
		var position: Vector2i = visual.offset
		IsometricPixelOperations._blend_on_base(
			output, terrain, screen_x + position.x, base_y + position.y,
			configuration.tile_height
		)


# paint the moving object of one visual into `output`
# shadow commands darken the pixels that are already present
# `offset` shifts every command, for painting into a sub-rectangle
static func draw_moving_thing(
	output: Variant,
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	cache: Dictionary,
	visual: IsometricMovingVisuals.Visual,
	configuration: CityViewConfiguration,
	offset := Vector2i.ZERO
) -> void:
	for command in IsometricDynamicCommands.moving_thing_draw_commands_for_visual(
		city, sprites, visual, configuration
	):
		var sprite := IsometricPixelOperations.sprite_image(
			sprites, palette, cache, command.sprite_id, command.flip
		)
		var position: Vector2i = command.position + offset

		if command.shadow:
			IsometricPixelOperations._blend_shadow(output, sprite, palette, position)
		else:
			output.blend_rect(
				sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), position
			)
