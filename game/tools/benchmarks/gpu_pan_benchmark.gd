extends "res://tools/benchmarks/fixture_paths.gd"


## Region preparation latency, separate from steady-state frame rate.
func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CityState.from_document(Sc2File.load_path(input_path(large_city_path(512))))
	var view := int(OS.get_environment("CITY_BENCH_ARTWORK")) if OS.has_environment("CITY_BENCH_ARTWORK") else 2
	var sprites := Sc2SpriteArchive.load_path(reference_path("DATA/LARGE.DAT")) if view == 2 else Sc2SpriteArchive.combine([
		Sc2SpriteArchive.load_path(reference_path("DATA/SMALLMED.DAT")), Sc2SpriteArchive.load_path(reference_path("DATA/SPECIAL.DAT"))])
	var cache := CityRegionCache.new()
	cache.gpu_enabled = true
	cache.configure(city, Sc2Palette.index_encoding(), sprites, [1], view, CityViewMode.Mode.CITY, {}, true, true)

	if OS.has_environment("CITY_BENCH_REGION_EDGE"):
		cache.region_edge = int(OS.get_environment("CITY_BENCH_REGION_EDGE"))

	var zoom := float(OS.get_environment("CITY_BENCH_ZOOM")) if OS.has_environment("CITY_BENCH_ZOOM") else 0.25
	var size := Vector2(1909, 733) / zoom
	report_metadata({"zoom": zoom, "artwork": view, "viewport": Vector2(1909, 733)})
	var start := Vector2(cache.native_size * cache.divisor) / 2 - size / 2

	var cold_only := OS.get_environment("CITY_BENCH_COLD_ONLY") == "1"
	var offsets: Array[Vector2] = [Vector2.ZERO]
	if not cold_only:
		offsets.append_array([Vector2(1024, 0), Vector2(2048, 0), Vector2(4096, 0), Vector2(-4096, 0), Vector2.ZERO])
	for offset in offsets:
		var began := Time.get_ticks_usec()
		cache.update_viewport(Rect2(start + offset, size))
		var missing := 0

		for key in cache.visible:
			if not cache.entries.has(key):
				missing += 1

		var first := -1.0
		var half := -1.0
		var initially_missing: Array[Vector2i] = []
		for key in cache.visible:
			if not cache.entries.has(key):
				initially_missing.append(key)
		var max_poll := 0

		while not cache.ready() and Time.get_ticks_usec() - began < 60000000:
			var poll := Time.get_ticks_usec()
			cache.tick()
			max_poll = maxi(max_poll, Time.get_ticks_usec() - poll)

			var filled := 0
			for key in initially_missing:
				if cache.entries.has(key):
					filled += 1
			if first < 0 and filled > 0:
				first = (Time.get_ticks_usec() - began) / 1000.0
			if half < 0 and filled * 2 >= initially_missing.size():
				half = (Time.get_ticks_usec() - began) / 1000.0

			await process_frame

		if not (cache.ready()):
			printerr("Benchmark check failed: cache.ready()")
			quit(1)
			return
		print("PAN edge=%d offset=%s missing=%d first_ms=%.2f half_ms=%.2f ready_ms=%.2f max_poll_ms=%.2f metrics=%s" % [cache.region_edge, offset, missing, first, half, (Time.get_ticks_usec() - began) / 1000.0, max_poll / 1000.0, cache.metrics()])
		if cold_only:
			continue
		var warm := Time.get_ticks_msec() + 2000

		while Time.get_ticks_msec() < warm:
			cache.tick()
			await process_frame

	if OS.get_environment("CITY_BENCH_CONTINUOUS") == "1":
		var offset := Vector2.ZERO

		for screen_velocity: Vector2 in [Vector2(800, 0), Vector2(0, 800), Vector2(-800, 0)]:
			var velocity := screen_velocity / zoom
			var began := Time.get_ticks_usec()
			var previous := began
			var missing_frames := 0
			var max_missing := 0
			var frames := 0

			while Time.get_ticks_usec() - began < 3000000:
				var now := Time.get_ticks_usec()
				offset += velocity * ((now - previous) / 1000000.0)
				var travel := ((Vector2(cache.native_size * cache.divisor) - size) / 2).max(Vector2.ZERO)
				offset = offset.clamp(-travel, travel)
				previous = now
				cache.update_viewport(Rect2(start + offset, size))
				cache.tick()
				var missing := 0

				for key in cache.visible:
					if not cache.entries.has(key):
						missing += 1

				if missing > 0:
					missing_frames += 1

				max_missing = maxi(max_missing, missing)
				frames += 1
				await process_frame

			print("CONTINUOUS screen_pixels_per_second=%s frames=%d uncovered_frames=%d max_missing_regions=%d" % [velocity * zoom, frames, missing_frames, max_missing])

	cache.close()
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		input_path(large_city_path(512)), reference_path("DATA/LARGE.DAT"), reference_path("DATA/SMALLMED.DAT"), reference_path("DATA/SPECIAL.DAT"),
	])
