class_name ScurkEditorControl
extends ColorRect

signal close_requested
signal tile_set_applied(tile_set: ScurkMif, display_name: String, source_path: String)

const Mif = preload("res://src/assets/scurk_mif.gd")
const PixelCanvas = preload("res://src/view/scurk_pixel_canvas.gd")
const PaletteControl = preload("res://src/view/scurk_palette_control.gd")

const VIEW_LARGE := 0
const VIEW_MEDIUM := 1
const VIEW_SMALL := 2
const HISTORY_LIMIT := 24

var palette: Sc2Palette
var base_large_sprites: Sc2SpriteArchive
var base_small_medium_sprites: Sc2SpriteArchive
var reference_directory := ""
var tile_set: ScurkMif
var source_path := ""
var saved_bytes := PackedByteArray()
var current_large_id := -1
var current_view := VIEW_LARGE
var current_tool := ScurkPixelCanvas.TOOL_PENCIL
var foreground_palette_index := 0
var background_palette_index := 255
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var pending_edit_before := PackedByteArray()
var object_start_bytes := PackedByteArray()
var object_start_large_id := -1
var pending_discard_action := ""
var dirty := false

var title_label: Label
var source_label: Label
var object_search: LineEdit
var object_list: ItemList
var name_edit: LineEdit
var name_button: Button
var revert_name_button: Button
var view_buttons: Array[Button] = []
var tool_buttons: Array[Button] = []
var undo_button: Button
var redo_button: Button
var revert_button: Button
var save_button: Button
var pixel_canvas: ScurkPixelCanvas
var palette_control: ScurkPaletteControl
var foreground_color: ColorRect
var foreground_color_label: Label
var background_color: ColorRect
var background_color_label: Label
var brush_size_selector: OptionButton
var texture_selector: OptionButton
var filled_shapes_check: CheckBox
var round_brush_check: CheckBox
var grid_check: CheckBox
var zoom_label: Label
var sprite_status_label: Label
var pointer_status_label: Label
var status_label: Label
var open_dialog: FileDialog
var save_dialog: FileDialog
var discard_dialog: ConfirmationDialog
var error_dialog: AcceptDialog


func _ready() -> void:
	name = "SCURKEditor"
	color = Color(0.0, 0.0, 0.0, 0.38)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	hide()


func configure(
	value_palette: Sc2Palette,
	value_large_sprites: Sc2SpriteArchive,
	value_small_medium_sprites: Sc2SpriteArchive,
	value_reference_directory: String
) -> void:
	palette = value_palette
	base_large_sprites = value_large_sprites
	base_small_medium_sprites = value_small_medium_sprites
	reference_directory = value_reference_directory.simplify_path()
	if palette_control != null:
		palette_control.set_palette(palette)
		_select_palette_index(foreground_palette_index, false)
		_select_palette_index(background_palette_index, true)
	if tile_set != null:
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
	if object_list != null:
		object_list.grab_focus()
	return {"ok": true, "error": ""}


func load_path(path: String) -> Dictionary:
	var loaded := Mif.load_path(path)
	if not loaded.is_valid():
		return {"ok": false, "error": loaded.parse_error}
	tile_set = loaded
	source_path = ProjectSettings.globalize_path(path).simplify_path()
	var encoded := tile_set.to_bytes()
	if not encoded.ok:
		return {"ok": false, "error": encoded.error}
	saved_bytes = encoded.bytes.duplicate()
	undo_stack.clear()
	redo_stack.clear()
	pending_edit_before.clear()
	dirty = false
	var ids := editable_large_sprite_ids(tile_set)
	current_large_id = ids[0] if not ids.is_empty() else -1
	current_view = VIEW_LARGE
	_refresh_object_list()
	_capture_object_start()
	_refresh_sprite()
	_update_history_buttons()
	_update_title()
	_set_status(
		"Loaded %s: %d objects and %d names."
		% [source_path.get_file(), ids.size(), tile_set.names.size()]
	)
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
	saved_bytes = encoded.bytes.duplicate()
	_update_dirty()
	_update_title()
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


func undo() -> void:
	if undo_stack.is_empty():
		return
	var action: Dictionary = undo_stack.pop_back()
	if _replace_document_bytes(action.before):
		redo_stack.append(action)
	_update_after_history()


func redo() -> void:
	if redo_stack.is_empty():
		return
	var action: Dictionary = redo_stack.pop_back()
	if _replace_document_bytes(action.after):
		undo_stack.append(action)
	_update_after_history()


func revert_object() -> void:
	if (
		object_start_bytes.is_empty()
		or current_large_id < 0
		or object_start_large_id != current_large_id
	):
		return
	var encoded := tile_set.to_bytes() if tile_set != null else {}
	if not encoded.get("ok", false) or encoded.bytes == object_start_bytes:
		return
	var before: PackedByteArray = encoded.bytes.duplicate()
	if not _replace_document_bytes(object_start_bytes):
		return
	_record_edit(before)
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
	_record_edit(pending_edit_before)
	_refresh_object_list()
	_refresh_sprite()
	_set_status("Restored the original query name for object %d." % tile_id)


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
		request_close()
		return true
	return false


static func editable_large_sprite_ids(value: ScurkMif) -> PackedInt32Array:
	var ids := PackedInt32Array()
	if value == null or not value.is_valid():
		return ids
	var seen := {}
	for entry in value.shapes:
		if entry.sprite_id < 1000 or entry.sprite_id > 1499 or seen.has(entry.sprite_id):
			continue
		seen[entry.sprite_id] = true
		ids.append(entry.sprite_id)
	ids.sort()
	return ids


static func view_sprite_id(large_sprite_id: int, view: int) -> int:
	if large_sprite_id < 1000 or large_sprite_id > 1499:
		return -1
	match view:
		VIEW_LARGE: return large_sprite_id
		VIEW_MEDIUM: return large_sprite_id - 500
		VIEW_SMALL: return large_sprite_id - 1000
		_: return -1


static func object_tile_id(large_sprite_id: int) -> int:
	return large_sprite_id - 1000 if large_sprite_id in range(1000, 1500) else -1


static func path_is_within(path: String, directory: String) -> bool:
	if path.is_empty() or directory.is_empty():
		return false
	var target := ProjectSettings.globalize_path(path).simplify_path()
	var root := ProjectSettings.globalize_path(directory).simplify_path().trim_suffix("/")
	return target == root or target.begins_with(root + "/")


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

	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 38)
	toolbar.add_theme_constant_override("separation", 5)
	page.add_child(toolbar)
	toolbar.add_child(_toolbar_button("Open...", request_open, "Open a SCURK MIF tile set."))
	save_button = _toolbar_button("Save", request_save, "Save this tile set.")
	toolbar.add_child(save_button)
	toolbar.add_child(_toolbar_button("Save As...", request_save_as, "Save to a new MIF file."))
	toolbar.add_child(VSeparator.new())
	undo_button = _toolbar_button("Undo", undo, "Undo the last pixel or name edit.")
	toolbar.add_child(undo_button)
	redo_button = _toolbar_button("Redo", redo, "Redo the last undone edit.")
	toolbar.add_child(redo_button)
	revert_button = _toolbar_button(
		"Revert", revert_object,
		"Restore this object to its state when it entered the drawing area."
	)
	toolbar.add_child(revert_button)
	toolbar.add_child(VSeparator.new())
	toolbar.add_child(_toolbar_button("Apply to City", _apply_tile_set, "Use this tile set in the city view."))
	var toolbar_spacer := Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)
	toolbar.add_child(_toolbar_button("Close", request_close, "Close the SCURK editor."))

	var header := HBoxContainer.new()
	page.add_child(header)
	title_label = Label.new()
	title_label.text = "SCURK Tile Editor"
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
	body.split_offset = 230
	page.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	left.add_theme_constant_override("separation", 5)
	body.add_child(left)
	var objects_heading := Label.new()
	objects_heading.text = "Tile Objects"
	objects_heading.add_theme_color_override("font_color", Color("000080"))
	left.add_child(objects_heading)
	object_search = LineEdit.new()
	object_search.placeholder_text = "Filter by ID or name"
	object_search.text_changed.connect(_on_search_changed)
	left.add_child(object_search)
	object_list = ItemList.new()
	object_list.name = "TileObjectList"
	object_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	object_list.item_selected.connect(_on_object_selected)
	left.add_child(object_list)
	var name_heading := Label.new()
	name_heading.text = "Query Name"
	left.add_child(name_heading)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Optional tile name"
	name_edit.text_submitted.connect(_commit_name.unbind(1))
	left.add_child(name_edit)
	name_button = Button.new()
	name_button.text = "Set Name"
	name_button.pressed.connect(_commit_name)
	left.add_child(name_button)
	revert_name_button = Button.new()
	revert_name_button.text = "Revert Name"
	revert_name_button.tooltip_text = "Remove the custom name and restore the original query name."
	revert_name_button.pressed.connect(revert_name)
	left.add_child(revert_name_button)

	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.split_offset = 620
	body.add_child(right_split)
	var editor_column := VBoxContainer.new()
	editor_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_column.add_theme_constant_override("separation", 5)
	right_split.add_child(editor_column)
	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 4)
	editor_column.add_child(view_row)
	var view_group := ButtonGroup.new()
	for view_data in [["Large", VIEW_LARGE], ["Medium", VIEW_MEDIUM], ["Small", VIEW_SMALL]]:
		var button := Button.new()
		button.text = view_data[0]
		button.toggle_mode = true
		button.button_group = view_group
		button.pressed.connect(_select_view.bind(view_data[1]))
		view_row.add_child(button)
		view_buttons.append(button)
	view_buttons[0].button_pressed = true
	var view_spacer := Control.new()
	view_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_row.add_child(view_spacer)
	view_row.add_child(_toolbar_button("-", _zoom_out, "Reduce the pixel zoom."))
	zoom_label = Label.new()
	zoom_label.text = "4x"
	zoom_label.custom_minimum_size = Vector2(34, 0)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_row.add_child(zoom_label)
	view_row.add_child(_toolbar_button("+", _zoom_in, "Increase the pixel zoom."))
	var tool_row := HFlowContainer.new()
	tool_row.custom_minimum_size = Vector2(0, 62)
	tool_row.add_theme_constant_override("h_separation", 4)
	tool_row.add_theme_constant_override("v_separation", 4)
	editor_column.add_child(tool_row)
	var tool_group := ButtonGroup.new()
	for tool_data in [
		["Pencil", ScurkPixelCanvas.TOOL_PENCIL],
		["Eraser", ScurkPixelCanvas.TOOL_ERASER],
		["Line", ScurkPixelCanvas.TOOL_LINE],
		["Diamond", ScurkPixelCanvas.TOOL_DIAMOND],
		["Left Wall", ScurkPixelCanvas.TOOL_LEFT_WALL],
		["Right Wall", ScurkPixelCanvas.TOOL_RIGHT_WALL],
		["Ellipse", ScurkPixelCanvas.TOOL_ELLIPSE],
		["Box", ScurkPixelCanvas.TOOL_RECTANGLE],
		["Fill", ScurkPixelCanvas.TOOL_FILL],
		["Pick", ScurkPixelCanvas.TOOL_EYEDROPPER],
	]:
		var button := Button.new()
		button.text = tool_data[0]
		button.toggle_mode = true
		button.button_group = tool_group
		button.custom_minimum_size = Vector2(0, 28)
		button.pressed.connect(_select_tool.bind(tool_data[1]))
		tool_row.add_child(button)
		tool_buttons.append(button)
	tool_buttons[0].button_pressed = true
	var brush_row := HBoxContainer.new()
	brush_row.add_theme_constant_override("separation", 5)
	editor_column.add_child(brush_row)
	var brush_label := Label.new()
	brush_label.text = "Brush"
	brush_row.add_child(brush_label)
	brush_size_selector = OptionButton.new()
	for size_value in range(1, 7):
		brush_size_selector.add_item("%d px" % size_value, size_value)
	brush_size_selector.item_selected.connect(_select_brush_size)
	brush_row.add_child(brush_size_selector)
	round_brush_check = CheckBox.new()
	round_brush_check.text = "Round 5–6 px"
	round_brush_check.tooltip_text = "Soften the corners of the five- and six-pixel brushes."
	round_brush_check.toggled.connect(_set_round_brush)
	brush_row.add_child(round_brush_check)
	filled_shapes_check = CheckBox.new()
	filled_shapes_check.text = "Filled shapes"
	filled_shapes_check.toggled.connect(_set_filled_shapes)
	brush_row.add_child(filled_shapes_check)
	grid_check = CheckBox.new()
	grid_check.text = "Grid"
	grid_check.button_pressed = true
	grid_check.toggled.connect(_set_grid_visible)
	brush_row.add_child(grid_check)

	var scroll := ScrollContainer.new()
	scroll.name = "PixelScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	editor_column.add_child(scroll)
	var canvas_center := CenterContainer.new()
	canvas_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(canvas_center)
	pixel_canvas = PixelCanvas.new()
	pixel_canvas.name = "PixelCanvas"
	pixel_canvas.edit_started.connect(_capture_edit_start)
	pixel_canvas.pixels_committed.connect(_commit_pixels)
	pixel_canvas.palette_index_picked.connect(_select_palette_index)
	pixel_canvas.pointer_changed.connect(_update_pointer_status)
	canvas_center.add_child(pixel_canvas)
	sprite_status_label = Label.new()
	sprite_status_label.text = "No sprite is selected."
	sprite_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	editor_column.add_child(sprite_status_label)

	var palette_column := VBoxContainer.new()
	palette_column.custom_minimum_size = Vector2(300, 0)
	palette_column.add_theme_constant_override("separation", 6)
	right_split.add_child(palette_column)
	var palette_heading := Label.new()
	palette_heading.text = "Original 256-Color Palette"
	palette_heading.add_theme_color_override("font_color", Color("000080"))
	palette_column.add_child(palette_heading)
	palette_control = PaletteControl.new()
	palette_control.name = "Palette"
	palette_control.index_selected.connect(_select_palette_index)
	palette_column.add_child(palette_control)
	var foreground_row := HBoxContainer.new()
	foreground_row.add_theme_constant_override("separation", 8)
	palette_column.add_child(foreground_row)
	foreground_color = ColorRect.new()
	foreground_color.custom_minimum_size = Vector2(38, 26)
	foreground_row.add_child(foreground_color)
	foreground_color_label = Label.new()
	foreground_row.add_child(foreground_color_label)
	var background_row := HBoxContainer.new()
	background_row.add_theme_constant_override("separation", 8)
	palette_column.add_child(background_row)
	background_color = ColorRect.new()
	background_color.custom_minimum_size = Vector2(38, 26)
	background_row.add_child(background_color)
	background_color_label = Label.new()
	background_row.add_child(background_color_label)
	var texture_label := Label.new()
	texture_label.text = "Brush Texture"
	palette_column.add_child(texture_label)
	texture_selector = OptionButton.new()
	for texture_name in ScurkPixelCanvas.TEXTURE_NAMES:
		texture_selector.add_item(texture_name)
	texture_selector.item_selected.connect(_select_texture)
	palette_column.add_child(texture_selector)
	var transparent_button := Button.new()
	transparent_button.text = "Transparent Eraser"
	transparent_button.tooltip_text = "Erase pixels to transparent with the selected brush size."
	transparent_button.pressed.connect(_select_tool.bind(ScurkPixelCanvas.TOOL_ERASER))
	palette_column.add_child(transparent_button)
	var help := Label.new()
	help.text = (
		"Left mouse uses the foreground color or texture. Right mouse uses the "
		+ "background color. Edit Large, Medium, and Small separately."
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("404040"))
	palette_column.add_child(help)
	var palette_spacer := Control.new()
	palette_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_column.add_child(palette_spacer)
	pointer_status_label = Label.new()
	pointer_status_label.text = "Pointer: --"
	palette_column.add_child(pointer_status_label)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 26)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	page.add_child(status_label)

	open_dialog = FileDialog.new()
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.add_filter("*.MIF, *.mif", "SCURK tile sets")
	open_dialog.file_selected.connect(_load_selected_path)
	add_child(open_dialog)
	save_dialog = FileDialog.new()
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.add_filter("*.MIF, *.mif", "SCURK tile sets")
	save_dialog.file_selected.connect(_save_selected_path)
	add_child(save_dialog)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Unsaved SCURK Changes"
	discard_dialog.get_ok_button().text = "Discard"
	discard_dialog.confirmed.connect(_confirm_discard)
	add_child(discard_dialog)
	error_dialog = AcceptDialog.new()
	error_dialog.title = "SCURK Error"
	add_child(error_dialog)
	_select_palette_index(0, false)
	_select_palette_index(255, true)
	_update_history_buttons()


func _toolbar_button(label: String, callable: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 30)
	button.pressed.connect(callable)
	return button


func _refresh_object_list() -> void:
	if object_list == null:
		return
	var selected_id := current_large_id
	var filter := object_search.text.strip_edges().to_lower() if object_search != null else ""
	object_list.clear()
	if tile_set == null:
		return
	for large_id in editable_large_sprite_ids(tile_set):
		var tile_id := object_tile_id(large_id)
		var tile_name := String(tile_set.names.get(tile_id, ""))
		var label := "%03d  %s" % [tile_id, tile_name if not tile_name.is_empty() else "Unnamed"]
		if not filter.is_empty() and not label.to_lower().contains(filter):
			continue
		var list_index := object_list.add_item(label)
		object_list.set_item_metadata(list_index, large_id)
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
	if palette_control != null:
		palette_control.set_selected_indices(
			foreground_palette_index, background_palette_index
		)
	if pixel_canvas != null:
		pixel_canvas.set_paint_indices(
			foreground_palette_index, background_palette_index
		)
	if foreground_color != null:
		foreground_color.color = (
			palette.color(foreground_palette_index)
			if palette != null and palette.is_valid()
			else Color.MAGENTA
		)
	if foreground_color_label != null:
		foreground_color_label.text = "Foreground: %d (0x%02X)" % [
			foreground_palette_index, foreground_palette_index,
		]
	if background_color != null:
		background_color.color = (
			palette.color(background_palette_index)
			if palette != null and palette.is_valid()
			else Color.MAGENTA
		)
	if background_color_label != null:
		background_color_label.text = "Background: %d (0x%02X)" % [
			background_palette_index, background_palette_index,
		]


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


func _select_texture(index: int) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_texture(index)


func _refresh_sprite() -> void:
	if pixel_canvas == null:
		return
	if tile_set == null or current_large_id < 0:
		pixel_canvas.clear_sprite()
		name_edit.text = ""
		name_edit.editable = false
		name_button.disabled = true
		revert_name_button.disabled = true
		return
	var sprite_id := view_sprite_id(current_large_id, current_view)
	var entry := tile_set.overrides.find_sprite(sprite_id)
	var source := "MIF override"
	if entry == null:
		var base_archive := base_large_sprites if current_view == VIEW_LARGE else base_small_medium_sprites
		entry = base_archive.find_sprite(sprite_id) if base_archive != null else null
		source = "original fallback"
	if entry == null:
		entry = tile_set.archive.find_sprite(sprite_id)
		source = "blank MIF shape"
	if entry == null:
		pixel_canvas.clear_sprite()
		sprite_status_label.text = "Sprite %d is missing." % sprite_id
		return
	var decoded := entry.decode_indices()
	if not decoded.ok:
		pixel_canvas.clear_sprite()
		sprite_status_label.text = decoded.error
		return
	pixel_canvas.set_sprite_data(entry.width, entry.height, decoded.pixels, palette)
	pixel_canvas.set_tool(current_tool)
	pixel_canvas.set_paint_indices(
		foreground_palette_index, background_palette_index
	)
	pixel_canvas.set_brush(
		brush_size_selector.get_item_id(brush_size_selector.selected),
		round_brush_check.button_pressed
	)
	pixel_canvas.set_texture(texture_selector.selected)
	pixel_canvas.filled_shapes = filled_shapes_check.button_pressed
	pixel_canvas.show_grid = grid_check.button_pressed
	var tile_id := object_tile_id(current_large_id)
	name_edit.editable = true
	name_button.disabled = false
	name_edit.text = String(tile_set.names.get(tile_id, ""))
	revert_name_button.disabled = not tile_set.names.has(tile_id)
	sprite_status_label.text = "Sprite %d: %d x %d pixels, %s." % [
		sprite_id, entry.width, entry.height, source,
	]


func _capture_edit_start() -> void:
	if tile_set == null:
		return
	var encoded := tile_set.to_bytes()
	pending_edit_before = encoded.bytes.duplicate() if encoded.ok else PackedByteArray()


func _capture_object_start() -> void:
	object_start_bytes.clear()
	object_start_large_id = current_large_id
	if tile_set == null or current_large_id < 0:
		return
	var encoded := tile_set.to_bytes()
	if encoded.ok:
		object_start_bytes = encoded.bytes.duplicate()
	_update_history_buttons()


func _commit_pixels(value_pixels: PackedInt32Array) -> void:
	if tile_set == null or current_large_id < 0:
		return
	var sprite_id := view_sprite_id(current_large_id, current_view)
	var result := tile_set.set_shape_indices(
		sprite_id, pixel_canvas.sprite_width, pixel_canvas.sprite_height, value_pixels
	)
	if not result.ok:
		_show_error(result.error)
		if not pending_edit_before.is_empty():
			_replace_document_bytes(pending_edit_before)
		_refresh_sprite()
		return
	_record_edit(pending_edit_before)
	_refresh_sprite()


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
	_record_edit(pending_edit_before)
	_refresh_object_list()
	_refresh_sprite()


func _record_edit(before: PackedByteArray) -> void:
	if before.is_empty() or tile_set == null:
		return
	var encoded := tile_set.to_bytes()
	if not encoded.ok or encoded.bytes == before:
		return
	undo_stack.append({"before": before.duplicate(), "after": encoded.bytes.duplicate()})
	if undo_stack.size() > HISTORY_LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()
	pending_edit_before.clear()
	_update_dirty()
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


func _update_dirty() -> void:
	if tile_set == null:
		dirty = false
		return
	var encoded := tile_set.to_bytes()
	dirty = encoded.ok and encoded.bytes != saved_bytes


func _update_history_buttons() -> void:
	if undo_button != null:
		undo_button.disabled = undo_stack.is_empty()
	if redo_button != null:
		redo_button.disabled = redo_stack.is_empty()
	if revert_button != null:
		var encoded := tile_set.to_bytes() if tile_set != null else {}
		revert_button.disabled = (
			object_start_bytes.is_empty()
			or object_start_large_id != current_large_id
			or not encoded.get("ok", false)
			or encoded.bytes == object_start_bytes
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
	if pointer_status_label == null:
		return
	pointer_status_label.text = (
		"Pointer: --"
		if point.x < 0
		else "Pointer: %d, %d — %s" % [
			point.x, point.y,
			"transparent" if index < 0 else "index %d" % index,
		]
	)


func _apply_tile_set() -> void:
	if tile_set == null or not tile_set.is_valid():
		return
	var display_name := source_path.get_file()
	if display_name.is_empty():
		display_name = "Unsaved tile set"
	tile_set_applied.emit(tile_set, display_name, source_path)
	_set_status("Applied %s to the city artwork." % display_name)


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
