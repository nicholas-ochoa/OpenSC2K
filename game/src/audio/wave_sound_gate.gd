class_name WaveSoundGate
extends RefCounted

const SOUND_FIRST := 500
const SOUND_LAST := 529
const BASE_TICK_MSEC := 200.0
const MINIMUM_REPLAY_TICKS := 3

# supplied executable table 0x004ea858 before its initialization pass
const RAW_DURATION_MSEC := [
	492, 153, 1485, 129, 1156, 221, 1064, 1657, 1510, 1511,
	2264, 886, 2766, 2203, 473, 625, 782, 1223, 2444, 1308,
	2468, 971, 2194, 1414, 2338, 1165, 1937, 2359, 1510, 1613,
]

var current_sound_id := -1
var remaining_ticks := 0
var accepted_count := 0
var suppressed_count := 0
var _tick_accumulator_msec := 0.0


static func duration_ticks(sound_id: int) -> int:
	if sound_id < SOUND_FIRST or sound_id > SOUND_LAST:
		return 0
	return int(RAW_DURATION_MSEC[sound_id - SOUND_FIRST] / 200) + 1


func request(sound_id: int) -> bool:
	var total_ticks := duration_ticks(sound_id)
	if total_ticks == 0:
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
	accepted_count += 1
	return true


func advance(delta_msec: float) -> void:
	if delta_msec <= 0.0:
		return
	_tick_accumulator_msec += delta_msec
	while _tick_accumulator_msec >= BASE_TICK_MSEC:
		_tick_accumulator_msec -= BASE_TICK_MSEC
		if remaining_ticks <= 0:
			continue
		remaining_ticks -= 1
		if remaining_ticks == 0:
			current_sound_id = -1


func stop() -> void:
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
