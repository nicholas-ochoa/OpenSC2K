extends "res://tools/benchmarks/fixture_paths.gd"


func _benchmark_initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path(large_city_path(512)))

	for step in 4:
		city.set_tile_flag(0, 10, 0x40, not city.is_powered(0, 10))
		var started := Time.get_ticks_usec()
		IsometricStaticVisuals.static_visual_signature(city)
		var total := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		IsometricStaticVisuals.static_visual_signature(city)
		var repeated := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
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
		print("SIGNATURE total_us=%d repeated_us=%d flags_us=%d overlays_us=%d arrays_us=%d signs_us=%d things_us=%d" % [total, repeated, flags, overlays, arrays, signs, things])

	for step in 4:
		city.set_text_overlay_id(10, 10 + step, 0xfb)
		var started := Time.get_ticks_usec()
		IsometricStaticVisuals.static_visual_signature(city)
		print("SIGNATURE changed_overlay_us=%d" % (Time.get_ticks_usec() - started))

	var simulated := CityState.from_document(Sc2File.load_path(large_city_path(512)))
	var engine := SimulationEngine.new(simulated, 123, 456, 789)
	IsometricStaticVisuals.static_visual_signature(simulated)

	for day in 4:
		assert(engine.advance_day().ok)
		assert(engine.advance_moving_things(day * 200).ok)
		var started := Time.get_ticks_usec()
		IsometricStaticVisuals.static_visual_signature(simulated)
		print("SIGNATURE simulated_day=%d total_us=%d" % [day + 1, Time.get_ticks_usec() - started])

	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		large_city_path(512),
	])
