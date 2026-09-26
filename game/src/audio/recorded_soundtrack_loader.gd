class_name RecordedSoundtrackLoader
extends RefCounted
## Owns queued decoding and rejects results from cancelled music requests.

var generation := 0
var active_request := -1
var thread: Thread
var pending: RecordedSoundtrack.Request


func queue(paths: PackedStringArray) -> void:
	pending = RecordedSoundtrack.Request.new(paths, generation)


func cancel() -> void:
	generation += 1
	pending = null


func is_pending() -> bool:
	return pending != null or (thread != null and active_request == generation)


func take_completed() -> RecordedSoundtrack.Result:
	if thread == null or thread.is_alive():
		return null

	var result: RecordedSoundtrack.Result = thread.wait_to_finish()
	thread = null
	return result if active_request == generation else null


func start_pending() -> Error:
	if thread != null or pending == null:
		return OK

	active_request = pending.request
	var paths := pending.paths
	pending = null
	thread = Thread.new()
	var error := thread.start(RecordedSoundtrack.load_track.bind(paths), Thread.PRIORITY_LOW)
	if error != OK:
		thread = null
	return error


func close() -> void:
	if thread != null:
		thread.wait_to_finish()
		thread = null
