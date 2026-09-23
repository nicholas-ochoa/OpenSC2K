class_name PhaseResult
extends RefCounted
# Common phase results. Subclasses add their own fields.



var ok := false
var error := ""

# false when the phase must run again on a later slice of the same day
# a phase that reports no progress has finished
var complete := true

# newspaper stories for the saved queue, and whether they reached it
var news_items: Array[NewsEvent] = []
var news_queue_updated := false
var news_queue_inserted := 0

# presentation events for the main thread
var sound_events: Array[SoundEvent] = []
var effect_events: Array[EffectEvent] = []
var game_over_events: Array[GameOverEvent] = []
var refresh_requests: Array[String] = []
var view_center_requests: Array[Vector2i] = []
var music_track_requests := PackedInt32Array()

# original string IDs for modal message boxes. the interface shows each one
# and suspends the simulation until the player closes it
var notice_ids := PackedInt32Array()

# true when the original opens the newspaper after this work
var newspaper_requested := false

# measured work for the timing window
var timing := SimulationTiming.new()


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
static func refreshing(requests: Array[String]) -> PhaseResult:
	var result := PhaseResult.new()
	result.ok = true
	result.refresh_requests = requests.duplicate()

	return result
