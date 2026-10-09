extends SceneTree
## The TypeScript declarations of the script API, opensc2k.d.ts, have each
## member of the API objects that api.js defines, the mod object, and each
## game event type.

const API_PATH := "res://assets/scripting/api.js"
const TYPES_PATH := "res://assets/scripting/opensc2k.d.ts"
# the global of each API object -> its interface in opensc2k.d.ts
const INTERFACES := {
	"game": "Game", "game.storage": "", "city": "City", "budget": "Budget", "sim": "Sim", "tools": "Tools", "view": "View",
	"ui": "Ui", "mod": "Mod", "mod.files": "ModFiles",
}

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var folder := OS.get_user_data_dir().path_join("scripting_types_test")
	DirAccess.make_dir_recursive_absolute(folder)
	var runtime := ScriptRuntime.new()
	check(runtime.set_sandbox(folder).is_empty(), "The runtime has a mod folder")
	runtime.set_host(_host)
	var loaded := runtime.run_script(FileAccess.get_file_as_string(API_PATH), API_PATH)
	check(bool(loaded.ok), "api.js runs: %s" % loaded.error)
	var types := FileAccess.get_file_as_string(TYPES_PATH)

	for path: String in INTERFACES:
		var listed := runtime.eval_console("JSON.stringify(Object.getOwnPropertyNames(%s))" % path)
		var members: Variant = JSON.parse_string(JSON.parse_string(str(listed.text)) if bool(listed.ok) else "[]")
		check(members is Array and not members.is_empty(), "%s has members" % path)
		var block := _interface(types, INTERFACES[path]) if not INTERFACES[path].is_empty() else _storage_block(types)

		for member: String in members:
			check(_declares(block, member), "opensc2k.d.ts declares %s.%s" % [path, member])

	var events := _interface(types, "GameEventMap")

	for type: String in ApplicationScripting.EVENTS:
		check(events.contains("'%s':" % type) or events.contains("\n  %s:" % type), "opensc2k.d.ts declares the event %s" % type)

	for name in ["game", "city", "budget", "sim", "tools", "view", "ui", "mod"]:
		check(types.contains("declare const %s: " % name), "opensc2k.d.ts declares the global %s" % name)

	runtime.close()
	DirAccess.remove_absolute(folder)
	print("Script types: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _host(name: String, _arguments: Array) -> Variant:
	if name == "mod.info":
		return {"id": "types", "name": "Types", "version": "1"}

	return null


# the text of an interface, from its name to the closing brace at line start
func _interface(types: String, name: String) -> String:
	var start := types.find("interface %s " % name)

	if start < 0:
		return ""

	return types.substr(start, types.find("\n}", start) - start)


func _storage_block(types: String) -> String:
	var game := _interface(types, "Game")
	var start := game.find("readonly storage: {")

	return game.substr(start, game.find("\n  };", start) - start) if start >= 0 else ""


static func _declares(block: String, member: String) -> bool:
	for form in ["%s(", "%s:", "%s<", "%s?:"]:
		if block.contains(" " + form % member):
			return true

	return false
