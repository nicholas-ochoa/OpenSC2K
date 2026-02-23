extends SceneTree
const TimingResults = preload("res://tests/support/timing_results.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	check_field_coverage()

	for edge in [128, 256, 384, 512]:
		await check_parity(edge)

	await check_special_ticks()
	await check_cancellation()
	print("Frame simulation checks: %d failures" % failures)
	quit(1 if failures else 0)


func make_controller(edge: int) -> GameSpeedController:
	var path := "res://../references/SIMCITY2000/CITIES/SYDNEY.SC2" if edge == 128 else "res://../local/large-cities/stitched-%d.sc2x" % edge
	var city := CityState.from_document(Sc2File.load_path(path))
	check(city.is_valid(), "fixture loads")
	var controller := GameSpeedController.new(SimulationEngine.new(city, 123, 456, 789))
	controller.set_speed(GameSpeedController.Speed.CHEETAH)

	return controller


func check_parity(edge: int) -> void:
	var sync := make_controller(edge)
	var sliced := make_controller(edge)
	var runner := FrameSimulationRunner.new(sliced)
	runner.budget_usec = 4000
	var random_id := sliced.engine.random.get_instance_id()
	var city_id := sliced.engine.city.get_instance_id()
	var document_id := sliced.engine.city.document.get_instance_id()
	var slices := 0

	for day in 25:
		var expected := sync.advance_time(200, day * 200)
		check(expected.ok, "reference tick")
		var before := SimulationSnapshot.stamp(sliced)
		var actual := runner.advance_time(200, day * 200)
		var deadline := Time.get_ticks_msec() + 15000

		while runner.is_pending() and Time.get_ticks_msec() < deadline:
			check(SimulationSnapshot.stamp(sliced) == before, "pending work remains private")
			await process_frame
			actual = runner.advance_time(0, day * 200)

		check(not runner.is_pending(), "tick completes without blocking frames")
		check(int(runner.last_work_metrics.elapsed_usec) >= int(runner.last_work_metrics.parked_usec), "elapsed job time includes frame waits")
		check(actual.job_timings.has("Worker / frame waits"), "accepted jobs publish wait timings")
		check(TimingResults.without_timings(actual) == TimingResults.without_timings(expected), "identical tick events and results at %d day %d" % [edge, day])
		check(sliced.engine.city.document.serialize().data == sync.engine.city.document.serialize().data, "identical saved bytes at %d day %d" % [edge, day])
		check(sliced.engine.random.state == sync.engine.random.state and sliced.engine.lfsr_random.state == sync.engine.lfsr_random.state and sliced.engine.game_random.state == sync.engine.game_random.state, "identical random states")
		slices += int(runner.last_work_metrics.get("slices", 0))

	check(slices > 25, "work spans multiple frame grants")
	check(sliced.engine.random.get_instance_id() == random_id and sliced.engine.city.get_instance_id() == city_id and sliced.engine.city.document.get_instance_id() == document_id, "publication preserves public identities")
	runner.close()
	print("PASS: %d synchronous/sliced day, event, byte and RNG comparisons; %d grants" % [edge, slices])


func check_cancellation() -> void:
	var sliced := make_controller(256)
	var sync := make_controller(256)
	var runner := FrameSimulationRunner.new(sliced)
	runner.advance_time(200, 200)
	sliced.engine.city.set_funds(123456)
	sync.engine.city.set_funds(123456)
	var expected := sync.advance_time(200, 200)
	var result := runner.advance_time(0, 200)
	var deadline := Time.get_ticks_msec() + 15000

	while runner.completed_ticks == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
		result = runner.advance_time(0, 200)

	check(runner.cancelled_ticks == 1 and runner.completed_ticks == 1, "stale work discarded and retried")
	check(TimingResults.without_timings(result) == TimingResults.without_timings(expected) and sliced.engine.city.document.serialize().data == sync.engine.city.document.serialize().data, "edit survives pending work")
	runner.advance_time(200, 400)
	sliced.set_speed(GameSpeedController.Speed.PAUSED)
	var age := sliced.engine.city.age_in_days()

	while runner.is_pending() and Time.get_ticks_msec() < deadline:
		await process_frame
		runner.advance_time(0, 400, true)

	check(sliced.engine.city.age_in_days() == age, "pause discards incomplete work")
	runner.close()
	print("PASS: edits and pause cancel private work without lost changes")


func check_special_ticks() -> void:
	var sync := make_controller(512)
	var sliced := make_controller(512)
	var runner := FrameSimulationRunner.new(sliced)

	for controller in [sync, sliced]:
		controller.engine.city.set_age_in_days(299)
		controller.engine.clock.city_days = 299
		BudgetPhase.set_funding(controller.engine.city, BudgetPhase.funding_values(controller.engine.city), true)

	await compare_tick(sync, sliced, runner, 200, "annual update")
	check(sliced.engine.city.age_in_days() == 300, "annual update completed")
	var expected := sync.engine.start_disaster(DisasterStartPhase.DISASTER_FIRE, Vector2i(64, 64))
	var actual := sliced.engine.start_disaster(DisasterStartPhase.DISASTER_FIRE, Vector2i(64, 64))
	check(TimingResults.without_timings(actual) == TimingResults.without_timings(expected) and actual.ok, "identical fire start")

	for tick in 10:
		await compare_tick(sync, sliced, runner, 400 + tick * 200, "fire tick")

	var before: PackedByteArray = sliced.engine.city.document.serialize().data
	runner.advance_time(200, 3000)
	runner.close()
	check(not runner.is_pending() and sliced.engine.city.document.serialize().data == before, "closing pending work cannot publish")
	var private := SimulationSnapshot.capture(sliced, null)
	private.engine.city.buildings[0] = (private.engine.city.buildings[0] + 1) & 255
	check(private.engine.city.buildings[0] != sliced.engine.city.buildings[0], "snapshot arrays are independent")
	print("PASS: 512 annual update, fire ticks, shutdown and private arrays")


func compare_tick(sync: GameSpeedController, sliced: GameSpeedController, runner: FrameSimulationRunner, now: int, context: String) -> void:
	var expected := sync.advance_time(200, now)
	var actual := runner.advance_time(200, now)
	var deadline := Time.get_ticks_msec() + 30000

	while runner.is_pending() and Time.get_ticks_msec() < deadline:
		await process_frame
		actual = runner.advance_time(0, now)

	check(not runner.is_pending() and expected.ok and TimingResults.without_timings(actual) == TimingResults.without_timings(expected), context + " results")
	check(sync.engine.city.document.serialize().data == sliced.engine.city.document.serialize().data, context + " bytes")
	check(SimulationSnapshot.stamp(sync).slice(-SimulationSnapshot.ENGINE_FIELDS.size() - SimulationSnapshot.CONTROLLER_FIELDS.size()) == SimulationSnapshot.stamp(sliced).slice(-SimulationSnapshot.ENGINE_FIELDS.size() - SimulationSnapshot.CONTROLLER_FIELDS.size()), context + " runtime fields")
	check(sync.engine.random.state == sliced.engine.random.state and sync.engine.lfsr_random.state == sliced.engine.lfsr_random.state and sync.engine.game_random.state == sliced.engine.game_random.state, context + " random states")


func check_field_coverage() -> void:
	var engine := SimulationEngine.new(null)

	for property in engine.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			check(property.name in SimulationSnapshot.ENGINE_FIELDS + ["city", "clock", "random", "lfsr_random", "game_random", "scenario"], "snapshot covers engine field " + property.name)

	var controller := GameSpeedController.new(engine)

	for property in controller.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			check(property.name in SimulationSnapshot.CONTROLLER_FIELDS + ["engine"], "snapshot covers controller field " + property.name)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
