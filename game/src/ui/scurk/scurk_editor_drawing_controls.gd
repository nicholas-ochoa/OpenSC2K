class_name ScurkEditorDrawingControls
extends PanelContainer

signal view_selected(view: int)
signal zoom_fit_requested
signal zoom_out_requested
signal zoom_in_requested
signal tool_selected(tool: int)
signal rotate_clipboard_clockwise_requested
signal rotate_clipboard_requested
signal flip_clipboard_horizontal_requested
signal flip_clipboard_vertical_requested
signal copy_object_requested
signal paste_image_requested
signal brush_size_changed(value: float)
signal round_brush_changed(enabled: bool)
signal filled_shapes_changed(enabled: bool)
signal grid_visibility_changed(enabled: bool)
signal grid_snap_changed(enabled: bool)
signal grid_width_changed(value: float)
signal grid_height_changed(value: float)
signal clip_region_changed(enabled: bool)
signal clip_enabled_changed(enabled: bool)

const VIEW_LARGE := 0
const VIEW_MEDIUM := 1
const VIEW_SMALL := 2

var view_buttons: Array[Button] = []
var zoom_label: Label
var tool_buttons: Array[Button] = []
var paste_tool_button: Button
var clipboard_action_buttons: Array[Button] = []
var copy_object_button: Button
var paste_image_button: Button
var brush_size_selector: SpinBox
var round_brush_check: CheckBox
var filled_shapes_check: CheckBox
var grid_check: CheckBox
var snap_to_grid_check: CheckBox
var grid_width_selector: SpinBox
var grid_height_selector: SpinBox
var clip_region_check: CheckBox
var zoom_out_button: Button
var zoom_in_button: Button
var clip_enabled_check: CheckBox


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

	for child in $Margin/Column/Tools.get_children():
		var button := child as Button
		button.button_group = tool_group
		button.pressed.connect(tool_selected.emit.bind(tool_buttons.size()))
		tool_buttons.append(button)

	tool_buttons[0].button_pressed = true
	paste_tool_button = tool_buttons[ScurkPixelCanvas.TOOL_PASTE]
	paste_tool_button.disabled = true
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
	grid_check = $"../Editor/Canvas/Footer/Row/GridScroll/Grid/Show"
	grid_check.toggled.connect(grid_visibility_changed.emit)
	snap_to_grid_check = $"../Editor/Canvas/Footer/Row/GridScroll/Grid/Snap"
	snap_to_grid_check.toggled.connect(grid_snap_changed.emit)
	clip_region_check = $"../Editor/Canvas/Footer/Row/GridScroll/Grid/Clip"
	clip_region_check.toggled.connect(clip_region_changed.emit)
	clip_enabled_check = $"../Editor/Canvas/Footer/Row/GridScroll/Grid/Limit"
	clip_enabled_check.toggled.connect(clip_enabled_changed.emit)
	grid_width_selector = $"../Editor/Canvas/Footer/Row/GridScroll/Grid/WidthRow/Width"
	grid_width_selector.value_changed.connect(grid_width_changed.emit)
	grid_height_selector = $"../Editor/Canvas/Footer/Row/GridScroll/Grid/HeightRow/Height"
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
	copy_object_button = $"Margin/Column/Clipboard/CopyObject"
	paste_image_button = $"Margin/Column/Clipboard/PasteImage"
	copy_object_button.pressed.connect(copy_object_requested.emit)
	paste_image_button.pressed.connect(paste_image_requested.emit)
	theme_changed.connect(_refresh_icon_colors)
	_refresh_icon_colors()


func _refresh_icon_colors() -> void:
	for button in tool_buttons + clipboard_action_buttons + [copy_object_button, paste_image_button]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var color_name := "font_color" if state == "normal" else "font_%s_color" % state
			button.add_theme_color_override(
				"icon_%s_color" % state, button.get_theme_color(color_name, "Button")
			)


func update_tool_controls(tool: int) -> void:
	var uses_brush := tool in [
		ScurkPixelCanvas.TOOL_PENCIL, ScurkPixelCanvas.TOOL_ERASER, ScurkPixelCanvas.TOOL_LINE,
		ScurkPixelCanvas.TOOL_DIAMOND, ScurkPixelCanvas.TOOL_LEFT_WALL, ScurkPixelCanvas.TOOL_RIGHT_WALL,
		ScurkPixelCanvas.TOOL_ELLIPSE, ScurkPixelCanvas.TOOL_RECTANGLE,
	]
	$Margin/Column/Brush.visible = uses_brush
	filled_shapes_check.visible = uses_brush and tool not in [
		ScurkPixelCanvas.TOOL_PENCIL, ScurkPixelCanvas.TOOL_ERASER, ScurkPixelCanvas.TOOL_LINE,
	]
