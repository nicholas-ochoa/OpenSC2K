extends "res://tools/benchmarks/fixture_paths.gd"


func _benchmark_initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path(large_city_path(512)))

	for step in 4:
		city.tile_flags[10] ^= 0xc6
		var started := Time.get_ticks_usec()
		city.masked_tile_flag_signature(0xc6)
		var flags := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		OverlayData.sign_indices(city.text_overlays)
		var signs := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()

		for record in city.thing_count():
			city.thing(record)

		var things := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		IsometricStaticVisuals._static_text_overlay_signature(city)
		var overlays := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()

		for data in [city.altitude_words, city.terrain, city.buildings, city.zones, city.document.find_chunk("XTRF").decoded_payload]:
			hash(data)

		var arrays := Time.get_ticks_usec() - started
		print("SIGNATURE flags_us=%d overlays_us=%d arrays_us=%d signs_us=%d things_us=%d" % [flags, overlays, arrays, signs, things])

	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		large_city_path(512),
	])
