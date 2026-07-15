class_name PhaseResult
extends RefCounted
# Common phase results. Phase-specific values still use extra.


# outcome. a failed phase stops the day and reports `error`
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

# from_dictionary shares this dictionary with the caller.
var extra: Dictionary = {}


# Copy shared fields from an older dictionary result.
static func from_dictionary(source: Dictionary) -> PhaseResult:
	var result := PhaseResult.new()
	result.extra = source
	result.ok = source.get("ok", false)
	result.error = source.get("error", "")
	result.complete = source.get("complete", true)
	result.news_items = source.get("news_items", [])
	result.news_queue_updated = source.get("news_queue_updated", false)
	result.news_queue_inserted = source.get("news_queue_inserted", 0)
	result.sound_events = source.get("sound_events", [])
	result.effect_events = source.get("effect_events", [])
	result.game_over_events = source.get("game_over_events", [])
	result.refresh_requests = source.get("refresh_requests", [])
	result.view_center_requests = source.get("view_center_requests", [])
	result.music_track_requests = source.get("music_track_requests", PackedInt32Array())
	result.timing = source.get("timing", {})

	return result


# Dictionary view for comparisons and debug output.
func to_dictionary() -> Dictionary:
	var result := extra.duplicate()

	for property in get_property_list():
		var name: String = property.name

		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and name != "extra":
			result[name] = get(name)

	return result


# a phase that only asks the interface to refresh
static func refreshing(requests: Array) -> PhaseResult:
	var result := PhaseResult.new()
	result.ok = true
	result.refresh_requests = requests.duplicate()

	return result
