class_name DispatchEditResult
extends EditCommandResult
# emergency unit dispatch, or recall of every dispatched unit. undo restores
# the xthg and xtxt payloads

var thing_type := 0
var thing_index := -1
var target := Vector2i(-1, -1)
var available := 0
var slot_index := 0
var reset_existing := false
var old_things := PackedByteArray()
var new_things := PackedByteArray()
var old_text := PackedByteArray()
var new_text := PackedByteArray()
# dispatch tool cycle state that the application restores on undo
var dispatch_cycles_before := PackedInt32Array()
var dispatch_cycles_after := PackedInt32Array()
var dispatch_initialized_before := false


static func rejected(message: String) -> DispatchEditResult:
	var result := DispatchEditResult.new()
	result.error = message

	return result
