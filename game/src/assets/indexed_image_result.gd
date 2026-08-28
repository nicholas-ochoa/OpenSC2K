class_name IndexedImageResult
extends RefCounted


var ok := false
var error := ""
var width := 0
var height := 0
var pixels := PackedInt32Array()
var colors: Array[Color] = []
var palette: Sc2Palette
var top_down := false
var remapped_color_count := 0
var rows := 0
var consumed := 0


static func failure(message: String) -> IndexedImageResult:
	var result := IndexedImageResult.new()
	result.error = message

	return result
