class_name ConsoleLog
extends RefCounted
## Keeps the recent engine and game output for the Console window. A Godot
## Logger receives the same messages, warnings and errors that the command
## line shows. Other threads can log, thus each access holds the mutex.

enum Level { MESSAGE, ERROR_OUTPUT, WARNING, ERROR, INPUT, RESULT }

# the oldest entries go when the log holds more than this many
const MAX_ENTRIES := 5000
# Logger.ErrorType names, as the command line shows them
const ERROR_TYPE_NAMES: PackedStringArray = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]
const RENDERING_DRIVER_NAMES := { "vulkan": "Vulkan", "metal": "Metal", "d3d12": "D3D12", "opengl3": "OpenGL API",
	"opengl3_es": "OpenGL ES API", "opengl3_angle": "OpenGL API" }
const RENDERING_METHOD_NAMES := { "forward_plus": "Forward+", "mobile": "Forward Mobile", "gl_compatibility": "Compatibility" }
# the command line indents the source location of each error type this much
const ERROR_TYPE_INDENTS: PackedStringArray = ["   ", "     ", "          ", "          "]
const ERROR_TYPE_WARNING := 1

static var _mutex := Mutex.new()
static var _entries: Array[Entry] = []
# the serial of the newest entry. it grows with each entry and clear() keeps it
static var _serial := 0
# it grows with each clear(), thus a view knows to show the log again
static var _generation := 0
# the warnings and errors in the log
static var _warnings := 0
static var _errors := 0
static var _logger: OutputLogger


## Starts to record the engine output. The autoload calls this before the
## main scene loads.
static func install() -> void:
	if _logger != null:
		return

	# Godot writes its first lines before the autoloads start
	append(Level.MESSAGE, godot_header())
	var renderer := renderer_line()

	if not renderer.is_empty():
		append(Level.MESSAGE, renderer)

	_logger = OutputLogger.new()
	OS.add_logger(_logger)


static func uninstall() -> void:
	if _logger == null:
		return

	OS.remove_logger(_logger)
	_logger = null


static func is_installed() -> bool:
	return _logger != null


static func append(level: Level, text: String) -> void:
	_mutex.lock()
	_serial += 1
	_entries.append(Entry.new(_serial, level, text, Time.get_ticks_msec()))
	_count(level, 1)

	if _entries.size() > MAX_ENTRIES:
		var removed := _entries.size() - MAX_ENTRIES

		for index in removed:
			_count(_entries[index].level, -1)

		_entries = _entries.slice(removed)

	_mutex.unlock()


static func _count(level: Level, step: int) -> void:
	if level == Level.WARNING:
		_warnings += step
	elif level == Level.ERROR:
		_errors += step


## The entries after `serial`, oldest first.
static func entries_since(serial: int) -> Array[Entry]:
	_mutex.lock()
	var first := _entries.size()

	while first > 0 and _entries[first - 1].serial > serial:
		first -= 1

	var result := _entries.slice(first)
	_mutex.unlock()

	return result


static func latest_serial() -> int:
	_mutex.lock()
	var serial := _serial
	_mutex.unlock()

	return serial


static func generation() -> int:
	_mutex.lock()
	var value := _generation
	_mutex.unlock()

	return value


## The number of warnings and errors in the log: [warnings, errors].
static func problem_counts() -> Vector2i:
	_mutex.lock()
	var counts := Vector2i(_warnings, _errors)
	_mutex.unlock()

	return counts


static func clear() -> void:
	_mutex.lock()
	_entries.clear()
	_generation += 1
	_warnings = 0
	_errors = 0
	_mutex.unlock()


## The text of the entries, one line for each line of output.
static func plain_text(entries: Array[Entry]) -> String:
	var lines := PackedStringArray()

	for entry in entries:
		lines.append(entry.text)

	return "\n".join(lines)


## An error as the command line shows it: the type and the reason, the source
## location, then the script call stack when there is one.
static func format_error(function: String, file: String, line: int, code: String, rationale: String,
		error_type: int, backtraces: Array = []) -> String:
	var known := error_type >= 0 and error_type < ERROR_TYPE_NAMES.size()
	var indent := ERROR_TYPE_INDENTS[error_type] if known else ERROR_TYPE_INDENTS[0]
	var text := "%s: %s" % [ERROR_TYPE_NAMES[error_type] if known else "ERROR", rationale if not rationale.is_empty() else code]

	if not function.is_empty() or not file.is_empty():
		text += "\n%sat: %s (%s:%d)" % [indent, function, file, line]

	for backtrace: ScriptBacktrace in backtraces:
		if backtrace != null and not backtrace.is_empty():
			text += "\n" + backtrace.format(indent.length()).trim_suffix("\n")

	return text


## The first line that Godot writes on the command line.
static func godot_header() -> String:
	var godot := Engine.get_version_info()
	var number := "%d.%d" % [godot.major, godot.minor]

	if int(godot.patch) > 0:
		number += ".%d" % godot.patch

	return "Godot Engine v%s.%s.%s.%s - https://godotengine.org" % [number, godot.status, godot.build, str(godot.hash).left(9)]


## The graphics driver and device line that Godot writes at the start. Empty
## without a graphics device, as in headless runs.
static func renderer_line() -> String:
	var device := RenderingServer.get_video_adapter_name()

	if device.is_empty():
		return ""

	var driver := RenderingServer.get_current_rendering_driver_name()
	var method := RenderingServer.get_current_rendering_method()
	var method_name: String = RENDERING_METHOD_NAMES.get(method, method.capitalize())

	return "%s %s - %s - Using Device: %s - %s" % [RENDERING_DRIVER_NAMES.get(driver, driver.capitalize()),
		RenderingServer.get_video_adapter_api_version(), method_name, RenderingServer.get_video_adapter_vendor(), device]


static func error_level(error_type: int) -> Level:
	return Level.WARNING if error_type == ERROR_TYPE_WARNING else Level.ERROR


class Entry extends RefCounted:
	var serial := 0
	var level := Level.MESSAGE
	var text := ""
	var msec := 0

	func _init(id: int, kind: Level, value: String, time_msec: int) -> void:
		serial = id
		level = kind
		text = value
		msec = time_msec


# Godot calls these methods from any thread. They must not log, because a
# message from a logger is not sent to the loggers again
class OutputLogger extends Logger:
	func _log_message(message: String, error: bool) -> void:
		ConsoleLog.append(Level.ERROR_OUTPUT if error else Level.MESSAGE, message.trim_suffix("\n"))

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		ConsoleLog.append(ConsoleLog.error_level(error_type),
			ConsoleLog.format_error(function, file, line, code, rationale, error_type, script_backtraces))
