extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1000, 480)
	var dialog := (load("res://src/ui/settings/app_settings_dialog.tscn") as PackedScene).instantiate() as AppSettingsDialog
	root.add_child(dialog)
	dialog.popup_centered()
	dialog.tabs.current_tab = dialog.visual_tab.get_index()
	var tab := dialog.visual_tab
	_check_cloud_settings(tab)
	var defaults := VisualEnhancementOptions.normalize({})
	assert(tab.terrain_strength_slider.value == 50.0)
	tab.terrain_strength_slider.value = 75.0
	assert(tab.selected_values().nature_terrain_strength == 0.75)
	(tab.controls.nature_terrain_strength as SpinBox).value = 20.0
	assert(tab.terrain_strength_slider.value == 20.0)
	(tab.controls.nature_terrain_enabled as CheckBox).button_pressed = false
	assert(not tab.terrain_strength_slider.editable and not (tab.controls.nature_terrain_strength as SpinBox).editable)
	tab.show_values(defaults)
	assert(tab.terrain_strength_slider.editable and tab.terrain_strength_slider.value == 50.0)
	var custom := VisualEnhancementOptions.normalize({"day_mode": 1, "day_hour": 7.5,
		"night_light_strength": 65.0, "weather_mode": 2, "weather_fixed": 6,
		"lut_folder": "user://profiles", "lut_path": "user://colors.png", "brightmap_folder": "masks"})
	tab.show_values(custom)
	var notifications := [0]
	dialog.settings_changed.connect(func() -> void: notifications[0] += 1)
	var clock := tab.controls.day_hour as VisualTimeEdit
	assert(clock.text == "07:30" and clock.value == 7.5)
	clock.text = "09:45"
	clock.text_submitted.emit(clock.text)
	assert(tab.selected_values().day_hour == 9.75 and notifications[0] == 1)
	clock.focus_exited.emit()
	assert(notifications[0] == 1, "Unchanged focus exit applied settings again")
	for invalid in ["24:00", "12:60", "-1:15", "abc", "12"]:
		clock.text = invalid
		clock.commit()
		assert(clock.value == 9.75 and notifications[0] == 1)
	clock.value = 23.99
	clock.commit()
	assert(clock.value == 23.99, "Displaying HH:MM rounded the stored value")
	clock.value = 0.0
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	clock._gui_input(up)
	assert(clock.value == 0.25)
	tab.show_values(custom)
	tab.select_category(1)
	notifications[0] = 0
	tab._reset_category()
	var expected := custom.duplicate()
	for key: String in VisualEnhancementsTab.SECTIONS[1][2]:
		expected[key] = defaults[key]
	assert(tab.selected_values() == expected and notifications[0] == 1)
	assert(not tab.undo_button.disabled)
	tab.undo_button.pressed.emit()
	assert(tab.selected_values() == custom and notifications[0] == 2)
	tab._reset_all()
	assert(tab.selected_values() == defaults and notifications[0] == 3)
	tab.undo_button.pressed.emit()
	assert(tab.selected_values() == custom)
	tab.select_category(8)
	tab._reset_category()
	assert(tab.selected_values().lut_folder.is_empty() and tab.selected_values().lut_path.is_empty())
	assert(tab.selected_values().day_hour == custom.day_hour)
	tab._undo_action()
	assert(tab.selected_values() == custom)
	tab._disable_all()
	assert(not tab.selected_values().day_enabled)
	tab._undo_action()
	assert(tab.selected_values() == custom)
	tab._reset_all()
	(tab.controls.cloud_enabled as CheckBox).button_pressed = false
	assert(tab.undo_button.disabled, "Undo must not overwrite later edits")
	assert((tab.dependency_hints.cloud_mode as Label).visible)
	assert(not (tab.dependency_hints.weather_mode as Label).visible)
	(tab.controls.season_enabled as CheckBox).button_pressed = false
	assert((tab.dependency_hints.season_water_strength as Label).visible)
	(tab.controls.brightmaps as CheckBox).button_pressed = false
	assert((tab.dependency_hints.night_daytime_enabled as Label).visible)
	tab.show_values(custom)
	tab.select_category(3)
	await process_frame
	await process_frame
	tab.page_scroll.scroll_vertical = 80
	var scroll := tab.page_scroll.scroll_vertical
	assert(scroll > 0, "Fixture must exercise a scrolling category")
	tab.select_category(0)
	await process_frame
	await process_frame
	tab.select_category(3)
	await process_frame
	await process_frame
	assert(tab.page_scroll.scroll_vertical == scroll, "Category scroll position was lost")
	dialog.hide()
	dialog.show_values(0.5, 0.5, false)
	await process_frame
	await process_frame
	assert(dialog.tabs.get_current_tab_control() == tab and tab.selected_category == 3)
	assert(tab.page_scroll.scroll_vertical == scroll)
	# Closing while a category restore is queued must cancel its callback.
	tab._schedule_scroll_restore(3)
	dialog.free()
	await process_frame
	print("PASS: visual settings reset scope, undo, time input, dependencies, single notifications and session navigation")
	quit()


func _check_cloud_settings(tab: VisualEnhancementsTab) -> void:
	for enabled in [false, true]:
		var migrated := VisualEnhancementOptions.normalize({"cloud_enabled": enabled, "weather_fog_enabled": not enabled})
		assert(migrated.cloud_enabled == enabled and migrated.cloud_mode == 0)
		assert(not migrated.has("weather_fog_enabled"), "Retired fog switch must not survive normalization")
	assert(VisualEnhancementOptions.normalize({"cloud_mode": -1}).cloud_mode == 0)
	assert(VisualEnhancementOptions.normalize({"cloud_mode": 9}).cloud_mode == 6)
	assert(VisualEnhancementOptions.normalize({"cloud_mode": "Fog"}).cloud_mode == 0)
	assert(not tab.controls.has("weather_fog_enabled"))
	var choice := tab.controls.cloud_mode as OptionButton
	assert(choice.item_count == 7)
	var notifications := [0]
	var count_change := func() -> void: notifications[0] += 1
	tab.changed.connect(count_change)
	for mode in range(7):
		tab.show_values({"cloud_mode": (mode + 1) % 7, "day_hour": 7.5})
		notifications[0] = 0
		choice.select(mode)
		choice.item_selected.emit(mode)
		var selected := tab.selected_values()
		assert(selected.cloud_mode == mode and notifications[0] == 1)
		tab.show_values(selected)
		assert(choice.selected == mode, "Cloud selection did not survive reopening")
		(tab.controls.weather_enabled as CheckBox).button_pressed = false
		assert(not choice.disabled and tab.selected_values().cloud_mode == mode)
		assert((tab.dependency_hints.cloud_mode as Label).visible == (mode == 0))
		(tab.controls.cloud_enabled as CheckBox).button_pressed = false
		assert(choice.disabled and (tab.dependency_hints.cloud_mode as Label).visible)
		for key in ["cloud_density", "cloud_shadow_strength", "cloud_speed"]:
			assert(not (tab.controls[key] as SpinBox).editable)
		(tab.controls.cloud_enabled as CheckBox).button_pressed = true
		assert(not choice.disabled and tab.selected_values().cloud_mode == mode)
		for key in ["cloud_density", "cloud_shadow_strength", "cloud_speed"]:
			assert((tab.controls[key] as SpinBox).editable)
	(tab.controls.weather_enabled as CheckBox).button_pressed = true
	assert((tab.dependency_hints.cloud_mode as Label).visible)
	tab.select_category(3)
	var before_reset := tab.selected_values()
	tab._reset_category()
	assert(tab.selected_values().cloud_mode == 0 and tab.selected_values().day_hour == 7.5)
	tab._undo_action()
	assert(tab.selected_values() == before_reset)
	tab.changed.disconnect(count_change)
