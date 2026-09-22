extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	_test_macintosh_resources()
	var archive := PackedByteArray()
	archive.resize(36)
	archive[0] = 65
	archive.encode_u32(12, 32)
	archive[16] = 66
	archive.encode_u32(28, 34)
	archive[32] = 11
	archive[33] = 12
	archive[34] = 21
	archive[35] = 22
	var loaded := Sc2ImportContainer.named_archive(archive, "fixture")
	assert(loaded.error.is_empty() and loaded.resources.size() == 2)
	assert(loaded.resources[0].name == "A" and loaded.resources[0].bytes == PackedByteArray([11, 12]))
	assert(loaded.resources[1].source == "fixture" and loaded.resources[1].bytes == PackedByteArray([21, 22]))
	archive.encode_u32(28, 31)
	assert(not Sc2ImportContainer.named_archive(archive, "fixture").error.is_empty())
	archive.encode_u32(12, 0xffffffff)
	assert(not Sc2ImportContainer.named_archive(archive, "fixture").error.is_empty())
	assert(not Sc2ImportContainer.macintosh(PackedByteArray(), "fixture").error.is_empty())
	assert(not Sc2ImportContainer.windows(PackedByteArray(), "fixture").error.is_empty())
	var pcm := Sc2ImportAudio.pcm_wave(PackedByteArray([0, 128, 255]), 11025, 1, 8)
	assert(pcm.ok and pcm.bytes.size() == 48 and pcm.bytes.decode_u32(40) == 3)
	var wave := AudioStreamWAV.load_from_buffer(pcm.bytes)
	assert(wave != null and wave.mix_rate == 11025 and wave.format == AudioStreamWAV.FORMAT_8_BITS)
	assert(not Sc2ImportAudio.pcm_wave(PackedByteArray([0]), 22050, 2, 16).ok)
	var sound := PackedByteArray()
	sound.resize(45)
	_put_be16(sound, 0, 1)
	_put_be16(sound, 2, 1)
	_put_be16(sound, 4, 5)
	_put_be16(sound, 10, 1)
	_put_be16(sound, 12, 0x8051)
	_put_be32(sound, 16, 20)
	_put_be32(sound, 24, 3)
	_put_be32(sound, 28, 11025 << 16)
	sound[42] = 0
	sound[43] = 128
	sound[44] = 255
	var converted := Sc2ImportAudio.mac_sound(sound)
	assert(converted.ok and converted.bytes == pcm.bytes)
	sound[40] = 0xfe
	assert(not Sc2ImportAudio.mac_sound(sound).ok)
	sound[40] = 0
	_put_be32(sound, 24, 0xffffffff)
	assert(not Sc2ImportAudio.mac_sound(sound).ok)
	print("PASS: bounded source directories, malformed inputs and Macintosh PCM conversion")
	quit()


func _put_be16(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 255
	data[offset + 1] = value & 255


func _put_be32(data: PackedByteArray, offset: int, value: int) -> void:
	_put_be16(data, offset, value >> 16)
	_put_be16(data, offset + 2, value & 65535)


func _test_macintosh_resources() -> void:
	var fork := PackedByteArray()
	fork.resize(74)
	_put_be32(fork, 0, 16)
	_put_be32(fork, 4, 24)
	_put_be32(fork, 8, 8)
	_put_be32(fork, 12, 50)
	_put_be32(fork, 16, 4)
	fork[20] = 10
	fork[21] = 20
	fork[22] = 30
	fork[23] = 40
	_put_be16(fork, 48, 28)
	fork[54] = 84
	fork[55] = 69
	fork[56] = 83
	fork[57] = 84
	_put_be16(fork, 60, 10)
	_put_be16(fork, 62, 7)
	_put_be16(fork, 64, 0xffff)
	var apple_double := PackedByteArray()
	apple_double.resize(38)
	_put_be32(apple_double, 0, 0x00051607)
	_put_be32(apple_double, 4, 0x00020000)
	_put_be16(apple_double, 24, 1)
	_put_be32(apple_double, 26, 2)
	_put_be32(apple_double, 30, 38)
	_put_be32(apple_double, 34, fork.size())
	apple_double.append_array(fork)
	var mac_binary := PackedByteArray()
	mac_binary.resize(128)
	mac_binary[1] = 1
	mac_binary[2] = 65
	_put_be32(mac_binary, 87, fork.size())
	mac_binary.append_array(fork)
	for bytes in [fork, apple_double, mac_binary]:
		var result := Sc2ImportContainer.macintosh(bytes, "generated")
		assert(result.error.is_empty() and result.resources.size() == 1)
		assert(result.resources[0].type == "TEST" and result.resources[0].id == 7)
		assert(result.resources[0].bytes == PackedByteArray([10, 20, 30, 40]))
		for length in bytes.size():
			assert(not Sc2ImportContainer.macintosh(bytes.slice(0, length), "generated").error.is_empty())
	for offset in [0, 4, 8, 12, 16, 66]:
		var bad := fork.duplicate()
		_put_be32(bad, offset, 0xffffffff)
		assert(not Sc2ImportContainer.macintosh(bad, "generated").error.is_empty())
