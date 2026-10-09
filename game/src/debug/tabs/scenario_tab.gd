class_name CityDebugScenarioTab
extends DebugWindowTab
## The scenario goals with their current values, and the disaster preview. The
## preview runs the disaster in a copy of the simulation and shows the tiles
## that it would change as the Disaster Preview tile layer.

const COLUMNS := ["Goal", "Current", "Required", "Status"]
const REFRESH_MSEC := 1000
const GOALS := DebugCityTables.SCENARIO_GOALS

var heading: Label
var table: Tree
var disaster_choice: OptionButton
var ticks: SpinBox
var result_label: Label
var _refreshed_at := -REFRESH_MSEC
var _scenario_disaster := Vector2i(-1, -1)


func _init() -> void:
	name = "Scenario"
	heading = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(heading)
	var locate := HBoxContainer.new()
	add_child(locate)
	make_button(locate, "Center on scenario disaster", "Move the view to the tile where the scenario disaster starts.", _locate)
	table = make_table(COLUMNS, 0)
	table.custom_minimum_size.y = 220
	add_child(table)
	var title := Label.new()
	title.text = "Disaster preview"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)
	var controls := HBoxContainer.new()
	add_child(controls)
	disaster_choice = OptionButton.new()

	for item in CityMenuBar.DISASTER_ITEMS:
		disaster_choice.add_item(item[0], int(item[1]))

	controls.add_child(disaster_choice)
	var caption := Label.new()
	caption.text = "Ticks"
	controls.add_child(caption)
	ticks = SpinBox.new()
	ticks.min_value = 1
	ticks.max_value = DisasterPreview.MAX_TICKS
	ticks.value = CityDebugMenu.PREVIEW_TICKS
	ticks.tooltip_text = "Disaster ticks to run in the copy. The first tick runs with the start."
	controls.add_child(ticks)
	make_button(controls, "Preview at view center", ("Start the disaster at the view center in a copy of the simulation, run the " +
		"ticks, and show the tiles that change. The city does not change."), _preview)
	result_label = Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(result_label)


func refresh(force := false) -> void:
	if not force and Time.get_ticks_msec() - _refreshed_at < REFRESH_MSEC:
		return

	_refreshed_at = Time.get_ticks_msec()
	table.clear()
	var app := application()
	var engine: SimulationEngine = app.simulation_state.simulation_engine if app != null else null
	var scenario := engine.scenario if engine != null else null
	_scenario_disaster = Vector2i(-1, -1)

	if scenario == null or not scenario.is_valid():
		heading.text = "This city has no active scenario."

		return

	var goals := scenario.evaluate_goals(engine.city)
	var disaster := CityMenuBar.disaster_name(scenario.disaster_type) if scenario.disaster_type > 0 else "None"
	_scenario_disaster = Vector2i(scenario.disaster_x, scenario.disaster_y) if scenario.disaster_type > 0 else Vector2i(-1, -1)
	heading.text = tr("%d months left. Scenario disaster: %s%s. %s") % [scenario.time_limit_months, disaster,
		" at %d, %d" % [scenario.disaster_x, scenario.disaster_y] if scenario.disaster_type > 0 else "",
		("All goals are met." if goals.met else "%d goals are not met." % goals.unmet.size()) if goals.ok else goals.error]
	var root := table.create_item()

	for row in goal_rows(scenario, goals):
		var item := table.create_item(root)

		for column in row.size():
			item.set_text(column, str(row[column]))

		if row[3] == "Not met":
			for column in COLUMNS.size():
				item.set_custom_bg_color(column, DebugRecordTable.WARNING_COLOR)


# rows of goal, current value, requirement and status
static func goal_rows(scenario: ScenarioState, goals: ScenarioState.Goals) -> Array:
	var rows := []

	if not goals.ok:
		return rows

	var targets: Array = GOALS.duplicate()

	for pair in [["first_building", "first_building_tiles", "first_building_tile_count", "first_building_id"],
		["second_building", "second_building_tiles", "second_building_tile_count", "second_building_id"]]:
		if int(scenario.get(pair[3])) != BuildingTileIds.EMPTY:
			targets.append([pair[0], pair[1], pair[2], false])

	for goal: Array in targets:
		var required := int(scenario.get(goal[2]))
		var limit: bool = goal[3]
		var off: bool = required <= 0 and (limit or goal[0] == "city_size")
		var status := "Off" if off else ("Not met" if goal[0] in goals.unmet else "Met")
		var requirement := "-" if off else ("at most %d" % required if limit else "at least %d" % required)
		rows.append([str(goal[0]).capitalize(), int(goals.values.get(goal[1], 0)), requirement, status])

	return rows


func _preview() -> void:
	var app := application()

	if app == null:
		return

	var message := app.debug_tools.checks.preview_disaster(disaster_choice.get_selected_id(), int(ticks.value))
	result_label.text = message
	report(message)


func _locate() -> void:
	var app := application()

	if app == null or _scenario_disaster.x < 0:
		report("The scenario has no disaster tile.")

		return

	app.map_view.center_on_tile(_scenario_disaster)
	report("Centered on the scenario disaster tile %d, %d." % [_scenario_disaster.x, _scenario_disaster.y])
