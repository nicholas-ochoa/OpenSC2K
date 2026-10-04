class_name ApplicationScurkWorkspace
extends RefCounted

@warning_ignore_start("integer_division")

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
	app.scurk_editor.set_control_bindings(app.preferences.control_bindings)
	app.scurk_editor.toolbar_button_clicked.connect(app.interface.play_toolbar_click)
	app.scurk_editor.settings_requested.connect(app.settings.open_settings_dialog)
	app.scurk_editor.about_requested.connect(app.interface.open_about_dialog)
	app.desktop_presentation.editor = app.scurk_editor


func ensure_scurk_place_print() -> void:
	if app.scurk_place_print != null:
		return

	app.scurk_place_print = app.main_overlays.ensure_scurk_place_print()
	app.scurk_place_print.button_clicked.connect(app.interface.play_toolbar_click)
	app.scurk_place_print.tile_selected.connect(_select_scurk_place_tile)
	app.scurk_place_print.edit_tool_selected.connect(_select_scurk_edit_tool)
	app.scurk_place_print.export_bmp_requested.connect(app.scurk_output._open_scurk_city_export)
	app.scurk_place_print.print_city_requested.connect(app.scurk_output._open_scurk_print_dialog)
	app.scurk_place_print.undo_requested.connect(undo_scurk_place)
	app.scurk_place_print.redo_requested.connect(_redo_scurk_place)
	app.scurk_place_print.close_requested.connect(close_scurk_place_print)
	app.scurk_place_print.flip_toggled.connect(func(_flipped: bool) -> void: app.map_view.queue_redraw())
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
		app.asset_state.palette, app.asset_state.base_large_sprites, app.asset_state.base_small_medium_sprites,
		app.asset_state.reference_root,
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

	if (app.scurk_editor.tile_set == null
			and app.asset_state.active_scurk_path.is_empty()
			and app.asset_state.asset_source.uses_graphics_pack):
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

	if not app.scurk_place_print.visible:
		app.scurk_state.tool_before_place_print = Vector2i(app.tool_state.selected_group, app.tool_state.selected_subtool)

	if app.scurk_editor != null and app.scurk_editor.visible:
		app.scurk_editor.hide()

	if app.view_state.overlay_mode != CityViewMode.Mode.CITY:
		app.menus.set_overlay(CityViewMode.Mode.CITY)

	var names: Dictionary[int, String] = {}

	if app.asset_state.active_scurk_tile_set != null:
		names = app.asset_state.active_scurk_tile_set.names

	app.scurk_place_print.configure(app.asset_state.palette, app.asset_state.large_sprites, names, app.asset_state.scurk_graphics)
	app.scurk_state.ghost_textures.clear()

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

	# the edit tools change the selected tool. give the sidebar its tool back
	var before := app.scurk_state.tool_before_place_print
	app.scurk_state.tool_before_place_print = Vector2i(-1, -1)

	if before.x >= 0:
		app.current_tool.select_tool_group(before.x)
		app.current_tool.select_subtool(before.y)

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
		var history := app.scurk_state.edit_history
		var stroke := app.map_view.uses_paint_brush() and app.map_view.is_left_drag_active()
		# the main Undo also routes this edit to the SCURK history
		command.scurk_place_history = true
		command.scurk_tool_name = scurk_name

		# one brush stroke is one history entry, as it is one undo of the city tools
		if stroke and app.scurk_state.brush_stroke != null and history.current_command() == app.scurk_state.brush_stroke:
			app.scurk_state.brush_stroke.merge_stroke(command)
		else:
			var entry := command.copy() if stroke else command
			history.record(entry, scurk_name)
			app.scurk_state.brush_stroke = entry if stroke else null

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
		app.scurk_place_print.selected_zone_id(),
		false,
		app.scurk_place_print.flipped
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


# the selected object at `tile` as the map draws it, for the translucent
# placement preview. positions use the large view, as the static painter does
func place_ghost(tile: Vector2i) -> CityDynamicVisual:
	var city := app.document_state.city

	if (city == null or app.scurk_place_print == null or not app.scurk_place_print.visible
			or not app.scurk_place_print.is_object_mode() or city.index_of(tile.x, tile.y) < 0):
		return null

	var tile_id := app.scurk_place_print.selected_tile_id
	var site := ScurkPlace.footprint(tile_id, tile)

	if site.size.x == 0:
		return null

	var developed := tile_id >= BuildingTileIds.DEVELOPED_FIRST and tile_id <= BuildingTileIds.MAX_ID
	# an odd compass rotation mirrors buildings, as the painter does
	var flip: bool = app.scurk_place_print.flipped != (developed and city.compass_rotation() % 2 == 1)
	var texture := _ghost_texture(tile_id, flip)

	if texture == null:
		return null

	var size := texture.get_size()
	var position := Vector2.ZERO

	if tile_id > BuildingTileIds.MAX_ID:
		# an artwork stamp hangs from the bottom corner of its tile
		var anchor: Vector2 = CityIsometricRenderer.tile_polygon(city, tile.x, tile.y)[2]
		position = anchor - Vector2(size.x / 2.0, size.y - 1)
	else:
		# the painter draws from the left tile of the footprint
		var left := Vector2i(site.position.x, site.end.y - 1)
		var offset := 0

		if developed:
			offset = int(size.x) / 4 - IsometricConstants.HALF_HEIGHT
		elif city.terrain_id(left.x, left.y) == TerrainTileIds.RAISED:
			offset = -IsometricConstants.ALTITUDE_STEP

		var baseline := (IsometricConstants.TOP_MARGIN + (left.x + left.y) * IsometricConstants.HALF_HEIGHT
			+ IsometricConstants.TILE_HEIGHT - city.object_altitude(left.x, left.y) * IsometricConstants.ALTITUDE_STEP + offset)
		position = Vector2(
			IsometricConstants.SIDE_MARGIN + (city.map_size + left.x - left.y) * IsometricConstants.HALF_WIDTH,
			baseline - size.y
		)

	return CityDynamicVisual.new(texture, position)


func _ghost_texture(tile_id: int, flip: bool) -> Texture2D:
	var key := Vector2i(tile_id, int(flip))

	if app.scurk_state.ghost_textures.has(key):
		return app.scurk_state.ghost_textures[key]

	var entry = app.asset_state.large_sprites.find_sprite(ScurkSpriteIds.LARGE_FIRST + tile_id)

	if entry == null:
		return null

	var rendered := entry.create_image(app.asset_state.palette)

	if not rendered.ok:
		return null

	var image: Image = rendered.image

	if flip:
		image.flip_x()

	var texture := ImageTexture.create_from_image(image)
	app.scurk_state.ghost_textures[key] = texture

	return texture


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
	_apply_scurk_tile_sets([tile_set], display_name, path)


# Combine the original sprites with each tile set in order. A later tile set
# replaces the graphics and names of an earlier one.
func _apply_scurk_tile_sets(
	tile_sets: Array[ScurkMif], display_name: String, path: String
) -> void:
	if app.asset_state.base_large_sprites == null or app.asset_state.base_small_medium_sprites == null:
		app.interface.show_error("Original sprite data is not loaded.")

		return

	var large_archives: Array[Sc2SpriteArchive] = [app.asset_state.base_large_sprites]
	var small_medium_archives: Array[Sc2SpriteArchive] = [app.asset_state.base_small_medium_sprites]
	var names: Dictionary[int, String] = {}

	for tile_set in tile_sets:
		if tile_set == null or not tile_set.is_valid():
			app.interface.show_error("Cannot apply an invalid SCURK tile set.")

			return

		large_archives.append(tile_set.overrides)
		small_medium_archives.append(tile_set.overrides)
		names.merge(tile_set.names, true)

	if tile_sets.is_empty():
		return

	var new_large := SpriteArchive.combine(large_archives)
	var new_small_medium := SpriteArchive.combine(small_medium_archives)

	if not new_large.is_valid() or not new_small_medium.is_valid():
		app.interface.show_error("Cannot combine the tile set with the original sprite data.")

		return

	var tile_set: ScurkMif = tile_sets[-1]
	app.asset_state.active_scurk_tile_set = tile_set
	app.asset_state.active_scurk_name = display_name
	app.asset_state.active_scurk_path = ProjectSettings.globalize_path(path).simplify_path() if not path.is_empty() else ""
	app.asset_state.large_sprites = new_large
	app.asset_state.small_medium_sprites = new_small_medium

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.scurk_place_print.configure(
			app.asset_state.palette,
			app.asset_state.large_sprites,
			names,
			app.asset_state.scurk_graphics,
		)

	app.static_render.invalidate_rendered_city()

	if app.document_state.city != null:
		app.map_render.refresh_map()

	var replacements := 0

	for loaded in tile_sets:
		replacements += loaded.overrides.entries.size()

	app.status_label.theme_type_variation = ""
	app.status_label.text = "Loaded tile set %s: %d graphic replacements and %d names." % [
		app.asset_state.active_scurk_name, replacements, names.size(),
	]


# As sc2kfix does, load the tile sets that the XFIX chunk of a loaded city
# lists. A path from another computer is found by file name beside the city
# or in the original SCURKART folder. Returns the number of tile sets loaded.
func restore_city_tile_sets(document: Sc2File) -> int:
	var saved_paths := Sc2kfixXfix.tile_set_paths(document)

	if saved_paths.is_empty():
		return 0

	var directories := PackedStringArray([
		document.source_path.get_base_dir(),
		app.asset_state.reference_root.path_join("SCURKART"),
	])
	var tile_sets: Array[ScurkMif] = []
	var last_path := ""

	for saved_path in saved_paths:
		var resolved := Sc2kfixXfix.resolve_tile_set(saved_path, directories)

		if resolved.is_empty():
			continue

		var tile_set := ScurkTileSet.load_path(resolved)

		if tile_set.is_valid():
			tile_sets.append(tile_set)
			last_path = resolved

	if tile_sets.is_empty():
		app.status_label.text += " The city lists sc2kfix tile sets that were not found."

		return 0

	var status := app.status_label.text
	_apply_scurk_tile_sets(tile_sets, last_path.get_file(), last_path)
	app.status_label.text = "%s Loaded %d of %d sc2kfix tile sets." % [status, tile_sets.size(), saved_paths.size()]

	return tile_sets.size()


func restore_original_tile_set() -> void:
	if app.asset_state.base_large_sprites == null or app.asset_state.base_small_medium_sprites == null:
		return

	app.asset_state.active_scurk_tile_set = null
	app.asset_state.active_scurk_name = ""
	app.asset_state.active_scurk_path = ""
	app.assets.use_default_sprites()

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
