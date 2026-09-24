extends SceneTree
const TimingResults = preload("res://tests/support/timing_results.gd")

class MetricsHost extends Control:
	var debug: Control = self
	var timing_state := TimingState.new()
	var queries := 0
	var terrain_levels := 32
	var detailed_timing := false
	var date := "01/03/1900"


	func debug_set_visible_altitude_levels(value: int) -> void:
		terrain_levels = value


	func debug_set_detailed_timing(enabled: bool) -> ApplicationDebug.ActionResult:
		detailed_timing = enabled

		return ApplicationDebug.ActionResult.new(true, "Detailed timing is %s." % ("on" if enabled else "off"))


	func debug_metrics() -> Dictionary:
		queries += 1

		return {"city_name": "Timing test", "date": date, "speed": "Paused",
			"detailed_timing": detailed_timing}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := MetricsHost.new()
	root.add_child(host)
	var debug := preload("res://src/debug/debug_overlay.tscn").instantiate() as CityDebugOverlay
	debug.setup(host)
	host.add_child(debug)
	await process_frame
	assert(not debug.is_open and not debug._window.visible)
	debug.toggle()
	debug._process(0.1)
	debug._process(0.15)
	assert(host.queries == 2, "Metrics reuse the current snapshot between refreshes")
	debug.toggle()
	debug._process(0.25)
	assert(host.queries == 2, "Hidden debug UI does not collect metrics")
	var metrics_tree: Tree = debug._metrics_tree
	metrics_tree.refresh({"simulation_slices": {"snapshot_usec": 2500, "work": {"parked_usec": 12000}},
		"render_regions": {"cpu_image_bytes": 1048576}, "no_disasters": false})
	assert(metrics_tree.rows["simulation_slices/snapshot_usec"].get_text(1) == "2.500 ms")
	assert(metrics_tree.rows["render_regions/cpu_image_bytes"].get_text(1) == "1.00 MiB")
	assert(metrics_tree.rows["no_disasters"].get_text(1) == "No")
	var worker_row: TreeItem = metrics_tree.rows["simulation_slices"]
	worker_row.collapsed = true
	metrics_tree.refresh({"simulation_slices": {"snapshot_usec": 4000}, "new_counter": 7})
	assert(metrics_tree.rows["simulation_slices"] == worker_row and worker_row.collapsed)
	assert(metrics_tree.rows["simulation_slices/snapshot_usec"].get_text(1) == "4.000 ms")
	assert(metrics_tree.rows["simulation_slices/work/parked_usec"].get_text(1) == "—")
	assert(metrics_tree.rows["new_counter"].get_text(1) == "7")
	host.timing_state.simulation_timings.consume(TimingResults.tick_fixture({"day_results": [{"ok": true, "day": 2,
		"timing": {"work_usec": 2500, "steps": {"pollution": 2500}}}]}))
	debug.toggle()
	assert(debug.is_open and debug._days.get_root().get_child_count() == 25)
	assert(debug._date_fields.map(func(spin: SpinBox) -> int: return int(spin.value)) == [2, 3, 1900],
		"Run to date suggests one month after the current date")
	assert(debug._target_date.text == "No target date")
	var day_three := debug._days.get_root().get_child(2)
	assert(debug._current_day_row == day_three, "The row for the city date is marked")
	assert(day_three.get_custom_bg_color(0) != Color() and debug._days.get_root().get_child(1).get_custom_bg_color(0) == Color())
	assert(day_three.get_text(0) == "3" and day_three.get_text(2) == "2.500")
	host.date = "01/25/1900"
	debug._refresh_metrics()
	assert(debug._current_day_row == debug._days.get_root().get_child(24) and day_three.get_custom_bg_color(0) == Color(),
		"The mark follows the city date")
	host.date = "01/03/1900"
	debug._refresh_metrics()
	assert(day_three.get_text(5) == "1" and day_three.get_text(6) == "2.500")
	assert(day_three.collapsed and day_three.get_child_count() == 1)
	assert(day_three.get_child(0).get_text(1).strip_edges() == "pollution")
	assert(day_three.get_child(0).get_text(2) == "2.500")
	day_three.collapsed = false
	host.timing_state.simulation_timings.consume(TimingResults.tick_fixture({"day_results": [{"ok": true, "day": 3,
		"timing": {"work_usec": 900, "steps": {"pollution": 900}}}],
		"job_timings": {"worker elapsed": 6000}}))
	debug._refresh_metrics()
	assert(debug._days.get_root().get_child(2) == day_three and not day_three.collapsed)
	assert(day_three.get_child_count() == 1 and day_three.get_child(0).get_text(2) == "2.500")
	assert(debug._days.get_root().get_child(3).get_child(0).get_text(2) == "0.900")
	assert(debug._other_steps.collapsed and debug._other_steps.get_child(0).get_text(2) == "6.000")
	for pair in [[1, "power"], [3, "growth"], [19, "traffic"], [20, "water"]]:
		var phase := PhaseResult.new()
		phase.timing = SimulationTiming.new(-1, {"measured detail": 6000})
		host.timing_state.simulation_timings.consume(TimingResults.tick_fixture({"day_results": [{"ok": true, "day": pair[0],
			"timing": {"work_usec": 7000, "steps": {pair[1]: 7000}},
			"phase_results": {pair[1]:
				phase}}]}))

	debug._refresh_metrics()

	for pair in [[1, "power"], [3, "growth"], [19, "traffic"], [20, "water"]]:
		var label := "Day %02d / %s / measured detail" % [pair[0] + 1, pair[1]]
		var detail: TreeItem = debug._step_rows[label]
		assert(detail.get_parent() == debug._step_rows[label.get_slice(" / ", 0) + " / " + pair[1]])
		assert(detail.get_text(2) == "6.000" and detail.get_text(5) == "1")

	var power: TreeItem = debug._step_rows["Day 02 / power"]
	power.collapsed = true
	host.timing_state.simulation_timings.record_step("Day 02 / power / network / scan", 2000)
	host.timing_state.simulation_timings.record_step("worker / publication / copy", 1000)
	debug._refresh_metrics()
	var network: TreeItem = debug._step_rows["Day 02 / power / network"]
	assert(network.get_parent() == power and power.collapsed)
	assert(network.get_text(2) == "—", "Expected no total for an unmeasured group")
	assert(debug._step_rows["Day 02 / power / network / scan"].get_parent() == network)
	assert(debug._step_rows["worker / publication / copy"].get_parent() == debug._step_rows["worker / publication"])
	host.timing_state.simulation_timings.steps.erase("Day 02 / power / network / scan")
	debug._refresh_metrics()
	assert(not debug._step_rows.has("Day 02 / power / network"))
	assert(debug._step_rows["Day 02 / power"] == power and power.collapsed)

	var paced := SimulationTickResult.new()
	paced.pacing_delays[2] = 7500
	host.timing_state.simulation_timings.consume(paced)
	debug._refresh_metrics()
	assert(day_three.get_text(3) == "2.500" and day_three.get_text(6) == "10.000", "Last w/ Delay adds the pacing delay")
	assert(debug._days.get_root().get_child(0).get_text(6) == "—")

	assert(not debug._detailed_timing_check.button_pressed, "Per-tile timing detail stays off by default")
	debug._detailed_timing_check.button_pressed = true
	assert(host.detailed_timing, "The debug window forwards the detailed-timing request")
	assert(debug._action_label.text == "Detailed timing is on.")
	host.detailed_timing = false
	debug._refresh_metrics()
	assert(not debug._detailed_timing_check.button_pressed, "The checkbox follows the reported state")

	assert(debug._terrain_slider.min_value == 1 and debug._terrain_slider.max_value == 32)
	debug._terrain_slider.value = 12
	assert(host.terrain_levels == 12 and debug._terrain_value.text == "12")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	debug._input(escape)
	assert(not debug.is_open)
	debug._input(escape)
	assert(not debug.is_open, "Escape cannot open a hidden debug window")
	var queries := host.queries
	debug._process(1.0)
	assert(not debug.is_open and not debug._window.visible and host.queries == queries)
	debug._reset_averages()
	assert(host.timing_state.simulation_timings.days.is_empty())
	assert(day_three.get_child_count() == 0 and day_three.get_text(2) == "—")
	assert(not day_three.collapsed and debug._other_steps == null)
	host.queue_free()
	await process_frame
	print("PASS: native debug window builds, displays timing rows and stays idle while hidden")
	quit()
