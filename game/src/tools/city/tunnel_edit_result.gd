class_name TunnelEditResult
extends EditCommandResult


var start := Vector2i(-1, -1)
var finish := Vector2i(-1, -1)
var start_tile := BuildingTileIds.EMPTY
var finish_tile := BuildingTileIds.EMPTY
# the player must confirm the price first. the city is unchanged
var confirmation_required := false
var cancelled := false


static func rejected(message: String, charged := 0) -> TunnelEditResult:
	var result := TunnelEditResult.new()
	result.error = message
	result.cost = charged

	return result
