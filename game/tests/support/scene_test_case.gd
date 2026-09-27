extends Node
## A scene test that completes without stopping the shared SceneTree.

var completed := false
var exit_code := 0
var root: Window:
	get:
		return get_tree().root
var process_frame: Signal:
	get:
		return get_tree().process_frame


func quit(code := 0) -> void:
	exit_code = code
	completed = true
