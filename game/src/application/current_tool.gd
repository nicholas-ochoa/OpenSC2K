class_name ApplicationCurrentTool
extends RefCounted


const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const ToolState = preload("res://src/tools/shared/tool_edit_state.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const Hydro = preload("res://src/tools/city/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/city/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/city/onramp_command.gd")
const Tunnels = preload("res://src/tools/city/tunnel_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")
const Dispatch = preload("res://src/tools/city/dispatch_command.gd")
const ScurkPlace = preload("res://src/tools/scurk/scurk_place_command.gd")
const LEVEL_BRUSH_SIZE := 1
const EDITOR_LEVEL_BRUSH_SIZE := 5

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func select_tool_group(index: int) -> void:
	if app.terrain_stretch.active:
		app.map_view.cancel_active_selection()

	if app.landscape_editor and index not in [0, 1, 16, 17]:
		return

	if index < 0 or index >= Tools.GROUPS.size():
		return

	app.selected_group = index

	if app.selected_group == Dispatch.GROUP_DISPATCH:
		app.dispatch_cycles = PackedInt32Array([0, 0, 0])
		app.dispatch_initialized = false

	app.selected_subtool = app.city_toolbar.show_tool_group(
		app.selected_group, app.city, app.camera_input.tool_button_icon
	)
	_auto_select_underground()
	_sync_child_tool_selection()
	update_edit_state()


func _auto_select_underground() -> void:
	# query, camera and bulldozer work in both views
	if app.selected_group in [16, 17] or (CityViewMode.is_map(app.overlay_mode) and Demolish.supports_tool(app.selected_group, app.selected_subtool)):
		return

	if app.city == null:
		return

	var underground_tool := (app.selected_group == 4 and app.selected_subtool == 0) or (app.selected_group == 7 and app.selected_subtool == 1)
	var target := CityViewMode.Mode.UNDERGROUND if underground_tool else CityViewMode.Mode.CITY

	if app.overlay_mode != target:
		app.menus.set_overlay(target)


func select_subtool(index: int) -> void:
	if app.terrain_stretch.active:
		app.map_view.cancel_active_selection()

	if not app.landscape_editor and LandscapeEditorCommand.supports_tool(app.selected_group, index) and not (app.selected_group == 1 and index == 3):
		return

	if app.landscape_editor and (app.selected_group not in [0, 1, 16, 17] or (app.selected_group == 0 and index == 4) or (app.selected_group == 16 and index != 0)):
		return

	if app.selected_group == 2 and index == 3:
		var recalled := Dispatch.recall_all(app.city)

		if recalled.ok:
			recalled.dispatch_cycles_before = app.dispatch_cycles.duplicate()
			recalled.dispatch_initialized_before = app.dispatch_initialized
			app.last_edit_command = recalled
			app.dispatch_cycles = PackedInt32Array([0, 0, 0])
			app.dispatch_initialized = false
			app.static_render.refresh_after_city_edit(recalled)
			app.status_label.text = "All emergency services recalled."

		_sync_child_tool_selection()

		return

	app.selected_subtool = index
	_auto_select_underground()
	_sync_child_tool_selection()
	update_edit_state()

	if app.landscape_editor and app.selected_group == 0 and index in [6, 7]:
		app.city_edits._apply_map_selection(Vector2i.ZERO, Vector2i.ZERO, [Vector2i.ZERO], false)

	if app.selected_tool_available and ToolState.is_tool_chooser(app.selected_group, app.selected_subtool):
		app.query_choices._open_tool_choice_dialog(app.selected_group)


func _sync_child_tool_selection() -> void:
	if app.city_toolbar != null:
		app.city_toolbar.sync_child_tool_selection(app.selected_group, app.selected_subtool)


func refresh_tool_availability() -> bool:
	if app.city == null or app.city_toolbar == null:
		return false

	return app.city_toolbar.refresh_tool_availability(
		app.city, app.selected_group, app.selected_subtool, app.selected_tool_available
	)


func update_edit_state() -> void:
	if app.map_view == null:
		return

	var state: Dictionary
	app.assets._refresh_scurk_artwork()
	app.map_view.desktop_cursor_app = "city"
	app.map_view.desktop_cursor_role = DesktopCursorRules.city_tool(app.selected_group, app.selected_subtool)

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.map_view.desktop_cursor_app = "scurk"

		if app.scurk_place_print.is_object_mode():
			app.map_view.desktop_cursor_role = 9
			state = ToolState.scurk_object(
				app.city, app.overlay_mode, app.scurk_place_print.selected_tile_id
			)
		else:
			var cursor_tool := app.scurk_place_print.selected_edit_tool()
			app.map_view.desktop_cursor_role = DesktopCursorRules.city_tool(cursor_tool.group, cursor_tool.subtool)
			state = ToolState.scurk_tool(
				app.city, app.scurk_place_print.selected_edit_tool()
			)
	else:
		state = ToolState.normal(
			app.city, app.overlay_mode, app.selected_group, app.selected_subtool
		)
		app.selected_tool_available = bool(state.available)

	app.map_view.shift_rectangle_enabled = (bool(state.landscape) and app.selected_subtool != 3) or (app.landscape_editor and app.selected_group == 0 and app.selected_subtool in [1, 2, 3])
	app.map_view.continuous_placement = app.selected_group == 1 and app.selected_subtool == 3
	app.map_view.shift_line_enabled = app.selected_group == 1 and app.selected_subtool in [0, 1]

	if app.map_view.shift_line_enabled:
		state.selection = "rectangle"
		app.map_view.shift_rectangle_enabled = false

	app.map_view.placement_validator = _placement_preview_valid

	if app.landscape_editor and LandscapeEditorCommand.supports_tool(app.selected_group, app.selected_subtool):
		state.enabled = true
		state.available = true
		app.selected_tool_available = true
		state.selection = "point"
		state.area = 7 if app.selected_group == 1 and app.selected_subtool == 3 else 1
		state.status_text = str(Tools.tool(app.selected_group, app.selected_subtool).name)
		state.status_detail = "Drag up or down to stretch terrain live. Hold Shift to apply on release." if app.selected_group == 0 and app.selected_subtool == 5 else "Free landscape editor tool."

	var level_brush := app.new_city._level_brush_active()
	app.map_view.landscape_brush = (level_brush or app.selected_group == 1 and app.selected_subtool in [0, 1, 3]) and not (app.scurk_place_print != null and app.scurk_place_print.visible)
	app.map_view.demolish_brush = app.selected_group == 0 and app.selected_subtool == 0 and not app.landscape_editor and not (app.scurk_place_print != null and app.scurk_place_print.visible)
	app.map_view.bulldozer_visual_provider = app.moving_sprites.demolish_brush_visual if app.overlay_mode == CityViewMode.Mode.CITY else Callable()
	app.city_toolbar.brush_controls.visible = app.landscape_editor and app.map_view.landscape_brush and not level_brush
	if level_brush:
		app.map_view.brush_size = EDITOR_LEVEL_BRUSH_SIZE if app.landscape_editor else LEVEL_BRUSH_SIZE
		app.map_view.brush_round = true
	else:
		app.map_view.brush_size = int(app.city_toolbar.brush_size_input.value) if app.landscape_editor else (7 if app.selected_subtool == 3 else 1)
		app.map_view.brush_round = app.city_toolbar.brush_shape_input.selected == 1 if app.landscape_editor else true
	if app.map_view.uses_paint_brush():
		app.map_view.continuous_placement = true
		app.map_view.shift_line_enabled = false
		app.map_view.shift_rectangle_enabled = true
		state.selection = "point"
		state.area = 1
	app.map_view.stretch_terrain = app.landscape_editor and app.selected_group == 0 and app.selected_subtool == 5
	app.map_view.placement_error_provider = _placement_preview_error
	app.map_view.show_selection_preview = app.selected_group != 17
	app.map_view.terrain_diamond_preview = app.selected_group == 0 and app.selected_subtool in [2, 3, 5]
	app.map_view.highway_preview = app.selected_group == 6 and app.selected_subtool == 1
	app.map_view.query_footprint_preview = app.selected_group == 16
	if app.selected_group != 16 or app.selected_subtool != 1:
		app.map_view.clear_trip_reach()
	if app.selected_group != 16 or app.selected_subtool != 2:
		app.map_view.clear_service_query()
	app.map_view.query_city = app.city
	app.map_view.set_edit_enabled(
		bool(state.enabled),
		str(state.selection),
		int(state.area),
		bool(state.landscape),
	)
	app.interface.refresh_status_summary()

	if app.status_label == null or not bool(state.show_status):
		return

	app.status_label.theme_type_variation = ""
	app.status_label.text = str(state.status_text)
	app.status_label.set_meta("status_tooltip_text", str(state.status_detail))
	app.city_status_bar.refresh_message_tooltip()


func _placement_preview_valid(point: Vector2i) -> bool:
	return _placement_preview_error(point).is_empty()


func _placement_preview_error(point: Vector2i) -> String:
	var map_edge: int = app.city.map_size if app.city != null else 128

	if app.city == null or app.city.index_of(point.x, point.y) < 0:
		return "Select a tile inside the map."

	if app.scurk_place_print != null and app.scurk_place_print.visible and app.scurk_place_print.is_object_mode():
		var tile_id := app.scurk_place_print.selected_tile_id
		var site := ScurkPlace.footprint(tile_id, point)

		if site.size.x == 0 or not Rect2i(0, 0, map_edge, map_edge).encloses(site):
			return "The object footprint extends outside the map."

		return "" if tile_id > 255 else String(ScurkPlace._check_site(app.city.buildings, app.city.terrain, app.city.tile_flags, site, tile_id, map_edge).get("error", ""))

	if Buildings.supports_tool(app.selected_group, app.selected_subtool):
		return Buildings.preview_error(app.city, app.selected_group, app.selected_subtool, point)

	if Hydro.supports_tool(app.selected_group, app.selected_subtool):
		var index := app.city.index_of(point.x, point.y)

		if app.city.funds() < int(Tools.tool(app.selected_group, app.selected_subtool).cost):
			return "Insufficient funds."

		if app.city.buildings[index] != 0:
			return "Clear the existing structure first."

		return "" if app.city.terrain[index] in [0x2e, 0x3e] else "Hydroelectric power requires a waterfall tile."

	if Onramps.supports_tool(app.selected_group, app.selected_subtool):
		return Onramps.apply(app.city, app.selected_group, app.selected_subtool, point, false, true).error

	if SubwayToRail.supports_tool(app.selected_group, app.selected_subtool):
		return SubwayToRail.apply(app.city, app.selected_group, app.selected_subtool, point, true).error

	if Tunnels.supports_tool(app.selected_group, app.selected_subtool):
		var proposal := Tunnels.apply(app.city, app.selected_group, app.selected_subtool, point)

		if not proposal.confirmation_required:
			return proposal.error

		return "" if app.city.funds() >= proposal.cost else "Insufficient funds for this tunnel."

	if Highways.supports_tool(app.selected_group, app.selected_subtool):
		return Highways.preview_error(app.city, point)

	return ""


func update_network_preview() -> void:
	if app.network_preview == null:
		return

	if app.city == null or not app.camera_input.camera_keys_allowed() or not app.map_view.edit_enabled or app.map_view.is_panning() or not NetworkPlacementPreview.supports_tool(app.selected_group, app.selected_subtool):
		app.network_preview.clear()

		return

	# hover highlights the tile; artwork needs a pressed selection
	var start := app.map_view.selection_start
	var finish := app.map_view.selection_end

	if start.x < 0 or finish.x < 0:
		app.network_preview.clear()

		return

	var view := app.static_render.city_view_size()
	var sprites := app.large_sprites if view == IsometricRenderer.VIEW_LARGE else app.small_medium_sprites

	if sprites != null and app.palette != null:
		app.network_preview.request(
			app.city, app.selected_group, app.selected_subtool, start, finish, view, app.palette, sprites,
			app.overlay_mode == CityViewMode.Mode.UNDERGROUND, app.scurk_workspace.scurk_edit_tool_active()
		)
