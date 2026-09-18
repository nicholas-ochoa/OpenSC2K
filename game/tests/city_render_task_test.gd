extends SceneTree

func _initialize() -> void:
	var release := Semaphore.new()
	var task := CityRenderTask.new()
	assert(task.start(func() -> int:
		release.wait()
		return 42) == OK)
	assert(task.is_running(), "Blocked job stays pending")
	assert(task.start(func() -> int: return 0) == ERR_ALREADY_IN_USE)
	release.post()
	assert(task.finish() == 42, "Joining publishes the completed result")
	assert(not task.is_running())
	assert(task.finish() == null, "A completed task is not joined twice")
	assert(task.start(func() -> PackedInt32Array: return PackedInt32Array([1, 2, 3])) == OK)
	assert(task.finish() == PackedInt32Array([1, 2, 3]), "A reused owner releases its previous result")
	print("PASS: pooled render task publication, busy rejection, shutdown join and reuse")
	quit()
