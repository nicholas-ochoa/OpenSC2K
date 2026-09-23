class_name ApplicationFrame
extends RefCounted


const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")

var app: CityApplication
var palette_clock: PaletteAnimationClock


func _init(application: CityApplication) -> void:
	app = application
	palette_clock = application.palette_clock


func process(delta: float) -> void:
	app.new_city.poll_new_city_preview()
	app.current_tool.update_network_preview()
	app.camera_input.update_keyboard_camera(delta)

	if app.audio_controller != null:
		app.audio_controller.set_menu_music(
			app.asset_state.assets_ready and app.main_menu != null and app.main_menu.visible and app.preferences.music_volume > 0.0
			and (app.document_state.city == null or app.document_state.city.music_enabled())
		)
		app.audio_controller.advance(delta * 1000.0)

	_update_fps(delta)

	if app.city_status_bar != null:
		app.city_status_bar.update_report_rotation(delta)

	app.static_render.poll_static_render()
	app.static_render.start_pending_static_render()
	app.city_png_export.poll_export()

	if app.simulation_state.speed_controller == null or app.document_state.city == null:
		return

	app.simulation_state.simulation_engine.midi_playback_active = app.effects_audio.music_playback_is_active()
	var interaction_suspended := _simulation_suspended()
	var result: SimulationTickResult

	if app.simulation_state.frame_simulation != null:
		app.simulation_state.frame_simulation.budget_usec = FrameSimulationRunner.budget_for_frame(delta)
		result = app.simulation_state.frame_simulation.advance_time(delta * 1000.0, Time.get_ticks_msec(), interaction_suspended)
	else:
		result = app.simulation_state.speed_controller.advance_time(delta * 1000.0, Time.get_ticks_msec(), interaction_suspended)

	if not result.ok:
		app.simulation_state.speed_controller.set_speed(GameSpeed.Speed.PAUSED)
		sync_speed_ui()
		app.interface.show_error("Simulation stopped: %s" % result.error)

		return

	_advance_palette_animation(delta, interaction_suspended)

	consume_simulation_result(result)
	app.moving_sprites.advance_blend()


# registered windows declare whether they block. other conditions stay listed here
func _simulation_suspended() -> bool:
	return (
		(app.map_view != null and (app.map_view.is_left_drag_active() or app.map_view.is_panning()))
		or (app.city_dialogs != null and app.city_dialogs.blocks_simulation())
		or (app.main_overlays != null and app.main_overlays.blocks_simulation())
		# workflows create these file prompts outside the registries
		or (app.sc2x_conversion_dialog != null and app.sc2x_conversion_dialog.visible)
		or (app.scurk_city_export_dialog != null and app.scurk_city_export_dialog.visible)
		or (app.scurk_print_pdf_dialog != null and app.scurk_print_pdf_dialog.visible)
		or app.city_dialogs.budget_dialog.bond_confirmation_visible()
		or app.simulation_state.game_over_active
		or app.tool_state.landscape_editor
		or app.newspaper_state.founding_pending
	)


func _advance_palette_animation(delta: float, suspended: bool) -> void:
	# Keep palette animation running while the simulation worker is busy.
	if suspended or app.simulation_state.speed_controller.speed == GameSpeed.Speed.PAUSED:
		return

	palette_clock.elapsed_msec += maxf(delta, 0.0) * 1000.0
	var ticks := int(palette_clock.elapsed_msec / GameSpeedController.BASE_TICK_MSEC)

	if ticks > 0:
		palette_clock.elapsed_msec -= ticks * GameSpeedController.BASE_TICK_MSEC
		palette_clock.cycle_ticks += ticks
		app.static_render.update_palette_cycle_texture()


func consume_simulation_result(result: SimulationTickResult) -> void:
	if result.base_ticks > 0:
		sync_speed_ui()

	if result.paused_on_target_day:
		app.status_label.theme_type_variation = ""
		app.status_label.text = "The simulation paused on the target date."

	app.timing_state.simulation_timings.consume(result)
	var refresh_started := Time.get_ticks_usec()
	var ran_days: bool = not result.day_results.is_empty()
	var changed_disaster_map := false

	for disaster in result.disaster_results:
		if disaster.map_changed:
			changed_disaster_map = true
			break

	var moved_things := app.reports.moving_things_are_active(result.moving_results)

	# start the display blend before the refresh publishes the new positions
	if not result.moving_results.is_empty():
		app.moving_sprites.note_moving_tick()

	if ran_days or moved_things or changed_disaster_map:
		app.tool_state.last_edit_command = null
		app.scurk_state.edit_history.clear()
		# sc2x data-map updates do not change the surface or underground artwork
		var data_maps_only: bool = (app.document_state.city.document.full_resolution_maps() and result.day_results.size() == 1
			and SimulationDaySchedule.scanned_data_maps_only(result.day_results[0])
			and result.effect_events.is_empty() and result.view_center_requests.is_empty()
			and CityViewMode.is_map(app.view_state.overlay_mode))

		if moved_things or changed_disaster_map or not data_maps_only:
			app.simulation_state.simulation_map_dirty = true

	if ran_days:
		app.interface.refresh_details()

	var force_refresh: bool = (
		not result.effect_events.is_empty()
		or not result.view_center_requests.is_empty()
	)
	var map_refresh_requested: bool = app.simulation_state.simulation_map_dirty and (
		result.base_ticks > 0 or force_refresh
	)

	if map_refresh_requested:
		app.map_render.refresh_map(false)
		app.simulation_state.simulation_map_dirty = false
	elif result.base_ticks > 0:
		app.moving_sprites.refresh_moving_things()

	if ran_days or map_refresh_requested:
		app.timing_state.simulation_timings.record_step("Main thread / simulation display refresh", Time.get_ticks_usec() - refresh_started)

	for point in result.view_center_requests:
		app.map_view.center_on_tile(point)

	if not result.effect_events.is_empty() or not result.sound_events.is_empty():
		app.effects_audio.show_effect_events(result.effect_events, app.moving_sprites.audible_sound_events(result.sound_events), true)

	for track_id in result.music_track_requests:
		if app.document_state.city.music_enabled():
			app.effects_audio.play_music_track(int(track_id))

	if not result.news_items.is_empty():
		app.reports.show_news_items(result.news_items)

	if not result.notice_ids.is_empty():
		app.reports.show_notices(result.notice_ids)

	if not result.game_over_events.is_empty():
		app.reports.show_game_over_events(result.game_over_events)

	for request in result.interaction_requests:
		if request.type == "annual_budget":
			app.budget.open_budget_dialog(request.funding_values, true)
		elif request.type == "military_proposal":
			app.budget.open_military_proposal()


func _update_fps(delta: float) -> void:
	app.timing_state.fps_update_seconds += delta

	if app.city_menu_bar == null or app.timing_state.fps_update_seconds < 0.25:
		return

	app.timing_state.fps_update_seconds = fmod(app.timing_state.fps_update_seconds, 0.25)
	app.city_menu_bar.set_fps(Engine.get_frames_per_second())

	if app.city_status_bar != null:
		app.city_status_bar.refresh_tooltips()


func select_speed(speed_value: int) -> void:
	if app.simulation_state.speed_controller == null:
		return

	if not app.simulation_state.speed_controller.set_speed(speed_value):
		app.interface.show_error("Cannot change the simulation speed.")

		return

	sync_speed_ui()
	app.status_label.theme_type_variation = ""
	app.status_label.text = "%s speed selected." % app.simulation_state.speed_controller.speed_name()


func sync_speed_ui() -> void:
	var selected_speed := (
		app.simulation_state.speed_controller.speed if app.simulation_state.speed_controller != null else GameSpeed.Speed.PAUSED
	)

	if app.speed_menu != null:
		var popup := app.speed_menu.get_popup()

		for speed_id in range(5):
			var item_index := popup.get_item_index(speed_id)
			popup.set_item_checked(
				item_index, app.simulation_state.speed_controller != null and speed_id + 1 == selected_speed
			)

	if app.city_status_bar != null:
		var speed_name := app.simulation_state.speed_controller.speed_name() if app.simulation_state.speed_controller != null else "--"
		app.city_status_bar.set_speed(speed_name)
		app.city_status_bar.set_city_status(
			app.simulation_state.simulation_engine if app.document_state.city != null and not app.tool_state.landscape_editor else null,
			selected_speed == GameSpeed.Speed.PAUSED
		)
