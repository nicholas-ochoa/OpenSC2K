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

var chunks: Array[Sc2Chunk] = []
var source_bytes := PackedByteArray()
var source_path := ""
var parse_error := ""


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
	source_bytes = PackedByteArray()
	parse_error = ""

	if bytes.size() < 12:
		return _fail("File is shorter than the 12-byte FORM header")
	if _ascii(bytes, 0, 4) != "FORM":
		return _fail("File does not start with FORM")
	if _read_u32_be(bytes, 4) != bytes.size() - 8:
		return _fail("FORM length does not match the file size")
	if _ascii(bytes, 8, 4) != "SCDH":
		return _fail("FORM type is not SCDH")

	var offset := 12
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
		chunk.expected_decoded_size = DECODED_SIZES.get(chunk_id, -1)
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
	return true


func is_valid() -> bool:
	return parse_error.is_empty()


func duplicate_document() -> Sc2File:
	var result := Sc2File.new()
	result.source_bytes = source_bytes.duplicate()
	result.source_path = source_path
	result.parse_error = parse_error
	for chunk in chunks:
		var copied := Sc2Chunk.new()
		copied.chunk_id = chunk.chunk_id
		copied.source_offset = chunk.source_offset
		copied.stored_payload = chunk.stored_payload.duplicate()
		copied.decoded_payload = chunk.decoded_payload.duplicate()
		copied.expected_decoded_size = chunk.expected_decoded_size
		copied.is_compressed = chunk.is_compressed
		copied.is_dirty = chunk.is_dirty
		result.chunks.append(copied)
	return result


# Use the first chunk with a given ID. Sprite lookup uses the last duplicate.
func find_chunk(chunk_id: String, occurrence: int = 0) -> Sc2Chunk:
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
	var changed := chunk.decoded_payload.duplicate()
	var encoded_value := _u32_be(value & 0xffffffff)
	for index in 4:
		changed[offset + index] = encoded_value[index]
	return chunk.set_decoded_payload(changed)


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
	body.append_array("SCDH".to_ascii_buffer())
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
