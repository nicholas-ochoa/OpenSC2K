class_name WaveSoundGate
extends RefCounted
## Which wave sounds play: one sound plays at a time, and moving objects and
## simulation events wait for their replay delays. A disaster loop plays beside
## them. The native audio library holds the rules; see
## native/core/audio/src/wave_gate.rs and sound_loop.rs.

# player preference for vehicle sounds. disaster sounds and player feedback always play
enum CitySounds { DEFAULT, REDUCED, OFF }

const SOUND_FIRST := 500
const SOUND_LAST := 529
const SOUND_EXPLODE := 504
const SOUND_FLOOD := 511
# presentation preferences of the native gate: the event and reduced replay delays
const EVENT_REPLAY_MSEC := 10000.0
const REDUCED_REPLAY_MSEC := 30000.0

var current_sound_id: int:
	get:
		return _native.metrics().current_sound_id
var remaining_ticks: int:
	get:
		return _native.metrics().remaining_ticks
var accepted_count: int:
	get:
		return _native.metrics().accepted_count
var suppressed_count: int:
	get:
		return _native.metrics().suppressed_count
# the sound that loops, or -1
var loop_sound_id: int:
	get:
		return _native.loop_sound_id()
# the plays of a counted loop, or 0 for a loop until `stop_loop`
var loop_plays: int:
	get:
		return _native.loop_plays()
var city_sounds: CitySounds:
	get:
		return _native.city_sounds() as CitySounds
	set(value):
		_native.set_city_sounds(value)

var _native := NativeWaveSoundGate.new()


static func duration_ticks(sound_id: int) -> int:
	return NativeWaveSoundGate.duration_ticks(sound_id)


static func event_replay_msec(sound_id: int) -> float:
	return NativeWaveSoundGate.event_replay_msec(sound_id)


# `ambient` requests come from moving objects. `simulation` requests come from other
# simulation events. both wait for their replay delay. other requests are player feedback
func request(sound_id: int, ambient := false, simulation := false) -> bool:
	return _native.request(sound_id, ambient, simulation)


# loops the sound for `plays` plays, or until `stop_loop` when `plays` is less than 1
func request_loop(sound_id: int, plays: int) -> void:
	_native.request_loop(sound_id, plays)


func stop_loop() -> void:
	_native.stop_loop()


func advance(delta_msec: float) -> void:
	_native.advance(delta_msec)


func stop() -> void:
	_native.stop()


func metrics() -> Dictionary:
	return _native.metrics()
