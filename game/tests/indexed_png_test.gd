extends SceneTree

const Codec = preload("res://src/assets/indexed_png.gd")
# Independent Python zlib/struct fixture. All 256 palette colors are identical.
# Independent Python fixture: 4x1, 2-bit indices 0 through 3, three palette colors, and index 1 clear.
const LOW_DEPTH := "89504e470d0a1a0a0000000d49484452000000040000000102030000008452e75e00000009504c54450a141e28323c46505a16ac84740000000274524e53ff00e5b7304a0000000a49444154789c63900600001d001c8ef4f5210000000049454e44ae426082"
const FIXTURE := "89504e470d0a1a0a0000000d4948445200000004000000010803000000cee2ffff00000300504c5445285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078285078ea1b5a240000000174524e530040e6d8660000000d49444154789c6360605cbd0600020a0159b627e5db0000000049454e44ae426082"


func _initialize() -> void:
	# Independent zlib CRC-32 vectors: empty input, standard text, every byte value.
	assert(Codec._crc(PackedByteArray()) == 0)
	assert(Codec._crc("123456789".to_ascii_buffer()) == 0xcbf43926)
	var byte_values := PackedByteArray()
	for value in 256:
		byte_values.append(value)
	assert(Codec._crc(byte_values) == 0x29058c73)
	var bytes := FIXTURE.hex_decode()
	var decoded := Codec.decode(bytes)
	assert(decoded.ok, str(decoded))
	assert(decoded.width == 4 and decoded.height == 1)
	assert(decoded.pixels == PackedInt32Array([-1, 1, 171, 172]))
	assert(decoded.palette.colors[1] == Color8(40, 80, 120))
	assert(decoded.palette.colors[171] == decoded.palette.colors[172])
	var cycle: PackedInt32Array = decoded.palette.animation_index_map(1)
	assert(cycle[171] != cycle[172])
	var encoded := Codec.encode(decoded.width, decoded.height, decoded.pixels, decoded.palette)
	assert(encoded.ok)
	var round_trip := Codec.decode(encoded.bytes)
	assert(round_trip.ok and round_trip.pixels == decoded.pixels)
	assert(round_trip.palette.colors == decoded.palette.colors)
	var all_indices := PackedInt32Array()

	for index in 256:
		all_indices.append(index)

	var opaque := Codec.encode(256, 1, all_indices, decoded.palette)
	assert(opaque.ok and Codec.decode(opaque.bytes).pixels == all_indices)
	all_indices.append(-1)
	assert(not Codec.encode(257, 1, all_indices, decoded.palette).ok)
	assert(not Codec.encode(1, 1, PackedInt32Array([256]), decoded.palette).ok)
	assert(not Codec.encode(2, 1, PackedInt32Array([0]), decoded.palette).ok)
	var corrupt := bytes.duplicate()
	corrupt[50] ^= 1
	assert(not Codec.decode(corrupt).ok)
	assert(not Codec.decode(bytes.slice(0, bytes.size() - 1)).ok)
	var trailing := bytes.duplicate()
	trailing.append(0)
	assert(not Codec.decode(trailing).ok)
	# Imports accept low bit depths. An index past a short palette reads as entry 0.
	var low_depth := LOW_DEPTH.hex_decode()
	assert(not Codec.decode(low_depth).ok)
	var low_decoded := Codec.decode(low_depth, false)
	assert(low_decoded.ok and low_decoded.pixels == PackedInt32Array([0, -1, 2, 0]))
	assert(low_decoded.palette.colors[2] == Color8(70, 80, 90))
	var rgba := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	assert(not Codec.decode(rgba.save_png_to_buffer()).ok)
	print("Indexed PNG tests passed: exact indices, transparency, palette cycles, invalid input")
	quit()
