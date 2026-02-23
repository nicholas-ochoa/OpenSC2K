extends SceneTree


func _initialize() -> void:
	var city := CityState.new()

	for size in [0, 1, 7, 8, 9, 31, 16384, 262144]:
		city.tile_flags.resize(size)

		for index in size:
			city.tile_flags[index] = (index * 37 + (index >> 3)) & 255

		for mask in [0, 1, 4, 0x3f, 0x80, 0xc6, 0xff]:
			var expected := city.tile_flags.duplicate()

			for index in size:
				expected[index] &= mask

			assert(city.masked_tile_flag_signature(mask) == hash(expected))
			assert(city.masked_tile_flag_signature(mask) == hash(expected))

		if size > 0:
			city.tile_flags[0] ^= 0xc6
			var expected := city.tile_flags.duplicate()

			for index in size:
				expected[index] &= 0xc6

			assert(city.masked_tile_flag_signature(0xc6) == hash(expected))

	print("PASS: packed flag signatures match byte masks, high bits, tails, empty maps and cache invalidation")
	quit()
