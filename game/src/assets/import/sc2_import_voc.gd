class_name Sc2ImportVoc
extends RefCounted
## Decode Creative Voice PCM blocks. Retain sample loops in the WAV smpl chunk.

@warning_ignore_start("integer_division")

const MAX_PCM_BYTES := 64 * 1024 * 1024


static func convert(data: PackedByteArray) -> AssetBytesResult:
	if data.size() < 26 or data.slice(0, 20) != "Creative Voice File".to_ascii_buffer() + PackedByteArray([26]):
		return AssetBytesResult.failure("Missing Creative Voice header.")

	var cursor := int(data.decode_u16(20))

	if cursor < 26 or cursor > data.size():
		return AssetBytesResult.failure("Invalid Creative Voice data offset.")

	var samples := PackedByteArray()
	var rate := 0
	var channels := 1
	var bits := 8
	var extended_rate := 0
	var extended_channels := 1
	var repeat_start := -1
	var repeat_count := 0
	var loop_start := -1
	var loop_end := -1

	while cursor < data.size():
		var type := int(data[cursor])
		cursor += 1

		if type == 0:
			break

		if not Sc2ImportContainer.has_range(data, cursor, 3):
			return AssetBytesResult.failure("Truncated Creative Voice block header.")

		var length := int(data[cursor]) | (int(data[cursor + 1]) << 8) | (int(data[cursor + 2]) << 16)
		cursor += 3

		if not Sc2ImportContainer.has_range(data, cursor, length):
			return AssetBytesResult.failure("Truncated Creative Voice block.")

		var block := data.slice(cursor, cursor + length)
		cursor += length
		var next_rate := rate
		var next_channels := channels
		var next_bits := bits
		var pcm := PackedByteArray()

		match type:
			1:
				if length < 2 or block[1] != 0:
					return AssetBytesResult.failure("Unsupported Creative Voice sample codec.")

				next_rate = extended_rate if extended_rate > 0 else 1000000 / (256 - int(block[0]))
				next_channels = extended_channels if extended_rate > 0 else 1
				next_bits = 8
				extended_rate = 0
				pcm = block.slice(2)
			2:
				if rate == 0:
					return AssetBytesResult.failure("Creative Voice continuation has no sample format.")

				pcm = block
			3:
				if length != 3:
					return AssetBytesResult.failure("Invalid Creative Voice silence block.")

				next_rate = 1000000 / (256 - int(block[2]))
				next_channels = 1
				next_bits = 8
				pcm.resize(int(block.decode_u16(0)) + 1)
				pcm.fill(128)
			4, 5:
				# Marker and annotation blocks have no sample data.
				continue
			6:
				if length != 2 or repeat_start >= 0:
					return AssetBytesResult.failure("Invalid or nested Creative Voice repeat block.")

				repeat_start = samples.size()
				repeat_count = int(block.decode_u16(0))
				continue
			7:
				if repeat_start < 0 or length != 0 or samples.size() == repeat_start:
					return AssetBytesResult.failure("Invalid Creative Voice repeat end.")

				if repeat_count == 65535:
					if loop_start >= 0:
						return AssetBytesResult.failure("Multiple endless Creative Voice loops are unsupported.")

					loop_start = repeat_start
					loop_end = samples.size()
				else:
					var repeated := samples.slice(repeat_start)

					if samples.size() + repeated.size() * repeat_count > MAX_PCM_BYTES:
						return AssetBytesResult.failure("Creative Voice repeats exceed the sample limit.")

					for index in repeat_count:
						samples.append_array(repeated)

				repeat_start = -1
				continue
			8:
				if length != 4 or block[2] != 0 or block[3] > 1:
					return AssetBytesResult.failure("Unsupported Creative Voice extended format.")

				extended_channels = int(block[3]) + 1
				extended_rate = 256000000 / ((65536 - int(block.decode_u16(0))) * extended_channels)
				continue
			9:
				if length < 12:
					return AssetBytesResult.failure("Truncated Creative Voice sample header.")

				next_rate = int(block.decode_u32(0))
				next_bits = int(block[4])
				next_channels = int(block[5])
				var codec := int(block.decode_u16(6))

				if not ((codec == 0 and next_bits == 8) or (codec == 4 and next_bits == 16)):
					return AssetBytesResult.failure("Unsupported Creative Voice sample codec.")

				pcm = block.slice(12)
			_:
				return AssetBytesResult.failure("Unsupported Creative Voice block %d." % type)

		if next_rate < 1000 or next_rate > 192000 or next_channels not in [1, 2]:
			return AssetBytesResult.failure("Invalid Creative Voice sample format.")

		if not samples.is_empty() and (rate != next_rate or channels != next_channels or bits != next_bits):
			return AssetBytesResult.failure("Creative Voice changes sample format within one sound.")

		rate = next_rate
		channels = next_channels
		bits = next_bits

		if pcm.size() % (channels * (bits / 8)) != 0 or samples.size() + pcm.size() > MAX_PCM_BYTES:
			return AssetBytesResult.failure("Invalid or oversized Creative Voice sample data.")

		samples.append_array(pcm)

	if repeat_start >= 0 or extended_rate > 0:
		return AssetBytesResult.failure("Incomplete Creative Voice repeat or extended block.")

	var result := Sc2ImportAudio.pcm_wave(samples, rate, channels, bits)

	if result.ok and loop_start >= 0:
		var frame_size := channels * (bits / 8)
		var sampler := PackedByteArray()
		sampler.resize(68)
		sampler.encode_u32(0, 0x6c706d73)
		sampler.encode_u32(4, 60)
		sampler.encode_u32(16, 1000000000 / rate)
		sampler.encode_u32(20, 60)
		sampler.encode_u32(36, 1)
		sampler.encode_u32(52, loop_start / frame_size)
		sampler.encode_u32(56, loop_end / frame_size - 1)
		result.bytes.append_array(sampler)
		result.bytes.encode_u32(4, result.bytes.size() - 8)

	return result
