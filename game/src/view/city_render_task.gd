class_name CityRenderTask
extends RefCounted
# one pooled render job. only the main thread starts, polls, and finishes it
# finish must run once for every successful start, including shutdown

var _task_id := -1
var _result: Variant


func start(action: Callable) -> Error:
	if _task_id >= 0:
		return ERR_ALREADY_IN_USE

	_task_id = WorkerThreadPool.add_task(_run.bind(action), false, "City render")

	return OK if _task_id >= 0 else ERR_CANT_CREATE


func is_running() -> bool:
	return _task_id >= 0 and not WorkerThreadPool.is_task_completed(_task_id)


func finish() -> Variant:
	if _task_id < 0:
		return null

	var error := WorkerThreadPool.wait_for_task_completion(_task_id)
	assert(error == OK, "Render jobs must be joined from their main-thread owner")
	_task_id = -1
	var result: Variant = _result
	_result = null

	return result


func _run(action: Callable) -> void:
	_result = action.call()
