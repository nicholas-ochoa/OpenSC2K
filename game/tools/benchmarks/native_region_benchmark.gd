extends "res://tools/benchmarks/fixture_paths.gd"
## Compare CPU region preparation, including the native bridge and cold asset setup.
## Headless timings exclude actual GPU uploads and frame presentation.

@warning_ignore_start("integer_division")


func _benchmark_initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path(input_path(large_city_path(512))))
	var large := Sc2SpriteArchive.load_path(reference_path("DATA/LARGE.DAT"))
	var small := Sc2SpriteArchive.combine([Sc2SpriteArchive.load_path(reference_path("DATA/SMALLMED.DAT")),
		Sc2SpriteArchive.load_path(reference_path("DATA/SPECIAL.DAT"))])
	var palette := Sc2Palette.index_encoding()
	report_metadata({"regions_per_stage": 64, "repeats": 3, "stages": ["cold", "pan", "return"],
		"includes": "snapshot, asset setup, geometry and bridge", "excludes": "GPU uploads and display"})
	for view in 3:
		var edge := 128 if view == 0 else 256
		var center := CityIsometricRenderer.output_size_for_view(view, city.map_size) / 2 / edge
		var sprites := large if view == 2 else small
		for repeat in 3:
			for native: bool in ([false, true] if repeat % 2 == 0 else [true, false]):
				var context := CityGpuBuildContext.new()
				context.use_native = native
				var offsets := [0, 8, 0]
				for stage in offsets.size():
					var before := context.tile_builds
					var quads := 0
					var started := Time.get_ticks_usec()
					var first := 0
					for y in range(-4, 4):
						for x in range(-4, 4):
							var result := CityGpuRegionRenderer.render(city, palette, sprites,
								Rect2i((center + Vector2i(x + offsets[stage], y)) * edge, Vector2i(edge, edge)),
								view, CityViewMode.Mode.CITY, true, true, context, 1, -1, false)
							if not result.ok:
								printerr(result.error)
								quit(1)
								return
							quads += result.gpu_arrays[Mesh.ARRAY_VERTEX].size() / 4
							if first == 0:
								first = Time.get_ticks_usec() - started
					print("REGION_COMPARE ", JSON.stringify({"backend": "rust" if native else "gdscript", "view": view,
						"repeat": repeat, "stage": ["cold", "pan", "return"][stage], "total_us": Time.get_ticks_usec() - started,
						"first_us": first, "quads": quads, "tile_builds": context.tile_builds - before}))
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([input_path(large_city_path(512)), reference_path("DATA/LARGE.DAT"),
		reference_path("DATA/SMALLMED.DAT"), reference_path("DATA/SPECIAL.DAT")])
