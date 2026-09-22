extends SceneTree
const Reference = preload("res://tests/support/native_data_map_reference.gd")
const Results = preload("res://tests/support/timing_results.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# The grid-math suite covers intermediate dimensions. Compare the full phase
	# at both boundary sizes, with ordinance branches exercised on the small map.
	for edge in [128, 512]:
		var modes := [0]
		if edge == 128:
			modes.append(PollutionPhase.POLICE_COVERAGE_ORDINANCE | PollutionPhase.FIRE_COVERAGE_ORDINANCE | PollutionPhase.CRIME_REDUCTION_ORDINANCE)
		for ordinances in modes:
			var doc := EmptyCityTemplate.create(edge)
			assert(doc.enable_full_resolution_maps())
			var city := CityState.from_document(doc)
			var buildings := city.buildings.duplicate()
			var zones := city.zones.duplicate()
			var flags := city.tile_flags.duplicate()
			var types := [0, 1, 5, 6, 12, 15, 0x1d, 0x70, 0x80, 0x90, 0xa0, 0xb0, 0xc5, 0xfb,
				PollutionPhase.POLICE_STATION, PollutionPhase.FIRE_STATION, PollutionPhase.BIG_PARK]
			# cover every building byte used by the derived source tables
			types.append_array(range(256))

			for index in buildings.size():
				buildings[index] = types[(index * 13 + index / edge) % types.size()]
				zones[index] = (index % 7) | (PollutionPhase.ZONE_BUILDING_ORIGIN if index % 107 == 0 else 0)
				flags[index] = (index * 71) % 256

			assert(city.replace_buildings(buildings) and city.replace_zones(zones) and city.replace_tile_flags(flags))

			for id in Sc2File.HALF_MAP_CHUNKS + Sc2File.QUARTER_MAP_CHUNKS:
				var values := doc.find_chunk(id).decoded_payload.duplicate()

				for index in values.size():
					values[index] = (index * 37 + index / edge) % 256

				assert(doc.find_chunk(id).set_decoded_payload(values))

			assert(doc.set_misc_u32(PollutionPhase.MISC_ORDINANCES, ordinances))
			var original := CityState.from_document(doc.duplicate_document())
			var expected := Reference.run(original)
			var actual := NativeDataMapPhase.run(city)
			assert(actual.ok and Results.without_timings(actual) == Results.without_timings(expected))
			assert(doc.serialize().data == original.document.serialize().data, "Optimized maps or totals differ from reference bytes")

		print("PASS: exact data-map optimization at %d" % edge)

	quit()
