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
var edits: DebugEdits
var steps: ApplicationDebugSteps
var checks: ApplicationDebugChecks
var save_report_dialog: AcceptDialog
var _draw_order_note := ""
# chunk bytes at the last mark, by chunk key. packed arrays share their data,
# so a mark copies only the chunks that change later
var chunk_marks: Dictionary[String, PackedByteArray] = {}
var chunk_mark_serial := 0
var _inspector_due := 0
var _inspector_signature: Array = []
var _viewport_connected := false


func _init(application: CityApplication) -> void:
	app = application
	tile_views = ApplicationDebugTileViews.new(application, state)
	render_views = ApplicationDebugRenderViews.new(application, state)
	edits = DebugEdits.new(application)
	steps = ApplicationDebugSteps.new(application)
	checks = ApplicationDebugChecks.new(application)


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
		mark_chunks()

	# show or hide the debug query tools in the open tool palette
	if app.city_toolbar != null and app.tool_state.selected_group == CityToolIds.Group.QUERY:
		app.current_tool.select_tool_group(CityToolIds.Group.QUERY)

	if app.map_view != null:
		app.current_tool.update_edit_state()


func on_city_activated() -> void:
	edits.clear()
	steps.on_city_activated()
	chunk_marks.clear()
	chunk_mark_serial += 1

	if DebugMode.enabled:
		mark_chunks()

	tile_views.on_city_activated()
	render_views.clear()

	if app.map_view != null and app.map_view.debug_view.is_attached():
		app.map_view.debug_view.pinned_tile = Vector2i(-1, -1)
		app.map_view.debug_view.overlay.clear()
		app.map_view.debug_view.labels.labels.clear()

		if state.tile_layer != Layer.NONE:
			tile_views.set_layer(state.tile_layer)


# keep the bytes of every chunk, for the changed bytes of the chunk browser
func mark_chunks() -> String:
	var document := app.document_state.current_document
	chunk_marks.clear()
	chunk_mark_serial += 1

	if document == null:
		return "Load a city before you mark the chunks."

	var seen: Dictionary[String, int] = {}

	for chunk in document.chunks:
		chunk_marks[chunk_key(chunk.chunk_id, seen)] = chunk.decoded_payload

	return "Marked the bytes of %d chunks." % chunk_marks.size()


# the chunk ID, with "#2", "#3" and so on for a repeated chunk. `seen`
# counts the chunks before it
static func chunk_key(chunk_id: String, seen: Dictionary[String, int]) -> String:
	var occurrence := int(seen.get(chunk_id, 0))
	seen[chunk_id] = occurrence + 1

	return chunk_id if occurrence == 0 else "%s#%d" % [chunk_id, occurrence + 1]


static func find_keyed_chunk(document: Sc2File, key: String) -> Sc2Chunk:
	var parts := key.split("#")
	var occurrence := int(parts[1]) - 1 if parts.size() > 1 else 0

	return document.find_chunk(parts[0], occurrence)


# wait for background work before the application exits
func close() -> void:
	tile_views.close()
	checks.close()


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
		CityDebugMenu.MENU_VERIFY_SAVE:
			_status(checks.verify_save())
		CityDebugMenu.MENU_STEP_PHASE:
			_status(steps.step_phase())
		CityDebugMenu.MENU_STEP_DAY:
			_status(steps.step_day())
		CityDebugMenu.MENU_MISSING_ARTWORK:
			_status(checks.check_missing_artwork())
		CityDebugMenu.MENU_UNDO_EDIT:
			_status(edits.undo())
		CityDebugMenu.MENU_REPAIR_BAD_TERRAIN:
			_status(edits.repair_bad_terrain())
		CityDebugMenu.MENU_TILE_GRID:
			if app.map_view != null:
				app.map_view.debug_view.attach()
				tile_views.set_grid(not state.tile_grid)
				_apply_view_change()
		_:
			if id >= CityDebugMenu.PREVIEW_BASE:
				_status(checks.preview_disaster(id - CityDebugMenu.PREVIEW_BASE, CityDebugMenu.PREVIEW_TICKS))
			elif CityDebugMenu.CHECKS.has(id) and id not in CityDebugMenu.HANDLED_CHECKS:
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
		view.overlay.clear_flashes()

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

	# a pinned tile also shows each field of its moving object and the growth inputs
	var pinned := app.map_view.debug_view.pinned_tile == point

	if pinned:
		extra.append_array(GrowthInspection.rows(city, point))
	elif (city.zone_id(point.x, point.y) & Sc2ZoneLayout.TYPE_MASK) in range(1, 7):
		extra.append(["Growth", "Click to pin the tile and show its growth inputs"])

	return TileInspection.text(city, point, extra, pinned)


func process(delta: float) -> void:
	if checks.is_busy():
		_status(checks.process())

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
		view.labels.labels = tile_views.value_labels + render_views.thing_labels + render_views.draw_labels
		view.labels.queue_redraw()

	if render_views.draw_order_note != _draw_order_note:
		_draw_order_note = render_views.draw_order_note
		_status(_draw_order_note)

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


# show a check result as its tile layer, and outline the tile that it started from
func show_check_result(layer: Layer, values: PackedByteArray, summary: String, point := Vector2i(-1, -1)) -> void:
	if app.map_view == null:
		return

	app.map_view.debug_view.attach()
	tile_views.set_external(layer, values, summary)

	if point.x >= 0 and app.document_state.city != null:
		render_views.line_sets["check"] = [[CityMapDebugView.tile_outline(app.document_state.city, point), PINNED_COLOR]]
	else:
		render_views.line_sets.erase("check")

	_publish_lines()
	_apply_view_change()


func show_save_report(report: DebugSaveCheck.Report) -> void:
	if save_report_dialog == null:
		save_report_dialog = AcceptDialog.new()
		save_report_dialog.title = "Save Check"
		var text := TextEdit.new()
		text.name = "Report"
		text.editable = false
		text.custom_minimum_size = Vector2(720, 420)
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])
		text.add_theme_font_override("font", font)
		save_report_dialog.add_child(text)
		app.add_child(save_report_dialog)

	(save_report_dialog.get_node("Report") as TextEdit).text = report.text()

	if app.is_inside_tree() and DisplayServer.get_name() != "headless":
		save_report_dialog.popup_centered()


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
