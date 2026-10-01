class_name ApplicationDebugTools
extends RefCounted
## Debug mode, the Debug menu and the debug views. With debug mode off or with
## no view selected, `process` returns at once. Each view refreshes on change
## and on its own timer; see ApplicationDebugTileViews and
## ApplicationDebugRenderViews.

const Layer = DebugTileLayers.Layer
const INSPECTOR_INTERVAL_MSEC := 250
# chunks whose change refreshes the Tile Inspector text
const INSPECTED_CHUNKS: Array[String] = ["XBLD", "XZON", "XTER", "ALTM", "XUND", "XTXT", "XBIT", "XTHG", "XTRF",
	"XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG"]
const PINNED_COLOR := Color(1.0, 1.0, 1.0, 1.0)

var app: CityApplication
var state := DebugViewState.new()
var tile_views: ApplicationDebugTileViews
var render_views: ApplicationDebugRenderViews
var _inspector_due := 0
var _inspector_signature: Array = []
var _viewport_connected := false


func _init(application: CityApplication) -> void:
	app = application
	tile_views = ApplicationDebugTileViews.new(application, state)
	render_views = ApplicationDebugRenderViews.new(application, state)


func set_debug_mode(enabled: bool, save := true) -> void:
	DebugMode.enabled = enabled
	app.preferences.debug_mode = enabled

	if save:
		AppSettingsStore.save_debug_mode(enabled, app.preferences.settings_path)

	if app.city_menu_bar != null and app.city_menu_bar.debug_menu != null:
		app.city_menu_bar.debug_menu.visible = enabled

	if not enabled:
		state.reset()
		_clear_views()

		if DebugMode.is_debug_tool(app.tool_state.selected_group, app.tool_state.selected_subtool):
			app.tool_state.group_subtools[CityToolIds.Group.QUERY] = CityToolIds.Query.QUERY

	elif app.document_state.city != null:
		tile_views.on_city_activated()

	# show or hide the debug query tools in the open tool palette
	if app.city_toolbar != null and app.tool_state.selected_group == CityToolIds.Group.QUERY:
		app.current_tool.select_tool_group(CityToolIds.Group.QUERY)

	if app.map_view != null:
		app.current_tool.update_edit_state()


func on_city_activated() -> void:
	tile_views.on_city_activated()
	render_views.clear()

	if app.map_view != null and app.map_view.debug_view.is_attached():
		app.map_view.debug_view.pinned_tile = Vector2i(-1, -1)
		app.map_view.debug_view.overlay.clear()
		app.map_view.debug_view.labels.labels.clear()

		if state.tile_layer != Layer.NONE:
			tile_views.set_layer(state.tile_layer)


# wait for background work before the application exits
func close() -> void:
	tile_views.close()


func on_days_completed() -> void:
	if DebugMode.enabled:
		tile_views.on_days_completed()


func on_debug_menu(id: int) -> void:
	match id:
		CityDebugMenu.MENU_TILE_INSPECTOR:
			_select_query_tool(CityToolIds.Query.TILE_INSPECTOR)
		CityDebugMenu.MENU_TRIP_QUERY:
			_select_query_tool(CityToolIds.Query.TRIP_REACH)
		CityDebugMenu.MENU_TAKE_SNAPSHOT:
			_status(tile_views.take_snapshot())
		CityDebugMenu.MENU_CAPTURE:
			_status(DebugCapture.capture(app, state))
		CityDebugMenu.MENU_DEBUG_WINDOW:
			if app.debug_overlay != null and not app.debug_overlay.is_open:
				app.debug_overlay.toggle()
		_:
			if CityDebugMenu.CHECKS.has(id):
				var field: String = CityDebugMenu.CHECKS[id]
				state.set(field, not bool(state.get(field)))
				_apply_view_change()
			elif id >= CityDebugMenu.BASELINE_BASE:
				tile_views.set_baseline(id - CityDebugMenu.BASELINE_BASE)
			elif id >= CityDebugMenu.LAYER_BASE:
				set_tile_layer(id - CityDebugMenu.LAYER_BASE)

	sync_menu()


func set_tile_layer(layer: Layer) -> void:
	if app.map_view == null:
		return

	app.map_view.debug_view.attach()
	tile_views.set_layer(layer)
	_apply_view_change()


func _apply_view_change() -> void:
	if app.map_view == null:
		return

	_connect_viewport()
	var view := app.map_view.debug_view
	view.attach()
	view.hud.visible = state.performance_hud
	render_views.mark_dirty()

	if not state.region_repaints:
		view.overlay.flashes.clear()

	process(0.0)
	app.map_view.queue_redraw()


func _select_query_tool(subtool: int) -> void:
	if app.document_state.city == null or app.city_toolbar == null:
		return

	app.current_tool.select_tool_group(CityToolIds.Group.QUERY)
	app.current_tool.select_subtool(subtool)


func sync_menu() -> void:
	if app.city_menu_bar == null or app.city_menu_bar.debug_menu == null:
		return

	var query := app.tool_state.selected_group == CityToolIds.Group.QUERY
	CityDebugMenu.sync(app.city_menu_bar.debug_menu.get_popup(), state,
		query and app.tool_state.selected_subtool == CityToolIds.Query.TILE_INSPECTOR,
		query and app.tool_state.selected_subtool == CityToolIds.Query.TRIP_REACH)


# the current tool decides whether the Tile Inspector follows the pointer
func sync_tool(group_index: int, subtool_index: int) -> void:
	if app.map_view == null:
		return

	var active := (DebugMode.enabled and group_index == CityToolIds.Group.QUERY
		and subtool_index == CityToolIds.Query.TILE_INSPECTOR)
	var view := app.map_view.debug_view

	if active:
		view.attach()
		view.inspector_text = _inspector_text
	elif view.is_attached() and view.pinned_tile.x >= 0:
		view.pinned_tile = Vector2i(-1, -1)
		_sync_pinned_outline()

	view.inspector_active = active
	app.map_view.queue_redraw()


# a click with the Tile Inspector keeps the panel on the tile. a second click
# on the same tile lets the panel follow the pointer again
func pin_inspector(point: Vector2i) -> void:
	var view := app.map_view.debug_view
	view.pinned_tile = Vector2i(-1, -1) if view.pinned_tile == point else point
	_sync_pinned_outline()
	app.map_view.queue_redraw()


func unpin_inspector() -> bool:
	if app.map_view == null or not app.map_view.debug_view.is_attached() or app.map_view.debug_view.pinned_tile.x < 0:
		return false

	pin_inspector(app.map_view.debug_view.pinned_tile)

	return true


func _sync_pinned_outline() -> void:
	var view := app.map_view.debug_view
	var city := app.document_state.city

	if view.pinned_tile.x >= 0 and city != null:
		render_views.line_sets["pinned"] = [[CityMapDebugView.tile_outline(city, view.pinned_tile), PINNED_COLOR]]
	else:
		render_views.line_sets.erase("pinned")

	_publish_lines()


func _inspector_text(point: Vector2i) -> String:
	var city := app.document_state.city

	if city == null:
		return ""

	var extra := []

	if state.tile_layer != Layer.NONE:
		extra.append(["Debug layer", "%s: %s" % [DebugTileLayers.title(state.tile_layer), tile_views.describe(point)]])

	return TileInspection.text(city, point, extra)


func process(delta: float) -> void:
	if not DebugMode.enabled or app.map_view == null or not app.map_view.debug_view.is_attached():
		return

	var view := app.map_view.debug_view
	var now := Time.get_ticks_msec()

	if state.performance_hud:
		view.hud.add_frame(delta)

		if view.hud.text_due():
			view.hud.set_text(DebugPerformanceText.text(app))

	var labels_changed := tile_views.process(now)
	var lines_changed := render_views.process(now)

	if lines_changed:
		_publish_lines()

	if labels_changed or lines_changed:
		view.labels.labels = tile_views.value_labels + render_views.thing_labels
		view.labels.queue_redraw()

	view.overlay.expire_flashes()

	if view.inspector_active and now >= _inspector_due and app.document_state.city != null:
		_inspector_due = now + INSPECTOR_INTERVAL_MSEC
		var signature := app.document_state.city.mirror_signature(PackedStringArray(INSPECTED_CHUNKS))

		if signature != _inspector_signature:
			_inspector_signature = signature
			view.inspector_revision += 1
			app.map_view.queue_redraw()


func _publish_lines() -> void:
	var overlay := app.map_view.debug_view.overlay
	overlay.line_sets.clear()

	for key in render_views.line_sets:
		overlay.line_sets.append_array(render_views.line_sets[key])

	overlay.dots = render_views.thing_dots
	overlay.queue_redraw()


func _connect_viewport() -> void:
	if _viewport_connected or app.map_view == null:
		return

	app.map_view.viewport_changed.connect(render_views.mark_dirty)
	_viewport_connected = true


func _clear_views() -> void:
	render_views.clear()

	if app.map_view == null or not app.map_view.debug_view.is_attached():
		return

	tile_views.set_layer(Layer.NONE)
	var view := app.map_view.debug_view
	view.overlay.clear()
	view.labels.labels.clear()
	view.labels.queue_redraw()
	view.hud.hide()
	view.inspector_active = false
	view.pinned_tile = Vector2i(-1, -1)
	view.inspector.close()


func _status(message: String) -> void:
	if app.status_label == null or message.is_empty():
		return

	app.status_label.theme_type_variation = ""
	app.status_label.text = message


func metrics() -> Dictionary:
	return {
		"enabled": DebugMode.enabled,
		"tile_layer": tile_views.metrics(),
		"render": render_views.metrics(),
	}
