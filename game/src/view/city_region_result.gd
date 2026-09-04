class_name CityRegionResult
extends AssetImageResult
# a rendered region and its cache publication state. workers own each result

var bounds := Rect2i()
var occlusion_commands: Array[Dictionary] = []
var occlusion_grid: Dictionary[Vector2i, Array] = {}
var tiles_drawn := 0
var display_city: CityState
var usec := 0
var key := Vector2i.ZERO
var generation := 0
var last_visible := 0
var texture: ImageTexture


static func rejected(message: String) -> CityRegionResult:
	var result := CityRegionResult.new()
	result.error = message

	return result
