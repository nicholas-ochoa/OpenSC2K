class_name RotationEditResult
extends EditCommandResult


var counter_clockwise := false
var old_compass := 0
var new_compass := 0


static func rejected(message: String) -> RotationEditResult:
	var result := RotationEditResult.new()
	result.error = message

	return result
