class_name ZoneCommand
extends RefCounted
# Zoning and dezoning rectangles. The native simulation library prices and
# paints the rectangle; see native/core/sim/src/sim/tools/commands/zone.rs.

const GROUP_PORTS := CityToolIds.Group.PORTS
const GROUP_BULLDOZER := CityToolIds.Group.BULLDOZER
const SUBTOOL_DEZONE := CityToolIds.Bulldozer.DEZONE
const GROUP_RESIDENTIAL := CityToolIds.Group.RESIDENTIAL
const GROUP_COMMERCIAL := CityToolIds.Group.COMMERCIAL
const GROUP_INDUSTRIAL := CityToolIds.Group.INDUSTRIAL
# the chunks that a zone edit changes, in commit order
const PAYLOAD_IDS: PackedStringArray = ["XZON", "XBLD", "MISC"]
const ZONE_TYPES := {
	GROUP_PORTS: [9, 8],
	GROUP_RESIDENTIAL: [1, 2],
	GROUP_COMMERCIAL: [3, 4],
	GROUP_INDUSTRIAL: [5, 6],
}


static func apply_rectangle(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	dragged := true,
	free_mode := false,
	zone_type_override := -1
) -> ZoneEditResult:
	if city == null or not city.is_valid():
		return ZoneEditResult.rejected("city is invalid")

	var args := _args(group_index, subtool_index, start, finish, dragged, free_mode, zone_type_override)

	return NativeToolEdit.run("tool.zone", city, args, PAYLOAD_IDS)


static func preview_rectangle(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	finish: Vector2i,
	dragged := true,
	free_mode := false,
	zone_type_override := -1
) -> Preview:
	if city == null or not city.is_valid():
		return Preview.failure("city is invalid")

	var args := _args(group_index, subtool_index, start, finish, dragged, free_mode, zone_type_override)

	return NativeSimulationBridge.run("tool.zone_preview", city, null, null, null, args).result


static func _args(
	group_index: int, subtool_index: int, start: Vector2i, finish: Vector2i, dragged: bool, free_mode: bool, zone_type_override: int
) -> Dictionary:
	var args := NativeToolEdit.tool_args(group_index, subtool_index, free_mode)
	args.start = start
	args.finish = finish
	args.dragged = dragged
	args.tool_zone = _zone_type_for_tool(group_index, subtool_index)
	args.has_tool = ToolCatalog.tool(group_index, subtool_index) != null
	args.zone_type_override = zone_type_override

	return args


# undo also rejects a command of another family
static func undo(city: CityState, command: ZoneEditResult) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok:
		return EditCommandResult.failure("zone command is invalid")

	var indices := command.tile_indices
	var previous := command.previous_values
	var expected := command.new_values
	var previous_buildings := command.previous_buildings
	var expected_buildings := command.new_buildings

	if (
		indices.size() != previous.size()
		or indices.size() != expected.size()
		or indices.size() != previous_buildings.size()
		or indices.size() != expected_buildings.size()
	):
		return EditCommandResult.failure("zone undo data has the wrong size")

	for position in indices.size():
		if (
			city.zones[indices[position]] != expected[position]
			or city.buildings[indices[position]] != expected_buildings[position]
		):
			return EditCommandResult.failure("city changed after this zone command")

	var current := city.zones.duplicate()
	var current_buildings := city.buildings.duplicate()
	var restored := _restore_values(current, indices, previous)
	var restored_buildings := _restore_values(current_buildings, indices, previous_buildings)
	var current_funds := city.funds()

	if not city.replace_zones(restored):
		return EditCommandResult.failure("cannot restore XZON data")

	if not city.replace_buildings(restored_buildings):
		city.replace_zones(current)

		return EditCommandResult.failure("cannot restore XBLD data")

	if not city.set_funds(command.previous_funds):
		city.replace_zones(current)
		city.replace_buildings(current_buildings)
		city.set_funds(current_funds)

		return EditCommandResult.failure("cannot restore city funds")

	if CityTileCounts.exact(city):
		CityTileCounts.recount(city)

	return EditCommandResult.undone(indices.size())


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return _zone_type_for_tool(group_index, subtool_index) >= 0


static func _zone_type_for_tool(group_index: int, subtool_index: int) -> int:
	if group_index == GROUP_BULLDOZER and subtool_index == SUBTOOL_DEZONE:
		return 0

	if not ZONE_TYPES.has(group_index):
		return -1

	var zone_types: Array = ZONE_TYPES[group_index]

	if subtool_index < 0 or subtool_index >= zone_types.size():
		return -1

	return zone_types[subtool_index]


static func _restore_values(
	data: PackedByteArray, indices: PackedInt32Array, values: PackedByteArray
) -> PackedByteArray:
	var result := data.duplicate()

	for position in indices.size():
		result[indices[position]] = values[position]

	return result


class Preview extends RefCounted:
	var ok := false
	var error := ""
	var zone_type := 0
	var dragged := false
	var charged_tiles := 0
	var changed_tiles := 0
	var terrain_surcharges := 0
	var cost := 0
	var listed_cost := 0
	var affordable := false
	var free_mode := false

	static func failure(message: String) -> Preview:
		var result := Preview.new()
		result.error = message

		return result
