extends SceneTree
## Debug mode in the running application: the Debug window choice, the Debug
## menu, the debug query tools, the tile layers, the change baseline, the render
## and moving thing overlays, the performance HUD and the debug capture.

const AppFixture = preload("res://tests/support/app_fixture.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")
const Layer = DebugTileLayers.Layer
# a refresh waits for its timer and for a worker thread
const WAIT_MSEC := 10000


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	AppFixture.configure(main)
	root.add_child(main)
	await process_frame
	assert(main.asset_state.assets_ready)
	main.city_files._load_city_unchecked(GeneratedCityFixture.path(128))
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	var city := main.document_state.city
	var original := city.document.serialize().data
	main.debug_tools.set_debug_mode(false)
	await process_frame

	_check_hidden_tools(main)
	_enable_from_debug_window(main)
	await _check_inspector(main, city)
	await _check_layers(main, city)
	await _check_render_views(main)
	_check_capture(main)
	_check_disable(main)
	assert(city.document.serialize().data == original, "Debug views do not change the city")
	main.queue_free()
	await process_frame
	print("PASS: debug mode toggle, Debug menu, debug query tools, tile layers, change baseline, overlays, HUD and capture")
	quit()


func _check_hidden_tools(main: CityApplication) -> void:
	assert(not main.city_menu_bar.debug_menu.visible, "The Debug menu is hidden outside debug mode")
	main.current_tool.select_tool_group(CityToolIds.Group.QUERY)
	main.current_tool.select_subtool(CityToolIds.Query.TRIP_REACH)
	assert(main.tool_state.selected_subtool == CityToolIds.Query.QUERY, "Trip Query needs debug mode")
	main.current_tool.select_subtool(CityToolIds.Query.TILE_INSPECTOR)
	assert(main.tool_state.selected_subtool == CityToolIds.Query.QUERY, "Tile Inspector needs debug mode")


func _enable_from_debug_window(main: CityApplication) -> void:
	main.debug_overlay.toggle()
	main.debug_overlay.debug_mode_check.button_pressed = true
	assert(DebugMode.enabled and main.preferences.debug_mode)
	assert(main.city_menu_bar.debug_menu.visible, "Debug mode shows the Debug menu")
	assert(AppSettingsStore.load_values(main.preferences.settings_path).debug_mode, "The choice is kept")
	main.debug_overlay.toggle()


func _check_inspector(main: CityApplication, city: CityState) -> void:
	main.debug_tools.on_debug_menu(CityDebugMenu.MENU_TRIP_QUERY)
	assert(main.tool_state.selected_group == CityToolIds.Group.QUERY)
	assert(main.tool_state.selected_subtool == CityToolIds.Query.TRIP_REACH)
	main.debug_tools.on_debug_menu(CityDebugMenu.MENU_TILE_INSPECTOR)
	assert(main.tool_state.selected_subtool == CityToolIds.Query.TILE_INSPECTOR)
	var view := main.map_view.debug_view
	assert(view.inspector_active)
	var point := Vector2i(64, 64)
	main.city_edits._apply_view_tool(point)
	assert(view.pinned_tile == point, "A click pins the inspector")
	main.map_view.queue_redraw()
	await process_frame
	assert(view.inspector.visible and view.inspector.text().begins_with("Tile         64, 64"), view.inspector.text())
	assert(main.debug_tools.render_views.line_sets.has("pinned"))
	assert(main.debug_tools.unpin_inspector() and view.pinned_tile.x < 0)
	assert(not main.debug_tools.unpin_inspector())


func _check_layers(main: CityApplication, city: CityState) -> void:
	var tools := main.debug_tools
	var view := main.map_view.debug_view
	tools.on_debug_menu(CityDebugMenu.LAYER_BASE + Layer.ZONE_TYPE)
	assert(tools.state.tile_layer == Layer.ZONE_TYPE)
	await _wait_values(main, Layer.ZONE_TYPE)
	assert(view.tile_layer.mesh != null and view.tile_layer.window_tiles > 0)
	var zoned := _find_tile(city, func(x: int, y: int) -> bool: return city.zone_id(x, y) != 0)
	assert(DebugLayerValues.value_at(tools.tile_views.values, 128, zoned) == city.zones[city.index_of(zoned.x, zoned.y)])
	view.pinned_tile = zoned
	assert(tools._inspector_text(zoned).contains("Debug layer  Zone Type (XZON):"))
	view.pinned_tile = Vector2i(-1, -1)

	tools.on_debug_menu(CityDebugMenu.LAYER_BASE + Layer.POWER_GRIDS)
	await _wait_values(main, Layer.POWER_GRIDS)
	assert(view.legend_summary.contains("networks"), view.legend_summary)

	tools.on_debug_menu(CityDebugMenu.MENU_TILE_VALUES)
	main.map_view.zoom_factor = 4.0
	main.map_view.center_on_tile(zoned)
	await _wait_frames(4)
	await _wait_until(func() -> bool: return not tools.tile_views.value_labels.is_empty())
	tools.on_debug_menu(CityDebugMenu.MENU_TILE_VALUES)
	await _wait_until(func() -> bool: return tools.tile_views.value_labels.is_empty())

	# a change snapshot, then one changed tile
	tools.on_debug_menu(CityDebugMenu.LAYER_BASE + Layer.CHANGED_TILES)
	tools.on_debug_menu(CityDebugMenu.MENU_TAKE_SNAPSHOT)
	assert(tools.state.change_baseline == DebugViewState.ChangeBaseline.SNAPSHOT)
	await _wait_values(main, Layer.CHANGED_TILES)
	var empty := _find_tile(city, func(x: int, y: int) -> bool: return city.building_id(x, y) == 0)
	city.set_building_id(empty.x, empty.y, BuildingTileIds.TREES_1)
	await _wait_until(func() -> bool: return tools.tile_views.changed_tiles == 1)
	assert(view.legend_summary.begins_with("1 tiles changed since snapshot: Building 1"), view.legend_summary)
	city.set_building_id(empty.x, empty.y, 0)
	await _wait_until(func() -> bool: return tools.tile_views.changed_tiles == 0)

	tools.on_debug_menu(CityDebugMenu.LAYER_BASE + Layer.NONE)
	await process_frame
	assert(view.tile_layer.mesh == null and not view.legend.visible)


func _check_render_views(main: CityApplication) -> void:
	var tools := main.debug_tools
	main.map_view.zoom_factor = 1.0

	for id in [CityDebugMenu.MENU_REGION_BOUNDS, CityDebugMenu.MENU_THING_PATHS, CityDebugMenu.MENU_PERFORMANCE_HUD,
			CityDebugMenu.MENU_OCCLUDERS, CityDebugMenu.MENU_SPRITE_BOUNDS, CityDebugMenu.MENU_REGION_REPAINTS]:
		tools.on_debug_menu(id)

	assert(tools.state.region_bounds and tools.state.thing_paths and tools.state.performance_hud)
	await _wait_until(func() -> bool:
		return tools.render_views.line_sets.has("paths") and tools.render_views.line_sets.has("moving"))
	var lines := tools.render_views.line_sets
	assert(lines.has("paths") and lines.has("moving"), str(lines.keys()))

	# a headless run may draw the city without the region cache
	if main.render_caches.region_cache != null:
		assert(lines.has("regions") and lines.has("occluders") and lines.has("sprites"), str(lines.keys()))
		assert(tools.render_views.region_count > 0)

	assert(main.map_view.debug_view.hud.visible)
	assert(main.map_view.debug_view.hud._label.text.begins_with("FPS"))
	var metrics: Dictionary = main.debug.debug_metrics()
	assert(metrics.engine.has("draw_calls") and metrics.debug_views.enabled)
	tools.on_debug_menu(CityDebugMenu.MENU_REGION_BOUNDS)
	await _wait_until(func() -> bool: return not tools.render_views.line_sets.has("regions"))


func _check_capture(main: CityApplication) -> void:
	var folder := OS.get_temp_dir().path_join("opensc2k_debug_capture_%d" % OS.get_process_id())
	var message := DebugCapture.capture(main, main.debug_tools.state, folder)
	assert(message.begins_with("Saved a debug capture"), message)
	var captures := DirAccess.get_directories_at(folder)
	assert(captures.size() == 1)
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(captures[0]).path_join("state.json")))
	assert(record is Dictionary and record.camera.zoom_percent > 0 and record.debug_views.thing_paths)
	assert(record.metrics.has("engine"))

	for capture in captures:
		for file in DirAccess.get_files_at(folder.path_join(capture)):
			DirAccess.remove_absolute(folder.path_join(capture).path_join(file))

		DirAccess.remove_absolute(folder.path_join(capture))

	DirAccess.remove_absolute(folder)


func _check_disable(main: CityApplication) -> void:
	main.debug_tools.on_debug_menu(CityDebugMenu.MENU_TILE_INSPECTOR)
	main.debug_tools.set_debug_mode(false)
	assert(not DebugMode.enabled and not main.city_menu_bar.debug_menu.visible)
	assert(main.tool_state.selected_subtool == CityToolIds.Query.QUERY, "A debug tool falls back to Query")
	assert(not main.debug_tools.state.any_active())
	assert(not main.map_view.debug_view.hud.visible and not main.map_view.debug_view.inspector_active)
	assert(not AppSettingsStore.load_values(main.preferences.settings_path).debug_mode)


func _wait_values(main: CityApplication, layer: Layer) -> void:
	await _wait_until(func() -> bool:
		return main.debug_tools.tile_views.values != null and main.map_view.debug_view.tile_layer.layer == layer)


func _wait_until(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + WAIT_MSEC

	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return

		await process_frame

	assert(false, "A debug view did not refresh")


func _wait_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _find_tile(city: CityState, condition: Callable) -> Vector2i:
	for x in range(8, city.map_size - 8):
		for y in range(8, city.map_size - 8):
			if condition.call(x, y):
				return Vector2i(x, y)

	assert(false, "The fixture has no matching tile")

	return Vector2i(-1, -1)
