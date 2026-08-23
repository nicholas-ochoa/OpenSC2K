extends "res://tools/benchmarks/fixture_paths.gd"

@warning_ignore_start("integer_division")


## Read-only SC2X day-3 worker profile. Pass a city path after --.
## Headless frame admission costs exclude rendering and GPU work.
func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var doc := Sc2File.load_path(input_path(large_city_path(512)))
	if OS.get_cmdline_user_args().is_empty() and doc.is_valid():
		# The default stitched fixture has coarse maps. Convert only the in-memory copy.
		doc.enable_full_resolution_maps()
	if not (doc.is_valid() and doc.full_resolution_maps()):
		printerr("Benchmark check failed: doc.is_valid() and doc.full_resolution_maps()")
		quit(1)
		return
	var city := CityState.from_document(doc)
	if not (city.set_age_in_days((city.age_in_days() / 25) * 25 + 1)):
		printerr("Benchmark check failed: city.set_age_in_days((city.age_in_days() / 25) * 25 + 1)")
		quit(1)
		return
	var controller := GameSpeedController.new(SimulationEngine.new(city, 123, 456, 789))
	controller.set_speed(GameSpeedController.Speed.CHEETAH)
	controller.simulation_ready = true
	var runner := FrameSimulationRunner.new(controller)
	runner.budget_usec = FrameSimulationRunner.budget_for_frame(1.0 / 60.0)
	var frames := 0
	var max_call_usec := 0
	var started := Time.get_ticks_usec()
	var result := runner.advance_time(200, 200)
	max_call_usec = Time.get_ticks_usec() - started

	while runner.is_pending():
		await create_timer(1.0 / 60.0).timeout
		var frame_started := Time.get_ticks_usec()
		result = runner.advance_time(0, 200)
		max_call_usec = maxi(max_call_usec, Time.get_ticks_usec() - frame_started)
		frames += 1

	if not (result.ok and result.day_results.size() == 1):
		printerr("Benchmark check failed: result.ok and result.day_results.size() == 1")
		quit(1)
		return
	if not (int(result.day_results[0].day) % 25 == 2):
		printerr("Benchmark check failed: int(result.day_results[0].day) % 25 == 2")
		quit(1)
		return
	print(JSON.stringify({"edge": city.map_size, "frames_while_pending": frames,
		"elapsed_usec": Time.get_ticks_usec() - started, "max_main_call_usec": max_call_usec,
		"worker": runner.last_work_metrics, "day": result.day_results[0].timing,
		"job": result.job_timings}))
	runner.close()
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		input_path(large_city_path(512)),
	])
