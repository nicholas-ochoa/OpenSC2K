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
var _day_rows: Array[TreeItem] = []
var _step_rows: Dictionary = {}
var _other_steps: TreeItem
var _tabs: TabContainer
var _metrics_tree: Tree
var _action_label: Label
var _resume_speed := 2
var _terrain_slider: HSlider
var _terrain_value: Label
var _no_disasters_check: CheckBox


func setup(value: Control) -> void:
	main_control = value


func _ready() -> void:
	_window = $DebugWindow
	_window.theme = _create_debug_theme()
	_window.close_requested.connect(toggle)
	_window.window_input.connect(_input)
	var box: VBoxContainer = $DebugWindow/Panel/Margin/Content
	box.get_node("Header/Reset").pressed.connect(_reset_averages)
	var tabs: TabContainer = box.get_node("Tabs")
	_tabs = tabs
	tabs.tab_changed.connect(func(_index: int) -> void: _refresh_record_tab())
	_days = tabs.get_node("Simulation")
	_configure_table(_days, ["Day", "What happens", "Average ms", "Last ms", "Max ms", "Samples"])
	_build_day_rows()
	_metrics_tree = tabs.get_node("Metrics")
	_build_actions(tabs)


func _reset_averages() -> void:
	var history := _history()

	if history != null:
		history.clear()

	_refresh_metrics()


func _configure_table(tree: Tree, titles: Array) -> void:
	for column in titles.size():
		tree.set_column_title(column, titles[column])
		tree.set_column_expand(column, column == (1 if titles.size() == 6 else 0))
		tree.set_column_custom_minimum_width(column, 68 if column == 0 and titles.size() == 6 else 95)


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

	var levels := int(_metrics.get("visible_altitude_levels", 32))
	_terrain_slider.set_value_no_signal(levels)
	_terrain_value.text = str(levels)
	_no_disasters_check.set_pressed_no_signal(bool(_metrics.get("no_disasters", false)))
	_refresh_day_rows(_history())

	_metrics_tree.refresh(_metrics)
	_refresh_record_tab()


func _build_day_rows() -> void:
	var base := _days.create_item()

	for day in 25:
		var row := _days.create_item(base)
		row.set_text(0, str(day + 1))
		row.set_text(1, SimulationTimingHistory.DAY_SUMMARIES[day])
		row.set_tooltip_text(1, SimulationTimingHistory.DAY_SUMMARIES[day])
		row.set_tooltip_text(5, "Day samples combine work resumed after a player prompt. Child steps count individual measurements.")
		row.collapsed = true
		_day_rows.append(row)


func _refresh_day_rows(history: SimulationTimingHistory) -> void:
	for day in 25:
		_stats(_day_rows[day], 2, history.days.get(day, {}) if history != null else {})

	var samples: Dictionary = history.steps if history != null else {}

	for label: String in _step_rows.keys():
		if not samples.has(label):
			_step_rows[label].free()
			_step_rows.erase(label)

	var labels := samples.keys()
	labels.sort()

	for label: String in labels:
		var row: TreeItem = _step_rows.get(label)

		if row == null:
			var parent: TreeItem
			var caption := label

			for day in 25:
				var prefix := "Day %02d / " % (day + 1)

				if label.begins_with(prefix):
					parent = _day_rows[day]
					caption = label.trim_prefix(prefix)
					break

			if parent == null:
				if _other_steps == null:
					_other_steps = _days.create_item(_days.get_root())
					_other_steps.set_text(1, "Other simulation work")
					_other_steps.set_tooltip_text(1, "Moving objects, disasters and jobs without a recorded day association.")
					_other_steps.collapsed = true

				parent = _other_steps

			row = _days.create_item(parent)
			row.set_text(1, "      " + caption)
			row.set_tooltip_text(1, label)
			_step_rows[label] = row

		_stats(row, 2, samples[label])

	if _other_steps != null and _other_steps.get_child_count() == 0:
		_other_steps.free()
		_other_steps = null


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


func _refresh_record_tab(force := false) -> void:
	if not is_open or _tabs == null:
		return

	var tab := _tabs.get_current_tab_control()

	if tab is DebugRecordTable:
		tab.refresh_from_host(main_control, force)
