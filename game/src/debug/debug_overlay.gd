class_name CityDebugOverlay
extends Node

const SAMPLE_INTERVAL_SECONDS := 0.25
const DISASTER_NAMES := ["Fire", "Flood", "Riot", "Toxic Spill", "Air Crash",
	"Earthquake", "Tornado", "Monster", "Meltdown", "Microwave", "Volcano",
	"Firestorm", "Mass Riots", "Mass Floods", "Pollution", "Hurricane",
	"Helicopter Crash", "Plane Crash"]
var main_control: Control
var is_open := false
var _sample_elapsed := 0.0
var _metrics: Dictionary = {}
var _window: Window
var _days: Tree
var _steps: Tree
var _metrics_label: Label
var _action_label: Label
var _status: Label
var _resume_speed := 2

func setup(value: Control) -> void:
	main_control = value

func _ready() -> void:
	_window = Window.new()
	_window.title = "Simulation timings and debug — F12"
	_window.size = Vector2i(1040, 740)
	_window.min_size = Vector2i(640, 420)
	_window.visible = false
	_window.theme = ClassicUiStyle.create_dialog_theme()
	add_child(_window)
	_window.close_requested.connect(toggle)
	_window.window_input.connect(_input)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_window.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var note := Label.new()
	note.text = "Work time excludes frame-budget waits and player prompts. OS scheduling can still affect it.\nAverages cover this city since load or Reset. Unmeasured days show —."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var reset := Button.new()
	reset.text = "Reset timing averages"
	reset.pressed.connect(func() -> void:
		var history := _history()
		if history != null:
			history.clear()
		_refresh_metrics())
	box.add_child(reset)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	_days = _table(tabs, "Simulation days", ["Day", "What happens", "Average ms", "Last ms", "Max ms", "Samples"])
	_steps = _table(tabs, "Steps", ["Step", "Average ms", "Last ms", "Max ms", "Samples"])
	var scroll := ScrollContainer.new()
	scroll.name = "Metrics"
	tabs.add_child(scroll)
	_metrics_label = Label.new()
	_metrics_label.text = "No samples yet."
	scroll.add_child(_metrics_label)
	_build_actions(tabs)

func _table(tabs: TabContainer, caption: String, titles: Array) -> Tree:
	var tree := Tree.new()
	tree.name = caption
	tree.columns = titles.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	for column in titles.size():
		tree.set_column_title(column, titles[column])
		tree.set_column_expand(column, column == (1 if titles.size() == 6 else 0))
		tree.set_column_custom_minimum_width(column, 68 if column == 0 and titles.size() == 6 else 95)
	tabs.add_child(tree)
	return tree

func _build_actions(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Actions"
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_button(box, "Pause / Resume", func() -> void:
		if str(_metrics.get("speed", "Paused")) == "Paused":
			main_control.call("_select_speed", _resume_speed)
		else:
			_resume_speed = int(_metrics.get("speed_id", 2))
			main_control.call("_select_speed", 1))
	for action in [["Center map", "_debug_center_map"], ["Full redraw", "_debug_full_redraw"],
		["Clear render caches", "_debug_clear_render_caches"],
		["Unlock everything", "_debug_unlock_everything"], ["Call Maxis Man", "_debug_dispatch_maxis_man"],
		["End active disaster", "_debug_end_disaster"]]:
		var method := str(action[1])
		_button(box, action[0], func() -> void: _invoke(method))
	for amount in [10000, 100000, 1000000]:
		_button(box, "+$%d" % amount, func() -> void: _record_action(main_control.call("_debug_add_funds", amount)))
	for mode in ["city", "underground"]:
		_button(box, mode.capitalize() + " view", func() -> void: main_control.call("_set_overlay", mode))
	_button(box, "Toggle random disasters", func() -> void:
		_record_action(main_control.call("_debug_set_no_disasters", not bool(_metrics.get("no_disasters", false)))))
	var disaster := OptionButton.new()
	for caption in DISASTER_NAMES:
		disaster.add_item(caption)
	box.add_child(disaster)
	_button(box, "Start disaster at view center", func() -> void:
		_record_action(main_control.call("_debug_start_disaster", disaster.selected + 1)))
	var altitude := SpinBox.new()
	altitude.min_value = 1
	altitude.max_value = 32
	altitude.value = 32
	altitude.prefix = "Visible terrain levels: "
	box.add_child(altitude)
	altitude.value_changed.connect(func(value: float) -> void: main_control.call("_debug_set_visible_altitude_levels", int(value)))
	_button(box, "Print metrics", func() -> void: print(_metrics))
	_action_label = Label.new()
	_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_action_label)

func _button(parent: Control, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)

func _invoke(method: String) -> void:
	var result: Variant = main_control.call(method)
	if result is Dictionary:
		_record_action(result)

func _record_action(result: Dictionary) -> void:
	if _action_label != null:
		_action_label.text = str(result.get("message", result.get("error", "Debug action completed.")))
	_refresh_metrics()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F12 and event.pressed and not event.echo:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	is_open = not is_open
	if _window != null:
		if is_open:
			_window.popup_centered()
		else:
			_window.hide()
	if is_open:
		_refresh_metrics()

func _process(delta: float) -> void:
	if not is_open:
		return
	_sample_elapsed += delta
	if _sample_elapsed >= SAMPLE_INTERVAL_SECONDS:
		_sample_elapsed = 0.0
		_refresh_metrics()

func _history() -> SimulationTimingHistory:
	if main_control != null and main_control.get("simulation_timings") is SimulationTimingHistory:
		return main_control.get("simulation_timings") as SimulationTimingHistory
	return null

func _refresh_metrics() -> void:
	if not is_instance_valid(main_control):
		return
	_metrics = main_control.call("_debug_metrics")
	if _days == null:
		return
	_status.text = "%s — %s — %s — FPS %d" % [_metrics.get("city_name", "No city"), _metrics.get("date", "—"), _metrics.get("speed", "—"), Engine.get_frames_per_second()]
	var history := _history()
	_days.clear()
	var root := _days.create_item()
	for day in 25:
		var item := _days.create_item(root)
		item.set_text(0, str(day + 1))
		item.set_text(1, SimulationTimingHistory.DAY_SUMMARIES[day])
		item.set_tooltip_text(1, SimulationTimingHistory.DAY_SUMMARIES[day])
		_stats(item, 2, history.days.get(day, {}) if history != null else {})
	_steps.clear()
	root = _steps.create_item()
	if history != null:
		var labels := history.steps.keys()
		labels.sort()
		for label in labels:
			var item := _steps.create_item(root)
			item.set_text(0, label)
			item.set_tooltip_text(0, label)
			_stats(item, 1, history.steps[label])
	var lines := PackedStringArray()
	for key in _metrics:
		lines.append("%s: %s" % [key, _metrics[key]])
	_metrics_label.text = "\n".join(lines)

func _stats(item: TreeItem, column: int, row: Dictionary) -> void:
	if row.is_empty():
		for index in range(column, column + 4):
			item.set_text(index, "—")
		return
	item.set_text(column, "%.3f" % (float(row.total_usec) / row.count / 1000.0))
	item.set_text(column + 1, "%.3f" % (float(row.last_usec) / 1000.0))
	item.set_text(column + 2, "%.3f" % (float(row.max_usec) / 1000.0))
	item.set_text(column + 3, str(row.count))
