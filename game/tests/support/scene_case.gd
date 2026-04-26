extends RefCounted
## Scene cases share a process, but never a scene instance.

var tree: SceneTree
var root: Window:
	get:
		return tree.root
var process_frame: Signal:
	get:
		return tree.process_frame
