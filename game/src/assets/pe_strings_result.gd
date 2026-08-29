class_name PeStringsResult
extends RefCounted


var ok := false
var error := ""
var strings: Dictionary[int, String] = {}


static func failure(message: String) -> PeStringsResult:
	var result := PeStringsResult.new()
	result.error = message

	return result
