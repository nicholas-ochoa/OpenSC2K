class_name SubwayToRailEditResult
extends EditCommandResult


var tile_id := 0
var orientation := 0
var neighbor := Vector2i(-1, -1)


static func rejected(message: String, charged := 0) -> SubwayToRailEditResult:
	var result := SubwayToRailEditResult.new()
	result.error = message
	result.cost = charged

	return result
