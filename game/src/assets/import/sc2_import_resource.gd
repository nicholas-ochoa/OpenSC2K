class_name Sc2ImportResource
extends RefCounted
## One source record. The original container and record identity stay attached.

var name := ""
var type := ""
var id := -1
var bytes := PackedByteArray()
var source := ""


static func make(record_name: String, payload: PackedByteArray, origin: String, resource_type := "", resource_id := -1) -> Sc2ImportResource:
	var result := Sc2ImportResource.new()
	result.name = record_name
	result.bytes = payload
	result.source = origin
	result.type = resource_type
	result.id = resource_id

	return result
