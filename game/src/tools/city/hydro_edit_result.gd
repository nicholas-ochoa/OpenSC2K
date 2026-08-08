class_name HydroEditResult
extends EditCommandResult


var tile_id := 0
var overlay_id := 0
var immediate_power_refresh := false


static func rejected(message: String, charged := 0) -> HydroEditResult:
	var result := HydroEditResult.new()
	result.error = message
	result.cost = charged

	return result
