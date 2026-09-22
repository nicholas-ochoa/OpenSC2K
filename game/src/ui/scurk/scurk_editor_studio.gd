class_name ScurkEditorStudio
extends PanelContainer

@warning_ignore_start("integer_division")

const Workspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")
const LAYERS := "Margin/Tabs/Layers"
const HISTORY := "Margin/Tabs/History"
const META := "Margin/Tabs/Metadata"
const STAMPS := "Margin/Tabs/Stamps"

var tabs: TabContainer
var editor: ScurkEditorControl
var project := ScurkProject.new()
var project_path := ""
var recovery_path := "user://scurk/recovery.scurk"
var modified := false
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
var context_view := 0
var updating_controls := false


func bind(value: ScurkEditorControl) -> void:
	editor = value
	AppUiTheme.bind_frosted_panel(self)
	tabs = $Margin/Tabs
	tabs.tab_changed.connect(_tab_changed)
	for dialog: FileDialog in [$OpenProject, $SaveProject, $RecoveryFiles]:
		dialog.theme = AppUiTheme.file_dialog()
	$RecoveryFiles.file_selected.connect(func(path: String) -> void: load_project(path, true))
	$OpenProject.file_selected.connect(load_project)
	$SaveProject.file_selected.connect(save_project)
	$Recovery.confirmed.connect(func() -> void: load_project(recovery_path, true))
	get_node(LAYERS + "/List").item_selected.connect(func(row: int) -> void:
		_select_layer(int(get_node(LAYERS + "/List").get_item_metadata(row))))
	for action in ["Add", "Delete", "Up", "Down", "Rename"]:
		get_node(LAYERS + "/Actions/" + action).pressed.connect(_layer_action.bind(action))
	get_node(LAYERS + "/State/Visible").toggled.connect(_layer_visible)
	get_node(LAYERS + "/State/Locked").toggled.connect(_layer_locked)
	get_node(HISTORY + "/Actions/Add").pressed.connect(_add_checkpoint)
	get_node(HISTORY + "/Actions/Restore").pressed.connect(_restore_checkpoint)
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
	for view in 3:
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
	for button: Button in get_node(LAYERS + "/Actions").get_children():
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var color_name := "font_color" if state == "normal" else "font_%s_color" % state
			button.add_theme_color_override(
				"icon_%s_color" % state, button.get_theme_color(color_name, "Button")
			)


func reset(bytes: PackedByteArray) -> void:
	if loading:
		return
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
	canvas.layer_below_pixels = _composite_range(document, 0, int(document.active))
	canvas.layer_above_pixels = _composite_range(document, int(document.active) + 1, document.layers.size())
	var active: Dictionary = document.layers[int(document.active)]
	canvas.active_layer_visible = bool(active.visible)
	canvas.editing_disabled = bool(active.locked) or not bool(active.visible)
	canvas.comparison_pixels = saved_pixels.get(current, document.original_pixels).duplicate()
	last_key = current
	editor.palette_panel.set_used_pixels(project.flatten(current))
	_refresh_layers()
	if $Context.visible:
		_refresh_context()


func _composite_range(document: Dictionary, first: int, last: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(int(document.width) * int(document.height))
	result.fill(-1)
	for index in range(first, last):
		var layer: Dictionary = document.layers[index]
		if not bool(layer.visible):
			continue
		var pixels: PackedInt32Array = layer.pixels
		for offset in result.size():
			if pixels[offset] >= 0:
				result[offset] = pixels[offset]
	return result


func capture() -> void:
	if editor == null or project.current_mif.is_empty():
		return
	sync_editor_state()
	editor.edit_history.pending_project_before = project.snapshot()


func prepare_pixels(pixels: PackedInt32Array) -> PackedInt32Array:
	if not project.documents.has(key()):
		return pixels
	if not project.set_active_pixels(key(), pixels):
		return project.flatten(key())
	return project.flatten(key())


func record() -> void:
	sync_editor_state()
	if project.current_mif.is_empty():
		return
	var encoded := editor.tile_set.to_bytes()
	if encoded.ok:
		project.set_current_mif(encoded.bytes)
	editor.edit_history.pending_project_after = project.snapshot()
	update_modified()


func restore(state: Dictionary) -> void:
	if state.is_empty():
		project.documents.clear()
		return
	project.restore_snapshot(state)
	restore_editor_state()
	last_key = ""
	loading = true
	editor.palette_panel.import_state(palette_state())
	loading = false
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
	var list := get_node(LAYERS + "/List") as ItemList
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
	editor.pixel_canvas.cancel_paste()
	editor._capture_edit_start()
	var index := int(project.documents[key()].active)
	match action:
		"Add": project.add_layer(key(), "Layer %d" % (project.documents[key()].layers.size() + 1))
		"Delete": project.delete_layer(key(), index)
		"Up": project.move_layer(key(), index, index + 1)
		"Down": project.move_layer(key(), index, index - 1)
		"Rename": project.rename_layer(key(), index, get_node(LAYERS + "/Name").text)
	_flush_layers()


func _layer_visible(enabled: bool) -> void:
	if updating_controls:
		return
	editor._capture_edit_start()
	project.set_layer_visible(key(), int(project.documents[key()].active), enabled)
	_flush_layers()


func _layer_locked(enabled: bool) -> void:
	if updating_controls:
		return
	editor._capture_edit_start()
	project.set_layer_locked(key(), int(project.documents[key()].active), enabled)
	_flush_layers()


func _flush_layers() -> void:
	committing_layer = true
	editor._commit_pixels(project.flatten(key()))
	committing_layer = false
	_refresh_layers()


func _refresh_lists() -> void:
	var history := get_node(HISTORY + "/List") as ItemList
	history.clear()
	for checkpoint: Dictionary in project.checkpoints:
		history.add_item(String(checkpoint.name))
	var stamps := get_node(STAMPS + "/List") as ItemList
	stamps.clear()
	for stamp: Dictionary in project.stamps:
		stamps.add_item("%s (%d x %d)" % [stamp.name, stamp.width, stamp.height])


func _add_checkpoint() -> void:
	var name := String(get_node(HISTORY + "/Name").text).strip_edges()
	if name.is_empty():
		name = "Checkpoint %d" % (project.checkpoints.size() + 1)
	sync_editor_state()
	project.set_current_mif(editor.tile_set.to_bytes().bytes)
	if project.add_checkpoint(name) >= 0:
		modified = true
	_refresh_lists()
	editor._update_title()


func _restore_checkpoint() -> void:
	var selected := (get_node(HISTORY + "/List") as ItemList).get_selected_items()
	if selected.is_empty():
		return
	editor._capture_edit_start()
	if project.restore_checkpoint(selected[0]):
		editor.pixel_canvas.cancel_paste()
		restore_editor_state()
		loading = true
		editor.palette_panel.import_state(palette_state())
		loading = false
		editor._replace_document_bytes(project.current_mif)
		editor._record_edit(editor.edit_history.pending_edit_before)
		editor._refresh_sprite()
		_refresh_lists()
		_refresh_metadata()


func _metadata_changed() -> void:
	editor._capture_edit_start()
	project.metadata["author"] = get_node(META + "/Author").text
	project.metadata["title"] = get_node(META + "/Title").text
	project.metadata["notes"] = get_node(META + "/Notes").text
	editor._record_edit(editor.edit_history.pending_edit_before)


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
		if not editor.pixel_canvas.copy_selection():
			editor._set_status("Select pixels to save a stamp.")
			return
		var name := String(get_node(STAMPS + "/Name").text).strip_edges()
		if name.is_empty():
			name = "Stamp %d" % (project.stamps.size() + 1)
		editor._capture_edit_start()
		project.add_stamp(name, editor.pixel_canvas.clipboard_width, editor.pixel_canvas.clipboard_height,
			editor.pixel_canvas.clipboard_pixels, editor.pixel_canvas.paint_options.stamp_spacing)
		editor._record_edit(editor.edit_history.pending_edit_before)
	elif not selected.is_empty():
		if action == "Delete":
			editor._capture_edit_start()
			project.remove_stamp(selected[0])
			editor._record_edit(editor.edit_history.pending_edit_before)
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
	editor._capture_edit_start()
	var old_view := editor.current_view
	var selection := editor.pixel_canvas.selected_mask()
	var views := [0, 1, 2] if $Replace/Content/AllViews.button_pressed else [old_view]
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
		editor._write_pixels(project.flatten(key()))
		committing_layer = false
	editor.current_view = old_view
	editor._record_edit(editor.edit_history.pending_edit_before)
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
	editor._capture_edit_start()
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
	for index in 3:
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
		if (id is int or id is float) and int(id) >= 0 and int(id) < 1500:
			editor.edit_history.blank_shape_ids[int(id)] = true
	editor.unclipped_tiles.clear()
	for id: Variant in _id_list(state.get("unclipped_tile_ids", [])):
		if (id is int or id is float) and int(id) >= 1000 and int(id) < 1500:
			editor.unclipped_tiles[int(id)] = true
	var tile_value: Variant = state.get("tile", editor.current_large_id)
	var tile := int(tile_value) if tile_value is int or tile_value is float else editor.current_large_id
	if editor.editable_large_sprite_ids(editor.tile_set, editor.base_large_sprites).has(tile):
		editor.current_large_id = tile
		var view_value: Variant = state.get("view", 0)
		editor.current_view = clampi(int(view_value), 0, 2) if view_value is int or view_value is float else 0


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
	return value if value is Array and value.size() <= 1500 else []


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
