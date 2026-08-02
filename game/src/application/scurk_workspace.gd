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
	app.scurk_editor.tile_set_applied.connect(_apply_scurk_tile_set)
	app.scurk_editor.place_print_requested.connect(_open_scurk_place_print)
	app.desktop_presentation.editor = app.scurk_editor


func _ensure_scurk_place_print() -> void:
	if app.scurk_place_print != null:
		return

	app.scurk_place_print = app.main_overlays.ensure_scurk_place_print()
	app.scurk_place_print.tile_selected.connect(_select_scurk_place_tile)
	app.scurk_place_print.edit_tool_selected.connect(_select_scurk_edit_tool)
	app.scurk_place_print.export_bmp_requested.connect(app.scurk_output._open_scurk_city_export)
	app.scurk_place_print.print_city_requested.connect(app.scurk_output._open_scurk_print_dialog)
	app.scurk_place_print.undo_requested.connect(_undo_scurk_place)
	app.scurk_place_print.redo_requested.connect(_redo_scurk_place)
	app.scurk_place_print.close_requested.connect(_close_scurk_place_print)
	app.desktop_presentation.place_print = app.scurk_place_print
	app.scurk_city_export_dialog = preload("res://src/ui/shared/file_dialog_factory.gd").city_bitmap_save()
	app.scurk_place_print.add_child(app.scurk_city_export_dialog)
	app.scurk_city_export_dialog.file_selected.connect(app.scurk_output._export_scurk_city_bmp)


func _open_scurk_dialog() -> void:
	if not app.assets_ready:
		return

	if (
		app.palette == null
		or not app.palette.is_valid()
		or app.base_large_sprites == null
		or app.base_small_medium_sprites == null
	):
		app.interface._show_error("The SCURK graphics are not loaded.")

		return

	_ensure_scurk_editor()
	app.scurk_editor.configure(
		app.palette, app.base_large_sprites, app.base_small_medium_sprites, app.reference_root, app.scurk_graphics
	)
	var initial_path := (
		app.active_scurk_path
		if not app.active_scurk_path.is_empty()
		else app.reference_root.path_join("SCURKART/ORIGINAL.MIF")
	)

	if (
		app.scurk_editor.tile_set != null
		and not app.scurk_editor.dirty
		and not app.active_scurk_path.is_empty()
		and app.scurk_editor.source_path != app.active_scurk_path
	):
		var switched := app.scurk_editor.load_path(app.active_scurk_path)

		if not switched.ok:
			app.interface._show_error(switched.error)

			return

	if app.scurk_editor.tile_set == null and app.active_scurk_path.is_empty() and app.asset_source.uses_graphics_pack:
		var created := ScurkMif.from_archives([app.base_large_sprites, app.base_small_medium_sprites])
		var loaded := app.scurk_editor.load_tile_set(created)

		if not loaded.ok:
			app.interface._show_error(loaded.error)

			return

	var opened := app.scurk_editor.show_editor(initial_path)

	if not opened.ok:
		app.interface._show_error(opened.error)


func _open_scurk_place_print() -> void:
	if not app.assets_ready:
		return

	if app.landscape_editor:
		return

	if app.city == null:
		app.interface._show_error("Load or create a city before you open SCURK Place & Print.")

		return

	if (
		app.palette == null
		or not app.palette.is_valid()
		or app.large_sprites == null
		or not app.large_sprites.is_valid()
	):
		app.interface._show_error("The SCURK Place & Print graphics are not available.")

		return

	_ensure_scurk_place_print()
	app.interface._hide_main_menu()

	if app.scurk_editor != null and app.scurk_editor.visible:
		app.scurk_editor.hide()

	if app.overlay_mode != CityViewMode.Mode.CITY:
		app.menus._set_overlay(CityViewMode.Mode.CITY)

	var names := (
		app.active_scurk_tile_set.names
		if app.active_scurk_tile_set != null
		else {}
	)
	app.scurk_place_print.configure(app.palette, app.large_sprites, names, app.scurk_graphics)

	if not app.last_edit_command.get("scurk_place_history", false):
		app.scurk_edit_history.clear()

	app.scurk_place_print.set_history_enabled(
		app.scurk_edit_history.can_undo(), app.scurk_edit_history.can_redo()
	)
	app.scurk_place_print.set_export_enabled(app.map_view.zoom_percent() <= 25)

	if not app.scurk_place_print.show_workspace():
		app.interface._show_error("Cannot open SCURK Place & Print.")

		return

	_select_scurk_place_tile(app.scurk_place_print.selected_tile_id)


func _close_scurk_place_print() -> void:
	if app.scurk_place_print != null:
		app.scurk_place_print.hide()

	if app.scurk_print != null:
		app.scurk_print.hide()

	app.current_tool._update_edit_state()

	if app.city != null:
		app.status_label.theme_type_variation = ""
		app.status_label.text = "Closed SCURK Place & Print."


func _select_scurk_place_tile(tile_id: int) -> void:
	if app.scurk_place_print == null or not app.scurk_place_print.visible:
		return

	if not ScurkPlace.is_placeable_tile(tile_id):
		app.map_view.set_edit_enabled(false)

		return

	if app.overlay_mode != CityViewMode.Mode.CITY:
		app.menus._set_overlay(CityViewMode.Mode.CITY)

	app.current_tool._update_edit_state()


func _select_scurk_edit_tool(
	group_index: int, subtool_index: int, _zone_type: int
) -> void:
	if app.scurk_place_print == null or not app.scurk_place_print.visible:
		return

	app.selected_group = group_index
	app.selected_subtool = subtool_index
	var tool := app.scurk_place_print.selected_edit_tool()
	# "either" has no key and leaves the current view
	var required_view := CityViewMode.from_key(String(tool.get("view", "either")))

	if required_view != CityViewMode.Mode.NONE and app.overlay_mode != required_view:
		app.menus._set_overlay(required_view)

	app.current_tool._update_edit_state()


func _record_edit_command(
	command: Dictionary, scurk_history := false, scurk_name := ""
) -> void:
	if scurk_history:
		app.scurk_edit_history.record(command, scurk_name)

		if app.scurk_place_print != null:
			app.scurk_place_print.set_history_enabled(true, false)

	if app.map_view.uses_paint_brush() and app.map_view.is_left_drag_active():
		if app.landscape_brush_command.is_empty():
			app.landscape_brush_command = command.duplicate(true)
		else:
			for id in command.changed_ids:
				if id not in app.landscape_brush_command.changed_ids:
					app.landscape_brush_command.changed_ids.append(id)
					app.landscape_brush_command.old_payloads[id] = command.old_payloads[id]
				app.landscape_brush_command.new_payloads[id] = command.new_payloads[id]
			for field in ["cost", "listed_cost", "skipped_insufficient", "action_count", "easter_events", "skipped_specialized"]:
				app.landscape_brush_command[field] = int(app.landscape_brush_command.get(field, 0)) + int(command.get(field, 0))
			app.landscape_brush_command.random_state_after = command.random_state_after
			app.landscape_brush_command.random_used = app.landscape_brush_command.get("random_used", false) or command.get("random_used", false)
			app.landscape_brush_command.tile_indices.append_array(command.tile_indices)
		app.last_edit_command = app.landscape_brush_command
	else:
		app.last_edit_command = command


func _apply_scurk_place_selection(point: Vector2i) -> void:
	if app.city == null or app.scurk_place_print == null:
		return

	var tile_id := app.scurk_place_print.selected_tile_id
	var result := ScurkPlace.apply(
		app.city,
		tile_id,
		point,
		app.tool_random,
		app.scurk_place_print.selected_zone_id()
	)

	if not result.get("ok", false):
		app.interface._show_error("Cannot place the SCURK object: %s" % result.error)

		return

	_record_edit_command(result, true, "Object Placement")
	app.interface._refresh_details()
	app.static_render._refresh_after_city_edit(result)
	var area := int(result.get("area", 1))
	var message := "Placed SCURK tile %d at %d, %d (%d by %d)." % [
		tile_id, point.x, point.y, area, area,
	]
	app.scurk_place_print.set_status(message)
	app.status_label.theme_type_variation = ""
	app.status_label.text = message


func _undo_scurk_place() -> void:
	if app.city == null or not app.scurk_edit_history.can_undo():
		return

	var result := app.scurk_edit_history.undo(app.city, app.tool_random)

	if not result.get("ok", false):
		app.interface._show_error("Cannot undo SCURK placement: %s" % result.error)

		return

	var command: Dictionary = result.command
	app.last_edit_command = result.current_command
	app.scurk_place_print.set_history_enabled(
		app.scurk_edit_history.can_undo(), app.scurk_edit_history.can_redo()
	)
	app.interface._refresh_details()
	app.static_render._refresh_after_city_edit(command)
	var command_name := String(command.get("scurk_tool_name", "edit"))
	var message := "Undid SCURK %s across %d tiles." % [
		command_name, result.restored_tiles,
	]
	app.scurk_place_print.set_status(message)
	app.status_label.theme_type_variation = ""
	app.status_label.text = message


func _redo_scurk_place() -> void:
	if app.city == null or not app.scurk_edit_history.can_redo():
		return

	var result := app.scurk_edit_history.redo(app.city, app.tool_random)

	if not result.get("ok", false):
		app.interface._show_error("Cannot redo SCURK placement: %s" % result.error)

		return

	var command: Dictionary = result.command
	app.last_edit_command = command
	app.scurk_place_print.set_history_enabled(
		app.scurk_edit_history.can_undo(), app.scurk_edit_history.can_redo()
	)
	app.interface._refresh_details()
	app.static_render._refresh_after_city_edit(command)
	var command_name := String(command.get("scurk_tool_name", "edit"))
	var message := "Redid SCURK %s across %d tiles." % [
		command_name, result.restored_tiles,
	]
	app.scurk_place_print.set_status(message)
	app.status_label.theme_type_variation = ""
	app.status_label.text = message


func _open_tile_set_dialog() -> void:
	var tile_set_directory := app.reference_root.path_join("SCURKART")

	if DirAccess.dir_exists_absolute(tile_set_directory):
		app.tile_set_dialog.current_dir = tile_set_directory

	app.tile_set_dialog.popup_centered_ratio(0.8)


func _load_tile_set(path: String) -> void:
	if app.base_large_sprites == null or app.base_small_medium_sprites == null:
		app.interface._show_error("Original sprite data is not loaded.")

		return

	var tile_set := ScurkTileSet.load_path(path)

	if not tile_set.is_valid():
		app.interface._show_error("Cannot load tile set: %s" % tile_set.parse_error)

		return

	_apply_scurk_tile_set(tile_set, path.get_file(), path)


func _apply_scurk_tile_set(
	tile_set: ScurkMif, display_name: String, path: String
) -> void:
	if app.base_large_sprites == null or app.base_small_medium_sprites == null:
		app.interface._show_error("Original sprite data is not loaded.")

		return

	if tile_set == null or not tile_set.is_valid():
		app.interface._show_error("Cannot apply an invalid SCURK tile set.")

		return

	var new_large := SpriteArchive.combine([app.base_large_sprites, tile_set.overrides])
	var new_small_medium := SpriteArchive.combine([
		app.base_small_medium_sprites, tile_set.overrides,
	])

	if not new_large.is_valid() or not new_small_medium.is_valid():
		app.interface._show_error("Cannot combine the tile set with the original sprite data.")

		return

	app.active_scurk_tile_set = tile_set
	app.active_scurk_name = display_name
	app.active_scurk_path = ProjectSettings.globalize_path(path).simplify_path() if not path.is_empty() else ""
	app.large_sprites = new_large
	app.small_medium_sprites = new_small_medium

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.scurk_place_print.configure(app.palette, app.large_sprites, tile_set.names, app.scurk_graphics)

	app.static_render._invalidate_rendered_city()

	if app.city != null:
		app.map_render._refresh_map()

	app.status_label.theme_type_variation = ""
	app.status_label.text = "Loaded tile set %s: %d graphic replacements and %d names." % [
		app.active_scurk_name, tile_set.overrides.entries.size(), tile_set.names.size(),
	]


func _restore_original_tile_set() -> void:
	if app.base_large_sprites == null or app.base_small_medium_sprites == null:
		return

	app.active_scurk_tile_set = null
	app.active_scurk_name = ""
	app.active_scurk_path = ""
	app.large_sprites = app.base_large_sprites
	app.small_medium_sprites = app.base_small_medium_sprites

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.scurk_place_print.configure(app.palette, app.large_sprites, {}, app.scurk_graphics)

	app.static_render._invalidate_rendered_city()

	if app.city != null:
		app.map_render._refresh_map()

	app.status_label.theme_type_variation = ""
	app.status_label.text = "Restored the original tile set."


func _scurk_edit_tool_active() -> bool:
	return (
		app.scurk_place_print != null
		and app.scurk_place_print.visible
		and not app.scurk_place_print.is_object_mode()
	)
