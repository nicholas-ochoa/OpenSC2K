class_name AssetImportResult
extends RefCounted

var ok := false
var error := ""
var path := ""
var root := ""
var executable_hash := ""
var previous_root := ""
var created := PackedStringArray()
var cities := 0
var scenarios := 0
var graphics := ""
var sound := ""
var music := ""
var data := ""


static func failure(message: String) -> AssetImportResult:
	var result := AssetImportResult.new()
	result.error = message

	return result
