class_name DebugObjectFields
extends RefCounted
# meanings follow the current tick/renderer consumers, not a universal xthg enum

const EIGHT := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const FOUR := ["N", "E", "S", "W"]
const STATES := {
	1: {0: "Taking off", 1: "Landing", 2: "Cruising", 3: "Approaching target", 4: "Aligning with runway", 7: "Falling spiral"},
	2: {0: "Taking off", 2: "Flying to target", 3: "Descending", 4: "Waiting on ground", 5: "Crashing"},
	3: {0: "Under way", 1: "Turning toward target", 2: "Finding clear route", 3: "Docked", 4: "Departing"},
	5: {0: "Descending toward city", 1: "Attacking", 2: "Rising", 3: "Retreat / military reaction"},
	16: {0: "Pursuing target", 1: "Avoiding collision", 2: "Moving onward"},
}
const FIELDS := ["type", "direction", "state", "x", "y", "z", "px", "py", "dx", "dy", "label", "goal"]
# debug table column order; these fields show their translation instead of the stored number
const COLUMNS := ["type", "state", "direction", "goal", "x", "y", "z", "px", "py", "dx", "dy", "label"]
const TRANSLATED := ["type", "state", "direction", "goal", "label"]


static func type_name(value: int) -> String:
	return QueryInfo.THING_NAMES[value] if value >= 0 and value < QueryInfo.THING_NAMES.size() else "Unknown object type"


static func direction(record: Dictionary) -> String:
	var value := int(record.direction)
	var type := int(record.type)

	if type == 6:
		return "Animation frame %d%s" % [value, " (finishes on tick)" if value >= 2 else ""]
	if type in [7, 8, 14]:
		return "Unused by stationary dispatch"
	if type in [4, 9]:
		return FOUR[value] if value >= 0 and value < 4 else "Invalid cardinal direction"
	if type in [10, 11, 12, 13]:
		var cardinal := value & 15
		var result: String = FOUR[cardinal] if cardinal < 4 else "Invalid cardinal direction"
		return result + ("; high bits 0x%X ignored by route tick" % (value & 0xf0) if value > 15 else "")
	if type in [1, 2, 3, 5, 15, 16]:
		return EIGHT[value] if value >= 0 and value < 8 else "Invalid eight-way direction"

	return "Not interpreted for this type"


static func state(record: Dictionary, city: CityState) -> String:
	var value := int(record.state)
	var type := int(record.type)

	if type in [11, 13] and value == 0:
		return "Tail car / no next car"
	if type in [10, 11, 12, 13]:
		return "Next car: " + _target(value, city)
	if type == 9:
		return "Sailing" if value == 0 else "Distressed (any nonzero state)"
	if type == 6:
		return "Disaster: " + CityMenuBar.disaster_name(1 if value == 0 else value) + (" (zero defaults to Fire)" if value == 0 else "")
	if type in [4, 7, 8, 14, 15]:
		return "Unused by this object's tick"
	if STATES.has(type):
		var mode := value & 15 if type == 1 else value
		var result: String = STATES[type].get(mode, "Unrecognized state")

		if type == 1 and (mode in [3, 4] or value > 15):
			var axis := value >> 4
			result += "; runway axis " + (EIGHT[axis] if axis < 8 else "invalid %d" % axis)

		return result

	return "Not interpreted for this type"


static func goal(record: Dictionary, city: CityState) -> String:
	var value := int(record.goal)

	match int(record.type):
		5:
			return {0: "Normal demolition / fire", 1: "Radiation", 2: "Create water", 3: "Create wind power"}.get(value, "Unknown damage mode; demolition still attempted")
		6:
			return "No spread damage" if value == 0 else "Spread damage enabled"
		16:
			if ThingData.is_record_target(value):
				return "Follow " + _target(ThingData.target_record(value), city)

			return "Fixed disaster target (%d, %d)" % [record.dx, record.dy]
		1, 2, 3, 4, 7, 8, 9, 10, 11, 12, 13, 14, 15:
			return "Unused by this object's tick"

	return "Not interpreted for this type"


static func fields(record: Dictionary, city: CityState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var type := int(record.type)

	for index in FIELDS.size():
		var key: String = FIELDS[index]
		var value := int(record.get(key, 0))
		var meaning := "Not interpreted for this object type"
		var translated := ""

		match key:
			"type":
				meaning = "Object type"
				translated = type_name(value)
			"direction":
				meaning = "Animation frame" if type == 6 else "Preserved direction field" if type in [0, 7, 8, 14] else "Grid direction (north is decreasing Y)"
				translated = direction(record)
			"state":
				meaning = "Behavior state"

				if type in [10, 11, 12, 13]:
					meaning = "Linked car record (the tail link is not followed)"
				elif type == 1:
					meaning = "Low nibble: flight mode; high nibble: runway axis for approach modes"
				elif type == 6:
					meaning = "Disaster ID if explosion spreads"
				elif type in [0, 4, 7, 8, 14, 15]:
					meaning = "Preserved state field; no behavior selected by this value"
				translated = state(record, city)
			"goal":
				meaning = "Target or damage mode" if type in [5, 6, 16] else "Preserved goal field"
				translated = goal(record, city)
			"x", "y":
				meaning = "Current grid " + key.to_upper() + " coordinate"
				translated = "Outside map" if city != null and (value < 0 or value >= city.map_size) else "Tile %d" % value
			"z":
				meaning = "Stored Z; rail rendering derives height from map terrain" if type in [10, 11, 12, 13] else "Vertical offset / height used by this object's renderer"
			"px", "py":
				if type in [10, 11, 12, 13]:
					meaning = "Next grid %s coordinate" % ("X" if key == "px" else "Y")
				elif type in [1, 2, 3, 5, 9, 15, 16]:
					meaning = "Sub-tile %s position; %d units per tile" % ["X" if key == "px" else "Y", 12 if type == 3 else 16]
			"dx", "dy":
				if type == 16:
					meaning = "Fixed-target %s coordinate (used when goal is not an object reference)" % ("X" if key == "dx" else "Y")
				elif type in [1, 2, 3]:
					meaning = "Target grid %s coordinate" % ("X" if key == "dx" else "Y")
				elif type == 5:
					meaning = "Monster upper-body pose bits; bit 7 marks a damage hit" if key == "dx" else "Monster lower-body pose bits"
				elif type in [10, 11, 12, 13] and key == "dx":
					meaning = "Rail sprite transition code (not a target coordinate)"
			"label":
				if type in [1, 2, 3, 5, 10, 11, 12, 13, 15, 16]:
					meaning = "Previous XTXT overlay restored when leaving this tile"
					translated = _overlay(value)

		result.append({"name": key, "value": str(value), "raw": "0x%02X" % value,
			"translation": translated, "detail": meaning})

	return result


# one-line cells for the debug table: translated values, then "number / hex" for the child row
static func table_cells(id: int, record: Dictionary, city: CityState) -> Dictionary:
	var by_name := {}

	for field in fields(record, city):
		by_name[field.name] = field

	var cells: Array[String] = ["Object %d" % id]
	var raw: Array[String] = ["Stored values"]
	var tips: Array[String] = ["XTHG record %d" % id]

	for key: String in COLUMNS:
		var field: Dictionary = by_name[key]
		var text: String = field.value

		if key in TRANSLATED:
			text = "Unused" if field.translation.begins_with("Unused") else field.translation

		cells.append(text)
		raw.append("%s / %s" % [field.value, field.raw])
		var tip := "%s: %s\n%s" % [key, field.detail, raw[-1]]
		tips.append(tip if field.translation.is_empty() else "%s\n%s" % [tip, field.translation])

	return {"cells": cells, "raw": raw, "tooltips": tips}


static func _target(id: int, city: CityState) -> String:
	if city == null or id < 0 or id >= city.thing_count():
		return "object %d (invalid record)" % id

	var target := city.thing(id)
	return "object %d (%s)" % [id, "empty slot" if target.type == 0 else type_name(target.type)]


static func _overlay(value: int) -> String:
	if value == 0:
		return "No overlay"
	if OverlayData.is_facility(value):
		return "MicroSim record %d" % OverlayData.facility_record(value)
	if OverlayData.is_thing(value):
		return "Object record %d" % OverlayData.thing_record(value)
	if OverlayData.is_sign(value):
		return "Sign / label %d" % value

	return "Special map marker"
