extends SceneTree
## The console log records the command line output, its commands run, and the
## window shows, filters and recalls them.

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	_check_capture()
	_check_error_format()
	_check_limit()
	_check_commands()
	await _check_window()
	_check_shortcut()
	print("Console window: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_capture() -> void:
	check(ConsoleLog.is_installed(), "The autoload records the output before the main scene")
	var serial := ConsoleLog.latest_serial()
	print("console test message")
	push_warning("console test warning")
	var thread := Thread.new()
	thread.start(func() -> void: print("console thread message"))
	thread.wait_to_finish()
	var entries := ConsoleLog.entries_since(serial)
	check(entries.size() == 3, "Messages, warnings and other threads each make one entry")

	if entries.size() != 3:
		return

	check(entries[0].level == ConsoleLog.Level.MESSAGE and entries[0].text == "console test message",
		"A message keeps its text without the line end")
	check(entries[1].level == ConsoleLog.Level.WARNING
		and entries[1].text.begins_with("WARNING: console test warning\n     at: push_warning ("),
		"A warning shows as the command line shows it")
	check(entries[1].text.contains("console_window_test.gd"), "A warning shows its script call stack")
	check(entries[2].text == "console thread message", "A message from another thread is recorded")
	check(ConsoleLog.entries_since(0)[0].text.begins_with("Godot Engine v"), "The log starts with the Godot version line")


func _check_error_format() -> void:
	check(ConsoleLog.format_error("load", "core/io/file.cpp", 12, "err != OK", "Cannot open file.", 0)
		== "ERROR: Cannot open file.\n   at: load (core/io/file.cpp:12)", "An error shows its reason and source")
	check(ConsoleLog.format_error("reload", "res://a.gd", 3, "Parse error", "", 2)
		== "SCRIPT ERROR: Parse error\n          at: reload (res://a.gd:3)", "A script error without a reason shows its code")
	check(ConsoleLog.error_level(1) == ConsoleLog.Level.WARNING and ConsoleLog.error_level(3) == ConsoleLog.Level.ERROR,
		"Warnings and other errors have their levels")


func _check_limit() -> void:
	ConsoleLog.clear()

	for index in ConsoleLog.MAX_ENTRIES + 10:
		ConsoleLog.append(ConsoleLog.Level.ERROR if index < 20 else ConsoleLog.Level.MESSAGE, str(index))

	var entries := ConsoleLog.entries_since(0)
	check(entries.size() == ConsoleLog.MAX_ENTRIES and entries[0].text == "10", "The log keeps the newest entries")
	check(ConsoleLog.problem_counts() == Vector2i(0, 10), "The counts drop the removed entries")
	var generation := ConsoleLog.generation()
	ConsoleLog.clear()
	check(ConsoleLog.entries_since(0).is_empty() and ConsoleLog.generation() == generation + 1
		and ConsoleLog.problem_counts() == Vector2i.ZERO, "Clear removes the entries and starts a new generation")


func _check_commands() -> void:
	var commands := ConsoleCommands.new()
	commands.execute("  help ")
	var entries := ConsoleLog.entries_since(0)
	check(entries.size() == 2 and entries[0].level == ConsoleLog.Level.INPUT and entries[0].text == "> help",
		"A command shows the line that the player typed")
	check(entries.size() == 2 and entries[1].text.contains("clear") and entries[1].text.contains("version"),
		"Help lists the commands")
	commands.execute("nothing here")
	check(ConsoleLog.entries_since(0)[-1].level == ConsoleLog.Level.ERROR_OUTPUT and ConsoleLog.problem_counts() == Vector2i.ZERO,
		"An unknown command shows an error that the error count does not include")
	commands.evaluator = func(source: String) -> String: return "evaluated " + source
	commands.execute("1 + 2")
	check(ConsoleLog.entries_since(0)[-1].text == "evaluated 1 + 2", "Other lines go to the evaluator")
	commands.register("Echo", "Show the words.", func(words: PackedStringArray) -> String: return " ".join(words))
	commands.execute("ECHO a  b")
	check(ConsoleLog.entries_since(0)[-1].text == "a b", "A registered command takes its words")
	check(commands.completions("he") == PackedStringArray(["help"]) and commands.completions("").size() == 5,
		"Tab completion lists the matching commands")
	commands.execute("clear")
	check(ConsoleLog.entries_since(0).is_empty(), "The clear command empties the log")


func _check_window() -> void:
	var window := ConsoleWindow.new()
	root.add_child(window)
	window.open()
	ConsoleLog.append(ConsoleLog.Level.MESSAGE, "shown message")
	ConsoleLog.append(ConsoleLog.Level.WARNING, "WARNING: shown warning")
	# the process_frame signal comes before the nodes process
	await process_frame
	await process_frame
	check(window.visible and window.output.get_parsed_text().contains("shown message")
		and window.output.get_parsed_text().contains("shown warning"), "The window shows new entries")
	check(window.counts_label.text == "0 errors, 1 warning", "The window counts the warnings and errors")
	window.show_warnings.button_pressed = false
	check(not window.output.get_parsed_text().contains("shown warning"), "The Warnings check hides warnings")
	window.show_warnings.button_pressed = true
	window.filter_input.text = "MESSAGE"
	window.filter_input.text_changed.emit(window.filter_input.text)
	check(window.shown_entries().size() == 1 and window.shown_entries()[0].text == "shown message",
		"The filter shows the matching entries")
	window.filter_input.text = ""
	window.filter_input.text_changed.emit("")

	window.input.text = "version"
	window._on_input_key(_key(KEY_ENTER))
	check(window.input.text.is_empty() and window.output.get_parsed_text().contains("> version")
		and window.output.get_parsed_text().contains("OpenSC2K"), "The input line runs a command")
	window.input.text = "draft"
	window.input.set_caret_line(0)
	window._on_input_key(_key(KEY_UP))
	check(window.input.text == "version", "Up recalls the last command")
	window._on_input_key(_key(KEY_DOWN))
	check(window.input.text == "draft", "Down returns to the unfinished line")
	_check_multi_line(window)
	_check_save(window)
	window.input.text = "cle"
	window._on_input_key(_key(KEY_TAB))
	check(window.input.text == "clear ", "Tab completes a command name")
	window.submit()
	await process_frame
	check(window.output.get_parsed_text().is_empty(), "The window empties after a clear")

	window._on_window_input(_key(KEY_ESCAPE))
	check(not window.visible, "Escape closes the window")
	window.toggle()
	check(window.visible, "The shortcut opens the window again")
	window.queue_free()
	await process_frame


func _check_multi_line(window: ConsoleWindow) -> void:
	var single_height := window.input.custom_minimum_size.y
	var shift_enter := _key(KEY_ENTER)
	shift_enter.shift_pressed = true
	window.input.text = "first"
	window._caret_to_end()
	window._on_input_key(shift_enter)
	window.input.insert_text_at_caret("second")
	check(window.input.text == "first\nsecond" and window.input.custom_minimum_size.y > single_height,
		"Shift+Enter starts a new line and the input grows")
	window._on_input_key(_key(KEY_UP))
	check(window.input.text == "first\nsecond", "Up on a later line moves the caret, not the history")
	check(not window._complete() and window.input.text == "first\nsecond", "Tab does not complete multi-line input")
	var evaluated: Array[String] = []
	window.commands.evaluator = func(source: String) -> String:
		evaluated.append(source)

		return ""
	window.input.text = "first\nsecond"
	window._on_input_key(_key(KEY_ENTER))
	check(evaluated == ["first\nsecond"] and window.input.text.is_empty()
		and window.input.custom_minimum_size.y == single_height, "Enter runs all lines, then the input shrinks")
	check(window.output.get_parsed_text().contains("> first\n  second"), "The console shows each line of the input")
	window._on_input_key(_key(KEY_UP))
	check(window.input.text == "first\nsecond", "Up recalls multi-line input")
	window.input.clear()
	window.commands.evaluator = Callable()
	window.commands.execute("help\nversion")
	check(ConsoleLog.entries_since(0)[-1].text.begins_with("Only a script runtime"),
		"Multi-line input without a script runtime shows why it cannot run")


func _check_save(window: ConsoleWindow) -> void:
	var folder := OS.get_temp_dir().path_join("opensc2k_console_test_%d" % OS.get_process_id())
	var path := folder.path_join("saved console.log")
	ConsoleLog.append(ConsoleLog.Level.WARNING, "WARNING: hidden by the filter")
	window.show_warnings.button_pressed = false
	# the save command line is saved too
	var count := ConsoleLog.entries_since(0).size() + 1
	window.save_to(path)
	var saved := FileAccess.get_file_as_string(path)
	check(saved.contains("WARNING: hidden by the filter") and saved.contains("> first\n  second") and saved.ends_with("\n"),
		"Save writes all entries, also the hidden ones")
	check(ConsoleLog.entries_since(0)[-1].text == "Saved %d entries to %s." % [count, path],
		"Save shows the path and the entry count")
	window.show_warnings.button_pressed = true
	window.commands.execute("save " + folder.path_join("new/../new/second.log"))
	check(FileAccess.file_exists(folder.path_join("new/second.log")), "The save command makes the folders of its path")
	window.commands.execute("save " + folder)
	check(ConsoleLog.entries_since(0)[-1].level == ConsoleLog.Level.ERROR_OUTPUT, "A save that fails shows an error")
	window.open_save_dialog()
	check(window._save_dialog.visible and window._save_dialog.current_file.begins_with("console_")
		and window._save_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE, "Save opens a save dialog with a new file name")
	window._save_dialog.hide()
	check(ConsoleLog.default_save_path().get_base_dir() == ConsoleLog.log_folder()
		and ConsoleLog.default_save_path().get_file().begins_with("console_"), "A save without a path goes to the log folder")

	for file in ["saved console.log", "new/second.log", "new", ""]:
		DirAccess.remove_absolute(folder.path_join(file))


func _check_shortcut() -> void:
	var bindings := ControlBindings.defaults()
	var event := _key(KEY_J)
	event.shift_pressed = true
	event.meta_pressed = OS.has_feature("macos")
	event.ctrl_pressed = not OS.has_feature("macos")
	check(bindings.action_for(event, [ControlActions.KIND_PRESS], [ControlActions.SCOPE_ANYWHERE]) == "window_console",
		"Command+Shift+J opens the console on every screen")
	check(bindings.conflicts(bindings.first_key("window_console"), "window_console").is_empty(),
		"The console shortcut has no default conflict")


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true

	return event
