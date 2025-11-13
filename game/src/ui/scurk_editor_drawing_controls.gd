class_name ScurkEditorDrawingControls
extends VBoxContainer

signal view_selected(view: int)
signal zoom_out_requested
signal zoom_in_requested
signal tool_selected(tool: int)
signal rotate_clipboard_requested
signal flip_clipboard_horizontal_requested
signal flip_clipboard_vertical_requested
signal copy_object_requested
signal paste_image_requested
signal brush_size_selected(index: int)
signal round_brush_changed(enabled: bool)
signal filled_shapes_changed(enabled: bool)
signal grid_visibility_changed(enabled: bool)
signal grid_snap_changed(enabled: bool)
signal grid_width_changed(value: float)
signal grid_height_changed(value: float)
signal clip_region_changed(enabled: bool)
signal cycle_colors_changed(enabled: bool)
signal increment_cycle_requested

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
var brush_size_selector: OptionButton
var round_brush_check: CheckBox
var filled_shapes_check: CheckBox
var grid_check: CheckBox
var snap_to_grid_check: CheckBox
var grid_width_selector: SpinBox
var grid_height_selector: SpinBox
var clip_region_check: CheckBox
var cycle_colors_check: CheckBox
var increment_cycle_button: Button


func _ready() -> void:
	build()


func build() -> void:
	if zoom_label != null:
		return
	add_theme_constant_override("separation", 5)
	_build_view_row()
	_build_tool_row()
	_build_clipboard_rows()
	_build_brush_row()
	_build_grid_row()
	_build_cycle_row()


func _build_view_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var group := ButtonGroup.new()
	for view_data in [
		["Large", VIEW_LARGE],
		["Medium", VIEW_MEDIUM],
		["Small", VIEW_SMALL],
	]:
		var button := Button.new()
		button.text = view_data[0]
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(
			emit_signal.bind(&"view_selected", int(view_data[1]))
		)
		row.add_child(button)
		view_buttons.append(button)
	view_buttons[0].button_pressed = true
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_button(
		"-", &"zoom_out_requested", "Reduce the pixel zoom."
	))
	zoom_label = Label.new()
	zoom_label.text = "4x"
	zoom_label.custom_minimum_size = Vector2(34, 0)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(zoom_label)
	row.add_child(_button(
		"+", &"zoom_in_requested", "Increase the pixel zoom."
	))


func _build_tool_row() -> void:
	var row := HFlowContainer.new()
	row.custom_minimum_size = Vector2(0, 62)
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	add_child(row)
	var group := ButtonGroup.new()
	for tool_data in [
		["Pencil", ScurkPixelCanvas.TOOL_PENCIL],
		["Eraser", ScurkPixelCanvas.TOOL_ERASER],
		["Line", ScurkPixelCanvas.TOOL_LINE],
		["Diamond", ScurkPixelCanvas.TOOL_DIAMOND],
		["Left Wall", ScurkPixelCanvas.TOOL_LEFT_WALL],
		["Right Wall", ScurkPixelCanvas.TOOL_RIGHT_WALL],
		["Ellipse", ScurkPixelCanvas.TOOL_ELLIPSE],
		["Box", ScurkPixelCanvas.TOOL_RECTANGLE],
		["Fill", ScurkPixelCanvas.TOOL_FILL],
		["Pick", ScurkPixelCanvas.TOOL_EYEDROPPER],
		["Copy", ScurkPixelCanvas.TOOL_COPY],
		["Paste", ScurkPixelCanvas.TOOL_PASTE],
	]:
		var button := Button.new()
		button.text = tool_data[0]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 28)
		button.pressed.connect(
			emit_signal.bind(&"tool_selected", int(tool_data[1]))
		)
		row.add_child(button)
		tool_buttons.append(button)
		if int(tool_data[1]) == ScurkPixelCanvas.TOOL_PASTE:
			paste_tool_button = button
			paste_tool_button.disabled = true
	tool_buttons[0].button_pressed = true


func _build_clipboard_rows() -> void:
	var scurk_row := HBoxContainer.new()
	scurk_row.add_theme_constant_override("separation", 5)
	add_child(scurk_row)
	var scurk_label := Label.new()
	scurk_label.text = "SCURK Clipboard"
	scurk_row.add_child(scurk_label)
	for action_data in [
		[
			"Rotate CCW",
			&"rotate_clipboard_requested",
			"Rotate the copied pixels 90 degrees counter-clockwise.",
		],
		[
			"Flip Horizontal",
			&"flip_clipboard_horizontal_requested",
			"Flip the copied pixels from left to right.",
		],
		[
			"Flip Vertical",
			&"flip_clipboard_vertical_requested",
			"Flip the copied pixels from top to bottom.",
		],
	]:
		var action_button := _button(
			action_data[0], action_data[1], action_data[2]
		)
		action_button.disabled = true
		scurk_row.add_child(action_button)
		clipboard_action_buttons.append(action_button)

	var system_row := HBoxContainer.new()
	system_row.add_theme_constant_override("separation", 5)
	add_child(system_row)
	var system_label := Label.new()
	system_label.text = "System Clipboard"
	system_row.add_child(system_label)
	copy_object_button = _button(
		"Copy Object",
		&"copy_object_requested",
		"Copy the complete active object view for use in another graphics program.",
	)
	system_row.add_child(copy_object_button)
	paste_image_button = _button(
		"Paste Image",
		&"paste_image_requested",
		"Replace the active object view with the system clipboard image.",
	)
	system_row.add_child(paste_image_button)


func _build_brush_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	var label := Label.new()
	label.text = "Brush"
	row.add_child(label)
	brush_size_selector = OptionButton.new()
	for size_value in range(1, 7):
		brush_size_selector.add_item("%d px" % size_value, size_value)
	brush_size_selector.item_selected.connect(brush_size_selected.emit)
	row.add_child(brush_size_selector)
	round_brush_check = CheckBox.new()
	round_brush_check.text = "Round 5–6 px"
	round_brush_check.tooltip_text = (
		"Soften the corners of the five- and six-pixel brushes."
	)
	round_brush_check.toggled.connect(round_brush_changed.emit)
	row.add_child(round_brush_check)
	filled_shapes_check = CheckBox.new()
	filled_shapes_check.text = "Filled shapes"
	filled_shapes_check.toggled.connect(filled_shapes_changed.emit)
	row.add_child(filled_shapes_check)


func _build_grid_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	var label := Label.new()
	label.text = "Drawing Grid"
	row.add_child(label)
	grid_check = CheckBox.new()
	grid_check.text = "Show"
	grid_check.button_pressed = true
	grid_check.toggled.connect(grid_visibility_changed.emit)
	row.add_child(grid_check)
	snap_to_grid_check = CheckBox.new()
	snap_to_grid_check.text = "Snap shapes"
	snap_to_grid_check.tooltip_text = (
		"Snap shape start and end points to the nearest drawing-grid line."
	)
	snap_to_grid_check.toggled.connect(grid_snap_changed.emit)
	row.add_child(snap_to_grid_check)
	var width_label := Label.new()
	width_label.text = "Width"
	row.add_child(width_label)
	grid_width_selector = _grid_size_selector()
	grid_width_selector.value_changed.connect(grid_width_changed.emit)
	row.add_child(grid_width_selector)
	var height_label := Label.new()
	height_label.text = "Height"
	row.add_child(height_label)
	grid_height_selector = _grid_size_selector()
	grid_height_selector.value_changed.connect(grid_height_changed.emit)
	row.add_child(grid_height_selector)
	clip_region_check = CheckBox.new()
	clip_region_check.text = "Clip Region"
	clip_region_check.tooltip_text = (
		"Show the original object base and height limit. Clipping is always active."
	)
	clip_region_check.toggled.connect(clip_region_changed.emit)
	row.add_child(clip_region_check)


func _build_cycle_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	cycle_colors_check = CheckBox.new()
	cycle_colors_check.text = "Cycle Colors"
	cycle_colors_check.button_pressed = true
	cycle_colors_check.tooltip_text = (
		"Animate cycling palette indices in Paint the Town."
	)
	cycle_colors_check.toggled.connect(cycle_colors_changed.emit)
	row.add_child(cycle_colors_check)
	increment_cycle_button = _button(
		"Increment Cycle",
		&"increment_cycle_requested",
		"Advance the Paint the Town color cycle by one step.",
	)
	increment_cycle_button.disabled = true
	row.add_child(increment_cycle_button)


func _button(label: String, signal_name: StringName, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 30)
	button.pressed.connect(emit_signal.bind(signal_name))
	return button


func _grid_size_selector() -> SpinBox:
	var selector := SpinBox.new()
	selector.min_value = 1
	selector.max_value = 65
	selector.step = 1
	selector.value = 1
	selector.allow_greater = false
	selector.allow_lesser = false
	selector.custom_minimum_size = Vector2(66, 0)
	return selector
