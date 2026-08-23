extends "res://tools/benchmarks/fixture_paths.gd"


## Region preparation latency, separate from steady-state frame rate.
func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CityState.from_document(Sc2File.load_path(large_city_path(512)))
	var sprites := Sc2SpriteArchive.load_path(reference_path("DATA/LARGE.DAT"))
	var cache := CityRegionCache.new()
	cache.gpu_enabled = true
	cache.configure(city, Sc2Palette.index_encoding(), sprites, [1], 2, CityViewMode.Mode.CITY, {}, true, true)

	if OS.has_environment("CITY_BENCH_REGION_EDGE"):
		cache.region_edge = int(OS.get_environment("CITY_BENCH_REGION_EDGE"))

	var size := Vector2(1909, 733) / 0.25
	var start := Vector2(cache.native_size) / 2 - size / 2

	for offset in [Vector2.ZERO, Vector2(1024, 0), Vector2(2048, 0), Vector2.ZERO]:
		var began := Time.get_ticks_usec()
		cache.update_viewport(Rect2(start + offset, size))
		var missing := 0

		for key in cache.visible:
			if not cache.entries.has(key):
				missing += 1

		var first := -1.0
		var completed := cache.completed_regions
		var max_poll := 0

		while not cache.ready() and Time.get_ticks_usec() - began < 60000000:
			var poll := Time.get_ticks_usec()
			cache.tick()
			max_poll = maxi(max_poll, Time.get_ticks_usec() - poll)

			if first < 0 and cache.completed_regions > completed:
				first = (Time.get_ticks_usec() - began) / 1000.0

			await process_frame

		if not (cache.ready()):
			printerr("Benchmark check failed: cache.ready()")
			quit(1)
			return
		print("PAN edge=%d offset=%s missing=%d first_ms=%.2f ready_ms=%.2f max_poll_ms=%.2f metrics=%s" % [cache.region_edge, offset, missing, first, (Time.get_ticks_usec() - began) / 1000.0, max_poll / 1000.0, cache.metrics()])
		var warm := Time.get_ticks_msec() + 2000

		while Time.get_ticks_msec() < warm:
			cache.tick()
			await process_frame

	if OS.get_environment("CITY_BENCH_CONTINUOUS") == "1":
		var offset := Vector2.ZERO

		for velocity in [Vector2(1600, 0), Vector2(0, 1600), Vector2(-1600, 0)]:
			var began := Time.get_ticks_usec()
			var previous := began
			var missing_frames := 0
			var max_missing := 0
			var frames := 0

			while Time.get_ticks_usec() - began < 3000000:
				var now := Time.get_ticks_usec()
				offset += velocity * ((now - previous) / 1000000.0)
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

			print("CONTINUOUS screen_pixels_per_second=%s frames=%d uncovered_frames=%d max_missing_regions=%d" % [velocity * 0.25, frames, missing_frames, max_missing])

	cache.close()
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		large_city_path(512), reference_path("DATA/LARGE.DAT"),
	])
