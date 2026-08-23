extends "res://tools/benchmarks/fixture_paths.gd"

const TimingResults = preload("res://tests/support/timing_results.gd")


## Main-thread admission/publication costs; excludes city rendering and audio.
func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for edge in [256, 384, 512]:
		var source := Sc2File.load_path(large_city_path(edge))
		var sync := GameSpeedController.new(SimulationEngine.new(CityState.from_document(source.duplicate_document()), 123, 456, 789))
		var sliced := GameSpeedController.new(SimulationEngine.new(CityState.from_document(source.duplicate_document()), 123, 456, 789))
		sync.set_speed(GameSpeedController.Speed.CHEETAH)
		sliced.set_speed(GameSpeedController.Speed.CHEETAH)
		var runner := FrameSimulationRunner.new(sliced)
		var max_sync_usec := 0
		var max_frame_usec := 0
		var max_work_usec := 0
		var max_snapshot_usec := 0
		var grants := 0
		var frames := 0

		for day in 25:
			var started := Time.get_ticks_usec()
			var expected := sync.advance_time(200, day * 200)
			max_sync_usec = maxi(max_sync_usec, Time.get_ticks_usec() - started)
			if not (expected.ok):
				printerr("Benchmark check failed: expected.ok")
				quit(1)
				return
			started = Time.get_ticks_usec()
			var actual := runner.advance_time(200, day * 200)
			max_frame_usec = maxi(max_frame_usec, Time.get_ticks_usec() - started)

			while runner.is_pending():
				await process_frame
				started = Time.get_ticks_usec()
				actual = runner.advance_time(0, day * 200)
				max_frame_usec = maxi(max_frame_usec, Time.get_ticks_usec() - started)
				frames += 1

			if not (TimingResults.without_timings(actual) == TimingResults.without_timings(expected)):
				printerr("Benchmark check failed: TimingResults.without_timings(actual) == TimingResults.without_timings(expected)")
				quit(1)
				return
			max_snapshot_usec = maxi(max_snapshot_usec, runner.snapshot_usec)
			max_work_usec = maxi(max_work_usec, int(runner.last_work_metrics.max_slice_usec))
			grants += int(runner.last_work_metrics.slices)

		if not (sync.engine.city.document.serialize().data == sliced.engine.city.document.serialize().data):
			printerr("Benchmark check failed: sync.engine.city.document.serialize().data == sliced.engine.city.document.serialize().data")
			quit(1)
			return
		runner.close()
		print("SIZE %d sync_max_ms=%.3f frame_call_max_ms=%.3f snapshot_max_ms=%.3f worker_slice_max_ms=%.3f grants=%d frames=%d" % [edge, max_sync_usec / 1000.0, max_frame_usec / 1000.0, max_snapshot_usec / 1000.0, max_work_usec / 1000.0, grants, frames])

	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		large_city_path(256), large_city_path(384), large_city_path(512),
	])
