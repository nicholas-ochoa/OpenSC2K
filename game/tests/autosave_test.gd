extends SceneTree
## Recent autosaves: a worker thread writes a copy of the changed city to the
## autosave folder, the open city and its save state do not change, and saves
## older than ten minutes are deleted.

const AppFixture = preload("res://tests/support/app_fixture.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")
const WAIT_MSEC := 20000


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	AppFixture.configure(main)
	root.add_child(main)
	await process_frame
	assert(main.asset_state.assets_ready)
	main.city_files._load_city_unchecked(GeneratedCityFixture.path(128))
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	var autosave := main.autosave
	autosave.directory = OS.get_user_data_dir().path_join("autosave_test")
	_clear(autosave.directory)
	var document := main.document_state.current_document
	var save_path := main.document_state.current_save_path
	var saved_snapshot := main.document_state.saved_city_snapshot
	var started := Time.get_ticks_usec()
	assert(autosave.save_now(), "The changed city starts an autosave")
	print("Autosave main thread time: %d us" % (Time.get_ticks_usec() - started))
	assert(not autosave.save_now(), "One autosave runs at a time")
	await _wait(autosave)
	assert(autosave.last_error.is_empty(), autosave.last_error)
	assert(autosave.last_path.begins_with(autosave.directory) and autosave.last_path.get_extension() == "sc2")
	var saved := Sc2File.load_path(autosave.last_path)
	assert(saved.is_valid() and saved.serialize().data == document.serialize().data, "The autosave holds the city")
	assert(main.document_state.current_document == document and main.document_state.current_save_path == save_path
		and main.document_state.saved_city_snapshot == saved_snapshot, "An autosave leaves the open city and its save state")
	assert(not autosave.save_now(), "An unchanged city is not saved again")
	main.document_state.city.set_funds(main.document_state.city.funds() + 1)
	assert(autosave.save_now(), "A change starts the next autosave")
	await _wait(autosave)
	assert(DirAccess.get_files_at(autosave.directory).size() >= 1)

	var old := autosave.directory.path_join("Old City 2026-01-01_00-00-00.sc2")
	var file := FileAccess.open(old, FileAccess.WRITE)
	file.close()
	var note := autosave.directory.path_join("notes.txt")
	file = FileAccess.open(note, FileAccess.WRITE)
	file.close()
	var now := int(Time.get_unix_time_from_system())
	ApplicationAutosave.Job.remove_old(autosave.directory, autosave.last_path, now)
	assert(FileAccess.file_exists(old), "An autosave of the last ten minutes stays")
	ApplicationAutosave.Job.remove_old(autosave.directory, autosave.last_path, now + ApplicationAutosave.KEEP_SEC + 5)
	assert(not FileAccess.file_exists(old) and FileAccess.file_exists(autosave.last_path) and FileAccess.file_exists(note),
		"Older autosaves are deleted; the newest autosave and other files stay")

	main.preferences.recent_autosaves = false
	main.document_state.city.set_funds(main.document_state.city.funds() + 1)
	autosave.process(ApplicationAutosave.INTERVAL_SEC + 1.0)
	assert(autosave._job == null, "The option turns autosaves off")
	main.preferences.recent_autosaves = true
	autosave.process(ApplicationAutosave.INTERVAL_SEC + 1.0)
	assert(autosave._job != null, "Each interval starts an autosave of a changed city")
	await _wait(autosave)
	_clear(autosave.directory)
	main.queue_free()
	await process_frame
	print("PASS: recent autosaves write on a worker thread, keep the open city and remove old saves")
	quit()


func _wait(autosave: ApplicationAutosave) -> void:
	var deadline := Time.get_ticks_msec() + WAIT_MSEC

	while autosave._job != null and Time.get_ticks_msec() < deadline:
		await process_frame
		autosave.process(0.0)

	assert(autosave._job == null, "The autosave finishes")


func _clear(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)

	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
