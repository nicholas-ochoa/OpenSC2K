class_name ScurkEditorDrawingControls
extends PanelContainer

signal button_clicked
signal view_selected(view: int)
signal zoom_fit_requested
signal zoom_out_requested
signal zoom_in_requested
signal tool_selected(tool: int)
signal rotate_clipboard_clockwise_requested
signal rotate_clipboard_requested
signal flip_clipboard_horizontal_requested
signal flip_clipboard_vertical_requested
signal brush_size_changed(value: float)
signal round_brush_changed(enabled: bool)
signal filled_shapes_changed(enabled: bool)
signal isometric_guides_changed
signal grid_visibility_changed(enabled: bool)
signal grid_snap_changed(enabled: bool)
signal line_snap_changed(enabled: bool)
signal transparency_lock_changed(enabled: bool)
signal pixel_perfect_changed(enabled: bool)
signal grid_width_changed(value: float)
signal grid_height_changed(value: float)

const VIEW_LARGE := ScurkSpriteIds.View.LARGE
const VIEW_MEDIUM := ScurkSpriteIds.View.MEDIUM
const VIEW_SMALL := ScurkSpriteIds.View.SMALL

var view_buttons: Array[Button] = []
var zoom_label: Label
var tool_buttons: Array[Button] = []
var clipboard_action_buttons: Array[Button] = []
var brush_size_selector: SpinBox
var round_brush_check: CheckBox
var filled_shapes_check: CheckBox
var grid_check: CheckBox
var snap_to_grid_check: CheckBox
var grid_width_selector: SpinBox
var grid_height_selector: SpinBox
var zoom_out_button: Button
var zoom_in_button: Button


func _ready() -> void:
	AppUiTheme.bind_frosted_panel(self)
	build()


func build() -> void:
	if zoom_label != null:
		return

	var view_group := ButtonGroup.new()

	for view in ["Large", "Medium", "Small"]:
		var button := get_node("Margin/Column/Sizes/" + view) as Button
		button.button_group = view_group
		button.pressed.connect(view_selected.emit.bind(view_buttons.size()))
		view_buttons.append(button)

	view_buttons[0].button_pressed = true

	var tool_group := ButtonGroup.new()

	var names := ["Pencil", "Eraser", "Line", "Diamond", "LeftWall", "RightWall", "Ellipse", "Rectangle",
		"Fill", "Eyedropper", "SelectRect", "SelectLasso", "SelectWand", "Move", "Shade", "Stamp"]
	for index in names.size():
		var group := "Selection" if index in range(10, 14) else "Tools"
		var button := get_node("Margin/Column/" + group + "/" + names[index]) as Button
		button.button_group = tool_group
		button.pressed.connect(tool_selected.emit.bind(index))
		tool_buttons.append(button)

	tool_buttons[0].button_pressed = true
	zoom_label = $Margin/Column/Zoom/Value
	zoom_out_button = $Margin/Column/Zoom/Out
	zoom_in_button = $Margin/Column/Zoom/In
	zoom_out_button.pressed.connect(zoom_out_requested.emit)
	zoom_in_button.pressed.connect(zoom_in_requested.emit)
	$Margin/Column/Fit.pressed.connect(zoom_fit_requested.emit)
	brush_size_selector = $Margin/Column/Brush/SizeRow/Size
	brush_size_selector.max_value = ScurkPixelCanvas.MAX_BRUSH_SIZE
	brush_size_selector.value_changed.connect(brush_size_changed.emit)
	round_brush_check = $Margin/Column/Brush/Round
	round_brush_check.toggled.connect(round_brush_changed.emit)
	filled_shapes_check = $Margin/Column/Brush/Filled
	filled_shapes_check.toggled.connect(filled_shapes_changed.emit)
	grid_check = $Margin/Column/Grid/Show
	grid_check.toggled.connect(grid_visibility_changed.emit)
	grid_check.toggled.connect(func(enabled: bool) -> void: $Margin/Column/Grid/Dimensions.visible = enabled)
	snap_to_grid_check = $Margin/Column/Brush/Snap
	snap_to_grid_check.toggled.connect(grid_snap_changed.emit)
	$Margin/Column/Brush/SnapLines.toggled.connect(line_snap_changed.emit)
	$Margin/Column/Paint/Lock.toggled.connect(transparency_lock_changed.emit)
	$Margin/Column/Paint/Perfect.toggled.connect(pixel_perfect_changed.emit)
	grid_width_selector = $Margin/Column/Grid/Dimensions/WidthRow/Width
	grid_width_selector.get_line_edit().set("minimum_character_width", 2)
	grid_width_selector.value_changed.connect(grid_width_changed.emit)
	grid_height_selector = $Margin/Column/Grid/Dimensions/HeightRow/Height
	grid_height_selector.get_line_edit().set("minimum_character_width", 2)
	grid_height_selector.value_changed.connect(grid_height_changed.emit)
	$"Margin/Column/Clipboard/RotateCW".pressed.connect(rotate_clipboard_clockwise_requested.emit)
	$"Margin/Column/Clipboard/RotateCW".disabled = true
	clipboard_action_buttons.append($"Margin/Column/Clipboard/RotateCW")
	$"Margin/Column/Clipboard/Rotate".pressed.connect(rotate_clipboard_requested.emit)
	$"Margin/Column/Clipboard/Rotate".disabled = true
	clipboard_action_buttons.append($"Margin/Column/Clipboard/Rotate")
	$"Margin/Column/Clipboard/Horizontal".pressed.connect(flip_clipboard_horizontal_requested.emit)
	$"Margin/Column/Clipboard/Horizontal".disabled = true
	clipboard_action_buttons.append($"Margin/Column/Clipboard/Horizontal")
	$"Margin/Column/Clipboard/Vertical".pressed.connect(flip_clipboard_vertical_requested.emit)
	$"Margin/Column/Clipboard/Vertical".disabled = true
	clipboard_action_buttons.append($"Margin/Column/Clipboard/Vertical")
	$Margin/Column/Isometric/Guides.toggled.connect(func(enabled: bool) -> void:
		$Margin/Column/Isometric/GuideFields.visible = enabled
		isometric_guides_changed.emit())
	for field in ["Spacing", "OffsetX", "OffsetY"]:
		get_node("Margin/Column/Isometric/GuideFields/" + field).value_changed.connect(func(_value: float) -> void:
			isometric_guides_changed.emit())
	_watch_buttons(self)
	theme_changed.connect(_refresh_icon_colors)
	_refresh_icon_colors()


func _refresh_icon_colors() -> void:
	for button in tool_buttons + clipboard_action_buttons:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var color_name := "font_color" if state == "normal" else "font_%s_color" % state
			button.add_theme_color_override(
				"icon_%s_color" % state, button.get_theme_color(color_name, "Button")
			)


func update_tool_controls(tool: int, brush_size := 1, paste_active := false, paste_new_layer := false) -> void:
	var uses_brush := tool in [
		ScurkPixelCanvas.TOOL_PENCIL, ScurkPixelCanvas.TOOL_ERASER, ScurkPixelCanvas.TOOL_LINE,
		ScurkPixelCanvas.TOOL_DIAMOND, ScurkPixelCanvas.TOOL_LEFT_WALL, ScurkPixelCanvas.TOOL_RIGHT_WALL,
		ScurkPixelCanvas.TOOL_ELLIPSE, ScurkPixelCanvas.TOOL_RECTANGLE,
		ScurkPixelCanvas.TOOL_SHADE,
	]
	$Margin/Column/Brush.visible = uses_brush
	$Margin/Column/Brush/Snap.visible = ScurkPixelCanvas.is_shape_tool(tool)
	$Margin/Column/Paint/Lock.visible = not paste_new_layer and (paste_active or tool not in [ScurkPixelCanvas.TOOL_EYEDROPPER, ScurkPixelCanvas.TOOL_SHADE])
	$Margin/Column/Paint/Perfect.visible = tool == ScurkPixelCanvas.TOOL_PENCIL and brush_size == 1 and not paste_active
	$Margin/Column/Paint/RampHint.visible = tool == ScurkPixelCanvas.TOOL_SHADE and not paste_active
	$Margin/Column/Brush/SnapLines.visible = tool == ScurkPixelCanvas.TOOL_LINE
	filled_shapes_check.visible = uses_brush and tool not in [
		ScurkPixelCanvas.TOOL_PENCIL, ScurkPixelCanvas.TOOL_ERASER, ScurkPixelCanvas.TOOL_LINE,
		ScurkPixelCanvas.TOOL_SHADE, ScurkPixelCanvas.TOOL_STAMP,
	]


func _watch_buttons(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(button_clicked.emit)

	for child in node.get_children():
		_watch_buttons(child)
