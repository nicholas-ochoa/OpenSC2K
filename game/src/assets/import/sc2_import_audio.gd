class_name Sc2ImportAudio
extends RefCounted
## Convert source sound payloads into portable PCM WAV without playback.

@warning_ignore_start("integer_division")


static func mac_sound(data: PackedByteArray) -> AssetBytesResult:
	if data.size() < 6:
		return AssetBytesResult.failure("The Macintosh sound resource is truncated.")

	var format := BinaryData.read_u16_be(data, 0)
	var cursor := 4

	if format == 1:
		cursor += BinaryData.read_u16_be(data, 2) * 6
	elif format != 2:
		return AssetBytesResult.failure("Unsupported Macintosh sound resource format.")

	if not Sc2ImportContainer.has_range(data, cursor, 2):
		return AssetBytesResult.failure("The Macintosh sound command list is truncated.")

	var count := BinaryData.read_u16_be(data, cursor)
	cursor += 2

	if not Sc2ImportContainer.has_range(data, cursor, count * 8):
		return AssetBytesResult.failure("The Macintosh sound command list is truncated.")

	for index in count:
		var command := cursor + index * 8
		var operation := BinaryData.read_u16_be(data, command)

		# The offset flag points to bytes inside this resource.
		if operation not in [0x8050, 0x8051]:
			continue

		var header := BinaryData.read_u32_be(data, command + 4)

		if not Sc2ImportContainer.has_range(data, header, 22):
			return AssetBytesResult.failure("The Macintosh sample header is truncated.")

		if data[header + 20] != 0:
			return AssetBytesResult.failure("This Macintosh sound uses an unsupported extended or compressed sample format.")

		var length := BinaryData.read_u32_be(data, header + 4)
		var rate := BinaryData.read_u32_be(data, header + 8) >> 16

		if not Sc2ImportContainer.has_range(data, header + 22, length):
			return AssetBytesResult.failure("The Macintosh sample data is truncated.")

		return pcm_wave(data.slice(header + 22, header + 22 + length), rate, 1, 8)

	return AssetBytesResult.failure("No embedded sample buffer was found in the Macintosh sound.")


# Keep only the format and sample chunks of a RIFF WAVE file. Some Special Edition CD-ROM sounds
# have a sampler chunk after an odd-sized sample chunk without the RIFF pad byte.
static func riff_wave(data: PackedByteArray) -> AssetBytesResult:
	if data.size() < 12 or data.slice(0, 4).get_string_from_ascii() != "RIFF" or data.slice(8, 12).get_string_from_ascii() != "WAVE":
		return AssetBytesResult.failure("The sound is not a RIFF WAVE file.")

	var format := PackedByteArray()
	var samples := PackedByteArray()
	var cursor := 12

	while cursor + 8 <= data.size() and (format.is_empty() or samples.is_empty()):
		var id := data.slice(cursor, cursor + 4).get_string_from_ascii()
		var size := int(data.decode_u32(cursor + 4))
		var available := mini(size, data.size() - cursor - 8)

		if id == "fmt " and format.is_empty():
			format = data.slice(cursor + 8, cursor + 8 + available)
		elif id == "data" and samples.is_empty():
			samples = data.slice(cursor + 8, cursor + 8 + available)

		cursor += 8 + size + size % 2

	if format.size() < 16 or samples.is_empty():
		return AssetBytesResult.failure("The WAVE file has no format or sample data.")

	var bytes := "RIFF".to_ascii_buffer()
	bytes.resize(8)
	bytes.encode_u32(4, 4 + 8 + format.size() + format.size() % 2 + 8 + samples.size() + samples.size() % 2)
	bytes.append_array("WAVE".to_ascii_buffer())
	_append_chunk(bytes, "fmt ", format)
	_append_chunk(bytes, "data", samples)

	var result := AssetBytesResult.new()
	result.ok = true
	result.bytes = bytes

	return result


static func _append_chunk(bytes: PackedByteArray, id: String, payload: PackedByteArray) -> void:
	bytes.append_array(id.to_ascii_buffer())
	bytes.resize(bytes.size() + 4)
	bytes.encode_u32(bytes.size() - 4, payload.size())
	bytes.append_array(payload)

	if payload.size() % 2 != 0:
		bytes.append(0)


static func pcm_wave(samples: PackedByteArray, rate: int, channels: int, bits: int) -> AssetBytesResult:
	if rate < 1000 or rate > 192000 or channels not in [1, 2] or bits not in [8, 16] or samples.is_empty():
		return AssetBytesResult.failure("Invalid PCM sample format.")

	var block := channels * (bits / 8)

	if samples.size() % block != 0:
		return AssetBytesResult.failure("PCM samples end in an incomplete frame.")

	var data := PackedByteArray()
	data.resize(44)
	data.encode_u32(0, 0x46464952)
	data.encode_u32(4, 36 + samples.size() + samples.size() % 2)
	data.encode_u32(8, 0x45564157)
	data.encode_u32(12, 0x20746d66)
	data.encode_u32(16, 16)
	data.encode_u16(20, 1)
	data.encode_u16(22, channels)
	data.encode_u32(24, rate)
	data.encode_u32(28, rate * block)
	data.encode_u16(32, block)
	data.encode_u16(34, bits)
	data.encode_u32(36, 0x61746164)
	data.encode_u32(40, samples.size())

	data.append_array(samples)

	if samples.size() % 2 != 0:
		data.append(0)

	var result := AssetBytesResult.new()
	result.ok = true
	result.bytes = data

	return result
