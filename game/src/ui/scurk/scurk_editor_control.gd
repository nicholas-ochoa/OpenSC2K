class_name ScurkEditorControl
extends ColorRect

@warning_ignore_start("integer_division")

signal toolbar_button_clicked
signal about_requested
signal settings_requested
signal close_requested
signal tile_set_applied(tile_set: ScurkMif, display_name: String, source_path: String)
signal place_print_requested

const Mif = preload("res://src/assets/scurk_mif.gd")
const IndexedBitmap = preload("res://src/assets/indexed_bmp.gd")
const SystemImageClipboard = preload("res://src/platform/image_clipboard.gd")
const PickCopy = preload("res://src/tools/scurk/scurk_pick_copy.gd")
const DrawingWorkspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")
const EditorHistory = preload("res://src/tools/scurk/scurk_editor_history.gd")
const EditorRules = preload("res://src/tools/scurk/scurk_editor_rules.gd")
const ToolbarView = preload("res://src/ui/scurk/scurk_editor_toolbar.gd")
const DialogsView = preload("res://src/ui/scurk/scurk_editor_dialogs.gd")
const ObjectPanelView = preload("res://src/ui/scurk/scurk_editor_object_panel.gd")
const DrawingControlsView = preload("res://src/ui/scurk/scurk_editor_drawing_controls.gd")
const CanvasPanelView = preload("res://src/ui/scurk/scurk_editor_canvas_panel.gd")
const PalettePanelView = preload("res://src/ui/scurk/scurk_editor_palette_panel.gd")

class Result extends ScurkMif.Result:
	var path := ""

	static func rejected(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result


const VIEW_LARGE := 0
const VIEW_MEDIUM := 1
const VIEW_SMALL := 2

var studio: ScurkEditorStudio
var palette: Sc2Palette
var base_large_sprites: Sc2SpriteArchive
var base_small_medium_sprites: Sc2SpriteArchive
var reference_directory := ""
var tile_set: ScurkMif
var source_path := ""
var current_large_id := -1
var current_view := VIEW_LARGE
var current_tool := ScurkPixelCanvas.TOOL_PENCIL
var foreground_palette_index := 0
var background_palette_index := 255
var pending_discard_action := ""
var edit_history: ScurkEditorHistory = EditorHistory.new()
var undo_stack: Array[ScurkEditorHistory.Record]:
	get:
		return edit_history.undo_stack
var redo_stack: Array[ScurkEditorHistory.Record]:
	get:
		return edit_history.redo_stack
var dirty: bool:
	get:
		return edit_history.dirty or (studio != null and studio.modified)
var active_workspace := false
var active_base_width := 0
var view_preview_signatures := PackedStringArray(["", "", ""])

var pointer_status_label: Label
var unclipped_tiles: Dictionary[int, bool] = {}
var pending_export_view := 0
var tile_thumbnails: Dictionary[int, Texture2D] = {}
var thumbnail_signatures: Dictionary[int, int] = {}
var source_label: Label
var object_search: LineEdit
var object_list: OptionButton
var name_edit: LineEdit
var name_button: Button
var revert_name_button: Button
var object_panel: ScurkEditorObjectPanel
var view_buttons: Array[Button] = []
var tool_buttons: Array[Button] = []
var clipboard_action_buttons: Array[Button] = []
var clipboard_copy_button: Button
var clipboard_paste_button: Button
var undo_button: Button
var redo_button: Button
var revert_button: Button
var clear_object_button: Button
var save_button: Button
var pixel_canvas: ScurkPixelCanvas
var view_previews: Array[ScurkViewPreview] = []
var view_preview_panels: Array[Control] = []
var palette_panel: ScurkEditorPalettePanel
var brush_size_selector: SpinBox
var filled_shapes_check: CheckBox
var round_brush_check: CheckBox
var grid_check: CheckBox
var snap_to_grid_check: CheckBox
var grid_width_selector: SpinBox
var grid_height_selector: SpinBox
var clip_region_check: CheckBox
var cycle_colors_check: CheckBox
var increment_cycle_button: Button
var drawing_controls: ScurkEditorDrawingControls
var canvas_panel: ScurkEditorCanvasPanel
var zoom_label: Label
var sprite_status_label: Label
var status_label: Label
var open_dialog: FileDialog
var save_dialog: FileDialog
var import_bmp_dialog: FileDialog
var export_bmp_dialog: FileDialog
var discard_dialog: ConfirmationDialog
var error_dialog: AcceptDialog
var pick_copy_control: ScurkPickCopyControl
var dialog_registry: ScurkEditorDialogs


func _init() -> void:
	# set the theme before the scene children build their controls
	theme = AppUiTheme.current()


func _ready() -> void:
	AppUiTheme.bind_canvas(self)
	hide()
	_bind_interface()


func configure(
	value_palette: Sc2Palette,
	value_large_sprites: Sc2SpriteArchive,
	value_small_medium_sprites: Sc2SpriteArchive,
	value_reference_directory: String,
	value_scurk_graphics: ScurkGraphics = null,
) -> void:
	tile_thumbnails.clear()
	thumbnail_signatures.clear()
	palette = value_palette
	base_large_sprites = value_large_sprites
	base_small_medium_sprites = value_small_medium_sprites
	reference_directory = value_reference_directory.simplify_path()

	if pixel_canvas != null and value_scurk_graphics != null:
		pixel_canvas.set_drawing_graphics(value_scurk_graphics)
	elif pixel_canvas != null:
		pixel_canvas.set_drawing_graphics(null)
		_set_status("Using built-in texture patterns and a transparent drawing background.")

	if palette_panel != null and pixel_canvas != null:
		palette_panel.configure(
			palette,
			pixel_canvas.texture_patterns,
			foreground_palette_index, background_palette_index,
			value_scurk_graphics.pattern_names if value_scurk_graphics != null else PackedStringArray(),
		)
		_select_palette_index(foreground_palette_index, false)
		_select_palette_index(background_palette_index, true)

	if pick_copy_control != null:
		pick_copy_control.configure(
			palette, base_large_sprites, base_small_medium_sprites, reference_directory
		)

	if tile_set != null:
		_refresh_object_list()
		_refresh_sprite()


func show_editor(initial_path := "") -> Result:
	if tile_set == null:
		var path := initial_path

		if path.is_empty():
			path = reference_directory.path_join("SCURKART/ORIGINAL.MIF")

		var loaded := load_path(path)

		if not loaded.ok:
			return loaded

	show()
	studio.check_recovery.call_deferred()
	move_to_front()
	_refresh_sprite()
	_fit_canvas_after_layout()

	if object_list != null:
		object_list.grab_focus()

	var outcome := Result.new()
	outcome.ok = true
	outcome.error = ""

	return outcome


func load_path(path: String) -> Result:
	if path.get_extension().to_lower() == "scurk":
		var outcome := Result.new()
		outcome.ok = studio.load_project(path)
		outcome.error = "" if outcome.ok else "Cannot open the SCURK project."
		return outcome
	var loaded := Mif.load_path(path)

	if not loaded.is_valid():
		return Result.rejected(loaded.parse_error)

	return load_tile_set(loaded, path)


func load_tile_set(loaded: ScurkMif, path := "") -> Result:
	if loaded == null or not loaded.is_valid():
		return Result.rejected("The SCURK tile set is invalid.")

	var encoded := loaded.to_bytes()

	if not encoded.ok:
		return Result.rejected(encoded.error)

	tile_thumbnails.clear()
	thumbnail_signatures.clear()
	tile_set = loaded
	studio.reset(encoded.bytes)
	unclipped_tiles.clear()
	view_preview_signatures.fill("")
	source_path = ProjectSettings.globalize_path(path).simplify_path() if not path.is_empty() else ""
	edit_history.reset(encoded.bytes)
	var ids := editable_large_sprite_ids(tile_set, base_large_sprites)
	current_large_id = ids[0] if not ids.is_empty() else -1
	current_view = VIEW_LARGE
	studio.restore_editor_state()
	_refresh_object_list()
	_capture_object_start()
	_refresh_sprite()
	_update_history_buttons()
	_update_title()
	_set_status(
		"Loaded %s: %d objects and %d names."
		% [source_path.get_file() if not source_path.is_empty() else "the active graphics set", ids.size(), tile_set.names.size()]
	)

	if pick_copy_control != null and pick_copy_control.visible:
		pick_copy_control.open_with_working(tile_set, source_path)

	var outcome := Result.new()
	outcome.ok = true
	outcome.error = ""

	return outcome


func save_path(path: String) -> Result:
	if tile_set == null or not tile_set.is_valid():
		return Result.rejected("No valid SCURK tile set is loaded.")

	var output_path := ProjectSettings.globalize_path(path).simplify_path()

	if output_path.get_extension().to_lower() != "mif":
		output_path += ".MIF"

	if path_is_within(output_path, reference_directory):
		return Result.rejected("The original game data folder is read-only. Use another folder.")

	var parent := output_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent)

	if directory_error != OK:
		return Result.rejected("Cannot create the output directory: %s" % error_string(directory_error))

	var saved := tile_set.save_path(output_path)

	if not saved.ok:
		return Result.rejected(saved.error)

	var encoded := tile_set.to_bytes()

	if not encoded.ok:
		return Result.rejected(encoded.error)

	source_path = output_path
	edit_history.mark_saved(encoded.bytes)
	_update_title()

	if pick_copy_control != null and pick_copy_control.visible:
		pick_copy_control.open_with_working(tile_set, source_path)

	_set_status("Saved %s." % source_path.get_file())

	var outcome := Result.new()
	outcome.ok = true
	outcome.error = ""
	outcome.path = source_path

	return outcome


func request_close() -> void:
	if dirty:
		pending_discard_action = "close"
		discard_dialog.dialog_text = "Discard the unsaved SCURK changes?"
		discard_dialog.popup_centered()

		return

	hide()
	close_requested.emit()


func request_open() -> void:
	if dirty:
		pending_discard_action = "open"
		discard_dialog.dialog_text = "Discard the unsaved SCURK changes and open another tile set?"
		discard_dialog.popup_centered()

		return

	_popup_open_dialog()


func request_save() -> void:
	studio.request_save()


func request_save_tile_set() -> void:
	if source_path.is_empty() or path_is_within(source_path, reference_directory):
		request_save_as()

		return

	var result := save_path(source_path)

	if not result.ok:
		_show_error(result.error)


func request_save_as() -> void:
	var output_directory := ProjectSettings.globalize_path("user://tile_sets")
	DirAccess.make_dir_recursive_absolute(output_directory)
	save_dialog.current_dir = output_directory
	var proposed := source_path.get_file()

	if proposed.is_empty() or path_is_within(source_path, reference_directory):
		proposed = "CUSTOM.MIF"

	save_dialog.current_file = proposed
	save_dialog.popup_centered_ratio(0.75)


func request_import_bmp() -> void:
	if tile_set == null or current_large_id < 0:
		return

	var start_directory := source_path.get_base_dir()

	if not DirAccess.dir_exists_absolute(start_directory):
		start_directory = reference_directory.path_join("SCURKART")

	if DirAccess.dir_exists_absolute(start_directory):
		import_bmp_dialog.current_dir = start_directory

	import_bmp_dialog.popup_centered_ratio(0.75)


func request_export_bmp() -> void:
	if tile_set == null or current_large_id < 0:
		return

	for view in 3:
		dialog_registry.export_view.set_item_disabled(view, not _view_is_available(view))
	dialog_registry.export_view.select(current_view)
	dialog_registry.export_options.popup_centered()


func _show_export_file_dialog() -> void:
	dialog_registry.export_options.hide()
	pending_export_view = dialog_registry.export_view.selected
	if pixel_canvas == null or pixel_canvas.sprite_width <= 0:
		return

	var output_directory := ProjectSettings.globalize_path("user://scurk_exports")
	DirAccess.make_dir_recursive_absolute(output_directory)
	export_bmp_dialog.current_dir = output_directory
	var view_name: String = ["LARGE", "MEDIUM", "SMALL"][pending_export_view]
	export_bmp_dialog.current_file = "OBJECT_%03d_%s.png" % [
		object_tile_id(current_large_id), view_name,
	]
	export_bmp_dialog.popup_centered_ratio(0.75)


func import_bmp_path(path: String) -> Result:
	return import_image_path(path)


func import_image_path(path: String) -> Result:
	if tile_set == null or current_large_id < 0:
		return Result.rejected("No SCURK object is selected.")

	var imported := ScurkImageImport.load_path(path, palette)

	if not imported.ok:
		return Result.rejected(imported.error)

	if imported.width > 128 or imported.height > 256:
		return Result.rejected("SCURK graphics cannot be larger than 128 by 256 pixels.")

	return _replace_active_view(
		imported.width,
		imported.height,
		imported.pixels,
		"Imported %s" % path.get_file(),
		imported.remapped_color_count
	)


func export_image_path(path: String, view := -1) -> Result:
	if pixel_canvas == null or pixel_canvas.sprite_width <= 0:
		return Result.rejected("No SCURK sprite is available to export.")

	var output_path := ProjectSettings.globalize_path(path).simplify_path()

	if output_path.get_extension().is_empty():
		output_path += ".gif" if export_bmp_dialog.current_filter == 1 else ".png"

	if path_is_within(output_path, reference_directory):
		return Result.rejected("The original game data folder is read-only. Use another folder.")

	var shape := _active_output_shape() if view < 0 else _output_shape_for_view(view)

	if not shape.ok:
		return Result.rejected(shape.error)

	var encoded: AssetBytesResult

	match output_path.get_extension().to_lower():
		"png":
			encoded = IndexedPng.encode(shape.width, shape.height, shape.pixels, palette)
		"gif":
			encoded = IndexedGif.encode_cycle(shape.width, shape.height, shape.pixels, palette)
		_:
			return Result.rejected("Choose PNG or GIF as the image format.")

	if not encoded.ok:
		return Result.rejected(encoded.error)

	var error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())

	if error != OK:
		return Result.rejected("Cannot create the export folder.")

	var file := FileAccess.open(output_path, FileAccess.WRITE)

	if file == null:
		return Result.rejected("Cannot open the export file.")

	file.store_buffer(encoded.bytes)
	error = file.get_error()
	file.close()

	if error != OK:
		return Result.rejected("Cannot write the export file.")

	_set_status("Exported image to %s." % output_path.get_file())

	var outcome := Result.new()
	outcome.ok = true
	outcome.error = ""
	outcome.path = output_path

	return outcome


func export_bmp_path(path: String) -> Result:
	if pixel_canvas == null or pixel_canvas.sprite_width <= 0:
		return Result.rejected("No SCURK sprite is available to export.")

	var output_path := ProjectSettings.globalize_path(path).simplify_path()

	if output_path.get_extension().to_lower() != "bmp":
		output_path += ".BMP"

	if path_is_within(output_path, reference_directory):
		return Result.rejected("The original game data folder is read-only. Use another folder.")

	var directory_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())

	if directory_error != OK:
		return Result.rejected("Cannot create the output directory: %s" % error_string(directory_error))

	var active_shape := _active_output_shape()

	if not active_shape.ok:
		return Result.rejected(active_shape.error)

	var result := IndexedBitmap.save_path(
		output_path,
		active_shape.width,
		active_shape.height,
		active_shape.pixels,
		palette
	)

	if not result.ok:
		return Result.rejected(result.error)

	_set_status("Exported sprite %d to %s." % [
		view_sprite_id(current_large_id, current_view), output_path.get_file(),
	])

	var outcome := Result.new()
	outcome.ok = true
	outcome.error = ""
	outcome.path = output_path

	return outcome


func copy_object_to_system_clipboard() -> void:
	if pixel_canvas == null or pixel_canvas.sprite_width <= 0:
		return

	var active_shape := _active_output_shape()

	if not active_shape.ok:
		_show_error(active_shape.error)

		return

	var result := SystemImageClipboard.copy_indexed(
		active_shape.width,
		active_shape.height,
		active_shape.pixels,
		palette
	)

	if not result.ok:
		_show_error(result.error)

		return

	_set_status(
		"Copied sprite %d to the system clipboard."
		% view_sprite_id(current_large_id, current_view)
	)


func paste_image_from_system_clipboard() -> void:
	if tile_set == null or current_large_id < 0:
		return

	var imported := SystemImageClipboard.paste_indexed(palette)

	if not imported.ok:
		_show_error(imported.error)

		return

	if imported.width > 128 or imported.height > 256:
		_show_error("SCURK graphics cannot be larger than 128 by 256 pixels.")

		return

	var result := _replace_active_view(
		imported.width,
		imported.height,
		imported.pixels,
		"Pasted the system clipboard image",
		imported.remapped_color_count
	)

	if not result.ok:
		_show_error(result.error)


func request_pick_copy() -> void:
	if tile_set == null or not tile_set.is_valid():
		_show_error("No valid SCURK working object set is loaded.")

		return

	pick_copy_control.open_with_working(tile_set, source_path)


func _copy_pick_objects(
	source: ScurkMif, large_ids: PackedInt32Array, description: String
) -> void:
	if tile_set == null:
		return

	var encoded := tile_set.to_bytes()

	if not encoded.ok:
		pick_copy_control.copy_completed(ScurkPickCopy._failure(encoded.error))

		return

	studio.capture()
	edit_history.pending_description = "Copy objects"
	edit_history.capture_blank_state()
	var result := PickCopy.copy_objects(
		tile_set,
		source,
		large_ids,
		base_large_sprites,
		base_small_medium_sprites
	)

	if not result.ok:
		pick_copy_control.copy_completed(result)
		_show_error(result.error)

		return

	for large_id in large_ids:
		for view in 3:
			studio.project.documents.erase("%d:%d" % [large_id, view])
	_record_edit(encoded.bytes)
	_refresh_object_list()
	_refresh_sprite()
	pick_copy_control.copy_completed(result)
	_set_status(
		"%s copied %d objects and %d sprite views."
		% [description, result.object_count, result.shape_count]
	)


func _change_pick_working() -> void:
	request_open()


func _replace_active_view(
	width: int, height: int, pixels: PackedInt32Array,
	description: String, remapped_color_count: int
) -> Result:
	if pixel_canvas.editing_disabled:
		return Result.rejected("The active layer is locked or hidden.")
	_capture_edit_start("Import image")
	var workspace := DrawingWorkspace.from_shape(width, height, pixels, current_view, active_base_width, _clipping_enabled()) if active_workspace else pixels
	_commit_pixels(workspace)
	_set_status("%s. Remapped %d colors." % [description, remapped_color_count])
	var outcome := Result.new()
	outcome.ok = true
	return outcome


func undo() -> void:
	if not edit_history.can_undo():
		return

	var state: Dictionary = edit_history.undo_stack.back().project_before
	var result := edit_history.undo()
	if result.ok:
		studio.restore(state)

	if result.ok:
		tile_set = result.document
	else:
		_show_error(result.error)

	_update_after_history()


func redo() -> void:
	if not edit_history.can_redo():
		return

	var state: Dictionary = edit_history.redo_stack.back().project_after
	var result := edit_history.redo()
	if result.ok:
		studio.restore(state)

	if result.ok:
		tile_set = result.document
	else:
		_show_error(result.error)

	_update_after_history()


func revert_object() -> void:
	if studio.object_start.is_empty():
		return
	_capture_edit_start("Revert object")
	if not studio.project.restore_snapshot(studio.object_start):
		return
	_replace_document_bytes(studio.project.current_mif)
	_record_edit(edit_history.pending_edit_before)
	_update_after_history()
	_set_status("Reverted the current object to its state when selected.")


func revert_name() -> void:
	if tile_set == null or current_large_id < 0:
		return

	var tile_id := object_tile_id(current_large_id)

	if not tile_set.names.has(tile_id):
		return

	_capture_edit_start("Revert tile name")
	var result := tile_set.remove_name(tile_id)

	if not result.ok:
		_show_error(result.error)

		return

	_record_edit(edit_history.pending_edit_before)
	_refresh_object_list()
	_refresh_sprite()
	_set_status("Restored the original query name for object %d." % tile_id)


func clear_object() -> void:
	pixel_canvas.cancel_paste()
	if tile_set == null or current_large_id < 0:
		return

	_capture_edit_start("Clear object")
	var changed_views := 0

	for view in range(3) if active_workspace else [current_view]:
		if not _view_is_available(view):
			continue

		studio.ensure_view(view)
		var width := (
			int(active_base_width / DrawingWorkspace.view_divisor(view))
			if active_workspace
			else pixel_canvas.sprite_width
		)
		var blank := PackedInt32Array()
		blank.resize(maxi(1, width))
		blank.fill(-1)
		var result := tile_set.set_shape_indices(
			view_sprite_id(current_large_id, view), maxi(1, width), 1, blank
		)

		if not result.ok:
			edit_history.cancel_pending_edit()
			_show_error(result.error)
			_refresh_sprite()

			return

		edit_history.blank_shape_ids[view_sprite_id(current_large_id, view)] = true
		studio.clear_view(view)
		changed_views += 1

	_record_edit(edit_history.pending_edit_before)
	_refresh_sprite()
	_set_status("Cleared %d object view%s to clean ground and sky." % [
		changed_views, "" if changed_views == 1 else "s",
	])


func handle_shortcut(event: InputEventKey) -> bool:
	if not visible or not event.pressed or event.echo:
		return false

	if pixel_canvas.has_focus() and pixel_canvas._handle_editor_key(event):
		return true

	var command := event.meta_pressed or event.ctrl_pressed

	if command and event.keycode in [KEY_X, KEY_C, KEY_V]:
		if is_inside_tree():
			var focused := get_viewport().gui_get_focus_owner()
			if focused is LineEdit or focused is TextEdit:
				return false
		return pixel_canvas._handle_editor_key(event)

	if command and event.keycode == KEY_S:
		if event.shift_pressed:
			request_save_as()
		else:
			request_save()

		return true

	if command and event.keycode == KEY_O:
		request_open()

		return true

	if command and event.keycode == KEY_Z:
		if event.shift_pressed:
			redo()
		else:
			undo()

		return true

	if command and event.keycode == KEY_Y:
		redo()

		return true

	if event.keycode == KEY_ESCAPE:
		if pick_copy_control != null and pick_copy_control.visible:
			pick_copy_control.request_close()

			return true

		request_close()

		return true

	return false


static func editable_large_sprite_ids(
	value: ScurkMif, base_large: Sc2SpriteArchive = null
) -> PackedInt32Array:
	return EditorRules.editable_large_sprite_ids(value, base_large)


static func view_sprite_id(large_sprite_id: int, view: int) -> int:
	return EditorRules.view_sprite_id(large_sprite_id, view)


static func object_tile_id(large_sprite_id: int) -> int:
	return EditorRules.object_tile_id(large_sprite_id)


static func path_is_within(path: String, directory: String) -> bool:
	return EditorRules.path_is_within(path, directory)


func _bind_interface() -> void:
	var toolbar := get_node("Panel/Content/Toolbar") as ToolbarView
	toolbar.build()
	toolbar.open_requested.connect(request_open)
	toolbar.save_requested.connect(request_save)
	toolbar.save_as_requested.connect(request_save_as)
	toolbar.import_bmp_requested.connect(request_import_bmp)
	toolbar.export_bmp_requested.connect(request_export_bmp)
	toolbar.pick_copy_requested.connect(request_pick_copy)
	toolbar.undo_requested.connect(undo)
	toolbar.redo_requested.connect(redo)
	toolbar.revert_requested.connect(revert_object)
	toolbar.clear_requested.connect(clear_object)
	toolbar.name_requested.connect(request_edit_name)
	toolbar.settings_requested.connect(settings_requested.emit)
	toolbar.about_requested.connect(about_requested.emit)
	toolbar.close_requested.connect(request_close)
	save_button = toolbar.save_button
	undo_button = toolbar.undo_button
	redo_button = toolbar.redo_button
	revert_button = toolbar.revert_button
	clear_object_button = toolbar.clear_button

	source_label = get_node("Panel/Content/StatusBar/Row/File")
	pointer_status_label = get_node("Panel/Content/StatusBar/Row/Pointer")

	object_panel = get_node("Panel/Content/Body/Studio/Margin/Column/Objects")
	object_panel.build()
	object_panel.search_changed.connect(_on_search_changed)
	object_panel.object_selected.connect(_on_object_selected)
	object_panel.name_submitted.connect(_commit_name)
	object_panel.set_name_requested.connect(_commit_name)
	object_panel.revert_name_requested.connect(revert_name)
	object_search = object_panel.object_search
	object_list = object_panel.object_list
	name_edit = object_panel.name_edit
	name_button = object_panel.name_button
	revert_name_button = object_panel.revert_name_button

	drawing_controls = get_node("Panel/Content/Body/DrawingControls")
	drawing_controls.build()
	drawing_controls.button_clicked.connect(toolbar_button_clicked.emit)
	drawing_controls.view_selected.connect(_select_view)
	drawing_controls.zoom_fit_requested.connect(_fit_canvas)
	drawing_controls.zoom_out_requested.connect(_zoom_out)
	drawing_controls.zoom_in_requested.connect(_zoom_in)
	drawing_controls.tool_selected.connect(_select_tool)
	drawing_controls.rotate_clipboard_requested.connect(_rotate_clipboard)
	drawing_controls.rotate_clipboard_clockwise_requested.connect(func() -> void:
		pixel_canvas.rotate_clipboard_clockwise())
	drawing_controls.flip_clipboard_horizontal_requested.connect(
		_flip_clipboard_horizontal
	)
	drawing_controls.flip_clipboard_vertical_requested.connect(
		_flip_clipboard_vertical
	)
	drawing_controls.copy_requested.connect(func() -> void: pixel_canvas.copy_selection())
	drawing_controls.paste_requested.connect(func() -> void: pixel_canvas.begin_paste())
	drawing_controls.brush_size_changed.connect(_select_brush_size)
	drawing_controls.round_brush_changed.connect(_set_round_brush)
	drawing_controls.filled_shapes_changed.connect(_set_filled_shapes)
	drawing_controls.grid_visibility_changed.connect(_set_grid_visible)
	drawing_controls.grid_snap_changed.connect(_set_snap_to_grid)
	drawing_controls.grid_width_changed.connect(_set_grid_width)
	drawing_controls.grid_height_changed.connect(_set_grid_height)
	drawing_controls.clip_region_changed.connect(_set_clip_region_visible)
	drawing_controls.clip_enabled_changed.connect(_set_clipping_enabled)
	view_buttons = drawing_controls.view_buttons
	zoom_label = drawing_controls.zoom_label
	tool_buttons = drawing_controls.tool_buttons
	clipboard_action_buttons = drawing_controls.clipboard_action_buttons
	clipboard_copy_button = drawing_controls.clipboard_copy_button
	clipboard_paste_button = drawing_controls.clipboard_paste_button
	brush_size_selector = drawing_controls.brush_size_selector
	round_brush_check = drawing_controls.round_brush_check
	filled_shapes_check = drawing_controls.filled_shapes_check
	grid_check = drawing_controls.grid_check
	snap_to_grid_check = drawing_controls.snap_to_grid_check
	grid_width_selector = drawing_controls.grid_width_selector
	grid_height_selector = drawing_controls.grid_height_selector
	clip_region_check = drawing_controls.clip_region_check

	canvas_panel = get_node("Panel/Content/Body/Editor/Canvas")
	canvas_panel.build()
	canvas_panel.context_requested.connect(_studio_action.bind("Context"))
	pixel_canvas = canvas_panel.pixel_canvas
	view_previews = canvas_panel.view_previews
	view_preview_panels = canvas_panel.view_preview_panels
	sprite_status_label = toolbar.get_node("Row/SpriteStatus")
	pixel_canvas.edit_started.connect(_capture_edit_start)
	pixel_canvas.pixels_committed.connect(_commit_pixels)
	pixel_canvas.palette_index_picked.connect(_select_palette_index)
	pixel_canvas.pointer_changed.connect(_update_pointer_status)
	pixel_canvas.clipboard_changed.connect(_on_clipboard_changed)

	palette_panel = get_node("Panel/Content/Body/Studio/Margin/Column/Tabs/Colors")
	palette_panel.build()
	palette_panel.set_patterns(pixel_canvas.texture_patterns)
	palette_panel.palette_index_selected.connect(_select_palette_index)
	palette_panel.texture_selected.connect(_select_texture)
	cycle_colors_check = palette_panel.cycle_colors_check
	increment_cycle_button = palette_panel.increment_cycle_button
	cycle_colors_check.toggled.connect(_set_cycle_colors)
	increment_cycle_button.pressed.connect(_increment_cycle)
	pixel_canvas.set_process(false)
	for preview in view_previews:
		preview.set_process(false)

	status_label = get_node("Panel/Content/StatusBar/Row/Message")

	dialog_registry = get_node("Dialogs")
	dialog_registry._create_dialogs()
	open_dialog = dialog_registry.open_dialog
	open_dialog.file_selected.connect(_load_selected_path)
	save_dialog = dialog_registry.save_dialog
	save_dialog.file_selected.connect(_save_selected_path)
	import_bmp_dialog = dialog_registry.import_bmp_dialog
	import_bmp_dialog.file_selected.connect(_import_selected_bmp)
	export_bmp_dialog = dialog_registry.export_bmp_dialog
	export_bmp_dialog.file_selected.connect(_export_selected_bmp)
	error_dialog = dialog_registry.error_dialog
	dialog_registry.export_options.confirmed.connect(_show_export_file_dialog)
	discard_dialog = dialog_registry.discard_dialog
	discard_dialog.confirmed.connect(_confirm_discard)
	pick_copy_control = dialog_registry.pick_copy_control
	pick_copy_control.close_requested.connect(_pick_copy_closed)
	pick_copy_control.change_working_requested.connect(_change_pick_working)
	pick_copy_control.copy_requested.connect(_copy_pick_objects)
	_select_palette_index(0, false)
	_select_palette_index(255, true)
	studio = $Panel/Content/Body/Studio
	studio.bind(self)
	for button in tool_buttons + clipboard_action_buttons + [clipboard_copy_button, clipboard_paste_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			if pixel_canvas.is_inside_tree():
				pixel_canvas.grab_focus())
	pixel_canvas.pan_requested.connect(canvas_panel.pan_canvas)
	pixel_canvas.zoom_requested.connect(canvas_panel.zoom_at)
	canvas_panel.zoom_changed.connect(func(value: int) -> void: zoom_label.text = "%dx" % value)
	pixel_canvas.brush_size_requested.connect(func(size: int) -> void: brush_size_selector.value = size)
	pixel_canvas.paint_indices_swap_requested.connect(func() -> void:
		var foreground := pixel_canvas.foreground_index
		var background := pixel_canvas.background_index
		_select_palette_index(foreground)
		_select_palette_index(background, true))
	toolbar.studio_action.connect(_studio_action)
	_update_history_buttons()


func _pick_copy_closed() -> void:
	if is_inside_tree() and object_list != null:
		object_list.grab_focus()


func _refresh_object_list() -> void:
	if object_list == null:
		return

	var selected_id := current_large_id
	var filter := object_search.text.strip_edges().to_lower() if object_search != null else ""
	object_list.clear()

	if tile_set == null:
		return

	var selected_found := false
	for large_id in editable_large_sprite_ids(tile_set, base_large_sprites):
		var tile_id := object_tile_id(large_id)
		var tile_name := String(tile_set.names.get(tile_id, ""))
		var description := tile_name if not tile_name.is_empty() else sprite_role(tile_id)
		var label := "%03d  %s" % [tile_id, description]

		if not filter.is_empty() and not label.to_lower().contains(filter):
			continue

		var list_index := object_list.item_count
		object_list.add_icon_item(_tile_thumbnail(large_id), label)
		object_list.set_item_metadata(list_index, large_id)
		object_list.get_popup().set_item_tooltip(
			list_index,
			"Sprite family %d: Small %d, Medium %d, Large %d"
			% [tile_id, tile_id, tile_id + 500, tile_id + 1000]
		)

		if large_id == selected_id:
			object_list.select(list_index)
			selected_found = true

	if not selected_found and object_list.item_count > 0:
		object_list.select(0)
		var replacement_id := int(object_list.get_item_metadata(0))

		if replacement_id != current_large_id:
			current_large_id = replacement_id
			_capture_object_start()


func _on_object_selected(index: int) -> void:
	object_list.select(index)
	var selected_id := int(object_list.get_item_metadata(index))

	if selected_id != current_large_id:
		current_large_id = selected_id
		_capture_object_start()

	_refresh_sprite()


func _on_search_changed(_value: String) -> void:
	_refresh_object_list()
	_refresh_sprite()


func _select_view(view: int) -> void:
	if not _view_is_available(view):
		return

	current_view = view

	for index in view_buttons.size():
		view_buttons[index].button_pressed = index == view

	_refresh_sprite()


func _select_tool(tool_value: int) -> void:
	current_tool = tool_value
	drawing_controls.update_tool_controls(tool_value)

	if pixel_canvas != null:
		pixel_canvas.set_tool(tool_value)
		if pixel_canvas.is_inside_tree():
			pixel_canvas.grab_focus()

	for index in tool_buttons.size():
		tool_buttons[index].button_pressed = index == tool_value


func _select_palette_index(index: int, background := false) -> void:
	if studio != null and not studio.loading and not studio.project.current_mif.is_empty():
		palette_panel.remember_index(index)
	if background:
		background_palette_index = clampi(index, 0, 255)
	else:
		foreground_palette_index = clampi(index, 0, 255)

	if pixel_canvas != null:
		pixel_canvas.set_paint_indices(
			foreground_palette_index, background_palette_index
		)

	if palette_panel != null:
		palette_panel.set_colors(
			foreground_palette_index, background_palette_index
		)


func _select_brush_size(value: float) -> void:
	if brush_size_selector == null or pixel_canvas == null:
		return

	pixel_canvas.set_brush(
		roundi(value), round_brush_check.button_pressed
	)


func _set_round_brush(enabled: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_brush(pixel_canvas.brush_size, enabled)


func _set_filled_shapes(enabled: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.filled_shapes = enabled
		pixel_canvas.queue_redraw()


func _set_grid_visible(enabled: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.show_grid = enabled
		pixel_canvas.queue_redraw()


func _set_snap_to_grid(_enabled: bool) -> void:
	_apply_grid_settings()


func _set_grid_width(_value: float) -> void:
	_apply_grid_settings()


func _set_grid_height(_value: float) -> void:
	_apply_grid_settings()


func _apply_grid_settings() -> void:
	if (
		pixel_canvas == null
		or snap_to_grid_check == null
		or grid_width_selector == null
		or grid_height_selector == null
	):
		return

	pixel_canvas.set_grid_settings(
		roundi(grid_width_selector.value),
		roundi(grid_height_selector.value),
		snap_to_grid_check.button_pressed
	)


func _set_clip_region_visible(enabled: bool) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_clip_region_visible(enabled and not clip_region_check.disabled)


func _process(delta: float) -> void:
	if pixel_canvas == null or not is_visible_in_tree():
		return

	var before := pixel_canvas.palette_cycle_ticks
	pixel_canvas._process(delta)
	if before != pixel_canvas.palette_cycle_ticks:
		_sync_palette_cycle()


func _sync_palette_cycle() -> void:
	var tick := pixel_canvas.palette_cycle_ticks
	palette_panel.set_cycle_tick(tick)
	for preview in view_previews:
		preview.set_cycle_tick(tick)


func _set_cycle_colors(enabled: bool) -> void:
	pixel_canvas.set_palette_cycle_enabled(enabled)
	for preview in view_previews:
		preview.set_palette_cycle_enabled(enabled)
	increment_cycle_button.disabled = enabled
	_sync_palette_cycle()


func _increment_cycle() -> void:
	pixel_canvas.increment_palette_cycle()
	_sync_palette_cycle()
	_set_status("Advanced the color cycle by one step.")


func _clipping_enabled() -> bool:
	return not unclipped_tiles.get(current_large_id, false)


func _set_clipping_enabled(enabled: bool) -> void:
	unclipped_tiles[current_large_id] = not enabled
	_refresh_sprite()
	_set_status("Tile clipping enabled." if enabled else "Tile clipping disabled. Use the full drawing area.")


func _select_texture(index: int) -> void:
	if pixel_canvas != null:
		pixel_canvas.set_texture(index)

	if palette_panel != null:
		palette_panel.set_selected_texture(index)


func _rotate_clipboard() -> void:
	if pixel_canvas != null:
		pixel_canvas.rotate_clipboard_counterclockwise()


func _flip_clipboard_horizontal() -> void:
	if pixel_canvas != null:
		pixel_canvas.flip_clipboard_horizontal()


func _flip_clipboard_vertical() -> void:
	if pixel_canvas != null:
		pixel_canvas.flip_clipboard_vertical()


func _on_clipboard_changed(width: int, height: int) -> void:
	var available := width > 0 and height > 0

	if clipboard_paste_button != null:
		clipboard_paste_button.disabled = not available

	for button in clipboard_action_buttons:
		button.disabled = not available

	if available:
		_set_status("SCURK clipboard: %d x %d pixels." % [width, height])


func _refresh_sprite() -> void:
	if pixel_canvas == null:
		return

	if tile_set == null or current_large_id < 0:
		pixel_canvas.clear_sprite()
		_refresh_view_previews()
		name_edit.text = ""
		name_edit.editable = false
		name_button.disabled = true
		revert_name_button.disabled = true

		return

	_update_view_buttons()
	var sprite_id := view_sprite_id(current_large_id, current_view)
	var entry := tile_set.overrides.find_sprite(sprite_id)
	var source := "MIF override"

	if entry == null and edit_history.blank_shape_ids.has(sprite_id):
		entry = tile_set.archive.find_sprite(sprite_id)
		source = "cleared object"

	if entry == null:
		var base_archive := base_large_sprites if current_view == VIEW_LARGE else base_small_medium_sprites
		entry = base_archive.find_sprite(sprite_id) if base_archive != null else null
		source = "original fallback"

	if entry == null:
		entry = tile_set.archive.find_sprite(sprite_id)
		source = "blank MIF shape"

	if entry == null:
		pixel_canvas.clear_sprite()
		_refresh_view_previews()
		sprite_status_label.text = "Sprite %d is missing." % sprite_id

		return

	var decoded := entry.decode_indices()

	if not decoded.ok:
		pixel_canvas.clear_sprite()
		_refresh_view_previews()
		sprite_status_label.text = decoded.error

		return

	var large_entry := PickCopy.resolved_entry(
		tile_set, current_large_id, base_large_sprites, base_small_medium_sprites
	)
	var original_entry := base_large_sprites.find_sprite(current_large_id) if base_large_sprites != null else null
	active_base_width = original_entry.width if original_entry != null else (large_entry.width if large_entry != null else 0)
	active_workspace = DrawingWorkspace.is_standard_base_width(active_base_width)
	if active_workspace and not unclipped_tiles.has(current_large_id):
		unclipped_tiles[current_large_id] = _tile_needs_unclipped_workspace()

	drawing_controls.clip_enabled_check.set_pressed_no_signal(_clipping_enabled())
	drawing_controls.clip_enabled_check.disabled = not active_workspace
	clip_region_check.disabled = not active_workspace or not _clipping_enabled()
	pixel_canvas.clear_edit_region()

	if active_workspace:
		var workspace := DrawingWorkspace.from_shape(
			entry.width, entry.height, decoded.pixels, current_view, active_base_width, _clipping_enabled()
		)
		pixel_canvas.set_sprite_data(
			DrawingWorkspace.WIDTH, DrawingWorkspace.HEIGHT, workspace, palette, studio.key() == studio.last_key
		)
		if _clipping_enabled():
			pixel_canvas.set_edit_region(
				DrawingWorkspace.clip_mask(active_base_width, current_view),
				DrawingWorkspace.base_size(active_base_width)
			)
		pixel_canvas.set_clip_region_visible(clip_region_check.button_pressed and not clip_region_check.disabled)
	else:
		pixel_canvas.set_sprite_data(entry.width, entry.height, decoded.pixels, palette, studio.key() == studio.last_key)

	studio.bind_canvas()
	pixel_canvas.set_background_view(current_view)
	pixel_canvas.set_tool(current_tool)
	pixel_canvas.set_paint_indices(
		foreground_palette_index, background_palette_index
	)
	pixel_canvas.set_brush(
		roundi(brush_size_selector.value),
		round_brush_check.button_pressed
	)
	pixel_canvas.set_texture(palette_panel.selected_texture_index())
	pixel_canvas.filled_shapes = filled_shapes_check.button_pressed
	pixel_canvas.show_grid = grid_check.button_pressed
	_apply_grid_settings()
	_refresh_view_previews()
	_refresh_selected_thumbnail()
	var tile_id := object_tile_id(current_large_id)
	var can_name := tile_id >= 0
	name_edit.editable = can_name
	name_button.disabled = not can_name
	name_edit.text = String(tile_set.names.get(tile_id, ""))
	revert_name_button.disabled = not can_name or not tile_set.names.has(tile_id)
	sprite_status_label.text = (
		"Sprite %d: %d x %d output, %d x %d tile base, %s."
		% [
			sprite_id, entry.width, entry.height,
			DrawingWorkspace.base_size(active_base_width),
			DrawingWorkspace.base_size(active_base_width), source,
		]
		if active_workspace
		else "Sprite %d: %d x %d pixels, %s." % [
			sprite_id, entry.width, entry.height, source,
		]
	)


func _update_view_buttons() -> void:
	if current_large_id < 0:
		return

	if not _view_is_available(current_view):
		for candidate in [VIEW_LARGE, VIEW_MEDIUM, VIEW_SMALL]:
			if _view_is_available(candidate):
				current_view = candidate
				break

	for index in view_buttons.size():
		view_buttons[index].disabled = not _view_is_available(index)
		view_buttons[index].button_pressed = index == current_view


func _view_is_available(view: int) -> bool:
	if tile_set == null or current_large_id < 0:
		return false

	var sprite_id := view_sprite_id(current_large_id, view)

	return PickCopy.resolved_entry(
		tile_set, sprite_id, base_large_sprites, base_small_medium_sprites
	) != null


static func sprite_role(tile_id: int) -> String:
	return EditorRules.sprite_role(tile_id)


func _capture_edit_start(description := "Edit artwork") -> void:
	edit_history.capture_edit(tile_set, description)
	studio.capture()


func _capture_object_start() -> void:
	edit_history.capture_object(tile_set, current_large_id)
	studio.object_start = studio.project.snapshot()
	_update_history_buttons()


func _commit_pixels(value_pixels: PackedInt32Array) -> void:
	if pixel_canvas.editing_disabled and not studio.committing_layer:
		_refresh_sprite()
		return
	var flattened := value_pixels if studio.committing_layer else studio.prepare_pixels(value_pixels)
	if _write_pixels(flattened):
		_record_edit(edit_history.pending_edit_before)
		_refresh_selected_thumbnail()
		_refresh_sprite()


func _write_pixels(value_pixels: PackedInt32Array) -> bool:
	if tile_set == null or current_large_id < 0:
		return false

	var sprite_id := view_sprite_id(current_large_id, current_view)
	var output_width := pixel_canvas.sprite_width
	var output_height := pixel_canvas.sprite_height
	var output_pixels := value_pixels

	if active_workspace:
		var active_shape := DrawingWorkspace.shape_from_workspace(
			value_pixels, active_base_width, current_view, _clipping_enabled()
		)

		if not active_shape.ok:
			_show_error(active_shape.error)

			if not edit_history.pending_edit_before.is_empty():
				_replace_document_bytes(edit_history.pending_edit_before)

			_refresh_sprite()

			return false

		output_width = active_shape.width
		output_height = active_shape.height
		output_pixels = active_shape.pixels

	var result := tile_set.set_shape_indices(
		sprite_id, output_width, output_height, output_pixels
	)

	if not result.ok:
		_show_error(result.error)

		if not edit_history.pending_edit_before.is_empty():
			_replace_document_bytes(edit_history.pending_edit_before)

		_refresh_sprite()

		return false

	edit_history.mark_shape_blank_state(sprite_id, output_pixels)
	return true


func _refresh_view_previews() -> void:
	if view_previews.size() != 3 or view_preview_panels.size() != 3:
		return

	if is_inside_tree() and not is_visible_in_tree():
		return

	if tile_set == null or current_large_id < 0:
		for view in 3:
			view_previews[view].clear_preview(view)
			view_preview_panels[view].visible = false
			view_preview_signatures[view] = ""

		return

	for view in 3:
		var entry: Sc2SpriteArchive.SpriteEntry = _resolved_view_entry(view)

		if entry == null:
			view_previews[view].clear_preview(view)
			view_preview_panels[view].visible = false
			view_preview_signatures[view] = ""
			continue

		var signature := "%d:%d:%d:%d:%s" % [
			active_base_width, entry.width, entry.height, entry.pixel_hash(), _clipping_enabled(),
		]

		if view_preview_signatures[view] == signature:
			view_preview_panels[view].visible = true
			continue

		var decoded := entry.decode_indices()

		if not decoded.ok:
			view_previews[view].clear_preview(view)
			view_preview_panels[view].visible = false
			view_preview_signatures[view] = ""
			continue

		view_previews[view].set_preview(
			view,
			entry.width,
			entry.height,
			decoded.pixels,
			active_base_width,
			palette,
			pixel_canvas.clear_background_pixels,
			_clipping_enabled()
		)
		view_previews[view].set_palette_cycle_enabled(
			cycle_colors_check.button_pressed
		)
		view_preview_panels[view].visible = true
		view_preview_signatures[view] = signature


func _resolved_view_entry(view: int):
	if tile_set == null or current_large_id < 0:
		return null

	var sprite_id := view_sprite_id(current_large_id, view)
	var entry: Variant = tile_set.overrides.find_sprite(sprite_id)

	if entry == null and edit_history.blank_shape_ids.has(sprite_id):
		entry = tile_set.archive.find_sprite(sprite_id)

	if entry == null:
		var base_archive := (
			base_large_sprites if view == VIEW_LARGE else base_small_medium_sprites
		)
		entry = base_archive.find_sprite(sprite_id) if base_archive != null else null

	if entry == null:
		entry = tile_set.archive.find_sprite(sprite_id)

	return entry


func _active_output_shape() -> IndexedImageResult:
	if pixel_canvas == null or pixel_canvas.sprite_width <= 0:
		return IndexedImageResult.failure("No SCURK sprite is available.")

	var flattened := studio.project.flatten(studio.key()) if studio.project.documents.has(studio.key()) else pixel_canvas.pixels
	if active_workspace:
		return DrawingWorkspace.shape_from_workspace(
			flattened, active_base_width, current_view, _clipping_enabled()
		)

	var outcome := IndexedImageResult.new()
	outcome.ok = true
	outcome.width = pixel_canvas.sprite_width
	outcome.height = pixel_canvas.sprite_height
	outcome.pixels = flattened.duplicate()
	outcome.error = ""

	return outcome


func _commit_name() -> void:
	object_panel.name_dialog.hide()
	if tile_set == null or current_large_id < 0:
		return

	var tile_id := object_tile_id(current_large_id)
	var value := name_edit.text.strip_edges()

	if value == String(tile_set.names.get(tile_id, sprite_role(tile_id))):
		return

	_capture_edit_start("Rename tile")
	var result := tile_set.set_name(tile_id, value)

	if not result.ok:
		_show_error(result.error)

		return

	_record_edit(edit_history.pending_edit_before)
	_refresh_object_list()
	_refresh_sprite()


func _record_edit(before: PackedByteArray) -> void:
	studio.record()
	if not edit_history.record(before, tile_set):
		return

	_update_history_buttons()
	_update_title()


func _replace_document_bytes(bytes: PackedByteArray) -> bool:
	var replacement := Mif.new()

	if not replacement.parse(bytes):
		_show_error(replacement.parse_error)

		return false

	tile_set = replacement

	return true


func _update_after_history() -> void:
	_refresh_object_list()
	_refresh_sprite()
	_update_dirty()
	_update_history_buttons()
	_update_title()

	if pick_copy_control != null and pick_copy_control.visible:
		pick_copy_control.open_with_working(tile_set, source_path)


func _update_dirty() -> void:
	edit_history.update_dirty(tile_set)


func _update_history_buttons() -> void:
	if studio != null and studio.editor != null:
		studio.refresh_history()

	if undo_button != null:
		undo_button.disabled = not edit_history.can_undo()

	if redo_button != null:
		redo_button.disabled = not edit_history.can_redo()

	if revert_button != null:
		revert_button.disabled = not edit_history.can_revert_object(
			tile_set, current_large_id
		)

	if save_button != null:
		save_button.disabled = tile_set == null


func _update_title() -> void:
	if source_label == null:
		return

	var filename := source_path.get_file() if not source_path.is_empty() else "Untitled.MIF"
	if studio != null and not studio.project_path.is_empty():
		filename = studio.project_path.get_file()
	source_label.text = "%s%s" % [filename, " *" if dirty else ""]
	source_label.tooltip_text = source_path


func _zoom_in() -> void:
	if pixel_canvas == null:
		return

	pixel_canvas.set_zoom(pixel_canvas.zoom + 1)
	zoom_label.text = "%dx" % pixel_canvas.zoom


func _zoom_out() -> void:
	if pixel_canvas == null:
		return

	pixel_canvas.set_zoom(pixel_canvas.zoom - 1)
	zoom_label.text = "%dx" % pixel_canvas.zoom


func _update_pointer_status(point: Vector2i, index: int) -> void:
	pointer_status_label.text = "" if point.x < 0 else "%d, %d | %s" % [
		point.x, point.y, "transparent" if index < 0 else "index %d" % index,
	]


func _apply_tile_set() -> void:
	if tile_set == null or not tile_set.is_valid():
		return

	var display_name := source_path.get_file()

	if display_name.is_empty():
		display_name = "Unsaved tile set"

	tile_set_applied.emit(tile_set, display_name, source_path)
	_set_status("Applied %s to the city artwork." % display_name)


func request_place_print() -> void:
	if tile_set == null or not tile_set.is_valid():
		return

	_apply_tile_set()
	hide()
	place_print_requested.emit()


func _popup_open_dialog() -> void:
	var tile_set_directory := reference_directory.path_join("SCURKART")

	if DirAccess.dir_exists_absolute(tile_set_directory):
		open_dialog.current_dir = tile_set_directory

	open_dialog.popup_centered_ratio(0.75)


func _load_selected_path(path: String) -> void:
	var result := load_path(path)

	if not result.ok:
		_show_error(result.error)


func _save_selected_path(path: String) -> void:
	var result := save_path(path)

	if not result.ok:
		_show_error(result.error)


func _import_selected_bmp(path: String) -> void:
	studio.preview_import(path)


func _export_selected_bmp(path: String) -> void:
	var result := export_image_path(path, pending_export_view)

	if not result.ok:
		_show_error(result.error)


func _confirm_discard() -> void:
	var action := pending_discard_action
	pending_discard_action = ""

	studio.discard_recovery()
	if action == "recover":
		studio.show_recovery_files()
	elif action == "open":
		_popup_open_dialog()
	elif action == "close":
		hide()
		close_requested.emit()


func _set_status(message: String) -> void:
	if status_label == null:
		return

	status_label.theme_type_variation = ""
	status_label.text = message


func _show_error(message: String) -> void:
	if status_label != null:
		status_label.theme_type_variation = "ErrorLabel"
		status_label.text = message

	if error_dialog != null:
		error_dialog.dialog_text = message
		error_dialog.popup_centered()


func _fit_canvas() -> void:
	if pixel_canvas == null or canvas_panel == null:
		return

	var available := canvas_panel.pixel_scroll.size - Vector2(20, 20)
	var factor := mini(floori(available.x / maxi(1, pixel_canvas.sprite_width)), floori(available.y / maxi(1, pixel_canvas.sprite_height)))
	pixel_canvas.set_zoom(maxi(1, factor))
	zoom_label.text = "%dx" % pixel_canvas.zoom
	canvas_panel.pixel_scroll.scroll_horizontal = 0
	canvas_panel.pixel_scroll.scroll_vertical = 0


func _output_shape_for_view(view: int) -> IndexedImageResult:
	if view < VIEW_LARGE or view > VIEW_SMALL:
		return IndexedImageResult.failure("Select a valid image size.")

	var entry: Sc2SpriteArchive.SpriteEntry = _resolved_view_entry(view)
	if entry == null:
		return IndexedImageResult.failure("This image size is not available.")

	var decoded := entry.decode_indices()
	if not decoded.ok:
		return IndexedImageResult.failure(decoded.error)

	var result := IndexedImageResult.new()
	result.ok = true
	result.width = entry.width
	result.height = entry.height
	result.pixels = decoded.pixels
	return result


func _fit_canvas_after_layout() -> void:
	if not is_inside_tree():
		return

	await get_tree().process_frame
	await get_tree().process_frame
	_fit_canvas()


func _tile_needs_unclipped_workspace() -> bool:
	for view in 3:
		var entry := tile_set.overrides.find_sprite(view_sprite_id(current_large_id, view))
		if entry == null:
			continue

		if entry.width * DrawingWorkspace.view_divisor(view) > active_base_width:
			return true

		if path_is_within(source_path, reference_directory):
			continue

		var decoded := entry.decode_indices()
		if not decoded.ok:
			continue

		var expanded := DrawingWorkspace.from_shape(
			entry.width, entry.height, decoded.pixels, view, active_base_width, false
		)
		if expanded != DrawingWorkspace.apply_clip_mask(expanded, active_base_width, view):
			return true

	return false


func _refresh_selected_thumbnail() -> void:
	if object_list.selected >= 0:
		object_list.set_item_icon(object_list.selected, _tile_thumbnail(current_large_id))


func _tile_thumbnail(large_id: int) -> Texture2D:
	var entry := PickCopy.resolved_entry(
		tile_set, large_id, base_large_sprites, base_small_medium_sprites
	)
	if edit_history.blank_shape_ids.has(large_id):
		entry = tile_set.archive.find_sprite(large_id)
	if entry == null or palette == null:
		return null

	var signature: int = hash([entry.width, entry.height, entry.pixel_hash()])
	if thumbnail_signatures.get(large_id, -1) == signature:
		return tile_thumbnails[large_id]

	var rendered := entry.create_image(palette)
	if not rendered.ok:
		return null

	const SIDE := 32
	var image := rendered.image
	var factor := float(SIDE) / maxi(image.get_width(), image.get_height())
	image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_NEAREST)
	var thumbnail := Image.create(SIDE, SIDE, false, Image.FORMAT_RGBA8)
	thumbnail.fill(Color.TRANSPARENT)
	thumbnail.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), (Vector2i(SIDE, SIDE) - image.get_size()) / 2)
	var texture := ImageTexture.create_from_image(thumbnail)
	tile_thumbnails[large_id] = texture
	thumbnail_signatures[large_id] = signature
	return texture


func request_edit_name() -> void:
	if tile_set == null or current_large_id < 0:
		return

	var tile_id := object_tile_id(current_large_id)
	name_edit.text = String(tile_set.names.get(tile_id, sprite_role(tile_id)))
	object_panel.edit_name()


func _studio_action(action: String) -> void:
	match action:
		"RecoverProject": studio.request_recovery()
		"ProjectSaveAs": studio.request_save(true)
		"ExportTileSet": request_save_as()
		"PaintOptions": studio.show_paint()
		"ReplaceColor": studio.show_replace()
		"Context": studio.show_context()
		"SelectAll": pixel_canvas.select_all()
		"Deselect": pixel_canvas.clear_selection()
		"CopySelection": pixel_canvas.copy_selection()
		"CutSelection": pixel_canvas.cut_selection()
		"DuplicateSelection": pixel_canvas.duplicate_selection()
		"DeleteSelection": pixel_canvas.delete_selection()
		"PasteSelection": pixel_canvas.begin_paste()
	if is_inside_tree() and action in ["SelectAll", "Deselect", "CopySelection", "CutSelection", "DuplicateSelection", "DeleteSelection", "PasteSelection"]:
		pixel_canvas.grab_focus()
