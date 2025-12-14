extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.call("_load_city_unchecked", ProjectSettings.globalize_path("res://../references/DEFAULT.SC2"))
	main.call("_select_speed", GameSpeedController.Speed.PAUSED)
	var toolbar := main.get("city_toolbar") as CityToolbar
	var map := main.get("map_view") as CityMapControl
	var status := main.get("city_status_bar") as CityStatusBar
	main.call("_select_tool_group", 4)
	assert(main.get("overlay_mode") == "underground" and toolbar.view_mode_buttons.underground.button_pressed)
	main.call("_set_overlay", "city")
	main.call("_select_tool_group", 7)
	main.call("_select_subtool", 1)
	assert(main.get("overlay_mode") == "underground" and toolbar.view_mode_buttons.underground.button_pressed)
	main.call("_set_overlay", "city")
	main.call("_select_tool_group", 17)
	assert(not map.show_selection_preview)
	main.call("_select_tool_group", 6)
	main.call("_select_subtool", 1)
	assert(map.highway_preview)
	main.call("_update_zoom_controls", 50)
	assert(status.zoom_label.text == "Zoom: 50%")
	assert(toolbar.view_layers_heading.text == "Visible Layers")
	assert(toolbar.child_palette.size_flags_vertical == Control.SIZE_EXPAND_FILL)
	for group in [3, 6, 7]:
		main.call("_select_tool_group", group)
		await process_frame
		toolbar.child_tool_scroll.scroll_vertical = 100
		main.call("_select_tool_group", 3 if group != 3 else 6)
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
	assert(subway_button.icon != null and subway_button.text == "Subway\n$100")
	toolbar.toolbar_buttons[7].button_up.emit()
	toolbar.toolbar_buttons[7].pressed.emit()
	subway_button.pressed.emit()
	assert(not toolbar.hold_menu.visible and main.get("selected_subtool") == 1)
	assert(main.get("overlay_mode") == "underground")
	# Query's footprint is recovered from saved corner flags, from any member.
	var city := main.get("city") as CityState
	city.document.set_misc_i32(0x14, 100000)
	CityDebugActions.unlock_everything(city, city.document)
	var building := BuildingCommand.apply(city, 3, 9, Vector2i(60, 60),
		(main.get("simulation_engine") as SimulationEngine).lfsr_random, main.get("tool_random"))
	assert(building.ok)
	main.call("_set_overlay", "city")
	main.call("_select_tool_group", 16)
	map.hover_tile = Vector2i(61, 61)
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.pressed = true
	map._input(shift)
	assert(map.query_footprint_preview and map._selection_source_polygons().size() == 16)
	shift.pressed = false
	map._input(shift)
	assert(map._selection_source_polygons().size() == 1)
	var sign_dialog := main.get("sign_dialog") as CitySignDialog
	assert(sign_dialog.title == "Enter sign text...")
	assert(sign_dialog.get_label().get_theme_color("font_color") == Color.WHITE)
	main.queue_free()
	await process_frame
	print("PASS: toolbar selection, scroll reset, hold menu, underground switching, zoom and Query footprint")
	quit()
