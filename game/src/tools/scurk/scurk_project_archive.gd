class_name ScurkProjectArchive
extends RefCounted
## Maps project values to JSON, MIF, and PNG members without a scene or project dependency.
## The native assets library holds the codec; see native/core/assets/src/scurk/project/archive.rs.

const FORMAT := "opensc2k-scurk"
const VERSION := 2
const MANIFEST := "project.json"
const PALETTE := "palette.json"


# The caller validates the logical record before encoding it.
static func encode(record: Dictionary, palette_rgb: PackedByteArray) -> Result:
	var encoded := NativeScurkArchive.encode(record, palette_rgb)
	if not encoded.ok:
		return failure(encoded.error)
	var result := Result.new()
	result.ok = true
	result.bytes = encoded.bytes
	return result


static func decode(bytes: PackedByteArray) -> Result:
	var decoded := NativeScurkArchive.decode(bytes)
	if not decoded.ok:
		return failure(decoded.error)
	var result := Result.new()
	result.ok = true
	result.record = decoded.record
	result.palette_rgb = decoded.palette_rgb
	return result


static func failure(message: String) -> Result:
	var result := Result.new()
	result.error = message
	return result


class Result extends RefCounted:
	var ok := false
	var error := ""
	var bytes := PackedByteArray()
	var record: Dictionary = {}
	var palette_rgb := PackedByteArray()
