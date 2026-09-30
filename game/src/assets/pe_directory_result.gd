class_name PeDirectoryResult
extends RefCounted
## The bytes of an executable whose resource directory the native reader accepts.

var ok := false
var error := ""
var bytes := PackedByteArray()


static func failure(message: String) -> PeDirectoryResult:
	var result := PeDirectoryResult.new()
	result.error = message

	return result
