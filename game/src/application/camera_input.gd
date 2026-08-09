class_name ApplicationCameraInput
extends RefCounted


const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const Zones = preload("res://src/tools/city/zone_command.gd")
const ToolSounds = preload("res://src/audio/tool_sound_rules.gd")
const CityRotation = preload("res://src/tools/city/city_rotation_command.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func camera_keys_allowed() -> bool:
	if app.city == null or app.map_view == null or not app.map_view.is_visible_in_tree() or not DisplayServer.window_is_focused():
		return false

	var focus := app.get_viewport().gui_get_focus_owner()

	if focus is LineEdit or focus is TextEdit:
		return false

	for overlay in [app.main_menu, app.new_city_dialog, app.query_dialog, app.scurk_editor, app.scurk_place_print, app.scurk_print, app.settings_dialog, app.save_changes_dialog]:
		if overlay != null and overlay.visible:
			return false

	if app.city_dialogs != null:
		for dialog in app.city_dialogs.find_children("*", "Window", true, false):
			if dialog is Window and dialog.visible:
				return false

			if dialog is Control and dialog.visible and dialog.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				return false

	for window in app.get_viewport().get_embedded_subwindows():
		if window.visible:
			return false

	return true


func update_keyboard_camera(delta: float) -> void:
	var enabled := camera_keys_allowed()
	var direction := Vector2.ZERO
	enabled = enabled and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META) and not Input.is_key_pressed(KEY_ALT)

	if enabled:
		direction = app.camera_motion.held_direction()

	if direction.is_zero_approx():
		direction = app.camera_tap

	app.camera_tap = Vector2.ZERO

	if app.map_view != null:
		app.map_view.pan_screen(app.camera_motion.step(direction, delta, enabled and not app.map_view.is_panning() and not app.map_view.is_left_drag_active()))


func input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and app.audio_controller != null:
		if app.audio_controller.handle_media_key(event.keycode):
			app.get_viewport().set_input_as_handled()

			return

	# A focused control can consume the release event. Stop camera movement anyway.
	if event is InputEventKey and not event.pressed:
		app.camera_motion.release(event.physical_keycode)


func unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or app.map_view == null:
		return

	if camera_keys_allowed() and not event.is_command_or_control_pressed() and not event.alt_pressed:
		var directions := {KEY_W: Vector2.UP, KEY_A: Vector2.LEFT, KEY_S: Vector2.DOWN, KEY_D: Vector2.RIGHT}

		if directions.has(event.physical_keycode):
			app.camera_motion.press(event.physical_keycode)
			app.camera_tap += directions[event.physical_keycode]
			app.get_viewport().set_input_as_handled()

			return

	if app.scurk_editor != null and app.scurk_editor.visible:
		if app.scurk_editor.handle_shortcut(event):
			app.get_viewport().set_input_as_handled()

		return

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		if event.keycode == KEY_ESCAPE:
			app.scurk_workspace.close_scurk_place_print()
			app.get_viewport().set_input_as_handled()

		return

	if app.main_menu != null and app.main_menu.visible:
		if event.keycode == KEY_ESCAPE and app.city != null:
			app.interface.hide_main_menu()

		app.get_viewport().set_input_as_handled()

		return

	if event.keycode == KEY_ESCAPE and app.query_dialog != null and app.query_dialog.visible:
		app.query_choices.close_query(false)
		app.get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and app.new_city_dialog != null and app.new_city_dialog.visible:
		app.new_city.cancel_new_city()
		app.get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Z and event.is_command_or_control_pressed():
		app.city_edits.undo_last_edit()
		app.get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and app.map_view != null and (app.map_view.trip_reach != null or app.map_view.service_query != null):
		app.map_view.clear_trip_reach()
		app.map_view.clear_service_query()
		app.get_viewport().set_input_as_handled()
	elif camera_keys_allowed() and not event.is_command_or_control_pressed() and not event.alt_pressed and (event.keycode == KEY_PLUS or event.keycode == KEY_EQUAL or event.physical_keycode == KEY_E):
		if app.map_view.zoom_in():
			app.get_viewport().set_input_as_handled()
	elif camera_keys_allowed() and not event.is_command_or_control_pressed() and not event.alt_pressed and (event.keycode == KEY_MINUS or event.physical_keycode == KEY_Q):
		if app.map_view.zoom_out():
			app.get_viewport().set_input_as_handled()


func choose_tool_group(group_index: int) -> void:
	app.current_tool.select_tool_group(group_index)


func tool_button_icon(group_index: int, subtool_index: int) -> Texture2D:
	if group_index == 1 and subtool_index in [0, 1, 2, 3]:
		return TerrainToolIcons.terrain_action(app.asset_source.assets.city_ui_graphics,
			["tree", "water", "stream", "forest"][subtool_index])

	if group_index == 0 and subtool_index in [1, 2, 3]:
		return TerrainToolIcons.terrain_action(
			app.asset_source.assets.city_ui_graphics, ["", "level", "raise", "lower"][subtool_index]
		)

	if group_index == 0 and subtool_index in [5, 6, 7]:
		return TerrainToolIcons.terrain_action(app.asset_source.assets.city_ui_graphics, ["stretch", "sea_raise", "sea_lower"][subtool_index - 5])

	if app.palette == null or app.large_sprites == null or not app.large_sprites.is_valid():
		return app.city_toolbar.group_icon(group_index) if app.city_toolbar != null else null

	var tile_id := BuildingSites.tile_for_tool(group_index, subtool_index)
	var sprite_id := 1000 + tile_id if tile_id > 0 else -1

	if sprite_id < 0:
		var table_index := group_index * Tools.MAX_SLOTS_PER_GROUP + subtool_index
		const REPRESENTATIVE_SPRITES := {
			5: 1257, 6: 1270, 7: 1270,
			12: 1012, 13: 1270, 14: 1270, 15: 1012, 36: 1014, 39: 1198, 48: 1334,
			72: 1029, 73: 1073, 74: 1063, 75: 1093,
			84: 1044, 85: 1319, 88: 1108,
			96: 1299, 97: 1298,
			108: 1291, 109: 1292,
			120: 1293, 121: 1294,
			132: 1295, 133: 1296,
		}
		sprite_id = int(REPRESENTATIVE_SPRITES.get(table_index, -1))

	if sprite_id < 0:
		return app.city_toolbar.group_icon(group_index) if app.city_toolbar != null else null

	var entry := app.large_sprites.find_sprite(sprite_id)

	if entry == null:
		return app.city_toolbar.group_icon(group_index) if app.city_toolbar != null else null

	var rendered := entry.create_image(app.palette_clock.toolbar_palette if app.palette_clock.toolbar_palette != null else app.palette)

	if not rendered.get("ok", false):
		return app.city_toolbar.group_icon(group_index) if app.city_toolbar != null else null

	var image: Image = rendered.image.duplicate()

	if group_index == 6 and subtool_index == 1:
		var section := Image.create(image.get_width() + 32, image.get_height() + 16, false, Image.FORMAT_RGBA8)
		section.fill(Color.TRANSPARENT)

		for offset in [Vector2i(16, 0), Vector2i(0, 8), Vector2i(32, 8), Vector2i(16, 16)]:
			section.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), offset)

		image = section

	var scale := minf(1.0, minf(48.0 / image.get_width(), 44.0 / image.get_height()))

	if scale < 1.0:
		image.resize(
			maxi(1, roundi(image.get_width() * scale)),
			maxi(1, roundi(image.get_height() * scale)),
			Image.INTERPOLATE_NEAREST,
		)

	return ImageTexture.create_from_image(image)


func refresh_child_tool_icons() -> void:
	if app.city_toolbar != null:
		app.city_toolbar.refresh_child_tool_icons(app.selected_group, tool_button_icon)


func zoom_in() -> void:
	app.map_view.zoom_in()


func zoom_out() -> void:
	app.map_view.zoom_out()


func rotate_city(counter_clockwise: bool) -> void:
	var map_edge: int = app.city.map_size if app.city != null else 128

	if app.city == null:
		app.interface.show_error("No city is loaded.")

		return

	var old_center := Vector2i(-1, -1)

	if CityViewMode.DISPLAY_MODES.has(app.overlay_mode):
		old_center = app.map_view.center_tile()

	var new_center := CityRotation.rotate_point(
		old_center, map_edge, counter_clockwise
	)
	var result := CityRotation.apply(app.city, counter_clockwise)

	if not result.ok:
		app.interface.show_error("Cannot rotate city: %s" % result.error)

		return

	if app.simulation_engine != null:
		app.simulation_engine.rotate_runtime_coordinates(counter_clockwise)

	app.last_edit_command = null
	app.map_view.clear_trip_reach()
	app.map_view.clear_service_query()
	app.map_view.show_transient_effects([])
	app.map_render.refresh_map()

	if new_center.x >= 0:
		app.map_view.center_on_tile(new_center)

	app.status_label.theme_type_variation = ""
	app.status_label.text = "Rotated counterclockwise" if counter_clockwise else "Rotated clockwise"


func update_zoom_controls(percent: int) -> void:
	if app.city_workspace != null and app.city_workspace.status_bar != null:
		app.city_workspace.status_bar.set_zoom(percent)

	if app.zoom_in_button != null:
		app.zoom_in_button.disabled = not app.map_view.can_zoom_in()

	if app.zoom_out_button != null:
		app.zoom_out_button.disabled = not app.map_view.can_zoom_out()

	if app.rotate_counter_clockwise_button != null:
		app.rotate_counter_clockwise_button.disabled = app.city == null

	if app.rotate_clockwise_button != null:
		app.rotate_clockwise_button.disabled = app.city == null

	if app.scurk_place_print != null:
		app.scurk_place_print.set_export_enabled(percent <= 25)


func on_city_zoom_changed(percent: int) -> void:
	update_zoom_controls(percent)

	if app.city != null and CityViewMode.is_map(app.overlay_mode):
		app.map_render.refresh_map(false)


func on_map_selection_canceled() -> void:
	if app.terrain_stretch.active:
		refresh_terrain_stretch(0)
		app.terrain_stretch.finish()

	if app.status_label == null:
		return

	app.status_label.theme_type_variation = ""
	var painted := app.map_view.continuous_placement and (
		not app.map_view.uses_paint_brush() or app.landscape_brush_command != null
	)
	app.status_label.text = (
		"Brush stopped. Use Undo to remove its last edit."
		if painted else "Selection canceled. No action was taken."
	)


func on_map_selection_started() -> void:
	app.landscape_brush_command = null
	app.level_brush_altitude = -1
	if app.new_city.level_brush_active() and app.city != null:
		app.level_brush_altitude = app.city.land_altitude(app.map_view.selection_start.x, app.map_view.selection_start.y)
	if app.landscape_editor and app.selected_group == 0 and app.selected_subtool == 5:
		app.terrain_stretch.begin(app.map_view.selection_start)

	if app.selected_group != 0:
		return

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		return

	app.effects_audio.start_tool_loop_sound(508)


func on_map_selection_finished() -> void:
	if app.terrain_stretch.active:
		refresh_terrain_stretch(0)
		app.terrain_stretch.finish()

	app.effects_audio.stop_tool_loop_sound()


func on_terrain_stretch_changed(levels: int, deferred: bool) -> void:
	if app.terrain_stretch.active:
		refresh_terrain_stretch(0 if deferred else levels)


func refresh_terrain_stretch(levels: int) -> void:
	var update := app.terrain_stretch.update(app.city, app.tool_random, levels)

	if update != null and update.ok:
		app.static_render.refresh_after_city_edit(update)

		if levels != 0 and not is_instance_valid(app.audio_controller.tool_loop_player):
			app.effects_audio.play_sound_events([ToolSounds.SOUND_TRACTOR])


func on_map_selection_changed(
	start: Vector2i,
	finish: Vector2i,
	_path: Array[Vector2i],
	dragged: bool
) -> void:
	if app.scurk_place_print != null and app.scurk_place_print.visible:
		if app.scurk_place_print.is_object_mode():
			app.map_view.clear_selection_price()

			return

		var scurk_tool := app.scurk_place_print.selected_edit_tool()
		var zone_type := int(scurk_tool.get("zone", -1))

		if zone_type < 0:
			app.map_view.clear_selection_price()

			return

		var scurk_preview := Zones.preview_rectangle(
			app.city,
			int(scurk_tool.group),
			int(scurk_tool.subtool),
			start,
			finish,
			dragged,
			true,
			zone_type
		)

		if not scurk_preview.get("ok", false):
			app.map_view.clear_selection_price()

			return

		app.map_view.set_selection_price(0, true)
		app.status_label.theme_type_variation = ""
		app.status_label.text = "%s preview: %d tiles; free in SCURK." % [
			scurk_tool.name, int(scurk_preview.changed_tiles),
		]

		return

	if app.city != null and NetworkPlacementPreview.supports_tool(app.selected_group, app.selected_subtool):
		# route preview owns the anchored price
		return

	if app.city == null or not Zones.supports_tool(app.selected_group, app.selected_subtool):
		app.map_view.clear_selection_price()

		return

	var preview := Zones.preview_rectangle(
		app.city, app.selected_group, app.selected_subtool, start, finish, dragged
	)

	if not preview.get("ok", false):
		app.map_view.clear_selection_price()
		app.status_label.theme_type_variation = "ErrorLabel"
		app.status_label.text = "Cannot start zone selection: %s" % preview.error

		return

	var cost := int(preview.cost)
	var affordable := bool(preview.affordable)
	app.map_view.set_selection_price(cost, affordable)
	app.status_label.theme_type_variation = ""
	app.status_label.text = "%s preview: %d charged %s for $%s." % [
		Tools.tool(app.selected_group, app.selected_subtool).name,
		int(preview.charged_tiles),
		"tile" if int(preview.charged_tiles) == 1 else "tiles",
		app.interface.format_number(cost),
	]

	if not affordable:
		app.status_label.theme_type_variation = "ErrorLabel"
		app.status_label.text += " Funds are not sufficient."


func center_map_on_tile(point: Vector2i) -> void:
	if app.map_view.center_on_tile(point):
		app.effects_audio.play_tool_success_sound(17, 0)
		app.status_label.theme_type_variation = ""
		app.status_label.text = "Centered the map on tile %d, %d." % [point.x, point.y]
