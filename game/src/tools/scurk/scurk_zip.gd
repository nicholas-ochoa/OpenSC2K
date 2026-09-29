class_name ScurkZip
extends RefCounted
## Byte-only ZIP container for SCURK projects. No files are extracted to disk.
## Members are written in name order. ZipArchive holds the codec.

const Limits = preload("res://src/tools/scurk/scurk_project_limits.gd")
const MAX_FILE_BYTES := Limits.MAX_FILE_BYTES
const MAX_MEMBER_BYTES := Limits.MAX_FILE_BYTES


static func encode(members: Dictionary[String, PackedByteArray], max_data_bytes := MAX_MEMBER_BYTES) -> ZipArchive.Result:
	if max_data_bytes < 0 or max_data_bytes > MAX_MEMBER_BYTES:
		return _failure("The project ZIP member size limit is invalid.")
	var names := PackedStringArray(members.keys())
	names.sort()
	return ZipArchive.encode(names, members, MAX_FILE_BYTES, max_data_bytes)


static func decode(bytes: PackedByteArray, max_data_bytes := MAX_MEMBER_BYTES) -> ZipArchive.Result:
	if max_data_bytes < 0 or max_data_bytes > MAX_MEMBER_BYTES:
		return _failure("The project ZIP size is invalid.")
	return ZipArchive.decode(bytes, MAX_FILE_BYTES, max_data_bytes)


static func _failure(message: String) -> ZipArchive.Result:
	var result := ZipArchive.Result.new()
	result.error = message
	return result
