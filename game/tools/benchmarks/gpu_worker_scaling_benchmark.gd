extends "res://tools/benchmarks/fixture_paths.gd"
## Worker-thread scaling of GPU region geometry builds, without the main loop.
## Each thread owns one build context, as each region worker does. Object
## creation and shared reference counts serialize GDScript threads.

@warning_ignore_start("integer_division")


func _benchmark_initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path(input_path(large_city_path(512))))
	var view := int(OS.get_environment("CITY_BENCH_ARTWORK")) if OS.has_environment("CITY_BENCH_ARTWORK") else 2
	var sprites := Sc2SpriteArchive.load_path(reference_path("DATA/LARGE.DAT")) if view == 2 else Sc2SpriteArchive.combine([
		Sc2SpriteArchive.load_path(reference_path("DATA/SMALLMED.DAT")), Sc2SpriteArchive.load_path(reference_path("DATA/SPECIAL.DAT"))])
	var palette := Sc2Palette.index_encoding()
	var edge := CityRegionCache.GPU_SMALL_REGION_EDGE if view == 0 else CityRegionCache.GPU_REGION_EDGE
	var size := CityIsometricRenderer.output_size_for_view(view, city.map_size)
	var keys: Array[Vector2i] = []
	var center := size / 2 / edge

	for y in range(center.y - 6, center.y + 6):
		for x in range(center.x - 6, center.x + 6):
			keys.append(Vector2i(x, y))

	var counts := [1, 2, 4, 8]

	if OS.has_environment("CITY_BENCH_THREADS"):
		counts = [int(OS.get_environment("CITY_BENCH_THREADS"))]

	for threads: int in counts:
		var began := Time.get_ticks_usec()
		var running: Array[Thread] = []

		for index in threads:
			var mine: Array[Vector2i] = []

			for key_index in range(index, keys.size(), threads):
				mine.append(keys[key_index])

			var thread := Thread.new()
			thread.start(_build.bind(city, palette, sprites, view, edge, mine))
			running.append(thread)

		var usec := 0

		for thread in running:
			usec += int(thread.wait_to_finish())

		print("THREADS %d regions=%d wall_ms=%.1f worker_cpu_ms=%.1f" % [threads, keys.size(),
			(Time.get_ticks_usec() - began) / 1000.0, usec / 1000.0])

	quit()


func _build(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, view: int, edge: int,
		keys: Array[Vector2i]) -> int:
	var began := Time.get_ticks_usec()
	var context := CityGpuBuildContext.new()
	var request := CityGpuRegionBatch.Request.new()
	request.city = city
	request.prepared = true
	request.palette = palette
	request.sprites = sprites
	request.keys = keys
	request.edge = edge
	request.view = view
	request.generation = 1
	var result := CityGpuRegionBatch.build(request, context, -1)

	if not result.ok:
		printerr("Benchmark check failed: ", result.error)

	return Time.get_ticks_usec() - began


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		input_path(large_city_path(512)), reference_path("DATA/LARGE.DAT"), reference_path("DATA/SMALLMED.DAT"),
		reference_path("DATA/SPECIAL.DAT"),
	])
