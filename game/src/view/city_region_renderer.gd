class_name CityRegionRenderer
extends RefCounted
## CPU pixels and foreground commands of one screen region, from the native
## painter. A caller that paints many regions passes one context and a city
## revision, so the painter reuses its tiles.

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
# pixels of an HD region for each view pixel
const ARTWORK_FACTOR := 2


# gdstyle:ignore=quality/max-parameters
static func render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		bounds: Rect2i, view_size := Renderer.VIEW_LARGE, mode := CityViewMode.Mode.CITY,
		show_pipes := true, show_subways := true, show_water_mains := true,
		context: CityGpuBuildContext = null, revision := 0, show_tunnels := true, artwork_palette: Sc2Palette = null,
		artwork_context: CityGpuBuildContext = null) -> CityRegionResult:
	if city == null or not city.is_valid() or palette == null or not palette.is_valid() or sprites == null or not sprites.is_valid():
		return CityRegionResult.rejected("invalid region assets")

	var configuration := Renderer.view_configuration(view_size)

	if configuration == null or not CityViewMode.is_map(mode):
		return CityRegionResult.rejected("invalid region view")

	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, Renderer.output_size_for_view(view_size, city.map_size)))

	if not bounds.has_area():
		return CityRegionResult.rejected("empty region")

	if context == null:
		context = CityGpuBuildContext.new()

	var failure := context.prepare(city, palette, sprites, view_size, mode, show_pipes, show_subways, show_water_mains, revision,
		false, false, 0, show_tunnels)

	if not failure.is_empty():
		return CityRegionResult.rejected(failure)

	var painted := context.raster(bounds, Color.WHITE if mode == CityViewMode.Mode.UNDERGROUND else Color.TRANSPARENT)

	if painted.has("error"):
		return CityRegionResult.rejected(painted.error)

	var image: Image = painted.image

	if palette.is_index_encoding:
		image.convert(Image.FORMAT_L8 if mode == CityViewMode.Mode.UNDERGROUND else Image.FORMAT_LA8)

	var foreground: Array[CityStaticCommand] = []

	if mode != CityViewMode.Mode.UNDERGROUND:
		foreground = CityGpuBuildContext.foreground_commands(painted.records, true)

	var result := CityRegionResult.new()
	result.ok = true
	result.error = ""
	result.occlusion_commands = foreground
	result.occlusion_grid = Renderer.build_occlusion_grid(foreground, configuration.divisor)
	result.image = image
	result.emission_image = context.builder.auxiliary_raster(bounds, sprites.visual_emission, true)
	result.season_image = context.builder.auxiliary_raster(bounds, sprites.visual_seasons, false)
	result.bounds = bounds
	result.water = context.build_water(bounds, configuration.divisor, sprites, mode)

	# HD art paints with the colors of the palette, not with its indices
	if artwork_palette != null and not sprites.high_resolution.is_empty():
		if artwork_context == null:
			artwork_context = CityGpuBuildContext.new()

		failure = artwork_context.prepare(city, artwork_palette, sprites, view_size, mode, show_pipes, show_subways,
			show_water_mains, revision, false, false, 0, show_tunnels, true)

		if not failure.is_empty():
			return CityRegionResult.rejected(failure)

		var artwork := IsometricImageRender.paint_artwork(artwork_context, bounds,
			Color.WHITE if mode == CityViewMode.Mode.UNDERGROUND else Color.TRANSPARENT, ARTWORK_FACTOR)

		if not artwork.ok:
			return CityRegionResult.rejected(artwork.error)

		result.artwork_image = artwork.image

	return result
