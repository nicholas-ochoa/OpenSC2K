extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	var flags := PackedByteArray()
	flags.resize(256)

	for value in 256:
		flags[value] = value

	assert(city.document.find_chunk("XBIT").set_decoded_payload(flags))
	city.resync_mirrors(["XBIT"])
	var filtered := CityViewFilter.surface_copy(city, {"water": false})

	for value in 256:
		var x := value / 16
		var y := value % 16
		var actual := [city.is_salt_water(x, y), city.is_flipped(x, y), city.is_water(x, y),
			city.is_watered(x, y), city.is_piped(x, y), city.is_powered(x, y), city.is_powerable(x, y)]
		var bits := [1, 2, 4, 16, 32, 64, 128]

		for index in bits.size():
			assert(actual[index] == ((value & bits[index]) != 0))

		assert(filtered.tile_flags[value] == (value & 251))
		assert(city.tile_flags[value] == value)

	assert(city.document.find_chunk("XBIT").decoded_payload == flags)
	var zones := city.document.find_chunk("XZON")

	for value in 256:
		zones.write_decoded_byte(0, value)
		city.resync_mirrors(["XZON"])
		assert(city.zone_id(0, 0) == value % 16)
		assert(city.building_corners(0, 0) == (value / 16) * 16)
		assert(city.set_zone_id(0, 0, 9))
		assert(zones.decoded_payload[0] == (value / 16) * 16 + 9)
		assert(city.set_building_corners(0, 0, 160))
		assert(zones.decoded_payload[0] == 169)

	assert(not city.set_zone_id(0, 0, 16))
	assert(not city.set_building_corners(0, 0, 161))
	var altitude := city.document.find_chunk("ALTM")

	for word in [0, 1, 31, 32, 992, 1024, 31744, 32768, 65535]:
		assert(city._set_altitude_word(0, 0, word))
		assert(city.land_altitude(0, 0) == word % 32)
		assert(city.water_altitude(0, 0) == (word / 32) % 32)
		assert(city.tunnel_levels(0, 0) == word / 1024)

		for level in [0, 31]:
			assert(city._set_altitude_word(0, 0, word))
			assert(city.set_land_altitude(0, 0, level))
			assert(city.altitude_words[0] == word - word % 32 + level)
			assert(city._set_altitude_word(0, 0, word))
			assert(city.set_water_altitude(0, 0, level))
			assert(city.altitude_words[0] == word - ((word / 32) % 32) * 32 + level * 32)

		assert(city.set_tunnel_levels(0, 0, 63))
		var saved := (int(altitude.decoded_payload[0]) << 8) | altitude.decoded_payload[1]
		assert(saved == city.altitude_words[0] and saved / 1024 == 63)

	assert(not city.set_land_altitude(0, 0, 32))
	assert(not city.set_water_altitude(0, 0, 32))
	assert(not city.set_tunnel_levels(0, 0, 64))
	print("PASS: tile flags, filtered bits, packed zones and altitude fields")
	quit()
