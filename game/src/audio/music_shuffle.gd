class_name MusicShuffle
extends RefCounted
## The shuffled order of the music tracks: each track plays once before any
## track repeats. The native audio library keeps the order; see
## native/core/audio/src/shuffle.rs.

# the tracks that the current round has not played
var remaining: PackedInt64Array:
	get:
		return _native.remaining()
	set(tracks):
		_native.set_remaining(tracks)

var _native := NativeMusicShuffle.new()


func next_track() -> int:
	return _native.next_track(MusicDirector.FIRST_TRACK_ID, MusicDirector.TRACK_COUNT)


# a track that started outside the shuffle: the round skips it, and the next
# round does not start with it
func mark_started(track: int) -> void:
	_native.mark_started(track)


func restart_after(track: int) -> void:
	_native.restart_after(track)


# restart the order with `value`, for a repeatable test
func seed(value: int) -> void:
	_native.seed(value)
