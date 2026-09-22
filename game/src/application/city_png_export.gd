class_name ApplicationCityPngExport
extends RefCounted


const CityModel = preload("res://src/model/city_state.gd")
const ExportJob = preload("res://src/view/city_png_export_job.gd")
const PROGRESS_DELAY_MSEC := 1000
const STAGE_TEXT := {
	ExportJob.STAGE_RENDER: "Drawing the city…",
	ExportJob.STAGE_WRITE: "Writing the PNG file…",
}

signal error_reported(message: String)
signal status_changed(message: String)

var document_state: ActiveDocumentState
var view_state: ViewState
var asset_state: LoadedAssetState
var current_view_size: Callable
var sprites_for_view: Callable
var dialog: CityPngExportDialog
var progress_overlay: ProgressOverlay
var job: CityPngExportJob
var last_folder := ""
var progress_delay_msec := PROGRESS_DELAY_MSEC
var _started_msec := 0


func _init(document: ActiveDocumentState, view: ViewState, assets: LoadedAssetState,
		graphics_size: Callable, sprites: Callable) -> void:
	document_state = document
	view_state = view
	asset_state = assets
	current_view_size = graphics_size
	sprites_for_view = sprites


func bind_ui(export_dialog: CityPngExportDialog, progress: ProgressOverlay) -> void:
	dialog = export_dialog
	progress_overlay = progress


func is_running() -> bool:
	return job != null


func open_export_dialog() -> void:
	if document_state.city == null:
		error_reported.emit("Load a city before you export it.")

		return

	if is_running():
		error_reported.emit("A PNG export is already running.")

		return

	dialog.configure(
		document_state.city.city_name(),
		_default_folder(),
		document_state.city.map_size,
		current_view_size.call(),
		CityViewMode.key(view_state.overlay_mode),
		bool(view_state.surface_visibility.get("signs", true)),
		asset_state.reference_root,
	)
	dialog.show_options()


func start_export(options: CityPngExportJob.Options) -> void:
	if document_state.city == null or is_running():
		return

	# the worker renders a private copy, so play and edits can continue
	var snapshot := CityModel.from_document(document_state.current_document.duplicate_document())

	if not snapshot.is_valid():
		error_reported.emit("Cannot prepare the city for export: %s" % snapshot.load_error)

		return

	snapshot.visible_altitude_levels = document_state.city.visible_altitude_levels
	var view_size := int(options.view_size)
	job = ExportJob.new()
	job.city_snapshot = snapshot
	job.palette = asset_state.palette
	job.sprites = sprites_for_view.call(view_size)
	job.view_size = view_size
	job.render_mode = String(options.view)
	job.transparent_background = bool(options.transparent_background)
	job.include_signs = bool(options.signs)
	job.include_moving_things = bool(options.moving_things)
	job.surface_visibility = view_state.surface_visibility.duplicate()
	job.show_underground_pipes = view_state.show_underground_pipes
	job.show_underground_water_mains = view_state.show_underground_water_mains
	job.path = String(options.path)
	last_folder = job.path.get_base_dir()
	var error := job.start()

	if error != OK:
		job = null
		error_reported.emit("Cannot start the PNG export: %s" % error_string(error))

		return

	_started_msec = Time.get_ticks_msec()
	status_changed.emit("Exporting the city to %s…" % options.path.get_file())


func poll_export() -> void:
	if job == null:
		return

	if job.thread.is_alive():
		if Time.get_ticks_msec() - _started_msec >= progress_delay_msec:
			var progress := job.progress()
			var stage := String(progress.stage)
			# rendering reports its fraction; png encoding cannot
			var fraction := float(progress.fraction) if stage == ExportJob.STAGE_RENDER else -1.0
			progress_overlay.show_progress(
				"Exporting %s" % job.path.get_file(), String(STAGE_TEXT.get(stage, "")), fraction
			)

		return

	var result: CityPngExportJob.Result = job.thread.wait_to_finish()
	job = null
	progress_overlay.hide()

	if not result.ok:
		error_reported.emit("Cannot export the city: %s" % result.error)

		return

	var size: Vector2i = result.size
	status_changed.emit("Exported a %d by %d city image to %s." % [size.x, size.y, result.path])


func close() -> void:
	if job != null and job.thread != null and job.thread.is_started():
		job.thread.wait_to_finish()

	job = null


func _default_folder() -> String:
	if not last_folder.is_empty() and DirAccess.dir_exists_absolute(last_folder):
		return last_folder

	for directory in [OS.SYSTEM_DIR_PICTURES, OS.SYSTEM_DIR_DOCUMENTS]:
		var path := OS.get_system_dir(directory)

		if not path.is_empty() and DirAccess.dir_exists_absolute(path):
			return path

	return OS.get_environment("HOME")
