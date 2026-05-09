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
	return IsometricImageRender.create_image(
		city, palette, sprites, view_size, animation_phase, include_moving_things, transparent_background,
		validate_required_assets, include_special_overlays
	)


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
	return IsometricImageRender.patch_static_image(
		base_image, city, palette, sprites, dirty_indices, view_size, animation_phase, copy_image
	)


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
	IsometricImageRender._draw_tile(
		output, city, palette, sprites, cache, configuration, origin_x, x, y, animation_phase,
		include_moving_things, include_special_overlays
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
	IsometricImageRender._draw_edge_stacks(output, city, palette, sprites, cache, configuration, screen_x, flat_base_y, x, y)


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
	IsometricImageRender._draw_highway_ground(output, city, palette, sprites, cache, configuration, screen_x, base_y, x, y)


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
	IsometricImageRender._draw_moving_thing(output, city, palette, sprites, cache, visual, configuration)


static func moving_thing_draw_commands(
	city: CityState,
	sprites: Sc2SpriteArchive,
	view_size := VIEW_LARGE,
	animation_phase := 0
) -> Array[Dictionary]:
	return IsometricDynamicCommands.moving_thing_draw_commands(city, sprites, view_size, animation_phase)


static func dynamic_draw_commands(
	city: CityState,
	sprites: Sc2SpriteArchive,
	view_size := VIEW_LARGE,
	animation_phase := 0
) -> Array[Dictionary]:
	return IsometricDynamicCommands.dynamic_draw_commands(city, sprites, view_size, animation_phase)


static func special_overlay_draw_command(
	city: CityState,
	sprites: Sc2SpriteArchive,
	point: Vector2i,
	visual: Dictionary,
	configuration: Dictionary
) -> Dictionary:
	return IsometricDynamicCommands.special_overlay_draw_command(city, sprites, point, visual, configuration)


static func moving_thing_draw_commands_for_visual(
	city: CityState,
	sprites: Sc2SpriteArchive,
	visual: Dictionary,
	configuration: Dictionary
) -> Array[Dictionary]:
	return IsometricDynamicCommands.moving_thing_draw_commands_for_visual(city, sprites, visual, configuration)


static func _moving_draw_command(
	sprite_id: int, flip: bool, position: Vector2i, shadow: bool
) -> Dictionary:
	return IsometricDynamicCommands._moving_draw_command(sprite_id, flip, position, shadow)


static func static_occlusion_commands(
	city: CityState, sprites: Sc2SpriteArchive, view_size := VIEW_LARGE
) -> Array[Dictionary]:
	return IsometricStaticOcclusion.static_occlusion_commands(city, sprites, view_size)


static func patch_static_occlusion_commands(
	base_commands: Array[Dictionary],
	city: CityState,
	sprites: Sc2SpriteArchive,
	dirty_indices: PackedInt32Array,
	view_size := VIEW_LARGE
) -> Array[Dictionary]:
	return IsometricStaticOcclusion.patch_static_occlusion_commands(base_commands, city, sprites, dirty_indices, view_size)


static func _tile_occlusion_commands(
	city: CityState,
	sprites: Sc2SpriteArchive,
	configuration: Dictionary,
	origin_x: int,
	x: int,
	y: int,
	draw_order: int
) -> Array[Dictionary]:
	return IsometricStaticOcclusion._tile_occlusion_commands(city, sprites, configuration, origin_x, x, y, draw_order)


static func _append_occluder(
	commands: Array[Dictionary],
	sprites: Sc2SpriteArchive,
	sprite_id: int,
	flip: bool,
	base_position: Vector2i,
	draw_order: int,
	train_foreground_reference_sprite_id := 0
) -> void:
	IsometricStaticOcclusion._append_occluder(
		commands, sprites, sprite_id, flip, base_position, draw_order, train_foreground_reference_sprite_id
	)


static func configure_train_foreground(command: Dictionary, building_id: int, configuration: Dictionary) -> void:
	IsometricStaticOcclusion.configure_train_foreground(command, building_id, configuration)


static func train_power_foreground_reference_sprite_id(
	building_id: int, sprite_base := 1000
) -> int:
	return IsometricStaticOcclusion.train_power_foreground_reference_sprite_id(building_id, sprite_base)


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
	return IsometricImageRender._failure(message)


static func highway_train_deck_mask(surface: Image, thickness: int) -> Image:
	return IsometricPixelOperations.highway_train_deck_mask(surface, thickness)
