class_name MusicDirector
extends RefCounted
## The music tracks that the game chooses. The native simulation library holds
## the rules; see native/core/sim/src/sim/reports/music.rs.

const MAIN_THEME_TRACK := 10001
const ABOUT_TRACK := 10011
const FIRST_TRACK_ID := 10000
const TRACK_COUNT := 19
const DISASTER_TRACK := 10004
const RECREATION_TRACK := 10010

var general_track_index := 0


func next_general_track() -> int:
	var next := NativeSimulation.next_general_track(general_track_index)
	general_track_index = next[1]

	return next[0]


static func budget_track(random: SimLfsrRandom) -> int:
	return _draw_track("budget", random)


static func newspaper_track(random: SimLfsrRandom) -> int:
	return _draw_track("newspaper", random)


static func _draw_track(kind: String, random: SimLfsrRandom) -> int:
	if random == null:
		return -1

	var drawn := NativeSimulation.music_track(kind, random.state)
	random.state = drawn.state

	return drawn.track
