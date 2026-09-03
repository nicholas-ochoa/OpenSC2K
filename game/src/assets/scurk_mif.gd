class_name ScurkMif
extends RefCounted

const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")

const INFO_LENGTH := 0x72
const FILE_HEADER_LENGTH := 12

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

	var duplicate_counts: Dictionary[int, int] = {}

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


func to_bytes() -> AssetBytesResult:
	if not is_valid():
		return AssetBytesResult.failure(parse_error)

	if info_payload.size() != INFO_LENGTH:
		return AssetBytesResult.failure("INFO payload length is not 0x72")

	if piece_records.size() > 0xffff:
		return AssetBytesResult.failure("TILE piece count is too large")

	var tile_payload := PackedByteArray()
	_append_u16_be(tile_payload, piece_records.size())

	for piece in piece_records:
		var tag := str(piece.tag)
		var payload: PackedByteArray = piece.raw_payload

		if tag.length() != 4:
			return AssetBytesResult.failure("TILE piece has an invalid tag")

		tile_payload.append_array(tag.to_ascii_buffer())
		_append_u32_be(tile_payload, payload.size())
		tile_payload.append_array(payload)

	var bytes := PackedByteArray()
	bytes.append_array("MIFF".to_ascii_buffer())
	_append_u32_be(bytes, 0)
	bytes.append_array("SC2K".to_ascii_buffer())
	bytes.append_array("INFO".to_ascii_buffer())
	_append_u32_be(bytes, info_payload.size())
	bytes.append_array(info_payload)
	bytes.append_array("TILE".to_ascii_buffer())
	_append_u32_be(bytes, tile_payload.size())
	bytes.append_array(tile_payload)
	_write_u32_be(bytes, 4, bytes.size() - 8)

	var result := AssetBytesResult.new()
	result.ok = true
	result.bytes = bytes
	result.error = ""

	return result


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
	if sprite_id < 0 or sprite_id > 0xffff:
		return Result.failure("NAME sprite ID is outside the 16-bit range")

	var name_bytes := value.to_ascii_buffer()

	if name_bytes.size() + 1 > 0xffff:
		return Result.failure("NAME text is too long")

	name_bytes.append(0)
	var payload := PackedByteArray()
	_append_u16_be(payload, sprite_id)
	_append_u16_be(payload, name_bytes.size())
	payload.append_array(name_bytes)
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
	if sprite_id < 0 or sprite_id > 0xffff:
		return Result.failure("SHAP sprite ID is outside the 16-bit range")

	if width <= 0 or height <= 0 or width > 255 or height > 0xffff:
		return Result.failure("SHAP dimensions are invalid")

	if pixels.size() != width * height:
		return Result.failure("SHAP pixel count does not match its dimensions")

	for pixel in pixels:
		if pixel < -1 or pixel > 0xff:
			return Result.failure("SHAP palette index is invalid")

	var pixel_data := _encode_pixels(width, height, pixels)

	if pixel_data.is_empty():
		return Result.failure("SHAP pixels cannot be encoded")

	var payload := PackedByteArray()
	_append_u16_be(payload, sprite_id)
	_append_u16_be(payload, width)
	_append_u16_be(payload, height)
	_append_u32_be(payload, pixel_data.size())
	payload.append_array(pixel_data)

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

	entry.width = width
	entry.height = height
	entry.encoded_pixels = _normalize_pixel_end(pixel_data)
	entry.allow_unpadded_odd_runs = true
	entry._index_image = null

	if rebuild_archives:
		_rebuild_archives()

	piece_count = piece_records.size()

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


func _parse_shape(
	bytes: PackedByteArray,
	payload_start: int,
	payload_end: int,
	duplicate_counts: Dictionary[int, int]
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

	if not decoded.ok:
		return _fail(decoded.error)

	shapes.append(entry)
	archive.entries.append(entry)
	archive.entries_by_id[entry.sprite_id] = entry
	var pixels: PackedInt32Array = decoded.pixels

	for pixel in pixels:
		if pixel >= 0:
			overrides.entries.append(entry)
			overrides.entries_by_id[entry.sprite_id] = entry
			break

	piece_records.append(Piece.new("SHAP", entry.sprite_id, bytes.slice(payload_start, payload_end), entry))

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
	piece_records.append(Piece.new("NAME", sprite_id, bytes.slice(payload_start, payload_end)))

	return true


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
		var decoded := entry.decode_indices()

		if not decoded.ok:
			continue

		for pixel in decoded.pixels:
			if pixel >= 0:
				overrides.entries.append(entry)
				overrides.entries_by_id[entry.sprite_id] = entry
				break


static func _encode_pixels(
	width: int, height: int, pixels: PackedInt32Array
) -> PackedByteArray:
	var encoded := PackedByteArray()

	for y in height:
		var row := PackedByteArray()
		var x := 0

		while x < width:
			var transparent := pixels[y * width + x] < 0
			var run_start := x

			while x < width and (pixels[y * width + x] < 0) == transparent and x - run_start < 255:
				x += 1

			var count := x - run_start

			if transparent:
				row.append(count)
				row.append(3)
			else:
				row.append(count)
				row.append(4)

				for pixel_x in range(run_start, x):
					row.append(pixels[y * width + pixel_x])

				if count % 2 == 1:
					row.append(0)

		if row.size() > 255:
			return PackedByteArray()

		encoded.append(row.size())
		encoded.append(1)
		encoded.append_array(row)

	encoded.append_array(PackedByteArray([2, 1, 2, 2]))

	return encoded


static func _append_u16_be(bytes: PackedByteArray, value: int) -> void:
	bytes.append((value >> 8) & 0xff)
	bytes.append(value & 0xff)


static func _append_u32_be(bytes: PackedByteArray, value: int) -> void:
	bytes.append((value >> 24) & 0xff)
	bytes.append((value >> 16) & 0xff)
	bytes.append((value >> 8) & 0xff)
	bytes.append(value & 0xff)


static func _write_u32_be(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = (value >> 24) & 0xff
	bytes[offset + 1] = (value >> 16) & 0xff
	bytes[offset + 2] = (value >> 8) & 0xff
	bytes[offset + 3] = value & 0xff
