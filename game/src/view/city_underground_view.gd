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

	if Geometry.view_configuration(view_size) == null:
		return AssetImageResult.failure("underground view size is invalid")

	var context := CityGpuBuildContext.new()
	var failure := context.prepare(city, palette, sprites, view_size, CityViewMode.Mode.UNDERGROUND, show_pipes, show_subways,
		show_water_mains, 0, false)

	if not failure.is_empty():
		return AssetImageResult.failure(failure)

	if validate_required_assets:
		var missing := context.builder.missing_sprites()

		if not missing.is_empty():
			return AssetImageResult.failure("required underground sprite %d is missing" % missing[0])

	return IsometricImageRender.paint_whole_city(context, Geometry.output_size_for_view(view_size, map_edge),
		Color.TRANSPARENT if transparent_background else Color8(WHITE_PALETTE_INDEX, WHITE_PALETTE_INDEX, WHITE_PALETTE_INDEX, 255),
		palette.is_index_encoding and transparent_background, palette.is_index_encoding and not transparent_background, progress)


static func validate_assets(
	city: CityState,
	sprites: Sc2SpriteArchive,
	view_size := Geometry.VIEW_LARGE,
	show_pipes := true,
	show_subways := true, show_water_mains := true
) -> PackedStringArray:
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

	var context := CityGpuBuildContext.new()
	var failure := context.prepare(city, Sc2Palette.index_encoding(), sprites, view_size, CityViewMode.Mode.UNDERGROUND, show_pipes,
		show_subways, show_water_mains, 0, false)

	if not failure.is_empty():
		errors.append(failure)

		return errors

	for sprite_id in context.builder.missing_sprites():
		errors.append("required underground sprite %d is missing" % sprite_id)

	return errors


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
