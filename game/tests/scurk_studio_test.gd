extends SceneTree

const EditorScene = preload("res://src/ui/scurk/scurk_editor_control.tscn")
const Workspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")
const ContextPreview = preload("res://src/view/scurk_context_preview.gd")

var editor: ScurkEditorControl
var studio: ScurkEditorStudio
var original := PackedByteArray()
var folder := "user://scurk-studio-test-%d" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 1000)
	var assets := OriginalGameAssets.load_root(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	editor = EditorScene.instantiate() as ScurkEditorControl
	root.add_child(editor)
	studio = editor.studio
	studio.recovery_path = folder.path_join("recovery.scurk")
	editor.configure(assets.palette, assets.large_sprites, assets.small_medium_sprites,
		ProjectSettings.globalize_path("res://../references/SIMCITY2000"), assets.scurk_graphics)
	assert(editor.show_editor().ok)
	original = editor.tile_set.to_bytes().bytes
	editor._set_cycle_colors(false)
	await process_frame
	await process_frame
	await _test_sidebar()
	_test_layers()
	_test_layer_menu()
	_test_project()
	_test_delete_confirmation()
	_test_undo_history()
	_test_clipboard_layers()
	_test_all_layer_clipboard()
	_test_canvas_menu()
	_test_clear()
	_test_recovery_ownership()
	_test_replace()
	_test_import()
	_test_context()
	await _test_navigation()
	editor.free()
	var directory := DirAccess.open(folder)
	if directory != null:
		for name in directory.get_files():
			directory.remove(name)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("SCURK studio checks passed")
	quit()


func _fresh() -> void:
	var mif := ScurkMif.new()
	assert(mif.parse(original))
	assert(editor.load_tile_set(mif).ok)
	editor._set_clipping_enabled(false)


func _commit(pixels: PackedInt32Array) -> void:
	editor._capture_edit_start()
	editor._commit_pixels(pixels)


func _solid(index: int) -> PackedInt32Array:
	var pixels := editor.pixel_canvas.pixels.duplicate()
	pixels.fill(index)
	return pixels


func _document() -> Dictionary:
	return studio.project.documents[studio.key()]


func _test_sidebar() -> void:
	_fresh()
	var canvas := editor.pixel_canvas
	var scroll := editor.canvas_panel.pixel_scroll
	assert(studio.tabs.current_tab == 0 and editor.palette_panel.is_visible_in_tree())
	canvas.set_zoom(12)
	await process_frame
	await process_frame
	scroll.scroll_horizontal = 120
	scroll.scroll_vertical = 500
	await process_frame
	canvas.selection.combine(canvas.selection.rectangle(Vector2i(60, 200), Vector2i(63, 203)))
	var selection := canvas.selection.mask.duplicate()
	var position := Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical)
	var canvas_rect := canvas.get_global_rect()
	var author := studio.get_node(studio.META + "/Author") as LineEdit
	author.text = "Unapplied author"
	for tab in studio.tabs.get_tab_count():
		studio.tabs.current_tab = tab
		await process_frame
		assert(canvas.is_visible_in_tree() and canvas.selection.mask == selection)
		assert(editor.object_search.is_visible_in_tree() and editor.object_list.is_visible_in_tree())
		assert(canvas.zoom == 12 and canvas.get_global_rect() == canvas_rect, "%d zoom %d rect %s expected %s" % [tab, canvas.zoom, canvas.get_global_rect(), canvas_rect])
		assert(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical) == position)
		canvas.grab_focus()
		assert(root.gui_get_focus_owner() == canvas)
	assert(author.text == "Unapplied author")
	studio.tabs.current_tab = 1
	assert(studio.tabs.current_tab == 1)
	var add := studio.get_node(studio.LAYERS + "/Row/Actions/Add") as Button
	assert(add.is_visible_in_tree())
	add.pressed.emit()
	assert(_document().layers.size() == 2)
	var list := studio.get_node(studio.LAYERS + "/Row/List") as Tree
	list.get_root().get_child(1).select(1)
	list.item_selected.emit()
	assert(int(_document().active) == 0)
	list.get_root().get_child(0).select(1)
	list.item_selected.emit()
	assert(int(_document().active) == 1)
	editor._select_tool(ScurkPixelCanvas.TOOL_PENCIL)
	editor._select_palette_index(99)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(ScurkPixelCanvas.DISPLAY_MARGIN, 0) + Vector2(60, 200) * canvas.zoom
	event.pressed = true
	canvas._gui_input(event)
	event.pressed = false
	canvas._gui_input(event)
	assert(canvas.pixels[200 * Workspace.WIDTH + 60] == 99)
	assert(studio.tabs.current_tab == 1 and list.is_visible_in_tree())
	assert(canvas.selection.mask == selection)
	studio.get_node(studio.LAYERS + "/Name").text = "Windows"
	studio.get_node(studio.LAYERS + "/Name").text_changed.emit("Windows")
	assert(_document().layers[1].name == "Windows")
	studio.tabs.current_tab = 2
	studio.get_node(studio.STAMPS + "/Name").text = "Window stamp"
	studio.get_node(studio.STAMPS + "/Actions/Add").pressed.emit()
	assert(studio.project.stamps.size() == 1)
	studio.tabs.current_tab = 0
	editor.undo()
	studio.tabs.current_tab = 2
	var stamps := studio.get_node(studio.STAMPS + "/List") as ItemList
	assert(stamps.item_count == 0)
	editor.redo()
	studio.tabs.current_tab = 0
	studio.tabs.current_tab = 2
	assert(stamps.item_count == 1)
	stamps.select(0)
	stamps.item_selected.emit(0)
	assert(editor.current_tool == ScurkPixelCanvas.TOOL_STAMP)
	assert(canvas.paint_options.stamp_pixels.count(99) > 0)
	studio.tabs.current_tab = 3
	var history := studio.get_node(studio.HISTORY + "/List") as ItemList
	assert(history.item_count == editor.undo_stack.size() + editor.redo_stack.size() + 1)
	assert(history.get_selected_items() == PackedInt32Array([editor.undo_stack.size()]))
	studio.tabs.current_tab = 0


func _test_delete_confirmation() -> void:
	_fresh()
	studio._layer_action("Add")
	_commit(_solid(99))
	var before := editor.tile_set.to_bytes().bytes
	var count := editor.undo_stack.size()
	var dialog := studio.get_node("DeleteLayer") as ConfirmationDialog
	studio._layer_action("Delete")
	assert(dialog.visible and dialog.exclusive)
	assert(_document().layers.size() == 2 and editor.undo_stack.size() == count)
	dialog.canceled.emit()
	dialog.hide()
	assert(_document().layers.size() == 2 and editor.tile_set.to_bytes().bytes == before)
	studio._layer_action("Delete")
	dialog.confirmed.emit()
	dialog.hide()
	assert(_document().layers.size() == 1 and editor.undo_stack.size() == count + 1)
	editor.undo()
	assert(_document().layers.size() == 2 and editor.tile_set.to_bytes().bytes == before)
	# A document replacement while the dialog is open invalidates its target.
	studio._layer_action("Delete")
	editor.undo()
	count = editor.undo_stack.size()
	dialog.confirmed.emit()
	dialog.hide()
	assert(_document().layers.size() == 2 and editor.undo_stack.size() == count)


func _test_undo_history() -> void:
	_fresh()
	var history := studio.get_node(studio.HISTORY + "/List") as ItemList
	assert(history.item_count == 1)
	var original_pixels := editor.pixel_canvas.pixels.duplicate()
	_commit(_solid(42))
	studio._layer_action("Add")
	assert(history.item_count == 3 and history.get_selected_items() == PackedInt32Array([2]))
	var layers := studio.project.snapshot()
	history.item_selected.emit(0)
	assert(editor.undo_stack.is_empty() and editor.redo_stack.size() == 2)
	assert(editor.pixel_canvas.pixels == original_pixels and history.item_count == 3)
	history.item_selected.emit(2)
	assert(editor.undo_stack.size() == 2 and editor.redo_stack.is_empty())
	assert(studio.project.snapshot() == layers)
	studio.get_node(studio.HISTORY + "/Actions/Undo").pressed.emit()
	assert(editor.undo_stack.size() == 1 and editor.redo_stack.size() == 1)
	_commit(_solid(11))
	assert(editor.redo_stack.is_empty() and history.item_count == 3)
	assert(history.get_selected_items() == PackedInt32Array([2]))


func _test_layers() -> void:
	_fresh()
	_commit(_solid(42))
	var offset := 200 * Workspace.WIDTH + 60
	studio._layer_action("Add")
	assert(_document().layers.size() == 2 and int(_document().active) == 1)
	assert(editor.pixel_canvas.pixels[offset] == -1)
	var overlay := editor.pixel_canvas.pixels.duplicate()
	overlay[offset] = 99
	_commit(overlay)
	assert(studio.project.flatten(studio.key())[offset] == 99)
	assert(editor.pixel_canvas.layer_below_pixels[offset] == 42)
	editor.undo()
	assert(editor.pixel_canvas.pixels[offset] == -1 and _document().layers.size() == 2)
	editor.redo()
	assert(editor.pixel_canvas.pixels[offset] == 99)
	var canvas := editor.pixel_canvas
	canvas.selection.combine(canvas.selection.rectangle(Vector2i(60, 200), Vector2i(60, 200)))
	assert(canvas._begin_selection_move(false))
	canvas.paste_position += Vector2i(4, 0)
	var before_move := editor.tile_set.to_bytes().bytes
	studio._select_layer(0)
	assert(not canvas.paste_active and editor.tile_set.to_bytes().bytes == before_move)
	assert(_document().layers[1].pixels[offset] == 99 and _document().layers[1].pixels[offset + 4] == -1)
	var layers := studio.get_node(studio.LAYERS + "/Row/List") as Tree
	layers.get_root().get_child(0).select(1)
	layers.item_selected.emit()
	assert(int(_document().active) == int(layers.get_selected().get_metadata(1)) and int(_document().active) == 1)
	canvas.clear_selection()
	studio._layer_visible(false)
	assert(studio.project.flatten(studio.key())[offset] == 42 and editor.pixel_canvas.editing_disabled)
	studio._layer_visible(true)
	studio._layer_locked(true)
	assert(editor.pixel_canvas.editing_disabled)
	var locked := studio.project.active_pixels(studio.key())
	_commit(_solid(17))
	assert(studio.project.active_pixels(studio.key()) == locked)
	studio._layer_locked(false)
	studio._layer_action("Down")
	assert(studio.project.flatten(studio.key())[offset] == 42 and int(_document().active) == 0)
	studio._layer_action("Up")
	assert(studio.project.flatten(studio.key())[offset] == 99)
	var path := folder.path_join("flattened.mif")
	assert(editor.save_path(path).ok)
	var mif := ScurkMif.load_path(path)
	assert(mif.is_valid())
	var entry := mif.overrides.find_sprite(editor.current_large_id)
	assert(entry != null)
	var decoded := entry.decode_indices()
	assert(decoded.ok)
	var flattened := Workspace.from_shape(entry.width, entry.height, decoded.pixels, 0, editor.active_base_width, false)
	assert(flattened == studio.project.flatten(studio.key()))
	assert(_document().layers.size() == 2)
	var image_path := folder.path_join("flattened.png")
	assert(editor.export_image_path(image_path, 0).ok)
	var exported := IndexedPng.load_path(image_path)
	assert(exported.ok and exported.pixels == decoded.pixels)
	editor._capture_object_start()
	studio._layer_action("Add")
	_commit(_solid(17))
	assert(_document().layers.size() == 3)
	editor.revert_object()
	assert(_document().layers.size() == 2 and studio.project.flatten(studio.key()) == flattened)
	editor.undo()
	assert(_document().layers.size() == 3 and studio.project.flatten(studio.key())[offset] == 17)
	editor.redo()
	assert(_document().layers.size() == 2 and studio.project.flatten(studio.key()) == flattened)


func _test_clipboard_layers() -> void:
	_fresh()
	var canvas := editor.pixel_canvas
	editor._select_tool(ScurkPixelCanvas.TOOL_PENCIL)
	canvas.set_paint_indices(6, 7)
	var source := _solid(-1)
	var source_point := Vector2i(60, 200)
	var source_offset := source_point.y * Workspace.WIDTH + source_point.x
	var values := PackedInt32Array([42, -1, 73, 99, 51, 88])
	for y in 2:
		for x in 3:
			source[source_offset + y * Workspace.WIDTH + x] = values[y * 3 + x]
	_commit(source)
	studio._layer_action("Add")
	var target := _solid(-1)
	var destination := Vector2i(64, 204)
	var target_offset := destination.y * Workspace.WIDTH + destination.x
	for y in 2:
		for x in 3:
			target[target_offset + y * Workspace.WIDTH + x] = 77
	_commit(target)
	studio._select_layer(0)
	var selected := canvas.selection.empty_mask()
	var copied_mask := PackedByteArray([1, 1, 0, 1, 0, 1])
	for y in 2:
		for x in 3:
			selected[source_offset + y * Workspace.WIDTH + x] = copied_mask[y * 3 + x]
	canvas.selection.combine(selected)
	var history_count := editor.edit_history.undo_stack.size()
	_clipboard_key(KEY_C, true)
	var copied := PackedInt32Array([42, -1, -1, 99, -1, 88])
	assert(canvas.clipboard_width == 3 and canvas.clipboard_height == 2)
	assert(canvas.clipboard_pixels == copied and canvas.clipboard_mask == copied_mask)
	assert(_document().layers[0].pixels == source)
	assert(editor.edit_history.undo_stack.size() == history_count)
	studio._select_layer(1)
	assert(canvas.clipboard_pixels == copied and canvas.clipboard_mask == copied_mask)
	canvas.hover_point = destination
	_clipboard_key(KEY_V, false)
	assert(canvas.paste_active)
	assert(_document().layers[0].pixels == source and _document().layers[1].pixels == target)
	_clipboard_click(destination, MOUSE_BUTTON_LEFT)
	var pasted := target.duplicate()
	for y in 2:
		for x in 3:
			if copied_mask[y * 3 + x] != 0:
				pasted[target_offset + y * Workspace.WIDTH + x] = copied[y * 3 + x]
	assert(_document().layers[0].pixels == source and _document().layers[1].pixels == pasted)
	assert(canvas.tool == ScurkPixelCanvas.TOOL_PENCIL and editor.current_tool == canvas.tool)
	assert(editor.edit_history.undo_stack.size() == history_count + 1)
	editor.undo()
	assert(_document().layers[0].pixels == source and _document().layers[1].pixels == target)
	studio._select_layer(0)
	canvas.selection.combine(selected)
	_clipboard_key(KEY_X, false)
	var cut := source.duplicate()
	for offset in selected.size():
		if selected[offset] != 0:
			cut[offset] = -1
	assert(_document().layers[0].pixels == cut and _document().layers[1].pixels == target)
	assert(canvas.clipboard_pixels == copied and canvas.clipboard_mask == copied_mask)
	assert(editor.edit_history.undo_stack.size() == history_count + 1)
	studio._select_layer(1)
	canvas.hover_point = destination
	_clipboard_key(KEY_V, true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	canvas._gui_input(escape)
	assert(_document().layers[0].pixels == cut and _document().layers[1].pixels == target)
	assert(editor.edit_history.undo_stack.size() == history_count + 1)
	_clipboard_key(KEY_V, false)
	_clipboard_click(destination, MOUSE_BUTTON_LEFT)
	assert(_document().layers[0].pixels == cut and _document().layers[1].pixels == pasted)
	assert(editor.edit_history.undo_stack.size() == history_count + 2)
	editor.undo()
	assert(_document().layers[0].pixels == cut and _document().layers[1].pixels == target)
	editor.undo()
	assert(_document().layers[0].pixels == source and _document().layers[1].pixels == target)
	editor.redo()
	assert(_document().layers[0].pixels == cut and _document().layers[1].pixels == target)
	editor.redo()
	assert(_document().layers[0].pixels == cut and _document().layers[1].pixels == pasted)
	studio._select_layer(0)
	canvas.clear_selection()
	_clipboard_key(KEY_C, false)
	assert(canvas.clipboard_width == 2 and canvas.clipboard_height == 2)
	assert(canvas.clipboard_pixels == PackedInt32Array([-1, 73, 51, -1]))
	_clipboard_key(KEY_X, true)
	assert(_document().layers[0].pixels == _solid(-1))
	editor.undo()
	assert(_document().layers[0].pixels == cut and _document().layers[1].pixels == pasted)
	assert(canvas.tool == ScurkPixelCanvas.TOOL_PENCIL and editor.current_tool == canvas.tool)


func _clipboard_key(code: Key, meta: bool, shift := false) -> void:
	editor.pixel_canvas.grab_focus()
	var event := InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shift
	event.pressed = true
	event.meta_pressed = meta
	event.ctrl_pressed = not meta
	assert(editor.handle_shortcut(event))


func _clipboard_click(point: Vector2i, button: MouseButton) -> void:
	var canvas := editor.pixel_canvas
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = Vector2(canvas.DISPLAY_MARGIN, 0) + (Vector2(point) + Vector2(0.5, 0.5)) * canvas.zoom
	var before := canvas.pixels.duplicate()
	var history_count := editor.edit_history.undo_stack.size()
	event.pressed = true
	canvas._gui_input(event)
	assert(canvas.pixels == before and editor.edit_history.undo_stack.size() == history_count)
	assert(canvas.paste_active == (button == MOUSE_BUTTON_LEFT))
	event.pressed = false
	canvas._gui_input(event)
	assert(not canvas.paste_active)
	assert(editor.edit_history.undo_stack.size() == history_count + (1 if button == MOUSE_BUTTON_LEFT else 0))


func _test_project() -> void:
	var path := folder.path_join("layers.scurk")
	var key := studio.key()
	var expected := studio.project.flatten(key)
	assert(studio.save_project(path))
	assert(not studio.modified)
	var bytes := editor.tile_set.to_bytes().bytes
	studio.get_node(studio.META + "/Author").text = "Tile author"
	studio.get_node(studio.META + "/Title").text = "Layer test"
	studio.get_node(studio.META + "/Notes").text = "Indexed artwork"
	studio._metadata_changed()
	assert(studio.modified and editor.tile_set.to_bytes().bytes == bytes)
	assert(studio.project.metadata.author == "Tile author")
	editor.undo()
	assert(not studio.project.metadata.has("author"))
	assert(studio.get_node(studio.META + "/Author").text.is_empty())
	assert(studio.get_node(studio.META + "/Title").text.is_empty())
	assert(studio.get_node(studio.META + "/Notes").text.is_empty())
	assert(not studio.modified)
	editor.redo()
	assert(studio.project.metadata.author == "Tile author")
	assert(studio.get_node(studio.META + "/Author").text == "Tile author")
	assert(studio.get_node(studio.META + "/Title").text == "Layer test")
	assert(studio.get_node(studio.META + "/Notes").text == "Indexed artwork")
	studio.sync_editor_state()
	studio.project.set_current_mif(editor.tile_set.to_bytes().bytes)
	assert(studio.project.add_checkpoint("Before recolor") == 0)
	assert(studio.project.checkpoints.size() == 1)
	editor.palette_panel.palette_control.toggle_favorite(42)
	editor.palette_panel.palette_control.toggle_ramp_index(42)
	editor.palette_panel.palette_control.toggle_ramp_index(99)
	assert(studio.autosave())
	var recovered := ScurkProject.recover_path(studio.recovery_path)
	assert(recovered.ok and recovered.project.metadata.author == "Tile author")
	assert(recovered.project.flatten(key) == expected)
	assert(studio.load_project(studio.recovery_path, true))
	assert(studio.modified and studio.project_path.is_empty())
	assert(_document().layers.size() == 2 and studio.project.flatten(studio.key()) == expected)
	assert(editor.palette_panel.palette_control.favorite_indices.has(42))
	assert(editor.palette_panel.palette_control.ramp_indices == PackedInt32Array([42, 99]))
	assert(studio.save_project(path))
	assert(not FileAccess.file_exists(studio.recovery_path))
	_commit(_solid(11))
	assert(studio.project.flatten(studio.key()) != expected)
	assert(studio.load_project(path))
	assert(studio.project.flatten(studio.key()) == expected and not studio.modified)
	assert(studio.project.metadata.author == "Tile author" and studio.project.checkpoints.size() == 1)
	assert(studio.get_node(studio.META + "/Author").text == "Tile author")
	assert(studio.get_node(studio.META + "/Title").text == "Layer test")
	assert(studio.get_node(studio.META + "/Notes").text == "Indexed artwork")
	assert(studio.project.original_mif == original)
	var saved_palette := editor.palette_panel.export_state()
	_commit(_solid(11))
	studio._select_history(editor.undo_stack.size() - 1)
	assert(studio.project.flatten(studio.key()) == expected)
	editor.redo()
	assert(studio.project.flatten(studio.key()) != expected)
	editor.undo()
	assert(studio.project.flatten(studio.key()) == expected)
	assert(editor.palette_panel.export_state() == saved_palette)
	assert(studio.save_project(path))
	var saved := ScurkProject.load_path(path)
	assert(saved.ok)
	editor.palette_panel.import_state(saved.project.metadata.palette)
	assert(editor.palette_panel.export_state() == saved_palette)


func _test_clear() -> void:
	_fresh()
	var before := editor.pixel_canvas.pixels.duplicate()
	assert(before.count(-1) < before.size())
	editor.clear_object()
	assert(editor.pixel_canvas.pixels.count(-1) == editor.pixel_canvas.pixels.size())
	assert(editor.pixel_canvas.comparison_pixels == before)
	for view in 3:
		editor._select_view(view)
		assert(editor.pixel_canvas.pixels.count(-1) == editor.pixel_canvas.pixels.size())
		var baseline := editor.pixel_canvas.comparison_pixels
		assert(baseline.count(-1) < baseline.size())
	var path := folder.path_join("blank.scurk")
	assert(studio.save_project(path))
	assert(studio.load_project(path))
	for view in 3:
		editor._select_view(view)
		assert(editor.pixel_canvas.pixels.count(-1) == editor.pixel_canvas.pixels.size())
		var image_path := folder.path_join("blank-%d.png" % view)
		assert(editor.export_image_path(image_path, view).ok)
		var image := IndexedPng.load_path(image_path)
		assert(image.ok and image.pixels.count(-1) == image.pixels.size())


func _test_recovery_ownership() -> void:
	_fresh()
	studio.get_node(studio.META + "/Author").text = "Earlier session"
	studio._metadata_changed()
	assert(studio.autosave())
	var earlier := FileAccess.get_file_as_bytes(studio.recovery_path)
	assert(studio.modified and studio.recovery_owned)
	_fresh()
	assert(not studio.recovery_owned)
	assert(studio.save_project(folder.path_join("unrelated.scurk")))
	assert(not studio.modified and FileAccess.get_file_as_bytes(studio.recovery_path) == earlier)
	studio.get_node(studio.META + "/Author").text = "Current session"
	studio._metadata_changed()
	assert(studio.autosave() and studio.modified and studio.recovery_owned)
	var archives := PackedStringArray()
	for name in DirAccess.get_files_at(folder):
		if name.begins_with("recovery-") and name.ends_with(".scurk"):
			archives.append(folder.path_join(name))
	assert(archives.size() == 1)
	assert(FileAccess.get_file_as_bytes(archives[0]) == earlier)
	var current := ScurkProject.load_path(studio.recovery_path)
	assert(current.ok and current.project.metadata.author == "Current session")
	assert(studio.load_project(studio.recovery_path, true))
	assert(studio.modified and studio.recovery_owned)
	studio.project.metadata["invalid"] = Vector2.ZERO
	assert(not studio.save_project(folder.path_join("failed.scurk")))
	studio.project.metadata.erase("invalid")
	editor.error_dialog.hide()
	assert(studio.modified and studio.recovery_owned and FileAccess.file_exists(studio.recovery_path))
	assert(not FileAccess.file_exists(folder.path_join("failed.scurk")))
	assert(studio.save_project(folder.path_join("recovered-current.scurk")))
	assert(not studio.modified and not FileAccess.file_exists(studio.recovery_path))
	assert(FileAccess.get_file_as_bytes(archives[0]) == earlier)
	assert(studio.load_project(archives[0], true))
	assert(studio.modified and studio.project.metadata.author == "Earlier session")
	assert(studio.save_project(archives[0]))
	assert(not studio.modified and FileAccess.file_exists(archives[0]))
	var saved := ScurkProject.load_path(archives[0])
	assert(saved.ok and saved.project.metadata.author == "Earlier session")


func _test_replace() -> void:
	_fresh()
	for view in 3:
		editor._select_view(view)
		studio.show_replace()
		studio.get_node("Replace").hide()
		for index in 3:
			assert(studio.get_node("Replace/Content/Views/" + ["Large", "Medium", "Small"][index]).button_pressed == (view == index))
	for view in 3:
		editor._select_view(view)
		_commit(_solid(42))
	editor._select_view(0)
	var canvas := editor.pixel_canvas
	canvas.selection.combine(canvas.selection.rectangle(Vector2i(60, 196), Vector2i(63, 199)))
	studio.get_node("Replace/Content/Fields/From").value = 42
	studio.get_node("Replace/Content/Fields/To").value = 77
	for label in ["Large", "Medium", "Small"]:
		studio.get_node("Replace/Content/Views/" + label).button_pressed = true
	var before := editor.tile_set.to_bytes().bytes
	studio._replace_colors()
	var after := editor.tile_set.to_bytes().bytes
	assert(before != after and editor.current_view == 0)
	for view in 3:
		var pixels := studio.project.flatten(studio.key(view))
		assert(pixels[196 * Workspace.WIDTH + 60] == 77)
		assert(pixels[196 * Workspace.WIDTH + 64] == 42)
	editor.undo()
	assert(editor.tile_set.to_bytes().bytes == before)
	editor.redo()
	assert(editor.tile_set.to_bytes().bytes == after)
	canvas.clear_selection()
	studio._layer_locked(true)
	var locked := studio.project.flatten(studio.key())
	studio.show_replace()
	studio.get_node("Replace").hide()
	assert(studio.get_node("Replace/Content/Views/Large").button_pressed)
	assert(not studio.get_node("Replace/Content/Views/Medium").button_pressed)
	assert(not studio.get_node("Replace/Content/Views/Small").button_pressed)
	studio.get_node("Replace/Content/Fields/From").value = 42
	studio.get_node("Replace/Content/Fields/To").value = 19
	studio._replace_colors()
	assert(studio.project.flatten(studio.key()) == locked)
	studio._layer_locked(false)
	studio._replace_colors()
	assert(studio.project.flatten(studio.key())[196 * Workspace.WIDTH + 64] == 19)


func _test_import() -> void:
	_fresh()
	var pixels := PackedInt32Array([42, -1, 99, 171])
	var encoded := IndexedPng.encode(2, 2, pixels, editor.palette)
	assert(encoded.ok)
	var path := folder.path_join("import.png")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(encoded.bytes)
	file.close()
	var before := editor.tile_set.to_bytes().bytes
	studio.preview_import(path)
	assert(studio.get_node("ImportPreview").visible)
	assert(editor.tile_set.to_bytes().bytes == before)
	(studio.get_node("ImportPreview") as ConfirmationDialog).canceled.emit()
	studio.get_node("ImportPreview").hide()
	assert(editor.tile_set.to_bytes().bytes == before)
	studio.preview_import(path)
	studio.get_node("ImportPreview/Content/Placement/X").value = -1
	studio.get_node("ImportPreview/Content/Placement/Y").value = 255
	assert(studio.import_clipped == 3)
	studio.get_node("ImportPreview/Content/Placement/X").value = 60
	studio.get_node("ImportPreview/Content/Placement/Y").value = 196
	assert(studio.import_clipped == 0)
	studio.get_node("ImportPreview").confirmed.emit()
	studio.get_node("ImportPreview").hide()
	var canvas := editor.pixel_canvas
	assert(canvas.pixels[196 * Workspace.WIDTH + 60] == 42)
	assert(canvas.pixels[196 * Workspace.WIDTH + 61] == -1)
	assert(canvas.pixels[197 * Workspace.WIDTH + 60] == 99)
	assert(canvas.pixels[197 * Workspace.WIDTH + 61] == 171)
	assert(editor.tile_set.to_bytes().bytes != before)
	editor.undo()
	assert(editor.tile_set.to_bytes().bytes == before)
	editor.redo()
	assert(editor.pixel_canvas.pixels[196 * Workspace.WIDTH + 60] == 42)


func _test_context() -> void:
	var pixels := PackedInt32Array([-1, 42, 252, 171])
	var texture := ContextPreview.indexed_texture(pixels, 2, 2, editor.palette)
	assert(texture != null)
	var image := texture.get_image()
	assert(image.get_pixel(0, 0).a == 0)
	assert(image.get_pixel(1, 0).is_equal_approx(editor.palette.color(42)))
	assert(image.get_pixel(0, 1).is_equal_approx(editor.palette.color(252)))
	assert(pixels == PackedInt32Array([-1, 42, 252, 171]))
	assert(ContextPreview.indexed_texture(PackedInt32Array([256]), 1, 1, editor.palette) == null)
	studio._refresh_context()
	var preview := studio.get_node("Context/Content/View") as ScurkContextPreview
	assert(preview.artwork != null and preview.snapshot != null and preview.snapshot_city != null)
	studio.get_node("Context/Content/Options/Roads").button_pressed = false
	studio.get_node("Context/Content/Options/Neighbors").button_pressed = false
	assert(not preview.show_roads and not preview.show_neighbors)
	var original_view := editor.current_view
	var original_pixels := editor.pixel_canvas.pixels.duplicate()
	var original_bytes := editor.tile_set.to_bytes().bytes
	for view in 3:
		var button := studio.get_node("Context/Content/Options/" + ["Large", "Medium", "Small"][view]) as Button
		assert(not button.disabled)
		button.pressed.emit()
		assert(studio.context_view == view)
		assert(preview.view_size == [CityIsometricRenderer.VIEW_LARGE, CityIsometricRenderer.VIEW_MEDIUM, CityIsometricRenderer.VIEW_SMALL][view])
		assert(button.button_pressed)
		var shape := editor._output_shape_for_view(view)
		assert(preview.artwork.get_size() == Vector2(shape.width, shape.height))
		assert(editor.current_view == original_view and editor.pixel_canvas.pixels == original_pixels)
	assert(editor.tile_set.to_bytes().bytes == original_bytes)
	studio.show_context()
	assert(studio.context_view == editor.current_view)
	studio.get_node("Context").hide()


func _test_navigation() -> void:
	var panel := editor.canvas_panel
	var canvas := editor.pixel_canvas
	canvas.set_zoom(12)
	await process_frame
	await process_frame
	panel.pixel_scroll.scroll_horizontal = 120
	panel.pixel_scroll.scroll_vertical = 500
	await process_frame
	var point := Vector2(64, 100)
	var local := Vector2(ScurkPixelCanvas.DISPLAY_MARGIN, 0) + point * canvas.zoom
	var anchor := canvas.global_position + local
	await panel.zoom_at(1, local)
	await process_frame
	var shifted := canvas.global_position + Vector2(ScurkPixelCanvas.DISPLAY_MARGIN, 0) + point * canvas.zoom
	assert(shifted.distance_to(anchor) <= 1.5)
	var scroll := Vector2i(panel.pixel_scroll.scroll_horizontal, panel.pixel_scroll.scroll_vertical)
	panel.pan_canvas(Vector2(20, -30))
	assert(panel.pixel_scroll.scroll_horizontal == scroll.x - 20)
	assert(panel.pixel_scroll.scroll_vertical == scroll.y + 30)
	scroll = Vector2i(panel.pixel_scroll.scroll_horizontal, panel.pixel_scroll.scroll_vertical)
	var zoom := canvas.zoom
	editor._select_tool(ScurkPixelCanvas.TOOL_SELECT_LASSO)
	await process_frame
	assert(canvas.zoom == zoom)
	assert(Vector2i(panel.pixel_scroll.scroll_horizontal, panel.pixel_scroll.scroll_vertical) == scroll)
	local = Vector2(ScurkPixelCanvas.DISPLAY_MARGIN, 0) + point * canvas.zoom
	anchor = canvas.global_position + local
	for step in 3:
		panel.zoom_at(1, local)
	for frame in 4:
		await process_frame
	shifted = canvas.global_position + Vector2(ScurkPixelCanvas.DISPLAY_MARGIN, 0) + point * canvas.zoom
	assert(canvas.zoom == zoom + 3 and shifted.distance_to(anchor) <= 1.5)


func _test_all_layer_clipboard() -> void:
	_fresh()
	var canvas := editor.pixel_canvas
	var base := _solid(-1)
	base[0] = 10
	base[1] = 20
	_commit(base)
	studio._layer_action("Add")
	var upper := _solid(-1)
	upper[1] = 30
	upper[2] = 40
	_commit(upper)
	canvas.selection.combine(canvas.selection.rectangle(Vector2i.ZERO, Vector2i(1, 0)))
	var mask := canvas.selection.mask.duplicate()
	var before := studio.project.snapshot()
	_clipboard_key(KEY_C, false, true)
	assert(canvas.clipboard_pixels == PackedInt32Array([10, 30]))
	assert(studio.project.snapshot() == before)
	canvas.paint_options.lock_transparent = true
	var locked_history_size := editor.undo_stack.size()
	_clipboard_key(KEY_X, true, true)
	assert(studio.project.snapshot() == before and editor.undo_stack.size() == locked_history_size)
	assert(canvas.clipboard_pixels == PackedInt32Array([10, 30]))
	canvas.paint_options.lock_transparent = false
	_clipboard_key(KEY_X, true, true)
	assert(_document().layers[0].pixels[0] == -1 and _document().layers[0].pixels[1] == -1)
	assert(_document().layers[1].pixels[1] == -1 and _document().layers[1].pixels[2] == 40)
	editor.undo()
	assert(studio.project.snapshot() == before)
	editor.redo()
	assert(_document().layers[0].pixels[0] == -1)
	editor.undo()
	canvas.selection.mask = mask
	_clipboard_key(KEY_C, true, true)
	# A normal paste flattens the copy onto the active layer only.
	_clipboard_key(KEY_V, false)
	canvas.paste_position = Vector2i(4, 0)
	canvas.commit_paste()
	assert(_document().layers.size() == 2 and _document().layers[0].pixels == base)
	assert(_document().layers[1].pixels[4] == 10 and _document().layers[1].pixels[5] == 30)
	editor.undo()
	var history_size := editor.undo_stack.size()
	_clipboard_key(KEY_V, true, true)
	assert(canvas.paste_active and canvas.paste_new_layer and _document().layers.size() == 2)
	canvas.cancel_paste()
	assert(editor.undo_stack.size() == history_size and _document().layers.size() == 2)
	_clipboard_key(KEY_V, false, true)
	canvas.paste_position = Vector2i(4, 0)
	canvas.commit_paste()
	assert(_document().layers.size() == 3 and editor.undo_stack.size() == history_size + 1)
	assert(_document().layers[2].pixels[4] == 10 and _document().layers[2].pixels[5] == 30)
	assert(_document().layers[0].pixels == base and _document().layers[1].pixels == upper)
	editor.undo()
	assert(studio.project.snapshot() == before)
	editor.redo()
	assert(_document().layers.size() == 3)
	editor.undo()
	# Cuts respect hidden and locked layers; new-layer paste works from a locked layer.
	studio._layer_locked(true)
	canvas.selection.mask = mask
	_clipboard_key(KEY_X, false, true)
	assert(_document().layers[0].pixels[0] == -1 and _document().layers[1].pixels == upper)
	editor.undo()
	studio._layer_visible(false)
	_clipboard_key(KEY_C, false, true)
	assert(canvas.clipboard_pixels == PackedInt32Array([10, 20]))
	_clipboard_key(KEY_V, false, true)
	canvas.paste_position = Vector2i(4, 0)
	canvas.commit_paste()
	assert(_document().layers.size() == 3 and _document().layers[2].pixels[4] == 10)


func _test_layer_menu() -> void:
	_fresh()
	studio._refresh_layer_menu()
	var menu := studio.get_node("LayerMenu") as PopupMenu
	assert(menu.is_item_disabled(menu.get_item_index(studio.LayerAction.DELETE)))
	studio._layer_menu_action(studio.LayerAction.ADD)
	assert(_document().layers.size() == 2)
	studio._layer_menu_action(studio.LayerAction.VISIBLE)
	assert(not _document().layers[1].visible)
	studio._layer_menu_action(studio.LayerAction.LOCKED)
	assert(_document().layers[1].locked)
	studio._refresh_layer_menu()
	assert(menu.is_item_checked(menu.get_item_index(studio.LayerAction.LOCKED)))
	assert(not menu.is_item_checked(menu.get_item_index(studio.LayerAction.VISIBLE)))
	studio._layer_menu_action(studio.LayerAction.DOWN)
	assert(_document().active == 0 and _document().layers[0].locked)
	studio._layer_menu_action(studio.LayerAction.UP)
	assert(_document().active == 1)
	editor.undo()
	assert(_document().active == 0)


func _canvas_action(action: String) -> void:
	editor._refresh_canvas_menu()
	var menu := editor.get_node("CanvasMenu") as PopupMenu
	for index in menu.item_count:
		if menu.get_item_metadata(index) == action:
			assert(not menu.is_item_disabled(index))
			editor._canvas_menu_action(menu.get_item_id(index))
			return
	assert(false, "Missing canvas action: " + action)


func _test_canvas_menu() -> void:
	_fresh()
	var canvas := editor.pixel_canvas
	var source := _solid(-1)
	var offset := 200 * Workspace.WIDTH + 60
	source[offset] = 42
	source[offset + 1] = 55
	source[offset + 2] = 73
	_commit(source)
	canvas.selection.combine(canvas.selection.rectangle(Vector2i(60, 200), Vector2i(61, 200)))
	_canvas_action("CopySelection")
	assert(canvas.clipboard_pixels == PackedInt32Array([42, 55]))
	_canvas_action("SaveStamp")
	assert(studio.project.stamps.back().pixels == PackedInt32Array([42, 55]))
	var count := editor.undo_stack.size()
	_canvas_action("MoveSelectionToLayer")
	assert(_document().layers.size() == 2 and editor.undo_stack.size() == count + 1)
	assert(_document().layers[0].pixels[offset] == -1 and _document().layers[0].pixels[offset + 2] == 73)
	assert(_document().layers[1].pixels[offset] == 42 and _document().layers[1].pixels[offset + 1] == 55)
	assert(studio.project.flatten(studio.key()) == source)
	editor.undo()
	assert(_document().layers.size() == 1 and studio.project.active_pixels(studio.key()) == source)
	editor.redo()
	assert(_document().layers.size() == 2 and studio.project.flatten(studio.key()) == source)
	canvas.selection.combine(canvas.selection.rectangle(Vector2i(60, 200), Vector2i(61, 200)))
	_canvas_action("DuplicateSelection")
	assert(canvas.paste_active and not canvas.paste_clear_source)
	_canvas_action("CancelPaste")
	assert(not canvas.paste_active and not canvas.selection.active())
