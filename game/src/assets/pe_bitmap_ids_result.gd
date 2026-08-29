class_name PeBitmapIdsResult
extends RefCounted


var ok := false
var error := ""
var ids := PackedInt32Array()


static func failure(message: String) -> PeBitmapIdsResult:
	var result := PeBitmapIdsResult.new()
	result.error = message

	return result
