class_name PeIndexedBatchResult
extends RefCounted


var ok := false
var error := ""
var entries: Array[IndexedImageResult] = []


static func failure(message: String) -> PeIndexedBatchResult:
	var result := PeIndexedBatchResult.new()
	result.error = message

	return result
