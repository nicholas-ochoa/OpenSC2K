extends SceneTree
## Generated ZIP fixtures from Python zipfile, independent of the SCURK writer.

const Zip = preload("res://src/tools/scurk/scurk_zip.gd")
const Checksum = preload("res://src/formats/crc32.gd")

const PYTHON_STORED := (
	"504b03041400000000000000210023dd8a58080000000800000005000000612e62696e41424300ff414243504b03041400000000000000210049b8aa0e400000" +
	"00400000000c0000006e65737465642f622e62696e5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a" +
	"5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a504b03041400000000000000210000000000000000000000000005000000656d707479504b010214031400" +
	"000000000000210023dd8a580800000008000000050000000000000000000000800100000000612e62696e504b010214031400000000000000210049b8aa0e40" +
	"000000400000000c000000000000000000000080012b0000006e65737465642f622e62696e504b01021403140000000000000021000000000000000000000000" +
	"00050000000000000000000000800195000000656d707479504b05060000000003000300a0000000b80000000000"
)

const PYTHON_DEFLATED := (
	"504b03041400000008000000210023dd8a580a0000000800000005000000612e62696e73747266f8efe8e40c00504b03041400000008000000210049b8aa0e06" +
	"000000400000000c0000006e65737465642f622e62696e8b8aa20c0000504b03041400000008000000210000000000020000000000000005000000656d707479" +
	"0300504b010214031400000008000000210023dd8a580a00000008000000050000000000000000000000800100000000612e62696e504b010214031400000008" +
	"000000210049b8aa0e06000000400000000c000000000000000000000080012d0000006e65737465642f622e62696e504b010214031400000008000000210000" +
	"000000020000000000000005000000000000000000000080015d000000656d707479504b05060000000003000300a0000000820000000000"
)

const PYTHON_DESCRIPTOR := (
	"504b030414000800080028b0365d0000000000000000000000000e00000064657363726970746f722e62696ecb48cdc9c957482bcacf55282e294a4dcc4d4d51" +
	"88f20c0000504b0708e4ecd6031900000017000000504b0102140314000800080028b0365de4ecd60319000000170000000e0000000000000000000000800100" +
	"00000064657363726970746f722e62696e504b050600000000010001003c000000550000000000"
)

const PYTHON_DESCRIPTOR_CRC := (
	"504b0304140008000000b8b0365d000000000000000000000000070000006372632e62696eac0a7ad5504b07080400000004000000504b010214031400080000" +
	"00b8b0365d504b070804000000040000000700000000000000000000008001000000006372632e62696e504b0506000000000100010035000000350000000000"
)

const PYTHON_ZIP64 := (
	"504b03042d000000080000002100a36852e1ffffffffffffffff0a001400666f726365642e62696e01001000120000000000000014000000000000004bcb2f4a" +
	"4e4d5188f20c30335148cb4ccd490100504b01022d032d000000080000002100a36852e114000000120000000a0000000000000000000000800100000000666f" +
	"726365642e62696e504b0506000000000100010038000000500000000000"
)

const PYTHON_ZIP64_DESCRIPTOR := (
	"504b03042d00080008000000210000000000ffffffffffffffff0a001400666f726365642e62696e01001000000000000000000000000000000000004bcb2f4a" +
	"4e4d5188f20c30335148cb4ccd490100504b0708a36852e114000000000000001200000000000000504b01022d032d000800080000002100a36852e114000000" +
	"120000000a0000000000000000000000800100000000666f726365642e62696e504b0506000000000100010038000000680000000000"
)

var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Checksum.calculate(PackedByteArray()) == 0)
	_check(Checksum.calculate("123456789".to_utf8_buffer()) == 0xcbf43926)
	_check(Checksum.calculate(PackedByteArray(range(256))) == 0x29058c73)
	_test_external_archives()
	_test_writer()
	_test_preflight()
	_test_zip64_count()
	_test_file_and_member_limits()
	# Invalid native compressed streams report engine errors as well as failure.
	# Suppress only the expected diagnostics during malformed-input checks.
	Engine.print_error_messages = false
	_test_invalid_archives()
	Engine.print_error_messages = true
	print("PASS: SCURK ZIP bytes, external archives, CRC, bounds, and malformed inputs (%d checks)" % checks)
	quit()


func _test_external_archives() -> void:
	var expected: Dictionary[String, PackedByteArray] = {
		"a.bin": PackedByteArray([65, 66, 67, 0, 255, 65, 66, 67]),
		"nested/b.bin": "Z".repeat(64).to_utf8_buffer(), "empty": PackedByteArray(),
	}
	for encoded in [PYTHON_STORED, PYTHON_DEFLATED]:
		var bytes: PackedByteArray = encoded.hex_decode()
		var result := Zip.decode(bytes)
		_check(result.ok and result.members == expected)
		var end := bytes.size() - 22
		bytes.encode_u16(end + 20, 3)
		bytes.append_array("zip".to_utf8_buffer())
		_check(Zip.decode(bytes).members == expected)
	var ambiguous := Zip.decode(PYTHON_DESCRIPTOR_CRC.hex_decode())
	_check(ambiguous.ok and ambiguous.members["crc.bin"] == PackedByteArray([0xac, 0x0a, 0x7a, 0xd5]))
	for encoded in [PYTHON_ZIP64, PYTHON_ZIP64_DESCRIPTOR]:
		var forced := Zip.decode(encoded.hex_decode())
		_check(forced.ok and forced.members["forced.bin"].get_string_from_utf8() == "forced ZIP64 field")
	var streamed := Zip.decode(PYTHON_DESCRIPTOR.hex_decode())
	_check(streamed.ok and streamed.members["descriptor.bin"].get_string_from_utf8() == "hello from streamed ZIP")
	# Also accept the optional-signature form of a classic data descriptor.
	var unsigned := PYTHON_DESCRIPTOR.hex_decode()
	var end := unsigned.size() - 22
	var central := unsigned.decode_u32(end + 16)
	var descriptor := central - 16
	unsigned = unsigned.slice(0, descriptor) + unsigned.slice(descriptor + 4)
	unsigned.encode_u32(unsigned.size() - 6, central - 4)
	_check(Zip.decode(unsigned).members == streamed.members)


func _test_writer() -> void:
	var members: Dictionary[String, PackedByteArray] = {
		"one": PackedByteArray([255]), "nested/空.bin": "indexed artwork".repeat(10000).to_utf8_buffer(),
		"empty": PackedByteArray(), "bytes": PackedByteArray(range(256)),
	}
	var encoded := Zip.encode(members)
	_check(encoded.ok)
	var reordered: Dictionary[String, PackedByteArray] = {}
	for path in ["bytes", "empty", "nested/空.bin", "one"]:
		reordered[path] = members[path]
	_check(Zip.encode(reordered).bytes == encoded.bytes)
	var result := Zip.decode(encoded.bytes)
	_check(result.ok and result.members == members)
	result.members["one"][0] = 17
	_check(members["one"][0] == 255 and Zip.decode(encoded.bytes).members["one"][0] == 255)
	# Godot's separate native ZIPReader checks the emitted archive on disk.
	# Production encoding and decoding never use this temporary file.
	var path := "user://scurk-zip-%d.zip" % OS.get_process_id()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(encoded.bytes)
	file.close()
	var reader := ZIPReader.new()
	_check(reader.open(path) == OK)
	_check(reader.get_files().size() == members.size())
	for name: String in members:
		_check(reader.read_file(name) == members[name])
	reader.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var empty: Dictionary[String, PackedByteArray] = {}
	_check(Zip.decode(Zip.encode(empty).bytes).ok)
	for name in ["", "/absolute", "../parent", "a/../b", "./a", "a//b", "a/", "C:/a", "a\\b"]:
		var invalid: Dictionary[String, PackedByteArray] = {name: PackedByteArray([1])}
		_check(not Zip.encode(invalid).ok)


func _test_preflight() -> void:
	var input: Dictionary[String, PackedByteArray] = {"data": PackedByteArray([1, 2, 3])}
	_check(Zip.encode(input, 3).ok and not Zip.encode(input, 2).ok)
	_check(not Zip.encode(input, -1).ok and not Zip.encode(input, Zip.MAX_MEMBER_BYTES + 1).ok)
	var bytes := PYTHON_DEFLATED.hex_decode()
	_check(Zip.decode(bytes, 72).ok)
	_check(not Zip.decode(bytes, 71).ok)
	_check(not Zip.decode(bytes, -1).ok)
	_check(not Zip.decode(bytes, Zip.MAX_MEMBER_BYTES + 1).ok)
	var central := _central(bytes)
	var oversized := bytes.duplicate()
	oversized.encode_u32(central + 24, Zip.MAX_MEMBER_BYTES + 1)
	oversized.encode_u32(22, Zip.MAX_MEMBER_BYTES + 1)
	_check(not Zip.decode(oversized).ok)
	# This invalid stream must be rejected by the aggregate limit before inflate.
	bytes[35] = 0xff
	_check(not Zip.decode(bytes, 1).ok)


func _test_invalid_archives() -> void:
	for encoded in [PYTHON_STORED, PYTHON_DEFLATED, PYTHON_DESCRIPTOR, PYTHON_ZIP64, PYTHON_ZIP64_DESCRIPTOR]:
		var bytes: PackedByteArray = encoded.hex_decode()
		for length in bytes.size():
			_check(not Zip.decode(bytes.slice(0, length)).ok)
	var stored := PYTHON_STORED.hex_decode()
	var deflated := PYTHON_DEFLATED.hex_decode()
	var central := _central(stored)
	for location in [0, central, stored.size() - 22]:
		var invalid := stored.duplicate()
		invalid[location] ^= 1
		_check(not Zip.decode(invalid).ok)
	var changed := stored.duplicate()
	changed[35] ^= 1
	_check(not Zip.decode(changed).ok)
	changed = stored.duplicate()
	changed[30] = 98
	_check(not Zip.decode(changed).ok)
	changed = stored.duplicate()
	changed[central + 46] = 98
	_check(not Zip.decode(changed).ok)
	changed = stored.duplicate()
	changed.encode_u16(6, 1)
	changed.encode_u16(central + 8, 1)
	_check(not Zip.decode(changed).ok)
	changed = stored.duplicate()
	changed.encode_u16(8, 99)
	changed.encode_u16(central + 10, 99)
	_check(not Zip.decode(changed).ok)
	changed = stored.duplicate()
	changed.encode_u32(central + 24, 0xffffffff)
	_check(not Zip.decode(changed).ok)
	changed = stored.duplicate()
	changed.encode_u16(changed.size() - 18, 1)
	_check(not Zip.decode(changed).ok)
	changed = stored.duplicate()
	changed.encode_u32(central + 42, 1)
	_check(not Zip.decode(changed).ok)
	for unsafe in ["../xx", "/root", "a//bc", "a/./b", "C:/xx"]:
		changed = stored.duplicate()
		for index in 5:
			changed[30 + index] = unsafe.unicode_at(index)
			changed[central + 46 + index] = unsafe.unicode_at(index)
		_check(not Zip.decode(changed).ok)
	var pair: Dictionary[String, PackedByteArray] = {"a": PackedByteArray([1]), "b": PackedByteArray([2])}
	changed = Zip.encode(pair).bytes
	central = _central(changed)
	var second := central + 47
	var second_local := changed.decode_u32(second + 42)
	changed[second + 46] = 97
	changed[second_local + 30] = 97
	_check(not Zip.decode(changed).ok)
	central = _central(deflated)
	changed = deflated.duplicate()
	changed[35] = 7 # Reserved deflate block type.
	_check(not Zip.decode(changed).ok)
	changed = deflated.duplicate()
	changed.encode_u32(14, changed.decode_u32(14) ^ 1)
	changed.encode_u32(central + 16, changed.decode_u32(central + 16) ^ 1)
	_check(not Zip.decode(changed).ok)
	for size in [7, 9]:
		changed = deflated.duplicate()
		changed.encode_u32(22, size)
		changed.encode_u32(central + 24, size)
		_check(not Zip.decode(changed).ok)
	changed = PYTHON_DESCRIPTOR.hex_decode()
	central = _central(changed)
	changed[central - 12] ^= 1
	_check(not Zip.decode(changed).ok)


func _test_zip64_count() -> void:
	var members: Dictionary[String, PackedByteArray] = {}
	for index in 65536:
		members["p/%05d" % index] = PackedByteArray()
	var encoded := Zip.encode(members)
	_check(encoded.ok)
	var result := Zip.decode(encoded.bytes)
	_check(result.ok and result.members == members)
	var path := "user://scurk-zip64-%d.zip" % OS.get_process_id()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(encoded.bytes)
	file.close()
	var reader := ZIPReader.new()
	_check(reader.open(path) == OK and reader.get_files().size() == 65536)
	_check(reader.file_exists("p/00000") and reader.file_exists("p/65535"))
	reader.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var locator := encoded.bytes.size() - 42
	var record := int(encoded.bytes.decode_u64(locator + 8))
	for offset in [record + 24, record + 32, record + 40, record + 48, locator + 8]:
		var invalid := encoded.bytes.duplicate()
		invalid.encode_u64(offset, 0x7fffffffffffffff)
		_check(not Zip.decode(invalid).ok)
	var invalid := encoded.bytes.duplicate()
	invalid.encode_u32(locator + 16, 2)
	_check(not Zip.decode(invalid).ok)


func _test_file_and_member_limits() -> void:
	# Member bytes and encoded file bytes have separate bounds. Header bytes
	# must not reject compressible data at the accepted member-byte limit.
	var pixels := PackedByteArray()
	pixels.resize(Zip.MAX_MEMBER_BYTES)
	pixels.fill(0)
	var members: Dictionary[String, PackedByteArray] = {"pixels": pixels}
	var encoded := Zip.encode(members)
	_check(encoded.ok and encoded.bytes.size() < Zip.MAX_FILE_BYTES)
	members["extra"] = PackedByteArray([1])
	_check(not Zip.encode(members).ok)


func _central(bytes: PackedByteArray) -> int:
	return bytes.decode_u32(bytes.size() - 6)


func _check(condition: bool) -> void:
	checks += 1
	if not condition:
		Engine.print_error_messages = true
		printerr("SCURK ZIP check %d failed" % checks)
		quit(1)
		assert(condition)
