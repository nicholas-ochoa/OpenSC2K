class_name DebugTableRecord
extends RefCounted
# a published debug row or child field. sort values follow the visible columns
# and may be numbers, text, coordinate arrays, or null for an absent location

var id := ""
var name := ""
var value := ""
var raw := ""
var position := ""
var detail := ""
var translation := ""
var empty := false
var site: CityRecords.Site
var cells: Array[String] = []
var tooltips: Array[String] = []
var sort: Array = []
var fields: Array[DebugTableRecord] = []


static func field(key: String, text: String, stored: String, description: String, translated := "") -> DebugTableRecord:
	var result := DebugTableRecord.new()
	result.name = key
	result.value = text
	result.raw = stored
	result.detail = description
	result.translation = translated

	return result
