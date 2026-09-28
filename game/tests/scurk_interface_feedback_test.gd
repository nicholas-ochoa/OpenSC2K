extends SceneTree

var clicks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var editor := preload("res://src/ui/scurk/scurk_editor_control.tscn").instantiate() as ScurkEditorControl
	root.add_child(editor)
	editor.toolbar_button_clicked.connect(_clicked)
	ScurkInterfaceFeedback.bind(editor, editor.toolbar_button_clicked.emit)
	var toolbar := editor.get_node("Panel/Content/Toolbar")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(5, 5)
	var key := InputEventKey.new()
	key.keycode = KEY_UP
	key.pressed = true
	var actions: Array[Callable] = [editor.tool_buttons[0].pressed.emit,
		editor.drawing_controls.zoom_in_button.pressed.emit, editor.round_brush_check.pressed.emit,
		editor.brush_size_selector.gui_input.emit.bind(mouse), editor.grid_width_selector.gui_input.emit.bind(key),
		editor.brush_size_selector.get_line_edit().text_submitted.emit.bind("2"),
		toolbar.get_node("Row/Help").get_popup().id_pressed.emit.bind(0),
		editor.studio.tabs.get_tab_bar().tab_clicked.emit.bind(0),
		editor.cycle_colors_check.pressed.emit, editor.increment_cycle_button.pressed.emit,
		editor.canvas_panel.show_views_button.pressed.emit,
		editor.canvas_panel.get_node("Footer/Row/Compare/Mode").get_popup().index_pressed.emit.bind(1),
		editor.dialog_registry.generate_medium.pressed.emit,
		editor.pick_copy_control.get_node("Content/Toolbar/Controls/Large").pressed.emit,
		editor.studio.get_node("Margin/Column/Tabs/History/Actions/Undo").pressed.emit]
	for index in actions.size():
		_expect_click(actions[index], "Editor action %d" % index)

	# Palette gestures include shade ramps and favorites. Programmatic changes do not.
	var palette := editor.palette_panel.palette_control
	_expect_click(palette._gui_input.bind(mouse), "Palette color")
	mouse.shift_pressed = true
	_expect_click(palette._gui_input.bind(mouse), "Palette ramp")
	mouse.shift_pressed = false
	mouse.ctrl_pressed = true
	_expect_click(palette._gui_input.bind(mouse), "Palette favorite")
	mouse.ctrl_pressed = false
	clicks = 0
	editor.brush_size_selector.value = 3
	editor.grid_width_selector.value = 8
	editor.round_brush_check.button_pressed = true
	palette.set_selected_color(3)
	palette.clear_ramp()
	editor.studio.tabs.current_tab = 1
	editor.canvas_panel.get_node("Footer/Row/Compare/Mode").select(0)
	assert(clicks == 0, "Refreshing editor controls must be silent")

	# Texture buttons and object rows are rebuilt after the feedback is bound.
	var textures := editor.palette_panel.texture_control
	textures.set_patterns([PackedInt32Array()])
	_expect_click(textures.buttons[0].pressed.emit, "Rebuilt texture")
	editor.object_list.set_entries([ScurkTileSelector.Entry.new(1001, "Tile", "Group", null)], 1001)
	editor.object_list._rebuild_rows()
	_expect_click(editor.object_list.rows[0].pressed.emit, "New object row")

	# Engine-owned dialog buttons must not also produce a second click.
	var dialog := ConfirmationDialog.new()
	editor.add_child(dialog)
	_expect_click(dialog.get_ok_button().pressed.emit, "Confirm dialog")
	_expect_click(dialog.get_cancel_button().pressed.emit, "Cancel dialog")
	_expect_click(dialog.canceled.emit, "Dismiss dialog")
	var files := FileDialog.new()
	files.access = FileDialog.ACCESS_FILESYSTEM
	files.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	editor.add_child(files)
	var file := FileAccess.open("user://feedback.txt", FileAccess.WRITE)
	file.store_string("Feedback fixture")
	file.close()
	files.current_dir = ProjectSettings.globalize_path("user://")
	files.current_file = "feedback.txt"
	_expect_click(files.get_ok_button().pressed.emit, "Confirm file dialog")
	_expect_click(files.get_cancel_button().pressed.emit, "Cancel file dialog")

	var place := preload("res://src/ui/scurk/scurk_place_print_control.tscn").instantiate() as ScurkPlacePrintControl
	root.add_child(place)
	place.button_clicked.connect(_clicked)
	_expect_click(place.get_node("Panel/Margin/Content/WorkspaceRow/ModeSelector").get_popup().index_pressed.emit.bind(1), "Place mode")
	_expect_click(place.get_node("Panel/Margin/Content/HistoryActions/Close").pressed.emit, "Place close button")
	_expect_click(place.close_requested.emit, "Place close window")
	_expect_click(place.tool_list.gui_input.emit.bind(key), "Tool list keyboard")
	clicks = 0
	place.tool_list.select(0)
	assert(clicks == 0, "Programmatic tool selection must be silent")

	var print_dialog := preload("res://src/ui/scurk/scurk_print_control.tscn").instantiate() as ScurkPrintControl
	root.add_child(print_dialog)
	print_dialog.button_clicked.connect(_clicked)
	_expect_click(print_dialog.buildings_check.pressed.emit, "Print layer")
	_expect_click(print_dialog.magnification_selector.get_popup().index_pressed.emit.bind(1), "Print magnification")
	_expect_click(print_dialog.select_all_button.pressed.emit, "Select all pages")
	print_dialog.preview.set_entire_city(false)
	_expect_click(print_dialog.preview._gui_input.bind(mouse), "Select page")
	clicks = 0
	print_dialog.configure("City")
	print_dialog.preview.set_magnification(1)
	print_dialog.preview.select_all()
	assert(clicks == 0, "Refreshing print options must be silent")

	# Lists use input, since Tree.select also emits item_selected during refresh.
	var tree := Tree.new()
	editor.add_child(tree)
	var item := tree.create_item()
	_expect_click(tree.gui_input.emit.bind(key), "Layer tree keyboard")
	clicks = 0
	item.select(0)
	assert(clicks == 0, "Programmatic layer selection must be silent")
	editor.queue_free()
	place.queue_free()
	print_dialog.queue_free()
	await process_frame
	print("PASS: SCURK controls, menus, dialogs, dynamic buttons and silent state refreshes")
	quit()


func _clicked() -> void:
	clicks += 1


func _expect_click(action: Callable, label: String) -> void:
	clicks = 0
	action.call()
	assert(clicks == 1, "%s: expected one click, got %d" % [label, clicks])
