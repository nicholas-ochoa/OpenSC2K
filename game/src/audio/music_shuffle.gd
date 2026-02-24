class_name MusicShuffle
extends RefCounted

var random := RandomNumberGenerator.new()
var remaining: Array[int] = []
var last_track := -1


func _init() -> void:
	random.randomize()


func next_track() -> int:
	if remaining.is_empty():
		for id in range(MusicDirector.FIRST_TRACK_ID, MusicDirector.FIRST_TRACK_ID + MusicDirector.TRACK_COUNT):
			remaining.append(id)

		for index in range(remaining.size() - 1, 0, -1):
			var other := random.randi_range(0, index)
			var value := remaining[index]
			remaining[index] = remaining[other]
			remaining[other] = value

		if remaining.back() == last_track:
			var value := remaining[0]
			remaining[0] = remaining.back()
			remaining[-1] = value

	last_track = remaining.pop_back()

	return last_track
