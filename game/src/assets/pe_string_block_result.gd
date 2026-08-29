class_name PeStringBlockResult
extends RefCounted


var ok := false
var error := ""
var strings: Array[String] = []


static func failure(message: String) -> PeStringBlockResult:
	var result := PeStringBlockResult.new()
	result.error = message

	return result
