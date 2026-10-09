class_name ZipArchive
extends RefCounted
## Byte-only ZIP container. No files are extracted to disk. Callers set the size
## limits. The encoder writes members in the given order with fixed timestamps.
## The native formats library holds the codec; see
## native/core/formats/src/zip/mod.rs.

# ZIP64 fields can name larger sizes; these bound what one archive may use
const ABSOLUTE_MAX_BYTES := 1024 * 1024 * 1024


# `names` gives the member order. With `always_deflate`, every member uses
# DEFLATE, even when stored bytes would be smaller.
static func encode(
	names: PackedStringArray,
	members: Dictionary[String, PackedByteArray],
	max_file_bytes: int,
	max_data_bytes: int,
	always_deflate := false,
) -> Result:
	var encoded: Dictionary = NativeZip.encode(names, members, max_file_bytes, max_data_bytes, always_deflate)
	var result := Result.new()
	result.ok = encoded.ok
	result.error = encoded.error

	if result.ok:
		result.bytes = encoded.bytes

	return result


# `order` lists the members in central directory order. Every member is
# checked against its CRC-32 and size.
static func decode(bytes: PackedByteArray, max_file_bytes: int, max_data_bytes: int) -> Result:
	var decoded: Dictionary = NativeZip.decode(bytes, max_file_bytes, max_data_bytes)
	var result := Result.new()
	result.ok = decoded.ok
	result.error = decoded.error

	if result.ok:
		result.order = decoded.order
		result.members.assign(decoded.members)

	return result


class Result extends RefCounted:
	var ok := false
	var error := ""
	var bytes := PackedByteArray()
	var members: Dictionary[String, PackedByteArray] = {}
	var order := PackedStringArray()
