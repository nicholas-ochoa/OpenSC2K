extends SceneTree

var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for object_id in 500:
		_check(ScurkEditorRules.object_tile_id(1000 + object_id) == object_id)
		for view in 3:
			_check(ScurkEditorRules.view_sprite_id(1000 + object_id, view) == 1000 + object_id - view * 500)

	for large_id in [-1, 0, 999, 1500, 65535]:
		_check(ScurkEditorRules.object_tile_id(large_id) == -1)
		for view in 3:
			_check(ScurkEditorRules.view_sprite_id(large_id, view) == -1)

	for view in [-1, 3, 99]:
		_check(ScurkEditorRules.view_sprite_id(1000, view) == -1)
		_check(ScurkEditorRules.view_sprite_id(1499, view) == -1)

	_test_editable_ids()
	_test_placeable_ids()
	_test_copy()
	_test_saved_editor_ids()
	_test_view_clamps()
	print("PASS: SCURK sprite conversion, bounds, selection, copy, saved IDs, and view clamps (%d checks)" % checks)
	quit()


func _test_placeable_ids() -> void:
	var ids := ScurkPlaceCommand.placeable_large_ids(10)
	_check(ids.size() == 500)
	for object_id in 500:
		_check(ids[object_id] == 1000 + object_id)
		_check(ScurkPlaceCommand.is_placeable_tile(object_id))
	_check(not ScurkPlaceCommand.is_placeable_tile(-1))
	_check(not ScurkPlaceCommand.is_placeable_tile(500))
	var networks := ScurkPickCopy.group_large_ids(5)
	for object_id in range(0x0e, 0x70):
		networks.append(1000 + object_id)
	_check(ScurkPlaceCommand.placeable_large_ids(5) == networks)


func _test_editable_ids() -> void:
	_check(ScurkEditorRules.editable_large_sprite_ids(null).is_empty())
	var source := ScurkMif.from_archives([])
	for id in [1500, 1499, 999, 1000]:
		_check(source.set_shape_indices(id, 1, 1, PackedInt32Array([id % 256])).ok)
	var base := ScurkMif.from_archives([])
	for id in [1499, 1001, 0]:
		_check(base.set_shape_indices(id, 1, 1, PackedInt32Array([1])).ok)
	_check(ScurkEditorRules.editable_large_sprite_ids(source, base.archive) == PackedInt32Array([1000, 1001, 1499]))
	_check(ScurkEditorRules.editable_large_sprite_ids(source) == PackedInt32Array([1000, 1499]))


func _test_copy() -> void:
	var source := _object_set()
	var working := ScurkMif.from_archives([])
	var source_bytes: PackedByteArray = source.to_bytes().bytes
	var result := ScurkPickCopy.copy_objects(working, source, PackedInt32Array([1007, 1007]), source.archive, source.archive)
	_check(result.ok and result.object_count == 1 and result.shape_count == 3)
	_check(working.to_bytes().bytes == source_bytes)
	_check(source.to_bytes().bytes == source_bytes)
	for view in 3:
		var entry := working.archive.find_sprite(1007 - view * 500)
		_check(entry != null and entry.width == 2 and entry.height == 2)
		_check(entry.decode_indices().pixels == PackedInt32Array([view, -1, 255, 20 + view]))

	for invalid_id in [999, 1500]:
		result = ScurkPickCopy.copy_objects(working, source, PackedInt32Array([1007, invalid_id]), source.archive, source.archive)
		_check(not result.ok)
		_check(working.to_bytes().bytes == source_bytes)

	var incomplete := ScurkMif.from_archives([])
	_check(incomplete.set_shape_indices(1007, 1, 1, PackedInt32Array([42])).ok)
	result = ScurkPickCopy.copy_objects(working, incomplete, PackedInt32Array([1007]), incomplete.archive, incomplete.archive)
	_check(not result.ok and working.to_bytes().bytes == source_bytes)
	result = ScurkPickCopy.copy_objects(working, working, PackedInt32Array([1007]), source.archive, source.archive)
	_check(not result.ok and working.to_bytes().bytes == source_bytes)
	result = ScurkPickCopy.copy_objects(working, source, PackedInt32Array([1007]), null, source.archive)
	_check(not result.ok and working.to_bytes().bytes == source_bytes)

	var transparent := ScurkMif.from_archives([])
	_check(transparent.set_shape_indices(1007, 2, 2, PackedInt32Array([-1, -1, -1, -1])).ok)
	result = ScurkPickCopy.copy_objects(working, transparent, PackedInt32Array([1007]), source.archive, source.archive)
	_check(result.ok and working.to_bytes().bytes == source_bytes)
	_check(ScurkPickCopy.group_large_ids(-1).is_empty())
	_check(ScurkPickCopy.group_large_ids(11).is_empty())
	for group in 10:
		var expected := PackedInt32Array()
		for object_id in ScurkPickCopy.GROUP_TILE_IDS[group]:
			expected.append(1000 + object_id)
		_check(ScurkPickCopy.group_large_ids(group) == expected)


func _object_set() -> ScurkMif:
	var value := ScurkMif.from_archives([])
	for view in 3:
		_check(value.set_shape_indices(1007 - view * 500, 2, 2, PackedInt32Array([view, -1, 255, 20 + view])).ok)
	return value


func _test_saved_editor_ids() -> void:
	var editor := ScurkEditorControl.new()
	editor.tile_set = _object_set()
	var studio := ScurkEditorStudio.new()
	studio.editor = editor
	var repeated_ids: Array = []
	repeated_ids.resize(1500)
	repeated_ids.fill(1499)
	studio.project.metadata.editor_state = {
		"blank_shape_ids": range(1500), "unclipped_tile_ids": repeated_ids,
		"tile": 1007, "view": 2,
	}
	studio.restore_editor_state()
	_check(editor.edit_history.blank_shape_ids.size() == 1500)
	_check(editor.edit_history.blank_shape_ids.has(0) and editor.edit_history.blank_shape_ids.has(1499))
	_check(editor.unclipped_tiles == {1499: true})
	_check(editor.current_large_id == 1007 and editor.current_view == 2)
	_check(studio.project.documents.is_empty())

	repeated_ids.append(1499)
	studio.project.metadata.editor_state.blank_shape_ids = range(1501)
	studio.project.metadata.editor_state.unclipped_tile_ids = repeated_ids
	studio.restore_editor_state()
	_check(editor.edit_history.blank_shape_ids.is_empty() and editor.unclipped_tiles.is_empty())

	var mixed_ids: Array = [-1, 0, 499, 500, 999, 1000, 1499, 1500, -0.75, 1499.75, "1000", true, null]
	studio.project.metadata.editor_state = {
		"blank_shape_ids": mixed_ids, "unclipped_tile_ids": mixed_ids,
		"tile": 1007.75, "view": 1.75,
	}
	studio.restore_editor_state()
	_check(editor.edit_history.blank_shape_ids == {0: true, 499: true, 500: true, 999: true, 1000: true, 1499: true})
	_check(editor.unclipped_tiles == {1000: true, 1499: true})
	_check(editor.current_large_id == 1007 and editor.current_view == 1)

	for pair in [[-1, 0], [3, 2], ["2", 0], [null, 0]]:
		studio.project.metadata.editor_state.view = pair[0]
		studio.restore_editor_state()
		_check(editor.current_view == pair[1])

	studio.project.metadata.editor_state = {"tile": 1500, "view": 0}
	editor.current_view = 2
	studio.restore_editor_state()
	_check(editor.current_large_id == 1007 and editor.current_view == 2)
	for invalid_list in [PackedInt32Array([1007]), {"id": 1007}, "1007", null]:
		studio.project.metadata.editor_state = {"blank_shape_ids": invalid_list, "unclipped_tile_ids": invalid_list}
		studio.restore_editor_state()
		_check(editor.edit_history.blank_shape_ids.is_empty() and editor.unclipped_tiles.is_empty())
	studio.free()
	editor.free()


func _test_view_clamps() -> void:
	var canvas := ScurkPixelCanvas.new()
	var preview := ScurkViewPreview.new()
	_check(canvas.background_view == 0 and preview.view == 0)
	for row in [[-1, 0, 128, 256], [0, 0, 128, 256], [1, 1, 64, 128], [2, 2, 32, 64], [3, 2, 32, 64]]:
		canvas.set_background_view(row[0])
		preview.clear_preview(row[0])
		_check(canvas.background_view == row[1] and preview.view == row[1])
		_check(preview.preview_width == row[2] and preview.preview_height == row[3])
	_check(ScurkDrawingWorkspace.clip_mask(32) == ScurkDrawingWorkspace.clip_mask(32, 0))
	_check(ScurkDrawingWorkspace.view_divisor(-1) == 1 and ScurkDrawingWorkspace.view_divisor(3) == 1)
	canvas.free()
	preview.free()


func _check(condition: bool) -> void:
	checks += 1
	assert(condition, "SCURK sprite check %d failed" % checks)
