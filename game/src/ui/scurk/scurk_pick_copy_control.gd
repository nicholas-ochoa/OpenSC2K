class_name ScurkPickCopyControl
extends PanelContainer

signal close_requested
signal copy_requested(
	source: ScurkMif, large_ids: PackedInt32Array, description: String, destination_ids: PackedInt32Array
)

const PickCopy = preload("res://src/tools/scurk/scurk_pick_copy.gd")
const VIEW_LARGE := ScurkSpriteIds.View.LARGE
const VIEW_MEDIUM := ScurkSpriteIds.View.MEDIUM
const VIEW_SMALL := ScurkSpriteIds.View.SMALL
const THUMBNAIL_SIZE := 88

var palette: Sc2Palette
var palette_cycle_ticks := 0
var palette_cycle_accumulator := 0.0
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
var difference_cache := {}
var working_index_by_id := {}
var group_selector: OptionButton
var view_buttons: Array[Button] = []
var source_list: ScurkObjectList
var working_list: ScurkObjectList
var copy_selected_button: Button
var copy_all_button: Button
var source_dialog: FileDialog
var confirm_all_dialog: ConfirmationDialog
var preview_large_id := -1
var preview_before: TextureRect
var preview_after: TextureRect
var preview_label: Label
var preview_previous: Button
var preview_next: Button


func _ready() -> void:
	hide()
	group_selector = get_node("Content/Toolbar/Controls/GroupSelector")
	view_buttons.assign([get_node("Content/Toolbar/Controls/Large"), get_node("Content/Toolbar/Controls/Medium"),
		get_node("Content/Toolbar/Controls/Small")])
	source_list = get_node("Content/Sets/SourceObjectSetRow/SourceList")
	working_list = get_node("Content/Sets/WorkingObjectSetRow/WorkingList")
	source_list.item_selected.connect(_source_selection_changed.bind(true))
	working_list.item_selected.connect(_working_selection_changed.bind(true))
	$Content/Toolbar/Controls/AllowDestination.toggled.connect(_destination_mode_changed)
	$Content/Toolbar/Controls/DifferencesOnly.toggled.connect(func(_enabled: bool) -> void: _refresh_lists())
	$Content/Toolbar/Controls/HighlightDifferences.toggled.connect(func(_enabled: bool) -> void: _refresh_difference_preview())
	var destination_group := $Content/Toolbar/Controls/DestinationGroup as OptionButton
	for group in PickCopy.GROUP_NAMES.size():
		destination_group.add_item(PickCopy.GROUP_NAMES[group], group)
	destination_group.item_selected.connect(_destination_group_changed)
	source_list.get_v_scroll_bar().value_changed.connect(_sync_scroll.bind(working_list))
	working_list.get_v_scroll_bar().value_changed.connect(_sync_scroll.bind(source_list))
	copy_selected_button = get_node("Content/Actions/CopySelectedButton")
	copy_all_button = get_node("Content/Actions/CopyAllButton")
	source_dialog = get_node("SourceDialog")
	confirm_all_dialog = get_node("CopyConfirmation")
	preview_before = $Content/Preview/Images/Before/Artwork
	preview_after = $Content/Preview/Images/After/Artwork
	preview_label = $Content/Preview/Selection/Label
	preview_previous = $Content/Preview/Selection/Previous
	preview_next = $Content/Preview/Selection/Next
	preview_previous.pressed.connect(_step_preview.bind(-1))
	preview_next.pressed.connect(_step_preview.bind(1))
	get_node("Content/TitleBar").close_requested.connect(request_close)
	get_node("Content/Toolbar/Controls/ChangeSource").pressed.connect(request_source)
	get_node("Content/Toolbar/Controls/GroupSelector").item_selected.connect(_select_group)
	get_node("Content/Toolbar/Controls/Large").pressed.connect(_select_view.bind(VIEW_LARGE))
	get_node("Content/Toolbar/Controls/Medium").pressed.connect(_select_view.bind(VIEW_MEDIUM))
	get_node("Content/Toolbar/Controls/Small").pressed.connect(_select_view.bind(VIEW_SMALL))
	get_node("Content/Sets/SourceObjectSetRow/SourceList").multi_selected.connect(_source_selection_changed)
	get_node("Content/Sets/SourceObjectSetRow/SourceList").item_activated.connect(_source_item_activated)
	get_node("Content/Sets/WorkingObjectSetRow/WorkingList").objects_dropped.connect(_objects_dropped)
	working_list.multi_selected.connect(_working_selection_changed)
	get_node("Content/Actions/CopySelectedButton").pressed.connect(_request_copy_selected)
	get_node("Content/Actions/CopyAllButton").pressed.connect(_request_copy_all)
	get_node("SourceDialog").file_selected.connect(_source_selected)
	get_node("CopyConfirmation").confirmed.connect(_copy_all_confirmed)
	$Content/TitleBar.title_label.text = "SCURK Pick & Copy"
	source_list.drag_source = true
	working_list.drop_target = true
	source_dialog.theme = AppUiTheme.file_dialog()
	confirm_all_dialog.theme = AppUiTheme.current()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	palette_cycle_accumulator += delta
	var ticks := floori(palette_cycle_accumulator / Sc2Palette.SCURK_TIMER_INTERVAL_SECONDS)
	if ticks > 0:
		palette_cycle_accumulator -= ticks * Sc2Palette.SCURK_TIMER_INTERVAL_SECONDS
		set_cycle_tick(palette_cycle_ticks + ticks)


func _sync_scroll(scroll_value: float, target: ScurkObjectList) -> void:
	if _remapping():
		return
	# An unchanged Range value emits no signal, which stops the return update.
	target.get_v_scroll_bar().value = scroll_value


func _remapping() -> bool:
	return $Content/Toolbar/Controls/AllowDestination.button_pressed


func _destination_mode_changed(enabled: bool) -> void:
	var selected := source_list.selected_large_ids()
	source_list.deselect_all()
	working_list.deselect_all()
	source_list.select_mode = ItemList.SELECT_SINGLE if enabled else ItemList.SELECT_MULTI
	working_list.select_mode = source_list.select_mode
	working_list.remap_drops = enabled
	if not selected.is_empty():
		for index in source_list.item_count:
			if int(source_list.get_item_metadata(index)) == selected[0]:
				source_list.select(index)
	$Content/Toolbar/Controls/DestinationLabel.visible = enabled
	$Content/Toolbar/Controls/DestinationGroup.visible = enabled
	$Content/Toolbar/Controls/DestinationGroup.select(current_group)
	$Content/Toolbar/Controls/ObjectGroupLabel.text = "Source group" if enabled else "Object Group"
	$Content/Sets/WorkingObjectSetRow/WorkingObjectSetLabel.text = (
		"2. Working — select the destination" if enabled else "2. Working — matching objects to replace"
	)
	copy_all_button.visible = not enabled
	copy_selected_button.tooltip_text = (
		"Replace the selected destination in all three sizes. You can undo this change."
		if enabled else "Replace the matching working objects in all three sizes. You can undo this change."
	)
	preview_previous.visible = not enabled
	preview_next.visible = not enabled
	_refresh_lists()


func _destination_group_changed(_index: int) -> void:
	working_list.deselect_all()
	_refresh_lists()


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
	working_icon_cache.clear()
	working_path = ProjectSettings.globalize_path(path).simplify_path() if not path.is_empty() else ""

	if not source_path.is_empty() and _same_path(source_path, working_path):
		source_set = null
		source_path = ""
		source_icon_cache.clear()

	_refresh_lists()
	show()
	move_to_front()

	if source_set == null:
		_set_status("Choose a source MIF file. Select its objects on the left to preview the replacements.")
	elif is_inside_tree():
		source_list.grab_focus()


func load_source_path(path: String) -> ScurkMif.Result:
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

	var result := ScurkMif.Result.new()
	result.ok = true
	result.error = ""

	return result


func copy_completed(result: ScurkPickCopy.Result) -> void:
	if not result.ok:
		_set_status(result.error, true)

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


func _refresh_lists() -> void:
	if source_list == null or working_list == null:
		return

	var selected := source_list.selected_large_ids()
	source_list.clear()
	difference_cache.clear()
	var source_name_label := $Content/Sets/SourceObjectSetRow/SourceNameLabel as Label
	source_name_label.text = source_path.get_file() if source_set != null else "No source selected"
	var working_name_label := $Content/Sets/WorkingObjectSetRow/WorkingNameLabel as Label
	working_name_label.text = working_path.get_file() if not working_path.is_empty() else "Unsaved working set"
	var large_ids := ScurkPickCopy.group_large_ids(current_group)

	for large_id in large_ids:
		if not _passes_difference_filter(large_id):
			continue
		var source_index := _add_object_item(source_list, source_set, large_id, true)
		if large_id in selected:
			source_list.select(source_index, false)

	_refresh_working_list()
	_sync_working_selection()
	_update_buttons()


func _refresh_working_list() -> void:
	var selected := source_list.selected_large_ids()
	var destinations := working_list.selected_large_ids()
	working_list.clear()
	working_index_by_id.clear()
	var working_group: int = $Content/Toolbar/Controls/DestinationGroup.get_selected_id() if _remapping() else current_group
	for large_id in PickCopy.group_large_ids(working_group):
		if not _passes_difference_filter(large_id):
			continue
		if _remapping() and (source_set == null or selected.size() != 1 or not PickCopy.can_copy_to(selected[0], large_id)):
			continue
		var working_index := _add_object_item(working_list, working_set, large_id, false)
		working_index_by_id[large_id] = working_index
		if _remapping() and large_id in destinations:
			working_list.select(working_index, false)


func _passes_difference_filter(large_id: int) -> bool:
	if not $Content/Toolbar/Controls/DifferencesOnly.button_pressed:
		return true
	if source_set == null or working_set == null:
		return false
	if not difference_cache.has(large_id):
		difference_cache[large_id] = _object_differs(large_id)
	return difference_cache[large_id]


func _object_differs(large_id: int) -> bool:
	for view in ScurkSpriteIds.VIEW_COUNT:
		if _view_differs(large_id, large_id, view):
			return true
	return false


func _view_differs(source_id: int, destination_id: int, view: int) -> bool:
	var source := PickCopy.resolved_entry(source_set,
		ScurkEditorRules.view_sprite_id(source_id, view), base_large, base_small_medium)
	var working := PickCopy.resolved_entry(working_set,
		ScurkEditorRules.view_sprite_id(destination_id, view), base_large, base_small_medium)
	if source == working:
		return false
	if source == null or working == null or source.width != working.width or source.height != working.height:
		return true
	var source_pixels := source.decode_indices()
	var working_pixels := working.decode_indices()
	return not source_pixels.ok or not working_pixels.ok or source_pixels.pixels != working_pixels.pixels


func _shown_source_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for index in source_list.item_count:
		ids.append(int(source_list.get_item_metadata(index)))
	return ids


func _add_object_item(
	list: ScurkObjectList, value: ScurkMif, large_id: int, source: bool
) -> int:
	var tile_id := ScurkEditorRules.object_tile_id(large_id)
	var label := "%03d\n%s" % [tile_id, ScurkEditorRules.tile_name(tile_id, value.names if value != null else {})]

	var icon := _object_icon(value, large_id, source)
	list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var item_index := list.add_item(label, icon)
	list.set_item_metadata(item_index, large_id)
	list.set_item_tooltip(item_index, "%s\n%s object %d; sprite %d\nFootprint: %s" % [
		ScurkEditorRules.tile_name(tile_id, value.names if value != null else {}),
		"Source" if source else "Working", tile_id, ScurkEditorRules.view_sprite_id(large_id, current_view),
		_footprint_label(large_id),
	])

	return item_index


func _object_icon(value: ScurkMif, large_id: int, source: bool, thumbnail := true) -> Texture2D:
	if value == null or palette == null or not palette.is_valid():
		return null

	var cache := source_icon_cache if source else working_icon_cache
	var key := "%d:%d:%s" % [current_view, large_id, thumbnail]

	if cache.has(key):
		var cached: ObjectIcon = cache[key]
		cached.set_cycle(palette, palette.scurk_animation_index_map(palette_cycle_ticks))
		return cached.texture

	var sprite_id := ScurkEditorRules.view_sprite_id(large_id, current_view)
	var entry := ScurkPickCopy.resolved_entry(
		value, sprite_id, base_large, base_small_medium
	)

	if entry == null:
		return null

	var rendered := entry.create_image(Sc2Palette.index_encoding())

	if not rendered.ok:
		return null

	var image: Image = rendered.image.duplicate()
	var thumbnail_scale := minf(
		1.0,
		minf(
			float(THUMBNAIL_SIZE) / float(maxi(1, image.get_width())),
			float(THUMBNAIL_SIZE) / float(maxi(1, image.get_height()))
		)
	)

	if thumbnail and thumbnail_scale < 1.0:
		image.resize(
			maxi(1, floori(image.get_width() * thumbnail_scale)),
			maxi(1, floori(image.get_height() * thumbnail_scale)),
			Image.INTERPOLATE_NEAREST
		)

	var icon := ObjectIcon.new(image, palette)
	icon.set_cycle(palette, palette.scurk_animation_index_map(palette_cycle_ticks))
	cache[key] = icon

	return icon.texture


func set_cycle_tick(tick: int) -> void:
	var previous := palette_cycle_ticks
	palette_cycle_ticks = tick
	if not is_visible_in_tree() or palette == null or not palette.is_valid():
		return
	var mapping := palette.scurk_animation_index_map(tick)
	if mapping == palette.scurk_animation_index_map(previous):
		return
	for cache in [source_icon_cache, working_icon_cache]:
		for icon: ObjectIcon in cache.values():
			icon.set_cycle(palette, mapping)


func _select_group(index: int) -> void:
	current_group = group_selector.get_item_id(index)
	_refresh_lists()


func _select_view(view: int) -> void:
	current_view = view as ScurkSpriteIds.View

	for index in view_buttons.size():
		view_buttons[index].button_pressed = index == view

	_refresh_lists()


func _source_selection_changed(index: int, selected: bool) -> void:
	if selected:
		preview_large_id = int(source_list.get_item_metadata(index))
	if _remapping():
		_refresh_working_list()
	_sync_working_selection()
	_update_buttons()


func _sync_working_selection() -> void:
	if working_list == null or source_list == null:
		return
	if _remapping():
		_refresh_preview()
		return

	working_list.deselect_all()

	for large_id in source_list.selected_large_ids():
		if working_index_by_id.has(large_id):
			working_list.select(working_index_by_id[large_id], false)
	_refresh_preview()


func _working_selection_changed(index: int, selected: bool) -> void:
	if _remapping():
		_refresh_preview()
		_update_buttons()
		return
	var selected_ids := working_list.selected_large_ids()
	source_list.deselect_all()
	for source_index in source_list.item_count:
		if int(source_list.get_item_metadata(source_index)) in selected_ids:
			source_list.select(source_index, false)
	if selected:
		preview_large_id = int(working_list.get_item_metadata(index))
	_refresh_preview()
	_update_buttons()


func _refresh_preview() -> void:
	_refresh_artwork_preview()
	_refresh_difference_preview()


func _refresh_difference_preview() -> void:
	var panel := $Content/Preview/Images/Differences as VBoxContainer
	panel.visible = $Content/Toolbar/Controls/HighlightDifferences.button_pressed
	var artwork := panel.get_node("Artwork") as TextureRect
	var label := panel.get_node("Label") as Label
	var note := panel.get_node("OtherSizesNote") as Label
	note.hide()
	artwork.texture = null
	label.text = "Changed pixels (pink)"
	if not panel.visible or preview_before.texture == null or preview_after.texture == null:
		return
	var source_id := preview_large_id
	var destination_id := preview_large_id
	if _remapping():
		source_id = source_list.selected_large_ids()[0]
		destination_id = working_list.selected_large_ids()[0]
	var before := PickCopy.resolved_entry(working_set,
		ScurkEditorRules.view_sprite_id(destination_id, current_view), base_large, base_small_medium)
	var after := PickCopy.resolved_entry(source_set,
		ScurkEditorRules.view_sprite_id(source_id, current_view), base_large, base_small_medium)
	var difference := ScurkCopyDifference.compare(before, after, palette)
	if difference.image != null:
		artwork.texture = PixelArtTexture.wrap(ImageTexture.create_from_image(difference.image))
		label.text = tr("%d changed pixels (pink)") % difference.changed_pixels
		if difference.changed_pixels == 0:
			for view in ScurkSpriteIds.VIEW_COUNT:
				if view != current_view and _view_differs(source_id, destination_id, view):
					note.show()
					break


func _refresh_artwork_preview() -> void:
	var selected := source_list.selected_large_ids()
	var ready_to_preview := source_set != null and working_set != null and not selected.is_empty()
	preview_before.texture = null
	preview_after.texture = null
	preview_previous.disabled = true
	preview_next.disabled = true
	preview_previous.visible = not _remapping() and selected.size() > 1
	preview_next.visible = preview_previous.visible
	if _remapping():
		_refresh_destination_preview()
		return
	if not ready_to_preview:
		preview_large_id = -1
		preview_label.text = "Select source objects to preview their matching replacements."
		return

	if not selected.has(preview_large_id):
		preview_large_id = selected[0]
	var index := selected.find(preview_large_id)
	var tile_id := ScurkEditorRules.object_tile_id(preview_large_id)
	preview_label.text = tr("%d of %d selected · %s (object %03d) · %s preview") % [
		index + 1, selected.size(), ScurkEditorRules.tile_name(tile_id, working_set.names), tile_id,
		["Large", "Medium", "Small"][current_view],
	]
	preview_before.texture = _object_icon(working_set, preview_large_id, false, false)
	preview_after.texture = _object_icon(source_set, preview_large_id, true, false)
	preview_previous.disabled = index == 0
	preview_next.disabled = index == selected.size() - 1


func _refresh_destination_preview() -> void:
	var selected := source_list.selected_large_ids()
	var destinations := working_list.selected_large_ids()
	if selected.size() != 1 or source_set == null:
		preview_label.text = "Select one source tile, then choose its destination on the right."
		return
	var source_id := selected[0]
	preview_after.texture = _object_icon(source_set, source_id, true, false)
	if destinations.size() != 1:
		if working_list.item_count == 0:
			preview_label.text = "No compatible tiles in this destination group. Choose another group."
			return
		if PickCopy.footprint_size(source_id) == 0:
			preview_label.text = "This sprite has no map footprint. Choose the same tile ID as its destination."
			return
		preview_label.text = tr("Source %03d · Choose a %s destination on the right.") % [
			ScurkEditorRules.object_tile_id(source_id), _footprint_label(source_id),
		]
		return
	var destination_id := destinations[0]
	preview_before.texture = _object_icon(working_set, destination_id, false, false)
	preview_label.text = tr("Source %03d (%s) → Working %03d (%s) · %s") % [
		ScurkEditorRules.object_tile_id(source_id), _footprint_label(source_id),
		ScurkEditorRules.object_tile_id(destination_id), _footprint_label(destination_id),
		["Large", "Medium", "Small"][current_view] + " preview" if PickCopy.can_copy_to(source_id, destination_id)
		else "Cannot copy: footprints must match.",
	]


func _footprint_label(large_id: int) -> String:
	var size_in_tiles := PickCopy.footprint_size(large_id)
	return "%d×%d" % [size_in_tiles, size_in_tiles] if size_in_tiles > 0 else "no tile footprint"


func _destination_ready() -> bool:
	var selected := source_list.selected_large_ids()
	var destinations := working_list.selected_large_ids()
	return selected.size() == 1 and destinations.size() == 1 and PickCopy.can_copy_to(selected[0], destinations[0])


func _step_preview(direction: int) -> void:
	var selected := source_list.selected_large_ids()
	if selected.is_empty():
		return
	var index := clampi(selected.find(preview_large_id) + direction, 0, selected.size() - 1)
	preview_large_id = selected[index]
	_refresh_preview()


func _update_buttons() -> void:
	var sets_ready := source_set != null and working_set != null

	if copy_selected_button != null:
		copy_selected_button.disabled = not sets_ready or source_list.selected_large_ids().is_empty()
		copy_selected_button.text = tr("Copy Selected (%d) →") % source_list.selected_large_ids().size()
		if _remapping():
			copy_selected_button.disabled = not sets_ready or not _destination_ready()
			copy_selected_button.text = "Copy to Destination →"

	if copy_all_button != null:
		copy_all_button.disabled = not sets_ready or source_list.item_count == 0
		copy_all_button.text = tr("Copy All in %s…") % PickCopy.GROUP_NAMES[current_group]


func _request_copy_selected() -> void:
	var large_ids := source_list.selected_large_ids()

	if source_set == null or large_ids.is_empty():
		return

	if _remapping():
		if _destination_ready():
			copy_requested.emit(source_set, large_ids, "Copy to destination", working_list.selected_large_ids())
		return
	copy_requested.emit(source_set, large_ids, "Copy Selected", PackedInt32Array())


func _source_item_activated(_index: int) -> void:
	_request_copy_selected()


func _objects_dropped(large_ids: PackedInt32Array, destination_id: int) -> void:
	if source_set == null:
		return

	if _remapping():
		if large_ids.size() != 1 or not PickCopy.can_copy_to(large_ids[0], destination_id):
			return
		if not working_index_by_id.has(destination_id):
			return
		working_list.select(working_index_by_id[destination_id])
		_refresh_preview()
		copy_requested.emit(source_set, large_ids, "Dragged copy", PackedInt32Array([destination_id]))
		return
	copy_requested.emit(source_set, large_ids, "Dragged copy", PackedInt32Array())


func _request_copy_all() -> void:
	if source_set == null or _remapping():
		return

	var object_count := source_list.item_count
	if object_count == 0:
		return
	var source_name_label := $Content/Sets/SourceObjectSetRow/SourceNameLabel as Label
	var working_name_label := $Content/Sets/WorkingObjectSetRow/WorkingNameLabel as Label
	confirm_all_dialog.dialog_text = (
		("Copy graphics from %s into %s?\n\n"
		+ "Replace the %d shown objects in %s, including Large, Medium, and Small.\nYou can undo this change.")
		% [source_name_label.text, working_name_label.text, object_count, ScurkPickCopy.GROUP_NAMES[current_group]]
	)
	confirm_all_dialog.popup_centered()


func _copy_all_confirmed() -> void:
	if source_set == null or _remapping():
		return

	copy_requested.emit(
		source_set,
		_shown_source_ids(),
		"Copy All %s" % ScurkPickCopy.GROUP_NAMES[current_group],
		PackedInt32Array()
	)


func _source_selected(path: String) -> void:
	var result := load_source_path(path)

	if not result.ok:
		_set_status(result.error, true)


func _set_status(message: String, error := false) -> void:
	var status_label := $Content/StatusLabel as Label
	if status_label == null:
		return

	if error:
		status_label.theme_type_variation = "ErrorLabel"
	else:
		status_label.theme_type_variation = ""

	status_label.text = message


func _same_path(left: String, right: String) -> bool:
	return not left.is_empty() and not right.is_empty() and left.nocasecmp_to(right) == 0


func _failure(message: String) -> ScurkMif.Result:
	var result := ScurkMif.Result.new()
	result.ok = false
	result.error = message

	return result


class ObjectIcon:
	extends RefCounted

	var texture: Texture2D
	var image: Image
	var rgba: PackedByteArray
	var cycle_offsets := PackedInt32Array()
	var cycle_indices := PackedInt32Array()
	var cycle_map := PackedInt32Array()


	func _init(index_image: Image, value_palette: Sc2Palette) -> void:
		rgba = index_image.get_data()
		for pixel in index_image.get_width() * index_image.get_height():
			var offset := pixel * 4
			if rgba[offset + 3] == 0:
				continue
			var index := int(rgba[offset])
			rgba.encode_u32(offset, value_palette.color(index).to_abgr32())
			if ((index >= Sc2Palette.FAST_CYCLE_START and index < Sc2Palette.FAST_CYCLE_START + Sc2Palette.FAST_CYCLE_COUNT)
					or (index >= Sc2Palette.SLOW_CYCLE_START and index < Sc2Palette.SLOW_CYCLE_START + Sc2Palette.SLOW_CYCLE_COUNT)):
				cycle_offsets.append(offset)
				cycle_indices.append(index)
		image = Image.create_from_data(index_image.get_width(), index_image.get_height(), false, Image.FORMAT_RGBA8, rgba)
		texture = PixelArtTexture.wrap(ImageTexture.create_from_image(image))


	func set_cycle(value_palette: Sc2Palette, mapping: PackedInt32Array) -> void:
		if cycle_offsets.is_empty() or cycle_map == mapping:
			return
		cycle_map = mapping
		for pixel in cycle_offsets.size():
			rgba.encode_u32(cycle_offsets[pixel], value_palette.color(mapping[cycle_indices[pixel]]).to_abgr32())
		image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, rgba)
		(PixelArtTexture.unwrap(texture) as ImageTexture).update(image)
