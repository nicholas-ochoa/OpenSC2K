extends SceneTree
## Cold GPU region build time with and without the build context's tile shortcut,
## and CPU region paint time, over every 256-pixel region of the city view.
class ReferenceOnlyContext extends CityGpuBuildContext:
	func _fast_tile(_recorder: CityGpuDrawList, _city: CityState, _palette: Sc2Palette,
			_sprites: Sc2SpriteArchive, _config: Dictionary, _origin: int, _x: int, _y: int) -> bool:
		return false


func _initialize() -> void:
	var palette := Sc2Palette.index_encoding()
	var large := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var small := Sc2SpriteArchive.combine([Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SMALLMED.DAT"), Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SPECIAL.DAT")])
	var repeats := int(OS.get_environment("CITY_BENCH_REPEATS")) if OS.has_environment("CITY_BENCH_REPEATS") else 3

	for path in ["res://../references/SIMCITY2000/CITIES/SYDNEY.SC2", "res://../local/large-cities/stitched-256.sc2x"]:
		var city := CityState.from_document(Sc2File.load_path(path))

		for view in 3:
			var sprites := large if view == 2 else small
			var best := {true: 1 << 62, false: 1 << 62}
			var quads := {}

			for repeat in repeats:
				for fast: bool in [true, false]:
					var context: CityGpuBuildContext = CityGpuBuildContext.new() if fast else ReferenceOnlyContext.new()
					var size := CityIsometricRenderer.output_size_for_view(view, city.map_size)
					var began := Time.get_ticks_usec()
					var count := 0

					for y in range(0, size.y, 256):
						for x in range(0, size.x, 256):
							var result := CityGpuRegionRenderer.render(city, palette, sprites, Rect2i(x, y, 256, 256), view, "city", true, true, context, 1, -1, false)
							assert(result.ok)
							count += result.gpu_arrays[Mesh.ARRAY_VERTEX].size() / 4

					best[fast] = mini(best[fast], Time.get_ticks_usec() - began)
					quads[fast] = count

			var cpu_best := 1 << 62

			for repeat in repeats:
				var size := CityIsometricRenderer.output_size_for_view(view, city.map_size)
				var began := Time.get_ticks_usec()

				for y in range(0, size.y, 256):
					for x in range(0, size.x, 256):
						assert(CityRegionRenderer.render(city, palette, sprites, Rect2i(x, y, 256, 256), view, "city").ok)

				cpu_best = mini(cpu_best, Time.get_ticks_usec() - began)

			assert(quads[true] == quads[false])
			print("FAST_TILE map=%d view=%d fast_ms=%.1f reference_ms=%.1f saving=%.1f%% quads=%d cpu_region_ms=%.1f" % [city.map_size, view, best[true] / 1000.0, best[false] / 1000.0, 100.0 * (best[false] - best[true]) / best[false], quads[true], cpu_best / 1000.0])

	quit()
