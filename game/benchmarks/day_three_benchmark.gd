extends SceneTree
## Read-only SC2X day-3 worker profile. Pass a city path after --.
## Headless frame admission costs exclude rendering and GPU work.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1, "Pass a full-resolution SC2X city path")
	var doc := Sc2File.load_path(args[0])
	assert(doc.is_valid() and doc.full_resolution_maps())
	var city := CityState.from_document(doc)
	assert(city.set_age_in_days(city.age_in_days() / 25 * 25 + 1))
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
	assert(result.ok and result.day_results.size() == 1)
	assert(int(result.day_results[0].day) % 25 == 2)
	print(JSON.stringify({"edge": city.map_size, "frames_while_pending": frames,
		"elapsed_usec": Time.get_ticks_usec() - started, "max_main_call_usec": max_call_usec,
		"worker": runner.last_work_metrics, "day": result.day_results[0].timing,
		"job": result.job_timings}))
	runner.close()
	quit()
