class_name DispatchCommand
extends RefCounted
## Emergency dispatch: police, fire, and military units. The native simulation
## library places and recalls the units; see
## native/core/sim/src/sim/tools/commands/dispatch.rs.

const GROUP_DISPATCH := CityToolIds.Group.DISPATCH
const NO_CAPACITY := Vector3i(-1, -1, -1)
const PAYLOAD_IDS: PackedStringArray = ["XTHG", "XTXT"]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_DISPATCH and subtool_index >= CityToolIds.Dispatch.POLICE and subtool_index < CityToolIds.Dispatch.RECALL


# the units of each type: one for each eight station tiles, and the units of
# the military base. a city without any can still send one military unit
static func availability(city: CityState) -> Availability:
	if city == null or not city.is_valid():
		return Availability.failure("city is invalid")

	return NativeSimulationBridge.run("tool.dispatch_availability", city, null, null, null).result


# the disaster-mode start, as SIMCITY.EXE 0x0044f910: fix the unit counts for
# the disaster and remove every dispatched unit from the map
static func begin_disaster(city: CityState) -> Availability:
	if city == null or not city.is_valid():
		return Availability.failure("city is invalid")

	return NativeSimulationBridge.run("tool.dispatch_begin_disaster", city, null, null, null, {}, PAYLOAD_IDS).result


# one click of a dispatch tool, as SIMCITY.EXE 0x0044fb50 (police), 0x0044fd60
# (fire), and 0x0044ff70 (military). each type cycles its own slots 1 to N.
# `slot_points` holds the tile of each slot. `capacity` holds the police, fire,
# and military counts that the disaster start fixed. a negative count uses the
# live count
static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	target: Vector2i,
	cycle_index: int = 0,
	slot_points: Dictionary = {},
	capacity := NO_CAPACITY
) -> DispatchEditResult:
	if city == null or not city.is_valid():
		return DispatchEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return DispatchEditResult.rejected("tool is not an emergency dispatch tool")

	var args := {
		"subtool": subtool_index, "target": target, "cycle_index": cycle_index, "slot_points": slot_points,
		"capacity": PackedInt32Array([capacity.x, capacity.y, capacity.z]),
	}

	return NativeSimulationBridge.run("tool.dispatch", city, null, null, null, args, PAYLOAD_IDS).result


static func recall_all(city: CityState) -> DispatchEditResult:
	if city == null or not city.is_valid():
		return DispatchEditResult.rejected("city is invalid")

	return NativeSimulationBridge.run("tool.dispatch_recall", city, null, null, null, {}, PAYLOAD_IDS).result


static func undo(city: CityState, command: DispatchEditResult) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "dispatch":
		return EditCommandResult.failure("dispatch command is invalid")

	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")

	if thing_chunk == null or text_chunk == null:
		return EditCommandResult.failure("dispatch chunks are missing")

	if thing_chunk.decoded_payload != command.new_things:
		return EditCommandResult.failure("moving things changed after this dispatch command")

	if text_chunk.decoded_payload != command.new_text:
		return EditCommandResult.failure("text overlays changed after this dispatch command")

	if not thing_chunk.set_decoded_payload(command.old_things):
		return EditCommandResult.failure("cannot restore moving things")

	if not text_chunk.set_decoded_payload(command.old_text):
		thing_chunk.set_decoded_payload(command.new_things)

		return EditCommandResult.failure("cannot restore text overlays")

	city.resync_mirrors(["XTXT"])

	return EditCommandResult.undone(0)


class Availability extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var police: int = 0
	var fire: int = 0
	var military: int = 0
	var base_type: int = 0

	func counts() -> Vector3i:
		return Vector3i(police, fire, military)

	static func failure(message: String) -> Availability:
		var result := Availability.new()
		result.error = message

		return result
