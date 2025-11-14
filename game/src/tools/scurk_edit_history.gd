class_name ScurkEditHistory
extends RefCounted

const ScurkPlace = preload("res://src/tools/scurk_place_command.gd")

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []


func clear() -> void:
	undo_stack.clear()
	redo_stack.clear()


func record(command: Dictionary, tool_name: String) -> void:
	command["scurk_place_history"] = true
	command["scurk_tool_name"] = tool_name
	undo_stack.append(command)
	redo_stack.clear()


func can_undo() -> bool:
	return not undo_stack.is_empty()


func can_redo() -> bool:
	return not redo_stack.is_empty()


func current_command() -> Dictionary:
	return undo_stack[-1] if can_undo() else {}


func undo(city: CityState, random: SimRandom) -> Dictionary:
	if not can_undo():
		return {"ok": false, "error": "No SCURK edit is available to undo."}
	var command: Dictionary = undo_stack[-1]
	var result := ScurkPlace.undo(city, command, random)
	if not result.get("ok", false):
		return result
	undo_stack.pop_back()
	redo_stack.append(command)
	result["command"] = command
	result["current_command"] = current_command()
	return result


func redo(city: CityState, random: SimRandom) -> Dictionary:
	if not can_redo():
		return {"ok": false, "error": "No SCURK edit is available to redo."}
	var command: Dictionary = redo_stack[-1]
	var result := ScurkPlace.redo(city, command, random)
	if not result.get("ok", false):
		return result
	redo_stack.pop_back()
	undo_stack.append(command)
	result["command"] = command
	result["current_command"] = command
	return result
