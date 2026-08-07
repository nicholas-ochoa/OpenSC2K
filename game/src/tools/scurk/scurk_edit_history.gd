class_name ScurkEditHistory
extends RefCounted

const ScurkPlace = preload("res://src/tools/scurk/scurk_place_command.gd")

var undo_stack: Array[EditCommandResult] = []
var redo_stack: Array[EditCommandResult] = []


func clear() -> void:
	undo_stack.clear()
	redo_stack.clear()


func record(command: EditCommandResult, tool_name: String) -> void:
	command.scurk_place_history = true
	command.scurk_tool_name = tool_name

	# a family that still returns a dictionary reads these keys from it
	if not command.extra.is_empty():
		command.extra["scurk_place_history"] = true
		command.extra["scurk_tool_name"] = tool_name

	undo_stack.append(command)
	redo_stack.clear()


func can_undo() -> bool:
	return not undo_stack.is_empty()


func can_redo() -> bool:
	return not redo_stack.is_empty()


# null when nothing is left to undo
func current_command() -> EditCommandResult:
	return undo_stack[-1] if can_undo() else null


# on success, the undone edit moves to the top of `redo_stack`
func undo(city: CityState, random: SimRandom) -> EditCommandResult:
	if not can_undo():
		return EditCommandResult.failure("No SCURK edit is available to undo.")

	var command := undo_stack[-1]
	var result := ScurkPlace.undo(city, command, random)

	if not result.ok:
		return result

	undo_stack.pop_back()
	redo_stack.append(command)

	return result


# on success, the redone edit moves to the top of `undo_stack`
func redo(city: CityState, random: SimRandom) -> EditCommandResult:
	if not can_redo():
		return EditCommandResult.failure("No SCURK edit is available to redo.")

	var command := redo_stack[-1]
	var result := ScurkPlace.redo(city, command, random)

	if not result.ok:
		return result

	redo_stack.pop_back()
	undo_stack.append(command)

	return result
