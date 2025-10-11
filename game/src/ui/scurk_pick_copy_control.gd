class_name ScurkPickCopyControl
extends PanelContainer

signal close_requested
signal change_working_requested
signal copy_requested(
	source: ScurkMif, large_ids: PackedInt32Array, description: String
)

const PickCopy = preload("res://src/tools/scurk_pick_copy.gd")
const ObjectListControl = preload("res://src/ui/scurk_object_list.gd")

const VIEW_LARGE := 0
const VIEW_MEDIUM := 1
const VIEW_SMALL := 2
const THUMBNAIL_SIZE := 88

var palette: Sc2Palette
var base_large: Sc2SpriteArchive
var base_small_medium: Sc2SpriteArchive
var reference_directory := ""
var working_set: ScurkMif
var working_path := ""
var source_set: ScurkMif
var source_path := ""
var current_group := ScurkPickCopy.GROUP_RESIDENTIAL
var current_view := VIEW_LARGE
var source_icon_cache := {}
var working_icon_cache := {}
var working_index_by_id := {}

var group_selector: OptionButton
var view_buttons: Array[Button] = []
var source_name_label: Label
var working_name_label: Label
var source_list: ScurkObjectList
var working_list: ScurkObjectList
var copy_selected_button: Button
var copy_all_button: Button
var status_label: Label
var source_dialog: FileDialog
var confirm_all_dialog: ConfirmationDialog


func _ready() -> void:
	name = "ScurkPickCopy"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 38
	offset_top = 48
	offset_right = -38
	offset_bottom = -38
	_build_interface()
	hide()


func configure(
	value_palette: Sc2Palette,
	value_large: Sc2SpriteArchive,
	value_small_medium: Sc2SpriteArchive,
	value_reference_directory: String
) -> void:
	palette = value_palette
	base_large = value_large
	base_small_medium = value_small_medium
	reference_directory = value_reference_directory.simplify_path()
	source_icon_cache.clear()
	working_icon_cache.clear()


func open_with_working(value: ScurkMif, path: String) -> void:
	working_set = value
	working_path = ProjectSettings.globalize_path(path).simplify_path() if not path.is_empty() else ""
	if not source_path.is_empty() and _same_path(source_path, working_path):
		source_set = null
		source_path = ""
		source_icon_cache.clear()
	_refresh_lists()
	show()
	move_to_front()
	if source_set == null:
		_set_status("Choose a different source object set, then select objects to copy.")
	elif is_inside_tree():
		source_list.grab_focus()


func load_source_path(path: String) -> Dictionary:
	var normalized := ProjectSettings.globalize_path(path).simplify_path()
	if _same_path(normalized, working_path):
		return _failure("The source and working object sets must be different.")
	var loaded := ScurkMif.load_path(normalized)
	if not loaded.is_valid():
		return _failure(loaded.parse_error)
	source_set = loaded
	source_path = normalized
	source_icon_cache.clear()
	_refresh_lists()
	_set_status("Loaded source object set %s." % source_path.get_file())
	return {"ok": true, "error": ""}


func copy_completed(result: Dictionary) -> void:
	if not result.get("ok", false):
		_set_status(result.get("error", "The objects could not be copied."), true)
		return
	working_icon_cache.clear()
	_refresh_lists()
	_set_status(
		"Copied %d objects and %d sprite views into the working set."
		% [result.object_count, result.shape_count]
	)


func request_source() -> void:
	var start_directory := reference_directory.path_join("SCURKART")
	if DirAccess.dir_exists_absolute(start_directory):
		source_dialog.current_dir = start_directory
	source_dialog.popup_centered_ratio(0.78)


func request_close() -> void:
	hide()
	close_requested.emit()


func _build_interface() -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 7)
	add_child(page)

	var title_row := HBoxContainer.new()
	page.add_child(title_row)
	var title := Label.new()
	title.text = "SCURK Pick & Copy"
	title.add_theme_color_override("font_color", Color("000080"))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.tooltip_text = "Return to Paint the Town."
	close_button.pressed.connect(request_close)
	title_row.add_child(close_button)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	page.add_child(controls)
	var source_button := Button.new()
	source_button.text = "Change Source..."
	source_button.tooltip_text = "Choose the read-only object set to copy from."
	source_button.pressed.connect(request_source)
	controls.add_child(source_button)
	var working_button := Button.new()
	working_button.text = "Change Working..."
	working_button.tooltip_text = "Choose the object set that receives copied graphics."
	working_button.pressed.connect(change_working_requested.emit)
	controls.add_child(working_button)
	controls.add_child(VSeparator.new())
	var group_label := Label.new()
	group_label.text = "Object Group"
	group_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(group_label)
	group_selector = OptionButton.new()
	for group_index in ScurkPickCopy.GROUP_NAMES.size():
		group_selector.add_item(ScurkPickCopy.GROUP_NAMES[group_index], group_index)
	group_selector.item_selected.connect(_select_group)
	controls.add_child(group_selector)
	controls.add_child(VSeparator.new())
	var view_group := ButtonGroup.new()
	for view_data in [["Large", VIEW_LARGE], ["Medium", VIEW_MEDIUM], ["Small", VIEW_SMALL]]:
		var button := Button.new()
		button.text = view_data[0]
		button.toggle_mode = true
		button.button_group = view_group
		button.pressed.connect(_select_view.bind(view_data[1]))
		controls.add_child(button)
		view_buttons.append(button)
	view_buttons[0].button_pressed = true

	var sets := HSplitContainer.new()
	sets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sets.split_offset = 570
	page.add_child(sets)
	var source_column := _set_column("Source Object Set", true)
	sets.add_child(source_column)
	var working_column := _set_column("Working Object Set", false)
	sets.add_child(working_column)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	page.add_child(actions)
	copy_selected_button = Button.new()
	copy_selected_button.text = "Copy Selected"
	copy_selected_button.tooltip_text = "Replace each equivalent working object with its selected source graphics."
	copy_selected_button.disabled = true
	copy_selected_button.pressed.connect(_request_copy_selected)
	actions.add_child(copy_selected_button)
	copy_all_button = Button.new()
	copy_all_button.text = "Copy All"
	copy_all_button.tooltip_text = "Replace every working object in the selected group."
	copy_all_button.disabled = true
	copy_all_button.pressed.connect(_request_copy_all)
	actions.add_child(copy_all_button)
	var action_help := Label.new()
	action_help.text = "Ctrl-click or Shift-click to select more objects. You can also drag source objects onto the working set."
	action_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_help.add_theme_color_override("font_color", Color("404040"))
	actions.add_child(action_help)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 26)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	page.add_child(status_label)

	source_dialog = FileDialog.new()
	source_dialog.access = FileDialog.ACCESS_FILESYSTEM
	source_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	source_dialog.add_filter("*.MIF, *.mif", "SCURK tile sets")
	source_dialog.file_selected.connect(_source_selected)
	add_child(source_dialog)
	confirm_all_dialog = ConfirmationDialog.new()
	confirm_all_dialog.title = "Copy Object Group"
	confirm_all_dialog.get_ok_button().text = "Copy All"
	confirm_all_dialog.confirmed.connect(_copy_all_confirmed)
	add_child(confirm_all_dialog)


func _set_column(heading_text: String, source: bool) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(430, 0)
	column.add_theme_constant_override("separation", 5)
	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_color_override("font_color", Color("000080"))
	column.add_child(heading)
	var filename := Label.new()
	filename.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	filename.add_theme_color_override("font_color", Color("404040"))
	column.add_child(filename)
	var list := ObjectListControl.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.select_mode = ItemList.SELECT_MULTI
	list.icon_mode = ItemList.ICON_MODE_TOP
	list.fixed_icon_size = Vector2i(THUMBNAIL_SIZE, THUMBNAIL_SIZE)
	list.same_column_width = true
	list.max_columns = 0
	column.add_child(list)
	if source:
		source_name_label = filename
		source_list = list
		list.drag_source = true
		list.multi_selected.connect(_source_selection_changed)
		list.item_activated.connect(_source_item_activated)
	else:
		working_name_label = filename
		working_list = list
		list.drop_target = true
		list.objects_dropped.connect(_objects_dropped)
	return column


func _refresh_lists() -> void:
	if source_list == null or working_list == null:
		return
	var selected := source_list.selected_large_ids()
	source_list.clear()
	working_list.clear()
	working_index_by_id.clear()
	source_name_label.text = source_path.get_file() if source_set != null else "No source selected"
	working_name_label.text = working_path.get_file() if not working_path.is_empty() else "Unsaved working set"
	var large_ids := ScurkPickCopy.group_large_ids(current_group)
	for large_id in large_ids:
		var source_index := _add_object_item(source_list, source_set, large_id, true)
		var working_index := _add_object_item(working_list, working_set, large_id, false)
		working_index_by_id[large_id] = working_index
		if large_id in selected:
			source_list.select(source_index, false)
	_sync_working_selection()
	_update_buttons()


func _add_object_item(
	list: ScurkObjectList, value: ScurkMif, large_id: int, source: bool
) -> int:
	var tile_id := large_id - 1000
	var custom_name := String(value.names.get(tile_id, "")) if value != null else ""
	var label := "%03d" % tile_id
	if not custom_name.is_empty():
		label += "\n" + custom_name
	var icon := _object_icon(value, large_id, source)
	var item_index := list.add_item(label, icon)
	list.set_item_metadata(item_index, large_id)
	list.set_item_tooltip(item_index, "%s object %d; sprite %d" % [
		"Source" if source else "Working", tile_id, large_id - current_view * 500,
	])
	return item_index


func _object_icon(value: ScurkMif, large_id: int, source: bool) -> Texture2D:
	if value == null or palette == null or not palette.is_valid():
		return null
	var cache := source_icon_cache if source else working_icon_cache
	var key := "%d:%d" % [current_view, large_id]
	if cache.has(key):
		return cache[key]
	var sprite_id := large_id - current_view * 500
	var entry := ScurkPickCopy.resolved_entry(
		value, sprite_id, base_large, base_small_medium
	)
	if entry == null:
		return null
	var rendered := entry.create_image(palette)
	if not rendered.ok:
		return null
	var image: Image = rendered.image.duplicate()
	var scale := minf(
		1.0,
		minf(
			float(THUMBNAIL_SIZE) / float(maxi(1, image.get_width())),
			float(THUMBNAIL_SIZE) / float(maxi(1, image.get_height()))
		)
	)
	if scale < 1.0:
		image.resize(
			maxi(1, floori(image.get_width() * scale)),
			maxi(1, floori(image.get_height() * scale)),
			Image.INTERPOLATE_NEAREST
		)
	var texture := ImageTexture.create_from_image(image)
	cache[key] = texture
	return texture


func _select_group(index: int) -> void:
	current_group = group_selector.get_item_id(index)
	_refresh_lists()


func _select_view(view: int) -> void:
	current_view = view
	for index in view_buttons.size():
		view_buttons[index].button_pressed = index == view
	_refresh_lists()


func _source_selection_changed(_index: int, _selected: bool) -> void:
	_sync_working_selection()
	_update_buttons()


func _sync_working_selection() -> void:
	if working_list == null or source_list == null:
		return
	working_list.deselect_all()
	for large_id in source_list.selected_large_ids():
		if working_index_by_id.has(large_id):
			working_list.select(working_index_by_id[large_id], false)


func _update_buttons() -> void:
	var ready := source_set != null and working_set != null
	if copy_selected_button != null:
		copy_selected_button.disabled = not ready or source_list.selected_large_ids().is_empty()
	if copy_all_button != null:
		copy_all_button.disabled = not ready


func _request_copy_selected() -> void:
	var large_ids := source_list.selected_large_ids()
	if source_set == null or large_ids.is_empty():
		return
	copy_requested.emit(source_set, large_ids, "Copy Selected")


func _source_item_activated(_index: int) -> void:
	_request_copy_selected()


func _objects_dropped(large_ids: PackedInt32Array) -> void:
	if source_set == null:
		return
	copy_requested.emit(source_set, large_ids, "Dragged copy")


func _request_copy_all() -> void:
	if source_set == null:
		return
	var object_count := ScurkPickCopy.group_large_ids(current_group).size()
	confirm_all_dialog.dialog_text = (
		"Replace all %d working objects in the %s group?"
		% [object_count, ScurkPickCopy.GROUP_NAMES[current_group]]
	)
	confirm_all_dialog.popup_centered()


func _copy_all_confirmed() -> void:
	if source_set == null:
		return
	copy_requested.emit(
		source_set,
		ScurkPickCopy.group_large_ids(current_group),
		"Copy All %s" % ScurkPickCopy.GROUP_NAMES[current_group]
	)


func _source_selected(path: String) -> void:
	var result := load_source_path(path)
	if not result.ok:
		_set_status(result.error, true)


func _set_status(message: String, error := false) -> void:
	if status_label == null:
		return
	if error:
		status_label.add_theme_color_override("font_color", Color("b00000"))
	else:
		status_label.remove_theme_color_override("font_color")
	status_label.text = message


func _same_path(left: String, right: String) -> bool:
	return not left.is_empty() and not right.is_empty() and left.nocasecmp_to(right) == 0


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
