class_name ZoneEditResult
extends EditCommandResult


var zone_type := 0
var dragged := false
var charged_tiles := 0
var terrain_surcharges := 0
# xzon and xbld bytes at `tile_indices`, before and after the edit
var previous_values := PackedByteArray()
var new_values := PackedByteArray()
var previous_buildings := PackedByteArray()
var new_buildings := PackedByteArray()
var previous_funds := 0


static func rejected(message: String, charged := 0) -> ZoneEditResult:
	var result := ZoneEditResult.new()
	result.error = message
	result.cost = charged

	return result
