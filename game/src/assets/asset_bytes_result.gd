class_name AssetBytesResult
extends RefCounted
# encoded asset bytes. failure has an empty buffer

var ok := false
var error := ""
var bytes := PackedByteArray()

var frame_count := 0
var duration_cs := 0


static func failure(message: String) -> AssetBytesResult:
	var result := AssetBytesResult.new()
	result.error = message

	return result
