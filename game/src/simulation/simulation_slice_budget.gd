class_name SimulationSliceBudget
extends RefCounted
# a worker parks at checkpoints until the next rendered frame grants time
# only the worker calls checkpoint/finish. the main thread grants/cancels
var parked_usec := 0

var _created_usec := Time.get_ticks_usec()
var _elapsed_usec := 0
var _mutex := Mutex.new()
var _resume := Semaphore.new()
var _waiting := false
var _cancelled := false
var _stopped := false
var _deadline := 0
var _started := 0
var _allowance_usec := 4000
var _slices := 0
var _max_slice_usec := 0

func checkpoint() -> void:
	if _stopped or Time.get_ticks_usec() < _deadline:
		return
	_mutex.lock()
	_record_slice()
	if _cancelled:
		_stopped = true
		_mutex.unlock()
		return
	_waiting = true
	_mutex.unlock()
	var wait_started := Time.get_ticks_usec()
	_resume.wait()
	var waited_usec := Time.get_ticks_usec() - wait_started
	_mutex.lock()
	parked_usec += waited_usec
	if _cancelled:
		_stopped = true
	else:
		_started = Time.get_ticks_usec()
		_deadline = _started + _allowance_usec
		_slices += 1
	_mutex.unlock()

func grant(usec: int) -> void:
	_mutex.lock()
	var wake := _waiting and not _cancelled
	if wake:
		_waiting = false
		_allowance_usec = maxi(100, usec)
	_mutex.unlock()
	if wake:
		_resume.post()

func cancel() -> void:
	_mutex.lock()
	var wake := not _cancelled
	_cancelled = true
	_mutex.unlock()
	if wake:
		_resume.post()

func finish() -> void:
	_mutex.lock()
	_record_slice()
	_elapsed_usec = Time.get_ticks_usec() - _created_usec
	_mutex.unlock()

func metrics() -> Dictionary:
	_mutex.lock()
	var result := {"slices": _slices, "max_slice_usec": _max_slice_usec, "waiting": _waiting, "cancelled": _cancelled, "elapsed_usec": _elapsed_usec, "parked_usec": parked_usec}
	_mutex.unlock()
	return result

func _record_slice() -> void:
	if _started > 0:
		_max_slice_usec = maxi(_max_slice_usec, Time.get_ticks_usec() - _started)
		_started = 0
