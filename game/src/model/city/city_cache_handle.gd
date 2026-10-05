class_name CityCacheHandle
extends RefCounted
## A native copy of the chunks of one city. Simulation and tool calls send the
## chunks with their revisions, and the native library copies only the chunks
## that changed since the last call. A simulation snapshot shares the handle of
## its city. See native/simulation/src/bridge/city_cache.rs.

var handle := NativeSimulation.cache_create()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		NativeSimulation.cache_free(handle)
