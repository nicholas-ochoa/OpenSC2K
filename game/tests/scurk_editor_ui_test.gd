extends SceneTree

const EditorScene = preload("res://src/ui/scurk/scurk_editor_control.tscn")
const Workspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_footprints()
	var assets := OriginalGameAssets.load_root(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	var editor := EditorScene.instantiate() as ScurkEditorControl
	root.add_child(editor)
	editor.configure(assets.palette, assets.large_sprites, assets.small_medium_sprites,
		ProjectSettings.globalize_path("res://../references/SIMCITY2000"), assets.scurk_graphics)
	assert(editor.show_editor().ok)
	await process_frame
	await process_frame
	assert(editor.object_list.get_item_icon(0) != null)
	editor.brush_size_selector.value = 24
	assert(editor.pixel_canvas.brush_size == 24)
	editor.brush_size_selector.value = 25
	assert(editor.brush_size_selector.value == 24)
	editor.brush_size_selector.value = 1
	# Only tools that paint with a brush expose its size and shape controls.
	for tool in editor.tool_buttons.size():
		editor.tool_buttons[tool].pressed.emit()
		var uses_brush := tool <= ScurkPixelCanvas.TOOL_RECTANGLE or tool in [ScurkPixelCanvas.TOOL_SHADE, ScurkPixelCanvas.TOOL_STAMP]
		assert(editor.brush_size_selector.is_visible_in_tree() == uses_brush)
		assert(editor.round_brush_check.is_visible_in_tree() == uses_brush)
		assert(editor.filled_shapes_check.is_visible_in_tree() == (tool >= ScurkPixelCanvas.TOOL_DIAMOND and tool <= ScurkPixelCanvas.TOOL_RECTANGLE))
	editor.tool_buttons[ScurkPixelCanvas.TOOL_PENCIL].pressed.emit()
	# Filtering must select the visible result, including after an empty result.
	editor.object_search.text = "255"
	editor._on_search_changed("255")
	assert(editor.object_list.item_count > 0)
	assert(editor.current_large_id == int(editor.object_list.get_item_metadata(editor.object_list.selected)))
	editor.object_search.text = "no matching tile"
	editor._on_search_changed("")
	assert(editor.object_list.item_count == 0)
	editor.object_search.text = ""
	editor._on_search_changed("")
	assert(editor.object_list.item_count == 499)
	editor._on_object_selected(0)
	# The name editor is modal. Apply and revert both retain undo history.
	editor.request_edit_name()
	assert(editor.name_edit.text == editor.sprite_role(1))
	assert(editor.object_panel.name_dialog.visible and editor.object_panel.name_dialog.exclusive)
	editor.name_edit.text = "Test tile"
	editor.object_panel.name_dialog.confirmed.emit()
	editor.object_panel.name_dialog.hide()
	assert(editor.tile_set.names[1] == "Test tile")
	editor.request_edit_name()
	assert(editor.name_edit.text == "Test tile")
	editor.object_panel.name_dialog.hide()
	editor.revert_name_button.pressed.emit()
	assert(not editor.tile_set.names.has(1))
	editor.undo()
	assert(editor.tile_set.names[1] == "Test tile")
	editor.undo()
	# Palette animation uses one tick even while display views are hidden.
	editor._set_cycle_colors(false)
	var tick := editor.pixel_canvas.palette_cycle_ticks
	editor._increment_cycle()
	assert(editor.pixel_canvas.palette_cycle_ticks == tick + Sc2Palette.SCURK_INCREMENT_TIMER_TICKS)
	assert(editor.palette_panel.palette_control.palette_cycle_ticks == editor.pixel_canvas.palette_cycle_ticks)
	for preview in editor.view_previews:
		assert(preview.palette_cycle_ticks == editor.pixel_canvas.palette_cycle_ticks)
	var palette_before := editor.palette_panel.palette_control.display_palette_index(171)
	for step in 10:
		editor._increment_cycle()
		if editor.palette_panel.palette_control.display_palette_index(171) != palette_before:
			break
	assert(editor.palette_panel.palette_control.display_palette_index(171) != palette_before)
	editor._set_cycle_colors(true)
	tick = editor.pixel_canvas.palette_cycle_ticks
	editor._process(Sc2Palette.SCURK_TIMER_INTERVAL_SECONDS * 2)
	assert(editor.pixel_canvas.palette_cycle_ticks > tick)
	for preview in editor.view_previews:
		assert(preview.palette_cycle_ticks == editor.pixel_canvas.palette_cycle_ticks)
	# The moved controls still update the canvas, and clip guides require clipping.
	editor.snap_to_grid_check.button_pressed = true
	assert(editor.pixel_canvas.snap_to_grid)
	editor.snap_to_grid_check.button_pressed = false
	editor.grid_check.button_pressed = false
	assert(not editor.pixel_canvas.show_grid)
	assert(not editor.grid_width_selector.is_visible_in_tree() and not editor.grid_height_selector.is_visible_in_tree())
	editor.grid_check.button_pressed = true
	assert(editor.grid_width_selector.is_visible_in_tree() and editor.grid_height_selector.is_visible_in_tree())
	var before_clip_controls: PackedByteArray = editor.tile_set.to_bytes().bytes
	editor.clip_region_check.button_pressed = true
	assert(editor.pixel_canvas.show_clip_region and not editor.clip_region_check.disabled)
	editor.drawing_controls.clip_enabled_check.button_pressed = false
	assert(editor.clip_region_check.disabled and not editor.pixel_canvas.show_clip_region)
	assert(editor.pixel_canvas.clip_guide_rects().is_empty())
	editor.drawing_controls.clip_enabled_check.button_pressed = true
	assert(not editor.clip_region_check.disabled and editor.pixel_canvas.show_clip_region)
	for view in 3:
		editor._select_view(view)
		assert(editor.pixel_canvas.background_view == view)
	editor._select_view(0)
	assert(editor.tile_set.to_bytes().bytes == before_clip_controls)
	editor.clip_region_check.button_pressed = false
	# A pixel outside the original tile survives commit, undo, save, and reload.
	var original: PackedByteArray = editor.tile_set.to_bytes().bytes
	editor._set_clipping_enabled(false)
	assert(editor.pixel_canvas.edit_mask.is_empty())
	var pixels := editor.pixel_canvas.pixels.duplicate()
	pixels[240 * Workspace.WIDTH] = 171
	editor._capture_edit_start()
	editor._commit_pixels(pixels)
	var expanded: PackedByteArray = editor.tile_set.to_bytes().bytes
	assert(expanded != original)
	assert(editor._resolved_view_entry(0).width == 128)
	assert(editor.pixel_canvas.pixels[240 * Workspace.WIDTH] == 171)
	editor.undo()
	assert(editor.tile_set.to_bytes().bytes == original)
	editor.redo()
	assert(editor.tile_set.to_bytes().bytes == expanded)
	editor._on_object_selected(1)
	assert(editor._clipping_enabled())
	editor._on_object_selected(0)
	assert(not editor._clipping_enabled())
	var folder := "user://scurk-ui-%d" % OS.get_process_id()
	assert(editor.save_path(folder.path_join("CUSTOM.MIF")).ok)
	assert(editor.load_path(folder.path_join("CUSTOM.MIF")).ok)
	assert(not editor._clipping_enabled())
	assert(editor.pixel_canvas.pixels[240 * Workspace.WIDTH] == 171)
	# Export any view without changing the active view or indexed artwork.
	for view in 3:
		editor.request_export_bmp()
		editor.dialog_registry.export_view.select(view)
		editor.dialog_registry.export_options.confirmed.emit()
		editor.dialog_registry.export_options.hide()
		editor.export_bmp_dialog.hide()
		assert(editor.pending_export_view == view)
		var path := folder.path_join("view-%d.png" % view)
		editor._export_selected_bmp(path)
		var decoded := IndexedPng.load_path(path)
		var expected := editor._output_shape_for_view(view)
		assert(decoded.ok and decoded.width == expected.width and decoded.height == expected.height)
		assert(decoded.pixels == expected.pixels and decoded.palette.colors == assets.palette.colors)
		var bytes := FileAccess.get_file_as_bytes(path)
		assert(bytes[24] == 8 and bytes[25] == 3) # indexed PNG, 8 bits per pixel
		assert(editor.current_view == 0 and editor.tile_set.to_bytes().bytes == expanded)
		DirAccess.remove_absolute(path)
	assert(not editor.export_image_path(folder.path_join("invalid.png"), 3).ok)
	editor.canvas_panel.show_views_button.button_pressed = true
	assert(editor.canvas_panel.previews_panel.visible)
	editor.canvas_panel.show_views_button.button_pressed = false
	assert(not editor.canvas_panel.previews_panel.visible)
	# The canvas, selectors, and status bar fit the supported 1024x768 workspace.
	editor.size = Vector2(1024, 768)
	await process_frame
	await process_frame
	var panel := editor.get_node("Panel") as Control
	assert(panel.position.x + panel.size.x <= editor.size.x)
	assert(panel.position.y + panel.size.y <= editor.size.y)
	assert(editor.pixel_canvas.get_parent().get_parent().size.x > 0)
	# Every texture remains visible and pickable as the available area changes.
	var textures := editor.palette_panel.texture_control
	for viewport_size in [Vector2(1024, 768), Vector2(1600, 1000)]:
		editor.size = viewport_size
		await process_frame
		await process_frame
		for index in textures.patterns.size():
			var cell := textures.cell_rect(index)
			assert(textures.index_at(cell.get_center()) == index)
			textures.buttons[index].pressed.emit()
			assert(editor.pixel_canvas.texture_index == index)
			assert(cell.position.x >= 0 and cell.position.y >= 0)
			assert(cell.end.x <= textures.size.x + 0.01 and cell.end.y <= textures.size.y + 0.01)
		assert(textures.get_global_rect().end.y <= editor.size.y)
		assert(textures.index_at(Vector2(-1, 0)) == -1)
		assert(textures.index_at(Vector2(textures.size.x, 0)) == -1)
	DirAccess.remove_absolute(folder.path_join("CUSTOM.MIF"))
	DirAccess.remove_absolute(folder)
	editor.free()
	print("PASS: SCURK selection, modal names, synchronized cycling, unclipped save/reload, selected-view indexed PNG, views and viewport fit")
	quit()


func _test_footprints() -> void:
	var canvas := ScurkPixelCanvas.new()
	root.add_child(canvas)
	var blank := PackedInt32Array()
	blank.resize(20 * 20)
	blank.fill(-1)
	canvas.set_sprite_data(20, 20, blank, Sc2Palette.index_encoding())
	canvas.hover_point = Vector2i(10, 10)
	canvas.set_brush(6, true)
	var mask := PackedByteArray()
	mask.resize(400)
	mask.fill(1)
	mask[210] = 0
	canvas.set_edit_region(mask, 1)
	for tool in range(ScurkPixelCanvas.TOOL_PENCIL, ScurkPixelCanvas.TOOL_RECTANGLE + 1):
		canvas.set_tool(tool)
		canvas.pixels = blank.duplicate()
		canvas.hover_point = Vector2i(12, 13)
		canvas.shape_start = Vector2i(7, 8)
		canvas.stroke_active = true
		canvas.stroke_base_pixels = blank.duplicate()
		if tool == ScurkPixelCanvas.TOOL_ERASER:
			canvas.pixels.fill(5)
		var before := canvas.pixels.duplicate()
		var footprint := canvas.tool_footprint()
		if canvas._is_shape_tool(tool):
			canvas._preview_shape(canvas.hover_point)
		else:
			canvas._apply_brush(canvas.hover_point)
		for y in 20:
			for x in 20:
				var point := Vector2i(x, y)
				assert(footprint.has(point) == (before[y * 20 + x] != canvas.pixels[y * 20 + x]))
	canvas.pixels = blank.duplicate()
	canvas.set_tool(ScurkPixelCanvas.TOOL_FILL)
	canvas.hover_point = Vector2i(9, 10)
	assert(canvas.tool_footprint().size() == 399)
	canvas.set_tool(ScurkPixelCanvas.TOOL_PASTE)
	canvas.clipboard_width = 3
	canvas.clipboard_height = 2
	canvas.clipboard_pixels = PackedInt32Array([1, -1, 1, 1, 1, 1])
	assert(canvas.tool_footprint().size() == 5)
	canvas.set_tool(ScurkPixelCanvas.TOOL_EYEDROPPER)
	assert(canvas.tool_footprint().size() == 1)
	canvas.clipboard_width = 3
	canvas.clipboard_height = 2
	canvas.clipboard_pixels = PackedInt32Array([1, 2, 3, 4, 5, 6])
	canvas.rotate_clipboard_clockwise()
	assert(canvas.clipboard_width == 2 and canvas.clipboard_height == 3)
	assert(canvas.clipboard_pixels == PackedInt32Array([4, 1, 5, 2, 6, 3]))
	canvas.rotate_clipboard_counterclockwise()
	assert(canvas.clipboard_pixels == PackedInt32Array([1, 2, 3, 4, 5, 6]))
	blank.resize(32 * 32)
	blank.fill(-1)
	canvas.clear_edit_region()
	canvas.set_sprite_data(32, 32, blank, Sc2Palette.index_encoding())
	canvas.set_tool(ScurkPixelCanvas.TOOL_PENCIL)
	canvas.set_brush(24, false)
	canvas.hover_point = Vector2i(15, 15)
	assert(canvas.tool_footprint().size() == 24 * 24)
	canvas.set_brush(24, true)
	var footprint := canvas.tool_footprint()
	assert(footprint.size() < 24 * 24 and footprint.size() > 400)
	canvas._apply_brush(canvas.hover_point)
	for point in footprint:
		assert(canvas.pixel_at(point) == canvas.foreground_index)
	canvas.set_brush(25, false)
	assert(canvas.brush_size == 24)
	canvas.free()
