class_name ScurkMif
extends RefCounted

const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")

const INFO_LENGTH := 0x72
const FILE_HEADER_LENGTH := 12

var info_payload := PackedByteArray()
var shapes: Array[Sc2SpriteArchive.SpriteEntry] = []
var names: Dictionary = {}
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


func parse(bytes: PackedByteArray) -> bool:
	_clear()
	if bytes.size() < FILE_HEADER_LENGTH:
		return _fail("file is shorter than the MIFF header")
	if _tag(bytes, 0) != "MIFF" or _tag(bytes, 8) != "SC2K":
		return _fail("file does not have a MIFF/SC2K header")
	if _read_u32_be(bytes, 4) != bytes.size() - 8:
		return _fail("MIFF length does not match the file size")

	var position := FILE_HEADER_LENGTH
	if position + 8 > bytes.size() or _tag(bytes, position) != "INFO":
		return _fail("INFO chunk is missing")
	var info_length := _read_u32_be(bytes, position + 4)
	position += 8
	if info_length != INFO_LENGTH:
		return _fail("INFO chunk length is not 0x72")
	if position + info_length > bytes.size():
		return _fail("INFO chunk extends past the file")
	info_payload = bytes.slice(position, position + info_length)
	position += info_length

	if position + 10 > bytes.size() or _tag(bytes, position) != "TILE":
		return _fail("TILE chunk is missing")
	var tile_length := _read_u32_be(bytes, position + 4)
	position += 8
	var tile_end := position + tile_length
	if tile_end != bytes.size():
		return _fail("TILE chunk length does not match the file size")
	piece_count = _read_u16_be(bytes, position)
	position += 2

	var duplicate_counts: Dictionary = {}
	for piece_index in piece_count:
		if position + 8 > tile_end:
			return _fail("piece %d header extends past the TILE chunk" % piece_index)
		var piece_tag := _tag(bytes, position)
		var piece_length := _read_u32_be(bytes, position + 4)
		var payload_start := position + 8
		var payload_end := payload_start + piece_length
		if payload_end > tile_end:
			return _fail("piece %d extends past the TILE chunk" % piece_index)
		if piece_tag == "SHAP":
			if not _parse_shape(bytes, payload_start, payload_end, duplicate_counts):
				return false
		elif piece_tag == "NAME":
			if not _parse_name(bytes, payload_start, payload_end):
				return false
		else:
			return _fail("piece %d has unknown tag %s" % [piece_index, piece_tag])
		position = payload_end
	if position != tile_end:
		return _fail("TILE chunk has data after its declared pieces")
	return true


func is_valid() -> bool:
	return parse_error.is_empty()


func _parse_shape(
	bytes: PackedByteArray,
	payload_start: int,
	payload_end: int,
	duplicate_counts: Dictionary
) -> bool:
	if payload_end - payload_start < 10:
		return _fail("SHAP payload is shorter than its header")
	var entry := Sc2SpriteArchive.SpriteEntry.new()
	entry.sprite_id = _read_u16_be(bytes, payload_start)
	entry.width = _read_u16_be(bytes, payload_start + 2)
	entry.height = _read_u16_be(bytes, payload_start + 4)
	var pixel_length := _read_u32_be(bytes, payload_start + 6)
	if entry.width <= 0 or entry.height <= 0:
		return _fail("SHAP sprite %d has an empty dimension" % entry.sprite_id)
	if payload_start + 10 + pixel_length != payload_end:
		return _fail("SHAP sprite %d has an invalid pixel length" % entry.sprite_id)
	entry.offset = payload_start + 10
	entry.duplicate_index = int(duplicate_counts.get(entry.sprite_id, 0))
	duplicate_counts[entry.sprite_id] = entry.duplicate_index + 1
	entry.encoded_pixels = _normalize_pixel_end(
		bytes.slice(payload_start + 10, payload_end)
	)
	entry.allow_unpadded_odd_runs = true
	var decoded := entry.decode_indices()
	if not decoded.get("ok", false):
		return _fail(decoded.get("error", "SHAP sprite cannot be decoded"))

	shapes.append(entry)
	archive.entries.append(entry)
	archive.entries_by_id[entry.sprite_id] = entry
	var pixels: PackedInt32Array = decoded.pixels
	for pixel in pixels:
		if pixel >= 0:
			overrides.entries.append(entry)
			overrides.entries_by_id[entry.sprite_id] = entry
			break
	return true


func _parse_name(bytes: PackedByteArray, payload_start: int, payload_end: int) -> bool:
	if payload_end - payload_start < 4:
		return _fail("NAME payload is shorter than its header")
	var sprite_id := _read_u16_be(bytes, payload_start)
	var name_length := _read_u16_be(bytes, payload_start + 2)
	if payload_start + 4 + name_length != payload_end:
		return _fail("NAME %d has an invalid text length" % sprite_id)
	var name_bytes := bytes.slice(payload_start + 4, payload_end)
	while not name_bytes.is_empty() and name_bytes[name_bytes.size() - 1] == 0:
		name_bytes.resize(name_bytes.size() - 1)
	names[sprite_id] = name_bytes.get_string_from_ascii()
	return true


func _clear() -> void:
	info_payload.clear()
	shapes.clear()
	names.clear()
	archive = Sc2SpriteArchive.new()
	overrides = Sc2SpriteArchive.new()
	piece_count = 0
	parse_error = ""


func _fail(message: String) -> bool:
	parse_error = message
	archive.parse_error = message
	overrides.parse_error = message
	return false


static func _normalize_pixel_end(bytes: PackedByteArray) -> PackedByteArray:
	if (
		bytes.size() >= 4
		and bytes[bytes.size() - 4] == 2
		and bytes[bytes.size() - 3] == 1
		and bytes[bytes.size() - 2] == 2
		and bytes[bytes.size() - 1] == 2
	):
		var normalized := bytes.slice(0, bytes.size() - 4)
		normalized.append(0)
		normalized.append(2)
		return normalized
	return bytes


static func _tag(bytes: PackedByteArray, offset: int) -> String:
	return bytes.slice(offset, offset + 4).get_string_from_ascii()


static func _read_u16_be(bytes: PackedByteArray, offset: int) -> int:
	return (bytes[offset] << 8) | bytes[offset + 1]


static func _read_u32_be(bytes: PackedByteArray, offset: int) -> int:
	return (
		(bytes[offset] << 24)
		| (bytes[offset + 1] << 16)
		| (bytes[offset + 2] << 8)
		| bytes[offset + 3]
	)
