class_name ApplicationScripting
extends RefCounted
## The JavaScript runtime of mods and developer scripts: QuickJS-ng in the
## native scripting library. The runtime starts at its first use, from
## console input or a script file. The game sends an event to scripts only
## while a script listens to its type. See docs/scripting.md.

@warning_ignore_start("integer_division")

const API_PATH := "res://assets/scripting/api.js"
# a relative path of the run command starts in this folder of the user data
const SCRIPTS_FOLDER := "scripts"
# the events that the game sends: type -> description. "*" listens to all
const EVENTS := {
	"city.opened": "A city opened: { name, size, date }.",
	"city.closed": "The city closed.",
	"city.saved": "The city was saved: { path }.",
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
	"frame": "A frame started: { delta } in seconds. Timers are better for most work.",
}

var app: CityApplication
var api: ApplicationScriptingApi
# null until the first use, and after reset
var runtime: ScriptRuntime
var last_script_path := ""
# event type -> number of script listeners
var _listeners: Dictionary[String, int] = {}
var _timers_active := false
var _handlers: Dictionary[String, Callable] = {}
# the console commands that scripts registered
var _script_commands: PackedStringArray = []
var _commands: ConsoleCommands
# the active disaster at the last check, for the started and ended events
var _disaster := 0
var _file_dialog: FileDialog


func _init(application: CityApplication) -> void:
	app = application
	api = ApplicationScriptingApi.new(application)
	_handlers = api.handlers()


## Adds the script commands to the console, and sends the other input to
## scripts. The console keeps method Callables, which do not keep this object.
func attach_console(commands: ConsoleCommands) -> void:
	_commands = commands
	commands.evaluator = evaluate_console
	commands.register("run", "Run a JavaScript file: run <path>. A relative path starts in the scripts folder.", _run_command_file)
	commands.register("reset", "Stop all scripts and start a new script runtime.", _reset_command)
	commands.register("scripts", "Show the script runtime: listeners, timers and memory.", _status_command)


func _run_command_file(words: PackedStringArray) -> String:
	if words.is_empty():
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "Name a script file: run <path>.")

		return ""

	run_file(script_path(" ".join(words)))

	return ""


func _reset_command(_words: PackedStringArray) -> String:
	reset()

	return "The script runtime stopped. The next script starts a new one."


func _status_command(_words: PackedStringArray) -> String:
	return status_text()


## Starts the runtime and the game API. False when the runtime cannot start.
func start() -> bool:
	if runtime != null:
		return true

	var created := ScriptRuntime.new()

	if not created.is_ready():
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "The script runtime cannot start: %s" % created.get_error())

		return false

	runtime = created
	runtime.set_host(_host)
	_disaster = _active_disaster()
	var result := runtime.run_script(FileAccess.get_file_as_string(API_PATH), API_PATH)

	if not bool(result.ok):
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "The game API of scripts failed: %s" % result.error)

	return true


func is_running() -> bool:
	return runtime != null


## Stops all scripts: their listeners, timers and console commands.
func reset() -> void:
	if runtime != null:
		runtime.close()

	runtime = null
	_listeners.clear()
	_timers_active = false

	if _commands != null:
		for name in _script_commands:
			_commands.unregister(name)

	_script_commands.clear()


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
	if runtime == null:
		return "The script runtime is not running. Console input or a script file starts it."

	var memory := runtime.memory_usage()
	var types := PackedStringArray()

	for type in _listeners:
		types.append("%s (%d)" % [type, _listeners[type]])

	return "QuickJS-ng %s. Memory: %d KiB of %d MiB, %d objects.\nListeners: %s.\nTimers: %s. Commands: %s." % [
		ScriptRuntime.engine_version(), int(memory.memory_used) / 1024, int(memory.memory_limit) / 1048576, int(memory.objects),
		", ".join(types) if not types.is_empty() else "none", "waiting" if _timers_active else "none",
		", ".join(_script_commands) if not _script_commands.is_empty() else "none",
	]


## True when a script listens to the event type, or to all events.
func listens(type: String) -> bool:
	return runtime != null and (_listeners.has(type) or _listeners.has("*"))


## Sends an event to the script listeners. Returns the event after the
## listeners, or an empty Dictionary when no script listens. A listener sets
## `cancelled` of a cancelable event.
func emit(type: String, detail: Dictionary = {}, cancelable := false) -> Dictionary:
	if not listens(type):
		return {}

	return runtime.dispatch(type, detail, cancelable)


## True when a script cancelled the event.
func cancelled(type: String, detail: Dictionary) -> bool:
	return bool(emit(type, detail, true).get("cancelled", false))


func process(delta: float) -> void:
	if runtime == null:
		return

	if listens("frame"):
		emit("frame", {"delta": delta})

	if _timers_active or runtime.has_pending_jobs():
		runtime.tick()


func close() -> void:
	reset()


## Sends the events of a published simulation tick.
func on_simulation_result(result: SimulationTickResult) -> void:
	if runtime == null:
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

	if runtime == null or active == _disaster:
		_disaster = active

		return

	var previous := _disaster
	_disaster = active

	if previous != 0:
		emit("disaster.ended", {"id": previous, "name": CityMenuBar.disaster_name(previous)})

	if active != 0:
		emit("disaster.started", {"id": active, "name": CityMenuBar.disaster_name(active)})


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


# runs a host function of a script: (name, arguments) -> value
func _host(name: String, arguments: Array) -> Variant:
	match name:
		"console":
			_console(str(arguments[0]), str(arguments[1]))

			return null
		"listeners":
			_count_listeners(str(arguments[0]), int(arguments[1]))

			return null
		"timers":
			_timers_active = int(arguments[0]) > 0

			return null
		"command":
			_register_command(str(arguments[0]), str(arguments[1]))

			return null

	var handler: Callable = _handlers.get(name, Callable())

	if not handler.is_valid():
		runtime.throw_error("The game has no function named %s." % name)

		return null

	api.failure = ""
	var value: Variant = handler.call(arguments)

	if not api.failure.is_empty() and runtime != null:
		runtime.throw_error(api.failure)

	return value


func _console(level: String, text: String) -> void:
	match level:
		"warn":
			ConsoleLog.append(ConsoleLog.Level.WARNING, text)
		"error":
			printerr(text)
		"result":
			ConsoleLog.append(ConsoleLog.Level.RESULT, text)
		_:
			print(text)


func _count_listeners(type: String, count: int) -> void:
	if count > 0:
		_listeners[type] = count
	else:
		_listeners.erase(type)


func _register_command(name: String, description: String) -> void:
	if _commands == null:
		return

	if _commands.has(name) and not _script_commands.has(name):
		runtime.throw_error("The console already has a command named %s." % name)

		return

	_commands.register(name, description, _run_command.bind(name))

	if not _script_commands.has(name):
		_script_commands.append(name)


# the handler of a script command. The command name is bound after the words
func _run_command(words: PackedStringArray, name: String) -> String:
	if runtime == null:
		return ""

	var result := runtime.run_command(name, words)

	if not bool(result.ok):
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "Uncaught " + str(result.error))

		return ""

	return str(result.text) if result.text != null else ""
