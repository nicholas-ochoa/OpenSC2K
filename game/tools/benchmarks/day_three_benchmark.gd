extends "res://tools/benchmarks/fixture_paths.gd"

## Repeat one fixed-seed data-map day. Pass a city path after --.
## Headless timings exclude rendering. Work time includes OS preemption.
@warning_ignore_start("integer_division")

const TimingResults = preload("res://tests/support/timing_results.gd")
const PHASE := "pollution_terrain_land_value"


func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var samples := int(OS.get_environment("CITY_BENCH_SAMPLES")) if OS.has_environment("CITY_BENCH_SAMPLES") else 5
	var warmup := int(OS.get_environment("CITY_BENCH_WARMUP")) if OS.has_environment("CITY_BENCH_WARMUP") else 1
	var sliced := OS.get_environment("CITY_BENCH_SYNC") != "1"
	var map_mode := OS.get_environment("CITY_BENCH_MAP_MODE")
	if map_mode.is_empty():
		map_mode = "full"
	if samples < 1 or warmup < 0 or map_mode not in ["full", "coarse"]:
		printerr("Invalid sample count, warmup count, or map mode")
		quit(1)
		return

	var source := Sc2File.load_path(input_path(large_city_path(512)))
	if not source.is_valid() or (map_mode == "full" and not source.enable_full_resolution_maps()):
		printerr("Cannot prepare the data-map fixture")
		quit(1)
		return
	if source.full_resolution_maps() != (map_mode == "full"):
		printerr("The fixture does not use the requested map mode")
		quit(1)
		return

	report_metadata({"map_size": source.map_size, "map_mode": map_mode, "sliced": sliced,
		"samples": samples, "warmup": warmup, "seeds": [123, 456, 789], "frame_grant_seconds": 1.0 / 60.0})
	var expected: Dictionary = {}
	for index in warmup + samples:
		var measured := await _run_sample(source, sliced)
		if measured.is_empty():
			quit(1)
			return
		if expected.is_empty():
			expected = measured.proof
		elif measured.proof != expected:
			printerr("Repeated data-map days changed saved bytes, results, or RNG state")
			quit(1)
			return
		if index >= warmup:
			measured.sample = index - warmup
			print(JSON.stringify(measured))

	quit()


func _run_sample(source: Sc2File, sliced: bool) -> Dictionary:
	var city := CityState.from_document(source.duplicate_document(true))
	if not city.is_valid() or not city.set_age_in_days((city.age_in_days() / 25) * 25 + 1):
		printerr("Cannot prepare the data-map day")
		return {}

	var controller := GameSpeedController.new(SimulationEngine.new(city, 123, 456, 789))
	controller.set_speed(GameSpeedController.Speed.CHEETAH)
	controller.simulation_ready = true
	var runner := FrameSimulationRunner.new(controller)
	runner.budget_usec = FrameSimulationRunner.budget_for_frame(1.0 / 60.0)
	var frames := 0
	var started := Time.get_ticks_usec()
	var result := runner.advance_time(200, 200) if sliced else controller.advance_time(200, 200)
	var max_call_usec := Time.get_ticks_usec() - started
	var deadline := Time.get_ticks_msec() + 60000

	while runner.is_pending() and Time.get_ticks_msec() < deadline:
		await create_timer(1.0 / 60.0).timeout
		var frame_started := Time.get_ticks_usec()
		result = runner.advance_time(0, 200)
		max_call_usec = maxi(max_call_usec, Time.get_ticks_usec() - frame_started)
		frames += 1

	var elapsed := Time.get_ticks_usec() - started
	var finished := not runner.is_pending()
	runner.close()
	if not finished or not result.ok or result.day_results.size() != 1:
		printerr("Data-map day failed or timed out: %s" % result.error)
		return {}
	var day := result.day_results[0]
	if day.day % 25 != 2 or not day.phase_results.has(PHASE):
		printerr("The expected data-map phase did not run")
		return {}
	var saved := city.document.serialize(true)
	if not saved.ok:
		printerr("Cannot serialize the data-map result: %s" % saved.error)
		return {}
	var proof := {"save_sha256": bytes_sha256(saved.data),
		"results_sha256": bytes_sha256(JSON.stringify(TimingResults.without_timings(result)).to_utf8_buffer()),
		"random": controller.engine.random.state, "lfsr": controller.engine.lfsr_random.state,
		"game_random": controller.engine.game_random.state}

	return {"edge": city.map_size, "frames_while_pending": frames, "elapsed_usec": elapsed,
		"max_main_call_usec": max_call_usec, "proof": proof,
		"worker": runner.last_work_metrics.debug_fields() if runner.last_work_metrics != null else {},
		"day": {"work_usec": day.timing.work_usec, "steps": day.timing.steps},
		"phase": {"work_usec": day.phase_results[PHASE].timing.work_usec, "steps": day.phase_results[PHASE].timing.steps},
		"job": result.job_timings}


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([input_path(large_city_path(512))])
