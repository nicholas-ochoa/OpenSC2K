class_name TerrainStretchSession
extends RefCounted

var active := false
var point := Vector2i.ZERO
var levels := 0
var command: TerrainEditResult


func begin(anchor: Vector2i) -> void:
	active = true
	point = anchor
	levels = 0
	command = null


# null when the height is unchanged. otherwise the result carries the display
# payloads before and after, or the error of a failed restore
func update(city: CityState, random: SimRandom, target_levels: int) -> EditCommandResult:
	if not active or target_levels == levels:
		return null

	var before := _display_payloads(city)

	if command != null:
		var restored := TerrainCommand.undo(city, command, random)

		if not restored.ok:
			return restored

	command = null
	levels = target_levels

	if levels != 0:
		var edited := LandscapeEditorCommand.apply(city, 0, 5, point, random, levels)

		if edited.ok:
			command = edited

	var display := TerrainEditResult.new()
	display.ok = true
	display.command_type = "terrain"
	display.old_payloads = before
	display.new_payloads = _display_payloads(city)

	return display


# the committed edit, or null when nothing changed
func finish() -> TerrainEditResult:
	var result := command
	active = false
	command = null

	return result


static func _display_payloads(city: CityState) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

	for id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT"]:
		result[id] = city.document.find_chunk(id).decoded_payload.duplicate()

	return result
