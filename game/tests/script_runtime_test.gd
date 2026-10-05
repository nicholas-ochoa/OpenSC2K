extends SceneTree
## The native ScriptRuntime: console input, script files, host functions in
## both directions, events, script commands, the time limit, and the tool
## selection paths of the script API.

var checks := 0
var failures := 0
var host_calls: Array = []
var runtime: ScriptRuntime


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	runtime = ScriptRuntime.new()
	check(runtime.is_ready() and not ScriptRuntime.engine_version().is_empty(), "The runtime starts")
	runtime.set_host(_host)
	_check_console()
	_check_values()
	_check_errors()
	_check_events()
	_check_commands_and_files()
	_check_time_limit()
	_check_selection_paths()
	_check_console_commands()
	runtime.close()
	runtime = null
	print("Script runtime: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


# the host of the test: echo returns its arguments, point returns a Vector2i,
# fail throws an Error
func _host(name: String, arguments: Array) -> Variant:
	host_calls.append([name, arguments])

	match name:
		"echo":
			return arguments
		"point":
			return {"tile": Vector2i(3, -4), "ids": PackedInt32Array([7, 8]), "name": &"Road"}
		"typed":
			var names: Array[String] = ["city", "traffic"]
			var counts: Dictionary[String, int] = {"roads": 3}

			return {"names": names, "counts": counts}
		"fail":
			runtime.throw_error("the city refused")

	return null


func _check_console() -> void:
	var sum := runtime.eval_console("1 + 2")
	check(bool(sum.ok) and sum.text == "3", "Console input shows its value")
	check(runtime.eval_console("var funds = 500").text == "", "An undefined result shows nothing")
	check(runtime.eval_console("funds * 2").text == "1000", "Declarations stay for the next input")
	check(runtime.eval_console("await new Promise((done) => done('later'))").text == "\"later\"", "Console input can await")


func _check_values() -> void:
	var echoed := runtime.eval_console("JSON.stringify(__runtime.host('echo', 1, 2.5, 'a', [true, null], { x: 1 }))")
	check(echoed.text == "\"[1,2.5,\\\"a\\\",[true,null],{\\\"x\\\":1}]\"", "Script values reach the host and return: " + echoed.text)
	var received: Array = host_calls[-1][1]
	check(received.size() == 5 and typeof(received[0]) == TYPE_INT and typeof(received[1]) == TYPE_FLOAT,
		"Whole numbers arrive as int and other numbers as float")
	check(received[4] is Dictionary and int(received[4].x) == 1, "Objects arrive as dictionaries")
	var point := runtime.eval_console("const p = __runtime.host('point'); [p.tile.x, p.tile.y, p.ids[1], p.name].join()")
	check(point.text == "\"3,-4,8,Road\"", "Vectors, packed arrays and names become script values: " + point.text)
	var typed := runtime.eval_console("const t = __runtime.host('typed'); t.names.join() + ' ' + t.counts.roads")
	check(typed.text == "\"city,traffic 3\"", "Typed arrays and dictionaries become script values: " + str(typed))
	var called := runtime.call_function("Math.max", [4, 9, 2])
	check(bool(called.ok) and int(called.value) == 9, "The game can call a script function")


func _check_errors() -> void:
	var caught := runtime.eval_console("try { __runtime.host('fail') } catch (error) { error.message }")
	check(caught.text == "\"the city refused\"", "throw_error throws in the script")
	var thrown := runtime.eval_console("null.city")
	check(not bool(thrown.ok) and str(thrown.error).begins_with("TypeError"), "A script error returns its type and message")
	var missing := runtime.call_function("noSuchFunction", [])
	check(not bool(missing.ok) and str(missing.error).contains("not a function"), "A missing function is an error")


func _check_events() -> void:
	runtime.eval_console("__runtime.events.on('tool.beforeApply', (event) => { if (event.tool.name === 'Bulldozer') event.cancel() })")
	check(_host_names().has("listeners"), "The host learns that a script listens")
	var cancelled := runtime.dispatch("tool.beforeApply", {"tool": {"name": "Bulldozer"}, "start": Vector2i(1, 2)}, true)
	check(bool(cancelled.cancelled) and cancelled.start.x == 1, "A listener cancels a cancelable event")
	var allowed := runtime.dispatch("tool.beforeApply", {"tool": {"name": "Road"}}, true)
	check(not bool(allowed.cancelled), "Other events are not cancelled")
	var fixed := runtime.dispatch("tool.beforeApply", {"tool": {"name": "Bulldozer"}}, false)
	check(not bool(fixed.cancelled), "A listener cannot cancel an event that is not cancelable")


func _check_commands_and_files() -> void:
	var folder := OS.get_temp_dir().path_join("opensc2k_script_runtime_test_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder.path_join("lib"))
	_write(folder.path_join("lib/format.js"), "export const money = (value) => '$' + value;")
	var main := folder.path_join("main.js")
	_write(main, "import { money } from './lib/format.js';\n__runtime.command('price', 'Show a price.', (value) => money(value));")
	var ran := runtime.run_script(FileAccess.get_file_as_string(main), main)
	check(bool(ran.ok), "A module imports a file by relative path: " + str(ran.error))
	check(_host_names().has("command"), "A script command registers with the host")
	var price := runtime.run_command("price", PackedStringArray(["25"]))
	check(bool(price.ok) and price.text == "$25", "The game runs a script command")
	var broken := runtime.run_script("function (", folder.path_join("broken.js"))
	check(not bool(broken.ok) and str(broken.error).contains("broken.js"), "A script error names the file")

	for file in ["lib/format.js", "main.js"]:
		DirAccess.remove_absolute(folder.path_join(file))

	DirAccess.remove_absolute(folder.path_join("lib"))
	DirAccess.remove_absolute(folder)


func _check_time_limit() -> void:
	runtime.set_time_limit_msec(50)
	var started := Time.get_ticks_msec()
	var endless := runtime.eval_console("for (;;) {}")
	check(not bool(endless.ok) and str(endless.error).contains("interrupted"), "The time limit stops an endless loop")
	check(Time.get_ticks_msec() - started < 2000, "The loop stops near the limit")
	runtime.set_time_limit_msec(5000)
	check(runtime.eval_console("6 * 7").text == "42", "The runtime runs after an interruption")


func _check_selection_paths() -> void:
	var line := ApplicationScriptingApi.selection_path("path", Vector2i(2, 2), Vector2i(5, 3))
	var expected: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3), Vector2i(5, 3)]
	check(line == expected,
		"A path tool follows the map selection path")
	check(ApplicationScriptingApi.selection_path("rectangle", Vector2i(3, 3), Vector2i(2, 2)).size() == 4, "A rectangle tool selects the area")
	var last: Array[Vector2i] = [Vector2i(4, 4)]
	check(ApplicationScriptingApi.selection_path("point", Vector2i(1, 1), Vector2i(4, 4)) == last, "A point tool selects the last tile")


func _check_console_commands() -> void:
	var commands := ConsoleCommands.new()
	commands.register("mod", "A script command.", func(_words: PackedStringArray) -> String: return "")
	check(commands.has("MOD"), "A command name is not case sensitive")
	commands.unregister("mod")
	check(not commands.has("mod"), "A script command can be removed")


func _host_names() -> Array:
	return host_calls.map(func(call: Array) -> String: return call[0])


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
