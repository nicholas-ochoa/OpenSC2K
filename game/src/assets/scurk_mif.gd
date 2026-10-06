class_name ScurkMif
extends RefCounted
## A SCURK MIF tile set: SHAP artwork and NAME pieces. The native formats
## library reads, encodes, and writes the bytes; see
## native/core/assets/src/scurk/mif.rs. This keeps the objects that the
## editor changes.

const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const INFO_LENGTH := 0x72
# sc2kfix marks the tile sets that use its DOS colours with this INFO revision
const SC2KFIX_REVISION := "00W_"


var info_payload := PackedByteArray()
var shapes: Array[Sc2SpriteArchive.SpriteEntry] = []
var names: Dictionary[int, String] = {}
var piece_records: Array[Piece] = []
var archive: Sc2SpriteArchive = Sc2SpriteArchive.new()
var overrides: Sc2SpriteArchive = Sc2SpriteArchive.new()
var piece_count := 0
var parse_error := ""


static func load_path(path: String) -> ScurkMif:
	var result := ScurkMif.new()

	if not FileAccess.file_exists(path):
		result.parse_error = "SCURK tile set does not exist: %s" % path

		return result

	result.parse(FileAccess.get_file_as_bytes(path))

	return result


static func from_archives(archives: Array[Sc2SpriteArchive]) -> ScurkMif:
	# independent document. opaque info bytes have no inferred native values
	var result := ScurkMif.new()
	result.info_payload.resize(INFO_LENGTH)
	result.info_payload.fill(0)
	var entries: Dictionary[int, Sc2SpriteArchive.SpriteEntry] = {}

	for source in archives:
		if source == null or not source.is_valid():
			result._fail("Cannot create a tile set from an invalid sprite archive")

			return result

		for entry in source.entries:
			entries[entry.sprite_id] = entry

	for sprite_id in entries:
		var entry := entries[sprite_id] as Sc2SpriteArchive.SpriteEntry
		var decoded := entry.decode_indices()

		if not decoded.ok:
			result._fail(decoded.error)

			return result

		var changed := result._set_shape_indices(sprite_id, entry.width, entry.height, decoded.pixels, false)

		if not changed.ok:
			result._fail(changed.error)

			return result

	result._rebuild_archives()

	return result


func parse(bytes: PackedByteArray) -> bool:
	_clear()
	var parsed := NativeScurkMif.parse(bytes)
	info_payload = parsed.info
	piece_count = parsed.piece_count

	for fields: Dictionary in parsed.pieces:
		var entry: Sc2SpriteArchive.SpriteEntry = null

		if fields.has_shape:
			entry = Sc2SpriteArchive.SpriteEntry.new()
			entry.sprite_id = fields.sprite_id
			entry.width = fields.width
			entry.height = fields.height
			entry.offset = fields.offset
			entry.duplicate_index = fields.duplicate_index
			entry.encoded_pixels = fields.encoded
			entry.allow_unpadded_odd_runs = true
			shapes.append(entry)
			archive.entries.append(entry)
			archive.entries_by_id[entry.sprite_id] = entry

			if fields.opaque:
				overrides.entries.append(entry)
				overrides.entries_by_id[entry.sprite_id] = entry
		elif fields.tag == "NAME":
			names[fields.sprite_id] = fields.name

		piece_records.append(Piece.new(fields.tag, fields.sprite_id, fields.raw, entry))

	if not str(parsed.error).is_empty():
		return _fail(parsed.error)

	return true


func is_valid() -> bool:
	return parse_error.is_empty()


# The INFO revision tag, such as "NIW_" for Windows and SC2KFIX_REVISION
func revision() -> String:
	return info_payload.slice(0, 4).get_string_from_ascii() if info_payload.size() >= 4 else ""


# An sc2kfix tile set uses the DOS colours that sc2kfix adds to the palette
func uses_dos_colors() -> bool:
	return revision() == SC2KFIX_REVISION


func to_bytes() -> AssetBytesResult:
	if not is_valid():
		return AssetBytesResult.failure(parse_error)

	var tags := PackedStringArray()
	var payloads := []

	for piece in piece_records:
		tags.append(str(piece.tag))
		payloads.append(piece.raw_payload)

	return AssetBytesResult.from_native(NativeScurkMif.to_bytes(info_payload, tags, payloads))


func save_path(path: String) -> Result:
	var encoded := to_bytes()

	if not encoded.ok:
		return Result.failure(encoded.error)

	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return Result.failure("cannot open SCURK tile set for writing: %s" % path)

	file.store_buffer(encoded.bytes)
	var error := file.get_error()
	file.close()

	if error != OK:
		return Result.failure("cannot write SCURK tile set: %s" % error_string(error))

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


func set_name(sprite_id: int, value: String) -> Result:
	var encoded := NativeScurkMif.name_payload(sprite_id, value)

	if not encoded.ok:
		return Result.failure(encoded.error)

	var payload: PackedByteArray = encoded.payload
	var record_index := _last_piece_index("NAME", sprite_id)

	if record_index < 0:
		piece_records.append(Piece.new("NAME", sprite_id, payload))
	else:
		piece_records[record_index].raw_payload = payload

	names[sprite_id] = value
	piece_count = piece_records.size()

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


func remove_name(sprite_id: int) -> Result:
	if sprite_id < 0 or sprite_id > 0xffff:
		return Result.failure("NAME sprite ID is outside the 16-bit range")

	var kept_records: Array[Piece] = []

	for piece in piece_records:
		if (
			piece.tag == "NAME"
			and int(piece.sprite_id) == sprite_id
		):
			continue

		kept_records.append(piece)

	piece_records = kept_records
	names.erase(sprite_id)
	piece_count = piece_records.size()

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


func set_shape_indices(
	sprite_id: int, width: int, height: int, pixels: PackedInt32Array
) -> Result:
	return _set_shape_indices(sprite_id, width, height, pixels, true)


func _set_shape_indices(
	sprite_id: int, width: int, height: int, pixels: PackedInt32Array, rebuild_archives: bool
) -> Result:
	var encoded := NativeScurkMif.shape_payload(sprite_id, width, height, pixels)

	if not encoded.ok:
		return Result.failure(encoded.error)

	var payload: PackedByteArray = encoded.payload
	var record_index := _last_piece_index("SHAP", sprite_id)
	var entry: Sc2SpriteArchive.SpriteEntry

	if record_index < 0:
		entry = Sc2SpriteArchive.SpriteEntry.new()
		entry.sprite_id = sprite_id
		entry.duplicate_index = 0
		shapes.append(entry)
		piece_records.append(Piece.new("SHAP", sprite_id, payload, entry))
	else:
		entry = piece_records[record_index].entry as Sc2SpriteArchive.SpriteEntry
		piece_records[record_index].raw_payload = payload

		# an edit of an empty sc2kfix shape gives it a sprite
		if entry == null:
			entry = Sc2SpriteArchive.SpriteEntry.new()
			entry.sprite_id = sprite_id
			shapes.append(entry)
			piece_records[record_index].entry = entry

	entry.width = width
	entry.height = height
	entry.encoded_pixels = encoded.encoded
	entry.allow_unpadded_odd_runs = true
	entry._index_image = null

	if rebuild_archives:
		_rebuild_archives()

	piece_count = piece_records.size()

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


func _clear() -> void:
	info_payload.clear()
	shapes.clear()
	names.clear()
	piece_records.clear()
	archive = Sc2SpriteArchive.new()
	overrides = Sc2SpriteArchive.new()
	piece_count = 0
	parse_error = ""


func _fail(message: String) -> bool:
	parse_error = message
	archive.parse_error = message
	overrides.parse_error = message

	return false


func _last_piece_index(tag: String, sprite_id: int) -> int:
	for index in range(piece_records.size() - 1, -1, -1):
		var piece: Piece = piece_records[index]

		if piece.tag == tag and int(piece.sprite_id) == sprite_id:
			return index

	return -1


func _rebuild_archives() -> void:
	archive = Sc2SpriteArchive.new()
	overrides = Sc2SpriteArchive.new()

	for entry in shapes:
		archive.entries.append(entry)
		archive.entries_by_id[entry.sprite_id] = entry

		if _shape_state(entry) == 1:
			overrides.entries.append(entry)
			overrides.entries_by_id[entry.sprite_id] = entry


# the pixels with the game's sprite end in place of the SCURK end
static func normalize_pixel_end(bytes: PackedByteArray) -> PackedByteArray:
	return NativeScurkMif.normalize_pixel_end(bytes)


# 1 for a shape with an opaque pixel, 0 for a blank shape, or -1 if it does not decode
static func _shape_state(entry: Sc2SpriteArchive.SpriteEntry) -> int:
	if not entry._direct_indices.is_empty():
		for pixel in entry._direct_indices:
			if pixel >= 0:
				return 1

		return 0

	return NativeScurkMif.shape_state(entry.width, entry.height, entry.encoded_pixels, entry.allow_unpadded_odd_runs)


class Result extends RefCounted:
	var ok := false
	var error := ""

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result


class Piece extends RefCounted:
	var tag := ""
	var sprite_id := -1
	var raw_payload := PackedByteArray()
	var entry: Sc2SpriteArchive.SpriteEntry

	func _init(kind: String, id: int, payload: PackedByteArray, sprite: Sc2SpriteArchive.SpriteEntry = null) -> void:
		tag = kind
		sprite_id = id
		raw_payload = payload
		entry = sprite
