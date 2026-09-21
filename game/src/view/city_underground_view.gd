class_name CityUndergroundView
extends RefCounted

const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

const Geometry = preload("res://src/view/isometric/geometry.gd")

const TERRAIN_WIREFRAME_FIRST := 0x131
const SUBWAY_AND_PIPE_FIRST := 0x13e
const PIPED_TERRAIN := 0x15f
const DEEP_TUNNEL := 0x160
const WATERED_PIPE_OFFSET := 0x74
const WATERED_TERRAIN := 0x1d3
const WHITE_PALETTE_INDEX := 0xff


static func create_image(
	city: CityState,
	palette: Sc2Palette,
	sprites: Sc2SpriteArchive,
	view_size := Geometry.VIEW_LARGE,
	validate_required_assets := true,
	show_pipes := true,
	show_subways := true, show_water_mains := true,
	transparent_background := false,
	progress := Callable()
) -> AssetImageResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return AssetImageResult.failure("city is invalid")

	if palette == null or not palette.is_valid():
		return AssetImageResult.failure("palette is invalid")

	if sprites == null or not sprites.is_valid():
		return AssetImageResult.failure("sprite archive is invalid")

	var configuration := Geometry.view_configuration(view_size)

	if configuration == null:
		return AssetImageResult.failure("underground view size is invalid")

	if validate_required_assets:
		var asset_errors := validate_assets(city, sprites, view_size, show_pipes, show_subways, show_water_mains)

		if not asset_errors.is_empty():
			return AssetImageResult.failure(asset_errors[0])

	var output_size := Geometry.output_size_for_view(view_size, map_edge)
	var output := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT if transparent_background else Color8(
		WHITE_PALETTE_INDEX,
		WHITE_PALETTE_INDEX,
		WHITE_PALETTE_INDEX,
		255,
	))
	var origin_x: int = (
		configuration.side_margin
		+ map_edge * configuration.half_width
	)
	var cache: Dictionary = {}

	for diagonal in map_edge * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y

			if x >= map_edge or y >= map_edge:
				continue

			draw_tile(
				output, city, palette, sprites, cache, configuration, origin_x, x, y,
				show_pipes, show_subways, show_water_mains
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


static func validate_assets(
	city: CityState,
	sprites: Sc2SpriteArchive,
	view_size := Geometry.VIEW_LARGE,
	show_pipes := true,
	show_subways := true, show_water_mains := true
) -> PackedStringArray:
	var map_edge: int = city.map_size if city != null else 128
	var errors := PackedStringArray()

	if city == null or not city.is_valid():
		errors.append("city is invalid")

		return errors

	if sprites == null or not sprites.is_valid():
		errors.append("sprite archive is invalid")

		return errors

	var configuration := Geometry.view_configuration(view_size)

	if configuration == null:
		errors.append("underground view size is invalid")

		return errors

	var missing: Dictionary = {}

	for x in map_edge:
		for y in map_edge:
			for sprite_id in tile_sprite_ids(city, x, y, view_size, show_pipes, show_subways, show_water_mains):
				if sprites.find_sprite(sprite_id) == null:
					missing[sprite_id] = true

			var tunnel_sprite := tunnel_sprite_id(city, x, y, view_size)

			if tunnel_sprite > 0 and sprites.find_sprite(tunnel_sprite) == null:
				missing[tunnel_sprite] = true

	var ids := missing.keys()
	ids.sort()

	for sprite_id in ids:
		errors.append("required underground sprite %d is missing" % sprite_id)

	return errors


static func tile_sprite_ids(
	city: CityState,
	x: int,
	y: int,
	view_size := Geometry.VIEW_LARGE,
	show_pipes := true,
	show_subways := true, show_water_mains := true
) -> PackedInt32Array:
	var result := PackedInt32Array()

	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return result

	var configuration := Geometry.view_configuration(view_size)

	if configuration == null:
		return result

	var sprite_base := configuration.sprite_base
	var underground := city.underground_id(x, y)

	if not show_subways:
		if underground == UnderTiles.PIPE_TB_SUBWAY_LR:
			underground = UnderTiles.PIPE_TB
		elif underground == UnderTiles.PIPE_LR_SUBWAY_TB:
			underground = UnderTiles.PIPE_LR
		elif underground in range(UnderTiles.SUBWAY_FIRST, UnderTiles.PIPE_FIRST) or underground == UnderTiles.SUBWAY_ENTRANCE:
			underground = UnderTiles.EMPTY

	var is_pipe := (
		(underground >= UnderTiles.PIPE_LR and underground <= UnderTiles.PIPE_LTBR)
		or underground == UnderTiles.PIPE_TB_SUBWAY_LR
		or underground == UnderTiles.PIPE_LR_SUBWAY_TB
	)

	if is_pipe:
		if not show_water_mains:
			if underground == UnderTiles.PIPE_TB_SUBWAY_LR:
				result.append(sprite_base + SUBWAY_AND_PIPE_FIRST + UnderTiles.SUBWAY_LR)
			elif underground == UnderTiles.PIPE_LR_SUBWAY_TB:
				result.append(sprite_base + SUBWAY_AND_PIPE_FIRST + UnderTiles.SUBWAY_TB)
			else:
				result.append(
					sprite_base + terrain_wireframe_offset(city.terrain_id(x, y))
				)

			return result

		if city.is_piped(x, y) and city.is_watered(x, y):
			underground += WATERED_PIPE_OFFSET

		result.append(sprite_base + SUBWAY_AND_PIPE_FIRST + underground)

		return result

	if underground == UnderTiles.EMPTY:
		if not show_pipes or not city.is_piped(x, y):
			result.append(
				sprite_base + terrain_wireframe_offset(city.terrain_id(x, y))
			)
		elif city.is_watered(x, y):
			result.append(sprite_base + WATERED_TERRAIN)
		else:
			result.append(sprite_base + PIPED_TERRAIN)

		return result

	result.append(sprite_base + SUBWAY_AND_PIPE_FIRST + underground)

	if show_pipes and city.is_piped(x, y):
		result.append(
			sprite_base + (WATERED_TERRAIN if city.is_watered(x, y) else PIPED_TERRAIN)
		)

	return result


static func terrain_wireframe_offset(terrain: int) -> int:
	if terrain >= TerrainTileIds.FLAT and terrain <= TerrainTileIds.LAND_DRAW_LAST:
		return TERRAIN_WIREFRAME_FIRST + mini(terrain, TerrainTileIds.RAISED)

	if terrain >= TerrainTileIds.DEEP_WATER_FIRST and terrain <= TerrainTileIds.DEEP_WATER_DRAW_LAST:
		return TERRAIN_WIREFRAME_FIRST + mini(terrain - TerrainTileIds.DEEP_WATER_FIRST, TerrainTileIds.RAISED)

	if terrain >= TerrainTileIds.SHORE_FIRST and terrain <= TerrainTileIds.FORBIDDEN_COAST:
		return TERRAIN_WIREFRAME_FIRST + mini(terrain - TerrainTileIds.SHORE_FIRST, TerrainTileIds.RAISED)

	return TERRAIN_WIREFRAME_FIRST


static func tunnel_sprite_id(
	city: CityState, x: int, y: int, view_size := Geometry.VIEW_LARGE
) -> int:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return -1

	var configuration := Geometry.view_configuration(view_size)

	if configuration == null:
		return -1

	var levels := city.tunnel_levels(x, y) & 0x1f

	if levels == 0:
		return -1

	if levels == 1:
		return configuration.sprite_base + (BuildingTileIds.TUNNEL_FIRST - 1) + city.terrain_id(x, y)

	return configuration.sprite_base + DEEP_TUNNEL


static func visual_signature(city: CityState, view_size: int, show_pipes := true, show_subways := true, show_water_mains := true) -> Array:
	if city == null or not city.is_valid():
		return []

	# chunk revisions replace whole-map content hashes. xbit keeps a masked
	# content signature because the wireframe follows only its water-network
	# bits, and the rest of the chunk changes every tick
	return [
		"underground",
		city.visible_altitude_levels,
		view_size,
		show_pipes,
		show_subways,
		show_water_mains,
		city.compass_rotation(),
		city.chunk_revision("ALTM"),
		city.chunk_revision("XTER"),
		city.chunk_revision("XUND"),
		city.masked_tile_flag_signature(0x30),
	]


# paint one underground map tile into `output`, in back-to-front order
# `output` is an `Image` or any recorder with the same `blend_rect` call
# `origin_x` is the screen column of tile (0, 0)
# `cache` holds decoded sprites and belongs to the caller
# the surface painter calls this for cutaway tiles
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
	show_pipes: bool,
	show_subways: bool,
	show_water_mains := true
) -> void:
	var surface_visible := city.tile_is_visible(x, y)
	var screen_x := origin_x + (x - y) * configuration.half_width
	var base_y := (
		configuration.top_margin
		+ (x + y) * configuration.half_height
		- city.land_altitude(x, y) * configuration.altitude_step
	)
	var terrain_image := _sprite_image(
		sprites,
		palette,
		cache,
		configuration.sprite_base + terrain_wireframe_offset(city.terrain_id(x, y)),
	)
	var terrain_top := base_y + configuration.tile_height - terrain_image.get_height()

	var tunnel_sprite := tunnel_sprite_id(city, x, y, configuration.view_size)

	if tunnel_sprite > 0 and city.underground_level_is_visible(x, y, maxi(0, (city.tunnel_levels(x, y) & 0x1f) - 1)):
		var tunnel_image := _sprite_image(sprites, palette, cache, tunnel_sprite)
		var tunnel_y := base_y + configuration.tile_height - tunnel_image.get_height()
		var levels := city.tunnel_levels(x, y) & 0x1f

		if levels > 1:
			tunnel_y += (levels - 1) * configuration.altitude_step

		_blend(output, tunnel_image, Vector2i(screen_x, tunnel_y))

	# pipes and the wireframe follow the terrain. subways sit one level below it
	if not surface_visible:
		var underground := city.underground_id(x, y)

		if not show_subways or not city.underground_level_is_visible(x, y, 1):
			return

		if not (underground in range(UnderTiles.SUBWAY_FIRST, UnderTiles.PIPE_FIRST) or underground in [UnderTiles.PIPE_TB_SUBWAY_LR, UnderTiles.PIPE_LR_SUBWAY_TB, UnderTiles.SUBWAY_ENTRANCE]):
			return

	for sprite_id in tile_sprite_ids(
		city, x, y, configuration.view_size, show_pipes and surface_visible, show_subways, show_water_mains and surface_visible
	):
		var image := _sprite_image(sprites, palette, cache, sprite_id)
		_blend(output, image, Vector2i(screen_x, terrain_top))


static func _sprite_image(
	sprites: Sc2SpriteArchive,
	palette: Sc2Palette,
	cache: Dictionary,
	sprite_id: int
) -> Image:
	if cache.has(sprite_id):
		return cache[sprite_id]

	var entry := sprites.find_sprite(sprite_id)
	var rendered := entry.create_image(palette)
	var image: Image = rendered.image
	cache[sprite_id] = image

	return image


static func _blend(output: Variant, sprite: Image, position: Vector2i) -> void:
	output.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), position)
