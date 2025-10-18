class_name ScurkPlacePrintControl
extends Window

signal tile_selected(tile_id: int)
signal undo_requested
signal redo_requested

const Place = preload("res://src/tools/scurk_place_command.gd")
const PickCopy = preload("res://src/tools/scurk_pick_copy.gd")

const THUMBNAIL_SIZE := 64
const PANEL_SIZE := Vector2i(440, 680)
const ZONE_CHOICES := [
	["Automatic", 0],
	["Light Residential", 1],
	["Dense Residential", 2],
	["Light Commercial", 3],
	["Dense Commercial", 4],
	["Light Industrial", 5],
	["Dense Industrial", 6],
	["Military", 7],
	["Airport or Seaport", 8],
	["Special", 9],
]

var palette: Sc2Palette
var sprites: Sc2SpriteArchive
var custom_names: Dictionary = {}
var current_group := PickCopy.GROUP_RESIDENTIAL
var selected_tile_id := -1
var icon_cache: Dictionary = {}

var group_selector: OptionButton
var zone_selector: OptionButton
var object_list: ItemList
var selection_label: Label
var undo_button: Button
var redo_button: Button


func _ready() -> void:
	name = "SCURKPlacePrint"
	title = "SCURK Place & Print"
	min_size = PANEL_SIZE
	size = PANEL_SIZE
	unresizable = false
	_build_interface()
	hide()


func configure(
	value_palette: Sc2Palette,
	value_sprites: Sc2SpriteArchive,
	value_names: Dictionary = {}
) -> void:
	palette = value_palette
	sprites = value_sprites
	custom_names = value_names.duplicate()
	icon_cache.clear()
	_refresh_objects()


func show_workspace() -> bool:
	if (
		palette == null
		or not palette.is_valid()
		or sprites == null
		or not sprites.is_valid()
	):
		return false
	popup_centered(PANEL_SIZE)
	if object_list != null:
		object_list.grab_focus()
	return true


func selected_zone_id() -> int:
	if zone_selector == null or zone_selector.selected < 0:
		return 0
	return zone_selector.get_item_id(zone_selector.selected)


func select_tile(tile_id: int, notify := true) -> bool:
	if not Place.is_placeable_tile(tile_id):
		return false
	var group := _first_group_for_tile(tile_id)
	if group < 0:
		return false
	current_group = group
	selected_tile_id = tile_id
	_select_group_button(group)
	_refresh_objects()
	if notify:
		tile_selected.emit(selected_tile_id)
	return true


func set_history_enabled(can_undo: bool, can_redo: bool) -> void:
	if undo_button != null:
		undo_button.disabled = not can_undo
	if redo_button != null:
		redo_button.disabled = not can_redo


func set_status(message: String) -> void:
	if selection_label != null:
		selection_label.text = message
		selection_label.tooltip_text = message


func _build_interface() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = Color("c0c0c0")
	panel_box.border_color = Color("ffffff")
	panel_box.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", panel_box)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	var heading := Label.new()
	heading.text = "Place & Print Work Area"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("000080"))
	heading.add_theme_font_size_override("font_size", 20)
	page.add_child(heading)

	var instructions := Label.new()
	instructions.text = (
		"Select an object. Then click its anchor tile in the city. "
		+ "SCURK placement does not use city funds or normal development gates."
	)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size = Vector2(0, 48)
	page.add_child(instructions)

	var group_row := HBoxContainer.new()
	group_row.add_theme_constant_override("separation", 8)
	page.add_child(group_row)
	var group_label := Label.new()
	group_label.text = "Object Group"
	group_label.custom_minimum_size = Vector2(110, 0)
	group_row.add_child(group_label)
	group_selector = OptionButton.new()
	group_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for group in placeable_groups():
		group_selector.add_item(PickCopy.GROUP_NAMES[group], group)
	group_selector.item_selected.connect(_on_group_selected)
	group_row.add_child(group_selector)

	var zone_row := HBoxContainer.new()
	zone_row.add_theme_constant_override("separation", 8)
	page.add_child(zone_row)
	var zone_label := Label.new()
	zone_label.text = "Building Zone"
	zone_label.custom_minimum_size = Vector2(110, 0)
	zone_row.add_child(zone_label)
	zone_selector = OptionButton.new()
	zone_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_selector.tooltip_text = (
		"Select the saved zone type for transitional Residential, Commercial, "
		+ "or Industrial objects. Other objects use their fixed zone type."
	)
	for choice in ZONE_CHOICES:
		zone_selector.add_item(choice[0], choice[1])
	zone_row.add_child(zone_selector)

	object_list = ItemList.new()
	object_list.name = "PlaceObjectList"
	object_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	object_list.select_mode = ItemList.SELECT_SINGLE
	object_list.icon_mode = ItemList.ICON_MODE_TOP
	object_list.fixed_icon_size = Vector2i(THUMBNAIL_SIZE, THUMBNAIL_SIZE)
	object_list.fixed_column_width = 124
	object_list.max_columns = 3
	object_list.same_column_width = true
	object_list.allow_reselect = true
	object_list.item_selected.connect(_on_object_selected)
	object_list.item_activated.connect(_on_object_selected)
	page.add_child(object_list)

	selection_label = Label.new()
	selection_label.text = "Select an object."
	selection_label.custom_minimum_size = Vector2(0, 36)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	page.add_child(selection_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	page.add_child(buttons)
	undo_button = Button.new()
	undo_button.text = "Undo Place"
	undo_button.disabled = true
	undo_button.pressed.connect(undo_requested.emit)
	buttons.add_child(undo_button)
	redo_button = Button.new()
	redo_button.text = "Redo Place"
	redo_button.disabled = true
	redo_button.pressed.connect(redo_requested.emit)
	buttons.add_child(redo_button)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close_requested.emit)
	buttons.add_child(close_button)


func _on_group_selected(index: int) -> void:
	if index < 0 or index >= group_selector.item_count:
		return
	current_group = group_selector.get_item_id(index)
	selected_tile_id = -1
	_refresh_objects()


func _on_object_selected(index: int) -> void:
	if index < 0 or index >= object_list.item_count:
		return
	selected_tile_id = int(object_list.get_item_metadata(index))
	_update_selection_label()
	tile_selected.emit(selected_tile_id)


func _refresh_objects() -> void:
	if object_list == null:
		return
	object_list.clear()
	if sprites == null or not sprites.is_valid():
		return
	var selected_index := -1
	for large_id in Place.placeable_large_ids(current_group):
		var tile_id := large_id - 1000
		var label := "%03d\n%s" % [tile_id, _object_name(tile_id)]
		var item_index := object_list.add_item(label, _object_icon(tile_id))
		object_list.set_item_metadata(item_index, tile_id)
		object_list.set_item_tooltip(
			item_index,
			"%s\nTile %d; large sprite %d" % [
				_object_name(tile_id), tile_id, large_id,
			]
		)
		if tile_id == selected_tile_id:
			selected_index = item_index
	if selected_index < 0 and object_list.item_count > 0:
		selected_index = 0
		selected_tile_id = int(object_list.get_item_metadata(0))
	if selected_index >= 0:
		object_list.select(selected_index)
		object_list.ensure_current_is_visible()
	_update_selection_label()
	if selected_tile_id >= 0:
		tile_selected.emit(selected_tile_id)


func _update_selection_label() -> void:
	if selected_tile_id < 0:
		set_status("No object is available in this group.")
		return
	var area := Place.footprint(selected_tile_id, Vector2i(8, 8)).size.x
	set_status(
		"Selected: %s (tile %d, %d by %d footprint)."
		% [_object_name(selected_tile_id), selected_tile_id, area, area]
	)


func _object_name(tile_id: int) -> String:
	var custom_name := String(custom_names.get(tile_id, "")).strip_edges()
	if not custom_name.is_empty():
		return custom_name
	if tile_id >= 0x70 and tile_id <= 0xc5:
		return "Residential, Commercial, or Industrial"
	if tile_id >= 0xc6 and tile_id <= 0xcf:
		return "Power Plant"
	if tile_id >= 0xd0 and tile_id <= 0xdf:
		return "City Service"
	if tile_id >= 0xe0 and tile_id <= 0xfa:
		return "City Infrastructure"
	if tile_id <= 0x0d:
		return "Landscape Object"
	return "City Object"


func _object_icon(tile_id: int) -> Texture2D:
	if icon_cache.has(tile_id):
		return icon_cache[tile_id]
	var entry = sprites.find_sprite(1000 + tile_id)
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
	icon_cache[tile_id] = texture
	return texture


func _select_group_button(group: int) -> void:
	if group_selector == null:
		return
	for index in group_selector.item_count:
		if group_selector.get_item_id(index) == group:
			group_selector.select(index)
			return


static func placeable_groups() -> PackedInt32Array:
	return PackedInt32Array([
		PickCopy.GROUP_RESIDENTIAL,
		PickCopy.GROUP_COMMERCIAL,
		PickCopy.GROUP_INDUSTRIAL,
		PickCopy.GROUP_SPECIAL,
		PickCopy.GROUP_POWER,
		PickCopy.GROUP_TRANSPORTATION,
		PickCopy.GROUP_MISC,
		PickCopy.GROUP_CONSTRUCTION,
		PickCopy.GROUP_ALL,
	])


static func _first_group_for_tile(tile_id: int) -> int:
	for group in placeable_groups():
		if group == PickCopy.GROUP_ALL:
			continue
		if PickCopy.GROUP_TILE_IDS[group].has(tile_id):
			return group
	return -1
