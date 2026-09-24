class_name FrameSimulationRunner
extends RefCounted
# one isolated tick at a time. the main thread publishes only complete ticks
const DEFAULT_BUDGET_USEC := 8000
var controller: GameSpeedController
var budget_usec := DEFAULT_BUDGET_USEC
var pending_msec := 0.0
var completed_ticks := 0
var cancelled_ticks := 0
var snapshot_usec := 0
var publish_usec := 0
var last_work_metrics: SimulationSliceBudget.Metrics
# a tick that runs a day starts at least this long after the previous day tick
# started. fast days then take about as long as a typical day. 0 turns this off
var day_period_usec := 0
var _thread: Thread
var _budget: SimulationSliceBudget
var _working: GameSpeedController
var _stamp: Array = []
var _submitted_msec := 0.0
var _discard := false
var _tick_started_usec := 0
var _hold_until_usec := 0
var _held_since_usec := -1
var _paced_label := ""
# measured pacing waits for the next accepted result
var _pacing_timings: Dictionary[String, int] = {}


func _init(source: GameSpeedController) -> void:
	controller = source


func advance_time(delta_msec: float, now_msec: int, suspended := false) -> SimulationTickResult:
	var empty := controller._empty_result()
	empty.ok = true

	if delta_msec < 0:
		empty.ok = false
		empty.error = "elapsed time cannot be negative"

		return empty

	pending_msec += delta_msec

	if _thread != null:
		if not _discard and (suspended or SimulationSnapshot.stamp(controller) != _stamp):
			_discard = true
			cancelled_ticks += 1
			_budget.cancel()

		if not _thread.is_alive():
			var result: SimulationTickResult = _thread.wait_to_finish()
			last_work_metrics = _budget.metrics()
			_thread = null

			if not _discard:
				pending_msec = maxf(0.0, pending_msec - _submitted_msec)

				if result.ok:
					var started := Time.get_ticks_usec()
					SimulationSnapshot.publish(_working, controller)
					publish_usec = Time.get_ticks_usec() - started
					result.job_timings = {"Main thread / snapshot": snapshot_usec, "Main thread / publish": publish_usec,
						"Worker / elapsed": last_work_metrics.elapsed_usec, "Worker / frame waits": last_work_metrics.parked_usec}
					result.job_timings.merge(_pacing_timings)
					_pacing_timings.clear()
					completed_ticks += 1

					if not result.day_results.is_empty():
						_hold_until_usec = _tick_started_usec + day_period_usec
						_paced_label = "Day %02d / pacing delay" % (posmod(result.day_results[-1].day, 25) + 1)

				_working = null
				_budget = null

				return result

			_working = null
			_budget = null
		else:
			_budget.grant(budget_usec)

			if suspended or controller.speed == GameSpeedController.Speed.PAUSED:
				var paused := controller.advance_time(pending_msec, now_msec, true)
				pending_msec = 0.0

				return paused

			return empty

	if (suspended or controller.speed == GameSpeedController.Speed.PAUSED or controller.interaction_blocked or controller.terminal_blocked
			or (controller.accumulator_msec + pending_msec < GameSpeedController.BASE_TICK_MSEC and not controller.simulation_ready)):
		var immediate := controller.advance_time(pending_msec, now_msec, suspended)
		pending_msec = 0.0
		# a pause or a prompt ends the wait without a measurement
		_held_since_usec = -1

		return immediate

	var submitted := minf(GameSpeedController.BASE_TICK_MSEC, pending_msec)
	var started := Time.get_ticks_usec()

	if started < _hold_until_usec and controller.tick_runs_day(submitted):
		if _held_since_usec < 0:
			_held_since_usec = started

		return empty

	if _held_since_usec >= 0:
		_pacing_timings[_paced_label] = int(_pacing_timings.get(_paced_label, 0)) + started - _held_since_usec
		_held_since_usec = -1

	_hold_until_usec = 0
	_tick_started_usec = started
	_submitted_msec = submitted
	var submitted_time := now_msec - int(pending_msec - _submitted_msec)
	_budget = SimulationSliceBudget.new()
	_stamp = SimulationSnapshot.stamp(controller)
	_working = SimulationSnapshot.capture(controller, _budget)
	snapshot_usec = Time.get_ticks_usec() - started
	_discard = false
	_thread = Thread.new()
	_budget.grant(budget_usec)
	var error := _thread.start(_run.bind(_working, _budget, _submitted_msec, submitted_time), Thread.PRIORITY_LOW)

	if error != OK:
		_thread = null
		_working = null
		_budget = null
		empty.ok = false
		empty.error = "cannot start the simulation worker: %s" % error_string(error)

	return empty


static func budget_for_frame(delta_seconds: float) -> int:
	# healthy frames permit overlap with the next frame. a slow frame reduces
	# the next lease so rendering has room to recover. this is worker time only
	if delta_seconds > 0.020:
		return 4000

	return clampi(roundi(delta_seconds * 1250000.0), 4000, 20000)


func is_pending() -> bool:
	return _thread != null


# Values shown in the debug tree.
func metrics() -> Dictionary:
	var work := _budget.metrics() if _budget != null else last_work_metrics
	return {"pending": is_pending(), "pending_msec": pending_msec, "completed_ticks": completed_ticks, "cancelled_ticks": cancelled_ticks,
			"snapshot_usec": snapshot_usec, "publish_usec": publish_usec, "day_period_usec": day_period_usec,
			"work": work.debug_fields() if work != null else {}}


func close() -> void:
	if _thread != null:
		_budget.cancel()
		_thread.wait_to_finish()

	_thread = null
	_working = null
	_budget = null


static func _run(working: GameSpeedController, budget: SimulationSliceBudget, delta_msec: float, now_msec: int) -> SimulationTickResult:
	budget.checkpoint()
	var result := working.advance_time(delta_msec, now_msec)
	budget.finish()

	return result
