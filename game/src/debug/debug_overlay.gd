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
var _terrain_slider: HSlider
var _terrain_value: Label
var _no_disasters_check: CheckBox


func setup(value: Control) -> void:
	main_control = value


func _ready() -> void:
	_window = Window.new()
	_window.title = "Simulation timings and debug — F12"
	_window.size = Vector2i(1040, 740)
	_window.min_size = Vector2i(640, 420)
	_window.visible = false
	_window.theme = _create_debug_theme()
	add_child(_window)
	_window.close_requested.connect(toggle)
	_window.window_input.connect(_input)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.add_child(panel)
	var margin := MarginContainer.new()

	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)

	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_status)
	var note := Label.new()
	note.text = "Work time excludes frame-budget waits and player prompts. OS scheduling can still affect it.\nAverages cover this city since load or Reset. Unmeasured days show —."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var reset := Button.new()
	reset.text = "Reset averages"
	reset.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void:
		var history := _history()

		if history != null:
			history.clear()

		_refresh_metrics())
	header.add_child(reset)
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
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)
	var simulation := _action_section(box, "Simulation and view", 3)
	_button(simulation, "Pause / Resume", func() -> void:
		if str(_metrics.get("speed", "Paused")) == "Paused":
			main_control.call("_select_speed", _resume_speed)
		else:
			_resume_speed = int(_metrics.get("speed_id", 2))
			main_control.call("_select_speed", 1))

	for action in [["Center map", "_debug_center_map"], ["Full redraw", "_debug_full_redraw"],
		["Clear render caches", "_debug_clear_render_caches"]]:
		var method := str(action[1])
		_button(simulation, action[0], func() -> void:
			_invoke(method))

	for mode in ["city", "underground"]:
		_button(simulation, mode.capitalize() + " view", func() -> void:
			main_control.call("_set_overlay", mode))

	_button(simulation, "Print metrics", func() -> void:
		print(_metrics))
	var cheats := _action_section(box, "City cheats", 3)

	for amount in [10000, 100000, 1000000]:
		_button(cheats, "+$%d" % amount, func() -> void:
			_record_action(main_control.call("_debug_add_funds", amount)))

	_button(cheats, "Unlock everything", func() -> void:
		_invoke("_debug_unlock_everything"))
	_button(cheats, "Call Maxis Man", func() -> void:
		_invoke("_debug_dispatch_maxis_man"))
	var disasters := _action_section(box, "Disasters", 3)
	var disaster := OptionButton.new()
	disaster.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for caption in DISASTER_NAMES:
		disaster.add_item(caption)

	disasters.add_child(disaster)
	_button(disasters, "Start at view center", func() -> void:
		_record_action(main_control.call("_debug_start_disaster", disaster.selected + 1)))
	_button(disasters, "End active disaster", func() -> void:
		_invoke("_debug_end_disaster"))
	_no_disasters_check = CheckBox.new()
	_no_disasters_check.text = "Disable random disasters"
	_no_disasters_check.toggled.connect(func(enabled: bool) -> void:
		_record_action(main_control.call("_debug_set_no_disasters", enabled)))
	disasters.add_child(_no_disasters_check)
	var terrain := _action_section(box, "Terrain visibility", 3)
	var label := Label.new()
	label.text = "Visible terrain levels"
	terrain.add_child(label)
	_terrain_slider = HSlider.new()
	_terrain_slider.min_value = 1
	_terrain_slider.max_value = 32
	_terrain_slider.step = 1
	_terrain_slider.value = 32
	_terrain_slider.custom_minimum_size.x = 200
	_terrain_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_terrain_slider.tooltip_text = "32 shows all terrain levels. Lower values hide higher terrain."
	terrain.add_child(_terrain_slider)
	_terrain_value = Label.new()
	_terrain_value.text = "32"
	_terrain_value.custom_minimum_size.x = 30
	terrain.add_child(_terrain_value)
	_terrain_slider.value_changed.connect(func(value: float) -> void:
		_terrain_value.text = str(int(value))
		main_control.call("_debug_set_visible_altitude_levels", int(value)))
	_action_label = Label.new()
	_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_action_label)


func _action_section(parent: VBoxContainer, caption: String, columns: int) -> GridContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 15)
	section.add_child(label)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	section.add_child(grid)

	return grid


func _button(parent: Control, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_F12 or (event.keycode == KEY_ESCAPE and is_open):
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
	var levels := int(_metrics.get("visible_altitude_levels", 32))
	_terrain_slider.set_value_no_signal(levels)
	_terrain_value.text = str(levels)
	_no_disasters_check.set_pressed_no_signal(bool(_metrics.get("no_disasters", false)))
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


static func _create_debug_theme() -> Theme:
	var theme := ClassicUiStyle.create_dialog_theme()
	var ink := Color("f0f3f6")
	var paper := Color("161b22")
	var face := Color("252a30")
	var border := Color("4a5664")
	var selection := Color("1f5c99")
	theme.set_stylebox("panel", "PanelContainer", ClassicUiStyle.create_box(face, border, 1))

	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, "CheckBox", ink)

	theme.set_color("font_color", "Label", ink)

	for control in ["Button", "OptionButton"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(state, control, ink)

		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var fill := Color("354252") if state in ["hover", "focus"] else selection if state in ["pressed", "hover_pressed"] else face
			theme.set_stylebox(state, control, ClassicUiStyle.create_box(fill, border, 1, 8, 5))

	# define every content surface and its text together. do not inherit
	# black classic-shell text on the debug window's dark backgrounds
	theme.set_stylebox("panel", "TabContainer", ClassicUiStyle.create_box(face, border, 1, 8, 8))

	for state in ["selected", "unselected", "hovered", "disabled"]:
		theme.set_stylebox("tab_" + state, "TabContainer", ClassicUiStyle.create_box(Color("354252") if state == "selected" else face, border, 1, 12, 6))
		theme.set_color("font_" + state + "_color", "TabContainer", ink if state != "disabled" else Color("86909e"))

	theme.set_stylebox("panel", "Tree", ClassicUiStyle.create_box(paper, border, 1))
	theme.set_color("font_color", "Tree", ink)
	theme.set_color("font_hovered_color", "Tree", ink)
	theme.set_color("font_selected_color", "Tree", Color.WHITE)
	theme.set_color("title_button_color", "Tree", ink)

	for state in ["normal", "hover", "pressed"]:
		theme.set_stylebox("title_button_" + state, "Tree", ClassicUiStyle.create_box(face, border, 1, 6, 5))

	for state in ["selected", "selected_focus"]:
		theme.set_stylebox(state, "Tree", ClassicUiStyle.create_box(selection, selection, 0))

	theme.set_stylebox("hover", "Tree", ClassicUiStyle.create_box(Color("2f3b49"), border, 0))
	theme.set_stylebox("normal", "LineEdit", ClassicUiStyle.create_box(paper, border, 1))
	theme.set_color("font_color", "LineEdit", ink)
	theme.set_color("font_selected_color", "LineEdit", Color.WHITE)
	theme.set_color("selection_color", "LineEdit", selection)
	theme.set_stylebox("panel", "PopupMenu", ClassicUiStyle.create_box(paper, border, 1))
	theme.set_stylebox("hover", "PopupMenu", ClassicUiStyle.create_box(selection, selection, 0))
	theme.set_color("font_color", "PopupMenu", ink)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	return theme
