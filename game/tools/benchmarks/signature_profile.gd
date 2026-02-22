extends SceneTree
func _initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://../local/large-cities/stitched-512.sc2x"))
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
		CityIsometricRenderer._static_text_overlay_signature(city)
		var overlays := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		for data in [city.altitude_words, city.terrain, city.buildings, city.zones, city.document.find_chunk("XTRF").decoded_payload]:
			hash(data)
		var arrays := Time.get_ticks_usec() - started
		print("SIGNATURE flags_us=%d overlays_us=%d arrays_us=%d signs_us=%d things_us=%d" % [flags, overlays, arrays, signs, things])
	quit()
