class_name ApplicationDebug
extends RefCounted


@warning_ignore_start("integer_division")

const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const DebugActions = preload("res://src/debug/city_debug_actions.gd")

class ActionResult extends RefCounted:
	var ok := false
	var message := ""

	func _init(succeeded: bool, text: String) -> void:
		ok = succeeded
		message = text


var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func debug_metrics() -> Dictionary:
	var result := {
		"simulation_slices": app.simulation_state.frame_simulation.metrics() if app.simulation_state.frame_simulation != null else {},
		"render_regions": app.render_caches.region_cache.metrics() if app.render_caches.region_cache != null else {},
		"visible_altitude_levels": app.document_state.city.visible_altitude_levels if app.document_state.city != null else 32,
		"city_name": "None",
		"date": "--",
		"population": "--",
		"funds": "--",
		"speed": app.simulation_state.speed_controller.speed_name() if app.simulation_state.speed_controller != null else "--",
		"speed_id": app.simulation_state.speed_controller.speed if app.simulation_state.speed_controller != null else 1,
		"speed_accumulator_msec": (
			app.simulation_state.speed_controller.accumulator_msec if app.simulation_state.speed_controller != null else 0.0
		),
		"tool": "--",
		"view": CityViewMode.key(app.view_state.overlay_mode),
		"static_render": "running" if app.static_render_state.task != null else "idle",
		"render_pending": app.static_render_state.pending,
		"static_cache": app.render_caches.static_view_cache.size(),
		"dynamic_cache": app.render_caches.dynamic_visual_cache.size(),
		"foreground_cache": app.render_caches.dynamic_foreground_cache.size(),
		"active_disaster": (
			CityMenuBar.disaster_name(app.simulation_state.simulation_engine.active_disaster_type)
			if app.simulation_state.simulation_engine != null
			else "None"
		),
		"active_disaster_id": (
			app.simulation_state.simulation_engine.active_disaster_type if app.simulation_state.simulation_engine != null else 0
		),
		"no_disasters": app.document_state.city != null and app.document_state.city.no_disasters_enabled(),
		"detailed_timing": SimulationTimingSpan.detailed,
	}

	if app.audio_controller != null:
		result.merge(app.audio_controller.debug_metrics(), true)

	if app.map_view != null:
		result.merge(app.map_view.debug_metrics(), true)

	if app.document_state.city != null:
		result.city_name = app.document_state.city.city_name()
		result.date = "%02d/%02d/%04d" % [
			app.document_state.city.current_month(), app.document_state.city.current_day(), app.document_state.city.current_year(),
		]
		result.population = app.interface.format_number(app.document_state.city.population())
		result.funds = "$%s" % app.interface.format_number(app.document_state.city.funds())
		result.tool = str(Tools.tool(app.tool_state.selected_group, app.tool_state.selected_subtool).name)

	return result


func debug_center_map() -> void:
	var map_edge: int = app.document_state.city.map_size if app.document_state.city != null else 128

	if app.map_view != null and app.document_state.city != null:
		app.map_view.center_on_tile(Vector2i(map_edge / 2, map_edge / 2))


func debug_full_redraw() -> void:
	if app.document_state.city == null:
		return

	app.static_render.invalidate_view_render()
	app.map_render.refresh_map(true)


func debug_clear_render_caches() -> void:
	app.render_caches.static_view_cache.clear()
	app.render_caches.dynamic_sprite_cache.clear()
	app.render_caches.dynamic_foreground_cache.clear()
	app.render_caches.dynamic_occluder_cache.clear()
	app.render_caches.dynamic_visual_cache.clear()
	app.render_caches.sign_foreground_cache.clear()
	app.render_caches.dynamic_special_batch_cache.clear()
	debug_full_redraw()


func debug_add_funds(amount: int) -> ActionResult:
	var result := DebugActions.add_funds(app.document_state.city, amount)

	if not result.ok:
		return ActionResult.new(false, result.error)

	app.interface.refresh_details()

	return ActionResult.new(
		true,
		"Added $%s. Funds are now $%s."
		% [app.interface.format_number(amount), app.interface.format_number(int(result.new_funds))]
	)


func debug_unlock_everything() -> ActionResult:
	var result := DebugActions.unlock_everything(app.document_state.city, app.document_state.current_document)

	if not result.ok:
		return ActionResult.new(false, result.error)

	app.camera_input.refresh_child_tool_icons()
	app.current_tool.refresh_tool_availability()
	app.current_tool.update_edit_state()
	app.interface.refresh_details()

	return ActionResult.new(true, "Unlocked all inventions, rewards, arcologies, and power plants.")


func debug_set_no_disasters(enabled: bool) -> ActionResult:
	var result := DebugActions.set_no_disasters(app.document_state.city, enabled)

	if not result.ok:
		return ActionResult.new(false, result.error)

	app.menus.sync_city_option_menus()
	app.interface.refresh_details()

	return ActionResult.new(true, "Random disasters are %s." % ("disabled" if enabled else "enabled"))


func debug_set_detailed_timing(enabled: bool) -> ActionResult:
	SimulationTimingSpan.detailed = enabled

	return ActionResult.new(
		true,
		"Detailed per-tile timing is %s. It is measured work, so it also slows the phases it reports." % (
			"on" if enabled else "off"
		)
	)


func debug_start_disaster(disaster_type: int) -> ActionResult:
	if disaster_type < DisasterStart.DISASTER_FIRE or disaster_type > DisasterStart.DISASTER_PLANE_CRASH:
		return ActionResult.new(false, "The disaster selection is not valid.")

	var result := app.reports.start_disaster_at_view_center(disaster_type)

	if not result.ok:
		return ActionResult.new(
			false,
			"The %s could not start: %s"
			% [CityMenuBar.disaster_name(disaster_type), result.error]
		)

	return ActionResult.new(
		true,
		"%s started at the current view center."
		% CityMenuBar.disaster_name(disaster_type)
	)


func debug_end_disaster() -> ActionResult:
	var result := DebugActions.end_disaster(app.document_state.city, app.document_state.current_document, app.simulation_state.simulation_engine)

	if not result.ok:
		return ActionResult.new(false, result.error)

	app.tool_state.last_edit_command = null
	app.simulation_state.simulation_map_dirty = false
	app.map_render.refresh_map(false)
	app.moving_sprites.refresh_moving_things()
	app.interface.refresh_details()

	return ActionResult.new(
		true,
		"Ended %s and cleared %d marker(s) and %d object(s)."
		% [
			(
				CityMenuBar.disaster_name(int(result.active_type))
				if int(result.active_type) != 0
				else "the disaster"
			),
			int(result.cleared_markers),
			int(result.cleared_objects),
		]
	)


func debug_dispatch_maxis_man() -> ActionResult:
	var center := app.map_view.center_tile() if app.map_view != null else Vector2i(64, 64)
	var result := DebugActions.dispatch_maxis_man(app.document_state.city, app.document_state.current_document, center)

	if not result.ok:
		return ActionResult.new(false, result.error)

	app.moving_sprites.refresh_moving_things()

	return ActionResult.new(
		true,
		"Maxis Man was dispatched from %s toward %s."
		% [str(result.start), str(result.target)]
	)


func debug_set_visible_altitude_levels(levels: int) -> void:
	if app.document_state.city == null:
		return

	levels = clampi(levels, 1, 32)

	if app.document_state.city.visible_altitude_levels == levels:
		return

	app.document_state.city.visible_altitude_levels = levels

	if app.map_view.city != null:
		app.map_view.city.visible_altitude_levels = levels

	app.map_view.signs._invalidate_sign_entries()
	app.static_render.invalidate_view_render()
	app.map_render.refresh_map(false)
