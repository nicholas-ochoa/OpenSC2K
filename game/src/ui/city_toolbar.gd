class_name CityToolbar
extends PanelContainer

signal button_clicked
signal start_city_requested

var start_city_button: Button
var landscape_editor := false

signal group_requested(index: int)
signal subtool_requested(index: int)
signal rotate_requested(counter_clockwise: bool)
signal zoom_out_requested
signal zoom_in_requested
signal overlay_requested(mode: String)
signal surface_visibility_requested(visible: bool, layer: String)
signal underground_pipes_visibility_requested(visible: bool)
signal underground_subways_visibility_requested(visible: bool)

const Tools = preload("res://src/tools/tool_catalog.gd")
const ClassicStyle = preload("res://src/ui/classic_ui_style.gd")
const ChildToolPalette = preload("res://src/ui/city_child_tool_palette.gd")
const HoldMenu = preload("res://src/ui/city_tool_hold_menu.gd")
const HOLD_SECONDS := 0.45
const MAP_DISPLAY_MODES := ["city", "underground"]
const GROUP_ICON_REGIONS := [
	Rect2i(0, 0, 23, 23), Rect2i(24, 0, 26, 23), Rect2i(50, 0, 20, 23),
	Rect2i(70, 0, 25, 23), Rect2i(95, 0, 21, 23), Rect2i(116, 0, 24, 23),
	Rect2i(140, 0, 23, 23), Rect2i(163, 0, 23, 23), Rect2i(186, 0, 23, 23),
	Rect2i(209, 0, 23, 23), Rect2i(232, 0, 23, 23), Rect2i(255, 0, 23, 23),
	Rect2i(278, 0, 23, 23), Rect2i(302, 0, 23, 23), Rect2i(325, 0, 23, 23),
	Rect2i(348, 0, 29, 23), Rect2i(377, 0, 26, 23), Rect2i(510, 0, 21, 23),
]

var hold_menu: CityToolHoldMenu
var _hold_generation := 0
var _held_group := -1
var _hold_opened := false
var _current_city: CityState
var _icon_provider := Callable()
var _selected_subtool := 0

var toolbar_art: Image
var toolbar_buttons: Array[Button] = []
var rotate_counter_clockwise_button: Button
var rotate_clockwise_button: Button
var zoom_out_button: Button
var zoom_in_button: Button
var active_tool_group_label: Label
var child_tool_scroll: ScrollContainer
var child_tool_grid: GridContainer
var child_tool_buttons: Dictionary = {}
var child_palette: CityChildToolPalette
var view_layers_heading: Label
var view_visibility_checks: Dictionary = {}
var view_mode_buttons: Dictionary = {}


func _init(source_art: Image = null) -> void:
	toolbar_art = source_art


func _ready() -> void:
	custom_minimum_size = Vector2(195, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("c0c0c0"), Color("808080"), 2)
	)
	hold_menu = HoldMenu.new()
	hold_menu.subtool_requested.connect(subtool_requested.emit)
	add_child(hold_menu)
	var toolbar_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		toolbar_margin.add_theme_constant_override("margin_" + side, 6)
	add_child(toolbar_margin)

	var toolbar := VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	toolbar_margin.add_child(toolbar)

	start_city_button = Button.new()
	start_city_button.text = "Start City"
	start_city_button.custom_minimum_size.y = 36
	start_city_button.hide()
	start_city_button.pressed.connect(start_city_requested.emit)
	toolbar.add_child(start_city_button)

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
	var camera_row := _camera_row(toolbar, "Rotate")
	rotate_counter_clockwise_button = _icon_button(
		Rect2i(405, 0, 27, 23), "Rotate Counter-Clockwise"
	)
	rotate_counter_clockwise_button.disabled = true
	rotate_counter_clockwise_button.pressed.connect(
		rotate_requested.emit.bind(true)
	)
	camera_row.add_child(rotate_counter_clockwise_button)
	rotate_clockwise_button = _icon_button(
		Rect2i(433, 0, 27, 23), "Rotate Clockwise"
	)
	rotate_clockwise_button.disabled = true
	rotate_clockwise_button.pressed.connect(rotate_requested.emit.bind(false))
	camera_row.add_child(rotate_clockwise_button)

	var zoom_row := _camera_row(toolbar, "Zoom")
	zoom_out_button = _icon_button(Rect2i(462, 0, 23, 23), "Zoom Out (Q / -)")
	zoom_out_button.pressed.connect(zoom_out_requested.emit)
	zoom_row.add_child(zoom_out_button)
	zoom_in_button = _icon_button(Rect2i(486, 0, 23, 23), "Zoom In (E / +)")
	zoom_in_button.pressed.connect(zoom_in_requested.emit)
	zoom_row.add_child(zoom_in_button)

	child_palette = ChildToolPalette.new()
	child_palette.build()
	child_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child_palette.subtool_requested.connect(subtool_requested.emit)
	toolbar.add_child(child_palette)
	active_tool_group_label = child_palette.heading
	child_tool_scroll = child_palette.scroll
	child_tool_grid = child_palette.grid
	child_tool_buttons = child_palette.buttons

	toolbar.add_child(HSeparator.new())
	view_layers_heading = Label.new()
	view_layers_heading.text = "Visible Layers"
	view_layers_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_layers_heading.add_theme_color_override("font_color", Color("000080"))
	toolbar.add_child(view_layers_heading)
	var view_grid := VBoxContainer.new()
	view_grid.add_theme_constant_override("separation", 0)
	toolbar.add_child(view_grid)
	var view_group := ButtonGroup.new()
	for mode in MAP_DISPLAY_MODES:
		var button := CheckBox.new()
		button.text = mode.capitalize()
		button.button_group = view_group
		button.button_pressed = mode == "city"
		button.tooltip_text = "Show the %s isometric view." % mode
		button.pressed.connect(overlay_requested.emit.bind(mode))
		view_grid.add_child(button)
		view_mode_buttons[mode] = button

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
	var subway_check := CheckBox.new()
	subway_check.text = "Subways"
	subway_check.tooltip_text = "Show or hide subways in the underground view."
	subway_check.button_pressed = true
	subway_check.toggled.connect(underground_subways_visibility_requested.emit)
	view_visibility_checks["subways"] = subway_check
	layers_grid.add_child(subway_check)
	_watch_buttons(self)


func group_icon(group_index: int) -> Texture2D:
	if group_index < 0 or group_index >= GROUP_ICON_REGIONS.size():
		return null
	return _toolbar_icon(GROUP_ICON_REGIONS[group_index])


func show_tool_group(
	group_index: int,
	city: CityState,
	icon_provider: Callable = Callable(),
) -> int:
	if group_index < 0 or group_index >= Tools.GROUPS.size():
		return 0
	_current_city = city
	_icon_provider = icon_provider
	for button_index in toolbar_buttons.size():
		toolbar_buttons[button_index].button_pressed = button_index == group_index
	return child_palette.show_tool_group(group_index, city, icon_provider)


func sync_child_tool_selection(group_index: int, subtool_index: int) -> void:
	_selected_subtool = subtool_index
	child_palette.sync_selection(group_index, subtool_index)


func refresh_child_tool_icons(
	group_index: int, icon_provider: Callable
) -> void:
	child_palette.refresh_icons(group_index, icon_provider)


func refresh_tool_availability(
	city: CityState,
	group_index: int,
	selected_subtool: int,
	selected_was_available: bool,
) -> bool:
	return child_palette.refresh_availability(
		city, group_index, selected_subtool, selected_was_available
	)


func tool_button_tooltip(
	group_index: int, subtool_index: int, available: bool
) -> String:
	return child_palette.tool_button_tooltip(
		group_index, subtool_index, available
	)


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
	button.button_down.connect(_begin_group_hold.bind(group_index))
	button.button_up.connect(_end_group_hold)
	button.mouse_exited.connect(_cancel_group_hold)
	button.pressed.connect(_activate_group.bind(group_index))
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


func sync_view_mode(mode: String) -> void:
	for key in view_mode_buttons:
		(view_mode_buttons[key] as CheckBox).set_pressed_no_signal(key == mode)


func _camera_row(parent: VBoxContainer, title: String) -> HBoxContainer:
	# equal side columns center the buttons independently of the left label
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 45
	row.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 3)
	row.add_child(buttons)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size.x = 45
	row.add_child(spacer)
	return buttons


func _begin_group_hold(group_index: int) -> void:
	_hold_generation += 1
	_held_group = group_index
	_hold_opened = false
	if group_index >= 15 or not is_inside_tree():
		return
	get_tree().create_timer(HOLD_SECONDS).timeout.connect(
		_show_held_group.bind(group_index, _hold_generation)
	)


func _end_group_hold() -> void:
	_hold_generation += 1
	_held_group = -1


func _cancel_group_hold() -> void:
	if not _hold_opened:
		_end_group_hold()


func _activate_group(group_index: int) -> void:
	if _hold_opened:
		_hold_opened = false
		return
	hold_menu.hide()
	group_requested.emit(group_index)


func _show_held_group(group_index: int, generation: int) -> void:
	if generation != _hold_generation or _held_group != group_index:
		return
	_hold_opened = true
	group_requested.emit(group_index)
	hold_menu.show_tools(
		group_index, _current_city, _icon_provider, _selected_subtool,
		toolbar_buttons[group_index].get_global_rect()
	)


func set_landscape_editor(enabled: bool) -> void:
	landscape_editor = enabled
	start_city_button.visible = enabled
	child_palette.free_landscape = enabled
	hold_menu.palette.free_landscape = enabled
	for index in toolbar_buttons.size():
		toolbar_buttons[index].visible = not enabled or index in [0, 1, 16, 17]
	view_mode_buttons.underground.disabled = enabled


func _watch_buttons(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(button_clicked.emit):
		node.pressed.connect(button_clicked.emit)
	if not node.child_entered_tree.is_connected(_watch_buttons):
		node.child_entered_tree.connect(_watch_buttons)
	for child in node.get_children():
		_watch_buttons(child)
