class_name TerrainStretchSession
extends RefCounted

var active := false
var point := Vector2i.ZERO
var levels := 0
var command := {}


func begin(anchor: Vector2i) -> void:
	active = true
	point = anchor
	levels = 0
	command = {}


func update(city: CityState, random: SimRandom, target_levels: int) -> Dictionary:
	if not active or target_levels == levels:
		return {}

	var before := _display_payloads(city)

	if not command.is_empty():
		var restored := TerrainCommand.undo(city, command, random)

		if not restored.ok:
			return restored

	command = {}
	levels = target_levels

	if levels != 0:
		var edited := LandscapeEditorCommand.apply(city, 0, 5, point, random, levels)

		if edited.ok:
			command = edited

	return {"ok": true, "command_type": "terrain", "old_payloads": before, "new_payloads": _display_payloads(city)}


func finish() -> Dictionary:
	var result := command
	active = false
	command = {}

	return result


static func _display_payloads(city: CityState) -> Dictionary:
	var result := {}

	for id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT"]:
		result[id] = city.document.find_chunk(id).decoded_payload.duplicate()

	return result
