extends SceneTree
## Generated MIFF records. Expected bytes do not use the production binary helpers.

const SHAPE := "123400030002000000180a010104000001030104ff00060103041122330002010202"
const TRANSPARENT := "123400010001000000080201010302010202"
const NAME := "123400054f616b0000"
const PIXELS := [0, -1, 255, 17, 34, 51]

var rejected := 0
var errors := PackedStringArray()


func _initialize() -> void:
	var fixture := _file([_piece("SHAP", SHAPE.hex_decode()), _piece("NAME", NAME.hex_decode()),
		_piece("SHAP", TRANSPARENT.hex_decode())])
	_test_round_trip(fixture)
	_test_writes()
	_test_truncation(fixture)
	_test_invalid_fields(fixture)
	_test_parse_reuse(fixture)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update("\n".join(errors).to_utf8_buffer())
	print("PASS: generated SCURK MIF bytes, duplicates, high-byte fields, %d rejected inputs and parse recovery; errors_sha256=%s" % [rejected, hash.finish().hex_encode()])
	quit()


func _test_round_trip(bytes: PackedByteArray) -> void:
	assert(bytes.slice(0, 20) == "4d494646000000dd5343324b494e464f00000072".hex_decode())
	var mif := ScurkMif.new()
	assert(mif.parse(bytes), mif.parse_error)
	assert(mif.info_payload == _info())
	assert(mif.piece_count == 3 and mif.piece_records.size() == 3)
	assert(mif.names == {0x1234: "Oak"})
	assert(mif.shapes.size() == 2)
	assert(mif.shapes[0].sprite_id == 0x1234 and mif.shapes[0].width == 3 and mif.shapes[0].height == 2)
	assert(mif.shapes[0].decode_indices().pixels == PackedInt32Array(PIXELS))
	assert(mif.shapes[1].decode_indices().pixels == PackedInt32Array([-1]))
	assert(mif.shapes[0].duplicate_index == 0 and mif.shapes[1].duplicate_index == 1)
	assert(mif.archive.entries_by_id[0x1234] == mif.shapes[1])
	assert(mif.overrides.entries_by_id[0x1234] == mif.shapes[0])
	assert(mif.piece_records[0].raw_payload == SHAPE.hex_decode())
	assert(mif.piece_records[1].raw_payload == NAME.hex_decode())
	assert(mif.to_bytes().bytes == bytes, "Opaque INFO, record order and raw payloads survive a round trip")
	var path := "user://scurk-mif-codec-%d.mif" % OS.get_process_id()
	assert(mif.save_path(path).ok)
	assert(ScurkMif.load_path(path).to_bytes().bytes == bytes)
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK)
	assert(not ScurkMif.load_path(path).is_valid())


func _test_writes() -> void:
	var mif := ScurkMif.from_archives([])
	var empty_info := PackedByteArray()
	empty_info.resize(114)
	assert(mif.to_bytes().bytes == "4d494646000000885343324b494e464f00000072".hex_decode()
		+ empty_info + "54494c45000000020000".hex_decode())
	mif.info_payload = _info()
	assert(mif.set_shape_indices(0x1234, 3, 2, PackedInt32Array(PIXELS)).ok)
	assert(mif.set_name(0x1234, "Oak").ok)
	assert(mif.to_bytes().bytes == _file([_piece("SHAP", SHAPE.hex_decode()),
		_piece("NAME", "123400044f616b00".hex_decode())]))
	var transparent := PackedInt32Array()
	transparent.resize(256)
	transparent.fill(-1)
	assert(mif.set_shape_indices(0xffff, 1, 256, transparent).ok)
	assert(mif.piece_records[2].raw_payload.slice(0, 10) == "ffff0001010000000404".hex_decode())
	assert(mif.set_name(0xffff, "X".repeat(255)).ok)
	assert(mif.piece_records[3].raw_payload.slice(0, 4) == "ffff0100".hex_decode())
	var bytes := mif.to_bytes().bytes
	var parsed := ScurkMif.new()
	assert(parsed.parse(bytes), parsed.parse_error)
	assert(parsed.archive.entries_by_id[0xffff].height == 256)
	assert(parsed.archive.entries_by_id[0xffff].decode_indices().pixels == transparent)
	assert(parsed.names[0xffff] == "X".repeat(255))
	assert(parsed.to_bytes().bytes == bytes)
	# The existing parser permits an empty NAME and text without a zero terminator.
	for payload in ["ffff0000", "800000024142"]:
		bytes = _file([_piece("NAME", payload.hex_decode())])
		assert(parsed.parse(bytes), parsed.parse_error)
		assert(parsed.to_bytes().bytes == bytes)


func _test_truncation(bytes: PackedByteArray) -> void:
	for length in bytes.size():
		_reject(bytes.slice(0, length))
		# Repair outer lengths to reach the inner INFO, TILE and piece guards.
		if length >= 12:
			var prefix := bytes.slice(0, length)
			_replace(prefix, 4, "%08x" % (length - 8))
			if length >= 142:
				_replace(prefix, 138, "%08x" % (length - 142))
			_reject(prefix)
	for length in 10:
		_reject(_file([_piece("SHAP", SHAPE.hex_decode().slice(0, length))]))
	for length in 4:
		_reject(_file([_piece("NAME", NAME.hex_decode().slice(0, length))]))


func _test_invalid_fields(bytes: PackedByteArray) -> void:
	for edit in [[0, "00494646"], [8, "0043324b"], [12, "004e464f"], [16, "00000071"],
		[16, "00000073"], [16, "80000000"], [134, "00494c45"], [138, "00000000"],
		[138, "00000001"], [138, "ffffffff"], [142, "0000"], [142, "0002"],
		[142, "0004"], [142, "ffff"], [144, "42414421"], [148, "80000000"], [148, "ffffffff"]]:
		var bad := bytes.duplicate()
		_replace(bad, edit[0], edit[1])
		_reject(bad)
	for edit in [[2, "0000"], [4, "0000"], [6, "00000000"], [6, "00000019"], [6, "ffffffff"]]:
		var shape := SHAPE.hex_decode()
		_replace(shape, edit[0], edit[1])
		_reject(_file([_piece("SHAP", shape)]))
	for text_length in ["0000", "0004", "0006", "8000", "ffff"]:
		var name := NAME.hex_decode()
		_replace(name, 2, text_length)
		_reject(_file([_piece("NAME", name)]))
	_reject(_file([_piece("SHAP", "1234000100010000000100".hex_decode())]))


func _test_parse_reuse(bytes: PackedByteArray) -> void:
	var mif := ScurkMif.new()
	assert(mif.parse(bytes))
	assert(not mif.parse(PackedByteArray()))
	assert(mif.piece_count == 0 and mif.shapes.is_empty() and mif.names.is_empty() and mif.piece_records.is_empty())
	assert(mif.parse(bytes), mif.parse_error)
	assert(mif.archive.is_valid() and mif.overrides.is_valid())
	assert(mif.to_bytes().bytes == bytes)


func _reject(bytes: PackedByteArray) -> void:
	var mif := ScurkMif.new()
	assert(not mif.parse(bytes), "Malformed MIF must fail")
	assert(not mif.is_valid() and not mif.parse_error.is_empty())
	assert(mif.archive.parse_error == mif.parse_error and mif.overrides.parse_error == mif.parse_error)
	var encoded := mif.to_bytes()
	assert(not encoded.ok and encoded.error == mif.parse_error and encoded.bytes.is_empty())
	rejected += 1
	errors.append(mif.parse_error)


func _file(pieces: Array[PackedByteArray]) -> PackedByteArray:
	var tile := ("%04x" % pieces.size()).hex_decode()
	for piece in pieces:
		tile.append_array(piece)
	var body := "SC2K".to_ascii_buffer() + _piece("INFO", _info()) + _piece("TILE", tile)
	return "MIFF".to_ascii_buffer() + ("%08x" % body.size()).hex_decode() + body


func _piece(tag: String, payload: PackedByteArray) -> PackedByteArray:
	return tag.to_ascii_buffer() + ("%08x" % payload.size()).hex_decode() + payload


func _info() -> PackedByteArray:
	var bytes := PackedByteArray()
	for index in 114:
		bytes.append((index * 37 + 165) & 255)
	return bytes


func _replace(bytes: PackedByteArray, offset: int, hex: String) -> void:
	var field := hex.hex_decode()
	for index in field.size():
		bytes[offset + index] = field[index]
