class_name SignEditResult
extends EditCommandResult


var point := Vector2i(-1, -1)
var tile_index := -1
var label_id := 0
var old_overlay := 0
var new_overlay := 0
var old_record := PackedByteArray()
var new_record := PackedByteArray()
# stored text, at most 23 characters
var text := ""


static func rejected(message: String) -> SignEditResult:
	var result := SignEditResult.new()
	result.error = message

	return result
