class_name Sc2Chunk
extends RefCounted

const RleCodec = preload("res://src/formats/maxis_rle.gd")

var chunk_id := ""
var source_offset := 0
var stored_payload := PackedByteArray()
var decoded_payload := PackedByteArray()
var expected_decoded_size := -1
var is_compressed := false
var is_dirty := false
var mutation_revision := 0


func set_decoded_payload(value: PackedByteArray) -> bool:
	if expected_decoded_size >= 0 and value.size() != expected_decoded_size:
		return false

	decoded_payload = value.duplicate()
	mark_mutated()

	return true


func mark_mutated() -> void:
	is_dirty = true
	mutation_revision += 1


# Writes only the requested range. An invalid range leaves the chunk unchanged.
func write_decoded_bytes(offset: int, bytes: PackedByteArray) -> bool:
	if offset < 0 or offset + bytes.size() > decoded_payload.size():
		return false

	for index in bytes.size():
		decoded_payload[offset + index] = bytes[index]

	mark_mutated()

	return true


# keep the original compressed bytes if nobody edited this chunk
func payload_for_write() -> PackedByteArray:
	if not is_dirty:
		return stored_payload.duplicate()

	if is_compressed:
		return RleCodec.encode(decoded_payload)

	return decoded_payload.duplicate()

