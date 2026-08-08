class_name OnrampEditResult
extends EditCommandResult


var tile_id := 0
var road_direction := 0
var road_point := Vector2i(-1, -1)


static func rejected(message: String, charged := 0) -> OnrampEditResult:
	var result := OnrampEditResult.new()
	result.error = message
	result.cost = charged

	return result
