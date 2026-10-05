class_name ApplicationScripting
extends RefCounted
## The JavaScript runtimes of mods and developer scripts: QuickJS-ng in the
## native scripting library. Console input and script files run in the
## console runtime, which starts at its first use. Each mod runs in its own
## runtime (ApplicationMods), and reaches the other runtimes only through
## events. The game sends an event to a runtime only while a script of it
## listens to the type. See docs/scripting.md and docs/mods.md.

@warning_ignore_start("integer_division")

const API_PATH := "res://assets/scripting/api.js"
# a relative path of the run command starts in this folder of the user data
const SCRIPTS_FOLDER := "scripts"
# the game.storage file of the console scripts, in the user data folder
const STORAGE_FILE := "scripts/storage.json"
# the port of the DevTools inspector, as the --inspect option of Node.js uses
const INSPECTOR_PORT := 9229
const INSPECTOR_OPTION := "--inspect"
# the game console lines that a new DevTools window receives
const INSPECTOR_HISTORY := 200
# a listener can send an event, whose listener can send another one. They
# nest this deep at most
const MAX_EMIT_DEPTH := 16
# the events that the game sends: type -> description. "*" listens to all
const EVENTS := {
	"city.opened": "A city opened: { name, size, date }.",
	"city.closed": "The city closed.",
	"city.saved": "The city was saved: { path }.",
	"city.renamed": "The city has a new name: { name }.",
	"budget.changed": "The taxes, the funding or the automatic budget changed: { taxes, funding, autoBudget, bonds }.",
	"sim.speed": "The simulation speed changed: { speed }.",
	"sim.day": "A simulation day ended: { year, month, day, age }.",
	"sim.month": "A new month started: { year, month }.",
	"sim.year": "A new year started: { year }.",
	"disaster.beforeStart": "A menu or a script starts a disaster: { id, name, x, y }. Cancelable.",
	"disaster.started": "A disaster started: { id, name }.",
	"disaster.ended": "The disaster ended: { id, name }.",
	"news": "The simulation sent a news story: { type, argument }.",
	"notice": "The simulation showed a notice: { id }.",
	"budget.prompt": "The yearly budget opens.",
	"military.proposal": "The military asks for a base.",
	"game.over": "The game ended, or the scenario was won: { type, funds }.",
	"tool.selected": "A tool was selected: { tool }.",
	"tool.beforeApply": "A tool is about to change the map: { tool, start, finish, dragged, tiles }. Cancelable.",
	"tool.applied": "A tool was used: { tool, start, finish, changed, command, cost, message }.",
	"tool.undone": "The last edit was undone: { command }.",
	"view.mode": "The view changed: { mode }.",
	"frame": "A frame started: { delta } in seconds. Timers are better for most work.",
	"mod.loaded": "A mod started: { id, name, version }.",
	"mod.unloaded": "A mod stopped: { id }.",
}

var app: CityApplication
var api: ApplicationScriptingApi
var mods: ApplicationMods
# the runtime of console input and script files. null until the first use,
# and after reset
var console: ScriptContext
var runtime: ScriptRuntime:
	get:
		return console.runtime if console != null else null
var last_script_path := ""
var _handlers: Dictionary[String, Callable] = {}
var _commands: ConsoleCommands
# the active disaster at the last check, for the started and ended events
var _disaster := 0
var _file_dialog: FileDialog
# the port of the inspector that the player started, or 0 when it is off
var _inspector_port := 0
# the newest game console entry that DevTools received, and the entries that
# scripts wrote. DevTools receives script output from the script runtime itself
var _forwarded_serial := 0
var _inspector_was_connected := false
var _script_serials: Dictionary[int, bool] = {}
# mod id -> the port of its inspector. A reload of the mod keeps the port
var _mod_inspector_ports: Dictionary[String, int] = {}
# the events from scripts that run now, one inside the other
var _emit_depth := 0


func _init(application: CityApplication) -> void:
	app = application
	api = ApplicationScriptingApi.new(application)
	mods = ApplicationMods.new(self)
	_handlers = api.handlers()


static func console_storage_path() -> String:
	return AppPaths.path(STORAGE_FILE)


## Adds the script commands to the console, and sends the other input to
## scripts. The console keeps method Callables, which do not keep this object.
func attach_console(commands: ConsoleCommands) -> void:
	_commands = commands
	commands.evaluator = evaluate_console
	commands.register("run", "Run a JavaScript file: run <path>. A relative path starts in the scripts folder.", _run_command_file)
	commands.register("reset", "Stop all scripts, start a new console runtime and load the mods again.", _reset_command)
	commands.register("scripts", "Show the script runtimes: listeners, timers and memory.", _status_command)
	commands.register("inspect", "Connect Chrome DevTools to scripts: inspect [port], inspect <mod> [port], or inspect [mod] off.",
		_inspect_command)
	commands.register("mods", "Show the mods: mods, mods enable <id>, mods disable <id>, mods reload.", mods.command)


func _run_command_file(words: PackedStringArray) -> String:
	if words.is_empty():
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "Name a script file: run <path>.")

		return ""

	run_file(script_path(" ".join(words)))

	return ""


func _reset_command(_words: PackedStringArray) -> String:
	reset()

	return "The scripts stopped, and the mods loaded again. The next console script starts a new runtime."


func _status_command(_words: PackedStringArray) -> String:
	return status_text()


func _inspect_command(words: PackedStringArray) -> String:
	if not words.is_empty() and mods.context(words[0].to_lower()) != null:
		return _inspect_mod_command(words[0].to_lower(), words.slice(1))

	if not words.is_empty() and words[0].to_lower() == "off":
		stop_inspector()

		return "The script inspector stopped."

	var port := INSPECTOR_PORT

	if not words.is_empty():
		var port_error := _port_error(words[0])

		if not port_error.is_empty():
			ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, port_error)

			return ""

		port = int(words[0])

	var error := start_inspector(port)

	if not error.is_empty():
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, error)

		return ""

	return inspector_text()


# inspect <mod> [port], or inspect <mod> off
func _inspect_mod_command(id: String, words: PackedStringArray) -> String:
	if not words.is_empty() and words[0].to_lower() == "off":
		stop_mod_inspector(id)

		return "The script inspector of the mod %s stopped." % id

	var port: int = _mod_inspector_ports.get(id, 0)

	if not words.is_empty():
		var port_error := _port_error(words[0])

		if not port_error.is_empty():
			ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, port_error)

			return ""

		port = int(words[0])

	var error := start_mod_inspector(id, port)

	if not error.is_empty():
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, error)

		return ""

	return inspector_text(mods.context(id))


static func _port_error(word: String) -> String:
	if not word.is_valid_int() or int(word) < 0 or int(word) > 65535:
		return "The port must be a number from 0 to 65535."

	return ""


## Starts the console runtime and the game API. False when the runtime cannot start.
func start() -> bool:
	if console != null:
		return true

	var context := create_context(ScriptContext.CONSOLE_ID, null, ScriptStorage.new(console_storage_path()))

	if not context.error.is_empty():
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, context.error)

		return false

	console = context

	if _inspector_port > 0:
		_listen(_inspector_port)

	return true


## A new runtime with the game API. A mod runtime uses files and modules
## only in the mod folder. When the runtime cannot start, `error` of the
## context tells why.
func create_context(id: String, manifest: ModManifest, storage: ScriptStorage) -> ScriptContext:
	if contexts().is_empty():
		_disaster = _active_disaster()

	var created := ScriptRuntime.new()
	var context := ScriptContext.new(id, manifest, created, storage)

	if not created.is_ready():
		context.error = "The script runtime cannot start: %s" % created.get_error()

		return context

	if manifest != null:
		var sandbox_error := created.set_sandbox(manifest.folder)

		if not sandbox_error.is_empty():
			context.error = sandbox_error

			return context

	created.set_host(_host.bind(context))
	var result := created.run_script(FileAccess.get_file_as_string(API_PATH), API_PATH)

	if not bool(result.ok):
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "The game API of scripts failed: %s" % result.error)

	if manifest != null and _mod_inspector_ports.has(id):
		_listen_context(context, _mod_inspector_ports[id], "OpenSC2K mod %s" % manifest.name)

	return context


## Stops the scripts of a runtime: its listeners, timers and console commands.
func close_context(context: ScriptContext) -> void:
	if context.runtime != null:
		context.runtime.close()

	if _commands != null:
		for name in context.commands:
			_commands.unregister(name)

	context.commands.clear()
	context.listeners.clear()
	context.timers_active = false
	context.runtime = null


## The runtimes that run now: the console runtime, then the mods in load order.
func contexts() -> Array[ScriptContext]:
	var result: Array[ScriptContext] = []

	if console != null:
		result.append(console)

	result.append_array(mods.contexts())

	return result


func is_running() -> bool:
	return console != null


## Stops all scripts: their listeners, timers and console commands. The
## mods load again from their folders.
func reset() -> void:
	if console != null:
		close_context(console)

	console = null
	_inspector_was_connected = false
	mods.reload()

	# DevTools can connect again to the new runtime at the same address
	if _inspector_port > 0:
		start()


## Starts the DevTools server of scripts on 127.0.0.1. Port 0 selects a free
## port. Returns an empty text, or why it cannot start.
func start_inspector(port := INSPECTOR_PORT) -> String:
	if runtime == null:
		_inspector_port = maxi(port, 1)

		if not start():
			_inspector_port = 0

			return "The script runtime cannot start."

	var error := _listen(port)

	if error.is_empty():
		ConsoleLog.append(ConsoleLog.Level.RESULT, inspector_text())

	return error


func _listen(port: int) -> String:
	var error := _listen_context(console, port, "OpenSC2K %s" % ProjectSettings.get_setting("application/config/version", ""))
	_inspector_port = runtime.inspector_port() if error.is_empty() else 0

	return error


func _listen_context(context: ScriptContext, port: int, title: String) -> String:
	return context.runtime.inspector_start(port, title)


## Starts the DevTools server of a mod on 127.0.0.1. Port 0 selects a free
## port. Returns an empty text, or why it cannot start.
func start_mod_inspector(id: String, port: int) -> String:
	var context := mods.context(id)

	if context == null:
		return "No mod with the id %s runs now." % id

	var error := _listen_context(context, port, "OpenSC2K mod %s" % context.manifest.name)

	if error.is_empty():
		_mod_inspector_ports[id] = context.runtime.inspector_port()

	return error


func stop_mod_inspector(id: String) -> void:
	_mod_inspector_ports.erase(id)
	var context := mods.context(id)

	if context != null:
		context.runtime.inspector_stop()


func stop_inspector() -> void:
	_inspector_port = 0
	_inspector_was_connected = false

	if runtime != null:
		runtime.inspector_stop()


func inspector_running() -> bool:
	return runtime != null and runtime.inspector_port() > 0


## How to connect DevTools to the console runtime or to a mod, or that the
## inspector is off.
func inspector_text(context: ScriptContext = null) -> String:
	var target := context if context != null else console

	if target == null or target.runtime == null or target.runtime.inspector_port() <= 0:
		return "The script inspector is off. Type inspect to start it."

	var port := target.runtime.inspector_port()
	var urls := ScriptRuntime.inspector_urls(port)

	if target.is_mod():
		return ("The script inspector of the mod %s listens on %s.\nOpen %s\nor add localhost:%d to the targets of chrome://inspect.") % [
			target.id, urls[0], urls[1], port]

	return ("The script inspector listens on %s.\nIn Chrome, open chrome://inspect and select OpenSC2K under Remote Target, "
		+ "or open %s") % [urls[0], urls[1]]


## Starts the inspector when the command line has --inspect or --inspect=PORT.
func apply_command_line(arguments: PackedStringArray) -> void:
	for argument in arguments:
		if argument == INSPECTOR_OPTION:
			start_inspector(INSPECTOR_PORT)
		elif argument.begins_with(INSPECTOR_OPTION + "=") and argument.get_slice("=", 1).is_valid_int():
			start_inspector(int(argument.get_slice("=", 1)))


## Runs console input. Returns the text of the result.
func evaluate_console(source: String) -> String:
	if not start():
		return ""

	var result := runtime.eval_console(source)

	if not bool(result.ok):
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "Uncaught " + str(result.error))

		return ""

	return str(result.text)


## Runs a script file. Its listeners, timers and commands stay until a reset.
func run_file(path: String) -> bool:
	if not start():
		return false

	var source := FileAccess.get_file_as_string(path)

	if source.is_empty() and FileAccess.get_open_error() != OK:
		_report_file("Cannot read the script %s: %s." % [path, error_string(FileAccess.get_open_error())], false)

		return false

	# a module imports other files relative to this path
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	last_script_path = absolute
	var result := runtime.run_script(source, absolute)

	if not bool(result.ok):
		_report_file("The script %s stopped with an error:\n%s" % [absolute.get_file(), result.error], false)

		return false

	_report_file("Ran the script %s." % absolute.get_file(), true)

	return true


## The path of a run command: a relative path starts in the scripts folder.
static func script_path(path: String) -> String:
	if path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://"):
		return path

	return AppPaths.path(SCRIPTS_FOLDER).path_join(path)


func open_run_dialog() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialogFactory.script_open()
		_file_dialog.title = "Run Script File"
		_file_dialog.file_selected.connect(_run_selected_file)
		app.add_child(_file_dialog)

	var folder := last_script_path.get_base_dir() if not last_script_path.is_empty() else AppPaths.path(SCRIPTS_FOLDER)
	DirAccess.make_dir_recursive_absolute(folder)
	_file_dialog.current_dir = folder
	_file_dialog.popup_centered_ratio(0.7)


func _run_selected_file(path: String) -> void:
	run_file(path)


func status_text() -> String:
	var lines := PackedStringArray(["QuickJS-ng %s." % ScriptRuntime.engine_version()])

	if console == null:
		lines.append("Console: not running. Console input or a script file starts it.")

	for context in contexts():
		lines.append(_context_status(context))

	return "\n".join(lines)


func _context_status(context: ScriptContext) -> String:
	var memory := context.runtime.memory_usage()
	var types := PackedStringArray()

	for type in context.listeners:
		types.append("%s (%d)" % [type, context.listeners[type]])

	return "%s: memory %d KiB of %d MiB, %d objects.\n  Listeners: %s.\n  Timers: %s. Commands: %s." % [
		"Mod " + context.id if context.is_mod() else "Console", int(memory.memory_used) / 1024,
		int(memory.memory_limit) / 1048576, int(memory.objects), ", ".join(types) if not types.is_empty() else "none",
		"waiting" if context.timers_active else "none", ", ".join(context.commands) if not context.commands.is_empty() else "none",
	]


## True when a script of a runtime listens to the event type, or to all events.
func listens(type: String) -> bool:
	for context in contexts():
		if context.listens(type):
			return true

	return false


## Sends an event to the script listeners of each runtime: the console
## runtime first, then the mods in load order. Returns the event after the
## listeners, or an empty Dictionary when no script listens. A listener sets
## `cancelled` of a cancelable event; the later runtimes see it.
func emit(type: String, detail: Dictionary = {}, cancelable := false) -> Dictionary:
	if not listens(type):
		return {}

	return _dispatch(type, detail, cancelable)


func _dispatch(type: String, detail: Dictionary, cancelable: bool) -> Dictionary:
	var event := {}
	var sent := detail

	for context in contexts():
		if context.runtime == null or not context.listens(type):
			continue

		var result := context.runtime.dispatch(type, sent, cancelable)

		if result.is_empty():
			continue

		event = result

		if cancelable and bool(result.get("cancelled", false)) and not bool(sent.get("cancelled", false)):
			sent = detail.duplicate()
			sent["cancelled"] = true

	if bool(sent.get("cancelled", false)):
		event["cancelled"] = true

	return event


# game.emit of a script: the event goes to the listeners of each runtime,
# with the id of the sender as `source`. A mod cannot send a game event
func _emit_from_script(context: ScriptContext, arguments: Array) -> Variant:
	var type := str(arguments[0]) if not arguments.is_empty() and arguments[0] != null else ""

	if type.is_empty():
		context.runtime.throw_error("The event type must be a text.")

		return null

	if context.is_mod() and (EVENTS.has(type) or type == "*"):
		context.runtime.throw_error("A mod cannot send the game event %s." % type)

		return null

	if _emit_depth >= MAX_EMIT_DEPTH:
		context.runtime.throw_error("Events from scripts nest more than %d deep: %s." % [MAX_EMIT_DEPTH, type])

		return null

	var detail: Dictionary = (arguments[1] as Dictionary).duplicate(true) if arguments.size() > 1 and arguments[1] is Dictionary else {}
	detail["source"] = context.id
	_emit_depth += 1
	_dispatch(type, detail, false)
	_emit_depth -= 1

	return null


## True when a script cancelled the event.
func cancelled(type: String, detail: Dictionary) -> bool:
	return bool(emit(type, detail, true).get("cancelled", false))


func process(delta: float) -> void:
	if listens("frame"):
		emit("frame", {"delta": delta})

	for context in contexts():
		# a timer can stop a runtime
		if context.runtime == null:
			continue

		if context.timers_active or context.runtime.has_pending_jobs():
			context.runtime.tick()

		if context.is_mod() and context.runtime != null and _mod_inspector_ports.has(context.id):
			context.runtime.inspector_poll()

	if _inspector_port > 0 and runtime != null:
		runtime.inspector_poll()
		_forward_game_log()


# sends the new game console lines to DevTools. A new DevTools window first
# receives the recent lines
func _forward_game_log() -> void:
	var connected := runtime.inspector_connected()

	if connected and not _inspector_was_connected:
		_forwarded_serial = maxi(0, ConsoleLog.latest_serial() - INSPECTOR_HISTORY)

	_inspector_was_connected = connected

	if not connected:
		_script_serials.clear()

		return

	for entry in ConsoleLog.entries_since(_forwarded_serial):
		_forwarded_serial = entry.serial

		if _script_serials.has(entry.serial) or entry.level in [ConsoleLog.Level.INPUT, ConsoleLog.Level.RESULT]:
			continue

		var level := "log"

		if entry.level == ConsoleLog.Level.WARNING:
			level = "warning"
		elif entry.level in [ConsoleLog.Level.ERROR, ConsoleLog.Level.ERROR_OUTPUT]:
			level = "error"

		runtime.inspector_log(level, entry.text)

	_script_serials.clear()


func close() -> void:
	if console != null:
		close_context(console)

	console = null
	mods.close_all()


## Sends the events of a published simulation tick.
func on_simulation_result(result: SimulationTickResult) -> void:
	if contexts().is_empty():
		return

	for day in result.day_results:
		_emit_day(day)

	for item in result.news_items:
		emit("news", {"type": item.type, "argument": item.argument})

	for id in result.notice_ids:
		emit("notice", {"id": id})

	for event in result.game_over_events:
		emit("game.over", {"type": event.type, "funds": event.funds})

	for request in result.interaction_requests:
		if request.type == "annual_budget":
			emit("budget.prompt")
		elif request.type == "military_proposal":
			emit("military.proposal")

	check_disaster()


func _emit_day(day: SimulationDayResult) -> void:
	var city := app.document_state.city

	if city == null or not (listens("sim.day") or listens("sim.month") or listens("sim.year")):
		return

	var schedule := day.schedule if day.schedule != null else SimulationClock.state_for_day(day.day)
	var year := city.founding_year() + schedule.elapsed_years

	if schedule.month_day == 0 and schedule.month == 0:
		emit("sim.year", {"year": year})

	if schedule.month_day == 0:
		emit("sim.month", {"year": year, "month": schedule.month + 1})

	emit("sim.day", {"year": year, "month": schedule.month + 1, "day": schedule.month_day + 1, "age": schedule.city_days})


## Sends disaster.started or disaster.ended when the active disaster changed.
func check_disaster() -> void:
	var active := _active_disaster()

	if contexts().is_empty() or active == _disaster:
		_disaster = active

		return

	var previous := _disaster
	_disaster = active

	if previous != 0:
		emit("disaster.ended", {"id": previous, "name": CityMenuBar.disaster_name(previous)})

	if active != 0:
		emit("disaster.started", {"id": active, "name": CityMenuBar.disaster_name(active)})


## Sends budget.changed with the budget values.
func emit_budget_changed() -> void:
	if listens("budget.changed"):
		var info: Variant = api.budget_api.handlers()["budget.info"].call([])

		if info is Dictionary:
			emit("budget.changed", info)


func on_city_opened() -> void:
	_disaster = _active_disaster()
	var city := app.document_state.city

	if city != null and listens("city.opened"):
		emit("city.opened", {"name": city.city_name(), "size": city.map_size,
			"date": {"year": city.current_year(), "month": city.current_month(), "day": city.current_day(), "age": city.age_in_days()}})


func _active_disaster() -> int:
	var engine := app.simulation_state.simulation_engine

	return engine.active_disaster_type if engine != null else 0


func _report_file(message: String, ok: bool) -> void:
	ConsoleLog.append(ConsoleLog.Level.RESULT if ok else ConsoleLog.Level.ERROR_OUTPUT, message)

	if app.status_label != null:
		app.status_label.theme_type_variation = ""
		app.status_label.text = message.get_slice("\n", 0)


# runs a host function of a script: (name, arguments) -> value. The context
# of the calling runtime is bound after the arguments
func _host(name: String, arguments: Array, context: ScriptContext) -> Variant:
	match name:
		"console":
			_console(context, str(arguments[0]), str(arguments[1]))

			return null
		"listeners":
			_count_listeners(context, str(arguments[0]), int(arguments[1]))

			return null
		"timers":
			context.timers_active = int(arguments[0]) > 0

			return null
		"command":
			_register_command(context, str(arguments[0]), str(arguments[1]))

			return null
		"emit":
			return _emit_from_script(context, arguments)
		"mod.info":
			return context.manifest.info() if context.is_mod() else null
		"game.mods":
			return mods.running_info()

	if name.begins_with("storage."):
		return _storage(context, name, arguments)

	var handler: Callable = _handlers.get(name, Callable())

	if not handler.is_valid():
		context.runtime.throw_error("The game has no function named %s." % name)

		return null

	api.take_failure()
	var value: Variant = handler.call(arguments)
	var failure := api.take_failure()

	if not failure.is_empty() and context.runtime != null:
		context.runtime.throw_error(failure)

	return value


# game.storage of a runtime. Each mod has its own values
func _storage(context: ScriptContext, name: String, arguments: Array) -> Variant:
	var key := str(ScriptingApiBase.argument(arguments, 0, ""))

	match name:
		"storage.get":
			return context.storage.get_value(key, ScriptingApiBase.argument(arguments, 1))
		"storage.set":
			var error := "A storage key cannot be empty." if key.is_empty() else context.storage.set_value(key,
				ScriptingApiBase.argument(arguments, 1))

			if not error.is_empty():
				context.runtime.throw_error(error)

				return null

			return true
		"storage.remove":
			return context.storage.remove(key)
		"storage.keys":
			return context.storage.values().keys()

	context.runtime.throw_error("The game has no function named %s." % name)

	return null


func _console(context: ScriptContext, level: String, text: String) -> void:
	var before := ConsoleLog.latest_serial()
	_write_console(level, context.prefix() + text)

	if _inspector_was_connected and context == console:
		for serial in range(before + 1, ConsoleLog.latest_serial() + 1):
			_script_serials[serial] = true


func _write_console(level: String, text: String) -> void:
	match level:
		"warn":
			ConsoleLog.append(ConsoleLog.Level.WARNING, text)
		"error":
			printerr(text)
		"result":
			ConsoleLog.append(ConsoleLog.Level.RESULT, text)
		_:
			print(text)


func _count_listeners(context: ScriptContext, type: String, count: int) -> void:
	if count > 0:
		context.listeners[type] = count
	else:
		context.listeners.erase(type)


func _register_command(context: ScriptContext, name: String, description: String) -> void:
	if _commands == null:
		return

	if _commands.has(name) and not context.commands.has(name):
		context.runtime.throw_error("The console already has a command named %s." % name)

		return

	_commands.register(name, description, _run_command.bind(context, name))

	if not context.commands.has(name):
		context.commands.append(name)


# the handler of a script command. The runtime and the command name are bound
# after the words
func _run_command(words: PackedStringArray, context: ScriptContext, name: String) -> String:
	if context.runtime == null:
		return ""

	var result := context.runtime.run_command(name, words)

	if not bool(result.ok):
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "Uncaught " + context.prefix() + str(result.error))

		return ""

	return str(result.text) if result.text != null else ""
