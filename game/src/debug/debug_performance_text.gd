class_name DebugPerformanceText
extends RefCounted
## The text of the performance HUD: engine frame and render counters, the
## simulation day cost and the region cache state.

const MEBIBYTE := 1048576.0


static func text(app: CityApplication) -> String:
	var lines := PackedStringArray()
	var hud := app.map_view.debug_view.hud
	var frames := hud.frame_summary()
	lines.append("FPS %d   frame %.1f ms avg, %.1f ms max" % [Engine.get_frames_per_second(), frames.y, frames.x])
	lines.append("process %.2f ms   draw calls %d   objects %d" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	lines.append("primitives %d   video %.0f MiB   static %.0f MiB" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MEBIBYTE,
		Performance.get_monitor(Performance.MEMORY_STATIC) / MEBIBYTE])
	var timings := app.timing_state.simulation_timings

	if timings != null:
		lines.append("simulation day %.1f ms typical" % (timings.typical_day_usec / 1000.0))

	var cache := app.render_caches.region_cache

	if cache != null:
		var metrics := cache.metrics()
		lines.append("regions %d visible, %d resident, %s" % [
			int(metrics.visible), int(metrics.resident), "pending" if metrics.pending else "ready"])

	return "\n".join(lines)


# engine counters for the Metrics tab of the Debug window
static func monitors() -> Dictionary:
	return {
		"fps": Engine.get_frames_per_second(),
		"process_msec": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
