extends SceneTree


func _initialize() -> void:
	var city := CityState.new()
	var reference := CityState.new()

	for size in [0, 1, 7, 8, 9, 31, 16384, 262144]:
		city.tile_flags.resize(size)

		for index in size:
			city.tile_flags[index] = (index * 37 + (index >> 3)) & 255

		for mask in [0, 1, 4, 0x3f, 0x80, 0xc6, 0xff]:
			var expected := city.tile_flags.duplicate()

			for index in size:
				expected[index] &= mask

			reference.tile_flags = expected
			var signature := reference.masked_tile_flag_signature(0xff)
			assert(city.masked_tile_flag_signature(mask) == signature)
			assert(city.masked_tile_flag_signature(mask) == signature)

		if size > 0:
			for changed in [0, mini(4095, size - 1), mini(4096, size - 1), size - 1]:
				var before := city.masked_tile_flag_signature(0xc6)
				city.tile_flags[changed] ^= 0x39
				assert(city.masked_tile_flag_signature(0xc6) == before, "Masked bits do not change the signature")
				city.tile_flags[changed] ^= 0x39 | 0xc6
				assert(city.masked_tile_flag_signature(0xc6) != before, "Visible bits change the signature")

	print("PASS: packed flag signatures match byte masks, high bits, tails, empty maps and cache invalidation")
	quit()
