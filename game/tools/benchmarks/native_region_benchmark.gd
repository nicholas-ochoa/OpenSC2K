extends "res://tools/benchmarks/fixture_paths.gd"
## Measure worker-side region preparation: the native builder, the Godot bridge
## and the region result. Headless timings exclude GPU uploads and presentation.

@warning_ignore_start("integer_division")


func _benchmark_initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path(input_path(large_city_path(512))))
	var large := Sc2SpriteArchive.load_path(reference_path("DATA/LARGE.DAT"))
	var small := Sc2SpriteArchive.combine([Sc2SpriteArchive.load_path(reference_path("DATA/SMALLMED.DAT")),
		Sc2SpriteArchive.load_path(reference_path("DATA/SPECIAL.DAT"))])
	var palette := Sc2Palette.index_encoding()
	var stages := ["cold", "pan", "return", "revision"]
	report_metadata({"regions_per_stage": 64, "repeats": 3, "stages": stages,
		"includes": "snapshot, artwork setup, native geometry, bridge and region result",
		"excludes": "GPU uploads and display"})

	for view in 3:
		var edge := 128 if view == 0 else 256
		var center := CityIsometricRenderer.output_size_for_view(view, city.map_size) / 2 / edge
		var sprites := large if view == 2 else small

		for repeat in 3:
			var context := CityGpuBuildContext.new()
			# The last stage returns to the first regions in a new city revision.
			var offsets := [0, 8, 0, 0]

			for stage in stages.size():
				var revision := 2 if stage == 3 else 1
				var builds := context.tile_builds
				var reuses := context.tile_reuses
				var atlas_changes := 0
				var quads := 0
				var started := Time.get_ticks_usec()
				var first := 0

				for y in range(-4, 4):
					for x in range(-4, 4):
						var atlas_revision := context.atlas_revision
						var result := CityGpuRegionRenderer.render(city, palette, sprites,
							Rect2i((center + Vector2i(x + offsets[stage], y)) * edge, Vector2i(edge, edge)),
							view, CityViewMode.Mode.CITY, true, true, context, revision, -1, false)

						if not result.ok:
							printerr(result.error)
							quit(1)
							return

						atlas_changes += int(context.atlas_revision != atlas_revision)
						quads += result.gpu_arrays[Mesh.ARRAY_VERTEX].size() / 4

						if first == 0:
							first = Time.get_ticks_usec() - started

				print("REGION ", JSON.stringify({"view": view, "repeat": repeat, "stage": stages[stage],
					"total_us": Time.get_ticks_usec() - started, "first_us": first, "quads": quads,
					"tile_builds": context.tile_builds - builds, "tile_reuses": context.tile_reuses - reuses,
					"cached_tiles": context.cached_tile_count(), "atlas_changes": atlas_changes,
					"atlas_edge": context.atlas_edge}))

	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([input_path(large_city_path(512)), reference_path("DATA/LARGE.DAT"),
		reference_path("DATA/SMALLMED.DAT"), reference_path("DATA/SPECIAL.DAT")])
