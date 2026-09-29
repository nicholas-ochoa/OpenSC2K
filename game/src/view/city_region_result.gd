class_name CityRegionResult
extends AssetImageResult
# a rendered region and its cache publication state. workers own each result

var bounds := Rect2i()
var occlusion_commands: Array[CityStaticCommand] = []
var occlusion_grid: Dictionary[Vector2i, Array] = {}
# A positive screen scale leaves `occlusion_grid` to the first query. Most
# regions of a wide view never answer an occlusion query.
var occlusion_divisor := 0
var tiles_drawn := 0
var display_city: CityState
var usec := 0
var key := Vector2i.ZERO
var generation := 0
var last_visible := 0
var texture: ImageTexture


func candidate_grid() -> Dictionary[Vector2i, Array]:
	if occlusion_divisor > 0:
		occlusion_grid = CityIsometricRenderer.build_occlusion_grid(occlusion_commands, occlusion_divisor)
		occlusion_divisor = 0

	return occlusion_grid


static func rejected(message: String) -> CityRegionResult:
	var result := CityRegionResult.new()
	result.error = message

	return result
