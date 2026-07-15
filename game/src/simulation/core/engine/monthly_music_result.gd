class_name MonthlyMusicResult
extends PhaseResult
# the monthly midi gate. active playback skips the selection and its random draw

var playback_was_active := false
var selection_attempted := false


static func selected(was_active: bool, requests: PackedInt32Array) -> MonthlyMusicResult:
	var result := MonthlyMusicResult.new()
	result.ok = true
	result.playback_was_active = was_active
	result.selection_attempted = not was_active
	result.music_track_requests = requests

	return result
