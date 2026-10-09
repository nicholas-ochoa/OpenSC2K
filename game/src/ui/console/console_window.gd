class_name ConsoleWindow
extends Window
## Shows the output that the command line shows: messages, warnings and
## errors, with their script call stacks. The input at the bottom runs
## ConsoleCommands. Enter runs the input and Shift+Enter starts a new line.

const DEFAULT_SIZE := Vector2i(900, 520)
const MINIMUM_SIZE := Vector2i(480, 260)
# commands that the Up and Down keys can recall
const HISTORY_LIMIT := 100
# the input grows to this many lines, then it scrolls
const INPUT_MAX_LINES := 8
# the view shows the log again from the start after this many more lines than the log keeps
const REBUILD_MARGIN := 500
const MONOSPACE_FONTS: PackedStringArray = ["Menlo", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"]

var commands := ConsoleCommands.new()
# (event: InputEvent) -> bool. true for the shortcut that opens and closes the console
var toggle_shortcut := Callable()
var output: RichTextLabel
var input: TextEdit
var show_messages: CheckBox
var show_warnings: CheckBox
var show_errors: CheckBox
var filter_input: LineEdit
var counts_label: Label
var _shown_serial := 0
var _shown_generation := -1
var _shown_lines := 0
var _history: PackedStringArray = []
# the history entry that the input shows. the history size means the new line
var _history_index := 0
var _draft := ""
var _save_dialog: FileDialog


func _init() -> void:
	title = "Console"
	size = DEFAULT_SIZE
	min_size = MINIMUM_SIZE
	visible = false
	wrap_controls = true
	theme = AppUiTheme.current()
	close_requested.connect(hide)
	window_input.connect(_on_window_input)
	visibility_changed.connect(_on_visibility_changed)
	_build()


func toggle() -> void:
	if visible:
		hide()
	else:
		open()


func open() -> void:
	if not visible:
		popup_centered()

	grab_focus()
	input.grab_focus()
	# the fonts of the theme apply only in the tree
	_fit_input_height()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin := MarginContainer.new()

	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)

	panel.add_child(margin)

	var layout := VBoxContainer.new()
	margin.add_child(layout)

	var bar := HBoxContainer.new()
	layout.add_child(bar)
	show_messages = _filter_check(bar, "Messages", "Show messages that the game and the engine print.")
	show_warnings = _filter_check(bar, "Warnings", "Show warnings.")
	show_errors = _filter_check(bar, "Errors", "Show errors and script errors.")

	filter_input = LineEdit.new()
	filter_input.placeholder_text = "Filter"
	filter_input.tooltip_text = "Show only the entries that contain this text."
	filter_input.clear_button_enabled = true
	filter_input.custom_minimum_size.x = 160
	filter_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_input.text_changed.connect(func(_text: String) -> void: rebuild())
	bar.add_child(filter_input)

	counts_label = Label.new()
	bar.add_child(counts_label)

	_action_button(bar, "Copy", "Copy the lines that the console shows.", copy_shown)
	_action_button(bar, "Save", "Save all lines of the console to a text file, also the lines that the checks and the filter hide.",
		open_save_dialog)
	_action_button(bar, "Clear", "Remove all lines from the console.", func() -> void: ConsoleLog.clear())
	_action_button(bar, "Log Folder", "Open the folder of the log files. They keep the output of earlier sessions.", open_log_folder)

	output = RichTextLabel.new()
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.scroll_following = true
	output.selection_enabled = true
	output.context_menu_enabled = true
	output.focus_mode = Control.FOCUS_CLICK
	var mono := SystemFont.new()
	mono.font_names = MONOSPACE_FONTS
	output.add_theme_font_override("normal_font", mono)
	output.add_theme_font_override("mono_font", mono)
	layout.add_child(output)

	var prompt_row := HBoxContainer.new()
	layout.add_child(prompt_row)
	var prompt := Label.new()
	prompt.text = ">"
	prompt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	prompt_row.add_child(prompt)

	input = TextEdit.new()
	input.placeholder_text = "Type a command. Type help to list the commands. Shift+Enter starts a new line."
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_font_override("font", mono)
	input.text_changed.connect(_fit_input_height)
	input.text_set.connect(_fit_input_height)
	input.gui_input.connect(_on_input_key)
	prompt_row.add_child(input)
	_fit_input_height()


# one line for each line of the input, up to INPUT_MAX_LINES
func _fit_input_height() -> void:
	var lines := clampi(input.get_line_count(), 1, INPUT_MAX_LINES)
	var frame := input.get_theme_stylebox("normal").get_minimum_size().y if input.has_theme_stylebox("normal") else 0.0
	input.custom_minimum_size.y = lines * input.get_line_height() + frame


func _filter_check(parent: Control, text: String, tooltip: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.tooltip_text = tooltip
	check.button_pressed = true
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(func(_pressed: bool) -> void: rebuild())
	parent.add_child(check)

	return check


func _action_button(parent: Control, text: String, tooltip: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: action.call())
	parent.add_child(button)


func _process(_delta: float) -> void:
	if visible:
		refresh()


func _on_visibility_changed() -> void:
	set_process(visible)

	if visible:
		refresh()


## Shows the new log entries. Shows the log again from the start after a
## clear, or when the view holds too many lines.
func refresh() -> void:
	if ConsoleLog.generation() != _shown_generation or _shown_lines > ConsoleLog.MAX_ENTRIES + REBUILD_MARGIN:
		rebuild()

		return

	if ConsoleLog.latest_serial() == _shown_serial:
		return

	_append(ConsoleLog.entries_since(_shown_serial))


func rebuild() -> void:
	output.clear()
	_shown_lines = 0
	_shown_serial = 0
	_shown_generation = ConsoleLog.generation()
	_append(ConsoleLog.entries_since(0))


func _append(entries: Array[ConsoleLog.Entry]) -> void:
	for entry in entries:
		_shown_serial = entry.serial

		if not shows(entry):
			continue

		if _shown_lines > 0:
			output.newline()

		output.push_color(_level_color(entry.level))
		output.add_text(entry.text)
		output.pop()
		_shown_lines += 1

	_refresh_counts()


## True when the level checks and the filter text let the entry show.
func shows(entry: ConsoleLog.Entry) -> bool:
	var level_shown := show_messages.button_pressed

	if entry.level == ConsoleLog.Level.WARNING:
		level_shown = show_warnings.button_pressed
	elif entry.level in [ConsoleLog.Level.ERROR, ConsoleLog.Level.ERROR_OUTPUT]:
		level_shown = show_errors.button_pressed

	return level_shown and (filter_input.text.is_empty() or entry.text.containsn(filter_input.text))


func shown_entries() -> Array[ConsoleLog.Entry]:
	var result: Array[ConsoleLog.Entry] = []
	result.assign(ConsoleLog.entries_since(0).filter(shows))

	return result


func copy_shown() -> void:
	DisplayServer.clipboard_set(ConsoleLog.plain_text(shown_entries()))


func open_log_folder() -> void:
	var folder := ConsoleLog.log_folder()
	DirAccess.make_dir_recursive_absolute(folder)
	OS.shell_open(folder)


func open_save_dialog() -> void:
	if _save_dialog == null:
		_save_dialog = FileDialogFactory.console_log_save()
		_save_dialog.title = "Save Console"
		_save_dialog.file_selected.connect(save_to)
		add_child(_save_dialog)

	var path := ConsoleLog.default_save_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_save_dialog.current_dir = path.get_base_dir()
	_save_dialog.current_file = path.get_file()
	_save_dialog.popup_centered_ratio(0.7)


## Saves the console as the save command does, and shows the result.
func save_to(path: String) -> void:
	commands.execute("save " + path)
	refresh()


func _refresh_counts() -> void:
	var counts := ConsoleLog.problem_counts()
	counts_label.text = "%d %s, %d %s" % [counts.y, "error" if counts.y == 1 else "errors", counts.x, "warning" if counts.x == 1 else "warnings"]


func _level_color(level: ConsoleLog.Level) -> Color:
	match level:
		ConsoleLog.Level.WARNING:
			return get_theme_color("warning", "AppPalette")
		ConsoleLog.Level.ERROR, ConsoleLog.Level.ERROR_OUTPUT:
			return get_theme_color("error", "AppPalette")
		ConsoleLog.Level.INPUT:
			return get_theme_color("chart_accent", "AppPalette")

	return get_theme_color("ink", "AppPalette")


## Runs the input and keeps it in the history.
func submit() -> void:
	var text := input.text
	input.clear()

	if text.strip_edges().is_empty():
		return

	if _history.is_empty() or _history[-1] != text:
		_history.append(text)

	if _history.size() > HISTORY_LIMIT:
		_history = _history.slice(_history.size() - HISTORY_LIMIT)

	_history_index = _history.size()
	_draft = ""
	commands.execute(text)
	refresh()


## Enter runs the input and Shift+Enter starts a new line. Up on the first
## line and Down on the last line recall earlier input. Tab completes a
## command name on one line, and types a tab in other input.
func _on_input_key(event: InputEvent) -> void:
	var key := event as InputEventKey

	if key == null or not key.pressed:
		return

	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		if key.shift_pressed:
			input.insert_text_at_caret("\n")
			# TextEdit sends text_changed in the next frame
			_fit_input_height()
		elif not key.ctrl_pressed and not key.meta_pressed and not key.alt_pressed:
			submit()
		else:
			return

		input.accept_event()
	elif key.keycode == KEY_UP and input.get_caret_line() == 0:
		_recall(-1)
		input.accept_event()
	elif key.keycode == KEY_DOWN and input.get_caret_line() == input.get_line_count() - 1:
		_recall(1)
		input.accept_event()
	elif key.keycode == KEY_TAB and not key.shift_pressed and _complete():
		input.accept_event()


func _recall(step: int) -> void:
	if _history.is_empty():
		return

	if _history_index == _history.size():
		_draft = input.text

	_history_index = clampi(_history_index + step, 0, _history.size())
	input.text = _history[_history_index] if _history_index < _history.size() else _draft
	_caret_to_end()


func _caret_to_end() -> void:
	input.set_caret_line(input.get_line_count() - 1)
	input.set_caret_column(input.get_line(input.get_line_count() - 1).length())
	_fit_input_height()


# true when the input is one line that starts a command name
func _complete() -> bool:
	if input.text.contains("\n") or input.text.strip_edges().is_empty():
		return false

	var matches := commands.completions(input.text)

	if matches.size() == 1:
		input.text = matches[0] + " "
		_caret_to_end()
	elif matches.size() > 1:
		ConsoleLog.append(ConsoleLog.Level.RESULT, "  ".join(matches))

	return not matches.is_empty()


func _on_window_input(event: InputEvent) -> void:
	var key := event as InputEventKey

	if key == null or not key.pressed or key.echo:
		return

	if key.keycode == KEY_ESCAPE or (toggle_shortcut.is_valid() and toggle_shortcut.call(event)):
		hide()
		set_input_as_handled()
