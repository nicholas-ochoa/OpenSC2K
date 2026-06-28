class_name Sc2File
extends RefCounted

const ChunkType = preload("res://src/formats/sc2_chunk.gd")
const RleCodec = preload("res://src/formats/maxis_rle.gd")

const DECODED_SIZES := {
	"CNAM": 32,
	"MISC": 4800,
	"ALTM": 32768,
	"XTER": 16384,
	"XBLD": 16384,
	"XZON": 16384,
	"XUND": 16384,
	"XTXT": 16384,
	"XLAB": 6400,
	"XMIC": 1200,
	"XTHG": 480,
	"XBIT": 16384,
	"XTRF": 4096,
	"XPLT": 4096,
	"XVAL": 4096,
	"XCRM": 4096,
	"XPLC": 1024,
	"XFIR": 1024,
	"XPOP": 1024,
	"XROG": 1024,
	"XGRP": 3328,
}

const RAW_CHUNKS := {
	"CNAM": true,
	"ALTM": true,
	"TEXT": true,
	"SCEN": true,
	"PICT": true,
	"TMPL": true,
}

const MAP_SIZES := [16, 32, 64, 128, 256, 384, 512]
const FULL_MAP_CHUNKS := ["ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XBIT"]
# these maps aren't all the same size; traffic uses half, services use a quarter
const HALF_MAP_CHUNKS := ["XTRF", "XPLT", "XVAL", "XCRM"]
const QUARTER_MAP_CHUNKS := ["XPLC", "XFIR", "XPOP", "XROG"]

var map_size := 128
var large_version := 2

var chunks: Array[Sc2Chunk] = []
var source_bytes := PackedByteArray()
var source_path := ""
var parse_error := ""

# Cache the first occurrence of each chunk ID. Worker lookups only read
# the cache; rebuild it when the chunk list changes. A size mismatch
# falls back to a scan. Store positions so the cache cannot keep chunks alive.
var _chunk_cache := {}
var _chunk_cache_size := -1


static func load_path(path: String) -> Sc2File:
	var city := Sc2File.new()
	city.source_path = path

	if not FileAccess.file_exists(path):
		city.parse_error = "File does not exist: %s" % path

		return city

	var bytes := FileAccess.get_file_as_bytes(path)

	if FileAccess.get_open_error() != OK:
		city.parse_error = "Cannot read file: %s" % path

		return city

	city.parse(bytes)

	return city


func parse(bytes: PackedByteArray) -> bool:
	chunks.clear()
	invalidate_chunk_cache()
	source_bytes = PackedByteArray()
	parse_error = ""
	map_size = 128
	large_version = 2

	if bytes.size() < 12:
		return _fail("File is shorter than the 12-byte FORM header")

	if _ascii(bytes, 0, 4) != "FORM":
		return _fail("File does not start with FORM")

	if _read_u32_be(bytes, 4) != bytes.size() - 8:
		return _fail("FORM length does not match the file size")

	var form_type := _ascii(bytes, 8, 4)

	if form_type not in ["SCDH", "SCLG"]:
		return _fail("FORM type is not SCDH or experimental SCLG")

	var offset := 12

	if form_type == "SCLG":
		if bytes.size() < 28 or _ascii(bytes, 12, 4) != "SIZE" or _read_u32_be(bytes, 16) != 8:
			return _fail("Experimental SIZE header is missing")

		map_size = _read_u32_be(bytes, 24)
		large_version = _read_u32_be(bytes, 20)

		if (
			large_version not in [1, 2, 3] or map_size not in MAP_SIZES
			or (map_size == 128 and large_version != 3)
			or (map_size < 128 and large_version == 1)
		):
			return _fail("Unsupported experimental city version or size")

		offset = 28

	while offset < bytes.size():
		if offset + 8 > bytes.size():
			return _fail("Chunk header at 0x%x is truncated" % offset)

		var chunk_id := _ascii(bytes, offset, 4)

		if not _is_chunk_id(chunk_id):
			return _fail("Chunk ID at 0x%x is not printable ASCII" % offset)

		var stored_size := _read_u32_be(bytes, offset + 4)
		var payload_start := offset + 8
		var payload_end := payload_start + stored_size

		if payload_end > bytes.size():
			return _fail("Chunk %s at 0x%x extends past the file" % [chunk_id, offset])

		var chunk := ChunkType.new()
		chunk.chunk_id = chunk_id
		chunk.source_offset = offset
		chunk.stored_payload = bytes.slice(payload_start, payload_end)
		chunk.expected_decoded_size = decoded_size(chunk_id)
		chunk.is_compressed = (
			chunk.expected_decoded_size >= 0 and not RAW_CHUNKS.has(chunk_id)
		)

		if chunk.is_compressed:
			var decode_result := RleCodec.decode(
				chunk.stored_payload, chunk.expected_decoded_size
			)

			if not decode_result.ok:
				return _fail("Chunk %s: %s" % [chunk_id, decode_result.error])

			chunk.decoded_payload = decode_result.data
		else:
			chunk.decoded_payload = chunk.stored_payload.duplicate()

			if (
				chunk.expected_decoded_size >= 0
				and chunk.decoded_payload.size() != chunk.expected_decoded_size
			):
				return _fail(
					"Chunk %s has %d bytes; expected %d"
					% [chunk_id, chunk.decoded_payload.size(), chunk.expected_decoded_size]
				)

		chunks.append(chunk)
		offset = payload_end

	if offset != bytes.size():
		return _fail("Chunk data does not end at the file boundary")

	source_bytes = bytes.duplicate()
	rebuild_chunk_cache()

	return true


func is_valid() -> bool:
	return parse_error.is_empty()


# simulation may share immutable file bytes; decoded payloads always remain private
func duplicate_document(share_source_bytes := false) -> Sc2File:
	var result := Sc2File.new()
	result.map_size = map_size
	result.large_version = large_version
	result.source_bytes = source_bytes if share_source_bytes else source_bytes.duplicate()
	result.source_path = source_path
	result.parse_error = parse_error

	for chunk in chunks:
		var copied := Sc2Chunk.new()
		copied.chunk_id = chunk.chunk_id
		copied.source_offset = chunk.source_offset
		copied.stored_payload = chunk.stored_payload if share_source_bytes else chunk.stored_payload.duplicate()
		copied.decoded_payload = chunk.decoded_payload.duplicate()
		copied.expected_decoded_size = chunk.expected_decoded_size
		copied.is_compressed = chunk.is_compressed
		copied.is_dirty = chunk.is_dirty
		copied.mutation_revision = chunk.mutation_revision
		result.chunks.append(copied)

	result.rebuild_chunk_cache()

	return result


func find_chunk(chunk_id: String, occurrence: int = 0) -> Sc2Chunk:
	if occurrence != 0 or _chunk_cache_size != chunks.size():
		return _scan_chunk(chunk_id, occurrence)

	var index: int = _chunk_cache.get(chunk_id, -1)

	if index < 0:
		return null

	var chunk := chunks[index]
	# stripped from release builds; the size guard above covers every append,
	# erase, and clear. a same-size replacement needs rebuild_chunk_cache
	assert(chunk.chunk_id == chunk_id, "Stale chunk cache; call rebuild_chunk_cache after editing chunks")

	return chunk


# Call rebuild_chunk_cache after changing chunks directly, before sharing
# the document with workers. The size check cannot catch same-size replacements.
func rebuild_chunk_cache() -> void:
	_chunk_cache.clear()

	for index in chunks.size():
		var id := chunks[index].chunk_id

		if not _chunk_cache.has(id):
			_chunk_cache[id] = index

	_chunk_cache_size = chunks.size()


# drop the cached lookups and return find_chunk to a plain scan
func invalidate_chunk_cache() -> void:
	_chunk_cache.clear()
	_chunk_cache_size = -1


func _scan_chunk(chunk_id: String, occurrence: int) -> Sc2Chunk:
	for chunk in chunks:
		if chunk.chunk_id != chunk_id:
			continue

		if occurrence == 0:
			return chunk

		occurrence -= 1

	return null


func city_name() -> String:
	var chunk := find_chunk("CNAM")

	if chunk == null or chunk.decoded_payload.size() < 2:
		return ""

	var end := 1

	while end < chunk.decoded_payload.size() and chunk.decoded_payload[end] != 0:
		end += 1

	return chunk.decoded_payload.slice(1, end).get_string_from_ascii()


func set_city_name(value: String) -> bool:
	var chunk := find_chunk("CNAM")

	if chunk == null or chunk.decoded_payload.size() != DECODED_SIZES.CNAM:
		return false

	var encoded := value.to_ascii_buffer()

	if encoded.size() > 30:
		encoded = encoded.slice(0, 30)

	var changed := chunk.decoded_payload.duplicate()

	for index in encoded.size():
		changed[index + 1] = encoded[index]

	changed[encoded.size() + 1] = 0

	return chunk.set_decoded_payload(changed)


func misc_u32(offset: int) -> int:
	var chunk := find_chunk("MISC")

	if chunk == null or offset < 0 or offset + 4 > chunk.decoded_payload.size():
		return 0

	return _read_u32_be(chunk.decoded_payload, offset)


func misc_i32(offset: int) -> int:
	var value := misc_u32(offset)

	if value >= 0x80000000:
		return value - 0x100000000

	return value


func set_misc_u32(offset: int, value: int) -> bool:
	var chunk := find_chunk("MISC")

	if chunk == null or offset < 0 or offset + 4 > chunk.decoded_payload.size():
		return false

	return chunk.write_decoded_bytes(offset, _u32_be(value & 0xffffffff))


func set_misc_i32(offset: int, value: int) -> bool:
	return set_misc_u32(offset, value)


func serialize(force_rebuild: bool = false) -> Dictionary:
	var has_changes := false

	for chunk in chunks:
		if chunk.is_dirty:
			has_changes = true
			break

	if not force_rebuild and not has_changes and not source_bytes.is_empty():
		return {"ok": true, "data": source_bytes.duplicate(), "error": ""}

	var body := PackedByteArray()
	body.append_array(("SCLG" if is_extended() else "SCDH").to_ascii_buffer())

	if is_extended():
		body.append_array("SIZE".to_ascii_buffer())
		body.append_array(_u32_be(8))
		body.append_array(_u32_be(large_version))
		body.append_array(_u32_be(map_size))

	for chunk in chunks:
		var payload := chunk.payload_for_write()
		body.append_array(chunk.chunk_id.to_ascii_buffer())
		body.append_array(_u32_be(payload.size()))
		body.append_array(payload)

	var output := PackedByteArray()
	output.append_array("FORM".to_ascii_buffer())
	output.append_array(_u32_be(body.size()))
	output.append_array(body)

	return {"ok": true, "data": output, "error": ""}


func _fail(message: String) -> bool:
	parse_error = message
	chunks.clear()
	invalidate_chunk_cache()

	return false


static func _read_u32_be(bytes: PackedByteArray, offset: int) -> int:
	return (
		(bytes[offset] << 24)
		| (bytes[offset + 1] << 16)
		| (bytes[offset + 2] << 8)
		| bytes[offset + 3]
	)


static func _u32_be(value: int) -> PackedByteArray:
	return PackedByteArray(
		[
			(value >> 24) & 0xff,
			(value >> 16) & 0xff,
			(value >> 8) & 0xff,
			value & 0xff,
		]
	)


static func _ascii(bytes: PackedByteArray, offset: int, length: int) -> String:
	return bytes.slice(offset, offset + length).get_string_from_ascii()


static func _is_chunk_id(value: String) -> bool:
	if value.length() != 4:
		return false

	var bytes := value.to_ascii_buffer()

	for byte in bytes:
		if byte < 0x20 or byte > 0x7e:
			return false

	return true


func decoded_size(chunk_id: String) -> int:
	if full_resolution_maps() and chunk_id in HALF_MAP_CHUNKS + QUARTER_MAP_CHUNKS:
		return map_size * map_size

	if map_size > 128 and large_version >= 2:
		var factor := IntegerMath.div_trunc(map_size * map_size, 16384)

		match chunk_id:
			"XTXT":
				return map_size * map_size * 2
			"XMIC":
				return 150 * factor * 8
			"XLAB":
				return (OverlayData.EXTRA_SIGN + 50 * factor - 50) * 25
			"XTHG":
				return 40 * factor * 24

	if chunk_id == "XTHG" and map_size > 128:
		return 960

	if chunk_id in FULL_MAP_CHUNKS:
		return map_size * map_size * (2 if chunk_id == "ALTM" else 1)

	if chunk_id in HALF_MAP_CHUNKS:
		return (IntegerMath.div_trunc(map_size, 2)) * (IntegerMath.div_trunc(map_size, 2))

	if chunk_id in QUARTER_MAP_CHUNKS:
		return (IntegerMath.div_trunc(map_size, 4)) * (IntegerMath.div_trunc(map_size, 4))

	return DECODED_SIZES.get(chunk_id, -1)


func resize_empty_map(edge: int) -> bool:
	if edge not in MAP_SIZES:
		return false

	if edge == map_size:
		return true

	var native_maps := full_resolution_maps()
	map_size = edge
	large_version = 3 if native_maps else 2
	source_bytes.clear()

	for chunk in chunks:
		if chunk.chunk_id not in FULL_MAP_CHUNKS + HALF_MAP_CHUNKS + QUARTER_MAP_CHUNKS + ["XTHG", "XMIC", "XLAB"]:
			continue

		chunk.expected_decoded_size = decoded_size(chunk.chunk_id)
		var data := PackedByteArray()
		data.resize(chunk.expected_decoded_size)
		chunk.set_decoded_payload(data)

	set_misc_u32(0x01f0, map_size * map_size)

	return true


func upgrade_large_limits() -> void:
	if map_size == 128 or large_version >= 2:
		return

	large_version = 2
	source_bytes.clear()

	for id in ["XTXT", "XMIC", "XLAB", "XTHG"]:
		var chunk := find_chunk(id)

		if chunk == null:
			continue

		var old := chunk.decoded_payload.duplicate()
		chunk.expected_decoded_size = decoded_size(id)
		var expanded := PackedByteArray()
		expanded.resize(chunk.expected_decoded_size)

		if id == "XTHG":
			for index in 480:
				expanded[index] = old[index]
				expanded[IntegerMath.div_trunc(expanded.size(), 2) + index] = old[480 + index]
		else:
			for index in old.size():
				expanded[index] = old[index]

		chunk.set_decoded_payload(expanded)


func is_extended() -> bool:
	return map_size != 128 or full_resolution_maps()


func full_resolution_maps() -> bool:
	return large_version == 3


func enable_full_resolution_maps() -> bool:
	if full_resolution_maps():
		return true

	var expanded := {}

	for id in HALF_MAP_CHUNKS + QUARTER_MAP_CHUNKS:
		var chunk := find_chunk(id)

		if chunk == null or chunk.decoded_payload.size() != decoded_size(id):
			return false

		expanded[id] = CityDataGrid.expand(chunk.decoded_payload, map_size)

	upgrade_large_limits()
	large_version = 3
	source_bytes.clear()

	for id in expanded:
		var chunk := find_chunk(id)
		chunk.expected_decoded_size = decoded_size(id)
		chunk.set_decoded_payload(expanded[id])

	return true
