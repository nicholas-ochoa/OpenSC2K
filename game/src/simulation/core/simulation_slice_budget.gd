class_name SimulationSliceBudget
extends RefCounted
## A worker parks at checkpoints until the next rendered frame grants time.
## Only the worker calls checkpoint and finish. The main thread grants and cancels.
## The native library keeps the lease, so native simulation loops park too.

# frame waits so far. timings exclude them
var parked_usec: int:
	get:
		return NativeSimulation.budget_parked_usec(handle)

# the native budget. native simulation calls receive it with each request
var handle := NativeSimulation.budget_create()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		NativeSimulation.budget_free(handle)


func checkpoint() -> void:
	NativeSimulation.budget_checkpoint(handle)


func grant(usec: int) -> void:
	NativeSimulation.budget_grant(handle, usec)


func cancel() -> void:
	NativeSimulation.budget_cancel(handle)


func finish() -> void:
	NativeSimulation.budget_finish(handle)


func metrics() -> Metrics:
	var fields: Dictionary = NativeSimulation.budget_metrics(handle)
	var result := Metrics.new()
	result.slices = fields.slices
	result.max_slice_usec = fields.max_slice_usec
	result.waiting = fields.waiting
	result.cancelled = fields.cancelled
	result.elapsed_usec = fields.elapsed_usec
	result.parked_usec = fields.parked_usec

	return result


class Metrics extends RefCounted:
	var slices := 0
	var max_slice_usec := 0
	var waiting := false
	var cancelled := false
	var elapsed_usec := 0
	var parked_usec := 0

	# Values for the debug tree and benchmark JSON.
	func debug_fields() -> Dictionary:
		return {"slices": slices, "max_slice_usec": max_slice_usec, "waiting": waiting, "cancelled": cancelled,
				"elapsed_usec": elapsed_usec, "parked_usec": parked_usec}
