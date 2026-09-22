extends SceneTree

var failures := 0


func _initialize() -> void:
	var cases := [
		[0, [0, 0, 0, 0], 0],
		[0x12345678, [0x12, 0x34, 0x56, 0x78], 0x12345678],
		[0x7fffffff, [0x7f, 0xff, 0xff, 0xff], 0x7fffffff],
		[0x80000000, [0x80, 0, 0, 0], -2147483648],
		[0xffffffff, [0xff, 0xff, 0xff, 0xff], -1],
		[-2, [0xff, 0xff, 0xff, 0xfe], -2],
		[0x100000001, [0, 0, 0, 1], 1],
	]
	for entry: Array in cases:
		var data := PackedByteArray([0xa5, 0, 0, 0, 0, 0x5a])
		BinaryData.write_u32_be(data, 1, entry[0])
		check(data.slice(1, 5) == PackedByteArray(entry[1]), "big-endian bytes")
		check(data[0] == 0xa5 and data[5] == 0x5a, "surrounding bytes")
		check(BinaryData.read_u32_be(data, 1) == (int(entry[0]) & 0xffffffff), "unsigned value")
		check(BinaryData.read_i32_be(data, 1) == entry[2], "signed value")
	var short_data := PackedByteArray([0xa5, 0, 0, 0x5a])
	BinaryData.write_u16_be(short_data, 1, 0x12345)
	check(short_data == PackedByteArray([0xa5, 0x23, 0x45, 0x5a]), "16-bit wrap")
	check(BinaryData.read_u16_be(short_data, 1) == 0x2345, "16-bit read")
	BinaryData.write_u16_be(short_data, 1, -2)
	check(short_data == PackedByteArray([0xa5, 0xff, 0xfe, 0x5a]), "negative 16-bit write")
	print("Binary data checks: %d failures" % failures)
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)
