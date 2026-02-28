extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(FrameSimulationRunner.budget_for_frame(1.0 / 60.0) > 16667)
	assert(FrameSimulationRunner.budget_for_frame(1.0 / 120.0) > 8333)
	assert(FrameSimulationRunner.budget_for_frame(0.040) == 4000)
	var budget := SimulationSliceBudget.new()
	var entered := Semaphore.new()
	var proceed := Semaphore.new()
	var thread := Thread.new()
	budget.grant(20000)
	assert(thread.start(func() -> void:
		budget.checkpoint()
		entered.post()
		proceed.wait()
		budget.checkpoint()
		entered.post()
		proceed.wait()
		budget.checkpoint()
		budget.finish()) == OK)

	# One frame grant is enough to start the worker.
	await _wait_signal(entered)
	OS.delay_msec(25)
	budget.grant(20000)
	proceed.post()
	await _wait_signal(entered)
	assert(not budget.metrics().waiting, "A fresh running grant survives the old lease")
	OS.delay_msec(25)
	proceed.post()
	var deadline := Time.get_ticks_msec() + 2000

	while not budget.metrics().waiting and Time.get_ticks_msec() < deadline:
		await process_frame

	assert(budget.metrics().waiting, "Expired grants cannot accumulate unlimited work")
	budget.cancel()
	thread.wait_to_finish()
	assert(budget.metrics().cancelled and budget.metrics().elapsed_usec > 0)
	print("PASS: initial admission, running renewal, expired lease, slow-frame backoff and parked cancellation")
	quit()


func _wait_signal(signal_ready: Semaphore) -> void:
	var deadline := Time.get_ticks_msec() + 2000

	while Time.get_ticks_msec() < deadline:
		if signal_ready.try_wait():
			return

		await process_frame

	assert(false, "Worker stalled after its first grant")
