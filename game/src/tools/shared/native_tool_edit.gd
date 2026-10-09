class_name NativeToolEdit
extends RefCounted
## Runs a player tool command in the native simulation library. See
## native/core/sim/src/sim/tools/commands. The command edits the city chunks
## and returns its result class; this adds the payloads before and after the
## edit, which undo exchanges.


# `payload_ids` are the chunks that the command checks, in commit order. The
# result keeps each one; `changed_ids` lists the ones that changed
static func run(
	operation: String,
	city: CityState,
	args: Dictionary,
	payload_ids: PackedStringArray,
	random: SimRandom = null,
	lfsr_random: SimLfsrRandom = null,
) -> Variant:
	var before: Dictionary[String, PackedByteArray] = {}

	for chunk_id in payload_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk != null:
			before[chunk_id] = chunk.decoded_payload

	var random_state := random.state if random != null else 0
	var lfsr_state := lfsr_random.state if lfsr_random != null else 0
	var response := NativeSimulationBridge.run(operation, city, random, lfsr_random, null, args, payload_ids)
	var result: Variant = response.result

	# a chunk that the document rejects undoes the whole edit, random draws included
	if not String(response.failed_chunk).is_empty():
		if random != null:
			random.state = random_state

		if lfsr_random != null:
			lfsr_random.state = lfsr_state

	if not (result is EditCommandResult and result.ok):
		return result

	# A changed chunk holds the written array now, so the old array is ours.
	# The new payload is a copy: later edits may change the chunk in place.
	var written: Dictionary = response.written
	var changed_ids := PackedStringArray()
	var old_payloads: Dictionary[String, PackedByteArray] = {}
	var new_payloads: Dictionary[String, PackedByteArray] = {}

	for chunk_id: String in before:
		old_payloads[chunk_id] = before[chunk_id]

		if written.has(chunk_id):
			changed_ids.append(chunk_id)
			new_payloads[chunk_id] = (written[chunk_id] as PackedByteArray).duplicate()
		else:
			new_payloads[chunk_id] = before[chunk_id]

	result.changed_ids = changed_ids
	result.old_payloads = old_payloads
	result.new_payloads = new_payloads

	return result


# Undo `command`: restore its old payloads when the city still holds the new
# ones. Returns an error, or an empty string. `noun` names the command
static func restore(city: CityState, command: EditCommandResult, noun: String) -> String:
	for chunk_id in command.changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not command.new_payloads.has(chunk_id) or chunk.decoded_payload != command.new_payloads[chunk_id]:
			return "city changed after this %s command" % noun

	if not OrderedChunkCommit.apply(city, command.changed_ids, command.old_payloads, command.new_payloads):
		return "cannot restore %s changes" % noun

	return ""


# The common undo of a command without random state
static func undo(
	city: CityState, command: EditCommandResult, command_type: String, noun: String, restored_tiles: int
) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != command_type:
		return EditCommandResult.failure("%s command is invalid" % noun)

	var error := restore(city, command, noun)

	if not error.is_empty():
		return EditCommandResult.failure(error)

	return EditCommandResult.undone(restored_tiles)


# The tool fields of a request
static func tool_args(group: int, subtool: int, free_mode := false) -> Dictionary:
	var tool := ToolCatalog.tool(group, subtool)

	return {
		"group": group,
		"subtool": subtool,
		"cost": int(tool.cost) if tool != null else 0,
		"free_mode": free_mode,
	}
