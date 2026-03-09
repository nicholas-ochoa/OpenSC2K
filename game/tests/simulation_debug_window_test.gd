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
	assert(debug._steps.get_root().get_child_count() == 1)
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
	host.queue_free()
	await process_frame
	print("PASS: native debug window builds, displays timing rows and stays idle while hidden")
	quit()
