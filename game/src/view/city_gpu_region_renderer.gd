class_name CityGpuRegionRenderer
extends RefCounted
## Validates a GPU region request and passes it to the worker's native builder.


# gdstyle:ignore=quality/max-parameters
static func render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		bounds: Rect2i, view: int, mode: CityViewMode.Mode, pipes: bool, subways: bool,
		context: CityGpuBuildContext, revision: int, uploaded_atlas_revision: int, copy_atlas := true,
		water_mains := true, tunnels := true) -> CityGpuRegionResult:
	if (city == null or not city.is_valid() or palette == null or not palette.is_valid() or sprites == null or not sprites.is_valid()
			or view not in [0, 1, 2] or not CityViewMode.is_map(mode)):
		return CityGpuRegionResult.failed("invalid GPU region assets")

	return context.render(city, palette, sprites, bounds, view, mode, pipes, subways, revision, uploaded_atlas_revision,
		copy_atlas, water_mains, tunnels)
