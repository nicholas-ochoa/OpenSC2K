class_name ScriptContext
extends RefCounted
## One script runtime and what the game knows about it: the console runtime,
## or the runtime of one mod. Runtimes share no JavaScript values. A mod
## reaches the other mods only through events, which the game copies.

const CONSOLE_ID := "console"

# "console", or the id of the mod
var id := CONSOLE_ID
# null for the console runtime
var manifest: ModManifest
var runtime: ScriptRuntime
var storage: ScriptStorage
# event type -> number of listeners
var listeners: Dictionary[String, int] = {}
var timers_active := false
# the console commands that the scripts of this runtime registered
var commands: PackedStringArray = []
# why the runtime could not start, or an empty text
var error := ""


func _init(context_id: String, mod_manifest: ModManifest, script_runtime: ScriptRuntime, values: ScriptStorage) -> void:
	id = context_id
	manifest = mod_manifest
	runtime = script_runtime
	storage = values


func is_mod() -> bool:
	return manifest != null


## True when a script of this runtime listens to the event type, or to all events.
func listens(type: String) -> bool:
	return listeners.has(type) or listeners.has("*")


## The label of console output: "[id] " for a mod.
func prefix() -> String:
	return "[%s] " % id if is_mod() else ""
