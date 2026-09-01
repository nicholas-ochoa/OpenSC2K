class_name PhaseResult
extends RefCounted
# Common phase results. Subclasses add their own fields.



var ok := false
var error := ""

# false when the phase must run again on a later slice of the same day
# a phase that reports no progress has finished
var complete := true

# newspaper stories for the saved queue, and whether they reached it
var news_items: Array = []
var news_queue_updated := false
var news_queue_inserted := 0

# presentation events for the main thread
var sound_events: Array = []
var effect_events: Array = []
var game_over_events: Array = []
var refresh_requests: Array = []
var view_center_requests: Array = []
var music_track_requests := PackedInt32Array()

# measured work for the timing window
var timing: Dictionary = {}


# Tests compare fields through this shallow dictionary. They exclude measured
# durations when checking deterministic results.
func to_dictionary() -> Dictionary:
	var result := {}

	for property in get_property_list():
		var name: String = property.name

		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result[name] = get(name)

	return result


# a phase that only asks the interface to refresh
static func refreshing(requests: Array) -> PhaseResult:
	var result := PhaseResult.new()
	result.ok = true
	result.refresh_requests = requests.duplicate()

	return result
