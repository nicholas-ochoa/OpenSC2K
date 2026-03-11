extends SceneTree

class MetricsHost extends Control:
	var simulation_timings := SimulationTimingHistory.new()
	var queries := 0
	var terrain_levels := 32


	func _debug_set_visible_altitude_levels(value: int) -> void:
		terrain_levels = value


	func _debug_metrics() -> Dictionary:
		queries += 1

		return {"city_name": "Timing test", "date": "01/03/1900", "speed": "Paused"}


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
	assert(debug._window.title == "Debug")
	assert(debug._window.owner == debug)
	assert(debug._days.get_column_title(1) == "What happens")
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
	assert(not debug.has_node("DebugWindow/Panel/Margin/Content/Header/Status"))
	assert(not debug.has_node("DebugWindow/Panel/Margin/Content/Note"))
	var theme := debug._window.theme
	assert(theme.get_color("font_color", "Label").get_luminance() > 0.8)
	assert((theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color.get_luminance() < 0.2)
	assert(theme.get_color("font_color", "Tree").get_luminance() > 0.8)
	assert((theme.get_stylebox("panel", "Tree") as StyleBoxFlat).bg_color.get_luminance() < 0.2)
	assert(theme.get_color("font_selected_color", "Tree") == Color.WHITE)
	assert((theme.get_stylebox("selected", "Tree") as StyleBoxFlat).bg_color.get_luminance() < 0.4)
	host.simulation_timings.consume({"day_results": [{"ok": true, "day": 2,
		"timing": {"work_usec": 2500, "steps": {"pollution": 2500}}}]})
	debug.toggle()
	assert(debug.is_open and debug._days.get_root().get_child_count() == 25)
	var day_three := debug._days.get_root().get_child(2)
	assert(day_three.get_text(0) == "3" and day_three.get_text(2) == "2.500")
	assert(day_three.get_text(5) == "1")
	assert(day_three.collapsed and day_three.get_child_count() == 1)
	assert(day_three.get_child(0).get_text(1) == "      pollution")
	assert(day_three.get_child(0).get_text(2) == "2.500")
	day_three.collapsed = false
	host.simulation_timings.consume({"day_results": [{"ok": true, "day": 3,
		"timing": {"work_usec": 900, "steps": {"pollution": 900}}}],
		"job_timings": {"worker elapsed": 6000}})
	debug._refresh_metrics()
	assert(debug._days.get_root().get_child(2) == day_three and not day_three.collapsed)
	assert(day_three.get_child_count() == 1 and day_three.get_child(0).get_text(2) == "2.500")
	assert(debug._days.get_root().get_child(3).get_child(0).get_text(2) == "0.900")
	assert(debug._other_steps.collapsed and debug._other_steps.get_child(0).get_text(2) == "6.000")
	assert(not debug.has_node("DebugWindow/Panel/Margin/Content/Tabs/Steps"))
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
	assert(host.simulation_timings.days.is_empty())
	assert(day_three.get_child_count() == 0 and day_three.get_text(2) == "—")
	assert(not day_three.collapsed and debug._other_steps == null)
	host.queue_free()
	await process_frame
	print("PASS: native debug window builds, displays timing rows and stays idle while hidden")
	quit()
