class_name MaxisRle
extends RefCounted


static func decode(encoded: PackedByteArray, expected_size: int = -1) -> BinaryResult:
	var decoded := PackedByteArray()
	var read_offset := 0

	while read_offset < encoded.size():
		var control: int = encoded[read_offset]
		read_offset += 1

		if control < 0x80:
			if read_offset + control > encoded.size():
				return BinaryResult.failure("Literal data extends past the encoded input")

			if expected_size >= 0 and decoded.size() + control > expected_size:
				return BinaryResult.failure("Literal data extends past the expected output size")

			decoded.append_array(encoded.slice(read_offset, read_offset + control))
			read_offset += control
		# 0x80 is invalid here, don't treat it as a run or a no-op
		elif control == 0x80:
			return BinaryResult.failure("Control byte 0x80 is reserved")
		else:
			if read_offset >= encoded.size():
				return BinaryResult.failure("Run control byte has no value byte")

			var count := control - 127

			if expected_size >= 0 and decoded.size() + count > expected_size:
				return BinaryResult.failure("Run extends past the expected output size")

			var value: int = encoded[read_offset]
			read_offset += 1

			for unused in count:
				decoded.append(value)

	if expected_size >= 0 and decoded.size() != expected_size:
		return BinaryResult.failure(
			"Decoded %d bytes; expected %d bytes" % [decoded.size(), expected_size]
		)

	var outcome := BinaryResult.new()
	outcome.ok = true
	outcome.data = decoded
	outcome.error = ""

	return outcome


static func encode(decoded: PackedByteArray) -> PackedByteArray:
	var encoded := PackedByteArray()
	var read_offset := 0

	while read_offset < decoded.size():
		var run_size := _measure_run(decoded, read_offset)

		if run_size >= 2:
			encoded.append(127 + run_size)
			encoded.append(decoded[read_offset])
			read_offset += run_size
			continue

		var literal_start := read_offset
		read_offset += 1

		while read_offset < decoded.size() and read_offset - literal_start < 127:
			if _measure_run(decoded, read_offset) >= 2:
				break

			read_offset += 1

		var literal_size := read_offset - literal_start
		encoded.append(literal_size)
		encoded.append_array(decoded.slice(literal_start, read_offset))

	return encoded


static func _measure_run(data: PackedByteArray, start: int) -> int:
	var run_size := 1

	while start + run_size < data.size():
		if run_size >= 128 or data[start + run_size] != data[start]:
			break

		run_size += 1

	return run_size
