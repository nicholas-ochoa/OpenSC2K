class_name ScurkEditorStudio
extends PanelContainer

@warning_ignore_start("integer_division")

const Workspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")
const LAYERS := "Margin/Column/Tabs/Layers"
const HISTORY := "Margin/Column/Tabs/History"
const META := "Margin/Column/Tabs/Metadata"
const STAMPS := "Margin/Column/Tabs/Stamps"
const MAX_SAVED_ID_LIST_SIZE := 1500

var tabs: TabContainer
var editor: ScurkEditorControl
var project: ScurkProject:
	get:
		return editor.session.project
	set(value):
		editor.session.project = value
var project_path := ""
var recovery_path := "user://scurk/recovery.scurk"
var modified: bool:
	get:
		return editor.session.modified if editor != null else false
	set(value):
		editor.session.modified = value
var loading := false
var committing_layer := false
var last_key := ""
var saved_pixels: Dictionary = {}
var saved_state: Dictionary = {}
var saved_checkpoints: Array = []
var object_start: Dictionary = {}
var autosave_elapsed := 0.0
var autosave_revision := -1
var recovery_checked := false
var recovery_owned := false
var recovered_source := ""
var imported: IndexedImageResult
var imported_path := ""
var import_clipped := 0
var context_view := ScurkSpriteIds.View.LARGE
var updating_controls := false
var pending_delete_key := ""
var pending_delete_layer: Dictionary = {}


func bind(value: ScurkEditorControl) -> void:
	editor = value
	AppUiTheme.bind_frosted_panel(self)
	tabs = $Margin/Column/Tabs
	tabs.tab_changed.connect(_tab_changed)
	for dialog: FileDialog in [$OpenProject, $SaveProject, $RecoveryFiles]:
		dialog.theme = AppUiTheme.file_dialog()
	$RecoveryFiles.file_selected.connect(func(path: String) -> void: load_project(path, true))
	$OpenProject.file_selected.connect(load_project)
	$SaveProject.file_selected.connect(save_project)
	$Recovery.confirmed.connect(func() -> void: load_project(recovery_path, true))
	get_node(LAYERS + "/Row/List").item_selected.connect(func(row: int) -> void:
		_select_layer(int(get_node(LAYERS + "/Row/List").get_item_metadata(row))))
	for action in ["Add", "Delete", "Up", "Down", "Rename"]:
		get_node(LAYERS + "/Row/Actions/" + action).pressed.connect(_layer_action.bind(action))
	get_node(LAYERS + "/State/Visible").toggled.connect(_layer_visible)
	get_node(LAYERS + "/State/Locked").toggled.connect(_layer_locked)
	get_node(HISTORY + "/Actions/Undo").pressed.connect(editor.undo)
	get_node(HISTORY + "/Actions/Redo").pressed.connect(editor.redo)
	get_node(HISTORY + "/List").item_selected.connect(_select_history)
	$DeleteLayer.confirmed.connect(_confirm_delete_layer)
	$DeleteLayer.canceled.connect(_cancel_delete_layer)
	get_node(META + "/Apply").pressed.connect(_metadata_changed)
	for action in ["Add", "Use", "Delete"]:
		get_node(STAMPS + "/Actions/" + action).pressed.connect(_stamp_action.bind(action))
	get_node(STAMPS + "/Spacing/Value").value_changed.connect(func(value: float) -> void:
		editor.pixel_canvas.paint_options.stamp_spacing = roundi(value))
	$Paint/Content/Shade.toggled.connect(func(enabled: bool) -> void:
		if enabled:
			$Paint/Content/Stamp.set_pressed_no_signal(false))
	$Paint/Content/Stamp.toggled.connect(func(enabled: bool) -> void:
		if enabled:
			$Paint/Content/Shade.set_pressed_no_signal(false))
	for option in ["Lock", "Perfect", "Shade", "Stamp", "Iso", "Guides"]:
		get_node("Paint/Content/" + option).toggled.connect(func(_enabled: bool) -> void: _paint_options_changed())
	for field in ["Spacing", "OffsetX", "OffsetY"]:
		get_node("Paint/Content/GuideFields/" + field).value_changed.connect(func(_value: float) -> void: _paint_options_changed())
	var compare := $Paint/Content/Compare as OptionButton
	for label in ["Current artwork", "Saved artwork", "Saved overlay", "Changed pixels"]:
		compare.add_item(label)
	compare.item_selected.connect(func(index: int) -> void:
		editor.pixel_canvas.comparison_mode = index
		editor.pixel_canvas.queue_redraw())
	$Replace.confirmed.connect(_replace_colors)
	$ImportPreview.confirmed.connect(_apply_import)
	for field in ["X", "Y"]:
		get_node("ImportPreview/Content/Placement/" + field).value_changed.connect(func(_value: float) -> void: _refresh_import())
	for view in ScurkSpriteIds.VIEW_COUNT:
		get_node("Context/Content/Options/" + ["Large", "Medium", "Small"][view]).pressed.connect(_select_context_view.bind(view))
	$Context/Content/Options/Roads.toggled.connect(func(enabled: bool) -> void:
		$Context/Content/View.show_roads = enabled
		$Context/Content/View.queue_redraw())
	$Context/Content/Options/Neighbors.toggled.connect(func(enabled: bool) -> void:
		$Context/Content/View.show_neighbors = enabled
		$Context/Content/View.queue_redraw())
	editor.palette_panel.palette_index_hovered.connect(func(index: int) -> void:
		editor.pixel_canvas.highlighted_palette_index = index
		editor.pixel_canvas.queue_redraw())
	editor.palette_panel.shade_ramp_changed.connect(editor.pixel_canvas.paint_options.set_shade_ramp)
	editor.palette_panel.navigation_changed.connect(_palette_state_changed)
	theme_changed.connect(_refresh_icon_colors)
	_refresh_icon_colors()


func _refresh_icon_colors() -> void:
	for button: Button in get_node(LAYERS + "/Row/Actions").get_children():
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var color_name := "font_color" if state == "normal" else "font_%s_color" % state
			button.add_theme_color_override(
				"icon_%s_color" % state, button.get_theme_color(color_name, "Button")
			)


func reset(bytes: PackedByteArray) -> void:
	if loading:
		return
	editor.session.cancel_edit()
	project = ScurkProject.new()
	project.initialize(bytes)
	project.metadata["editor_state"] = {"blank_shape_ids": [], "unclipped_tile_ids": []}
	project_path = ""
	recovery_owned = false
	recovered_source = ""
	modified = false
	last_key = ""
	saved_pixels.clear()
	saved_state = project.snapshot()
	saved_checkpoints.clear()
	object_start.clear()
	autosave_revision = -1
	_refresh_lists()
	_refresh_metadata()


func key(view := -1) -> String:
	return "%d:%d" % [editor.current_large_id, editor.current_view if view < 0 else view]


func bind_canvas() -> void:
	var canvas := editor.pixel_canvas
	if editor.current_large_id < 0 or canvas.pixels.is_empty():
		return
	var current := key()
	if not project.ensure_document(current, canvas.pixels, canvas.sprite_width, canvas.sprite_height):
		editor._show_error("This layer size does not match the selected tile.")
		return
	var document: Dictionary = project.documents[current]
	if saved_state.has("documents") and not saved_state.documents.has(current):
		saved_state.documents[current] = document.duplicate(true)
	if not saved_pixels.has(current):
		saved_pixels[current] = document.original_pixels.duplicate()
	var keep := current == last_key
	canvas.set_sprite_data(int(document.width), int(document.height), project.active_pixels(current), editor.palette, keep)
	canvas.layer_below_pixels = project.flatten_range(current, 0, int(document.active))
	canvas.layer_above_pixels = project.flatten_range(current, int(document.active) + 1, document.layers.size())
	get_node(LAYERS + "/Row/Actions/Delete").disabled = document.layers.size() <= 1
	var active: Dictionary = document.layers[int(document.active)]
	canvas.active_layer_visible = bool(active.visible)
	canvas.editing_disabled = bool(active.locked) or not bool(active.visible)
	canvas.comparison_pixels = saved_pixels.get(current, document.original_pixels).duplicate()
	last_key = current
	editor.palette_panel.set_used_pixels(project.flatten(current))
	_refresh_layers()
	if $Context.visible:
		_refresh_context()


func restore(state: Dictionary) -> void:
	if state.is_empty():
		project.documents.clear()
		return
	project.restore_snapshot(state)
	refresh_restored_state()


func refresh_restored_state(update_modified_state := true) -> void:
	restore_editor_state()
	last_key = ""
	loading = true
	editor.palette_panel.import_state(palette_state())
	loading = false
	if update_modified_state:
		update_modified()
	_refresh_lists()
	_refresh_metadata()


func _tab_changed(index: int) -> void:
	if index == 1:
		_refresh_layers()
	elif index in [2, 3]:
		_refresh_lists()


func _refresh_metadata() -> void:
	get_node(META + "/Author").text = String(project.metadata.get("author", ""))
	get_node(META + "/Title").text = String(project.metadata.get("title", ""))
	get_node(META + "/Notes").text = String(project.metadata.get("notes", ""))


func show_paint() -> void:
	$Paint/Content/Shade.set_pressed_no_signal(editor.current_tool == ScurkPixelCanvas.TOOL_SHADE)
	$Paint/Content/Stamp.set_pressed_no_signal(editor.current_tool == ScurkPixelCanvas.TOOL_STAMP)
	$Paint.popup_centered()


func show_replace() -> void:
	$Replace/Content/Fields/From.value = editor.foreground_palette_index
	$Replace/Content/Fields/To.value = editor.background_palette_index
	$Replace.popup_centered()


func request_open() -> void:
	$OpenProject.popup_centered_ratio(0.75)


func request_save(save_as := false) -> void:
	if not save_as and not project_path.is_empty():
		save_project(project_path)
		return
	var directory := ProjectSettings.globalize_path("user://scurk/projects") if project_path.is_empty() else project_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	$SaveProject.current_dir = directory
	$SaveProject.current_file = "Untitled.scurk" if project_path.is_empty() else project_path.get_file()
	$SaveProject.popup_centered_ratio(0.75)


func load_project(path: String, recovered := false) -> bool:
	var loaded := ScurkProject.load_path(path)
	if not loaded.ok:
		editor._show_error(loaded.error)
		return false
	var mif := ScurkMif.new()
	if not mif.parse(loaded.project.current_mif):
		editor._show_error(mif.parse_error)
		return false
	loading = true
	project = loaded.project
	last_key = ""
	saved_pixels.clear()
	for name: String in project.documents:
		saved_pixels[name] = project.flatten(name)
	var result := editor.load_tile_set(mif)
	loading = false
	if not result.ok:
		editor._show_error(result.error)
		return false
	project_path = "" if recovered else ProjectSettings.globalize_path(path)
	recovery_owned = recovered and ProjectSettings.globalize_path(path) == ProjectSettings.globalize_path(recovery_path)
	recovered_source = path if recovered else ""
	loading = true
	editor.palette_panel.import_state(palette_state())
	loading = false
	saved_state = project.snapshot()
	saved_checkpoints = project.checkpoints.duplicate(true)
	_refresh_lists()
	_refresh_metadata()
	modified = recovered
	editor._update_title()
	editor._set_status("Recovered project." if recovered else "Loaded %s." % path.get_file())
	return true


func save_project(path: String) -> bool:
	if path.get_extension().to_lower() != "scurk":
		path += ".scurk"
	if editor.path_is_within(path, editor.reference_directory):
		editor._show_error("The original game data folder is read-only. Use another folder.")
		return false
	sync_editor_state()
	project.set_current_mif(editor.tile_set.to_bytes().bytes)
	project.metadata["palette"] = editor.palette_panel.export_state()
	var result := project.save_path(path)
	if not result.ok:
		editor._show_error(result.error)
		return false
	project_path = ProjectSettings.globalize_path(path)
	modified = false
	saved_state = project.snapshot()
	saved_checkpoints = project.checkpoints.duplicate(true)
	editor.edit_history.mark_saved(project.current_mif)
	saved_pixels.clear()
	for name: String in project.documents:
		saved_pixels[name] = project.flatten(name)
	editor.pixel_canvas.comparison_pixels = saved_pixels.get(key(), PackedInt32Array())
	editor._update_title()
	editor._set_status("Saved %s." % path.get_file())
	if recovery_owned and FileAccess.file_exists(recovery_path) and ProjectSettings.globalize_path(recovery_path).simplify_path() != project_path.simplify_path():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(recovery_path))
	if not recovered_source.is_empty() and FileAccess.file_exists(recovered_source) and ProjectSettings.globalize_path(recovered_source).simplify_path() != project_path.simplify_path():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(recovered_source))
	recovery_owned = false
	recovered_source = ""
	return true


func check_recovery() -> void:
	if recovery_checked:
		return
	recovery_checked = true
	if FileAccess.file_exists(recovery_path):
		$Recovery.popup_centered()


func _process(delta: float) -> void:
	if editor == null or not editor.is_visible_in_tree() or not modified:
		return
	autosave_elapsed += delta
	if autosave_elapsed < 30.0:
		return
	autosave_elapsed = 0.0
	autosave()


func autosave() -> bool:
	if project.current_mif.is_empty():
		return false
	sync_editor_state()
	project.set_current_mif(editor.tile_set.to_bytes().bytes)
	if FileAccess.file_exists(recovery_path) and not recovery_owned:
		var archived := "%s/recovery-%d-%d.scurk" % [recovery_path.get_base_dir(), Time.get_unix_time_from_system(), Time.get_ticks_usec()]
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(recovery_path), ProjectSettings.globalize_path(archived)) != OK:
			editor._set_status("Cannot preserve the previous recovery file.")
			return false
	var result := project.autosave_path(recovery_path)
	if result.ok:
		recovery_owned = true
	if not result.ok:
		editor._set_status("Autosave failed: " + result.error)
	return result.ok


func _refresh_layers() -> void:
	if editor == null or not project.documents.has(key()):
		return
	updating_controls = true
	var document: Dictionary = project.documents[key()]
	var list := get_node(LAYERS + "/Row/List") as ItemList
	list.clear()
	for index in range(document.layers.size() - 1, -1, -1):
		var layer: Dictionary = document.layers[index]
		list.add_item("%s%s%s" % [layer.name, " (hidden)" if not layer.visible else "", " (locked)" if layer.locked else ""])
		list.set_item_metadata(list.item_count - 1, index)
	list.select(document.layers.size() - 1 - int(document.active))
	var active: Dictionary = document.layers[int(document.active)]
	get_node(LAYERS + "/Name").text = active.name
	get_node(LAYERS + "/State/Visible").set_pressed_no_signal(active.visible)
	get_node(LAYERS + "/State/Locked").set_pressed_no_signal(active.locked)
	updating_controls = false


func _select_layer(index: int) -> void:
	if updating_controls:
		return
	editor.pixel_canvas.cancel_paste()
	project.select_layer(key(), index)
	editor._refresh_sprite()


func _layer_action(action: String) -> void:
	if not project.documents.has(key()):
		return
	var index := int(project.documents[key()].active)
	if action == "Delete":
		if project.documents[key()].layers.size() <= 1:
			return
		pending_delete_key = key()
		pending_delete_layer = project.documents[key()].layers[index]
		$DeleteLayer.dialog_text = 'Delete layer "%s"?' % pending_delete_layer.name
		$DeleteLayer.popup_centered()
		return
	editor.pixel_canvas.cancel_paste()
	if not editor._capture_edit_start(action + " layer"):
		return
	match action:
		"Add": project.add_layer(key(), "Layer %d" % (project.documents[key()].layers.size() + 1))
		"Up": project.move_layer(key(), index, index + 1)
		"Down": project.move_layer(key(), index, index - 1)
		"Rename": project.rename_layer(key(), index, get_node(LAYERS + "/Name").text)
	_flush_layers()


func _layer_visible(enabled: bool) -> void:
	if updating_controls:
		return
	if not editor._capture_edit_start("Layer visibility"):
		return
	project.set_layer_visible(key(), int(project.documents[key()].active), enabled)
	_flush_layers()


func _layer_locked(enabled: bool) -> void:
	if updating_controls:
		return
	if not editor._capture_edit_start("Layer lock"):
		return
	project.set_layer_locked(key(), int(project.documents[key()].active), enabled)
	_flush_layers()


func _flush_layers() -> void:
	committing_layer = true
	editor._commit_pixels(project.flatten(key()))
	committing_layer = false
	_refresh_layers()


func _confirm_delete_layer() -> void:
	if key() == pending_delete_key and project.documents.has(pending_delete_key):
		var layers: Array = project.documents[pending_delete_key].layers
		for index in layers.size():
			if is_same(layers[index], pending_delete_layer):
				editor.pixel_canvas.cancel_paste()
				if not editor._capture_edit_start("Delete layer"):
					return
				if project.delete_layer(pending_delete_key, index):
					_flush_layers()
				break
	_cancel_delete_layer()


func _cancel_delete_layer() -> void:
	pending_delete_key = ""
	pending_delete_layer = {}


func refresh_history() -> void:
	var history := get_node(HISTORY + "/List") as ItemList
	history.clear()
	history.add_item("Earlier state")
	for action: ScurkEditorHistory.Record in editor.undo_stack:
		history.add_item(action.description)
	for index in range(editor.redo_stack.size() - 1, -1, -1):
		history.add_item(editor.redo_stack[index].description)
		history.set_item_custom_fg_color(history.item_count - 1, Color(0.5, 0.5, 0.5))
	history.select(editor.undo_stack.size())
	history.ensure_current_is_visible()
	get_node(HISTORY + "/Actions/Undo").disabled = not editor.edit_history.can_undo()
	get_node(HISTORY + "/Actions/Redo").disabled = not editor.edit_history.can_redo()


func _select_history(index: int) -> void:
	while editor.undo_stack.size() != index:
		var previous := editor.undo_stack.size()
		if previous > index:
			editor.undo()
		else:
			editor.redo()
		if editor.undo_stack.size() == previous:
			break


func _refresh_lists() -> void:
	refresh_history()
	var stamps := get_node(STAMPS + "/List") as ItemList
	stamps.clear()
	for stamp: Dictionary in project.stamps:
		stamps.add_item("%s (%d x %d)" % [stamp.name, stamp.width, stamp.height])


func _metadata_changed() -> void:
	if not editor._capture_edit_start("Edit metadata"):
		return
	project.metadata["author"] = get_node(META + "/Author").text
	project.metadata["title"] = get_node(META + "/Title").text
	project.metadata["notes"] = get_node(META + "/Notes").text
	editor._record_edit()


func _palette_state_changed(state: Dictionary) -> void:
	if loading or project.current_mif.is_empty():
		return
	project.metadata["palette"] = state.duplicate(true)
	modified = true
	editor._update_title()


func _paint_options_changed() -> void:
	var canvas := editor.pixel_canvas
	canvas.paint_options.lock_transparent = $Paint/Content/Lock.button_pressed
	canvas.paint_options.pixel_perfect = $Paint/Content/Perfect.button_pressed
	canvas.paint_options.isometric_snap = $Paint/Content/Iso.button_pressed
	canvas.show_isometric_guides = $Paint/Content/Guides.button_pressed
	var spacing := roundi($Paint/Content/GuideFields/Spacing.value)
	canvas.paint_options.guide_spacing = Vector2i(spacing, maxi(1, spacing / 2))
	canvas.paint_options.guide_offset = Vector2i(roundi($Paint/Content/GuideFields/OffsetX.value), roundi($Paint/Content/GuideFields/OffsetY.value))
	if $Paint/Content/Stamp.button_pressed:
		editor._select_tool(ScurkPixelCanvas.TOOL_STAMP)
	elif $Paint/Content/Shade.button_pressed:
		editor._select_tool(ScurkPixelCanvas.TOOL_SHADE)
	elif editor.current_tool in [ScurkPixelCanvas.TOOL_SHADE, ScurkPixelCanvas.TOOL_STAMP]:
		editor._select_tool(ScurkPixelCanvas.TOOL_PENCIL)
	canvas.queue_redraw()


func _stamp_action(action: String) -> void:
	var list := get_node(STAMPS + "/List") as ItemList
	var selected := list.get_selected_items()
	if action == "Add":
		if not editor.pixel_canvas.copy_selection(false):
			editor._set_status("Select pixels to save a stamp.")
			return
		var name := String(get_node(STAMPS + "/Name").text).strip_edges()
		if name.is_empty():
			name = "Stamp %d" % (project.stamps.size() + 1)
		if not editor._capture_edit_start("Add stamp"):
			return
		project.add_stamp(name, editor.pixel_canvas.clipboard_width, editor.pixel_canvas.clipboard_height,
			editor.pixel_canvas.clipboard_pixels, editor.pixel_canvas.paint_options.stamp_spacing)
		editor._record_edit()
	elif not selected.is_empty():
		if action == "Delete":
			if not editor._capture_edit_start("Delete stamp"):
				return
			project.remove_stamp(selected[0])
			editor._record_edit()
		elif action == "Use":
			var stamp: Dictionary = project.stamps[selected[0]]
			editor.pixel_canvas.paint_options.set_stamp(stamp.width, stamp.height, stamp.pixels)
			editor.pixel_canvas.paint_options.stamp_spacing = stamp.spacing
			get_node(STAMPS + "/Spacing/Value").value = stamp.spacing
			editor._select_tool(ScurkPixelCanvas.TOOL_STAMP)
			if editor.pixel_canvas.is_inside_tree():
				editor.pixel_canvas.grab_focus()
	_refresh_lists()


func _replace_colors() -> void:
	var from := roundi($Replace/Content/Fields/From.value)
	var to := roundi($Replace/Content/Fields/To.value)
	if from == to:
		return
	if not editor._capture_edit_start("Replace colors"):
		return
	var old_view := editor.current_view
	var selection := editor.pixel_canvas.selected_mask()
	var views := range(ScurkSpriteIds.VIEW_COUNT) if $Replace/Content/AllViews.button_pressed else [old_view]
	for view: int in views:
		if not editor._view_is_available(view):
			continue
		editor.current_view = view
		editor._refresh_sprite()
		var document: Dictionary = project.documents[key()]
		for layer: Dictionary in document.layers:
			if layer.locked:
				continue
			var pixels: PackedInt32Array = layer.pixels
			for offset in pixels.size():
				if pixels[offset] == from and (selection.size() != pixels.size() or selection[offset] != 0):
					pixels[offset] = to
		committing_layer = true
		var written := editor._write_pixels(project.flatten(key()))
		committing_layer = false
		if not written:
			editor.current_view = old_view
			editor._refresh_sprite()
			return
	editor.current_view = old_view
	editor._record_edit()
	editor._refresh_sprite()


func preview_import(path: String) -> void:
	imported = ScurkImageImport.load_path(path, editor.palette)
	if not imported.ok:
		editor._show_error(imported.error)
		return
	if imported.width > 128 or imported.height > 256:
		editor._show_error("SCURK graphics cannot be larger than 128 by 256 pixels.")
		return
	imported_path = path
	$ImportPreview/Content/Placement/X.set_value_no_signal((editor.pixel_canvas.sprite_width - imported.width) / 2)
	$ImportPreview/Content/Placement/Y.set_value_no_signal(editor.pixel_canvas.sprite_height - imported.height)
	_refresh_import()
	$ImportPreview.popup_centered()


func _import_pixels() -> PackedInt32Array:
	var canvas := editor.pixel_canvas
	var result := PackedInt32Array()
	result.resize(canvas.sprite_width * canvas.sprite_height)
	result.fill(-1)
	import_clipped = 0
	var origin := Vector2i(roundi($ImportPreview/Content/Placement/X.value), roundi($ImportPreview/Content/Placement/Y.value))
	for y in imported.height:
		for x in imported.width:
			var value := imported.pixels[y * imported.width + x]
			if value < 0:
				continue
			var point := origin + Vector2i(x, y)
			if not canvas._point_is_editable(point):
				import_clipped += 1
			else:
				result[point.y * canvas.sprite_width + point.x] = value
	return result


func _refresh_import() -> void:
	var pixels := _import_pixels()
	var canvas := editor.pixel_canvas
	$ImportPreview/Content/Image.texture = ScurkContextPreview.indexed_texture(pixels, canvas.sprite_width, canvas.sprite_height, editor.palette)
	$ImportPreview/Content/Summary.text = "%d x %d pixels; %d colors remapped; %d pixels clipped.\nTransparent pixels are preserved. Imports replace the active layer." % [imported.width, imported.height, imported.remapped_color_count, import_clipped]
	$ImportPreview.get_ok_button().disabled = canvas.editing_disabled


func _apply_import() -> void:
	if imported == null or editor.pixel_canvas.editing_disabled:
		return
	if not editor._capture_edit_start("Import image"):
		return
	editor._commit_pixels(_import_pixels())
	editor._set_status("Imported %s." % imported_path.get_file())


func show_context() -> void:
	context_view = editor.current_view
	_refresh_context()
	$Context.popup_centered()


func _select_context_view(value: int) -> void:
	if not editor._view_is_available(value):
		return
	context_view = value
	_refresh_context()


func _refresh_context() -> void:
	var view := $Context/Content/View as ScurkContextPreview
	for index in ScurkSpriteIds.VIEW_COUNT:
		var button := get_node("Context/Content/Options/" + ["Large", "Medium", "Small"][index]) as Button
		button.disabled = not editor._view_is_available(index)
		button.set_pressed_no_signal(index == context_view)
	var shape := editor._output_shape_for_view(context_view)
	if not shape.ok:
		return
	var city_view: int = [CityIsometricRenderer.VIEW_LARGE, CityIsometricRenderer.VIEW_MEDIUM, CityIsometricRenderer.VIEW_SMALL][context_view]
	view.configure(shape.pixels, shape.width, shape.height,
		maxi(1, editor.active_base_width / 32), editor.palette,
		Sc2SpriteArchive.combine([editor.base_large_sprites, editor.base_small_medium_sprites, editor.tile_set.overrides]), city_view)


func update_modified() -> void:
	var current := project.snapshot()
	current.metadata.erase("editor_state")
	var saved := saved_state.duplicate(true)
	if saved.has("metadata"):
		saved.metadata.erase("editor_state")
	for name: String in current.documents:
		if saved.has("documents") and saved.documents.has(name):
			saved.documents[name].active = current.documents[name].active
	modified = current != saved or project.checkpoints != saved_checkpoints


func sync_editor_state() -> void:
	var unclipped: Array = []
	for id: int in editor.unclipped_tiles:
		if editor.unclipped_tiles[id]:
			unclipped.append(id)
	project.metadata["editor_state"] = {
		"blank_shape_ids": Array(editor.edit_history.blank_shape_ids.keys()),
		"unclipped_tile_ids": unclipped, "tile": editor.current_large_id, "view": editor.current_view,
	}


func restore_editor_state() -> void:
	var value: Variant = project.metadata.get("editor_state", {})
	var state: Dictionary = value if value is Dictionary else {}
	editor.edit_history.blank_shape_ids.clear()
	for id: Variant in _id_list(state.get("blank_shape_ids", [])):
		if (id is int or id is float) and int(id) >= ScurkSpriteIds.SMALL_FIRST and int(id) < ScurkSpriteIds.SPRITE_COUNT:
			editor.edit_history.blank_shape_ids[int(id)] = true
	editor.unclipped_tiles.clear()
	for id: Variant in _id_list(state.get("unclipped_tile_ids", [])):
		if (id is int or id is float) and int(id) >= ScurkSpriteIds.LARGE_FIRST and int(id) <= ScurkSpriteIds.LARGE_LAST:
			editor.unclipped_tiles[int(id)] = true
	var tile_value: Variant = state.get("tile", editor.current_large_id)
	var tile := int(tile_value) if tile_value is int or tile_value is float else editor.current_large_id
	if editor.editable_large_sprite_ids(editor.tile_set, editor.base_large_sprites).has(tile):
		editor.current_large_id = tile
		var view_value: Variant = state.get("view", ScurkSpriteIds.View.LARGE)
		editor.current_view = clampi(int(view_value), ScurkSpriteIds.View.LARGE, ScurkSpriteIds.View.SMALL) if view_value is int or view_value is float else ScurkSpriteIds.View.LARGE


func ensure_view(view: int) -> bool:
	if project.documents.has(key(view)):
		return true
	var entry: Sc2SpriteArchive.SpriteEntry = editor._resolved_view_entry(view)
	if entry == null:
		return false
	var decoded := entry.decode_indices()
	if not decoded.ok:
		return false
	var pixels := Workspace.from_shape(entry.width, entry.height, decoded.pixels, view, editor.active_base_width, editor._clipping_enabled()) if editor.active_workspace else decoded.pixels
	return project.ensure_document(key(view), pixels, Workspace.WIDTH if editor.active_workspace else entry.width, Workspace.HEIGHT if editor.active_workspace else entry.height)


func clear_view(view: int) -> void:
	if not project.documents.has(key(view)):
		return
	var document: Dictionary = project.documents[key(view)]
	var blank := PackedInt32Array()
	blank.resize(int(document.width) * int(document.height))
	blank.fill(-1)
	document.layers = [{"name": "Root", "visible": true, "locked": false, "pixels": blank}]
	document.active = 0


func palette_state() -> Dictionary:
	var value: Variant = project.metadata.get("palette", {})
	return value if value is Dictionary else {}


func _id_list(value: Variant) -> Array:
	return value if value is Array and value.size() <= MAX_SAVED_ID_LIST_SIZE else []


func request_recovery() -> void:
	if editor.dirty:
		editor.pending_discard_action = "recover"
		editor.discard_dialog.dialog_text = "Discard the unsaved changes and recover another project?"
		editor.discard_dialog.popup_centered()
		return
	show_recovery_files()


func show_recovery_files() -> void:
	$RecoveryFiles.current_dir = ProjectSettings.globalize_path(recovery_path.get_base_dir())
	$RecoveryFiles.popup_centered_ratio(0.75)


func discard_recovery() -> void:
	if recovery_owned:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(recovery_path))
		recovery_owned = false
