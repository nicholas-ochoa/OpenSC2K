class_name ScurkEditorControl
extends ColorRect

signal close_requested
signal tile_set_applied(tile_set: ScurkMif, display_name: String, source_path: String)
signal place_print_requested

const Mif = preload("res://src/assets/scurk_mif.gd")
const IndexedBitmap = preload("res://src/assets/indexed_bmp.gd")
const SystemImageClipboard = preload("res://src/platform/image_clipboard.gd")
const PickCopy = preload("res://src/tools/scurk_pick_copy.gd")
const DrawingWorkspace = preload("res://src/tools/scurk_drawing_workspace.gd")
const EditorHistory = preload("res://src/tools/scurk_editor_history.gd")
const EditorRules = preload("res://src/tools/scurk_editor_rules.gd")
const ToolbarView = preload("res://src/ui/scurk_editor_toolbar.gd")
const DialogsView = preload("res://src/ui/scurk_editor_dialogs.gd")
const ObjectPanelView = preload("res://src/ui/scurk_editor_object_panel.gd")
const DrawingControlsView = preload("res://src/ui/scurk_editor_drawing_controls.gd")
const CanvasPanelView = preload("res://src/ui/scurk_editor_canvas_panel.gd")
const PalettePanelView = preload("res://src/ui/scurk_editor_palette_panel.gd")

const VIEW_LARGE := 0
const VIEW_MEDIUM := 1
const VIEW_SMALL := 2

var palette: Sc2Palette
var base_large_sprites: Sc2SpriteArchive
var base_small_medium_sprites: Sc2SpriteArchive
var reference_directory := ""
var tile_set: ScurkMif
var source_path := ""
var current_large_id := -1
var current_view := VIEW_LARGE
var current_tool := ScurkPixelCanvas.TOOL_PENCIL
var foreground_palette_index := 0
var background_palette_index := 255
var pending_discard_action := ""
var edit_history: ScurkEditorHistory = EditorHistory.new()
var undo_stack: Array[Dictionary]:
	get: return edit_history.undo_stack
var redo_stack: Array[Dictionary]:
	get: return edit_history.redo_stack
var dirty: bool:
	get: return edit_history.dirty
var active_workspace := false
var active_base_width := 0
var view_preview_signatures := PackedStringArray(["", "", ""])

var title_label: Label
var source_label: Label
var object_search: LineEdit
var object_list: ItemList
var name_edit: LineEdit
var name_button: Button
var revert_name_button: Button
var object_panel: ScurkEditorObjectPanel
var view_buttons: Array[Button] = []
var tool_buttons: Array[Button] = []
var paste_tool_button: Button
var clipboard_action_buttons: Array[Button] = []
var copy_object_button: Button
var paste_image_button: Button
var undo_button: Button
var redo_button: Button
var revert_button: Button
var clear_object_button: Button
var save_button: Button
var pixel_canvas: ScurkPixelCanvas
var view_previews: Array[ScurkViewPreview] = []
var view_preview_panels: Array[Control] = []
var palette_panel: ScurkEditorPalettePanel
var brush_size_selector: OptionButton
var filled_shapes_check: CheckBox
var round_brush_check: CheckBox
var grid_check: CheckBox
var snap_to_grid_check: CheckBox
var grid_width_selector: SpinBox
var grid_height_selector: SpinBox
var clip_region_check: CheckBox
var cycle_colors_check: CheckBox
var increment_cycle_button: Button
var drawing_controls: ScurkEditorDrawingControls
var canvas_panel: ScurkEditorCanvasPanel
var zoom_label: Label
var sprite_status_label: Label
var status_label: Label
var open_dialog: FileDialog
var save_dialog: FileDialog
var import_bmp_dialog: FileDialog
var export_bmp_dialog: FileDialog
var discard_dialog: ConfirmationDialog
var error_dialog: AcceptDialog
var pick_copy_control: ScurkPickCopyControl
var dialog_registry: ScurkEditorDialogs


func _ready() -> void:
	name = "SCURKEditor"
	color = Color("c0c0c0")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	hide()


func configure(
	value_palette: Sc2Palette,
	value_large_sprites: Sc2SpriteArchive,
	value_small_medium_sprites: Sc2SpriteArchive,
	value_reference_directory: String,
	value_scurk_graphics: ScurkGraphics = null,
) -> void:
	palette = value_palette
	base_large_sprites = value_large_sprites
	base_small_medium_sprites = value_small_medium_sprites
	reference_directory = value_reference_directory.simplify_path()
	if drawing_controls != null:
		drawing_controls.set_control_images(value_scurk_graphics.control_images if value_scurk_graphics != null else {})
	if pixel_canvas != null and value_scurk_graphics != null:
		pixel_canvas.set_drawing_graphics(value_scurk_graphics)
	elif pixel_canvas != null:
		var textures := pixel_canvas.load_original_textures(
			reference_directory.path_join("WINSCURK.EXE")
		)
		if not textures.ok:
			_set_status(textures.error + " Using fallback texture patterns.")
		var backgrounds := pixel_canvas.load_original_clear_backgrounds(
			reference_directory.path_join("WINSCURK.EXE")
		)
		if not backgrounds.ok:
			_set_status(backgrounds.error + " Using a transparent drawing background.")
	if palette_panel != null and pixel_canvas != null:
		palette_panel.configure(
			palette,
			pixel_canvas.texture_patterns,
			foreground_palette_index, background_palette_index,
			value_scurk_graphics.pattern_names if value_scurk_graphics != null else PackedStringArray(),
		)
		palette_panel.set_workspace_images(value_scurk_graphics.workspace_images if value_scurk_graphics != null else {})
		_select_palette_index(foreground_palette_index, false)
		_select_palette_index(background_palette_index, true)
	if pick_copy_control != null:
		pick_copy_control.configure(
			palette, base_large_sprites, base_small_medium_sprites, reference_directory
		)
	if tile_set != null:
		_refresh_object_list()
		_refresh_sprite()


func show_editor(initial_path := "") -> Dictionary:
	if tile_set == null:
		var path := initial_path
		if path.is_empty():
			path = reference_directory.path_join("SCURKART/ORIGINAL.MIF")
		var loaded := load_path(path)
		if not loaded.ok:
			return loaded
	show()
	move_to_front()
	_refresh_sprite()
	if object_list != null:
		object_list.grab_focus()
	return {"ok": true, "error": ""}


func load_path(path: String) -> Dictionary:
	var loaded := Mif.load_path(path)
	if not loaded.is_valid():
		return {"ok": false, "error": loaded.parse_error}
	return load_tile_set(loaded, path)


func load_tile_set(loaded: ScurkMif, path := "") -> Dictionary:
	if loaded == null or not loaded.is_valid():
		return {"ok": false, "error": "The SCURK tile set is invalid."}
	var encoded := loaded.to_bytes()
	if not encoded.ok:
		return {"ok": false, "error": encoded.error}
	tile_set = loaded
	source_path = ProjectSettings.globalize_path(path).simplify_path() if not path.is_empty() else ""
	edit_history.reset(encoded.bytes)
	var ids := editable_large_sprite_ids(tile_set, base_large_sprites)
	current_large_id = ids[0] if not ids.is_empty() else -1
	current_view = VIEW_LARGE
	_refresh_object_list()
	_capture_object_start()
	_refresh_sprite()
	_update_history_buttons()
	_update_title()
	_set_status(
		"Loaded %s: %d objects and %d names."
		% [source_path.get_file() if not source_path.is_empty() else "the active graphics set", ids.size(), tile_set.names.size()]
	)
	if pick_copy_control != null and pick_copy_control.visible:
		pick_copy_control.open_with_working(tile_set, source_path)
	return {"ok": true, "error": ""}


func save_path(path: String) -> Dictionary:
	if tile_set == null or not tile_set.is_valid():
		return {"ok": false, "error": "No valid SCURK tile set is loaded."}
	var output_path := ProjectSettings.globalize_path(path).simplify_path()
	if output_path.get_extension().to_lower() != "mif":
		output_path += ".MIF"
	if path_is_within(output_path, reference_directory):
		return {
			"ok": false,
			"error": "The original game data folder is read-only. Use another folder.",
		}
	var parent := output_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent)
	if directory_error != OK:
		return {
			"ok": false,
			"error": "Cannot create the output directory: %s" % error_string(directory_error),
		}
	var saved := tile_set.save_path(output_path)
	if not saved.ok:
		return saved
	var encoded := tile_set.to_bytes()
	if not encoded.ok:
		return {"ok": false, "error": encoded.error}
	source_path = output_path
	edit_history.mark_saved(encoded.bytes)
	_update_title()
	if pick_copy_control != null and pick_copy_control.visible:
		pick_copy_control.open_with_working(tile_set, source_path)
	_set_status("Saved %s." % source_path.get_file())
	return {"ok": true, "error": "", "path": source_path}


func request_close() -> void:
	if dirty:
		pending_discard_action = "close"
		discard_dialog.dialog_text = "Discard the unsaved SCURK changes?"
		discard_dialog.popup_centered()
		return
	hide()
	close_requested.emit()


func request_open() -> void:
	if dirty:
		pending_discard_action = "open"
		discard_dialog.dialog_text = "Discard the unsaved SCURK changes and open another tile set?"
		discard_dialog.popup_centered()
		return
	_popup_open_dialog()


func request_save() -> void:
	if source_path.is_empty() or path_is_within(source_path, reference_directory):
		request_save_as()
		return
	var result := save_path(source_path)
	if not result.ok:
		_show_error(result.error)


func request_save_as() -> void:
	var output_directory := ProjectSettings.globalize_path("user://tile_sets")
	DirAccess.make_dir_recursive_absolute(output_directory)
	save_dialog.current_dir = output_directory
	var proposed := source_path.get_file()
	if proposed.is_empty() or path_is_within(source_path, reference_directory):
		proposed = "CUSTOM.MIF"
	save_dialog.current_file = proposed
	save_dialog.popup_centered_ratio(0.75)


func request_import_bmp() -> void:
	if tile_set == null or current_large_id < 0:
		return
	var start_directory := source_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(start_directory):
		start_directory = reference_directory.path_join("SCURKART")
	if DirAccess.dir_exists_absolute(start_directory):
		import_bmp_dialog.current_dir = start_directory
	import_bmp_dialog.popup_centered_ratio(0.75)


func request_export_bmp() -> void:
	if pixel_canvas == null or pixel_canvas.sprite_width <= 0:
		return
	var output_directory := ProjectSettings.globalize_path("user://scurk_exports")
	DirAccess.make_dir_recursive_absolute(output_directory)
	export_bmp_dialog.current_dir = output_directory
	var view_name: String = ["LARGE", "MEDIUM", "SMALL"][current_view]
	export_bmp_dialog.current_file = "OBJECT_%03d_%s.BMP" % [
		object_tile_id(current_large_id), view_name,
	]
	export_bmp_dialog.popup_centered_ratio(0.75)


func import_bmp_path(path: String) -> Dictionary:
	if tile_set == null or current_large_id < 0:
		return {"ok": false, "error": "No SCURK object is selected."}
	var imported := IndexedBitmap.load_path(path, palette)
	if not imported.ok:
		return imported
	if imported.width > 128 or imported.height > 256:
		return {
			"ok": false,
			"error": "SCURK graphics cannot be larger than 128 by 256 pixels.",
		}
	return _replace_active_view(
		imported.width,
		imported.height,
		imported.pixels,
		"Imported %s" % path.get_file(),
		imported.remapped_color_count
	)


func export_bmp_path(path: String) -> Dictionary:
	if pixel_canvas == null or pixel_canvas.sprite_width <= 0:
		return {"ok": false, "error": "No SCURK sprite is available to export."}
	var output_path := ProjectSettings.globalize_path(path).simplify_path()
	if output_path.get_extension().to_lower() != "bmp":
		output_path += ".BMP"
	if path_is_within(output_path, reference_directory):
		return {
			"ok": false,
			"error": "The original game data folder is read-only. Use another folder.",
		}
	var directory_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if directory_error != OK:
		return {
			"ok": false,
			"error": "Cannot create the output directory: %s" % error_string(directory_error),
		}
	var active_shape := _active_output_shape()
	if not active_shape.ok:
		return active_shape
	var result := IndexedBitmap.save_path(
		output_path,
		active_shape.width,
		active_shape.height,
		active_shape.pixels,
		palette
	)
	if not result.ok:
		return result
	_set_status("Exported sprite %d to %s." % [
		view_sprite_id(current_large_id, current_view), output_path.get_file(),
	])
	return {"ok": true, "error": "", "path": output_path}


func copy_object_to_system_clipboard() -> void:
	if pixel_canvas == null or pixel_canvas.sprite_width <= 0:
		return
	var active_shape := _active_output_shape()
	if not active_shape.ok:
		_show_error(active_shape.error)
		return
	var result := SystemImageClipboard.copy_indexed(
		active_shape.width,
		active_shape.height,
		active_shape.pixels,
		palette
	)
	if not result.ok:
		_show_error(result.error)
		return
	_set_status(
		"Copied sprite %d to the system clipboard."
		% view_sprite_id(current_large_id, current_view)
	)


func paste_image_from_system_clipboard() -> void:
	if tile_set == null or current_large_id < 0:
		return
	var imported := SystemImageClipboard.paste_indexed(palette)
	if not imported.ok:
		_show_error(imported.error)
		return
	if imported.width > 128 or imported.height > 256:
		_show_error("SCURK graphics cannot be larger than 128 by 256 pixels.")
		return
	var result := _replace_active_view(
		imported.width,
		imported.height,
		imported.pixels,
		"Pasted the system clipboard image",
		imported.remapped_color_count
	)
	if not result.ok:
		_show_error(result.error)


func request_pick_copy() -> void:
	if tile_set == null or not tile_set.is_valid():
		_show_error("No valid SCURK working object set is loaded.")
		return
	pick_copy_control.open_with_working(tile_set, source_path)


func _copy_pick_objects(
	source: ScurkMif, large_ids: PackedInt32Array, description: String
) -> void:
	if tile_set == null:
		return
	var encoded := tile_set.to_bytes()
	if not encoded.ok:
		pick_copy_control.copy_completed(encoded)
		return
	edit_history.capture_blank_state()
	var result := PickCopy.copy_objects(
		tile_set,
		source,
		large_ids,
		base_large_sprites,
		base_small_medium_sprites
	)
	if not result.ok:
		pick_copy_control.copy_completed(result)
		_show_error(result.error)
		return
	_record_edit(encoded.bytes)
	_refresh_object_list()
	_refresh_sprite()
	pick_copy_control.copy_completed(result)
	_set_status(
		"%s copied %d objects and %d sprite views."
		% [description, result.object_count, result.shape_count]
	)


func _change_pick_working() -> void:
	request_open()


func _replace_active_view(
	width: int,
	height: int,
	pixels: PackedInt32Array,
	description: String,
	remapped_color_count: int
) -> Dictionary:
	_capture_edit_start()
	var sprite_id := view_sprite_id(current_large_id, current_view)
	var output_width := width
	var output_height := height
	var output_pixels := pixels
	if active_workspace:
		var workspace := DrawingWorkspace.from_shape(
			width, height, pixels, current_view, active_base_width
		)
		var active_shape := DrawingWorkspace.shape_from_workspace(
			workspace, active_base_width, current_view
		)
		if not active_shape.ok:
			edit_history.cancel_pending_edit()
			return active_shape
		output_width = active_shape.width
		output_height = active_shape.height
		output_pixels = active_shape.pixels
	var changed := tile_set.set_shape_indices(
		sprite_id, output_width, output_height, output_pixels
	)
	if not changed.ok:
		edit_history.cancel_pending_edit()
		return changed
	edit_history.mark_shape_blank_state(sprite_id, output_pixels)
	_record_edit(edit_history.pending_edit_before)
	_refresh_sprite()
	var remap_note := (
		" Remapped %d colors." % remapped_color_count
		if remapped_color_count > 0
		else ""
	)
	_set_status("%s into sprite %d.%s" % [description, sprite_id, remap_note])
	return {"ok": true, "error": ""}


func undo() -> void:
	if not edit_history.can_undo():
		return
	var result := edit_history.undo()
	if result.ok:
		tile_set = result.document
	else:
		_show_error(result.error)
	_update_after_history()


func redo() -> void:
	if not edit_history.can_redo():
		return
	var result := edit_history.redo()
	if result.ok:
		tile_set = result.document
	else:
		_show_error(result.error)
	_update_after_history()


func revert_object() -> void:
	var result := edit_history.revert_object(tile_set, current_large_id)
	if result.get("no_action", false):
		return
	if not result.ok:
		_show_error(result.error)
		return
	tile_set = result.document
	_update_after_history()
	_set_status("Reverted the current object to its state when selected.")


func revert_name() -> void:
	if tile_set == null or current_large_id < 0:
		return
	var tile_id := object_tile_id(current_large_id)
	if not tile_set.names.has(tile_id):
		return
	_capture_edit_start()
	var result := tile_set.remove_name(tile_id)
	if not result.ok:
		_show_error(result.error)
		return
	_record_edit(edit_history.pending_edit_before)
	_refresh_object_list()
	_refresh_sprite()
	_set_status("Restored the original query name for object %d." % tile_id)


func clear_object() -> void:
	if tile_set == null or current_large_id < 0:
		return
	_capture_edit_start()
	var changed_views := 0
	for view in range(3) if active_workspace else [current_view]:
		if not _view_is_available(view):
			continue
		var width := (
			int(active_base_width / DrawingWorkspace.view_divisor(view))
			if active_workspace
			else pixel_canvas.sprite_width
		)
		var blank := PackedInt32Array()
		blank.resize(maxi(1, width))
		blank.fill(-1)
		var result := tile_set.set_shape_indices(
			view_sprite_id(current_large_id, view), maxi(1, width), 1, blank
		)
		if not result.ok:
			edit_history.cancel_pending_edit()
			_show_error(result.error)
			_refresh_sprite()
			return
		edit_history.blank_shape_ids[view_sprite_id(current_large_id, view)] = true
		changed_views += 1
	_record_edit(edit_history.pending_edit_before)
	_refresh_sprite()
	_set_status("Cleared %d object view%s to clean ground and sky." % [
		changed_views, "" if changed_views == 1 else "s",
	])


func handle_shortcut(event: InputEventKey) -> bool:
	if not visible or not event.pressed or event.echo:
		return false
	var command := event.meta_pressed or event.ctrl_pressed
	if command and event.keycode == KEY_S:
		if event.shift_pressed:
			request_save_as()
		else:
			request_save()
		return true
	if command and event.keycode == KEY_O:
		request_open()
		return true
	if command and event.keycode == KEY_Z:
		if event.shift_pressed:
			redo()
		else:
			undo()
		return true
	if command and event.keycode == KEY_Y:
		redo()
		return true
	if event.keycode == KEY_ESCAPE:
		if pick_copy_control != null and pick_copy_control.visible:
			pick_copy_control.request_close()
			return true
		request_close()
		return true
	return false


static func editable_large_sprite_ids(
	value: ScurkMif, base_large: Sc2SpriteArchive = null
) -> PackedInt32Array:
	return EditorRules.editable_large_sprite_ids(value, base_large)


static func view_sprite_id(large_sprite_id: int, view: int) -> int:
	return EditorRules.view_sprite_id(large_sprite_id, view)


static func object_tile_id(large_sprite_id: int) -> int:
	return EditorRules.object_tile_id(large_sprite_id)


static func path_is_within(path: String, directory: String) -> bool:
	return EditorRules.path_is_within(path, directory)


func _build_interface() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 10
	panel.offset_top = 10
	panel.offset_right = -10
	panel.offset_bottom = -10
	add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	panel.add_child(page)

	var toolbar := ToolbarView.new()
	toolbar.build()
	page.add_child(toolbar)
	toolbar.open_requested.connect(request_open)
	toolbar.save_requested.connect(request_save)
	toolbar.save_as_requested.connect(request_save_as)
	toolbar.import_bmp_requested.connect(request_import_bmp)
	toolbar.export_bmp_requested.connect(request_export_bmp)
	toolbar.pick_copy_requested.connect(request_pick_copy)
	toolbar.undo_requested.connect(undo)
	toolbar.redo_requested.connect(redo)
	toolbar.revert_requested.connect(revert_object)
	toolbar.clear_requested.connect(clear_object)
	toolbar.apply_requested.connect(_apply_tile_set)
	toolbar.place_print_requested.connect(request_place_print)
	toolbar.close_requested.connect(request_close)
	save_button = toolbar.save_button
	undo_button = toolbar.undo_button
	redo_button = toolbar.redo_button
	revert_button = toolbar.revert_button
	clear_object_button = toolbar.clear_button

	var header := HBoxContainer.new()
	page.add_child(header)
	title_label = Label.new()
	title_label.text = "Paint the Town"
	title_label.add_theme_color_override("font_color", Color("000080"))
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	source_label = Label.new()
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	source_label.custom_minimum_size = Vector2(180, 0)
	source_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	source_label.add_theme_color_override("font_color", Color("404040"))
	header.add_child(source_label)

	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 250
	page.add_child(body)
	object_panel = ObjectPanelView.new()
	object_panel.build()
	object_panel.search_changed.connect(_on_search_changed)
	object_panel.object_selected.connect(_on_object_selected)
	object_panel.name_submitted.connect(_commit_name)
	object_panel.set_name_requested.connect(_commit_name)
	object_panel.revert_name_requested.connect(revert_name)
	body.add_child(object_panel)
	object_search = object_panel.object_search
	object_list = object_panel.object_list
	name_edit = object_panel.name_edit
	name_button = object_panel.name_button
	revert_name_button = object_panel.revert_name_button

	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.split_offset = 680
	body.add_child(right_split)
	var editor_column := VBoxContainer.new()
	editor_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_column.add_theme_constant_override("separation", 5)
	right_split.add_child(editor_column)
	drawing_controls = DrawingControlsView.new()
	drawing_controls.build()
	drawing_controls.view_selected.connect(_select_view)
	drawing_controls.zoom_out_requested.connect(_zoom_out)
	drawing_controls.zoom_in_requested.connect(_zoom_in)
	drawing_controls.tool_selected.connect(_select_tool)
	drawing_controls.rotate_clipboard_requested.connect(_rotate_clipboard)
	drawing_controls.flip_clipboard_horizontal_requested.connect(
		_flip_clipboard_horizontal
	)
	drawing_controls.flip_clipboard_vertical_requested.connect(
		_flip_clipboard_vertical
	)
	drawing_controls.copy_object_requested.connect(copy_object_to_system_clipboard)
	drawing_controls.paste_image_requested.connect(paste_image_from_system_clipboard)
	drawing_controls.brush_size_selected.connect(_select_brush_size)
	drawing_controls.round_brush_changed.connect(_set_round_brush)
	drawing_controls.filled_shapes_changed.connect(_set_filled_shapes)
	drawing_controls.grid_visibility_changed.connect(_set_grid_visible)
	drawing_controls.grid_snap_changed.connect(_set_snap_to_grid)
	drawing_controls.grid_width_changed.connect(_set_grid_width)
	drawing_controls.grid_height_changed.connect(_set_grid_height)
	drawing_controls.clip_region_changed.connect(_set_clip_region_visible)
	drawing_controls.cycle_colors_changed.connect(_set_cycle_colors)
	drawing_controls.increment_cycle_requested.connect(_increment_cycle)
	editor_column.add_child(drawing_controls)
	view_buttons = drawing_controls.view_buttons
	zoom_label = drawing_controls.zoom_label
	tool_buttons = drawing_controls.tool_buttons
	paste_tool_button = drawing_controls.paste_tool_button
	clipboard_action_buttons = drawing_controls.clipboard_action_buttons
	copy_object_button = drawing_controls.copy_object_button
	paste_image_button = drawing_controls.paste_image_button
	brush_size_selector = drawing_controls.brush_size_selector
	round_brush_check = drawing_controls.round_brush_check
	filled_shapes_check = drawing_controls.filled_shapes_check
	grid_check = drawing_controls.grid_check
	snap_to_grid_check = drawing_controls.snap_to_grid_check
	grid_width_selector = drawing_controls.grid_width_selector
	grid_height_selector = drawing_controls.grid_height_selector
	clip_region_check = drawing_controls.clip_region_check
	cycle_colors_check = drawing_controls.cycle_colors_check
	increment_cycle_button = drawing_controls.increment_cycle_button

	canvas_panel = CanvasPanelView.new()
	canvas_panel.build()
	editor_column.add_child(canvas_panel)
	pixel_canvas = canvas_panel.pixel_canvas
	view_previews = canvas_panel.view_previews
	view_preview_panels = canvas_panel.view_preview_panels
	sprite_status_label = canvas_panel.sprite_status_label
	pixel_canvas.edit_started.connect(_capture_edit_start)
	pixel_canvas.pixels_committed.connect(_commit_pixels)
	pixel_canvas.palette_index_picked.connect(_select_palette_index)
	pixel_canvas.pointer_changed.connect(_update_pointer_status)
	pixel_canvas.clipboard_changed.connect(_on_clipboard_changed)
	pixel_canvas.clipboard_copy_rejected.connect(_on_clipboard_copy_rejected)

	palette_panel = PalettePanelView.new()
	palette_panel.build()
	palette_panel.set_patterns(pixel_canvas.texture_patterns)
	palette_panel.palette_index_selected.connect(_select_palette_index)
	palette_panel.texture_selected.connect(_select_texture)
	palette_panel.eraser_requested.connect(
		_select_tool.bind(ScurkPixelCanvas.TOOL_ERASER)
	)
	right_split.add_child(palette_panel)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 26)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	page.add_child(status_label)

	dialog_registry = DialogsView.new()
	dialog_registry._create_dialogs()
	add_child(dialog_registry)
	open_dialog = dialog_registry.open_dialog
	open_dialog.file_selected.connect(_load_selected_path)
	save_dialog = dialog_registry.save_dialog
	save_dialog.file_selected.connect(_save_selected_path)
	import_bmp_dialog = dialog_registry.import_bmp_dialog
	import_bmp_dialog.file_selected.connect(_import_selected_bmp)
	export_bmp_dialog = dialog_registry.export_bmp_dialog
	export_bmp_dialog.file_selected.connect(_export_selected_bmp)
	discard_dialog = dialog_registry.discard_dialog
	discard_dialog.confirmed.connect(_confirm_discard)
	pick_copy_control = dialog_registry.pick_copy_control
	pick_copy_control.close_requested.connect(_pick_copy_closed)
	pick_copy_control.change_working_requested.connect(_change_pick_working)
	pick_copy_control.copy_requested.connect(_copy_pick_objects)
	_select_palette_index(0, false)
	_select_palette_index(255, true)
	_update_history_buttons()


func _pick_copy_closed() -> void:
	if is_inside_tree() and object_list != null:
		object_list.grab_focus()


func _refresh_object_list() -> void:
	if object_list == null:
		return
	var selected_id := current_large_id
	var filter := object_search.text.strip_edges().to_lower() if object_search != null else ""
	object_list.clear()
	if tile_set == null:
		return
	for large_id in editable_large_sprite_ids(tile_set, base_large_sprites):
		var tile_id := object_tile_id(large_id)
		var tile_name := String(tile_set.names.get(tile_id, ""))
		var description := tile_name if not tile_name.is_empty() else sprite_role(tile_id)
		var label := "%03d  %s" % [tile_id, description]
		if not filter.is_empty() and not label.to_lower().contains(filter):
			continue
		var list_index := object_list.add_item(label)
		object_list.set_item_metadata(list_index, large_id)
		object_list.set_item_tooltip(
			list_index,
			"Sprite family %d: Small %d, Medium %d, Large %d"
			% [tile_id, tile_id, tile_id + 500, tile_id + 1000]
		)
		if large_id == selected_id:
			object_list.select(list_index)
	if object_list.get_selected_items().is_empty() and object_list.item_count > 0:
		object_list.select(0)
		var replacement_id := int(object_list.get_item_metadata(0))
		if replacement_id != current_large_id:
			current_large_id = replacement_id
			_capture_object_start()


func _on_object_selected(index: int) -> void:
	var selected_id := int(object_list.get_item_metadata(index))
	if selected_id != current_large_id:
		current_large_id = selected_id
		_capture_object_start()
	_refresh_sprite()


func _on_search_changed(_value: String) -> void:
	_refresh_object_list()
	_refresh_sprite()


func _select_view(view: int) -> void:
	if not _view_is_available(view):
		return
	current_view = view
	for index in view_buttons.size():
		view_buttons[index].button_pressed = index == view
	_refresh_sprite()


func _select_tool(tool_value: int) -> void:
	current_tool = tool_value
	if pixel_canvas != null:
		pixel_canvas.set_tool(tool_value)
	for index in tool_buttons.size():
		tool_buttons[index].button_pressed = index == tool_value


func _select_palette_index(index: int, background := false) -> void:
	if background:
		background_palette_index = clampi(index, 0, 255)
	else:
		foreground_palette_index = clampi(index, 0, 255)
	if pixel_canvas != null:
		pixel_canvas.set_paint_indices(
			foreground_palette_index, background_palette_index
		)
	if palette_panel != null:
		palette_panel.set_colors(
			foreground_palette_index, background_palette_index
		)


func _select_brush_size(index: int) -> void:
	if brush_size_selector == null or pixel_canvas == null:
		return
	pixel_canvas.set_brush(
		brush_size_selector.get_item_id(index), round_brush_check.button_pressed
	)


func _set_round_brush(enabled: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_brush(pixel_canvas.brush_size, enabled)


func _set_filled_shapes(enabled: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.filled_shapes = enabled


func _set_grid_visible(enabled: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.show_grid = enabled
		pixel_canvas.queue_redraw()


func _set_snap_to_grid(_enabled: bool) -> void:
	_apply_grid_settings()


func _set_grid_width(_value: float) -> void:
	_apply_grid_settings()


func _set_grid_height(_value: float) -> void:
	_apply_grid_settings()


func _apply_grid_settings() -> void:
	if (
		pixel_canvas == null
		or snap_to_grid_check == null
		or grid_width_selector == null
		or grid_height_selector == null
	):
		return
	pixel_canvas.set_grid_settings(
		roundi(grid_width_selector.value),
		roundi(grid_height_selector.value),
		snap_to_grid_check.button_pressed
	)


func _set_clip_region_visible(enabled: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_clip_region_visible(enabled)


func _set_cycle_colors(enabled: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_palette_cycle_enabled(enabled)
	for preview in view_previews:
		preview.set_palette_cycle_enabled(enabled)
	if increment_cycle_button != null:
		increment_cycle_button.disabled = enabled


func _increment_cycle() -> void:
	if pixel_canvas != null:
		pixel_canvas.increment_palette_cycle()
	for preview in view_previews:
		preview.increment_palette_cycle()
	_set_status("Advanced the Paint the Town color cycle by one step.")


func _select_texture(index: int) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_texture(index)
	if palette_panel != null:
		palette_panel.set_selected_texture(index)


func _rotate_clipboard() -> void:
	if pixel_canvas != null:
		pixel_canvas.rotate_clipboard_counterclockwise()


func _flip_clipboard_horizontal() -> void:
	if pixel_canvas != null:
		pixel_canvas.flip_clipboard_horizontal()


func _flip_clipboard_vertical() -> void:
	if pixel_canvas != null:
		pixel_canvas.flip_clipboard_vertical()


func _on_clipboard_changed(width: int, height: int) -> void:
	var available := width > 0 and height > 0
	if paste_tool_button != null:
		paste_tool_button.disabled = not available
	for button in clipboard_action_buttons:
		button.disabled = not available
	if available:
		_set_status("SCURK clipboard: %d x %d pixels." % [width, height])


func _on_clipboard_copy_rejected(minimum_span: int) -> void:
	_set_status(
		"Copy requires at least a %d-pixel endpoint span on each axis."
		% minimum_span
	)


func _refresh_sprite() -> void:
	if pixel_canvas == null:
		return
	if tile_set == null or current_large_id < 0:
		pixel_canvas.clear_sprite()
		_refresh_view_previews()
		name_edit.text = ""
		name_edit.editable = false
		name_button.disabled = true
		revert_name_button.disabled = true
		return
	_update_view_buttons()
	var sprite_id := view_sprite_id(current_large_id, current_view)
	var entry := tile_set.overrides.find_sprite(sprite_id)
	var source := "MIF override"
	if entry == null and edit_history.blank_shape_ids.has(sprite_id):
		entry = tile_set.archive.find_sprite(sprite_id)
		source = "cleared object"
	if entry == null:
		var base_archive := base_large_sprites if current_view == VIEW_LARGE else base_small_medium_sprites
		entry = base_archive.find_sprite(sprite_id) if base_archive != null else null
		source = "original fallback"
	if entry == null:
		entry = tile_set.archive.find_sprite(sprite_id)
		source = "blank MIF shape"
	if entry == null:
		pixel_canvas.clear_sprite()
		_refresh_view_previews()
		sprite_status_label.text = "Sprite %d is missing." % sprite_id
		return
	var decoded := entry.decode_indices()
	if not decoded.ok:
		pixel_canvas.clear_sprite()
		_refresh_view_previews()
		sprite_status_label.text = decoded.error
		return
	var large_entry := PickCopy.resolved_entry(
		tile_set, current_large_id, base_large_sprites, base_small_medium_sprites
	)
	active_base_width = large_entry.width if large_entry != null else 0
	active_workspace = DrawingWorkspace.is_standard_base_width(active_base_width)
	pixel_canvas.clear_edit_region()
	if active_workspace:
		var workspace := DrawingWorkspace.from_shape(
			entry.width, entry.height, decoded.pixels, current_view, active_base_width
		)
		pixel_canvas.set_sprite_data(
			DrawingWorkspace.WIDTH, DrawingWorkspace.HEIGHT, workspace, palette
		)
		pixel_canvas.set_edit_region(
			DrawingWorkspace.clip_mask(active_base_width),
			DrawingWorkspace.base_size(active_base_width)
		)
		pixel_canvas.set_clip_region_visible(clip_region_check.button_pressed)
	else:
		pixel_canvas.set_sprite_data(entry.width, entry.height, decoded.pixels, palette)
	pixel_canvas.set_tool(current_tool)
	pixel_canvas.set_paint_indices(
		foreground_palette_index, background_palette_index
	)
	pixel_canvas.set_brush(
		brush_size_selector.get_item_id(brush_size_selector.selected),
		round_brush_check.button_pressed
	)
	pixel_canvas.set_texture(palette_panel.selected_texture_index())
	pixel_canvas.filled_shapes = filled_shapes_check.button_pressed
	pixel_canvas.show_grid = grid_check.button_pressed
	_apply_grid_settings()
	_refresh_view_previews()
	var tile_id := object_tile_id(current_large_id)
	var can_name := tile_id >= 0
	name_edit.editable = can_name
	name_button.disabled = not can_name
	name_edit.text = String(tile_set.names.get(tile_id, ""))
	revert_name_button.disabled = not can_name or not tile_set.names.has(tile_id)
	sprite_status_label.text = (
		"Sprite %d: %d x %d output, %d x %d tile base, %s."
		% [
			sprite_id, entry.width, entry.height,
			DrawingWorkspace.base_size(active_base_width),
			DrawingWorkspace.base_size(active_base_width), source,
		]
		if active_workspace
		else "Sprite %d: %d x %d pixels, %s." % [
			sprite_id, entry.width, entry.height, source,
		]
	)


func _update_view_buttons() -> void:
	if current_large_id < 0:
		return
	if not _view_is_available(current_view):
		for candidate in [VIEW_LARGE, VIEW_MEDIUM, VIEW_SMALL]:
			if _view_is_available(candidate):
				current_view = candidate
				break
	for index in view_buttons.size():
		view_buttons[index].disabled = not _view_is_available(index)
		view_buttons[index].button_pressed = index == current_view


func _view_is_available(view: int) -> bool:
	if tile_set == null or current_large_id < 0:
		return false
	var sprite_id := view_sprite_id(current_large_id, view)
	return PickCopy.resolved_entry(
		tile_set, sprite_id, base_large_sprites, base_small_medium_sprites
	) != null


static func sprite_role(tile_id: int) -> String:
	return EditorRules.sprite_role(tile_id)


func _capture_edit_start() -> void:
	edit_history.capture_edit(tile_set)


func _capture_object_start() -> void:
	edit_history.capture_object(tile_set, current_large_id)
	_update_history_buttons()


func _commit_pixels(value_pixels: PackedInt32Array) -> void:
	if tile_set == null or current_large_id < 0:
		return
	var sprite_id := view_sprite_id(current_large_id, current_view)
	var output_width := pixel_canvas.sprite_width
	var output_height := pixel_canvas.sprite_height
	var output_pixels := value_pixels
	if active_workspace:
		var active_shape := DrawingWorkspace.shape_from_workspace(
			value_pixels, active_base_width, current_view
		)
		if not active_shape.ok:
			_show_error(active_shape.error)
			if not edit_history.pending_edit_before.is_empty():
				_replace_document_bytes(edit_history.pending_edit_before)
			_refresh_sprite()
			return
		output_width = active_shape.width
		output_height = active_shape.height
		output_pixels = active_shape.pixels
	var result := tile_set.set_shape_indices(
		sprite_id, output_width, output_height, output_pixels
	)
	if not result.ok:
		_show_error(result.error)
		if not edit_history.pending_edit_before.is_empty():
			_replace_document_bytes(edit_history.pending_edit_before)
		_refresh_sprite()
		return
	edit_history.mark_shape_blank_state(sprite_id, output_pixels)
	_record_edit(edit_history.pending_edit_before)
	_refresh_sprite()


func _refresh_view_previews() -> void:
	if view_previews.size() != 3 or view_preview_panels.size() != 3:
		return
	if is_inside_tree() and not is_visible_in_tree():
		return
	if tile_set == null or current_large_id < 0:
		for view in 3:
			view_previews[view].clear_preview(view)
			view_preview_panels[view].visible = false
			view_preview_signatures[view] = ""
		return
	for view in 3:
		var entry: Variant = _resolved_view_entry(view)
		if entry == null:
			view_previews[view].clear_preview(view)
			view_preview_panels[view].visible = false
			view_preview_signatures[view] = ""
			continue
		var signature := "%d:%d:%d:%d" % [
			active_base_width, entry.width, entry.height, entry.pixel_hash(),
		]
		if view_preview_signatures[view] == signature:
			view_preview_panels[view].visible = true
			continue
		var decoded: Dictionary = entry.decode_indices()
		if not decoded.ok:
			view_previews[view].clear_preview(view)
			view_preview_panels[view].visible = false
			view_preview_signatures[view] = ""
			continue
		view_previews[view].set_preview(
			view,
			entry.width,
			entry.height,
			decoded.pixels,
			active_base_width,
			palette,
			pixel_canvas.clear_background_pixels
		)
		view_previews[view].set_palette_cycle_enabled(
			cycle_colors_check.button_pressed
		)
		view_preview_panels[view].visible = true
		view_preview_signatures[view] = signature


func _resolved_view_entry(view: int):
	if tile_set == null or current_large_id < 0:
		return null
	var sprite_id := view_sprite_id(current_large_id, view)
	var entry: Variant = tile_set.overrides.find_sprite(sprite_id)
	if entry == null and edit_history.blank_shape_ids.has(sprite_id):
		entry = tile_set.archive.find_sprite(sprite_id)
	if entry == null:
		var base_archive := (
			base_large_sprites if view == VIEW_LARGE else base_small_medium_sprites
		)
		entry = base_archive.find_sprite(sprite_id) if base_archive != null else null
	if entry == null:
		entry = tile_set.archive.find_sprite(sprite_id)
	return entry


func _active_output_shape() -> Dictionary:
	if pixel_canvas == null or pixel_canvas.sprite_width <= 0:
		return {"ok": false, "error": "No SCURK sprite is available."}
	if active_workspace:
		return DrawingWorkspace.shape_from_workspace(
			pixel_canvas.pixels, active_base_width, current_view
		)
	return {
		"ok": true,
		"width": pixel_canvas.sprite_width,
		"height": pixel_canvas.sprite_height,
		"pixels": pixel_canvas.pixels.duplicate(),
		"error": "",
	}


func _commit_name() -> void:
	if tile_set == null or current_large_id < 0:
		return
	var tile_id := object_tile_id(current_large_id)
	var value := name_edit.text.strip_edges()
	if value == String(tile_set.names.get(tile_id, "")):
		return
	_capture_edit_start()
	var result := tile_set.set_name(tile_id, value)
	if not result.ok:
		_show_error(result.error)
		return
	_record_edit(edit_history.pending_edit_before)
	_refresh_object_list()
	_refresh_sprite()


func _record_edit(before: PackedByteArray) -> void:
	if not edit_history.record(before, tile_set):
		return
	_update_history_buttons()
	_update_title()


func _replace_document_bytes(bytes: PackedByteArray) -> bool:
	var replacement := Mif.new()
	if not replacement.parse(bytes):
		_show_error(replacement.parse_error)
		return false
	tile_set = replacement
	return true


func _update_after_history() -> void:
	_refresh_object_list()
	_refresh_sprite()
	_update_dirty()
	_update_history_buttons()
	_update_title()
	if pick_copy_control != null and pick_copy_control.visible:
		pick_copy_control.open_with_working(tile_set, source_path)


func _update_dirty() -> void:
	edit_history.update_dirty(tile_set)


func _update_history_buttons() -> void:
	if undo_button != null:
		undo_button.disabled = not edit_history.can_undo()
	if redo_button != null:
		redo_button.disabled = not edit_history.can_redo()
	if revert_button != null:
		revert_button.disabled = not edit_history.can_revert_object(
			tile_set, current_large_id
		)
	if save_button != null:
		save_button.disabled = tile_set == null


func _update_title() -> void:
	if title_label == null:
		return
	var filename := source_path.get_file() if not source_path.is_empty() else "Untitled.MIF"
	title_label.text = "SCURK Tile Editor — %s%s" % [filename, " *" if dirty else ""]
	if source_label != null:
		source_label.text = "Reference source: read-only" if path_is_within(source_path, reference_directory) else source_path


func _zoom_in() -> void:
	if pixel_canvas == null:
		return
	pixel_canvas.set_zoom(pixel_canvas.zoom + 1)
	zoom_label.text = "%dx" % pixel_canvas.zoom


func _zoom_out() -> void:
	if pixel_canvas == null:
		return
	pixel_canvas.set_zoom(pixel_canvas.zoom - 1)
	zoom_label.text = "%dx" % pixel_canvas.zoom


func _update_pointer_status(point: Vector2i, index: int) -> void:
	if palette_panel != null:
		palette_panel.set_pointer(point, index)


func _apply_tile_set() -> void:
	if tile_set == null or not tile_set.is_valid():
		return
	var display_name := source_path.get_file()
	if display_name.is_empty():
		display_name = "Unsaved tile set"
	tile_set_applied.emit(tile_set, display_name, source_path)
	_set_status("Applied %s to the city artwork." % display_name)


func request_place_print() -> void:
	if tile_set == null or not tile_set.is_valid():
		return
	_apply_tile_set()
	hide()
	place_print_requested.emit()


func _popup_open_dialog() -> void:
	var tile_set_directory := reference_directory.path_join("SCURKART")
	if DirAccess.dir_exists_absolute(tile_set_directory):
		open_dialog.current_dir = tile_set_directory
	open_dialog.popup_centered_ratio(0.75)


func _load_selected_path(path: String) -> void:
	var result := load_path(path)
	if not result.ok:
		_show_error(result.error)


func _save_selected_path(path: String) -> void:
	var result := save_path(path)
	if not result.ok:
		_show_error(result.error)


func _import_selected_bmp(path: String) -> void:
	var result := import_bmp_path(path)
	if not result.ok:
		_show_error(result.error)


func _export_selected_bmp(path: String) -> void:
	var result := export_bmp_path(path)
	if not result.ok:
		_show_error(result.error)


func _confirm_discard() -> void:
	var action := pending_discard_action
	pending_discard_action = ""
	if action == "open":
		_popup_open_dialog()
	elif action == "close":
		hide()
		close_requested.emit()


func _set_status(message: String) -> void:
	if status_label == null:
		return
	status_label.remove_theme_color_override("font_color")
	status_label.text = message


func _show_error(message: String) -> void:
	if status_label != null:
		status_label.add_theme_color_override("font_color", Color("b00000"))
		status_label.text = message
	if error_dialog != null:
		error_dialog.dialog_text = message
		error_dialog.popup_centered()
