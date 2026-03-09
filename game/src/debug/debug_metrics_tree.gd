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
	"snapshot_usec": "Snapshot copy", "publish_usec": "Publish result",
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
	"snapshot_usec": "Copy city state for the simulation worker.",
	"publish_usec": "Apply the completed worker result on the main thread.",
	"pending_msec": "Simulation time submitted to the pending tick.",
	"elapsed_usec": "Worker wall time; includes frame-budget waits.",
	"parked_usec": "Time waiting for another frame's work allowance.",
	"max_slice_usec": "Longest uninterrupted work slice.",
	"texture_bytes_estimate": "Estimate from cached image sizes; not total GPU memory.",
	"max_region_usec": "Largest recorded region build time.",
	"wave_sound_suppressed": "Requests blocked by sound replay limits.",
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
		section.collapsed = caption in ["City and view", "Map activity", "Audio", "Internal identifiers"]
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
				section.collapsed = true
				_sections["Other diagnostics"] = section

			_update_row(_sections["Other diagnostics"], key, key, metrics[key])


func _update_row(parent: TreeItem, path: String, key: String, value: Variant) -> void:
	var row: TreeItem = rows.get(path)

	if row == null:
		row = create_item(parent)
		row.set_text(0, LABELS.get(key, key.trim_suffix("_usec").trim_suffix("_msec").capitalize()))
		row.set_text(2, NOTES.get(key, ""))
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
