class_name ThingRecord
extends RefCounted
# one decoded xthg moving-object record. fields follow the stored byte order
# a read copies the values. a later write to xthg does not change this record

const FIELDS: Array[String] = ["type", "direction", "state", "x", "y", "z", "px", "py", "dx", "dy", "label", "goal"]

var type := 0
var direction := 0
var state := 0
var x := 0
var y := 0
var z := 0
var px := 0
var py := 0
var dx := 0
var dy := 0
var label := 0
var goal := 0


# decode the record at `offset`. sclg high planes widen the coordinate fields
static func read(data: PackedByteArray, offset: int) -> ThingRecord:
	var result := ThingRecord.new()
	result.type = int(data[offset])
	result.direction = int(data[offset + 1])
	result.state = ThingData.read(data, offset + 2)
	result.x = ThingData.read(data, offset + 3)
	result.y = ThingData.read(data, offset + 4)
	result.z = int(data[offset + 5])
	result.px = ThingData.read(data, offset + 6)
	result.py = ThingData.read(data, offset + 7)
	result.dx = ThingData.read(data, offset + 8)
	result.dy = ThingData.read(data, offset + 9)
	result.label = ThingData.read(data, offset + 10)
	result.goal = ThingData.read(data, offset + 11)

	return result


# build a record from named values. missing fields stay zero
static func from_fields(values: Dictionary) -> ThingRecord:
	var result := ThingRecord.new()

	for key in values:
		result.set(key, int(values[key]))

	return result


func to_dictionary() -> Dictionary:
	var result := {}

	for key in FIELDS:
		result[key] = get(key)

	return result


func equals(other: ThingRecord) -> bool:
	return other != null and to_dictionary() == other.to_dictionary()


func _to_string() -> String:
	return str(to_dictionary())
