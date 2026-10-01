class_name ApplicationControls
extends RefCounted
## Runs the player actions that keys and mouse buttons start. The bindings
## come from the preferences; ControlActions lists the actions.

const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")
const FAST_CAMERA_SCALE := 3.0

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func bindings() -> ControlBindings:
	return app.preferences.control_bindings


# Start a held camera action for a key press. Returns true when the key moves the camera.
func press_hold_key(event: InputEventKey) -> bool:
	var action := bindings().action_for(event, [ControlActions.KIND_HOLD])

	if not ControlActions.CAMERA_DIRECTIONS.has(action):
		return false

	app.view_state.camera_motion.press(key_id(event), action)
	app.view_state.camera_tap += ControlActions.CAMERA_DIRECTIONS[action]

	return true


func on_map_hold_changed(action: String, button: MouseButton, pressed: bool) -> void:
	if not ControlActions.CAMERA_DIRECTIONS.has(action):
		return

	if pressed and app.camera_input.camera_keys_allowed():
		app.view_state.camera_motion.press(-button, action)
		app.view_state.camera_tap += ControlActions.CAMERA_DIRECTIONS[action]
	else:
		app.view_state.camera_motion.release(-button)


# the id that camera_motion uses for a held key. mouse buttons use negative ids
static func key_id(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


func camera_speed_scale() -> float:
	return FAST_CAMERA_SCALE if bindings().is_held("camera_fast") else 1.0


# Music keys work on every screen. A key that types text does not start music
# while a text field has focus.
func handle_music_key(event: InputEventKey) -> bool:
	if app.audio_controller == null:
		return false

	var action := bindings().action_for(event, [ControlActions.KIND_PRESS], [ControlActions.SCOPE_ANYWHERE])

	if not ControlActions.MUSIC_KEYS.has(action):
		return false

	var focus := app.get_viewport().gui_get_focus_owner() if app.is_inside_tree() else null

	if (focus is LineEdit or focus is TextEdit) and event.unicode != 0:
		return false

	return app.audio_controller.handle_media_key(ControlActions.MUSIC_KEYS[action])


# Run the press or click action of a key. Returns true when an action ran.
func handle_key(event: InputEventKey) -> bool:
	var action := bindings().action_for(event, [ControlActions.KIND_PRESS, ControlActions.KIND_CLICK])

	if action.is_empty() or not action_allowed(action):
		return false

	return run(action)


func action_allowed(action: String) -> bool:
	var entry := ControlActions.find(action)

	if entry == null or entry.scope == ControlActions.SCOPE_FIXED:
		return false

	return app.camera_input.camera_keys_allowed(entry.scope == ControlActions.SCOPE_GLOBAL)


# Returns true when the action ran.
func run(action: String) -> bool:
	if app.city_menu_bar != null and app.city_menu_bar.has_action(action):
		return app.city_menu_bar.trigger(action)

	if ControlActions.TOOL_IDS.has(action):
		app.camera_input.choose_tool_group(ControlActions.TOOL_IDS.find(action))

		return true

	var data_index := ControlActions.DATA_VIEW_IDS.find(action)

	if data_index >= 0:
		return _set_view(CityViewMode.DATA_MODES[data_index])

	match action:
		"zoom_in":
			return app.map_view.zoom_in()
		"zoom_out":
			return app.map_view.zoom_out()
		"zoom_reset":
			return app.map_view.reset_zoom()
		"rotate_clockwise", "rotate_counter_clockwise":
			if app.document_state.city == null:
				return false

			app.camera_input.rotate_city(action == "rotate_counter_clockwise")

			return true
		"speed_toggle_pause":
			return toggle_pause()
		"speed_faster", "speed_slower":
			return step_speed(1 if action == "speed_faster" else -1)
		"tool_next_subtool", "tool_previous_subtool":
			return cycle_subtool(1 if action == "tool_next_subtool" else -1)
		"brush_larger", "brush_smaller":
			return step_brush(1 if action == "brush_larger" else -1)
		"tool_previous":
			if app.tool_state.previous_group < 0:
				return false

			app.camera_input.choose_tool_group(app.tool_state.previous_group)

			return true
		"cancel_selection":
			return app.map_view.cancel_active_selection()
		"view_city":
			return _set_view(CityViewMode.Mode.CITY)
		"view_toggle_underground":
			if app.tool_state.landscape_editor:
				return false

			return _set_view(CityViewMode.Mode.CITY if app.view_state.overlay_mode == CityViewMode.Mode.UNDERGROUND
				else CityViewMode.Mode.UNDERGROUND)
		"window_newspaper":
			return open_newspaper()
		"toggle_fullscreen":
			app.settings.set_fullscreen(not app.preferences.fullscreen)

			return true
		"undo":
			app.city_edits.undo_last_edit()

			return true
		"map_center_on_tile":
			if app.map_view.hover_tile.x < 0:
				return false

			app.camera_input.center_map_on_tile(app.map_view.hover_tile)

			return true
		"map_context_menu":
			if app.map_view.hover_tile.x < 0:
				return false

			app.map_view.context_menu.open_at(app.map_view.hover_tile, app.map_view.get_local_mouse_position())

			return true

	return false


func _set_view(mode: CityViewMode.Mode) -> bool:
	if app.document_state.city == null:
		return false

	if app.tool_state.landscape_editor and mode not in [CityViewMode.Mode.CITY, CityViewMode.Mode.HEIGHT]:
		return false

	app.menus.select_view(mode)

	return true


# Pause a running city and remember its speed. Resume a paused city at the
# remembered speed, the speed saved in the city, or Turtle.
func toggle_pause() -> bool:
	var controller := app.simulation_state.speed_controller

	if controller == null:
		return false

	if controller.speed != GameSpeed.Speed.PAUSED:
		app.frame.select_speed(GameSpeed.Speed.PAUSED)

		return true

	var resume: int = app.simulation_state.resume_speed

	if resume <= GameSpeed.Speed.PAUSED and app.document_state.city != null:
		resume = app.document_state.city.simulation_speed()

	if resume <= GameSpeed.Speed.PAUSED or resume > GameSpeed.Speed.AFRICAN_SWALLOW:
		resume = GameSpeed.Speed.TURTLE

	app.frame.select_speed(resume)

	return true


func step_speed(direction: int) -> bool:
	var controller := app.simulation_state.speed_controller

	if controller == null:
		return false

	var target := clampi(controller.speed + direction, GameSpeed.Speed.PAUSED, GameSpeed.Speed.AFRICAN_SWALLOW)

	if target == controller.speed:
		return false

	app.frame.select_speed(target)

	return true


# select the next available subtool in the current group, the same as a click
# on its toolbar button
func cycle_subtool(direction: int) -> bool:
	if app.city_toolbar == null or app.document_state.city == null:
		return false

	var choices: Array[int] = []

	if app.tool_state.landscape_editor:
		for key: Vector2i in app.city_toolbar.landscape_buttons:
			if key.x == app.tool_state.selected_group and not (app.city_toolbar.landscape_buttons[key] as BaseButton).disabled:
				choices.append(key.y)
	else:
		for subtool: int in app.city_toolbar.child_palette.buttons:
			if not (app.city_toolbar.child_palette.buttons[subtool] as BaseButton).disabled:
				choices.append(subtool)

	if choices.size() < 2:
		return false

	choices.sort()
	var current := choices.find(app.tool_state.selected_subtool)
	var next := choices[posmod(current + direction, choices.size())] if current >= 0 else choices[0]
	app.current_tool.select_subtool(next)

	return true


func step_brush(direction: int) -> bool:
	if app.city_toolbar == null or not app.city_toolbar.brush_controls.is_visible_in_tree():
		return false

	var input := app.city_toolbar.brush_size_input
	var before := input.value
	input.value += direction

	return input.value != before


# open the paper that the player last chose, or the first paper
func open_newspaper() -> bool:
	var city := app.document_state.city

	if city == null or app.city_menu_bar.newspaper_menu.disabled:
		return false

	var count := NewsQueue.available_paper_count(city.city_status())

	if count <= 0:
		return false

	var choice := int(city.document.misc_u32(Sc2MiscLayout.NEWSPAPER_CHOICE))
	app.reports.on_newspaper_menu(choice if choice >= 0 and choice < count else 0)

	return true
