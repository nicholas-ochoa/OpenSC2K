class_name CityQueryDialog
extends ColorRect

const ClassicStyle = preload("res://src/ui/classic_ui_style.gd")

class NeighborhoodPreview extends Control:
	var zoom := 3.5
	var palette: Sc2Palette
	var palette_texture: ImageTexture
	var ticks := 0
	var elapsed := 0.0

	func configure_animation(source: Sc2Palette, start_ticks: int) -> void:
		palette = source
		ticks = start_ticks
		elapsed = 0.0
		material = null
		palette_texture = null
		set_process(source != null)
		if source == null:
			return
		palette_texture = ImageTexture.create_from_image(source.animation_image(ticks))
		var shader := Shader.new()
		shader.code = CityMapControl.PALETTE_CYCLE_SHADER
		var lookup := ShaderMaterial.new()
		lookup.shader = shader
		lookup.set_shader_parameter("animated_palette", palette_texture)
		lookup.set_shader_parameter("palette_cycle_enabled", true)
		lookup.set_shader_parameter("palette_lookup_all", true)
		material = lookup

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or palette == null:
			return
		elapsed += delta
		var steps := int(elapsed / 0.2)
		if steps == 0:
			return
		elapsed -= steps * 0.2
		ticks += steps
		palette_texture.update(palette.animation_image(ticks))

	var texture: Texture2D:
		set(value):
			texture = value
			queue_redraw()
	func _draw() -> void:
		if texture != null:
			var target := texture.get_size() * zoom
			draw_texture_rect(texture, Rect2((size - target) * 0.5, target), false)


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
	name = "QueryOverlay"
	color = Color(0.0, 0.0, 0.0, 0.22)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 900
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "QueryDialog"
	panel.custom_minimum_size = Vector2(860, 600)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		ClassicStyle.create_box(Color("c0c0c0"), Color("404040"), 2, 8, 8)
	)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_add_title_bar(column)
	_add_body(column)
	_add_buttons(column)


func show_query(
	query_title: String,
	facility_name: String,
	is_specific: bool,
	details_text: String,
	action_text: String,
	info: Dictionary = {},
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
	neighborhood_view.zoom = QueryNeighborhood.zoom_for_tile(int(info.get("tile_id", 0)))
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


func _add_title_bar(column: VBoxContainer) -> void:
	var title_bar := DialogTitleBar.new("Query")
	title_label = title_bar.title_label
	title_bar.close_requested.connect(func() -> void: close_requested.emit(false))
	column.add_child(title_bar)


func _add_body(column: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var text_column := VBoxContainer.new()
	text_column.custom_minimum_size = Vector2(580, 0)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(text_column)
	name_input = LineEdit.new()
	name_input.max_length = 23
	name_input.editable = false
	name_input.add_theme_color_override("font_color", Color("101010"))
	name_input.add_theme_color_override("font_uneditable_color", Color("303030"))
	for state in ["normal", "focus", "read_only"]:
		name_input.add_theme_stylebox_override(
			state,
			ClassicStyle.create_box(Color("ffffff"), Color("808080"), 1, 8, 8)
		)
	text_column.add_child(name_input)
	tabs = TabContainer.new()
	tabs.add_theme_stylebox_override("panel", ClassicStyle.create_box(Color("eceeea"), Color("a0a5a0"), 1, 8, 8))
	tabs.add_theme_stylebox_override("tab_selected", ClassicStyle.create_box(Color("eceeea"), Color("a0a5a0"), 1, 10, 7))
	tabs.add_theme_stylebox_override("tab_unselected", ClassicStyle.create_box(Color("d2d5d2"), Color("a0a5a0"), 1, 10, 7))
	tabs.add_theme_color_override("font_selected_color", Color("202830"))
	tabs.add_theme_color_override("font_unselected_color", Color("505860"))
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_column.add_child(tabs)
	var summary := ScrollContainer.new()
	summary.name = "Overview"
	summary.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(summary)
	summary_rows = VBoxContainer.new()
	summary_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_rows.add_theme_constant_override("separation", 6)
	summary.add_child(summary_rows)
	details_grid = _make_details_grid("Technical details")
	things_grid = _make_details_grid("Object details")
	_add_image_column(body)


func _make_details_grid(title: String) -> Tree:
	var grid := Tree.new()
	grid.name = title
	grid.columns = 4
	grid.hide_root = true
	grid.column_titles_visible = true
	grid.select_mode = Tree.SELECT_ROW
	for index in 4:
		grid.set_column_title(index, ["Field", "Decimal", "Text", "Hex"][index])
		grid.set_column_custom_minimum_width(index, [150, 70, 160, 80][index])
		grid.set_column_expand(index, index == 2)
	grid.add_theme_stylebox_override("panel", ClassicStyle.create_box(Color("ffffff"), Color("a0a5a0"), 1, 4, 4))
	grid.add_theme_color_override("font_color", Color("202830"))
	grid.add_theme_color_override("title_button_color", Color("202830"))
	for state in ["normal", "hover", "pressed"]:
		var fill := Color("d2d5d2")
		if state == "hover":
			fill = Color("e0e3e0")
		elif state == "pressed":
			fill = Color("bcc2bc")
		grid.add_theme_stylebox_override("title_button_" + state, ClassicStyle.create_box(fill, Color("a0a5a0"), 1, 8, 6))
	for color_name in ["font_hovered_color", "font_selected_color", "font_hovered_selected_color"]:
		grid.add_theme_color_override(color_name, Color("202830"))
	for style_name in ["hovered", "selected", "selected_focus", "hovered_selected", "hovered_dimmed"]:
		grid.add_theme_stylebox_override(style_name, ClassicStyle.create_box(Color("dce7ef"), Color("839aaa"), 1, 2, 2))
	grid.add_theme_constant_override("v_separation", 8)
	tabs.add_child(grid)
	return grid

func _populate_summary(details: String, info: Dictionary) -> void:
	for child in summary_rows.get_children():
		summary_rows.remove_child(child)
		child.queue_free()
	var lines := details.split("\n")
	if info.has("point"):
		var point: Vector2i = info.point
		lines.insert(1, "Location: X: %d, Y: %d, Z: %d" % [point.x, point.y, int(info.get("altitude_raw", 0)) & 0x1f])
	for index in range(1, lines.size()):
		var line := lines[index].strip_edges()
		if line == "Advanced tile data":
			break
		if line.is_empty() or (info.has("point") and line.begins_with("Tile: ")):
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", ClassicStyle.create_box(Color("f4f4ef"), Color("d3d3cc"), 1, 12, 10))
		summary_rows.add_child(card)
		var split := line.find(":")
		if split > 0:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			card.add_child(row)
			var label := Label.new()
			label.text = line.left(split)
			label.custom_minimum_size.x = 145
			label.add_theme_color_override("font_color", Color("555b62"))
			row.add_child(label)
			var value := _summary_label(line.substr(split + 1).strip_edges())
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(value)
		else:
			card.add_child(_summary_label(line))


func _populate_details(info: Dictionary) -> void:
	_populate_grid(details_grid, QueryPresentation.advanced_rows(info))
	var objects := QueryPresentation.thing_rows(info)
	_populate_grid(things_grid, objects)
	tabs.set_tab_hidden(things_grid.get_index(), objects.is_empty())


func _populate_grid(grid: Tree, rows: Array[PackedStringArray]) -> void:
	grid.clear()
	var root := grid.create_item()
	var row_index := 0
	for row in rows:
		var item := grid.create_item(root)
		for column in 4:
			item.set_text(column, row[column])
			item.set_tooltip_text(column, row[column])
			item.set_custom_bg_color(column, Color("f0f2ee") if row_index % 2 == 0 else Color.WHITE)
		row_index += 1


func _summary_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("202830"))
	label.add_theme_font_size_override("font_size", 16)
	return label


func _add_image_column(body: HBoxContainer) -> void:
	var image_panel := PanelContainer.new()
	image_panel.custom_minimum_size = Vector2(240, 0)
	image_panel.add_theme_stylebox_override(
		"panel",
		ClassicStyle.create_box(Color("18242c"), Color("808080"), 1, 8, 8)
	)
	body.add_child(image_panel)
	var image_column := VBoxContainer.new()
	image_column.add_theme_constant_override("separation", 6)
	image_panel.add_child(image_column)
	neighborhood_view = NeighborhoodPreview.new()
	neighborhood_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	neighborhood_view.clip_contents = true
	neighborhood_view.custom_minimum_size.y = 180
	neighborhood_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_column.add_child(neighborhood_view)


func _add_buttons(column: VBoxContainer) -> void:
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	column.add_child(button_row)
	rename_button = Button.new()
	rename_button.text = "Rename"
	rename_button.pressed.connect(_enable_rename)
	button_row.add_child(rename_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)
	action_button = Button.new()
	action_button.visible = false
	action_button.pressed.connect(func() -> void: action_requested.emit())
	button_row.add_child(action_button)
	ok_button = Button.new()
	ok_button.text = "OK"
	ok_button.custom_minimum_size = Vector2(70, 30)
	ok_button.pressed.connect(func() -> void: close_requested.emit(true))
	button_row.add_child(ok_button)


func _enable_rename() -> void:
	name_input.editable = true
	name_input.grab_focus()
	name_input.select_all()
