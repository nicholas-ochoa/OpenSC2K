extends "res://tools/benchmarks/fixture_paths.gd"
## CPU calls only. Fixture generation, snapshot setup, and drawing are not timed.


func _benchmark_initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var samples := int(OS.get_environment("CITY_BENCH_SAMPLES")) if OS.has_environment("CITY_BENCH_SAMPLES") else 3
	if samples < 1:
		printerr("Invalid sample count")
		quit(1)
		return
	report_metadata({"samples": samples, "timed_work": "cold and reopened set_data_view calls; excludes drawing"})
	for edge in [128, 512]:
		for terrain in [false, true]:
			var doc := EmptyCityTemplate.create(edge)
			if terrain:
				var generated := NewCityTerrain.generate(doc, true, true, 16, 16, 8, SimRandom.new(123), GameLcgRandom.new(789))
				if not generated.ok:
					printerr(generated.error)
					quit(1)
					return
			else:
				var alt := doc.find_chunk("ALTM").decoded_payload.duplicate()
				for index in edge * edge:
					BinaryData.write_u16_be(alt, index * 2, 16)
				if not doc.find_chunk("ALTM").set_decoded_payload(alt):
					quit(1)
					return
			var city := CityState.from_document(doc)
			var display := CityState.from_document(doc.duplicate_document())
			print("FIXTURE ", JSON.stringify({"edge":edge,"terrain":terrain,"sha256":bytes_sha256(doc.serialize(true).data)}))
			for mode in [CityViewMode.Mode.LAND_VALUE, CityViewMode.Mode.HEIGHT]:
				for sample in samples:
					var view := CityMapControl.new()
					view.theme = AppUiTheme.current()
					view.size = Vector2(1280, 720)
					root.add_child(view)
					var start := Time.get_ticks_usec()
					view.set_data_view(city, mode)
					var cold := Time.get_ticks_usec() - start
					var mesh_id := view.data_view_mesh.get_instance_id()
					var source_bytes := 0
					for surface in view.data_view_mesh.get_surface_count():
						for array in view.data_view_mesh.surface_get_arrays(surface):
							if array != null:
								source_bytes += array.to_byte_array().size()
					view.clear_data_view()
					view.set_city_view(display, CityMapSource.new(CityIsometricRenderer.output_size_for_view(CityIsometricRenderer.VIEW_LARGE, edge)))
					start = Time.get_ticks_usec()
					view.set_data_view(city, mode)
					var reopened := Time.get_ticks_usec() - start
					print(JSON.stringify({"edge":edge,"terrain":terrain,"mode":mode,"sample":sample,
						"cold_usec":cold,"reopen_usec":reopened,"mesh_reused":mesh_id == view.data_view_mesh.get_instance_id(),
						"source_array_bytes":source_bytes}))
					view.free()
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray(["res://src/view/city_data_view.gd", "res://src/view/map/layers.gd"])
