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
# and redo exchange the `changed_ids` entries. published payload arrays are
# read-only. replace dictionary entries to extend an edit; never modify bytes
var changed_ids := PackedStringArray()
var old_payloads: Dictionary[String, PackedByteArray] = {}
var new_payloads: Dictionary[String, PackedByteArray] = {}

# map positions that the renderer repaints
var tile_indices := PackedInt32Array()
var points: Array[Vector2i] = []
var site := Rect2i()

# tool random state around the edit. scurk history checks and restores it
# when `tracks_random` is true
var tracks_random := false
var random_state_before := 0
var random_state_after := 0

# utilization from an immediate power or water scan, or -1 when none ran.
# the application keeps the engine values from before the edit for undo
var power_usage_percent := -1
var water_usage_percent := -1
var power_usage_before := -1
var water_usage_before := -1

# presentation events for the main thread
var sound_events: Array[int] = []
var effect_events: Array[EffectEvent] = []

# undo and redo results: the number of tiles restored
var restored_tiles := 0

# set when scurk place & print history owns this edit
var scurk_place_history := false
var scurk_tool_name := ""

# runtime-only reflection plan. script variables do not change between copies
var _copy_names := PackedStringArray()

static func failure(message: String) -> EditCommandResult:
	var result := EditCommandResult.new()
	result.error = message

	return result


static func undone(tiles: int) -> EditCommandResult:
	var result := EditCommandResult.new()
	result.ok = true
	result.restored_tiles = tiles

	return result


# independent mutable containers, for brush accumulation and stadium choices
# published payload bytes are read-only and can be shared between copies
func copy() -> EditCommandResult:
	var result: EditCommandResult = get_script().new()

	if _copy_names.is_empty():
		for property in get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name != "_copy_names":
				_copy_names.append(property.name)

	result._copy_names = _copy_names

	for name in _copy_names:
		var value: Variant = get(name)

		if value is Dictionary:
			value = value.duplicate(name != "old_payloads" and name != "new_payloads")
		elif value is Array:
			value = value.duplicate(true)
		elif typeof(value) > TYPE_ARRAY:
			value = value.duplicate()

		result.set(name, value)

	result.effect_events = EffectEvent.copy_all(effect_events)

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


# drop chunks which this edit never changes. pending multi-step edits must
# retain their initial snapshots until all steps have completed
func retain_changed_payloads() -> void:
	for id in old_payloads.keys():
		if id not in changed_ids:
			old_payloads.erase(id)

	for id in new_payloads.keys():
		if id not in changed_ids:
			new_payloads.erase(id)
