class_name CityQueryDialog
extends ColorRect

const NeighborhoodPreview = preload("res://src/ui/tools/query_neighborhood_preview.gd")


signal close_requested(commit_rename: bool)
signal action_requested

var title_label: Label
var name_input: LineEdit
var tabs: TabContainer
var summary_rows: VBoxContainer
var details_grid: Tree
var things_grid: Tree
var neighborhood_view: NeighborhoodPreview
var rename_button: Button
var action_button: Button
var ok_button: Button


func _ready() -> void:
	# visible in the editor, closed at startup
	hide()
	var title_bar: DialogTitleBar = $Center/QueryDialog/Content/TitleBar
	title_label = title_bar.title_label
	title_label.text = "Query"
	title_bar.close_requested.connect(func() -> void:
		close_requested.emit(false))
	name_input = get_node("Center/QueryDialog/Content/Body/Text/NameInput")
	tabs = get_node("Center/QueryDialog/Content/Body/Text/Tabs")
	summary_rows = get_node("Center/QueryDialog/Content/Body/Text/Tabs/Overview/Rows")
	details_grid = get_node("Center/QueryDialog/Content/Body/Text/Tabs/Technical details")
	things_grid = get_node("Center/QueryDialog/Content/Body/Text/Tabs/Object details")
	neighborhood_view = get_node("Center/QueryDialog/Content/Body/ImageFrame/Column/Preview")
	rename_button = get_node("Center/QueryDialog/Content/Buttons/Rename")
	action_button = get_node("Center/QueryDialog/Content/Buttons/Action")
	ok_button = get_node("Center/QueryDialog/Content/Buttons/OK")
	rename_button.pressed.connect(_enable_rename)
	action_button.pressed.connect(action_requested.emit)
	ok_button.pressed.connect(func() -> void:
		close_requested.emit(true))

	for grid in [details_grid, things_grid]:
		for index in 4:
			grid.set_column_title(index, ["Field", "Decimal", "Text", "Hex"][index])
			grid.set_column_custom_minimum_width(index, [150, 70, 160, 80][index])
			grid.set_column_expand(index, index == 2)


func show_query(
	query_title: String,
	facility_name: String,
	is_specific: bool,
	details_text: String,
	action_text: String,
	info: QueryResult = null,
	neighborhood_texture: Texture2D = null,
	animation_palette: Sc2Palette = null,
	animation_ticks: int = 0,
) -> void:
	title_label.text = "Query — %s" % query_title
	name_input.visible = is_specific
	name_input.text = facility_name if is_specific else ""
	name_input.editable = false
	rename_button.visible = is_specific
	action_button.visible = not action_text.is_empty()
	action_button.text = action_text
	_populate_summary(details_text, info)
	_populate_details(info)
	tabs.current_tab = 0
	neighborhood_view.configure_animation(animation_palette, animation_ticks)
	neighborhood_view.zoom = QueryNeighborhood.zoom_for_tile(info.tile_id if info != null else 0)
	neighborhood_view.texture = neighborhood_texture
	neighborhood_view.visible = neighborhood_texture != null
	show()
	ok_button.grab_focus()


func rename_is_enabled() -> bool:
	return name_input.editable


func facility_name() -> String:
	return name_input.text


func close_query() -> void:
	hide()
	neighborhood_view.configure_animation(null, 0)
	neighborhood_view.texture = null


func _populate_summary(details: String, info: QueryResult) -> void:
	for child in summary_rows.get_children():
		summary_rows.remove_child(child)
		child.queue_free()

	var lines := details.split("\n")

	if (info != null and info.point.x >= 0):
		var point: Vector2i = info.point
		lines.insert(1, "Location: X: %d, Y: %d, Z: %d" % [point.x, point.y, int(info.altitude_raw) & 0x1f])

	for index in range(1, lines.size()):
		var line := lines[index].strip_edges()

		if line == "Advanced tile data":
			break

		if line.is_empty() or ((info != null and info.point.x >= 0) and line.begins_with("Tile: ")):
			continue

		var card := PanelContainer.new()
		summary_rows.add_child(card)
		var split := line.find(":")

		if split > 0:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			card.add_child(row)
			var label := Label.new()
			label.text = line.left(split)
			label.custom_minimum_size.x = 145
			row.add_child(label)
			var value := _summary_label(line.substr(split + 1).strip_edges())
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(value)
		else:
			card.add_child(_summary_label(line))


func _populate_details(info: QueryResult) -> void:
	_populate_grid(details_grid, QueryPresentation.advanced_rows(info))
	var objects := QueryPresentation.thing_rows(info)
	_populate_grid(things_grid, objects)
	tabs.set_tab_hidden(things_grid.get_index(), objects.is_empty())


func _populate_grid(grid: Tree, rows: Array[PackedStringArray]) -> void:
	grid.clear()
	var root := grid.create_item()

	for row in rows:
		var item := grid.create_item(root)

		for column in 4:
			item.set_text(column, row[column])
			item.set_tooltip_text(column, row[column])


func _summary_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)

	return label


func _enable_rename() -> void:
	name_input.editable = true
	name_input.grab_focus()
	name_input.select_all()
