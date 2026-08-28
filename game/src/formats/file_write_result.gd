class_name FileWriteResult
extends RefCounted
# saved output path and optional serialized city bytes

var ok := false
var error := ""
var path := ""
var data := PackedByteArray()


static func failure(message: String) -> FileWriteResult:
	var result := FileWriteResult.new()
	result.error = message

	return result
