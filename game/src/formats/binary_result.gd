class_name BinaryResult
extends RefCounted
# serialized city bytes or decoded maxis rle bytes. failure has empty data

var ok := false
var error := ""
var data := PackedByteArray()


static func failure(message: String) -> BinaryResult:
	var result := BinaryResult.new()
	result.error = message

	return result
