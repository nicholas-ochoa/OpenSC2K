class_name CityToolbar
extends Panel

@warning_ignore_start("integer_division")

signal button_clicked
signal brush_changed
signal regenerate_requested
signal start_city_requested

var start_city_button: Button
var landscape_editor := false
var brush_controls: VBoxContainer
var brush_size_input: SpinBox
var brush_shape_input: OptionButton
var _brush_wheel_updated_ms := -50
var landscape_tools: GridContainer
var regenerate_button: Button
var landscape_buttons: Dictionary = {}
const LANDSCAPE_TOOL_ORDER := [
	Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 5), Vector2i(0, 1),
	Vector2i(0, 6), Vector2i(0, 7), Vector2i(1, 1), Vector2i(1, 2),
	Vector2i(1, 0), Vector2i(1, 3), Vector2i(16, 0), Vector2i(17, 0),
]

signal group_requested(index: int)
signal subtool_requested(index: int)
signal rotate_requested(counter_clockwise: bool)
signal zoom_out_requested
signal zoom_in_requested
signal overlay_requested(mode: String)
signal surface_visibility_requested(visible: bool, layer: String)
signal underground_water_mains_visibility_requested(visible: bool)
signal underground_pipes_visibility_requested(visible: bool)
signal underground_subways_visibility_requested(visible: bool)

const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const HoldMenu = preload("res://src/ui/shell/city_tool_hold_menu.gd")
const HOLD_SECONDS := 0.45
const MAP_DISPLAY_MODES := ["city", "underground"]
var data_view_input: OptionButton
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


func _ready() -> void:
	AppUiTheme.bind_frosted_panel(self)
	start_city_button = %StartCityButton
	rotate_counter_clockwise_button = %RotateCounterClockwiseButton
	rotate_clockwise_button = %RotateClockwiseButton
	zoom_out_button = %ZoomOutButton
	zoom_in_button = %ZoomInButton
	child_palette = %ChildPalette
	view_layers_heading = %ViewLayersHeading
	data_view_input = %DataViewInput
	view_mode_buttons = {"city": %CityView, "underground": %UndergroundView, "height": %HeightView}
	view_visibility_checks = {
		"buildings": %BuildingsVisible, "networks": %NetworksVisible,
		"water": %WaterVisible, "trees": %TreesVisible,
		"zones": %ZonesVisible, "signs": %SignsVisible, "vehicles": %VehiclesVisible,
		"water_mains": %WaterMainsVisible, "pipes": %PipesVisible, "subways": %SubwaysVisible,
	}

	hold_menu = HoldMenu.new()
	hold_menu.subtool_requested.connect(subtool_requested.emit)
	add_child(hold_menu)
	move_child(hold_menu, 0)
	start_city_button.pressed.connect(start_city_requested.emit)
	var tool_button_group := ButtonGroup.new()

	for group_index in range(15):
		_add_group_button(%ToolGroups, tool_button_group, group_index)

	for group_index in range(15, 17):
		_add_group_button(%SpecialTools, tool_button_group, group_index)

	_add_group_button(%ZoomButtons, tool_button_group, 17)

	brush_controls = %BrushControls
	brush_size_input = %BrushSizeInput
	brush_shape_input = %BrushShapeInput
	brush_size_input.get_line_edit().set("minimum_character_width", 2)
	landscape_tools = %LandscapeTools
	regenerate_button = %RegenerateTerrainButton
	brush_size_input.value_changed.connect(func(_value: float) -> void: brush_changed.emit())
	brush_shape_input.item_selected.connect(func(_index: int) -> void: brush_changed.emit())
	regenerate_button.pressed.connect(regenerate_requested.emit)
	_refresh_artwork_buttons(self)
	rotate_counter_clockwise_button.pressed.connect(rotate_requested.emit.bind(true))
	rotate_clockwise_button.pressed.connect(rotate_requested.emit.bind(false))
	zoom_out_button.pressed.connect(zoom_out_requested.emit)
	zoom_in_button.pressed.connect(zoom_in_requested.emit)

	child_palette.build()
	child_palette.subtool_requested.connect(subtool_requested.emit)
	active_tool_group_label = child_palette.heading
	child_tool_scroll = child_palette.scroll
	child_tool_grid = child_palette.grid
	child_tool_buttons = child_palette.buttons

	for mode in view_mode_buttons:
		view_mode_buttons[mode].pressed.connect(overlay_requested.emit.bind(mode))

	data_view_input.item_selected.connect(func(index: int) -> void:
		overlay_requested.emit("city" if index == 0 else CityDataView.MODES[index - 1]))

	for layer in ["buildings", "networks", "water", "trees", "zones", "signs", "vehicles"]:
		view_visibility_checks[layer].toggled.connect(_on_surface_visibility_toggled.bind(layer))

	view_visibility_checks.water_mains.toggled.connect(underground_water_mains_visibility_requested.emit)
	view_visibility_checks.pipes.toggled.connect(underground_pipes_visibility_requested.emit)
	view_visibility_checks.subways.toggled.connect(underground_subways_visibility_requested.emit)
	_watch_buttons(self)


func _input(event: InputEvent) -> void:
	if not brush_controls.is_visible_in_tree() or not event is InputEventMouseButton:
		return

	var mouse := event as InputEventMouseButton
	if mouse.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return
	if not brush_size_input.get_global_rect().has_point(mouse.position):
		return

	# consume before spinbox or lineedit handles the wheel a second time
	get_viewport().set_input_as_handled()
	if not mouse.pressed:
		return

	var now := Time.get_ticks_msec()
	if now - _brush_wheel_updated_ms < 50:
		return

	_brush_wheel_updated_ms = now
	brush_size_input.value += 1 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else -1


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

	var selected := child_palette.show_tool_group(group_index, city, icon_provider)
	if landscape_editor:
		child_palette.hide()
		_build_landscape_tools()
	return selected


func sync_child_tool_selection(group_index: int, subtool_index: int) -> void:
	_selected_subtool = subtool_index
	child_palette.sync_selection(group_index, subtool_index)
	for key in landscape_buttons:
		landscape_buttons[key].set_pressed_no_signal(key == Vector2i(group_index, subtool_index))


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
	button.custom_minimum_size = Vector2(32, 32)
	button.toggle_mode = true
	button.button_group = button_group
	button.tooltip_text = Tools.GROUPS[group_index].name
	button.theme_type_variation = "ArtworkButton"
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


func _on_surface_visibility_toggled(visible: bool, layer: String) -> void:
	surface_visibility_requested.emit(visible, layer)


func sync_view_mode(mode: String) -> void:
	if data_view_input != null:
		data_view_input.select(CityDataView.MODES.find(mode) + 1)

	for key in view_mode_buttons:
		(view_mode_buttons[key] as CheckBox).set_pressed_no_signal(key == mode)


func _begin_group_hold(group_index: int) -> void:
	_hold_generation += 1
	_held_group = group_index
	_hold_opened = false

	if (group_index >= 15 and group_index != 16) or not is_inside_tree():
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
	regenerate_button.visible = enabled
	landscape_tools.visible = enabled
	child_palette.visible = not enabled
	hold_menu.hide()
	child_palette.free_landscape = enabled
	hold_menu.palette.free_landscape = enabled

	for index in toolbar_buttons.size():
		toolbar_buttons[index].visible = not enabled

	view_mode_buttons.underground.disabled = enabled
	view_mode_buttons.underground.visible = not enabled
	view_mode_buttons.height.visible = enabled
	data_view_input.visible = not enabled
	%LandscapeSpacer.visible = enabled
	for key in view_visibility_checks:
		view_visibility_checks[key].visible = key in ["water", "trees"] if enabled else key not in ["water_mains", "pipes", "subways"]


func _watch_buttons(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(button_clicked.emit):
		node.pressed.connect(button_clicked.emit)

	if not node.child_entered_tree.is_connected(_watch_buttons):
		node.child_entered_tree.connect(_watch_buttons)

	for child in node.get_children():
		_watch_buttons(child)


func replace_artwork(value: Image) -> void:
	toolbar_art = value

	for index in toolbar_buttons.size():
		toolbar_buttons[index].theme_type_variation = "ArtworkButton"
		toolbar_buttons[index].icon = group_icon(index)
		toolbar_buttons[index].text = str(index + 1) if toolbar_buttons[index].icon == null else ""

	_refresh_artwork_buttons(self)


func _refresh_artwork_buttons(node: Node) -> void:
	if node is Button and node.has_meta("toolbar_region"):
		node.theme_type_variation = "ArtworkButton"
		node.icon = _toolbar_icon(node.get_meta("toolbar_region"))
		node.text = node.tooltip_text.left(1) if node.icon == null else ""

	for child in node.get_children():
		_refresh_artwork_buttons(child)


func _build_landscape_tools() -> void:
	if not landscape_buttons.is_empty():
		return
	var selection := ButtonGroup.new()
	for key in LANDSCAPE_TOOL_ORDER:
		var group: int = key.x
		var tool: int = key.y
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = selection
		button.custom_minimum_size = Vector2(46, 30)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.tooltip_text = str(Tools.GROUPS[group].tools[tool][1])
		button.icon = _icon_provider.call(group, tool) if _icon_provider.is_valid() else null
		if group in [0, 1] and button.icon != null:
			# terrain symbols are 19-pixel native icons, like the city toolbar
			var native_icon := button.icon.get_image()
			native_icon.resize(native_icon.get_width() / 2,
				(native_icon.get_height() / 2), Image.INTERPOLATE_NEAREST)
			button.icon = ImageTexture.create_from_image(native_icon)
		button.text = button.tooltip_text if button.icon == null else ""
		button.theme_type_variation = "ArtworkButton"
		button.pressed.connect(func() -> void:
			group_requested.emit(group)
			subtool_requested.emit(tool))
		landscape_tools.add_child(button)
		landscape_buttons[key] = button
