class_name CityRegionResult
extends AssetImageResult
# a rendered region and its cache publication state. workers own each result

var bounds := Rect2i()
var water: WaterReflectionRegion
var occlusion_commands: Array[CityStaticCommand] = []
var occlusion_grid: NativeRectIndex
# A positive screen scale leaves `occlusion_grid` to the first query. Most
# regions of a wide view never answer an occlusion query.
var occlusion_divisor := 0
var display_city: CityState
var usec := 0
var key := Vector2i.ZERO
var generation := 0
var last_visible := 0
var season_image: Image
var season_texture: ImageTexture
var emission_image: Image
var emission_texture: ImageTexture
var texture: ImageTexture
# the region with HD art, at CityRegionRenderer.ARTWORK_FACTOR pixels for each
# view pixel, or null. `image` keeps the indexed pixels for masks and shadows
var artwork_image: Image
var artwork_texture: ImageTexture


func candidate_grid() -> NativeRectIndex:
	if occlusion_divisor > 0:
		occlusion_grid = CityIsometricRenderer.build_occlusion_grid(occlusion_commands, occlusion_divisor)
		occlusion_divisor = 0

	return occlusion_grid


# Indices of the foreground commands that may meet `screen_bounds`.
func occlusion_indices(screen_bounds: Rect2i) -> PackedInt32Array:
	return CityIsometricRenderer.occlusion_candidate_indices(candidate_grid(), screen_bounds)


func occlusion_command(index: int) -> CityStaticCommand:
	return occlusion_commands[index]


static func rejected(message: String) -> CityRegionResult:
	var result := CityRegionResult.new()
	result.error = message

	return result
