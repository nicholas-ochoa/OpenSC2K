class_name ApplicationDebug
extends RefCounted


const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const DebugActions = preload("res://src/debug/city_debug_actions.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func _debug_metrics() -> Dictionary:
	var result := {
		"simulation_slices": app.frame_simulation.metrics() if app.frame_simulation != null else {},
		"render_regions": app.region_cache.metrics() if app.region_cache != null else {},
		"visible_altitude_levels": app.city.visible_altitude_levels if app.city != null else 32,
		"city_name": "None",
		"date": "--",
		"population": "--",
		"funds": "--",
		"speed": app.speed_controller.speed_name() if app.speed_controller != null else "--",
		"speed_id": app.speed_controller.speed if app.speed_controller != null else 1,
		"speed_accumulator_msec": (
			app.speed_controller.accumulator_msec if app.speed_controller != null else 0.0
		),
		"tool": "--",
		"view": app.overlay_mode,
		"static_render": "running" if app.static_render_thread != null else "idle",
		"render_pending": app.pending_static_render,
		"static_cache": app.static_view_cache.size(),
		"dynamic_cache": app.dynamic_visual_cache.size(),
		"foreground_cache": app.dynamic_foreground_cache.size(),
		"active_disaster": (
			CityMenuBar.disaster_name(app.simulation_engine.active_disaster_type)
			if app.simulation_engine != null
			else "None"
		),
		"active_disaster_id": (
			app.simulation_engine.active_disaster_type if app.simulation_engine != null else 0
		),
		"no_disasters": app.city != null and app.city.no_disasters_enabled(),
		"detailed_timing": SimulationTimingSpan.detailed,
	}

	if app.audio_controller != null:
		result.merge(app.audio_controller.debug_metrics(), true)

	if app.map_view != null:
		result.merge(app.map_view.debug_metrics(), true)

	if app.city != null:
		result.city_name = app.city.city_name()
		result.date = "%02d/%02d/%04d" % [
			app.city.current_month(), app.city.current_day(), app.city.current_year(),
		]
		result.population = app.interface._format_number(app.city.population())
		result.funds = "$%s" % app.interface._format_number(app.city.funds())
		result.tool = str(Tools.tool(app.selected_group, app.selected_subtool).name)

	return result


func _debug_center_map() -> void:
	var map_edge: int = app.city.map_size if app.city != null else 128

	if app.map_view != null and app.city != null:
		app.map_view.center_on_tile(Vector2i(IntegerMath.div_trunc(map_edge, 2), IntegerMath.div_trunc(map_edge, 2)))


func _debug_full_redraw() -> void:
	if app.city == null:
		return

	app.static_render._invalidate_view_render()
	app.map_render._refresh_map(true)


func _debug_clear_render_caches() -> void:
	app.static_view_cache.clear()
	app.dynamic_sprite_cache.clear()
	app.dynamic_foreground_cache.clear()
	app.dynamic_occluder_cache.clear()
	app.dynamic_visual_cache.clear()
	app.sign_foreground_cache.clear()
	app.dynamic_special_batch_cache.clear()
	_debug_full_redraw()


func _debug_add_funds(amount: int) -> Dictionary:
	var result := DebugActions.add_funds(app.city, amount)

	if not result.ok:
		return {"ok": false, "message": result.error}

	app.interface._refresh_details()

	return {
		"ok": true,
		"message": "Added $%s. Funds are now $%s."
		% [app.interface._format_number(amount), app.interface._format_number(int(result.new_funds))],
	}


func _debug_unlock_everything() -> Dictionary:
	var result := DebugActions.unlock_everything(app.city, app.current_document)

	if not result.ok:
		return {"ok": false, "message": result.error}

	app.camera_input._refresh_child_tool_icons()
	app.current_tool._refresh_tool_availability()
	app.current_tool._update_edit_state()
	app.interface._refresh_details()

	return {
		"ok": true,
		"message": "Unlocked all inventions, rewards, arcologies, and power plants.",
	}


func _debug_set_no_disasters(enabled: bool) -> Dictionary:
	var result := DebugActions.set_no_disasters(app.city, enabled)

	if not result.ok:
		return {"ok": false, "message": result.error}

	app.menus._sync_city_option_menus()
	app.interface._refresh_details()

	return {
		"ok": true,
		"message": "Random disasters are %s." % ("disabled" if enabled else "enabled"),
	}


func _debug_set_detailed_timing(enabled: bool) -> Dictionary:
	SimulationTimingSpan.detailed = enabled

	return {
		"ok": true,
		"message": "Detailed per-tile timing is %s. It is measured work, so it also slows the phases it reports." % (
			"on" if enabled else "off"
		),
	}


func _debug_start_disaster(disaster_type: int) -> Dictionary:
	if disaster_type < DisasterStart.DISASTER_FIRE or disaster_type > DisasterStart.DISASTER_PLANE_CRASH:
		return {"ok": false, "message": "The disaster selection is not valid."}

	var result := app.reports._start_disaster_at_view_center(disaster_type)

	if not result.get("ok", false):
		return {
			"ok": false,
			"message": "The %s could not start: %s"
			% [CityMenuBar.disaster_name(disaster_type), result.get("error", "unknown error")],
		}

	return {
		"ok": true,
		"message": "%s started at the current view center."
		% CityMenuBar.disaster_name(disaster_type),
	}


func _debug_end_disaster() -> Dictionary:
	var result := DebugActions.end_disaster(app.city, app.current_document, app.simulation_engine)

	if not result.ok:
		return {"ok": false, "message": result.error}

	app.last_edit_command = {}
	app.simulation_map_dirty = false
	app.map_render._refresh_map(false)
	app.moving_sprites._refresh_moving_things()
	app.interface._refresh_details()

	return {
		"ok": true,
		"message": "Ended %s and cleared %d marker(s) and %d object(s)."
		% [
			(
				CityMenuBar.disaster_name(int(result.active_type))
				if int(result.active_type) != 0
				else "the disaster"
			),
			int(result.cleared_markers),
			int(result.cleared_objects),
		],
	}


func _debug_dispatch_maxis_man() -> Dictionary:
	var center := app.map_view.center_tile() if app.map_view != null else Vector2i(64, 64)
	var result := DebugActions.dispatch_maxis_man(app.city, app.current_document, center)

	if not result.ok:
		return {"ok": false, "message": result.error}

	app.moving_sprites._refresh_moving_things()

	return {
		"ok": true,
		"message": "Maxis Man was dispatched from %s toward %s."
		% [str(result.start), str(result.target)],
	}


func _debug_set_visible_altitude_levels(levels: int) -> void:
	if app.city == null:
		return

	levels = clampi(levels, 1, 32)

	if app.city.visible_altitude_levels == levels:
		return

	app.city.visible_altitude_levels = levels

	if app.map_view.city != null:
		app.map_view.city.visible_altitude_levels = levels

	app.map_view.signs._invalidate_sign_entries()
	app.static_render._invalidate_view_render()
	app.map_render._refresh_map(false)
