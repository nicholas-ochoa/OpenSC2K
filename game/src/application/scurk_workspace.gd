class_name ApplicationScurkWorkspace
extends RefCounted


const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const ScurkTileSet = preload("res://src/assets/scurk_mif.gd")
const ScurkPlace = preload("res://src/tools/scurk/scurk_place_command.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func _ensure_scurk_editor() -> void:
	if app.scurk_editor != null:
		return

	app.scurk_editor = app.main_overlays.ensure_scurk_editor()
	app.scurk_editor.toolbar_button_clicked.connect(app.interface.play_toolbar_click)
	app.scurk_editor.settings_requested.connect(app.settings.open_settings_dialog)
	app.scurk_editor.about_requested.connect(app.interface.open_about_dialog)
	app.desktop_presentation.editor = app.scurk_editor


func ensure_scurk_place_print() -> void:
	if app.scurk_place_print != null:
		return

	app.scurk_place_print = app.main_overlays.ensure_scurk_place_print()
	app.scurk_place_print.tile_selected.connect(_select_scurk_place_tile)
	app.scurk_place_print.edit_tool_selected.connect(_select_scurk_edit_tool)
	app.scurk_place_print.export_bmp_requested.connect(app.scurk_output._open_scurk_city_export)
	app.scurk_place_print.print_city_requested.connect(app.scurk_output._open_scurk_print_dialog)
	app.scurk_place_print.undo_requested.connect(undo_scurk_place)
	app.scurk_place_print.redo_requested.connect(_redo_scurk_place)
	app.scurk_place_print.close_requested.connect(close_scurk_place_print)
	app.desktop_presentation.place_print = app.scurk_place_print
	app.scurk_city_export_dialog = preload("res://src/ui/shared/file_dialog_factory.gd").city_bitmap_save()
	app.scurk_place_print.add_child(app.scurk_city_export_dialog)
	app.scurk_city_export_dialog.file_selected.connect(app.scurk_output._export_scurk_city_bmp)


func open_scurk_dialog() -> void:
	if not app.asset_state.assets_ready:
		return

	if (
		app.asset_state.palette == null
		or not app.asset_state.palette.is_valid()
		or app.asset_state.base_large_sprites == null
		or app.asset_state.base_small_medium_sprites == null
	):
		app.interface.show_error("The SCURK graphics are not loaded.")

		return

	_ensure_scurk_editor()
	app.scurk_editor.configure(
		app.asset_state.palette, app.asset_state.base_large_sprites, app.asset_state.base_small_medium_sprites, app.asset_state.reference_root,
		app.asset_state.scurk_graphics
	)
	var initial_path := (
		app.asset_state.active_scurk_path
		if not app.asset_state.active_scurk_path.is_empty()
		else app.asset_state.reference_root.path_join("SCURKART/ORIGINAL.MIF")
	)

	if (
		app.scurk_editor.tile_set != null
		and not app.scurk_editor.dirty
		and not app.asset_state.active_scurk_path.is_empty()
		and app.scurk_editor.source_path != app.asset_state.active_scurk_path
	):
		var switched := app.scurk_editor.load_path(app.asset_state.active_scurk_path)

		if not switched.ok:
			app.interface.show_error(switched.error)

			return

	if app.scurk_editor.tile_set == null and app.asset_state.active_scurk_path.is_empty() and app.asset_state.asset_source.uses_graphics_pack:
		var created := ScurkMif.from_archives([app.asset_state.base_large_sprites, app.asset_state.base_small_medium_sprites])
		var loaded := app.scurk_editor.load_tile_set(created)

		if not loaded.ok:
			app.interface.show_error(loaded.error)

			return

	var opened := app.scurk_editor.show_editor(initial_path)

	if not opened.ok:
		app.interface.show_error(opened.error)


func open_scurk_place_print() -> void:
	if not app.asset_state.assets_ready:
		return

	if app.tool_state.landscape_editor:
		return

	if app.document_state.city == null:
		app.interface.show_error("Load or create a city before you open SCURK Place & Print.")

		return

	if (
		app.asset_state.palette == null
		or not app.asset_state.palette.is_valid()
		or app.asset_state.large_sprites == null
		or not app.asset_state.large_sprites.is_valid()
	):
		app.interface.show_error("The SCURK Place & Print graphics are not available.")

		return

	ensure_scurk_place_print()
	app.interface.hide_main_menu()

	if app.scurk_editor != null and app.scurk_editor.visible:
		app.scurk_editor.hide()

	if app.view_state.overlay_mode != CityViewMode.Mode.CITY:
		app.menus.set_overlay(CityViewMode.Mode.CITY)

	var names: Dictionary[int, String] = {}

	if app.asset_state.active_scurk_tile_set != null:
		names = app.asset_state.active_scurk_tile_set.names

	app.scurk_place_print.configure(app.asset_state.palette, app.asset_state.large_sprites, names, app.asset_state.scurk_graphics)

	if app.tool_state.last_edit_command == null or not app.tool_state.last_edit_command.scurk_place_history:
		app.scurk_state.edit_history.clear()

	app.scurk_place_print.set_history_enabled(
		app.scurk_state.edit_history.can_undo(), app.scurk_state.edit_history.can_redo()
	)
	app.scurk_place_print.set_export_enabled(app.map_view.zoom_percent() <= 25)

	if not app.scurk_place_print.show_workspace():
		app.interface.show_error("Cannot open SCURK Place & Print.")

		return

	_select_scurk_place_tile(app.scurk_place_print.selected_tile_id)


func close_scurk_place_print() -> void:
	if app.scurk_place_print != null:
		app.scurk_place_print.hide()

	if app.scurk_print != null:
		app.scurk_print.hide()

	app.current_tool.update_edit_state()

	if app.document_state.city != null:
		app.status_label.theme_type_variation = ""
		app.status_label.text = "Closed SCURK Place & Print."


func _select_scurk_place_tile(tile_id: int) -> void:
	if app.scurk_place_print == null or not app.scurk_place_print.visible:
		return

	if not ScurkPlace.is_placeable_tile(tile_id):
		app.map_view.set_edit_enabled(false)

		return

	if app.view_state.overlay_mode != CityViewMode.Mode.CITY:
		app.menus.set_overlay(CityViewMode.Mode.CITY)

	app.current_tool.update_edit_state()


func _select_scurk_edit_tool(
	group_index: int, subtool_index: int, _zone_type: int
) -> void:
	if app.scurk_place_print == null or not app.scurk_place_print.visible:
		return

	app.tool_state.selected_group = group_index
	app.tool_state.selected_subtool = subtool_index
	var tool := app.scurk_place_print.selected_edit_tool()
	# "either" has no key and leaves the current view
	var required_view := CityViewMode.from_key(tool.view if tool != null else "either")

	if required_view != CityViewMode.Mode.NONE and app.view_state.overlay_mode != required_view:
		app.menus.set_overlay(required_view)

	app.current_tool.update_edit_state()


func record_edit_command(
	command: EditCommandResult, scurk_history := false, scurk_name := ""
) -> void:
	if scurk_history:
		app.scurk_state.edit_history.record(command, scurk_name)

		if app.scurk_place_print != null:
			app.scurk_place_print.set_history_enabled(true, false)

	if app.map_view.uses_paint_brush() and app.map_view.is_left_drag_active():
		if app.tool_state.landscape_brush_command == null:
			app.tool_state.landscape_brush_command = command.copy()
		else:
			app.tool_state.landscape_brush_command.merge_stroke(command)
		app.tool_state.last_edit_command = app.tool_state.landscape_brush_command
	else:
		app.tool_state.last_edit_command = command


func apply_scurk_place_selection(point: Vector2i) -> void:
	if app.document_state.city == null or app.scurk_place_print == null:
		return

	var tile_id := app.scurk_place_print.selected_tile_id
	var result := ScurkPlace.apply(
		app.document_state.city,
		tile_id,
		point,
		app.tool_state.tool_random,
		app.scurk_place_print.selected_zone_id()
	)

	if not result.ok:
		app.interface.show_error("Cannot place the SCURK object: %s" % result.error)

		return

	var placed := result as ScurkPlaceResult
	record_edit_command(placed, true, "Object Placement")
	app.interface.refresh_details()
	app.static_render.refresh_after_city_edit(placed)
	var area := placed.area
	var message := "Placed SCURK tile %d at %d, %d (%d by %d)." % [
		tile_id, point.x, point.y, area, area,
	]
	app.scurk_place_print.set_status(message)
	app.status_label.theme_type_variation = ""
	app.status_label.text = message


func undo_scurk_place() -> void:
	if app.document_state.city == null or not app.scurk_state.edit_history.can_undo():
		return

	var result := app.scurk_state.edit_history.undo(app.document_state.city, app.tool_state.tool_random)

	if not result.ok:
		app.interface.show_error("Cannot undo SCURK placement: %s" % result.error)

		return

	var command: EditCommandResult = app.scurk_state.edit_history.redo_stack[-1]
	app.city_edits.change_neighbor_connections(command, -1)
	app.tool_state.last_edit_command = app.scurk_state.edit_history.current_command()
	app.scurk_place_print.set_history_enabled(
		app.scurk_state.edit_history.can_undo(), app.scurk_state.edit_history.can_redo()
	)
	app.interface.refresh_details()
	app.static_render.refresh_after_city_edit(command)
	var command_name := command.scurk_tool_name if not command.scurk_tool_name.is_empty() else "edit"
	var message := "Undid SCURK %s across %d tiles." % [
		command_name, result.restored_tiles,
	]
	app.scurk_place_print.set_status(message)
	app.status_label.theme_type_variation = ""
	app.status_label.text = message


func _redo_scurk_place() -> void:
	if app.document_state.city == null or not app.scurk_state.edit_history.can_redo():
		return

	var result := app.scurk_state.edit_history.redo(app.document_state.city, app.tool_state.tool_random)

	if not result.ok:
		app.interface.show_error("Cannot redo SCURK placement: %s" % result.error)

		return

	var command: EditCommandResult = app.scurk_state.edit_history.undo_stack[-1]
	app.city_edits.change_neighbor_connections(command, 1)
	app.tool_state.last_edit_command = command
	app.scurk_place_print.set_history_enabled(
		app.scurk_state.edit_history.can_undo(), app.scurk_state.edit_history.can_redo()
	)
	app.interface.refresh_details()
	app.static_render.refresh_after_city_edit(command)
	var command_name := command.scurk_tool_name if not command.scurk_tool_name.is_empty() else "edit"
	var message := "Redid SCURK %s across %d tiles." % [
		command_name, result.restored_tiles,
	]
	app.scurk_place_print.set_status(message)
	app.status_label.theme_type_variation = ""
	app.status_label.text = message


func open_tile_set_dialog() -> void:
	var tile_set_directory := app.asset_state.reference_root.path_join("SCURKART")

	if DirAccess.dir_exists_absolute(tile_set_directory):
		app.tile_set_dialog.current_dir = tile_set_directory

	app.tile_set_dialog.popup_centered_ratio(0.8)


func load_tile_set(path: String) -> void:
	if app.asset_state.base_large_sprites == null or app.asset_state.base_small_medium_sprites == null:
		app.interface.show_error("Original sprite data is not loaded.")

		return

	var tile_set := ScurkTileSet.load_path(path)

	if not tile_set.is_valid():
		app.interface.show_error("Cannot load tile set: %s" % tile_set.parse_error)

		return

	_apply_scurk_tile_set(tile_set, path.get_file(), path)


func _apply_scurk_tile_set(
	tile_set: ScurkMif, display_name: String, path: String
) -> void:
	if app.asset_state.base_large_sprites == null or app.asset_state.base_small_medium_sprites == null:
		app.interface.show_error("Original sprite data is not loaded.")

		return

	if tile_set == null or not tile_set.is_valid():
		app.interface.show_error("Cannot apply an invalid SCURK tile set.")

		return

	var new_large := SpriteArchive.combine([app.asset_state.base_large_sprites, tile_set.overrides])
	var new_small_medium := SpriteArchive.combine([
		app.asset_state.base_small_medium_sprites, tile_set.overrides,
	])

	if not new_large.is_valid() or not new_small_medium.is_valid():
		app.interface.show_error("Cannot combine the tile set with the original sprite data.")

		return

	app.asset_state.active_scurk_tile_set = tile_set
	app.asset_state.active_scurk_name = display_name
	app.asset_state.active_scurk_path = ProjectSettings.globalize_path(path).simplify_path() if not path.is_empty() else ""
	app.asset_state.large_sprites = new_large
	app.asset_state.small_medium_sprites = new_small_medium

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.scurk_place_print.configure(app.asset_state.palette, app.asset_state.large_sprites, tile_set.names, app.asset_state.scurk_graphics)

	app.static_render.invalidate_rendered_city()

	if app.document_state.city != null:
		app.map_render.refresh_map()

	app.status_label.theme_type_variation = ""
	app.status_label.text = "Loaded tile set %s: %d graphic replacements and %d names." % [
		app.asset_state.active_scurk_name, tile_set.overrides.entries.size(), tile_set.names.size(),
	]


func restore_original_tile_set() -> void:
	if app.asset_state.base_large_sprites == null or app.asset_state.base_small_medium_sprites == null:
		return

	app.asset_state.active_scurk_tile_set = null
	app.asset_state.active_scurk_name = ""
	app.asset_state.active_scurk_path = ""
	app.asset_state.large_sprites = app.asset_state.base_large_sprites
	app.asset_state.small_medium_sprites = app.asset_state.base_small_medium_sprites

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.scurk_place_print.configure(app.asset_state.palette, app.asset_state.large_sprites, {}, app.asset_state.scurk_graphics)

	app.static_render.invalidate_rendered_city()

	if app.document_state.city != null:
		app.map_render.refresh_map()

	app.status_label.theme_type_variation = ""
	app.status_label.text = "Restored the original tile set."


func scurk_edit_tool_active() -> bool:
	return (
		app.scurk_place_print != null
		and app.scurk_place_print.visible
		and not app.scurk_place_print.is_object_mode()
	)
