class_name PeDibResult
extends RefCounted


var ok := false
var error := ""
var bytes := PackedByteArray()
var width := 0
var height := 0
var bits_per_pixel := 0
var compression := 0
var color_count := 0


static func failure(message: String) -> PeDibResult:
	var result := PeDibResult.new()
	result.error = message

	return result
