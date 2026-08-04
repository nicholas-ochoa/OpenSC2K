class_name EditCommandResult
extends RefCounted
# Shared edit and undo data. Tool subclasses add their own fields.


# outcome. a failed edit leaves the city unchanged and reports `error`
var ok := false
var error := ""

# tool family, for example "building" or "zone". undo dispatches on it
var command_type := ""
var group_index := -1
var subtool_index := -1

# funds charged. `listed_cost` is the catalog cost before free-mode and
# executable rules. free mode is scurk place & print and the terrain editor
var cost := 0
var listed_cost := 0
var free_mode := false

# decoded chunk payloads before and after the edit, keyed by chunk id. undo
# and redo exchange the `changed_ids` entries
var changed_ids := PackedStringArray()
var old_payloads: Dictionary = {}
var new_payloads: Dictionary = {}

# map positions that the renderer repaints
var tile_indices := PackedInt32Array()
var points: Array[Vector2i] = []
var site := Rect2i()

# tool random state around the edit. scurk history checks and restores it
# when `tracks_random` is true
var tracks_random := false
var random_state_before := 0
var random_state_after := 0

# presentation events for the main thread
var sound_events: Array = []
var effect_events: Array = []

# undo and redo results: the number of tiles restored
var restored_tiles := 0

# set when scurk place & print history owns this edit
var scurk_place_history := false
var scurk_tool_name := ""

# Temporary dictionary storage for tools that have not switched to typed results.
# from_dictionary shares it so their undo code can still read it.
var extra: Dictionary = {}


static func failure(message: String) -> EditCommandResult:
	var result := EditCommandResult.new()
	result.error = message

	return result


static func undone(tiles: int) -> EditCommandResult:
	var result := EditCommandResult.new()
	result.ok = true
	result.restored_tiles = tiles

	return result


# Copy shared fields from an older dictionary result.
static func from_dictionary(source: Dictionary) -> EditCommandResult:
	var result := EditCommandResult.new()
	result.extra = source
	result.ok = source.get("ok", false)
	result.error = source.get("error", "")
	result.command_type = source.get("command_type", "")
	result.group_index = source.get("group_index", -1)
	result.subtool_index = source.get("subtool_index", -1)
	result.cost = source.get("cost", 0)
	result.listed_cost = source.get("listed_cost", 0)
	result.free_mode = source.get("free_mode", false)
	result.changed_ids = source.get("changed_ids", PackedStringArray())
	result.old_payloads = source.get("old_payloads", {})
	result.new_payloads = source.get("new_payloads", {})
	result.tile_indices = source.get("tile_indices", PackedInt32Array())
	result.points.assign(source.get("points", []))
	result.site = source.get("site", Rect2i())
	result.sound_events = source.get("sound_events", [])
	result.effect_events = source.get("effect_events", [])
	result.restored_tiles = source.get("restored_tiles", 0)
	result.scurk_place_history = source.get("scurk_place_history", false)
	result.scurk_tool_name = source.get("scurk_tool_name", "")

	for prefix in ["process_random_state", "random_state"]:
		if source.has(prefix + "_before"):
			result.tracks_random = true
			result.random_state_before = source[prefix + "_before"]
			result.random_state_after = source.get(prefix + "_after", -1)

			break

	return result


# Accept a typed result or convert an older dictionary result.
static func of(value: Variant) -> EditCommandResult:
	return value if value is EditCommandResult else from_dictionary(value)


# an independent copy for paint-brush accumulation
func copy() -> EditCommandResult:
	if not extra.is_empty():
		return from_dictionary(extra.duplicate(true))

	var result: EditCommandResult = get_script().new()

	# packed arrays are shared references, so they are copied like the containers
	for property in get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = get(property.name)

			if value is Dictionary or value is Array:
				value = value.duplicate(true)
			elif typeof(value) > TYPE_ARRAY:
				value = value.duplicate()

			result.set(property.name, value)

	return result


# add one later paint-brush stroke to this accumulated edit
func merge_stroke(stroke: EditCommandResult) -> void:
	for id in stroke.changed_ids:
		if id not in changed_ids:
			changed_ids.append(id)
			old_payloads[id] = stroke.old_payloads[id]

		new_payloads[id] = stroke.new_payloads[id]

	cost += stroke.cost
	listed_cost += stroke.listed_cost
	random_state_after = stroke.random_state_after
	tile_indices.append_array(stroke.tile_indices)
	_merge_counts(stroke)


# subclasses add their own stroke counters
func _merge_counts(_stroke: EditCommandResult) -> void:
	pass
