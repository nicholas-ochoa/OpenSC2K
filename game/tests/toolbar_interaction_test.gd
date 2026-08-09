extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.map_view.zoom_factor = 0.25
	main.city_files.call("_load_city_unchecked", ProjectSettings.globalize_path("res://../references/SIMCITY2000/DEFAULT.SC2"))
	main.frame.call("select_speed", GameSpeedController.Speed.PAUSED)
	var toolbar := main.get("city_toolbar") as CityToolbar
	var map := main.get("map_view") as CityMapControl

	# Shared tools retain the selected layer and remain usable in either view.
	for mode: CityViewMode.Mode in [CityViewMode.Mode.CITY, CityViewMode.Mode.UNDERGROUND]:
		main.menus.call("set_overlay", mode)

		for group in [16, 17, 0]:
			toolbar.toolbar_buttons[group].pressed.emit()
			assert(main.get("overlay_mode") == mode and toolbar.view_mode_buttons[mode].button_pressed)
			assert(map.edit_enabled)
			main.current_tool.call("select_subtool", 0)
			assert(main.get("overlay_mode") == mode and map.edit_enabled)

			if group == 16:
				main.query_choices.call("open_query", Vector2i(20, 20))
				assert(main.query_dialog.visible and main.get("overlay_mode") == mode)
				main.query_choices.call("close_query")
			elif group == 17:
				main.camera_input.call("center_map_on_tile", Vector2i(20, 20))
				assert(main.get("overlay_mode") == mode)

	# Surface-only terrain tools still change back to the surface.
	main.current_tool.call("select_subtool", 2)
	assert(main.get("overlay_mode") == CityViewMode.Mode.CITY)
	main.current_tool.call("select_tool_group", 4)
	assert(main.get("overlay_mode") == CityViewMode.Mode.UNDERGROUND and toolbar.view_mode_buttons[CityViewMode.Mode.UNDERGROUND].button_pressed)
	main.menus.call("set_overlay", CityViewMode.Mode.CITY)
	main.current_tool.call("select_tool_group", 7)
	main.current_tool.call("select_subtool", 1)
	assert(main.get("overlay_mode") == CityViewMode.Mode.UNDERGROUND and toolbar.view_mode_buttons[CityViewMode.Mode.UNDERGROUND].button_pressed)
	main.menus.call("set_overlay", CityViewMode.Mode.CITY)
	main.current_tool.call("select_tool_group", 17)
	assert(not map.show_selection_preview)
	main.current_tool.call("select_tool_group", 6)
	main.current_tool.call("select_subtool", 1)
	assert(map.highway_preview)

	for group in [3, 6, 7]:
		main.current_tool.call("select_tool_group", group)
		await process_frame
		toolbar.child_tool_scroll.scroll_vertical = 100
		main.current_tool.call("select_tool_group", 3 if group != 3 else 6)
		await process_frame
		assert(toolbar.child_tool_scroll.scroll_vertical == 0)

	# Let the hold timer expire after a short press; the menu stays closed.
	toolbar.toolbar_buttons[6].button_down.emit()
	toolbar.toolbar_buttons[6].button_up.emit()
	toolbar.toolbar_buttons[6].pressed.emit()
	await create_timer(CityToolbar.HOLD_SECONDS + 0.05).timeout
	assert(not toolbar.hold_menu.visible and main.get("selected_group") == 6)
	# A hold opens the same icon, price and availability palette.
	toolbar.toolbar_buttons[7].button_down.emit()
	await create_timer(CityToolbar.HOLD_SECONDS + 0.05).timeout
	assert(toolbar.hold_menu.visible and main.get("selected_group") == 7)
	assert(toolbar.hold_menu.palette.buttons.size() == toolbar.child_tool_buttons.size())
	var subway_button := toolbar.hold_menu.palette.buttons[1] as Button
	assert(subway_button.icon != null)
	toolbar.toolbar_buttons[7].button_up.emit()
	toolbar.toolbar_buttons[7].pressed.emit()
	subway_button.pressed.emit()
	assert(not toolbar.hold_menu.visible and main.get("selected_subtool") == 1)
	assert(main.get("overlay_mode") == CityViewMode.Mode.UNDERGROUND)
	# Query's footprint is recovered from saved corner flags, from any member.
	var city := main.document_state.city as CityState
	city.document.set_misc_i32(0x14, 100000)
	CityDebugActions.unlock_everything(city, city.document)
	var building := BuildingCommand.apply(city, 3, 9, Vector2i(60, 60),
		(main.get("simulation_engine") as SimulationEngine).lfsr_random, main.get("tool_random"))
	assert(building.ok)
	main.menus.call("set_overlay", CityViewMode.Mode.CITY)
	main.current_tool.call("select_tool_group", 16)
	map.hover_tile = Vector2i(61, 61)
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.pressed = true
	map._input(shift)
	assert(map.query_footprint_preview and map.selection._selection_source_polygons().size() == 16)
	shift.pressed = false
	map._input(shift)
	assert(map.selection._selection_source_polygons().size() == 1)
	# Check city and random state after an invalid preview.
	var before: PackedByteArray = city.document.serialize().data
	assert(BuildingSites.preview_valid(city, 3, 2, Vector2i(75, 75)))
	assert(not BuildingSites.preview_valid(city, 3, 2, Vector2i(60, 60)))
	assert(not BuildingSites.preview_valid(city, 3, 2, Vector2i(0, 0)))
	assert(city.document.serialize().data == before)
	main.current_tool.call("select_tool_group", 5)
	assert(toolbar.child_tool_buttons.size() == 8 and not toolbar.child_tool_buttons.has(4))

	for arcology in range(5, 9):
		assert(toolbar.child_tool_buttons.has(arcology))

	main.current_tool.call("select_tool_group", 4)
	assert(main.get("overlay_mode") == CityViewMode.Mode.UNDERGROUND)
	main.current_tool.call("select_subtool", 1)
	assert(main.get("overlay_mode") == CityViewMode.Mode.CITY)
	main.preferences.zoom_graphics = AppSettingsStore.normalize_zoom_graphics(AppSettingsStore.DEFAULT_ZOOM_GRAPHICS)
	# Overview size is independent of the saved graphics settings.
	main.preferences.overview_graphics = CityIsometricRenderer.VIEW_SMALL
	map.zoom_factor = CityMapControl.ZOOM_LEVELS[0]
	assert(main.options_menu.get_popup().get_item_index(0x8008) == -1)
	assert(main.static_render.call("city_view_size") == CityIsometricRenderer.VIEW_SMALL)
	# City nature tools paint with fixed brushes and support Shift boxes.
	main.current_tool.call("select_tool_group", 1)
	assert(toolbar.child_tool_buttons.has(3))
	main.current_tool.call("select_subtool", 3)
	assert(main.selected_subtool == 3 and map.edit_enabled and map.brush_size == 7)
	assert(map.selection.point_preview_tiles(Vector2i(80, 80)).size() == 37)
	assert(not map.selection.point_preview_tiles(Vector2i(127, 127)).is_empty())

	for subtool in [0, 1]:
		main.current_tool.call("select_subtool", subtool)
		assert(map.selection_mode == "point" and not map.shift_line_enabled)
		assert(map.continuous_placement and map.shift_rectangle_enabled)
		assert(map.brush_size == 1 and not toolbar.brush_controls.visible)
		map.selection_start = Vector2i(80, 80)
		map.selection_end = Vector2i(83, 82)
		map.brush_box_selection = true
		map.selection._rebuild_selection_path()
		assert(map.selection_path.size() == 12)
		map.selection._clear_selection()

	map.shift_line_enabled = false
	# Held brush emits on its cadence and stops after the selection clears.
	var brush := CityMapControl.new()
	brush.edit_enabled = true
	brush.continuous_placement = true
	brush.selection_start = Vector2i(40, 40)
	brush.hover_tile = Vector2i(40, 40)
	var dabs: Array[Vector2i] = []
	brush.selection_completed.connect(func(_start, finish, _path, _dragged):
		dabs.append(finish))
	brush._process(0.29)
	assert(dabs.is_empty())
	brush._process(0.02)
	assert(dabs == [Vector2i(40, 40)])
	brush.hover_tile = Vector2i(42, 42)
	brush._process(0.3)
	assert(dabs.back() == Vector2i(42, 42) and dabs.size() == 2)
	brush.selection._clear_selection()
	brush._process(1.0)
	assert(dabs.size() == 2)
	brush.free()
	# Shift changes the same in-progress path in either direction.
	map.landscape_brush = false
	map.set_edit_enabled(true, "path", 1, true)
	map.shift_rectangle_enabled = true
	map.selection_start = Vector2i(80, 80)
	map.selection_end = Vector2i(83, 82)
	map.selection._rebuild_selection_path()
	assert(map.selection_path.size() == 6)
	shift.pressed = true
	map._input(shift)
	assert(map.selection_path.size() == 12)
	shift.pressed = false
	map._input(shift)
	assert(map.selection_path.size() == 6)
	map.selection._clear_selection()
	# Dual underground cells can display either or both networks without edits.
	city.set_underground_id(90, 90, 0x1f)
	var pipe_only := CityUndergroundView.tile_sprite_ids(city, 90, 90, 2, true, false)
	var subway_only := CityUndergroundView.tile_sprite_ids(city, 90, 90, 2, false, true)
	assert(pipe_only != subway_only and city.underground_id(90, 90) == 0x1f)
	assert(toolbar.view_visibility_checks.has("subways"))
	main.menus.call("set_underground_subways_visible", false)
	assert(not toolbar.view_visibility_checks.subways.button_pressed)
	# Recall removes only emergency records and supports exact Undo.
	var dispatched := DispatchCommand.apply(city, 2, 2, Vector2i(85, 85))
	assert(dispatched.ok)
	var dispatched_bytes: PackedByteArray = city.document.serialize().data
	var recalled := DispatchCommand.recall_all(city)
	assert(recalled.ok and city.text_overlays[city.index_of(85, 85)] == 0)
	assert(DispatchCommand.undo(city, recalled).ok)
	assert(city.document.serialize().data == dispatched_bytes)
	assert(DispatchCommand.undo(city, dispatched).ok)
	# All four slopes receive a low-side rail transition, with exact Undo.
	var low_sides := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

	for shape in range(1, 5):
		var slope := Vector2i(30 + shape * 5, 30)
		city.set_terrain_id(slope.x, slope.y, shape)
		var rail_before: PackedByteArray = city.document.serialize().data
		var foot: Vector2i = slope + low_sides[shape - 1]
		var rail := NetworkCommand.apply(city, 7, 0, slope, foot)
		assert(rail.ok)
		assert(city.building_id(foot.x, foot.y) == 0x3a + shape)
		assert(NetworkCommand.undo(city, rail).ok)
		assert(city.document.serialize().data == rail_before)

	var paper := main.get("newspaper_dialog") as NewspaperDialog
	paper.open_reports(city, city.document, null, {}, {}, 123)
	assert(paper.published_articles.size() == 5)
	assert(" ".join(paper.published_articles).contains(str(city.population())))

	for layout in range(3):
		paper.page.set_page(layout, "Test Gazette", "September 8", "25 cents", "Opinion", "Weather", PackedStringArray(["A", "B", "C", "D", "E"]))
		paper.page.set_articles(paper.published_articles)
		assert(not paper.page.articles[1].is_empty())

	paper.hide()
	await _test_network_drag_price(main, map, city)
	_test_fire_clock(city)
	main.queue_free()
	await process_frame
	print("PASS: toolbar interactions, placement validity, rail transitions, dispatch recall, landscape rectangles, fire timing, newspaper articles and display options")
	quit()


func _test_network_drag_price(main: Node, map: CityMapControl, city: CityState) -> void:
	main.menus.call("set_overlay", CityViewMode.Mode.CITY)
	main.current_tool.call("select_tool_group", 6)
	main.current_tool.call("select_subtool", 0)
	var start := Vector2i(30, 30)
	var finish := Vector2i(36, 30)
	var planned := NetworkCommand.apply(
		NetworkPlacementPreview.snapshot_city(city), 6, 0, start, finish
	)
	assert(planned.ok and int(planned.cost) > 0)
	map.selection_start = start
	map.selection_end = finish
	map.selection._rebuild_selection_path()
	map.selection_changed.emit(start, finish, map.selection.selection_tiles(), true)
	assert(map.selection_price < 0, "The route price waits for the planned command")
	var deadline := Time.get_ticks_msec() + 5000

	while map.selection_price < 0:
		assert(Time.get_ticks_msec() < deadline, "Timed out waiting for the road drag price")
		await create_timer(0.01).timeout

	assert(
		map.selection_price == int(planned.cost),
		"A road drag shows its planned price anchored at the start tile",
	)
	assert(map.selection_price_affordable)
	map.selection._clear_selection()
	main.current_tool.call("update_network_preview")
	assert(map.selection_price < 0, "Ending the drag removes the route price")


class CountingEngine extends SimulationEngine:
	var fire_ticks := 0


	func advance_moving_things(_current_time_msec := -1) -> Dictionary:
		return {"ok": true}


	func advance_disaster_tick() -> Dictionary:
		fire_ticks += 1

		return {"ok": true}


func _test_fire_clock(city: CityState) -> void:
	var engine := CountingEngine.new(city)
	engine.active_disaster_type = 1
	var controller := GameSpeedController.new(engine)
	controller.set_speed(GameSpeedController.Speed.AFRICAN_SWALLOW)

	for frame in range(120):
		assert(controller.advance_time(1000.0 / 120.0).ok)

	assert(engine.fire_ticks <= 1)
	controller.advance_time(1000.0)
	assert(engine.fire_ticks == 2)
	controller.set_speed(GameSpeedController.Speed.PAUSED)
	controller.advance_time(5000.0)
	assert(engine.fire_ticks == 2)
