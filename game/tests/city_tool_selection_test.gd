extends SceneTree


class TestToolbar extends CityToolbar:
	func show_tool_group(_group_index: int, _city: CityState, _icon_provider: Callable = Callable()) -> int:
		return 0


class TestMenus extends ApplicationMenus:
	func set_overlay(mode: CityViewMode.Mode) -> void:
		app.view_state.overlay_mode = mode


class TestCurrentTool extends ApplicationCurrentTool:
	func update_edit_state() -> void:
		pass


	func _sync_child_tool_selection() -> void:
		pass


class TestStaticRender extends ApplicationStaticRender:
	func refresh_after_city_edit(_command: EditCommandResult) -> void:
		pass


class TestCityEdits extends ApplicationCityEdits:
	var applied_tools: Array[Vector2i] = []


	func apply_map_selection(_start: Vector2i, _finish: Vector2i, _path: Array[Vector2i], _dragged: bool) -> void:
		applied_tools.append(Vector2i(app.tool_state.selected_group, app.tool_state.selected_subtool))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_catalog_indices()
	_command_selection()
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	var original := city.document.serialize().data
	_edit_state(city)
	_selection(city)
	assert(city.document.serialize().data == original)
	await _scurk_selection()
	print("PASS: city tool indices, view gating, selection guards, dispatch recall, and SCURK edit routing")
	quit()


func _catalog_indices() -> void:
	# The table slots are an external numeric contract. Keep these expectations independent.
	var groups := [
		[CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer, 0, 8],
		[CityToolIds.Group.LANDSCAPE, CityToolIds.Landscape, 12, 4],
		[CityToolIds.Group.DISPATCH, CityToolIds.Dispatch, 24, 4],
		[CityToolIds.Group.POWER, CityToolIds.Power, 36, 11],
		[CityToolIds.Group.WATER, CityToolIds.Water, 48, 5],
		[CityToolIds.Group.REWARDS, CityToolIds.Rewards, 60, 9],
		[CityToolIds.Group.ROADS, CityToolIds.Roads, 72, 5],
		[CityToolIds.Group.RAIL, CityToolIds.Rail, 84, 5],
		[CityToolIds.Group.PORTS, CityToolIds.Ports, 96, 2],
		[CityToolIds.Group.RESIDENTIAL, CityToolIds.Residential, 108, 2],
		[CityToolIds.Group.COMMERCIAL, CityToolIds.Commercial, 120, 2],
		[CityToolIds.Group.INDUSTRIAL, CityToolIds.Industrial, 132, 2],
		[CityToolIds.Group.EDUCATION, CityToolIds.Education, 144, 4],
		[CityToolIds.Group.SERVICES, CityToolIds.Services, 156, 4],
		[CityToolIds.Group.RECREATION, CityToolIds.Recreation, 168, 5],
		[CityToolIds.Group.SIGNS, CityToolIds.Signs, 180, 1],
		[CityToolIds.Group.QUERY, CityToolIds.Query, 192, 2],
		[CityToolIds.Group.CENTERING, CityToolIds.Centering, 204, 1],
	]
	for row: Array in groups:
		var subtools: Dictionary = row[1]
		assert(ToolCatalog.group(row[0]).tools.size() == row[3])
		assert(subtools.size() == row[3])
		var slot := 0
		for subtool: int in subtools.values():
			var tool := ToolCatalog.tool(row[0], subtool)
			assert(tool != null and tool.table_index == row[2] + slot)
			slot += 1

	assert(ToolCatalog.tool(-1, 0) == null)
	assert(ToolCatalog.tool(18, 0) == null)
	assert(ToolCatalog.tool(CityToolIds.Group.POWER, -1) == null)
	assert(ToolCatalog.tool(CityToolIds.Group.POWER, 11) == null)
	var coal := ToolCatalog.tool(CityToolIds.Group.POWER, CityToolIds.Power.COAL)
	assert(coal.cost == 4000 and coal.area == 4)
	var pipes := ToolCatalog.tool(CityToolIds.Group.WATER, CityToolIds.Water.PIPES)
	assert(pipes.cost == 3 and pipes.area == 1)


func _command_selection() -> void:
	# Input pairs are independent expectations for each command's accepted city tools.
	var commands := [
		[HydroCommand.supports_tool, [Vector2i(3, 3)]],
		[TunnelCommand.supports_tool, [Vector2i(6, 2)]],
		[OnrampCommand.supports_tool, [Vector2i(6, 3)]],
		[SubwayToRailCommand.supports_tool, [Vector2i(7, 4)]],
		[HighwayCommand.supports_tool, [Vector2i(6, 1)]],
		[DemolishCommand.supports_tool, [Vector2i(0, 0)]],
		[TerrainCommand.supports_tool, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]],
		[DispatchCommand.supports_tool, [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]],
		[ZoneCommand.supports_tool, [Vector2i(0, 4), Vector2i(8, 0), Vector2i(8, 1), Vector2i(9, 0),
			Vector2i(9, 1), Vector2i(10, 0), Vector2i(10, 1), Vector2i(11, 0), Vector2i(11, 1)]],
	]
	for row: Array in commands:
		var supports: Callable = row[0]
		var accepted: Array = row[1]
		for group in range(-1, 19):
			for subtool in range(-1, 13):
				assert(bool(supports.call(group, subtool)) == accepted.has(Vector2i(group, subtool)))


func _edit_state(city: CityState) -> void:
	var cases := [
		[CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.DEMOLISH, "rectangle", 1, false, true, false],
		[CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.RAISE, "path", 1, false, false, false],
		[CityToolIds.Group.LANDSCAPE, CityToolIds.Landscape.TREES, "path", 1, true, false, false],
		[CityToolIds.Group.LANDSCAPE, CityToolIds.Landscape.FOREST, "point", 7, true, false, false],
		[CityToolIds.Group.WATER, CityToolIds.Water.PIPES, "path", 1, false, true, false],
		[CityToolIds.Group.WATER, CityToolIds.Water.PUMP, "point", 1, false, false, false],
		[CityToolIds.Group.RAIL, CityToolIds.Rail.SUBWAY, "path", 1, false, true, false],
		[CityToolIds.Group.SIGNS, CityToolIds.Signs.SIGN, "point", 1, false, false, false],
		[CityToolIds.Group.QUERY, CityToolIds.Query.QUERY, "point", 1, false, true, true],
		[CityToolIds.Group.QUERY, CityToolIds.Query.TRIP_REACH, "point", 1, false, true, true],
		[CityToolIds.Group.CENTERING, CityToolIds.Centering.CENTER, "point", 1, false, true, true],
	]
	for row: Array in cases:
		for mode: CityViewMode.Mode in [CityViewMode.Mode.CITY, CityViewMode.Mode.UNDERGROUND, CityViewMode.Mode.CRIME]:
			var state := ToolEditState.normal(city, mode, row[0], row[1])
			assert(state.available and state.show_status)
			var enabled: bool = mode == CityViewMode.Mode.CITY or (mode == CityViewMode.Mode.UNDERGROUND and row[5]) or (mode == CityViewMode.Mode.CRIME and row[6])
			assert(state.enabled == enabled, "Tool (%d, %d), view %d" % [row[0], row[1], mode])
			assert(state.selection == row[2] and state.area == row[3] and state.landscape == row[4])
		var missing := ToolEditState.normal(null, CityViewMode.Mode.CITY, row[0], row[1])
		assert(not missing.available and not missing.enabled and not missing.show_status)

	var recall := ToolEditState.normal(city, CityViewMode.Mode.CITY, CityToolIds.Group.DISPATCH, CityToolIds.Dispatch.RECALL)
	assert(recall.available and not recall.enabled)


func _selection(city: CityState) -> void:
	var app := CityApplication.new()
	app.document_state.city = city
	app.city_toolbar = TestToolbar.new()
	app.add_child(app.city_toolbar)
	app.status_label = Label.new()
	app.add_child(app.status_label)
	app.current_tool = TestCurrentTool.new(app)
	app.menus = TestMenus.new(app)
	app.static_render = TestStaticRender.new(app)
	var city_edits := TestCityEdits.new(app)
	app.city_edits = city_edits

	for mode: CityViewMode.Mode in [CityViewMode.Mode.CITY, CityViewMode.Mode.UNDERGROUND]:
		for group in [CityToolIds.Group.QUERY, CityToolIds.Group.CENTERING, CityToolIds.Group.BULLDOZER]:
			app.view_state.overlay_mode = mode
			app.current_tool.select_tool_group(group)
			assert(app.tool_state.selected_group == group and app.view_state.overlay_mode == mode)

	app.current_tool.select_tool_group(CityToolIds.Group.WATER)
	assert(app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND)
	app.current_tool.select_subtool(CityToolIds.Water.PUMP)
	assert(app.view_state.overlay_mode == CityViewMode.Mode.CITY)
	app.current_tool.select_tool_group(CityToolIds.Group.RAIL)
	app.current_tool.select_subtool(CityToolIds.Rail.SUBWAY)
	assert(app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND)
	app.current_tool.select_tool_group(CityToolIds.Group.BULLDOZER)
	app.current_tool.select_subtool(CityToolIds.Bulldozer.RAISE)
	assert(app.view_state.overlay_mode == CityViewMode.Mode.CITY)
	app.current_tool.select_subtool(CityToolIds.Bulldozer.STRETCH)
	assert(app.tool_state.selected_subtool == CityToolIds.Bulldozer.RAISE)
	app.current_tool.select_tool_group(CityToolIds.Group.LANDSCAPE)
	app.current_tool.select_subtool(CityToolIds.Landscape.FOREST)
	assert(app.tool_state.selected_subtool == CityToolIds.Landscape.FOREST)
	app.current_tool.select_tool_group(-1)
	app.current_tool.select_tool_group(18)
	assert(app.tool_state.selected_group == CityToolIds.Group.LANDSCAPE)

	app.tool_state.landscape_editor = true
	for group in [CityToolIds.Group.BULLDOZER, CityToolIds.Group.LANDSCAPE, CityToolIds.Group.QUERY, CityToolIds.Group.CENTERING]:
		app.current_tool.select_tool_group(group)
		assert(app.tool_state.selected_group == group)
		app.current_tool.select_tool_group(CityToolIds.Group.POWER)
		assert(app.tool_state.selected_group == group)
	app.current_tool.select_tool_group(CityToolIds.Group.BULLDOZER)
	app.current_tool.select_subtool(CityToolIds.Bulldozer.DEZONE)
	assert(app.tool_state.selected_subtool == CityToolIds.Bulldozer.DEMOLISH)
	app.current_tool.select_subtool(CityToolIds.Bulldozer.RAISE_SEA)
	app.current_tool.select_subtool(CityToolIds.Bulldozer.LOWER_SEA)
	assert(city_edits.applied_tools == [Vector2i(0, 6), Vector2i(0, 7)])
	app.current_tool.select_tool_group(CityToolIds.Group.QUERY)
	app.current_tool.select_subtool(CityToolIds.Query.TRIP_REACH)
	assert(app.tool_state.selected_subtool == CityToolIds.Query.QUERY)
	app.tool_state.landscape_editor = false

	var dispatched := DispatchCommand.apply(city, CityToolIds.Group.DISPATCH, CityToolIds.Dispatch.MILITARY, Vector2i(8, 8))
	assert(dispatched.ok)
	var dispatched_bytes := city.document.serialize().data
	app.current_tool.select_tool_group(CityToolIds.Group.DISPATCH)
	app.tool_state.dispatch_cycles = PackedInt32Array([1, 2, 3])
	app.tool_state.dispatch_initialized = true
	app.current_tool.select_subtool(CityToolIds.Dispatch.RECALL)
	assert(app.tool_state.selected_subtool == CityToolIds.Dispatch.POLICE)
	assert(app.tool_state.dispatch_cycles == PackedInt32Array([0, 0, 0]) and not app.tool_state.dispatch_initialized)
	var recalled := app.tool_state.last_edit_command as DispatchEditResult
	assert(recalled != null and recalled.ok and city.text_overlay_id(8, 8) == 0)
	assert(DispatchCommand.undo(city, recalled).ok)
	assert(city.document.serialize().data == dispatched_bytes)
	assert(DispatchCommand.undo(city, dispatched).ok)
	app.free()


func _scurk_selection() -> void:
	var window := preload("res://src/ui/scurk/scurk_place_print_control.tscn").instantiate() as ScurkPlacePrintControl
	window.hide()
	root.add_child(window)
	await process_frame
	var emitted: Array[Vector3i] = []
	window.edit_tool_selected.connect(func(group: int, subtool: int, zone: int) -> void:
		emitted.append(Vector3i(group, subtool, zone)))
	# City tool pairs and saved zone overrides are separate numeric contracts.
	var expected := [
		[0, 0, -1, "either"], [0, 1, -1, "city"], [0, 2, -1, "city"],
		[0, 3, -1, "city"], [0, 4, 0, "city"], [1, 1, -1, "city"],
		[4, 0, -1, "underground"], [9, 0, 1, "city"], [9, 1, 2, "city"],
		[10, 0, 3, "city"], [10, 1, 4, "city"], [11, 0, 5, "city"],
		[11, 1, 6, "city"], [8, 0, 9, "city"], [8, 1, 8, "city"],
		[8, 0, 7, "city"], [6, 0, -1, "city"], [6, 1, -1, "city"],
		[6, 2, -1, "city"], [6, 3, -1, "city"], [3, 0, -1, "city"],
		[7, 0, -1, "city"], [7, 1, -1, "underground"],
		[7, 4, -1, "underground"], [17, 0, -1, "either"],
	]
	assert(window.selected_edit_tool() == null)
	assert(window.tool_list.item_count == expected.size())

	for index in expected.size():
		var row: Array = expected[index]
		assert(window.select_edit_tool(index))
		assert(emitted.size() == index + 1 and emitted[-1] == Vector3i(row[0], row[1], row[2]))
		var selected := window.selected_edit_tool()
		assert(selected != null and [selected.group, selected.subtool, selected.zone, selected.view] == row)
		assert(ToolCatalog.tool(selected.group, selected.subtool) != null)

		if selected.zone >= 0:
			_scurk_zone_selection(selected)

	assert(window.select_edit_tool(15, false))
	assert(emitted.size() == 25 and window.selected_edit_tool().zone == 7)
	assert(not window.select_edit_tool(-1) and not window.select_edit_tool(25))
	assert(window.selected_edit_index == 15 and emitted.size() == 25)
	window.free()


func _scurk_zone_selection(tool: ScurkEditTool) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	var point := Vector2i(8, 8)
	assert(city.set_zone_id(point.x, point.y, 2 if tool.zone == 1 else 1))
	var before := city.document.serialize().data
	var funds := city.funds()
	var command := ZoneCommand.apply_rectangle(city, tool.group, tool.subtool, point, point, false, true, tool.zone)
	assert(command.ok and command.tile_indices.size() == 1 and command.cost == 0)
	assert(city.zone_id(point.x, point.y) == tool.zone and city.funds() == funds)
	assert(ZoneCommand.undo(city, command).ok)
	assert(city.document.serialize().data == before)
