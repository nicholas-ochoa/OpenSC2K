class_name ApplicationCityPngExport
extends RefCounted


const CityModel = preload("res://src/model/city_state.gd")
const ExportJob = preload("res://src/view/city_png_export_job.gd")
const PROGRESS_DELAY_MSEC := 1000
const STAGE_TEXT := {
	ExportJob.STAGE_RENDER: "Drawing the city…",
	ExportJob.STAGE_WRITE: "Writing the PNG file…",
}

var app: CityApplication
var job: CityPngExportJob
var last_folder := ""
var progress_delay_msec := PROGRESS_DELAY_MSEC
var _started_msec := 0


func _init(application: CityApplication) -> void:
	app = application


func is_running() -> bool:
	return job != null


func _open_export_dialog() -> void:
	if app.city == null:
		app.interface._show_error("Load a city before you export it.")

		return

	if is_running():
		app.interface._show_error("A PNG export is already running.")

		return

	app.city_png_export_dialog.configure(
		app.city.city_name(),
		_default_folder(),
		app.city.map_size,
		app.static_render._city_view_size(),
		app.overlay_mode,
		bool(app.surface_visibility.get("signs", true)),
		app.reference_root,
	)
	app.city_png_export_dialog.show_options()


func _start_export(options: Dictionary) -> void:
	if app.city == null or is_running():
		return

	# the worker renders a private copy, so play and edits can continue
	var snapshot := CityModel.from_document(app.document_state.current_document.duplicate_document())

	if not snapshot.is_valid():
		app.interface._show_error("Cannot prepare the city for export: %s" % snapshot.load_error)

		return

	snapshot.visible_altitude_levels = app.city.visible_altitude_levels
	var view_size := int(options.view_size)
	job = ExportJob.new()
	job.city_snapshot = snapshot
	job.palette = app.palette
	job.sprites = app.static_render._sprite_archive_for_view(view_size)
	job.view_size = view_size
	job.render_mode = String(options.view)
	job.transparent_background = bool(options.transparent_background)
	job.include_signs = bool(options.signs)
	job.include_moving_things = bool(options.moving_things)
	job.surface_visibility = app.surface_visibility.duplicate()
	job.show_underground_pipes = app.show_underground_pipes
	job.show_underground_water_mains = app.show_underground_water_mains
	job.path = String(options.path)
	last_folder = job.path.get_base_dir()
	var error := job.start()

	if error != OK:
		job = null
		app.interface._show_error("Cannot start the PNG export: %s" % error_string(error))

		return

	_started_msec = Time.get_ticks_msec()
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Exporting the city to %s…" % options.path.get_file()


func _poll_export() -> void:
	if job == null:
		return

	if job.thread.is_alive():
		if Time.get_ticks_msec() - _started_msec >= progress_delay_msec:
			var progress := job.progress()
			var stage := String(progress.stage)
			# rendering reports its fraction; png encoding cannot
			var fraction := float(progress.fraction) if stage == ExportJob.STAGE_RENDER else -1.0
			app.city_png_export_progress.show_progress(
				"Exporting %s" % job.path.get_file(), String(STAGE_TEXT.get(stage, "")), fraction
			)

		return

	var result: Dictionary = job.thread.wait_to_finish()
	job = null
	app.city_png_export_progress.hide()

	if not result.ok:
		app.interface._show_error("Cannot export the city: %s" % result.error)

		return

	var size: Vector2i = result.size
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Exported a %d by %d city image to %s." % [size.x, size.y, result.path]


func _close() -> void:
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
