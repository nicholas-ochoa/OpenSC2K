class_name ApplicationDebugTileViews
extends RefCounted
## The debug tile layer, its tile value text and the change baselines. A
## worker thread builds the layer values and the change snapshots from shared
## copies of the city arrays, so a large map keeps its frame rate. One build
## runs at a time. A build starts when a source chunk changes, and a slow build
## waits longer before the next one.

@warning_ignore_start("integer_division")

const Layer = DebugTileLayers.Layer
const Baseline = DebugViewState.ChangeBaseline
# the shortest wait between two value builds. After a build, the wait is at
# least VALUE_COST_FACTOR times the build time
const MIN_VALUE_INTERVAL_MSEC := 200
const VALUE_COST_FACTOR := 4
const WINDOW_INTERVAL_MSEC := 100
# tile value text appears when at most this many tiles are in view
const MAX_VALUE_LABEL_TILES := 1200
const LABEL_COLOR := Color(1, 1, 1)
const COORDINATE_COLOR := Color(0.55, 0.95, 1.0)
# coordinate text sits below the value text of the same tile
const COORDINATE_OFFSET := Vector2(0, 6)
const MAX_COORDINATE_LABELS := 300
const MAX_COORDINATE_STEP := 64
const NO_BASELINE := "No baseline yet. It is taken after the next simulated day."
const NO_CHECK := "No result yet. Run the check from the Debug menu or the Scenario tab."

var app: CityApplication
var state: DebugViewState
var values: DebugLayerValues.Result
# Change baselines. A snapshot is filled once, on the worker thread, and is
# not changed after that; a new baseline is a new snapshot
var load_snapshot := NativeTileSnapshot.new()
var mark_snapshot := NativeTileSnapshot.new()
var day_start := NativeTileSnapshot.new()
var day_end := NativeTileSnapshot.new()
var change_counts := PackedInt32Array()
var changed_tiles := 0
var last_value_usec := 0
var value_builds := 0
# labels of the tile values, which ApplicationDebugTools adds to the map labels
var value_labels: Array = []
var _value_signature: Array = []
var _value_due := 0
var _window_due := 0
var _label_signature: Array = []
var _day_serial := 0
# the document of the load baseline
var _load_document_id := 0
# snapshots to fill in the next build: [NativeTileSnapshot, tile arrays]
var _captures: Array = []
var _job: ValueJob
var _task_id := -1
# a new city makes the running build obsolete
var _generation := 0
# check results by layer: [values, summary]
var _external: Dictionary[Layer, Array] = {}
var _external_serial := 0


func _init(application: CityApplication, view_state: DebugViewState) -> void:
	app = application
	state = view_state


func on_city_activated() -> void:
	_generation += 1
	_external.clear()
	_value_signature.clear()
	values = null
	_captures.clear()
	day_start = NativeTileSnapshot.new()
	day_end = NativeTileSnapshot.new()
	mark_snapshot = NativeTileSnapshot.new()
	load_snapshot = NativeTileSnapshot.new()
	_load_document_id = 0

	if DebugMode.enabled:
		_capture_load_baseline()


func on_days_completed() -> void:
	if state.tile_layer != Layer.CHANGED_TILES or state.change_baseline != Baseline.PREVIOUS_DAY:
		return

	var city := app.document_state.city

	if city == null:
		return

	# the end of the last day is the start of this one
	day_start = day_end
	day_end = _queue_capture(city)
	_day_serial += 1


func take_snapshot() -> String:
	var city := app.document_state.city

	if city == null:
		return "Load a city before you take a change snapshot."

	mark_snapshot = _queue_capture(city)
	state.change_baseline = Baseline.SNAPSHOT
	_value_signature.clear()

	return "Change snapshot taken. Changed Tiles now compares with this moment."


func set_baseline(baseline: Baseline) -> void:
	state.change_baseline = baseline
	_value_signature.clear()

	if baseline == Baseline.PREVIOUS_DAY and app.document_state.city != null:
		day_start = NativeTileSnapshot.new()
		day_end = _queue_capture(app.document_state.city)
	elif baseline == Baseline.LOAD:
		_capture_load_baseline()


func set_layer(layer: Layer) -> void:
	state.tile_layer = layer
	_window_due = 0
	_value_signature.clear()
	_label_signature.clear()
	var view := app.map_view.debug_view

	if layer == Layer.NONE:
		values = null
		value_labels.clear()
		view.legend_summary = ""
		view.tile_layer.set_layer(Layer.NONE)

		# the grid keeps the window mesh
		if not state.tile_grid:
			view.tile_layer.clear()
	elif layer == Layer.CHANGED_TILES:
		set_baseline(state.change_baseline)

	app.map_view.queue_redraw()


# the values of a check layer, such as the disaster preview. the layer shows them
func set_external(layer: Layer, data: PackedByteArray, summary: String) -> void:
	_external[layer] = [data, summary]
	_external_serial += 1

	if state.tile_layer != layer:
		set_layer(layer)
	else:
		_value_signature.clear()


func has_external(layer: Layer) -> bool:
	return _external.has(layer)


func set_grid(enabled: bool) -> void:
	state.tile_grid = enabled
	_window_due = 0
	_label_signature.clear()
	var view := app.map_view.debug_view
	view.tile_layer.set_grid(enabled)

	if not enabled and state.tile_layer == Layer.NONE:
		view.tile_layer.clear()

	app.map_view.queue_redraw()


# true when the map labels changed
func process(now: int) -> bool:
	_collect_job()
	var city := app.document_state.city

	if (state.tile_layer == Layer.NONE and not state.tile_grid) or city == null or app.map_view == null:
		# the grid or the layer turned off: take its text off the map
		if value_labels.is_empty():
			return false

		value_labels.clear()
		_label_signature.clear()

		return true

	var view := app.map_view.debug_view

	if now >= _window_due:
		_window_due = now + WINDOW_INTERVAL_MSEC
		var target := CityDebugTileLayer.visible_window(app.map_view.visible_tile_outline(), city.map_size)
		var geometry := CityDataView.geometry_signature(city)

		if view.tile_layer.needs_window(target, geometry):
			view.tile_layer.build_window(city, target, geometry)
			app.map_view.queue_redraw()

	if state.tile_layer == Layer.NONE:
		view.tile_layer.set_empty_values(city.map_size)

		return _refresh_labels(city)

	if now >= _value_due and _job == null:
		var signature := _signature(city)

		if signature != _value_signature:
			_start_job(city, signature)

	return _refresh_labels(city)


func _start_job(city: CityState, signature: Array) -> void:
	_job = ValueJob.new()
	_job.layer = state.tile_layer
	_job.source = DebugLayerValues.source(city, state.tile_layer)
	_job.signature = signature
	_job.generation = _generation
	_job.captures = _captures
	_captures = []

	if state.tile_layer == Layer.CHANGED_TILES:
		_job.baseline = _baseline()
		_job.current = tiles(city)
	elif state.tile_layer in DebugTileLayers.EXTERNAL:
		var external: Array = _external.get(state.tile_layer, [PackedByteArray(), NO_CHECK])
		_job.source["external"] = external[0]
		_job.external_summary = external[1]

	_task_id = WorkerThreadPool.add_task(_job.run, false, "Debug tile layer")


func _collect_job() -> void:
	if _job == null or not WorkerThreadPool.is_task_completed(_task_id):
		return

	WorkerThreadPool.wait_for_task_completion(_task_id)
	var job := _job
	_job = null
	_task_id = -1
	last_value_usec = job.usec
	_value_due = Time.get_ticks_msec() + maxi(MIN_VALUE_INTERVAL_MSEC, job.usec * VALUE_COST_FACTOR / 1000)

	if job.generation != _generation or job.layer != state.tile_layer or app.document_state.city == null:
		return

	var city := app.document_state.city
	var view := app.map_view.debug_view
	values = job.result
	view.tile_layer.set_layer(job.layer)
	view.tile_layer.set_values(values.image, city.map_size)
	var summary := values.summary

	if job.layer == Layer.CHANGED_TILES:
		change_counts = job.counts
		changed_tiles = job.changed
		summary = _change_summary() if job.has_baseline else NO_BASELINE
	elif job.layer in DebugTileLayers.EXTERNAL:
		summary = job.external_summary

	if view.tile_layer.clipped:
		summary += ("\n" if not summary.is_empty() else "") + (
			"Zoomed out: the layer covers %d x %d tiles around the view center." % [
				CityDebugTileLayer.MAX_WINDOW_EDGE, CityDebugTileLayer.MAX_WINDOW_EDGE])

	view.legend_summary = summary
	_value_signature = job.signature
	_label_signature.clear()
	value_builds += 1
	app.map_view.queue_redraw()


# wait for a running build, before the application exits
func close() -> void:
	if _job != null:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_job = null
		_task_id = -1


func _change_summary() -> String:
	var parts := PackedStringArray()

	for plane in change_counts.size():
		if change_counts[plane] > 0:
			parts.append("%s %d" % [DebugTileLayers.CHANGE_NAMES[plane], change_counts[plane]])

	var baseline_title: String = CityDebugMenu.BASELINE_TITLES[state.change_baseline]
	var detail := ": " + ", ".join(parts) if not parts.is_empty() else ""

	return "%d tiles changed %s%s" % [changed_tiles, baseline_title.to_lower(), detail]


func _signature(city: CityState) -> Array:
	var result: Array = [state.tile_layer, city.map_size, city.mirror_signature(DebugTileLayers.source_chunks(state.tile_layer))]

	if state.tile_layer == Layer.CHANGED_TILES:
		result.append_array([state.change_baseline, _baseline().get_instance_id(), _day_serial])
	elif state.tile_layer in DebugTileLayers.EXTERNAL:
		result.append(_external_serial)

	return result


func _baseline() -> NativeTileSnapshot:
	match state.change_baseline:
		Baseline.SNAPSHOT:
			return mark_snapshot
		Baseline.PREVIOUS_DAY:
			return day_start

	return load_snapshot


# a new snapshot of the city now. the next build fills it
func _queue_capture(city: CityState) -> NativeTileSnapshot:
	var snapshot := NativeTileSnapshot.new()
	_captures.append([snapshot, tiles(city)])

	return snapshot


func _capture_load_baseline() -> void:
	var city := app.document_state.city

	if city == null or _load_document_id == city.document.get_instance_id():
		return

	load_snapshot = _queue_capture(city)
	_load_document_id = city.document.get_instance_id()


# value text on each visible tile at a close zoom, and tile coordinates with
# the grid. true when the labels changed
func _refresh_labels(city: CityState) -> bool:
	var values_shown := state.tile_values and values != null

	if not values_shown and not state.tile_grid:
		if value_labels.is_empty():
			return false

		value_labels.clear()
		_label_signature.clear()

		return true

	var outline := app.map_view.visible_tile_outline()
	var bounds := CityDebugTileLayer.visible_window(outline, city.map_size, 2)
	var signature: Array = [bounds, _value_signature, app.map_view.zoom_factor, values_shown, state.tile_grid]

	if signature == _label_signature:
		return false

	_label_signature = signature
	value_labels.clear()

	if state.tile_grid:
		_add_coordinate_labels(city, bounds)

	# a diamond view covers about half of its tile rectangle
	if not values_shown or bounds.get_area() / 2 > MAX_VALUE_LABEL_TILES:
		return true

	for x in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			var value := DebugLayerValues.value_at(values, city.map_size, Vector2i(x, y))

			if value > 0 and city.tile_is_visible(x, y):
				value_labels.append([CityMapDebugView.tile_center(city, Vector2i(x, y)), str(value), LABEL_COLOR])

	return true


# "x,y" on every nth tile, with n a power of two that keeps the text readable
func _add_coordinate_labels(city: CityState, bounds: Rect2i) -> void:
	var step := 1

	while step < MAX_COORDINATE_STEP and bounds.get_area() / (2 * step * step) > MAX_COORDINATE_LABELS:
		step *= 2

	var first := Vector2i(ceili(bounds.position.x / float(step)) * step, ceili(bounds.position.y / float(step)) * step)

	for x in range(first.x, bounds.end.x, step):
		for y in range(first.y, bounds.end.y, step):
			if city.tile_is_visible(x, y):
				var at := CityMapDebugView.tile_center(city, Vector2i(x, y)) + COORDINATE_OFFSET
				value_labels.append([at, "%d,%d" % [x, y], COORDINATE_COLOR])


# the layer value text of a tile for the Tile Inspector, or an empty string
func describe(point: Vector2i) -> String:
	var city := app.document_state.city

	if values == null or city == null:
		return ""

	return DebugTileLayers.describe(state.tile_layer, DebugLayerValues.value_at(values, city.map_size, point))


func metrics() -> Dictionary:
	var layer := app.map_view.debug_view.tile_layer if app.map_view != null and app.map_view.debug_view.is_attached() else null

	return {
		"layer": DebugTileLayers.title(state.tile_layer),
		"value_builds": value_builds,
		"last_value_usec": last_value_usec,
		"building": _job != null,
		"window_builds": layer.builds if layer != null else 0,
		"last_window_usec": layer.last_build_usec if layer != null else 0,
		"window_tiles": layer.window_tiles if layer != null else 0,
		"changed_tiles": changed_tiles,
	}


static func tiles(city: CityState) -> Dictionary:
	return {
		"edge": city.map_size, "buildings": city.buildings, "zones": city.zones, "terrain": city.terrain,
		"altitude": city.altitude_words, "underground": city.underground, "overlays": city.text_overlays,
		"flags": city.tile_flags,
	}


## One layer build. The worker thread fills the snapshots, then builds the
## values. The main thread reads the results after the task completes.
class ValueJob extends RefCounted:
	var layer := DebugTileLayers.Layer.NONE
	var source := {}
	var signature: Array = []
	var generation := 0
	var captures: Array = []
	var baseline: NativeTileSnapshot
	var current := {}
	var external_summary := ""
	var result: DebugLayerValues.Result
	var counts := PackedInt32Array()
	var changed := 0
	var has_baseline := false
	var usec := 0

	func run() -> void:
		var started := Time.get_ticks_usec()

		for capture in captures:
			(capture[0] as NativeTileSnapshot).capture(capture[1])

		var changes := PackedByteArray()

		if baseline != null and not baseline.is_empty():
			var difference := baseline.difference(current, Sc2TileFlags.MARK)
			changes = difference.values
			counts = difference.counts
			changed = int(difference.tiles)
			has_baseline = true

		result = DebugLayerValues.build(source, layer, changes)
		usec = Time.get_ticks_usec() - started
