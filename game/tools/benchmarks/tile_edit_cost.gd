extends SceneTree
## Cost of building a fixture one tile at a time, which is how the tests and the
## benchmarks make their cities. CPU timings only.

const TILES := 4096


func _init() -> void:
	for edge in [128, 512]:
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		assert(city.is_valid(), city.load_error)
		var side := 64
		var results := {}

		for label in ["set_building_id", "set_zone_id", "set_tile_flag", "set_text_overlay_id", "set_land_altitude"]:
			var begin := Time.get_ticks_usec()

			for offset in TILES:
				var x := offset % side
				var y := offset / side

				match label:
					"set_building_id":
						city.set_building_id(x, y, 0x1d)
					"set_zone_id":
						city.set_zone_id(x, y, 0x03)
					"set_tile_flag":
						city.set_tile_flag(x, y, 0x40, true)
					"set_text_overlay_id":
						city.set_text_overlay_id(x, y, 0x0102 if edge > 128 else 0x02)
					"set_land_altitude":
						city.set_land_altitude(x, y, 0x0b)

			results[label] = (Time.get_ticks_usec() - begin) / 1000.0

		var line := "SIZE %d tiles=%d" % [edge, TILES]

		for label in results:
			line += " %s_ms=%.2f" % [label, results[label]]

		print(line)

	quit()
