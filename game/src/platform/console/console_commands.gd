class_name ConsoleCommands
extends RefCounted
## Runs the lines that the player types in the Console window. A line that
## starts with the name of a command runs that command. Other input, and all
## input with more than one line, goes to the evaluator, such as a script
## runtime, when one is set.

var _commands: Dictionary[String, Command] = {}
# (source: String) -> String. the result text, or "" when there is no result
var evaluator := Callable()


func _init() -> void:
	register("help", "List the console commands.", _help)
	register("clear", "Remove all lines from the console.", func(_arguments: PackedStringArray) -> String:
		ConsoleLog.clear()

		return "")
	register("version", "Show the OpenSC2K and Godot versions.", func(_arguments: PackedStringArray) -> String:
		return ConsoleCommands.version_text())
	register("save", "Save the console to a text file: save [path]. The log folder holds a relative path.", _save)


## `handler` takes the words after the command name and returns the text to show.
func register(name: String, description: String, handler: Callable) -> void:
	_commands[name.to_lower()] = Command.new(name.to_lower(), description, handler)


func names() -> PackedStringArray:
	var result := PackedStringArray(_commands.keys())
	result.sort()

	return result


## Shows the line and its result in the console log.
func execute(line: String) -> void:
	var source := line.strip_edges()

	if source.is_empty():
		return

	# continuation lines of a multi-line input line up under the first line
	ConsoleLog.append(ConsoleLog.Level.INPUT, "> " + source.replace("\n", "\n  "))
	var multi_line := source.contains("\n")
	var words := source.replace("\t", " ").split(" ", false)
	var command: Command = null if multi_line else _commands.get(words[0].to_lower())
	var result := ""

	if command != null:
		result = str(command.handler.call(words.slice(1)))
	elif evaluator.is_valid():
		result = str(evaluator.call(source))
	elif multi_line:
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "Only a script runtime can run input with more than one line. Type help to list the commands.")

		return
	else:
		# a typing error is not a game error, thus the error count does not include it
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "Unknown command: %s. Type help to list the commands." % words[0])

		return

	if not result.is_empty():
		ConsoleLog.append(ConsoleLog.Level.RESULT, result)


## The names of the commands that start with `prefix`.
func completions(prefix: String) -> PackedStringArray:
	var result := PackedStringArray()

	for name in names():
		if name.begins_with(prefix.strip_edges().to_lower()):
			result.append(name)

	return result


static func version_text() -> String:
	return "OpenSC2K %s\n%s" % [ProjectSettings.get_setting("application/config/version", ""), ConsoleLog.godot_header()]


## Writes the console to the path in the words, or to a new file in the log folder.
func _save(arguments: PackedStringArray) -> String:
	var path := " ".join(arguments)

	if path.is_empty():
		path = ConsoleLog.default_save_path()
	elif path.is_relative_path() and not path.begins_with("user://"):
		path = ConsoleLog.log_folder().path_join(path)

	path = ProjectSettings.globalize_path(path).simplify_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var count := ConsoleLog.entries_since(0).size()
	var error := ConsoleLog.save(path)

	if error != OK:
		ConsoleLog.append(ConsoleLog.Level.ERROR_OUTPUT, "Cannot save the console to %s: %s." % [path, error_string(error)])

		return ""

	return "Saved %d entries to %s." % [count, path]


func _help(_arguments: PackedStringArray) -> String:
	var lines := PackedStringArray()

	for name in names():
		lines.append("%-10s %s" % [name, _commands[name].description])

	return "\n".join(lines)


class Command extends RefCounted:
	var name := ""
	var description := ""
	var handler := Callable()

	func _init(command_name: String, text: String, callable: Callable) -> void:
		name = command_name
		description = text
		handler = callable
