class_name CityIsometricRenderer
extends IsometricConstants
# Public entry points for view/isometric/. Application code uses this class;
# tests can call the implementation classes directly.


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
	return IsometricImageRender.create_image(
		city, palette, sprites, view_size, animation_phase, include_moving_things, transparent_background,
		validate_required_assets, include_special_overlays, progress
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
) -> IsometricImageRender.PatchResult:
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


# return the largest sprite width and height in the archive
# reuse one result for every `potential_tile_bounds` call in a pass
static func maximum_sprite_size(sprites: Sc2SpriteArchive) -> Vector2i:
	return IsometricGeometry.maximum_sprite_size(sprites)


# return the screen rectangle that the sprites of one tile can touch
# it is a conservative bound, not the painted area. region renderers cull
# with it. `dirty_screen_rect` merges it for a set of tiles
static func potential_tile_bounds(
	configuration: CityViewConfiguration, sprite_limit: Vector2i, x: int, y: int,
	map_edge: int = 128,
) -> Rect2i:
	return IsometricGeometry.potential_tile_bounds(configuration, sprite_limit, x, y, map_edge)


# return the diagonals and screen columns whose tiles can touch `bounds`
# a region painter walks `first_diagonal` to `last_diagonal` in order
static func region_tile_span(
	configuration: CityViewConfiguration, sprite_limit: Vector2i, bounds: Rect2i,
	map_edge: int, underground: bool
) -> CityRegionTileSpan:
	return IsometricGeometry.region_tile_span(configuration, sprite_limit, bounds, map_edge, underground)


# return the first and last y of the tiles on `diagonal` inside `span`
static func diagonal_rows(span: CityRegionTileSpan, diagonal: int, map_edge: int) -> Vector2i:
	return IsometricGeometry.diagonal_rows(span, diagonal, map_edge)


static func surface_terrain_id(city: CityState, x: int, y: int) -> int:
	return IsometricGeometry.surface_terrain_id(city, x, y)


static func terrain_sprite_id(terrain: int, water_flag: bool, sprite_base := 1000) -> int:
	return IsometricGeometry.terrain_sprite_id(terrain, water_flag, sprite_base)


static func view_configuration(view_size: int) -> CityViewConfiguration:
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
	effect: EffectEvent,
	sprite_height: int,
	view_size := VIEW_LARGE
) -> Vector2i:
	return IsometricGeometry.transient_effect_position(city, effect, sprite_height, view_size)


static func effect_sprite_id(large_sprite_id: int, view_size := VIEW_LARGE) -> int:
	return IsometricGeometry.effect_sprite_id(large_sprite_id, view_size)


# paint one map tile into `output`, in back-to-front order
# `output` is an `Image` or any recorder with the same `blend_rect` call
# `origin_x` is the screen column of tile (0, 0). shift it, or shift
# `configuration.top_margin`, to paint into a sub-rectangle of the map
# `cache` holds decoded sprites and belongs to the caller
# this is the one tile painter. the city image, the region renderers, the
# gpu geometry builder, and the previews all paint the same pixels
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
	IsometricImageRender.draw_tile(
		output, city, palette, sprites, cache, configuration, origin_x, x, y, animation_phase,
		include_moving_things, include_special_overlays
	)


static func moving_thing_visual(
	city: CityState,
	x: int,
	y: int,
	view_size := VIEW_LARGE,
	animation_phase := 0
) -> IsometricMovingVisuals.Visual:
	return IsometricMovingVisuals.moving_thing_visual(city, x, y, view_size, animation_phase)


static func moving_thing_sprite(thing: ThingRecord, view_size := VIEW_LARGE) -> IsometricMovingVisuals.Sprite:
	return IsometricMovingVisuals.moving_thing_sprite(thing, view_size)


static func train_sprite(
	city: CityState, x: int, y: int, thing: ThingRecord
) -> IsometricMovingVisuals.Sprite:
	return IsometricMovingVisuals.train_sprite(city, x, y, thing)


static func tornado_sprite(
	city: CityState,
	x: int,
	y: int,
	thing: ThingRecord,
	record: int,
	view_size := VIEW_LARGE
) -> IsometricMovingVisuals.Sprite:
	return IsometricMovingVisuals.tornado_sprite(city, x, y, thing, record, view_size)


# For monsters, dx stores body-part flags rather than velocity.
static func monster_pose_layers(
	body_position: Vector2i, dx: int, dy: int, head_frame := 0, view_size := VIEW_LARGE
) -> Array[IsometricMovingVisuals.Layer]:
	return IsometricMovingVisuals.monster_pose_layers(body_position, dx, dy, head_frame, view_size)


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
	IsometricImageRender.draw_moving_thing(output, city, palette, sprites, cache, visual, configuration, offset)


static func dynamic_draw_commands(
	city: CityState,
	sprites: Sc2SpriteArchive,
	view_size := VIEW_LARGE,
	animation_phase := 0
) -> Array[CityDynamicCommand]:
	return IsometricDynamicCommands.dynamic_draw_commands(city, sprites, view_size, animation_phase)


static func moving_thing_draw_commands_for_visual(
	city: CityState,
	sprites: Sc2SpriteArchive,
	visual: IsometricMovingVisuals.Visual,
	configuration: CityViewConfiguration
) -> Array[CityDynamicCommand]:
	return IsometricDynamicCommands.moving_thing_draw_commands_for_visual(city, sprites, visual, configuration)


static func static_occlusion_commands(
	city: CityState, sprites: Sc2SpriteArchive, view_size := VIEW_LARGE
) -> Array[CityStaticCommand]:
	return IsometricStaticOcclusion.static_occlusion_commands(city, sprites, view_size)


static func patch_static_occlusion_commands(
	base_commands: Array[CityStaticCommand],
	city: CityState,
	sprites: Sc2SpriteArchive,
	dirty_indices: PackedInt32Array,
	view_size := VIEW_LARGE
) -> Array[CityStaticCommand]:
	return IsometricStaticOcclusion.patch_static_occlusion_commands(base_commands, city, sprites, dirty_indices, view_size)


# return the foreground occluder commands of one tile
# this is the per-tile form of `static_occlusion_commands`. a caller that
# paints tiles with `draw_tile` uses this for the foreground of the same
# tile, with the same `draw_order` rule
static func tile_occlusion_commands(
	city: CityState,
	sprites: Sc2SpriteArchive,
	configuration: CityViewConfiguration,
	origin_x: int,
	x: int,
	y: int,
	draw_order: int
) -> Array[CityStaticCommand]:
	return IsometricStaticOcclusion.tile_occlusion_commands(city, sprites, configuration, origin_x, x, y, draw_order)


static func configure_train_foreground(command: CityStaticCommand, building_id: int, configuration: CityViewConfiguration) -> void:
	IsometricStaticOcclusion.configure_train_foreground(command, building_id, configuration)


static func foreground_difference_mask(sprite: Image, background: Image) -> Image:
	return IsometricPixelOperations.foreground_difference_mask(sprite, background)


static func build_occlusion_grid(
	commands: Array[CityStaticCommand], divisor: int
) -> Dictionary[Vector2i, Array]:
	return IsometricPixelOperations.build_occlusion_grid(commands, divisor)


static func occlusion_candidate_indices(
	grid: Dictionary[Vector2i, Array], bounds: Rect2i
) -> Array[int]:
	return IsometricPixelOperations.occlusion_candidate_indices(grid, bounds)


static func occlude_dynamic_with_mask(
	sprite: Image,
	occluder_mask: Image,
	position: Vector2i,
	index_image: Image = null,
	same_tile_foreground_indices := PackedInt32Array(),
	index_reader := Callable()
) -> IsometricPixelOperations.OcclusionResult:
	return IsometricPixelOperations.occlude_dynamic_with_mask(
		sprite, occluder_mask, position, index_image, same_tile_foreground_indices, index_reader
	)


static func static_visual_signature(city: CityState, view_size := VIEW_LARGE) -> Array:
	return IsometricStaticVisuals.static_visual_signature(city, view_size)


static func shadow_palette_index(index: int) -> int:
	return IsometricPixelOperations.shadow_palette_index(index)


# These sprites use their width to set the vertical offset.
static func building_baseline_offset(
	building_id: int, terrain_id: int, sprite_width: int, view_size := VIEW_LARGE
) -> int:
	return IsometricStaticVisuals.building_baseline_offset(building_id, terrain_id, sprite_width, view_size)


# return the decoded sprite image, flipped on request
# `cache` belongs to the caller and holds the result. a caller that shares
# one cache with `draw_tile` gets the same image instances, so image
# identity stays usable as a sprite key
# the returned image belongs to the cache. do not change it
static func sprite_image(
	sprites: Sc2SpriteArchive,
	palette: Sc2Palette,
	cache: Dictionary,
	sprite_id: int,
	flip: bool
) -> Image:
	return IsometricPixelOperations.sprite_image(sprites, palette, cache, sprite_id, flip)


static func highway_train_deck_mask(surface: Image, thickness: int) -> Image:
	return IsometricPixelOperations.highway_train_deck_mask(surface, thickness)
