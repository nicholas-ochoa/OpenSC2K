class_name MusicDirector
extends RefCounted

const FIRST_TRACK_ID := 10000
const TRACK_COUNT := 19
const GENERAL_TRACKS := [10001, 10004, 10008, 10012, 10018]
const BUDGET_TRACKS := [10016, 10005, 10002, 10010]
const NEWSPAPER_TRACKS := [10009, 10015, 10014, 10006, 10002]
const DISASTER_TRACK := 10004
const RECREATION_TRACK := 10010

var general_track_index := 0


func next_general_track() -> int:
	var track: int = GENERAL_TRACKS[general_track_index % GENERAL_TRACKS.size()]
	general_track_index = (general_track_index % GENERAL_TRACKS.size()) + 1
	return track


static func monthly_track(speed: int, playback_active: bool, random: RefCounted) -> int:
	if playback_active or random == null:
		return -1
	var effective_speed := 2 if speed == 1 else speed
	var divisor := (effective_speed * 3 - 3) * 8
	if divisor <= 0 or int(random.next_u15()) % divisor != 0:
		return -1
	return FIRST_TRACK_ID + int(random.next_u15()) % TRACK_COUNT


static func budget_track(random: RefCounted) -> int:
	if random == null:
		return -1
	return BUDGET_TRACKS[int(random.next_mod(BUDGET_TRACKS.size()))]


static func newspaper_track(random: RefCounted) -> int:
	if random == null:
		return -1
	return NEWSPAPER_TRACKS[int(random.next_mod(NEWSPAPER_TRACKS.size()))]
