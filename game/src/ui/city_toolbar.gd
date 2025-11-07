class_name CityToolbar
extends PanelContainer

signal group_requested(index: int)
signal rotate_requested(counter_clockwise: bool)
signal zoom_out_requested
signal zoom_in_requested
signal undo_requested
signal overlay_requested(mode: String)
signal city_map_requested
signal surface_visibility_requested(visible: bool, layer: String)
signal underground_pipes_visibility_requested(visible: bool)

const Tools = preload("res://src/tools/tool_catalog.gd")
const ClassicStyle = preload("res://src/ui/classic_ui_style.gd")
const MAP_DISPLAY_MODES := ["city", "underground"]
const GROUP_ICON_REGIONS := [
	Rect2i(0, 0, 23, 23), Rect2i(24, 0, 26, 23), Rect2i(50, 0, 20, 23),
	Rect2i(70, 0, 25, 23), Rect2i(95, 0, 21, 23), Rect2i(116, 0, 24, 23),
	Rect2i(140, 0, 23, 23), Rect2i(163, 0, 23, 23), Rect2i(186, 0, 23, 23),
	Rect2i(209, 0, 23, 23), Rect2i(232, 0, 23, 23), Rect2i(255, 0, 23, 23),
	Rect2i(278, 0, 23, 23), Rect2i(302, 0, 23, 23), Rect2i(325, 0, 23, 23),
	Rect2i(348, 0, 29, 23), Rect2i(377, 0, 26, 23), Rect2i(510, 0, 23, 23),
]

var toolbar_art: Image
var toolbar_buttons: Array[Button] = []
var rotate_counter_clockwise_button: Button
var rotate_clockwise_button: Button
var zoom_out_button: Button
var zoom_in_button: Button
var zoom_label: Label
var active_tool_group_label: Label
var child_tool_scroll: ScrollContainer
var child_tool_grid: GridContainer
var undo_button: Button
var view_layers_heading: Label
var view_visibility_checks: Dictionary = {}


func _init(source_art: Image = null) -> void:
	toolbar_art = source_art


func _ready() -> void:
	custom_minimum_size = Vector2(195, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("c0c0c0"), Color("808080"), 2)
	)
	var toolbar_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		toolbar_margin.add_theme_constant_override("margin_" + side, 6)
	add_child(toolbar_margin)

	var toolbar := VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	toolbar_margin.add_child(toolbar)
	var toolbar_title := Label.new()
	toolbar_title.text = "City Toolbar"
	toolbar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar_title.add_theme_color_override("font_color", Color("000080"))
	toolbar_title.add_theme_font_size_override("font_size", 14)
	toolbar.add_child(toolbar_title)

	var tool_grid := GridContainer.new()
	tool_grid.columns = 3
	tool_grid.add_theme_constant_override("h_separation", 3)
	tool_grid.add_theme_constant_override("v_separation", 3)
	tool_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toolbar.add_child(tool_grid)
	var tool_button_group := ButtonGroup.new()
	for group_index in range(15):
		_add_group_button(tool_grid, tool_button_group, group_index)

	toolbar.add_child(HSeparator.new())
	var special_tool_grid := GridContainer.new()
	special_tool_grid.columns = 3
	special_tool_grid.add_theme_constant_override("h_separation", 3)
	special_tool_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toolbar.add_child(special_tool_grid)
	for group_index in range(15, Tools.GROUPS.size()):
		_add_group_button(special_tool_grid, tool_button_group, group_index)

	toolbar.add_child(HSeparator.new())
	var camera_row := HBoxContainer.new()
	camera_row.alignment = BoxContainer.ALIGNMENT_CENTER
	camera_row.add_theme_constant_override("separation", 3)
	toolbar.add_child(camera_row)
	var rotate_label := Label.new()
	rotate_label.text = "Rotate"
	rotate_label.custom_minimum_size = Vector2(48, 0)
	camera_row.add_child(rotate_label)
	rotate_counter_clockwise_button = _icon_button(
		Rect2i(405, 0, 27, 23), "Rotate Counter-Clockwise (Q)"
	)
	rotate_counter_clockwise_button.disabled = true
	rotate_counter_clockwise_button.pressed.connect(
		rotate_requested.emit.bind(true)
	)
	camera_row.add_child(rotate_counter_clockwise_button)
	rotate_clockwise_button = _icon_button(
		Rect2i(433, 0, 27, 23), "Rotate Clockwise (W)"
	)
	rotate_clockwise_button.disabled = true
	rotate_clockwise_button.pressed.connect(rotate_requested.emit.bind(false))
	camera_row.add_child(rotate_clockwise_button)

	var zoom_row := HBoxContainer.new()
	zoom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	zoom_row.add_theme_constant_override("separation", 3)
	toolbar.add_child(zoom_row)
	var zoom_heading := Label.new()
	zoom_heading.text = "Zoom"
	zoom_heading.custom_minimum_size = Vector2(48, 0)
	zoom_row.add_child(zoom_heading)
	zoom_out_button = _icon_button(Rect2i(462, 0, 23, 23), "Zoom Out")
	zoom_out_button.pressed.connect(zoom_out_requested.emit)
	zoom_row.add_child(zoom_out_button)
	zoom_in_button = _icon_button(Rect2i(486, 0, 23, 23), "Zoom In")
	zoom_in_button.pressed.connect(zoom_in_requested.emit)
	zoom_row.add_child(zoom_in_button)
	zoom_label = Label.new()
	zoom_label.text = "100%"
	zoom_label.custom_minimum_size = Vector2(38, 0)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_row.add_child(zoom_label)

	active_tool_group_label = Label.new()
	active_tool_group_label.text = "Selected Group"
	active_tool_group_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_tool_group_label.add_theme_color_override("font_color", Color("000080"))
	active_tool_group_label.add_theme_font_size_override("font_size", 13)
	toolbar.add_child(active_tool_group_label)
	child_tool_scroll = ScrollContainer.new()
	child_tool_scroll.custom_minimum_size = Vector2(0, 96)
	child_tool_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child_tool_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child_tool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	toolbar.add_child(child_tool_scroll)
	child_tool_grid = GridContainer.new()
	child_tool_grid.columns = 1
	child_tool_grid.add_theme_constant_override("h_separation", 3)
	child_tool_grid.add_theme_constant_override("v_separation", 3)
	child_tool_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child_tool_scroll.add_child(child_tool_grid)
	undo_button = Button.new()
	undo_button.text = "Undo Last Edit"
	undo_button.disabled = true
	undo_button.pressed.connect(undo_requested.emit)
	toolbar.add_child(undo_button)

	toolbar.add_child(HSeparator.new())
	var view_heading := Label.new()
	view_heading.text = "City View"
	view_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_heading.add_theme_color_override("font_color", Color("000080"))
	toolbar.add_child(view_heading)
	var view_grid := GridContainer.new()
	view_grid.columns = 2
	view_grid.add_theme_constant_override("h_separation", 4)
	view_grid.add_theme_constant_override("v_separation", 4)
	toolbar.add_child(view_grid)
	for mode in MAP_DISPLAY_MODES:
		var button := Button.new()
		button.text = mode.capitalize()
		button.tooltip_text = "Show the %s isometric view." % mode
		button.pressed.connect(overlay_requested.emit.bind(mode))
		view_grid.add_child(button)
	var city_map_button := Button.new()
	city_map_button.text = "City Map..."
	city_map_button.tooltip_text = "Open the tabbed two-dimensional city maps."
	city_map_button.pressed.connect(city_map_requested.emit)
	view_grid.add_child(city_map_button)

	view_layers_heading = Label.new()
	view_layers_heading.text = "Visible Layers"
	view_layers_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_layers_heading.add_theme_color_override("font_color", Color("000080"))
	toolbar.add_child(view_layers_heading)
	var layers_grid := GridContainer.new()
	layers_grid.columns = 2
	layers_grid.add_theme_constant_override("h_separation", 4)
	layers_grid.add_theme_constant_override("v_separation", 2)
	toolbar.add_child(layers_grid)
	for layer in [
		["Buildings", "buildings"], ["Networks", "networks"],
		["Water", "water"], ["Trees", "trees"],
		["Zones", "zones"], ["Signs", "signs"],
	]:
		var check := CheckBox.new()
		check.text = layer[0]
		check.tooltip_text = (
			"Show or hide %s in the city view." % str(layer[0]).to_lower()
		)
		check.button_pressed = true
		check.toggled.connect(_on_surface_visibility_toggled.bind(layer[1]))
		view_visibility_checks[layer[1]] = check
		layers_grid.add_child(check)
	var pipes_check := CheckBox.new()
	pipes_check.text = "Pipes"
	pipes_check.tooltip_text = "Show or hide pipes in the underground view."
	pipes_check.button_pressed = true
	pipes_check.toggled.connect(underground_pipes_visibility_requested.emit)
	view_visibility_checks["pipes"] = pipes_check
	layers_grid.add_child(pipes_check)


func group_icon(group_index: int) -> Texture2D:
	if group_index < 0 or group_index >= GROUP_ICON_REGIONS.size():
		return null
	return _toolbar_icon(GROUP_ICON_REGIONS[group_index])


func _add_group_button(
	parent: Control, button_group: ButtonGroup, group_index: int
) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(46, 30)
	button.toggle_mode = true
	button.button_group = button_group
	button.tooltip_text = Tools.GROUPS[group_index].name
	button.icon = group_icon(group_index)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.text = str(group_index + 1) if button.icon == null else ""
	button.pressed.connect(group_requested.emit.bind(group_index))
	parent.add_child(button)
	toolbar_buttons.append(button)


func _toolbar_icon(region: Rect2i) -> Texture2D:
	if (
		toolbar_art == null
		or not Rect2i(Vector2i.ZERO, toolbar_art.get_size()).encloses(region)
	):
		return null
	var image := toolbar_art.get_region(region)
	image.convert(Image.FORMAT_RGBA8)
	var background := image.get_pixel(0, 0)
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.is_equal_approx(background):
				image.set_pixel(x, y, Color(color.r, color.g, color.b, 0.0))
			else:
				minimum.x = mini(minimum.x, x)
				minimum.y = mini(minimum.y, y)
				maximum.x = maxi(maximum.x, x)
				maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x:
		return null
	var bounds := Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	return ImageTexture.create_from_image(image.get_region(bounds))


func _icon_button(region: Rect2i, tooltip: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(36, 30)
	button.icon = _toolbar_icon(region)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.text = tooltip.left(1) if button.icon == null else ""
	button.tooltip_text = tooltip
	return button


func _on_surface_visibility_toggled(visible: bool, layer: String) -> void:
	surface_visibility_requested.emit(visible, layer)
