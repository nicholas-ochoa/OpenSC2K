class_name Sc2kfixArchive
extends RefCounted
## The SC2X save format of the sc2kfix plugin (version 1), internally called
## "sc2kfix". It is not the OpenSC2K SC2X version 4 format.
##
## A ZIP archive holds `META.json`, `current/MISC.json`, `current/XFIX.json`,
## and the runtime arrays of an original 128-tile city under `current/`. A save
## also writes `opensc2k/MISC` and `opensc2k/chunks/<ID>` entries, so a file
## that OpenSC2K writes and reads again keeps all its data. sc2kfix ignores them.
## The native simulation library holds the codec; see
## native/core/sim/src/formats/sc2kfix.rs.

const META := "META.json"
const MAX_ARCHIVE_BYTES := 64 * 1024 * 1024
const MAX_DATA_BYTES := 64 * 1024 * 1024


class Archive extends RefCounted:
	var ok := false
	var error := ""
	var bytes := PackedByteArray()


# The first member of an sc2kfix archive is META.json. An OpenSC2K SC2X
# version 4 archive starts with metadata.json.
static func is_archive(bytes: PackedByteArray) -> bool:
	if not Sc2xDocument.is_archive(bytes) or bytes.size() < 30 + META.length():
		return false

	var name_size := bytes.decode_u16(26)

	return name_size == META.length() and bytes.slice(30, 30 + name_size).get_string_from_ascii() == META


# Fill `document` with the original city of an sc2kfix archive.
static func load_bytes(document: Sc2File, bytes: PackedByteArray) -> bool:
	return document.parse(bytes)


# An sc2kfix archive of an original city. `timestamp` is the META.json time.
static func encode(document: Sc2File, timestamp: int) -> Archive:
	var result := Archive.new()

	if document == null:
		result.error = "Only an original 128 × 128 city can use the sc2kfix format."

		return result

	var encoded: Dictionary = NativeCityDocument.encode_sc2kfix(document.to_native(), timestamp)
	result.ok = encoded.ok
	result.error = encoded.error

	if result.ok:
		result.bytes = encoded.bytes

	return result
