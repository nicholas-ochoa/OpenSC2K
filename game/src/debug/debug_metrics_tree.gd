extends Tree

const GROUPS := {
	"City and view": ["population", "funds", "tool", "view", "zoom", "center_tile", "visible_altitude_levels", "active_disaster", "no_disasters"],
	"Simulation worker": ["simulation_slices", "speed_accumulator_msec"],
	"Rendering and memory": ["render_regions", "static_render", "render_pending", "static_cache", "dynamic_cache", "foreground_cache"],
	"Map activity": ["panning", "selection_drag", "sign_entries", "sign_scans", "dynamic_visuals", "dynamic_revisions", "transient_effects"],
	"Audio": ["wave_sound_id", "wave_sound_ticks", "wave_sound_accepted", "wave_sound_suppressed", "wave_stream_cache"],
	"Internal identifiers": ["speed_id", "active_disaster_id"],
}
const LABELS := {
	"simulation_slices": "Tick processing", "render_regions": "Map regions",
	"work": "Worker scheduling", "pending_msec": "Pending simulation time",
	"snapshot_usec": "Snapshot copy", "publish_usec": "Publish result", "day_period_usec": "Day pacing period",
	"max_slice_usec": "Longest work slice", "elapsed_usec": "Worker elapsed time",
	"parked_usec": "Frame-budget waits", "speed_accumulator_msec": "Game timer accumulator",
	"max_region_usec": "Slowest region build", "atlas_bytes": "GPU atlas memory",
	"cpu_image_bytes": "CPU image memory", "texture_bytes_estimate": "Texture memory estimate",
	"gpu": "GPU rendering", "resident": "Cached regions", "visible": "Visible regions",
	"offscreen_limit": "Off-screen cache limit", "covered": "Visible area covered",
	"static_render": "Static render worker", "render_pending": "Static redraw queued",
	"static_cache": "Static view cache entries", "dynamic_cache": "Dynamic cache entries",
	"foreground_cache": "Foreground cache entries", "no_disasters": "Random disasters disabled",
	"wave_sound_id": "Current sound ID", "wave_sound_ticks": "Sound gate ticks remaining",
	"wave_sound_accepted": "Accepted sound requests", "wave_sound_suppressed": "Suppressed sound requests",
	"wave_stream_cache": "Cached sound streams", "selection_drag": "Selection drag active",
	"sign_scans": "Sign cache rebuilds", "dynamic_revisions": "Dynamic visual revisions",
}
const NOTES := {
	"snapshot_usec": "Time to copy the city data for the simulation worker.",
	"publish_usec": "Time to apply the worker result to the city on the main thread.",
	"day_period_usec": "Typical work time for one day. A faster day waits until this time is complete. At 0, days do not wait.",
	"pending_msec": "Game time that the simulation must still run. This value increases when the simulation is late.",
	"elapsed_usec": "Total time of the worker tick. This time includes the frame waits.",
	"parked_usec": "Time that the worker waits for the next frame.",
	"max_slice_usec": "Longest work period without a stop.",
	"texture_bytes_estimate": "Estimate from the sizes of the cached images. This value is not the total GPU memory.",
	"max_region_usec": "Longest time to build one region.",
	"wave_sound_suppressed": "Number of sound requests that the replay limits stopped.",
	"population": "City population.",
	"funds": "Money in the city treasury.",
	"tool": "The tool that the player selected.",
	"view": "The map view mode.",
	"zoom": "The map zoom level.",
	"center_tile": "The map tile at the center of the view.",
	"visible_altitude_levels": "Number of terrain levels that show. At 32, all levels show.",
	"active_disaster": "The disaster that is active now.",
	"no_disasters": "The Disasters > No Disasters menu item sets this value. The city file keeps this value.",
	"simulation_slices": "Data about the simulation worker thread.",
	"simulation_slices/pending": "Yes when a worker tick runs now.",
	"completed_ticks": "Number of worker ticks that the game applied to the city.",
	"cancelled_ticks": "Number of worker ticks that the game discarded. An edit, a pause, or a dialog box stops a tick.",
	"work": "Schedule data for the current or last tick.",
	"slices": "Number of work periods in the tick. Between the periods, the worker waits for a frame.",
	"waiting": "Yes when the worker waits for the next frame.",
	"simulation_slices/work/cancelled": "Yes when the game discarded the tick.",
	"speed_accumulator_msec": "Game time that is less than one 200 ms base tick. The next tick uses this time.",
	"render_regions": "Map image regions that the game builds in the background.",
	"gpu": "Yes when the GPU builds the regions.",
	"atlas_bytes": "GPU memory for the region image atlas.",
	"resident": "Number of regions in the cache.",
	"visible": "Number of regions in the view.",
	"offscreen_limit": "Maximum number of cached regions outside the view.",
	"cpu_image_bytes": "Memory for the cached region images.",
	"render_regions/completed": "Number of region builds that are complete.",
	"discarded": "Number of region builds that the game discarded because they were old.",
	"render_regions/ready": "Yes when all visible regions show the current map.",
	"covered": "Yes when all visible regions have an image. An image can be old.",
	"render_regions/pending": "Yes when a region build runs now.",
	"static_render": "The state of the static map render worker.",
	"render_pending": "Yes when a static redraw waits to start.",
	"static_cache": "Number of cached static map images.",
	"dynamic_cache": "Number of cached dynamic sprite images.",
	"foreground_cache": "Number of cached foreground sprite images.",
	"panning": "Yes when the player moves the map view.",
	"selection_drag": "Yes when the player drags a tool across the map.",
	"sign_entries": "Number of map signs in the sign cache.",
	"sign_scans": "Number of times the game collected the map signs again.",
	"dynamic_visuals": "Number of moving things and animations that show now.",
	"dynamic_revisions": "Number of times the dynamic sprite list changed.",
	"transient_effects": "Number of short map effects that show now.",
	"wave_sound_id": "The sound effect that plays now.",
	"wave_sound_ticks": "Number of ticks until the sound gate accepts a new sound.",
	"wave_sound_accepted": "Number of sound requests that played.",
	"wave_stream_cache": "Number of sound effect files in memory.",
	"speed_id": "The game speed number. 1 is Paused. 5 is African Swallow.",
	"active_disaster_id": "The disaster type number. 0 is no disaster.",
	"detailed_timing": "Yes when the growth scan records the time of each step.",
	"pause_at_date": "The date when Run to date stops the simulation.",
}
var rows: Dictionary = {}
var _sections: Dictionary = {}


func _ready() -> void:
	set_column_title(0, "Metric")
	set_column_title(1, "Current value")
	set_column_title(2, "Meaning")
	set_column_expand(0, true)
	set_column_expand(1, false)
	set_column_custom_minimum_width(0, 200)
	set_column_custom_minimum_width(1, 150)
	set_column_custom_minimum_width(2, 180)
	var base := create_item()

	for caption in GROUPS:
		var section := create_item(base)
		section.set_text(0, caption)
		section.set_custom_color(0, Color("9cc8ef"))
		_sections[caption] = section


func refresh(metrics: Dictionary) -> void:
	# keep absent values explicit when loading or closing a city
	for row: TreeItem in rows.values():
		row.set_text(1, "—")

	var assigned := {"city_name": true, "date": true, "speed": true}

	for caption in GROUPS:
		for key: String in GROUPS[caption]:
			assigned[key] = true
			_update_row(_sections[caption], key, key, metrics.get(key))

	for key: String in metrics:
		if not assigned.has(key):
			if not _sections.has("Other diagnostics"):
				var section := create_item(get_root())
				section.set_text(0, "Other diagnostics")
				_sections["Other diagnostics"] = section

			_update_row(_sections["Other diagnostics"], key, key, metrics[key])


func _update_row(parent: TreeItem, path: String, key: String, value: Variant) -> void:
	var row: TreeItem = rows.get(path)

	if row == null:
		row = create_item(parent)
		row.set_text(0, LABELS.get(key, key.trim_suffix("_usec").trim_suffix("_msec").capitalize()))
		# a path note is for a key name that has different meanings in different groups
		row.set_text(2, NOTES.get(path, NOTES.get(key, "")))
		row.set_tooltip_text(2, row.get_text(2))
		row.set_tooltip_text(0, path)
		rows[path] = row

	if value is Dictionary:
		row.set_text(1, "—" if value.is_empty() else "")

		for child_key: String in value:
			_update_row(row, path + "/" + child_key, child_key, value[child_key])
	else:
		row.set_text(1, format_value(key, value))
		row.set_tooltip_text(1, str(value) if value != null else "No sample available")


static func format_value(key: String, value: Variant) -> String:
	if value == null:
		return "—"

	if value is bool:
		return "Yes" if value else "No"

	if value is int or value is float:
		if key.ends_with("_usec"):
			return "%.3f ms" % (float(value) / 1000.0)
		if key.ends_with("_msec"):
			return "%.3f ms" % float(value)
		if "bytes" in key:
			return "%.2f MiB" % (float(value) / 1048576.0)

	return str(value)
