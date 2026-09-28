extends SceneTree

@warning_ignore_start("integer_division")

const EditorScene = preload("res://src/ui/scurk/scurk_editor_control.tscn")
const Workspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.gui_embed_subwindows = true
	_test_preview_crop()
	_test_footprints()
	await _test_tile_selector()
	var assets := OriginalGameAssets.new()
	assert(FixtureGraphics.pack().apply_to(assets))
	_test_clip_edges(assets)
	var editor := EditorScene.instantiate() as ScurkEditorControl
	root.add_child(editor)
	editor.configure(assets.palette, assets.large_sprites, assets.small_medium_sprites,
		"res://tests/fixtures", assets.scurk_graphics)
	assert(editor.load_tile_set(ScurkMif.from_archives([assets.large_sprites, assets.small_medium_sprites])).ok)
	assert(editor.show_editor().ok)
	await process_frame
	await process_frame
	await _test_pick_copy_preview(assets, editor.pick_copy_control)
	await _test_pick_copy_wheel(editor)
	await _test_pick_copy_destination(editor, assets)
	_test_pick_copy_differences(editor, assets)
	_test_pick_copy_animation(editor, assets)
	_test_copy_difference(assets)
	_test_close_confirmation(editor)
	await _test_tile_browser(editor)
	assert(editor.object_list.entries[0].thumbnail != null)
	var guides := editor.drawing_controls.get_node("Margin/Scroll/Column/Isometric")
	guides.get_node("Guides").button_pressed = true
	guides.get_node("GuideFields/Spacing").value = 24
	guides.get_node("GuideFields/OffsetX").value = 3
	guides.get_node("GuideFields/OffsetY").value = -2
	assert(editor.pixel_canvas.show_isometric_guides)
	assert(editor.pixel_canvas.paint_options.guide_spacing == Vector2i(24, 12))
	assert(editor.pixel_canvas.paint_options.guide_offset == Vector2i(3, -2))
	guides.get_node("Guides").button_pressed = false
	assert(not editor.pixel_canvas.show_isometric_guides)
	assert(editor.view_previews[3].preview_indices == editor.view_previews[0].preview_indices)
	assert(editor.view_previews[3].display_bounds == editor.view_previews[0].display_bounds)
	assert(editor.view_previews[3].custom_minimum_size.y > editor.view_previews[0].custom_minimum_size.y)
	_test_clipping_toggle(editor)
	_test_underground_canvas(editor)
	_test_clipboard_actions(editor)
	_test_paint_sidebar(editor)
	editor.brush_size_selector.value = 24
	assert(editor.pixel_canvas.brush_size == 24)
	editor.brush_size_selector.value = 25
	assert(editor.brush_size_selector.value == 24)
	editor.brush_size_selector.value = 1
	# Only tools that paint with a brush expose its size and shape controls.
	var snap_lines := editor.drawing_controls.get_node("Margin/Scroll/Column/Brush/SnapLines") as CheckBox
	for tool in editor.tool_buttons.size():
		editor.tool_buttons[tool].pressed.emit()
		assert(snap_lines.is_visible_in_tree() == (tool == ScurkPixelCanvas.TOOL_LINE))
		var uses_brush := tool <= ScurkPixelCanvas.TOOL_RECTANGLE or tool == ScurkPixelCanvas.TOOL_SHADE
		assert(editor.brush_size_selector.is_visible_in_tree() == uses_brush)
		assert(editor.round_brush_check.is_visible_in_tree() == uses_brush)
		assert(editor.filled_shapes_check.is_visible_in_tree() == (tool >= ScurkPixelCanvas.TOOL_DIAMOND
			and tool <= ScurkPixelCanvas.TOOL_RECTANGLE))
	assert(editor.studio.tabs.current_tab == 2)
	editor.tool_buttons[ScurkPixelCanvas.TOOL_LINE].pressed.emit()
	snap_lines.button_pressed = true
	assert(editor.pixel_canvas.paint_options.isometric_snap)
	snap_lines.button_pressed = false
	assert(not editor.pixel_canvas.paint_options.isometric_snap)
	editor.tool_buttons[ScurkPixelCanvas.TOOL_PENCIL].pressed.emit()
	var terrain := editor.canvas_panel.get_node("Footer/Row/Clipping/Terrain") as CheckBox
	var background := editor.surface_background_pixels.duplicate()
	editor.surface_background_pixels.resize(Workspace.WIDTH * Workspace.HEIGHT)
	editor.surface_background_pixels.fill(42)
	editor.view_preview_signatures.fill("")
	editor._refresh_view_previews()
	var terrain_indices := editor.view_previews[0].preview_indices.duplicate()
	terrain.button_pressed = false
	assert(not editor.pixel_canvas.show_terrain)
	assert(editor.view_previews[0].preview_indices.count(-1) > terrain_indices.count(-1))
	terrain.button_pressed = true
	assert(editor.pixel_canvas.show_terrain)
	assert(editor.view_previews[0].preview_indices == terrain_indices)
	editor.surface_background_pixels = background
	editor.view_preview_signatures.fill("")
	editor._refresh_view_previews()
	editor.studio.tabs.current_tab = 0
	editor._on_object_selected(0)
	editor.request_edit_name()
	assert(editor.name_edit.text == ScurkEditorRules.tile_name(1))
	assert(editor.object_panel.name_dialog.visible and editor.object_panel.name_dialog.exclusive)
	editor.name_edit.text = "Test tile"
	editor.object_panel.name_dialog.confirmed.emit()
	editor.object_panel.name_dialog.hide()
	assert(editor.tile_set.names[1] == "Test tile")
	assert(editor.object_list.entries[editor.object_list.selected].title == "Test tile")
	editor.request_edit_name()
	assert(editor.name_edit.text == "Test tile")
	editor.object_panel.name_dialog.hide()
	editor.revert_name_button.pressed.emit()
	assert(not editor.tile_set.names.has(1))
	assert(editor.object_list.entries[editor.object_list.selected].title == QueryStrings.tile_name(1))
	editor.undo()
	assert(editor.tile_set.names[1] == "Test tile")
	assert(editor.object_list.entries[editor.object_list.selected].title == "Test tile")
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
	editor.canvas_panel.clip_enabled_check.button_pressed = false
	assert(editor.clip_region_check.disabled and not editor.pixel_canvas.show_clip_region)
	assert(editor.pixel_canvas.clip_guide_rects().is_empty())
	editor.canvas_panel.clip_enabled_check.button_pressed = true
	assert(not editor.clip_region_check.disabled and editor.pixel_canvas.show_clip_region)
	for view in 3:
		editor._select_view(view)
		assert(editor.pixel_canvas.background_view == view)
	editor._select_view(0)
	assert(editor.tile_set.to_bytes().bytes == before_clip_controls)
	editor.clip_region_check.button_pressed = false
	var folder := _test_expanded_artwork_and_export(editor, assets)

	for index in editor.canvas_panel.preview_checks.size():
		editor.canvas_panel.preview_checks[index].button_pressed = false
		assert(not editor.view_preview_panels[index].visible)
		editor._refresh_view_previews()
		assert(not editor.view_preview_panels[index].visible, "Artwork refresh retains the view filter")
		for other in editor.view_preview_panels.size():
			assert(editor.view_preview_panels[other].visible == (other != index))
		editor.canvas_panel.preview_checks[index].button_pressed = true
		assert(editor.view_preview_panels[index].visible)
	await process_frame
	await process_frame
	var enlarged := editor.view_preview_panels[3].get_global_rect()
	for index in 3:
		assert(enlarged.position.y >= editor.view_preview_panels[index].get_global_rect().end.y)
	for check in editor.canvas_panel.preview_checks:
		assert(editor.get_global_rect().encloses(check.get_global_rect()), "Preview filters stay inside the editor")
	editor.canvas_panel.show_views_button.button_pressed = false
	assert(not editor.canvas_panel.previews_panel.visible)
	await _test_resize_layout(editor)
	DirAccess.remove_absolute(folder.path_join("CUSTOM.MIF"))
	DirAccess.remove_absolute(folder)

	editor.free()
	await _test_context_menu_input()
	await _test_menu_bar_shortcuts()
	print(("PASS: SCURK selection, modal names, synchronized cycling, unclipped save/reload, "
		+ "selected-view indexed PNG, views and viewport fit"))
	quit()


func _test_tile_selector() -> void:
	var selector := preload("res://src/ui/scurk/scurk_tile_selector.tscn").instantiate() as ScurkTileSelector
	root.add_child(selector)
	var entries: Array[ScurkTileSelector.Entry] = [
		ScurkTileSelector.Entry.new(1001, "First tile", "Landscape", null),
		ScurkTileSelector.Entry.new(1002, "Second tile", "Landscape", null),
		ScurkTileSelector.Entry.new(1201, "Third tile", "Building", null),
	]
	selector.set_entries(entries, 1002)
	assert(selector.selected == 1 and selector.rows.is_empty(), "Popup rows are built only when needed")
	selector.show_choices()
	await process_frame
	await process_frame
	assert(selector.rows.size() == entries.size())
	assert(selector.get_node("Popup").visible)
	assert(selector.rows[1].has_focus())
	var chosen := [-1]
	selector.item_selected.connect(func(index: int) -> void: chosen[0] = index)
	selector.rows[2].pressed.emit()
	assert(chosen[0] == 2 and selector.selected == 2)
	assert(not selector.get_node("Popup").visible)
	selector.set_entries([entries[0]], 1201)
	assert(selector.selected == 0 and selector.entries[0].large_id == 1001)
	selector.show_choices()
	await process_frame
	assert(selector.rows.size() == 1)
	selector.set_entries([], 1001)
	assert(selector.disabled and selector.selected == -1 and not selector.get_node("Popup").visible)
	selector.free()


func _test_pick_copy_preview(assets: OriginalGameAssets, picker: ScurkPickCopyControl) -> void:
	picker.configure(assets.palette, assets.large_sprites, assets.small_medium_sprites, "")
	var working := ScurkMif.from_archives([assets.large_sprites, assets.small_medium_sprites])
	var source := ScurkMif.from_archives([assets.large_sprites, assets.small_medium_sprites])
	var ids := ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_RESIDENTIAL)
	for view in ScurkSpriteIds.VIEW_COUNT:
		assert(source.set_shape_indices(ids[0] - view * 500, 2, 2, PackedInt32Array([10 + view, 20, 30, 40])).ok)
	picker.open_with_working(working, "")
	assert(picker.preview_before.texture == null and picker.preview_after.texture == null)
	picker.source_set = source
	picker._refresh_lists()
	picker.source_list.select(0)
	picker.source_list.multi_selected.emit(0, true)
	assert(picker.preview_large_id == ids[0])
	assert(picker.working_list.selected_large_ids() == PackedInt32Array([ids[0]]))
	assert(not picker.copy_selected_button.disabled)
	for view in ScurkSpriteIds.VIEW_COUNT:
		picker._select_view(view)
		var source_image := ScurkPickCopy.resolved_entry(source, ids[0] - view * 500,
			assets.large_sprites, assets.small_medium_sprites).create_image(assets.palette).image
		var working_image := ScurkPickCopy.resolved_entry(working, ids[0] - view * 500,
			assets.large_sprites, assets.small_medium_sprites).create_image(assets.palette).image
		assert(PixelArtTexture.unwrap(picker.preview_after.texture).get_image().get_data() == source_image.get_data())
		assert(PixelArtTexture.unwrap(picker.preview_before.texture).get_image().get_data() == working_image.get_data())

	# Multiple selection previews each matching destination without changing the copy selection.
	picker.source_list.select(1, false)
	picker.source_list.multi_selected.emit(1, true)
	assert(picker.preview_large_id == ids[1] and not picker.preview_previous.disabled)
	picker.preview_previous.pressed.emit()
	assert(picker.preview_large_id == ids[0] and not picker.preview_next.disabled)
	picker.preview_next.pressed.emit()
	assert(picker.preview_large_id == ids[1])
	assert(picker.working_list.selected_large_ids() == PackedInt32Array([ids[0], ids[1]]))
	picker.working_list.select(2)
	picker.working_list.multi_selected.emit(2, true)
	assert(picker.source_list.selected_large_ids() == PackedInt32Array([ids[2]]))
	assert(picker.preview_large_id == ids[2] and not picker.preview_previous.visible)
	picker.working_list.select(0)
	picker.working_list.multi_selected.emit(0, true)
	picker.working_list.select(1, false)
	picker.working_list.multi_selected.emit(1, true)
	assert(picker.source_list.selected_large_ids() == PackedInt32Array([ids[0], ids[1]]))
	assert(picker.preview_previous.visible and picker.preview_next.visible)
	assert(picker.working_list.selected_large_ids() == PackedInt32Array([ids[0], ids[1]]))
	var requests: Array[PackedInt32Array] = []
	var capture := func(_source: ScurkMif, selected: PackedInt32Array, _description: String, _destinations: PackedInt32Array) -> void:
		assert(_destinations.is_empty())
		requests.append(selected)
	# Test the selection signal without changing the editor's separate working document.
	var editor_copy := Callable(picker.get_parent().get_parent(), "_copy_pick_objects")
	picker.copy_requested.disconnect(editor_copy)
	picker.copy_requested.connect(capture)
	picker.copy_selected_button.pressed.emit()
	assert(requests == [PackedInt32Array([ids[0], ids[1]])])
	var copied := ScurkPickCopy.copy_objects(working, source, requests[0], assets.large_sprites, assets.small_medium_sprites)
	assert(copied.ok and copied.shape_count == 6)
	picker.copy_completed(copied)
	picker.preview_previous.pressed.emit()
	assert(PixelArtTexture.unwrap(picker.preview_before.texture).get_image().get_data()
		== PixelArtTexture.unwrap(picker.preview_after.texture).get_image().get_data())

	# A group change removes stale selection and artwork. The preview fits the window.
	picker._select_group(ScurkPickCopy.GROUP_COMMERCIAL)
	assert(picker.preview_before.texture == null and picker.preview_after.texture == null)
	assert(picker.copy_selected_button.disabled)
	await process_frame
	await process_frame
	assert(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(picker.get_global_rect()))
	assert(picker.get_global_rect().encloses(picker.preview_before.get_global_rect()))
	assert(picker.source_list.size.y >= 120 and picker.working_list.size.y >= 120)
	assert(picker.get_global_rect().encloses(picker.copy_selected_button.get_global_rect()))
	var source_scroll := picker.source_list.get_v_scroll_bar()
	var working_scroll := picker.working_list.get_v_scroll_bar()
	var scroll_end := source_scroll.max_value - source_scroll.page
	assert(scroll_end > 0)
	source_scroll.value = scroll_end * 0.75
	await process_frame
	assert(source_scroll.value > 0 and is_equal_approx(source_scroll.value, working_scroll.value))
	working_scroll.value = scroll_end * 0.25
	await process_frame
	assert(working_scroll.value < scroll_end * 0.5 and is_equal_approx(source_scroll.value, working_scroll.value))
	picker._select_view(ScurkSpriteIds.View.LARGE)
	await process_frame
	assert(is_equal_approx(source_scroll.value, working_scroll.value))
	picker.copy_requested.disconnect(capture)
	picker.copy_requested.connect(editor_copy)
	picker.request_close()


func _test_pick_copy_wheel(editor: ScurkEditorControl) -> void:
	var picker := editor.pick_copy_control
	var delay: float = ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.01)
	var viewport := SubViewport.new()
	viewport.size = root.size
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	editor.reparent(viewport)
	var tooltips := AppTooltips.new()
	viewport.add_child(tooltips)
	editor.request_pick_copy()
	picker._select_group(ScurkPickCopy.GROUP_ALL)
	await process_frame
	viewport.notify_mouse_entered()
	for list in [picker.source_list, picker.working_list]:
		list.get_v_scroll_bar().value = 0
		var point: Vector2 = list.global_position + list.get_item_rect(1).get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.relative = Vector2(32, 0)
		viewport.push_input(motion, true)
		await create_timer(0.15).timeout
		await process_frame
		await process_frame
		if list == picker.source_list:
			assert(_visible_tooltip(viewport), "Show a real tooltip before checking wheel input")
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = point
		wheel.global_position = point
		viewport.push_input(wheel, true)
		await process_frame
		assert(list.get_v_scroll_bar().value > 0, "Wheel input after a tooltip must reach the copy list")
		assert(is_equal_approx(picker.source_list.get_v_scroll_bar().value, picker.working_list.get_v_scroll_bar().value))
	picker.request_close()
	editor.reparent(root)
	viewport.free()
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", delay)


func _visible_tooltip(node: Node) -> bool:
	if node is PopupPanel and node.theme_type_variation == &"TooltipPanel" and node.visible:
		return true
	for child in node.get_children(true):
		if _visible_tooltip(child):
			return true
	return false


func _test_copy_difference(assets: OriginalGameAssets) -> void:
	var before := Sc2SpriteArchive.entry_from_indices(1000, 2, 2, PackedInt32Array([10, 20, -1, 40]))
	var after := Sc2SpriteArchive.entry_from_indices(1000, 2, 2, PackedInt32Array([11, -1, 30, 40]))
	var diff := ScurkCopyDifference.compare(before, after, assets.palette)
	assert(diff.changed_pixels == 3)
	assert(diff.image.get_pixel(0, 0).is_equal_approx(ScurkCopyDifference.CHANGED_COLOR))
	assert(diff.image.get_pixel(1, 0).is_equal_approx(ScurkCopyDifference.CHANGED_COLOR))
	assert(diff.image.get_pixel(0, 1).is_equal_approx(ScurkCopyDifference.CHANGED_COLOR))
	assert(diff.image.get_pixel(1, 1).a < 0.5)
	# Padding aligns at the bottom center, including newly added and removed artwork.
	var padded := Sc2SpriteArchive.entry_from_indices(1000, 4, 3,
		PackedInt32Array([-1, -1, -1, -1, -1, 10, 20, -1, -1, -1, 40, -1]))
	assert(ScurkCopyDifference.compare(before, padded, assets.palette).changed_pixels == 0)
	assert(ScurkCopyDifference.compare(padded, before, assets.palette).changed_pixels == 0)
	assert(ScurkCopyDifference.compare(before, before, assets.palette).changed_pixels == 0)


func _test_pick_copy_differences(editor: ScurkEditorControl, assets: OriginalGameAssets) -> void:
	var picker := editor.pick_copy_control
	var filter := picker.get_node("Content/Toolbar/Controls/DifferencesOnly") as CheckBox
	var remap := picker.get_node("Content/Toolbar/Controls/AllowDestination") as CheckBox
	var highlight := picker.get_node("Content/Toolbar/Controls/HighlightDifferences") as CheckBox
	var difference_art := picker.get_node("Content/Preview/Images/Differences/Artwork") as TextureRect
	var other_sizes_note := picker.get_node("Content/Preview/Images/Differences/OtherSizesNote") as Label
	assert(not filter.button_pressed)
	var working := ScurkMif.from_archives([assets.large_sprites, assets.small_medium_sprites])
	var source := ScurkMif.from_archives([assets.large_sprites, assets.small_medium_sprites])
	var ids := ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_RESIDENTIAL)
	var pixels := PackedInt32Array([10, 20, -1, 40])
	for value in [source, working]:
		for index in 4:
			for view in ScurkSpriteIds.VIEW_COUNT:
				assert(value.set_shape_indices(ids[index] - view * 500, 2, 2, pixels).ok)
	# Changes in any size count. Names and different sprite encodings do not.
	assert(source.set_shape_indices(ids[0], 2, 2, PackedInt32Array([11, 20, -1, 40])).ok)
	assert(source.set_shape_indices(ids[1] - 500, 4, 1, pixels).ok)
	assert(source.set_shape_indices(ids[2] - 1000, 2, 2, PackedInt32Array([10, 20, 30, 40])).ok)
	source.names[ScurkEditorRules.object_tile_id(ids[3])] = "Different name, same graphics"
	var encoded_source := ScurkMif.new()
	assert(encoded_source.parse(source.to_bytes().bytes))
	picker.source_set = encoded_source
	picker.source_icon_cache.clear()
	picker._select_group(ScurkPickCopy.GROUP_RESIDENTIAL)
	picker.open_with_working(working, "")
	filter.button_pressed = true
	assert(picker._shown_source_ids() == ids.slice(0, 3))
	assert(picker.working_list.item_count == 3)
	picker.source_list.select(0)
	picker.source_list.multi_selected.emit(0, true)
	highlight.button_pressed = true
	picker._select_view(ScurkSpriteIds.View.LARGE)
	assert(difference_art.texture != null)
	assert(PixelArtTexture.unwrap(difference_art.texture).get_image().get_pixel(0, 0).is_equal_approx(ScurkCopyDifference.CHANGED_COLOR))
	for view in ScurkSpriteIds.VIEW_COUNT:
		picker._select_view(view)
		assert(picker._shown_source_ids() == ids.slice(0, 3))
		assert(other_sizes_note.visible == (view != ScurkSpriteIds.View.LARGE))
	remap.button_pressed = true
	picker.source_list.select(0)
	picker.source_list.item_selected.emit(0)
	assert(picker.working_list.item_count == 3)
	remap.button_pressed = false
	var editor_copy := Callable(editor, "_copy_pick_objects")
	var requests: Array[PackedInt32Array] = []
	var capture := func(_source: ScurkMif, selected: PackedInt32Array, _description: String, _destinations: PackedInt32Array) -> void:
		requests.append(selected)
	picker.copy_requested.disconnect(editor_copy)
	picker.copy_requested.connect(capture)
	picker._copy_all_confirmed()
	assert(requests == [ids.slice(0, 3)])
	picker.copy_requested.disconnect(capture)
	picker.copy_requested.connect(editor_copy)
	var original := working.to_bytes().bytes
	var copied := ScurkPickCopy.copy_objects(working, encoded_source, ids.slice(0, 3), assets.large_sprites, assets.small_medium_sprites)
	assert(copied.ok)
	picker.copy_completed(copied)
	assert(picker.source_list.item_count == 0 and picker.working_list.item_count == 0)
	assert(picker.copy_selected_button.disabled and picker.copy_all_button.disabled)
	assert(picker.preview_before.texture == null and picker.preview_after.texture == null)
	assert(difference_art.texture == null)
	assert(not other_sizes_note.visible)
	var restored := ScurkMif.new()
	assert(restored.parse(original))
	picker.open_with_working(restored, "")
	assert(picker._shown_source_ids() == ids.slice(0, 3))
	filter.button_pressed = false
	highlight.button_pressed = false
	assert(picker.source_list.item_count == ids.size() and picker.working_list.item_count == ids.size())
	picker.request_close()


func _test_pick_copy_animation(editor: ScurkEditorControl, assets: OriginalGameAssets) -> void:
	var picker := editor.pick_copy_control
	var working := ScurkMif.from_archives([assets.large_sprites, assets.small_medium_sprites])
	var source := ScurkMif.from_archives([assets.large_sprites, assets.small_medium_sprites])
	var large_id := ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_RESIDENTIAL)[0]
	for value in [source, working]:
		for view in ScurkSpriteIds.VIEW_COUNT:
			assert(value.set_shape_indices(large_id - view * 500, 2, 2, PackedInt32Array([171, 224, 10, -1])).ok)
	var source_bytes := source.to_bytes().bytes
	var working_bytes := working.to_bytes().bytes
	picker.source_set = source
	picker.source_icon_cache.clear()
	picker._select_group(ScurkPickCopy.GROUP_RESIDENTIAL)
	picker.open_with_working(working, "")
	picker.source_list.select(0)
	picker.source_list.multi_selected.emit(0, true)
	editor._set_cycle_colors(false)
	var canvas_visible := editor.pixel_canvas.visible
	editor.pixel_canvas.hide()
	for view in ScurkSpriteIds.VIEW_COUNT:
		picker._select_view(view)
		picker.set_cycle_tick(0)
		picker.palette_cycle_accumulator = 0.0
		var icons: Array[ScurkPickCopyControl.ObjectIcon] = [
			picker.working_icon_cache["%d:%d:false" % [view, large_id]],
			picker.source_icon_cache["%d:%d:false" % [view, large_id]],
			picker.source_icon_cache["%d:%d:true" % [view, large_id]],
			picker.working_icon_cache["%d:%d:true" % [view, large_id]],
		]
		assert(icons[0].texture == picker.preview_before.texture and icons[1].texture == picker.preview_after.texture)
		assert(icons[2].texture == picker.source_list.get_item_icon(0) and icons[3].texture == picker.working_list.get_item_icon(0))
		picker._process(Sc2Palette.SCURK_TIMER_INTERVAL_SECONDS * 31.5)
		assert(picker.palette_cycle_ticks == 31)
		var mapping := assets.palette.scurk_animation_index_map(31)
		# The headless texture driver retains the initial upload. Check the updated image data.
		for icon in icons:
			var animated := icon.image
			assert(animated.get_pixel(0, 0).is_equal_approx(assets.palette.color(mapping[171])))
			assert(animated.get_pixel(1, 0).is_equal_approx(assets.palette.color(mapping[224])))
			assert(animated.get_pixel(0, 1).is_equal_approx(assets.palette.color(10)))
			assert(animated.get_pixel(1, 1).a == 0.0)
		picker.set_cycle_tick(0)
		for icon in icons:
			assert(icon.image.get_pixel(0, 0).is_equal_approx(assets.palette.color(171)))
	assert(source.to_bytes().bytes == source_bytes and working.to_bytes().bytes == working_bytes)
	editor.pixel_canvas.visible = canvas_visible
	editor._set_cycle_colors(true)
	picker.request_close()
	var tick := picker.palette_cycle_ticks
	picker._process(1.0)
	assert(picker.palette_cycle_ticks == tick, "Closed previews must not advance the palette clock")


func _test_pick_copy_destination(editor: ScurkEditorControl, assets: OriginalGameAssets) -> void:
	var picker := editor.pick_copy_control
	var checkbox := picker.get_node("Content/Toolbar/Controls/AllowDestination") as CheckBox
	var destination_group := picker.get_node("Content/Toolbar/Controls/DestinationGroup") as OptionButton
	assert(not checkbox.button_pressed)
	var original: PackedByteArray = editor.tile_set.to_bytes().bytes
	var source := ScurkMif.from_archives([])
	var source_id := 1000 + BuildingTileIds.CHEMICAL_PROCESSING_3X3
	var destination_id := 1000 + BuildingTileIds.LARGE_APARTMENT_BUILDING_3X3_1
	for view in 3:
		assert(source.set_shape_indices(source_id - view * 500, 2, 2, PackedInt32Array([10 + view, -1, 30, 40])).ok)
	var source_bytes: PackedByteArray = source.to_bytes().bytes
	picker.open_with_working(editor.tile_set, "")
	picker.source_set = source
	picker.source_icon_cache.clear()
	checkbox.button_pressed = true
	picker.group_selector.select(ScurkPickCopy.GROUP_INDUSTRIAL)
	picker.group_selector.item_selected.emit(ScurkPickCopy.GROUP_INDUSTRIAL)
	destination_group.select(ScurkPickCopy.GROUP_RESIDENTIAL)
	destination_group.item_selected.emit(ScurkPickCopy.GROUP_RESIDENTIAL)
	assert(picker.working_set == editor.tile_set)
	assert(picker.working_list.item_count == 0)
	picker.source_list.select(0)
	picker.source_list.item_selected.emit(0)
	assert(picker.copy_selected_button.disabled)
	assert(picker.working_list.item_count == 4)
	for index in picker.working_list.item_count:
		assert(ScurkPickCopy.footprint_size(int(picker.working_list.get_item_metadata(index))) == 3)
	picker.working_list.select(0)
	picker.working_list.item_selected.emit(0)
	# Changing the source footprint hides incompatible destinations and clears their selection.
	picker.source_list.select(1)
	picker.source_list.item_selected.emit(1)
	assert(picker.working_list.item_count == 8 and picker.working_list.selected_large_ids().is_empty())
	assert(picker.preview_before.texture == null)
	for index in picker.working_list.item_count:
		assert(ScurkPickCopy.footprint_size(int(picker.working_list.get_item_metadata(index))) == 2)
	picker.source_list.select(0)
	picker.source_list.item_selected.emit(0)
	destination_group.select(ScurkPickCopy.GROUP_POWER)
	destination_group.item_selected.emit(ScurkPickCopy.GROUP_POWER)
	assert(picker.working_list.item_count == 0 and picker.copy_selected_button.disabled)
	destination_group.select(ScurkPickCopy.GROUP_RESIDENTIAL)
	destination_group.item_selected.emit(ScurkPickCopy.GROUP_RESIDENTIAL)
	assert(picker.working_list.item_count == 4)
	assert(picker.copy_selected_button.disabled)
	picker._request_copy_selected()
	assert(editor.tile_set.to_bytes().bytes == original)
	picker.working_list.select(0)
	picker.working_list.item_selected.emit(0)
	assert(not picker.copy_selected_button.disabled)
	assert(picker.source_list.selected_large_ids() == PackedInt32Array([source_id]))
	assert(picker.working_list.selected_large_ids() == PackedInt32Array([destination_id]))
	var expected_source := source.archive.find_sprite(source_id - picker.current_view * 500).create_image(assets.palette).image
	var expected_target := ScurkPickCopy.resolved_entry(editor.tile_set, destination_id - picker.current_view * 500,
		assets.large_sprites, assets.small_medium_sprites).create_image(assets.palette).image
	assert(PixelArtTexture.unwrap(picker.preview_after.texture).get_image().get_data() == expected_source.get_data())
	assert(PixelArtTexture.unwrap(picker.preview_before.texture).get_image().get_data() == expected_target.get_data())
	await process_frame
	await process_frame
	var source_scroll := picker.source_list.get_v_scroll_bar()
	var working_scroll := picker.working_list.get_v_scroll_bar()
	working_scroll.value = 0
	source_scroll.value = source_scroll.max_value - source_scroll.page
	assert(source_scroll.value > 0 and working_scroll.value == 0)
	source_scroll.value = 0
	var drag := ScurkObjectList.CopyObjectsDrag.new(picker.source_list.get_instance_id(), PackedInt32Array([source_id]))
	assert(picker.working_list._can_drop_data(picker.working_list.get_item_rect(0).get_center(), drag))
	var incompatible_drag := ScurkObjectList.CopyObjectsDrag.new(picker.source_list.get_instance_id(),
		PackedInt32Array([1000 + BuildingTileIds.CHEMICAL_PROCESSING_2X2]))
	assert(not picker.working_list._can_drop_data(picker.working_list.get_item_rect(0).get_center(), incompatible_drag))
	assert(not picker.working_list._can_drop_data(Vector2(-1, -1), drag))
	# Keep the source's editable layers while replacing the destination's layers.
	editor._select_object(source_id)
	var source_key := editor.studio.key()
	var source_document: Dictionary = editor.studio.project.documents[source_key].duplicate(true)
	editor._select_object(destination_id)
	var destination_key := editor.studio.key()
	var destination_document: Dictionary = editor.studio.project.documents[destination_key].duplicate(true)
	editor._select_object(source_id)
	var history_count := editor.undo_stack.size()
	picker.copy_selected_button.pressed.emit()
	assert(editor.undo_stack.size() == history_count + 1)
	assert(not editor.studio.project.documents.has(destination_key))
	assert(editor.studio.project.documents[source_key] == source_document)
	for view in 3:
		assert(editor.tile_set.overrides.find_sprite(destination_id - view * 500).decode_indices().pixels
			== source.archive.find_sprite(source_id - view * 500).decode_indices().pixels)
	assert(source.to_bytes().bytes == source_bytes)
	var copied: PackedByteArray = editor.tile_set.to_bytes().bytes
	editor.undo()
	assert(editor.tile_set.to_bytes().bytes == original)
	assert(editor.studio.project.documents[destination_key] == destination_document)
	assert(PixelArtTexture.unwrap(picker.preview_before.texture).get_image().get_data() == expected_target.get_data())
	editor.redo()
	assert(editor.tile_set.to_bytes().bytes == copied)
	editor.undo()
	await process_frame
	picker.working_list._drop_data(picker.working_list.get_item_rect(0).get_center(), drag)
	assert(editor.tile_set.to_bytes().bytes == copied)
	editor.undo()
	# Disable remapping: restore matching groups, multi-selection and linked scrolling.
	checkbox.button_pressed = false
	assert(not picker.working_list.remap_drops)
	assert(picker.source_list.select_mode == ItemList.SELECT_MULTI)
	assert(picker.working_list.selected_large_ids() == picker.source_list.selected_large_ids())
	assert(picker.source_list.item_count == picker.working_list.item_count)
	picker.request_close()
	var restored := ScurkMif.new()
	assert(restored.parse(original) and editor.load_tile_set(restored).ok)
	editor._select_object(1001)


func _test_paint_sidebar(editor: ScurkEditorControl) -> void:
	var paint := editor.drawing_controls.get_node("Margin/Scroll/Column/Paint")
	var lock := paint.get_node("Lock") as CheckBox
	var perfect := paint.get_node("Perfect") as CheckBox
	editor._select_tool(ScurkPixelCanvas.TOOL_PENCIL)
	editor.brush_size_selector.value = 1
	lock.button_pressed = true
	perfect.button_pressed = true
	assert(editor.pixel_canvas.paint_options.lock_transparent)
	assert(editor.pixel_canvas.paint_options.pixel_perfect)
	assert(lock.is_visible_in_tree() and perfect.is_visible_in_tree())
	editor.brush_size_selector.value = 2
	assert(not perfect.is_visible_in_tree())
	editor.brush_size_selector.value = 1
	assert(perfect.is_visible_in_tree() and perfect.button_pressed)
	for tool in editor.tool_buttons.size():
		editor._select_tool(tool)
		assert(perfect.is_visible_in_tree() == (tool == ScurkPixelCanvas.TOOL_PENCIL))
		assert(lock.is_visible_in_tree() == (tool not in [ScurkPixelCanvas.TOOL_EYEDROPPER, ScurkPixelCanvas.TOOL_SHADE]))
	editor._select_tool(ScurkPixelCanvas.TOOL_PENCIL)
	editor.pixel_canvas.select_all()
	assert(editor.pixel_canvas.copy_selection())
	assert(editor.pixel_canvas.begin_paste(Vector2i.ZERO))
	assert(lock.is_visible_in_tree() and not perfect.is_visible_in_tree())
	editor.pixel_canvas.cancel_paste()
	assert(editor.pixel_canvas.begin_paste(Vector2i.ZERO, true))
	assert(not lock.is_visible_in_tree() and not perfect.is_visible_in_tree())
	editor.pixel_canvas.cancel_paste()
	editor.pixel_canvas.clear_selection()
	var compare := editor.canvas_panel.get_node("Footer/Row/Compare/Mode") as OptionButton
	for mode in range(compare.item_count - 1, -1, -1):
		compare.select(mode)
		compare.item_selected.emit(mode)
		assert(editor.pixel_canvas.comparison_mode == mode)
	lock.button_pressed = false
	perfect.button_pressed = false
	assert(not editor.pixel_canvas.paint_options.lock_transparent and not editor.pixel_canvas.paint_options.pixel_perfect)
	editor._select_tool(ScurkPixelCanvas.TOOL_PENCIL)


func _assert_inside(bounds: Rect2, control: Control) -> void:
	var rect := control.get_global_rect()
	assert(
		rect.position.x >= bounds.position.x and rect.position.y >= bounds.position.y,
		"%s: %s starts outside %s" % [control.get_path(), rect, bounds],
	)
	assert(rect.end.x <= bounds.end.x and rect.end.y <= bounds.end.y, "%s: %s ends outside %s" % [control.get_path(), rect, bounds])


func _test_clipping_toggle(editor: ScurkEditorControl) -> void:
	var before: PackedByteArray = editor.tile_set.to_bytes().bytes
	for id in [1124, 1127]:
		for row in editor.object_list.entries.size():
			if editor.object_list.entries[row].large_id == id:
				editor._on_object_selected(row)
				break
		assert(editor.current_large_id == id)
		for view in 3:
			editor._select_view(view)
			editor.canvas_panel.clip_enabled_check.button_pressed = false
			var entry: Sc2SpriteArchive.SpriteEntry = editor._resolved_view_entry(view)
			var decoded := entry.decode_indices()
			var expected := Workspace.from_shape(entry.width, entry.height, decoded.pixels, view, editor.active_base_width, false)
			assert(editor.pixel_canvas.pixels == expected)
			editor.canvas_panel.clip_enabled_check.button_pressed = true
			assert(editor.pixel_canvas.pixels == expected)
			assert(editor.pixel_canvas.edit_mask == Workspace.clip_mask(editor.active_base_width, view))
	assert(editor.tile_set.to_bytes().bytes == before)
	editor._select_view(0)
	editor._on_object_selected(0)


func _test_clip_edges(assets: OriginalGameAssets) -> void:
	for id in [1124, 1127]:
		var base := assets.large_sprites.find_sprite(id)
		for view in 3:
			var archive := assets.large_sprites if view == 0 else assets.small_medium_sprites
			var entry := archive.find_sprite(ScurkEditorRules.view_sprite_id(id, view))
			var decoded := entry.decode_indices()
			assert(decoded.ok)
			var raw := Workspace.from_shape(entry.width, entry.height, decoded.pixels, view, base.width, false)
			var clipped := Workspace.from_shape(entry.width, entry.height, decoded.pixels, view, base.width)
			assert(clipped == raw)
			var output := Workspace.shape_from_workspace(clipped, base.width, view)
			assert(output.ok and output.width == entry.width and output.height == entry.height)
			assert(output.pixels == decoded.pixels)
			var canvas := ScurkPixelCanvas.new()
			canvas.set_sprite_data(Workspace.WIDTH, Workspace.HEIGHT, raw, assets.palette)
			canvas.set_edit_region(Workspace.clip_mask(base.width, view), Workspace.base_size(base.width))
			assert(canvas.pixels == raw)
			canvas.free()
	for width in Workspace.STANDARD_BASE_WIDTHS:
		for view in 3:
			var divisor := Workspace.view_divisor(view)
			var mask := Workspace.clip_mask(width, view)
			assert(mask[255 * Workspace.WIDTH + 64 - divisor] == 1)
			assert(mask[255 * Workspace.WIDTH + 63 + divisor] == 1)
			assert(mask[255 * Workspace.WIDTH + 63 - divisor] == 0)
			assert(mask[255 * Workspace.WIDTH + 64 + divisor] == 0)
			for y in Workspace.HEIGHT:
				for x in Workspace.WIDTH / 2:
					assert(mask[y * Workspace.WIDTH + x] == mask[y * Workspace.WIDTH + Workspace.WIDTH - 1 - x])


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
		if ScurkPixelCanvas.is_shape_tool(tool):
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
	canvas.clipboard_width = 3
	canvas.clipboard_height = 2
	canvas.clipboard_pixels = PackedInt32Array([1, -1, 1, 1, 1, 1])
	assert(canvas.begin_paste(canvas.hover_point))
	assert(canvas.paste_position == canvas.hover_point)
	var pasted := canvas.composite_pixels()
	assert(pasted[canvas.hover_point.y * 20 + canvas.hover_point.x] == 1)
	assert(canvas.pixel_at(canvas.hover_point) == -1)
	canvas.cancel_paste()
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
	var ellipse_footprint := canvas.tool_footprint()
	assert(ellipse_footprint.size() < 24 * 24 and ellipse_footprint.size() > 400)
	canvas._apply_brush(canvas.hover_point)
	for point in ellipse_footprint:
		assert(canvas.pixel_at(point) == canvas.selected_color_index)
	canvas.set_brush(25, false)
	assert(canvas.brush_size == 24)
	canvas.free()


func _test_clipboard_actions(editor: ScurkEditorControl) -> void:
	var canvas := editor.pixel_canvas
	var artwork := canvas.pixels.duplicate()
	assert(editor.tool_buttons.size() == 16)
	editor._select_tool(ScurkPixelCanvas.TOOL_SELECT_RECT)
	editor._studio_action("CopySelection")
	assert(canvas.has_clipboard())
	assert(canvas.tool == ScurkPixelCanvas.TOOL_SELECT_RECT)
	editor._studio_action("PasteSelection")
	assert(canvas.paste_active and canvas.paste_follow_cursor)
	assert(canvas.tool == ScurkPixelCanvas.TOOL_SELECT_RECT and canvas.pixels == artwork)
	canvas.cancel_paste()
	var point := Vector2i(-1, -1)
	for offset in artwork.size():
		if artwork[offset] >= 0 and (canvas.edit_mask.is_empty() or canvas.edit_mask[offset] != 0):
			point = Vector2i(offset % canvas.sprite_width, offset / canvas.sprite_width)
			break
	assert(point.x >= 0)
	canvas.selection.combine(canvas.selection.rectangle(point, point))
	for command in [KEY_C, KEY_X, KEY_V]:
		var shortcut_event := InputEventKey.new()
		shortcut_event.keycode = command
		shortcut_event.pressed = true
		shortcut_event.ctrl_pressed = true
		editor.object_list.grab_focus()
		assert(editor.handle_shortcut(shortcut_event))
		assert(canvas.tool == ScurkPixelCanvas.TOOL_SELECT_RECT)
		if command == KEY_C:
			assert(canvas.clipboard_width == 1 and canvas.clipboard_height == 1)
		elif command == KEY_X:
			assert(canvas.pixel_at(point) == -1)
		else:
			assert(canvas.paste_active and canvas.paste_follow_cursor)
	canvas.cancel_paste()
	editor.undo()
	assert(canvas.pixels == artwork)
	var event := InputEventKey.new()
	event.keycode = KEY_X
	event.pressed = true
	event.meta_pressed = true
	editor.studio.tabs.current_tab = 4
	editor.studio.get_node(editor.studio.META + "/Author").grab_focus()
	assert(not editor.handle_shortcut(event))
	assert(canvas.pixels == artwork)
	canvas.clear_selection()
	editor._select_tool(ScurkPixelCanvas.TOOL_PENCIL)


func _test_preview_crop() -> void:
	var preview := ScurkViewPreview.new()
	preview.crop_to_artwork = true
	var pixels := PackedInt32Array([-1, 42, -1, -1])
	var terrain := PackedInt32Array()
	terrain.resize(Workspace.WIDTH * Workspace.HEIGHT)
	terrain.fill(55)
	preview.set_preview(0, 2, 2, pixels, 32, null, terrain, false)
	assert(preview.artwork_bounds.size == Vector2i.ONE)
	assert(preview.display_bounds.encloses(preview.artwork_bounds))
	assert(preview.display_bounds.size.x < preview.preview_width)
	var bounds := preview.display_bounds
	preview.set_preview(0, 2, 2, pixels, 32, null, PackedInt32Array(), false)
	assert(preview.display_bounds == bounds)
	preview.clear_preview(0)
	assert(preview.display_bounds.has_area())
	preview.free()


func _test_context_menu_input() -> void:
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu := ScurkContextMenu.new()
	host.add_child(menu)
	menu.add_item("Action")
	var clicks: Array[Vector2] = []
	host.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_RIGHT:
			clicks.append(input_event.position)
			menu.position = Vector2i(input_event.position)
			menu.popup()
	)
	menu.position = Vector2i(20, 20)
	menu.popup()
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	var destination := Vector2(400, 300)
	event.position = menu.get_screen_transform().affine_inverse() * (root.get_screen_transform() * destination)
	menu._outside_click(event)
	assert(not menu.visible)
	await process_frame
	assert(clicks.size() == 1 and clicks[0].is_equal_approx(destination))
	assert(menu.visible)
	# An inside right-click must not close or forward the event.
	event.position = Vector2(2, 2)
	menu._outside_click(event)
	await process_frame
	assert(menu.visible and clicks.size() == 1)
	menu.hide()
	host.free()


func _test_menu_bar_shortcuts() -> void:
	var toolbar := preload("res://src/ui/scurk/scurk_editor_toolbar.tscn").instantiate() as ScurkEditorToolbar
	root.add_child(toolbar)
	var actions: Array[String] = []
	toolbar.studio_action.connect(func(action: String) -> void: actions.append(action))
	toolbar.pick_copy_requested.connect(func() -> void: actions.append("PickCopy"))
	var files := (toolbar.get_node("Row/File") as MenuButton).get_popup()
	files.id_pressed.emit(7)
	assert(actions == ["PickCopy"])
	actions.clear()
	var menu := (toolbar.get_node("Row/Edit") as MenuButton).get_popup()
	var event := InputEventKey.new()
	event.keycode = KEY_C
	event.pressed = true
	event.shift_pressed = true
	event.meta_pressed = OS.has_feature("macos")
	event.ctrl_pressed = not event.meta_pressed
	menu.popup()
	await process_frame
	menu.window_input.emit(event)
	assert(actions == ["CopyAllLayers"] and not menu.visible)
	await process_frame
	(toolbar.get_node("Actions/CopyAllLayers") as Button).disabled = true
	menu.popup()
	await process_frame
	menu.window_input.emit(event)
	assert(actions == ["CopyAllLayers"], "Disabled menu action ran: %s" % [actions])
	menu.hide()
	toolbar.free()

	if OS.has_feature("macos"):
		assert(ScurkContextMenu.key_hint(KEY_MASK_META | KEY_COMMA) == "⌘,", "A macOS hint shows the key character")
		assert(ScurkContextMenu.key_hint(KEY_MASK_META | KEY_MASK_SHIFT | KEY_C) == "⇧⌘C")
		assert(ScurkContextMenu.key_hint(KEY_MASK_META | KEY_ESCAPE) == "⌘⎋")


func _test_underground_canvas(editor: ScurkEditorControl) -> void:
	var original_id := editor.current_large_id
	var original_view := editor.current_view
	var underground_id := ScurkSpriteIds.LARGE_FIRST + CityUndergroundView.SUBWAY_AND_PIPE_FIRST + UndergroundTileIds.SUBWAY_LR
	editor.current_large_id = underground_id
	for view in [ScurkSpriteIds.View.LARGE, ScurkSpriteIds.View.MEDIUM, ScurkSpriteIds.View.SMALL]:
		editor.current_view = view
		editor._refresh_sprite()
		var entry := editor._resolved_view_entry(view) as Sc2SpriteArchive.SpriteEntry
		var pixels := editor.pixel_canvas.pixels.duplicate()
		var background := editor.pixel_canvas.clear_background_pixels
		assert(background.size() == Workspace.WIDTH * Workspace.HEIGHT)
		assert(background != editor.surface_background_pixels)
		var sprites := editor.base_large_sprites if view == ScurkSpriteIds.View.LARGE else editor.base_small_medium_sprites
		var ground := sprites.find_sprite(ScurkEditorRules.view_sprite_id(ScurkSpriteIds.LARGE_FIRST
			+ CityUndergroundView.TERRAIN_WIREFRAME_FIRST, view))
		var source := ground.decode_indices().pixels
		var divisor := Workspace.view_divisor(view)
		var origin := Vector2i((Workspace.WIDTH - ground.width * divisor) / 2, Workspace.HEIGHT - entry.height * divisor)
		var sample := Vector2i(ground.width / 2, ground.height - 1)
		var target := origin + sample * divisor
		assert(background[target.y * Workspace.WIDTH + target.x] == source[sample.y * ground.width + sample.x])
		editor.pixel_canvas.show_terrain = false
		editor._refresh_view_previews()
		assert(editor.pixel_canvas.pixels == pixels)
		editor.pixel_canvas.show_terrain = true
	editor.current_large_id = original_id
	editor.current_view = original_view
	editor._refresh_sprite()
	assert(editor.pixel_canvas.clear_background_pixels == editor.surface_background_pixels)


func _test_close_confirmation(editor: ScurkEditorControl) -> void:
	var closed: Array[bool] = []
	var on_close := func() -> void: closed.append(true)
	editor.close_requested.connect(on_close)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	var dialog := editor.get_node("Dialogs/Close") as ConfirmationDialog
	assert(not editor.dirty)
	editor.pixel_canvas.select_all()
	editor.studio.tabs.current_tab = 4
	editor.studio.get_node(editor.studio.META + "/Author").grab_focus()
	assert(editor.handle_shortcut(escape))
	assert(not editor.pixel_canvas.selection.active() and not dialog.visible)
	assert(editor.handle_shortcut(escape))
	assert(editor.visible and dialog.visible and closed.is_empty())
	dialog.canceled.emit()
	dialog.hide()
	assert(editor.visible and closed.is_empty())
	assert(editor.handle_shortcut(escape))
	dialog.confirmed.emit()
	dialog.hide()
	assert(not editor.visible and closed.size() == 1)
	editor.show()
	editor.studio.modified = true
	assert(editor.handle_shortcut(escape))
	assert(editor.visible and editor.discard_dialog.visible and not dialog.visible)
	editor.discard_dialog.canceled.emit()
	editor.discard_dialog.hide()
	assert(editor.dirty and closed.size() == 1)
	editor.studio.modified = false
	editor.close_requested.disconnect(on_close)


func _test_expanded_artwork_and_export(editor: ScurkEditorControl, assets: OriginalGameAssets) -> String:
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
	# the Format list sets the file filter, the file extension, and the encoder
	editor.request_export_bmp()
	editor.dialog_registry.export_format.select(2)
	editor.dialog_registry.export_options.confirmed.emit()
	editor.dialog_registry.export_options.hide()
	editor.export_bmp_dialog.hide()
	assert(editor.export_bmp_dialog.filters == PackedStringArray(["*.bmp ; 256-color indexed BMP"]))
	assert(editor.export_bmp_dialog.current_file.ends_with(".bmp"))
	var bitmap_path := folder.path_join("view-0.bmp")
	editor._export_selected_bmp(bitmap_path)
	assert(IndexedBmp.decode(FileAccess.get_file_as_bytes(bitmap_path)).width == editor._output_shape_for_view(0).width)
	DirAccess.remove_absolute(bitmap_path)
	editor.dialog_registry.export_format.select(0)
	assert(not editor.export_image_path(folder.path_join("invalid.png"), 3).ok)
	assert(not editor.export_image_path(folder.path_join("invalid.png"), 0, 4).ok)
	editor.canvas_panel.show_views_button.button_pressed = true
	assert(editor.canvas_panel.previews_panel.visible)
	return folder


func _test_resize_layout(editor: ScurkEditorControl) -> void:
	# controls stay visible through resize cycles
	var textures := editor.palette_panel.texture_control
	for viewport_size in [Vector2(1024, 768), Vector2(1280, 800), Vector2(1600, 1000), Vector2(1024, 768)]:
		editor.size = viewport_size
		for frame in 4:
			await process_frame
		var bounds := editor.get_global_rect()
		for control: Control in [editor.get_node("Panel/Content"), editor.get_node("Panel/Content/Toolbar"),
			editor.get_node("Panel/Content/Body"), editor.studio, editor.get_node("Panel/Content/StatusBar"),
			editor.canvas_panel, editor.canvas_panel.pixel_scroll, editor.canvas_panel.get_node("Footer")]:
			_assert_inside(bounds, control)
		assert(editor.canvas_panel.pixel_scroll.size.x > 0 and editor.canvas_panel.pixel_scroll.size.y > 0)
		var colors := editor.palette_panel.palette_control
		for slot in colors.visible_indices.size():
			var cell := colors._cell_rect(slot)
			assert(colors.index_at(cell.get_center()) == colors.visible_indices[slot])
			assert(is_equal_approx(cell.size.x, cell.size.y))
		assert(is_equal_approx(colors._cell_rect(255).end.x, colors.size.x))
		assert(is_equal_approx(colors._cell_rect(255).end.y, colors.size.y))
		var columns := textures.columns
		var texture_rect := textures.get_global_rect()
		for frame in 4:
			await process_frame
			assert(textures.columns == columns and textures.get_global_rect() == texture_rect)
		for index in textures.patterns.size():
			var cell := textures.cell_rect(index)
			assert(textures.index_at(cell.get_center()) == index)
			textures.buttons[index].pressed.emit()
			assert(editor.pixel_canvas.texture_index == index)
			assert(cell.size.x >= 32 and cell.size.y >= 32)
			assert(cell.position.x >= 0 and cell.position.y >= 0)
			assert(cell.end.x <= textures.size.x + 0.01 and cell.end.y <= textures.size.y + 0.01)
		var palette_scroll := editor.palette_panel.get_node("Margin/Scroll") as ScrollContainer
		palette_scroll.ensure_control_visible(textures)
		await process_frame
		assert(textures.get_global_rect().end.y <= editor.size.y)
		palette_scroll.scroll_vertical = 0
		assert(textures.index_at(Vector2(-1, 0)) == -1)
		assert(textures.index_at(Vector2(textures.size.x, 0)) == -1)


func _test_tile_browser(editor: ScurkEditorControl) -> void:
	var current_id := editor.current_large_id
	var selector := editor.object_list
	var browser := editor.tile_browser
	editor.object_panel.get_node("Browse").pressed.emit()
	await process_frame
	await process_frame
	assert(browser.visible and browser.exclusive)
	assert(browser.cards.size() == selector.entries.size())
	assert(browser.cards.size() == 499)
	for card in browser.cards:
		assert(card.visible)
	assert(editor.canvas_panel.pixel_scroll.get_global_rect().encloses(editor.object_panel.get_global_rect()))
	assert(browser.size.x <= root.size.x and browser.size.y <= root.size.y, "Browser %s exceeds viewport %s" % [browser.size, root.size])
	browser.search.text = "255"
	browser.search.text_changed.emit("255")
	var matched := 0
	var match_index := -1
	for index in browser.cards.size():
		if browser.cards[index].visible:
			matched += 1
			match_index = index
	assert(matched == 1)
	assert(browser.entries[match_index].large_id == 1255)
	var category := browser.entries[match_index].category
	browser.category_checks[category].button_pressed = false
	assert(not browser.cards[match_index].visible)
	assert(editor.current_large_id == current_id)
	browser.category_checks[category].button_pressed = true
	assert(browser.cards[match_index].visible)
	browser.search.text = "no matching tile"
	browser.search.text_changed.emit(browser.search.text)
	for card in browser.cards:
		assert(not card.visible)
	assert(editor.current_large_id == current_id)
	browser.search.text = "255"
	browser.search.text_changed.emit("255")
	var graphic := browser.cards[match_index].get_child(0) as TextureRect
	assert(graphic.texture != null and graphic.texture.get_width() > 32)
	browser.cards[match_index].pressed.emit()
	assert(not browser.visible and editor.current_large_id == 1255)
	assert(selector.entries[selector.selected].large_id == 1255)
	editor._browse_tiles()
	assert(browser.search.text == "255")
	browser.hide()
	assert(editor.current_large_id == 1255)
	browser.search.clear()
	editor._on_object_selected(0)
