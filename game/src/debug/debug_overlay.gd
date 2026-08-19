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
var _detailed_timing_check: CheckBox


func setup(value: Control) -> void:
	main_control = value


func _ready() -> void:
	_window = $DebugWindow
	_window.hide()
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
	for tab_name in ["MicroSims", "Objects"]:
		(tabs.get_node(tab_name) as DebugRecordTable).locate_requested.connect(_locate_on_map)
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
			main_control.frame.call("select_speed", _resume_speed)
		else:
			_resume_speed = int(_metrics.get("speed_id", 2))
			main_control.frame.call("select_speed", 1))

	for action in [["Center map", "debug_center_map"], ["Full redraw", "debug_full_redraw"],
		["Clear render caches", "debug_clear_render_caches"]]:
		var method := str(action[1])
		_button(simulation, action[0], func() -> void:
			_invoke(method))

	for mode: CityViewMode.Mode in [CityViewMode.Mode.CITY, CityViewMode.Mode.UNDERGROUND]:
		_button(simulation, CityViewMode.key(mode).capitalize() + " view", func() -> void:
			main_control.menus.call("set_overlay", mode))

	_button(simulation, "Print metrics", func() -> void:
		print(_metrics))
	_detailed_timing_check = CheckBox.new()
	_detailed_timing_check.text = "Detailed per-tile timing"
	_detailed_timing_check.tooltip_text = "Break the growth scan into its per-tile steps. The extra clock reads are measured work and slow the phase."
	_detailed_timing_check.toggled.connect(func(enabled: bool) -> void:
		_record_action(main_control.debug.call("debug_set_detailed_timing", enabled)))
	simulation.add_child(_detailed_timing_check)
	var cheats := _action_section(box, "City cheats", 3)

	for amount in [10000, 100000, 1000000]:
		_button(cheats, "+$%d" % amount, func() -> void:
			_record_action(main_control.debug.call("debug_add_funds", amount)))

	_button(cheats, "Unlock everything", func() -> void:
		_invoke("debug_unlock_everything"))
	_button(cheats, "Call Maxis Man", func() -> void:
		_invoke("debug_dispatch_maxis_man"))
	var disasters := _action_section(box, "Disasters", 3)
	var disaster := OptionButton.new()
	disaster.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for caption in DISASTER_NAMES:
		disaster.add_item(caption)

	disasters.add_child(disaster)
	_button(disasters, "Start at view center", func() -> void:
		_record_action(main_control.debug.call("debug_start_disaster", disaster.selected + 1)))
	_button(disasters, "End active disaster", func() -> void:
		_invoke("debug_end_disaster"))
	_no_disasters_check = CheckBox.new()
	_no_disasters_check.text = "Disable random disasters"
	_no_disasters_check.toggled.connect(func(enabled: bool) -> void:
		_record_action(main_control.debug.call("debug_set_no_disasters", enabled)))
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
		main_control.debug.call("debug_set_visible_altitude_levels", int(value)))
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
	var result: Variant = main_control.debug.call(method)

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


func _locate_on_map(site: Rect2i) -> void:
	var map_view := main_control.get("map_view") as CityMapControl if is_instance_valid(main_control) else null

	if map_view != null and map_view.center_on_tiles(site.position, site.end - Vector2i.ONE) and is_open:
		toggle()


func _process(delta: float) -> void:
	if not is_open:
		return

	_sample_elapsed += delta

	if _sample_elapsed >= SAMPLE_INTERVAL_SECONDS:
		_sample_elapsed = 0.0
		_refresh_metrics()


func _history() -> SimulationTimingHistory:
	var timings: TimingState = main_control.get("timing_state") as TimingState if main_control != null else null

	if timings != null:
		return timings.simulation_timings

	return null


func _refresh_metrics() -> void:
	if not is_instance_valid(main_control):
		return

	_metrics = main_control.debug.call("debug_metrics")

	if _days == null:
		return

	var levels := int(_metrics.get("visible_altitude_levels", 32))
	_terrain_slider.set_value_no_signal(levels)
	_terrain_value.text = str(levels)
	_no_disasters_check.set_pressed_no_signal(bool(_metrics.get("no_disasters", false)))
	_detailed_timing_check.set_pressed_no_signal(bool(_metrics.get("detailed_timing", false)))
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

	# include intermediate groups even when they have no measured total
	var desired: Dictionary = {}

	for label: String in samples:
		var parts := label.split(" / ")
		var first := 1 if parts[0].begins_with("Day ") else 0
		var path := parts[0] if first == 1 else ""

		for index in range(first, parts.size()):
			path += (" / " if not path.is_empty() else "") + parts[index]
			desired[path] = true

	# free descendants first. treeitem.free() also frees its children
	var old_labels := _step_rows.keys()
	old_labels.sort()
	old_labels.reverse()

	for label: String in old_labels:
		if not desired.has(label):
			_step_rows[label].free()
			_step_rows.erase(label)

	var labels := desired.keys()
	labels.sort()

	for label: String in labels:
		var row: TreeItem = _step_rows.get(label)

		if row == null:
			var parts := label.split(" / ")
			var parent_path := label.get_slice(" / ", 0)
			var parent: TreeItem
			var depth := parts.size()

			if parts.size() > 1:
				parent_path = label.left(label.rfind(" / "))
				parent = _step_rows.get(parent_path)

			if parts[0].begins_with("Day "):
				depth -= 1

				if parent == null:
					parent = _day_rows[int(parts[0].trim_prefix("Day ")) - 1]

			if parent == null:
				if _other_steps == null:
					_other_steps = _days.create_item(_days.get_root())
					_other_steps.set_text(1, "Other simulation work")
					_other_steps.set_tooltip_text(1, "Moving objects, disasters and jobs without a recorded day association.")
					_other_steps.collapsed = true

				parent = _other_steps

			row = _days.create_item(parent)
			row.set_text(1, "      ".repeat(depth) + parts[-1])
			row.set_tooltip_text(1, label)
			row.set_tooltip_text(5, "One sample per measured phase execution. Repeated tile and network work is summed. Phase totals include their detail rows; do not add both. Groups without measured totals show a dash.")
			_step_rows[label] = row

		_stats(row, 2, samples.get(label, {}))

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
	return AppUiTheme.current()

func _refresh_record_tab(force := false) -> void:
	if not is_open or _tabs == null:
		return

	var tab := _tabs.get_current_tab_control()

	if tab is DebugRecordTable:
		tab.refresh_from_host(main_control, force)
