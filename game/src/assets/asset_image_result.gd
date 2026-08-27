class_name AssetImageResult
extends RefCounted


var ok := false
var error := ""
var image: Image


static func failure(message: String) -> AssetImageResult:
	var result := AssetImageResult.new()
	result.error = message

	return result
