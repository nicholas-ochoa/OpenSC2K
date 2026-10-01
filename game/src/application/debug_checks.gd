class_name ApplicationDebugChecks
extends RefCounted
## On-demand debug checks: the save round trip, the missing artwork of the
## tiles in view and the disaster preview. The save check and the artwork
## check run on a worker thread; their results arrive in `process`.

var app: CityApplication
var save_report: DebugSaveCheck.Report
var _save_task := -1
var _save_job: DebugSaveCheck.Job
var _artwork_task := -1
var _artwork_job: ArtworkJob


func _init(application: CityApplication) -> void:
	app = application


func is_busy() -> bool:
	return _save_job != null or _artwork_job != null


# Save a copy of the city to a temporary file, load it back, and compare every
# chunk. The open city and its save path do not change
func verify_save() -> String:
	if _save_job != null:
		return "A save check is still running."

	var job := DebugSaveCheck.prepare(app.document_state.current_document, app.asset_state.reference_root,
		app.simulation_state.speed_controller)

	if not job.error.is_empty():
		return job.error

	_save_job = job
	_save_task = WorkerThreadPool.add_task(job.run, false, "Debug save check")

	return "Checking the save round trip of %s..." % DebugFileInfo.format_name(app.document_state.current_document)


func check_missing_artwork() -> String:
	if _artwork_job != null:
		return "An artwork check is still running."

	var city := app.document_state.city

	if city == null or app.asset_state.palette == null:
		return "Load a city before you check its artwork."

	var cache := app.render_caches.region_cache
	var job := ArtworkJob.new()
	# the region snapshot belongs to no other writer. a copy serves without one
	job.city = cache.display_city if cache != null and cache.display_city != null else CityState.copy_for_edit(city)
	job.view = app.static_render.city_view_size()
	job.sprites = app.static_render.sprite_archive_for_view(job.view)
	job.palette = app.asset_state.palette
	job.window = CityDebugTileLayer.visible_window(app.map_view.visible_tile_outline(), city.map_size, 0)
	job.window = CityDebugTileLayer.limited(job.window, job.window)
	_artwork_job = job
	_artwork_task = WorkerThreadPool.add_task(job.run, false, "Debug artwork check")

	return "Checking the artwork of %d x %d tiles around the view..." % [job.window.size.x, job.window.size.y]


func preview_disaster(disaster_type: int, ticks: int) -> String:
	var city := app.document_state.city

	if city == null:
		return "Load a city before you preview a disaster."

	var point := app.map_view.center_tile()
	var result := DisasterPreview.run(app.simulation_state.speed_controller, disaster_type, point, ticks)

	if not result.ok:
		return result.error

	app.debug_tools.show_check_result(DebugTileLayers.Layer.DISASTER_PREVIEW, result.values, result.summary(), point)

	return result.summary()


# collect finished checks. returns a status message, or an empty string
func process() -> String:
	var message := ""

	if _save_job != null and WorkerThreadPool.is_task_completed(_save_task):
		WorkerThreadPool.wait_for_task_completion(_save_task)
		save_report = _save_job.report
		_save_job = null
		_save_task = -1
		message = save_report.summary()
		app.debug_tools.show_save_report(save_report)

	if _artwork_job != null and WorkerThreadPool.is_task_completed(_artwork_task):
		WorkerThreadPool.wait_for_task_completion(_artwork_task)
		var job := _artwork_job
		_artwork_job = null
		_artwork_task = -1
		message = job.summary()

		if job.error.is_empty() and app.document_state.city != null:
			app.debug_tools.show_check_result(DebugTileLayers.Layer.MISSING_ARTWORK, job.values(app.document_state.city.map_size),
				message)

	return message


func close() -> void:
	if _save_job != null:
		WorkerThreadPool.wait_for_task_completion(_save_task)
		_save_job = null

	if _artwork_job != null:
		WorkerThreadPool.wait_for_task_completion(_artwork_task)
		_artwork_job = null


## The tiles of a window that need artwork the sprite set lacks. The worker
## paints each tile with placeholders in its own native builder.
class ArtworkJob extends RefCounted:
	var city: CityState
	var palette: Sc2Palette
	var sprites: Sc2SpriteArchive
	var view := 2
	var window := Rect2i()
	var cells := PackedInt32Array()
	var tile_sprites := PackedInt32Array()
	var missing := PackedInt32Array()
	var error := ""

	func run() -> void:
		var context := CityGpuBuildContext.new()
		error = context.prepare(city, palette, sprites, view, CityViewMode.Mode.CITY, true, true, true, 0, false)

		if not error.is_empty():
			return

		var found: Dictionary = context.builder.missing_tiles(window)
		cells = found.cells
		tile_sprites = found.sprites
		missing = found.all

	func values(map_edge: int) -> PackedByteArray:
		var result := PackedByteArray()
		result.resize(map_edge * map_edge)

		for cell in cells:
			if cell < result.size():
				result[cell] = 1

		return result

	func summary() -> String:
		if not error.is_empty():
			return "The artwork check failed: %s." % error

		if cells.is_empty():
			return "Every tile in the %d x %d tile window has its artwork." % [window.size.x, window.size.y]

		var shown := Array(missing).slice(0, 12).map(func(id: int) -> String: return str(id))

		return "%d tiles need %d missing sprites: %s%s." % [cells.size(), missing.size(), ", ".join(shown),
			"…" if missing.size() > shown.size() else ""]
