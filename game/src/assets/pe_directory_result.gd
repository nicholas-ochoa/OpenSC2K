class_name PeDirectoryResult
extends RefCounted


var ok := false
var error := ""
var bytes := PackedByteArray()
var root_offset := 0
var section_offset := 0
var section_count := 0


static func failure(message: String) -> PeDirectoryResult:
	var result := PeDirectoryResult.new()
	result.error = message

	return result
