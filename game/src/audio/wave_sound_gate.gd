class_name WaveSoundGate
extends RefCounted

const SOUND_FIRST := 500
const SOUND_LAST := 529
const BASE_TICK_MSEC := 200.0
const MINIMUM_REPLAY_TICKS := 3
# presentation preference: share the ambient delay across all moving objects
const AMBIENT_REPLAY_MSEC := 15000.0
# presentation preference: the delay before a simulation event sound, such as a fire or flood, plays again
const EVENT_REPLAY_MSEC := 10000.0

# supplied executable table 0x004ea858 before its initialization pass
const RAW_DURATION_MSEC := [
	492, 153, 1485, 129, 1156, 221, 1064, 1657, 1510, 1511,
	2264, 886, 2766, 2203, 473, 625, 782, 1223, 2444, 1308,
	2468, 971, 2194, 1414, 2338, 1165, 1937, 2359, 1510, 1613,
]

# replay delays of ambient and simulation event sounds
var _ambient_remaining: Dictionary = {}
var _event_remaining: Dictionary = {}

var current_sound_id := -1
var remaining_ticks := 0
var accepted_count := 0
var suppressed_count := 0
var _tick_accumulator_msec := 0.0


static func duration_ticks(sound_id: int) -> int:
	if sound_id < SOUND_FIRST or sound_id > SOUND_LAST:
		return 0

	return int(RAW_DURATION_MSEC[sound_id - SOUND_FIRST] / 200) + 1


# `ambient` requests come from moving objects. `simulation` requests come from other
# simulation events. both wait for their replay delay and for the active sound to end.
# other requests are player feedback
func request(sound_id: int, ambient := false, simulation := false) -> bool:
	var total_ticks := duration_ticks(sound_id)

	if total_ticks == 0:
		return false

	var delays := _ambient_remaining if ambient else _event_remaining

	if (ambient or simulation) and (float(delays.get(sound_id, 0.0)) > 0.0 or remaining_ticks > 0):
		suppressed_count += 1

		return false

	if (
		current_sound_id == sound_id
		and remaining_ticks > 0
		and total_ticks - remaining_ticks < MINIMUM_REPLAY_TICKS
	):
		suppressed_count += 1

		return false

	current_sound_id = sound_id
	remaining_ticks = total_ticks

	if ambient:
		_ambient_remaining[sound_id] = AMBIENT_REPLAY_MSEC
	elif simulation:
		_event_remaining[sound_id] = EVENT_REPLAY_MSEC

	accepted_count += 1

	return true


func advance(delta_msec: float) -> void:
	if delta_msec <= 0.0:
		return

	for delays in [_ambient_remaining, _event_remaining]:
		for sound_id in delays.keys():
			var remaining := float(delays[sound_id]) - delta_msec

			if remaining <= 0.0:
				delays.erase(sound_id)
			else:
				delays[sound_id] = remaining

	_tick_accumulator_msec += delta_msec

	while _tick_accumulator_msec >= BASE_TICK_MSEC:
		_tick_accumulator_msec -= BASE_TICK_MSEC

		if remaining_ticks <= 0:
			continue

		remaining_ticks -= 1

		if remaining_ticks == 0:
			current_sound_id = -1


func stop() -> void:
	_ambient_remaining.clear()
	_event_remaining.clear()
	current_sound_id = -1
	remaining_ticks = 0
	_tick_accumulator_msec = 0.0


func metrics() -> Dictionary:
	return {
		"current_sound_id": current_sound_id,
		"remaining_ticks": remaining_ticks,
		"accepted_count": accepted_count,
		"suppressed_count": suppressed_count,
	}
