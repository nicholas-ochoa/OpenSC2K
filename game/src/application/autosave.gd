class_name ApplicationAutosave
extends RefCounted
## Recent autosaves. While a changed city is open, a copy of it is saved each
## minute to a folder in the system temporary folder, and autosaves older than
## ten minutes are deleted. The main thread only takes a copy of the city, which
## shares the city arrays until the game writes them. A worker thread encodes,
## writes, and checks the file, so the game does not wait for an autosave and
## the city, its save path, and its unsaved state do not change.

const INTERVAL_SEC := 60.0
const KEEP_SEC := 600
const FOLDER := "OpenSC2K Autosaves"

var app: CityApplication
# the autosave folder; tests use a folder of their own
var directory := folder()
var last_path := ""
var last_error := ""
var _elapsed := 0.0
var _task := -1
var _job: Job
var _signature: Array = []


func _init(application: CityApplication) -> void:
	app = application


static func folder() -> String:
	return OS.get_temp_dir().path_join(FOLDER)


func process(delta: float) -> void:
	_collect()

	if not app.preferences.recent_autosaves:
		_elapsed = 0.0

		return

	_elapsed += delta

	if _elapsed >= INTERVAL_SEC:
		_elapsed = 0.0
		save_now()


# Start an autosave of the open city. False when no city is open, the city is
# unchanged since the last autosave, an autosave is still running, or the
# simulation waits for the player.
func save_now() -> bool:
	if _job != null:
		return false

	var document := app.document_state.current_document

	if document == null or app.document_state.city == null:
		return false

	var signature := _content_signature(document)

	if signature == _signature:
		return false

	var controller := app.simulation_state.speed_controller

	if document.is_sc2x() and not Sc2xCheckpoint.save_error(controller).is_empty():
		return false

	var copy := document.duplicate_document(true)

	if copy.sc2x_metadata != null:
		Sc2xCheckpoint.capture(controller, copy.sc2x_metadata)

	var name := app.document_state.city.city_name().validate_filename().strip_edges()

	if name.is_empty():
		name = "City"

	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var extension := ".sc2x" if document.is_extended() else ".sc2"
	_job = Job.new()
	_job.document = copy
	_job.path = directory.path_join("%s %s%s" % [name, stamp, extension])
	_job.reference_root = app.asset_state.reference_root
	_task = WorkerThreadPool.add_task(_job.run, false, "Autosave")
	_signature = signature

	return true


# Wait for a running autosave, for example before the game closes.
func close() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)

	_collect()


func _collect() -> void:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return

	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	last_path = _job.saved_path
	last_error = _job.error

	# a failed autosave tries again at the next interval
	if not last_error.is_empty():
		_signature = []

	_job = null


# The chunk revisions change with each edit and simulation day. A new document
# or a renamed city changes the signature too.
static func _content_signature(document: Sc2File) -> Array:
	var signature: Array = [document.get_instance_id(), document.city_name(), document.chunks.size()]

	for chunk in document.chunks:
		signature.append(chunk.mutation_revision)

	return signature


class Job extends RefCounted:
	var document: Sc2File
	var path := ""
	var reference_root := ""
	var saved_path := ""
	var error := ""


	func run() -> void:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var prepared := CityFileStore.prepare(document, path, reference_root)

		if not prepared.ok:
			error = prepared.error

			return

		var written := CityFileStore.write(prepared)

		if not written.ok:
			error = written.error

			return

		saved_path = written.path
		remove_old(path.get_base_dir(), saved_path, int(Time.get_unix_time_from_system()))


	# keep the autosaves of the last ten minutes and the newest one
	static func remove_old(autosave_folder: String, newest: String, now: int) -> void:
		var limit := now - KEEP_SEC

		for file in DirAccess.get_files_at(autosave_folder):
			var file_path := autosave_folder.path_join(file)

			if file_path == newest or file.get_extension().to_lower() not in ["sc2", "sc2x"]:
				continue

			if FileAccess.get_modified_time(file_path) < limit:
				DirAccess.remove_absolute(file_path)
