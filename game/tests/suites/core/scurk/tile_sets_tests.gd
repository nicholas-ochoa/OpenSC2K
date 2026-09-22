extends "res://tests/support/core_test_suite.gd"

## Scurk: tile sets checks.

@warning_ignore_start("integer_division")

const Palette = preload("res://src/assets/sc2_palette.gd")
const IndexedBitmap = preload("res://src/assets/indexed_bmp.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const ScurkTileSet = preload("res://src/assets/scurk_mif.gd")
const ScurkEditor = preload("res://src/ui/scurk/scurk_editor_control.tscn")
const ScurkPickCopy = preload("res://src/tools/scurk/scurk_pick_copy.gd")
const ScurkWorkspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")
const ScurkPixelEditor = preload("res://src/view/scurk_pixel_canvas.gd")
const ScurkViewWindow = preload("res://src/view/scurk_view_preview.gd")
const ScurkPalette = preload("res://src/view/scurk_palette_control.gd")
const PlacementTests = preload("res://tests/suites/core/scurk/placement_tests.gd")
const IndexedBitmapTests = preload("res://tests/suites/core/scurk/indexed_bitmap_tests.gd")


func test_scurk_mif(reference_root: String) -> void:
	IndexedBitmapTests.new(context).test_indexed_bmp()
	PlacementTests.new(context).test_scurk_place_command(reference_root)
	var scurk_directory := reference_root.path_join("SCURKART")
	var mif_files := PackedStringArray()

	for filename in DirAccess.get_files_at(scurk_directory):
		if filename.get_extension().to_lower() == "mif":
			mif_files.append(filename)

	mif_files.sort()
	_check(mif_files.size() == 31, "All 31 supplied SCURK tile sets are present")

	for filename in mif_files:
		var mif_path := scurk_directory.path_join(filename)
		var tile_set := ScurkTileSet.load_path(mif_path)
		_check(tile_set.is_valid(), "%s parses: %s" % [filename, tile_set.parse_error])

		if tile_set.is_valid():
			var serialized := tile_set.to_bytes()
			_check(
				serialized.ok and serialized.bytes == FileAccess.get_file_as_bytes(mif_path),
				"%s has a byte-identical no-change write" % filename,
			)

	var original := ScurkTileSet.load_path(scurk_directory.path_join("ORIGINAL.MIF"))
	_check(original.is_valid(), "ORIGINAL.MIF parses: %s" % original.parse_error)

	if original.is_valid():
		var editable_ids := ScurkEditorControl.editable_large_sprite_ids(original)
		var grouped_ids := ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_ALL)
		var grouped_unique := {}

		for grouped_id in grouped_ids:
			grouped_unique[grouped_id] = true

		_check(
			original.piece_count == 558
			and original.shapes.size() == 558
			and original.overrides.entries.size() == 558
			and original.names.is_empty(),
			"ORIGINAL.MIF contains 558 visible SHAP records",
		)
		_check(
			editable_ids.size() == 186
			and ScurkEditorControl.view_sprite_id(editable_ids[0], ScurkEditorControl.VIEW_LARGE)
				== editable_ids[0]
			and ScurkEditorControl.view_sprite_id(editable_ids[0], ScurkEditorControl.VIEW_MEDIUM)
				== editable_ids[0] - 500
			and ScurkEditorControl.view_sprite_id(editable_ids[0], ScurkEditorControl.VIEW_SMALL)
				== editable_ids[0] - 1000,
			"SCURK editor exposes 186 objects with direct three-view sprite IDs",
		)
		_check(
			ScurkPickCopy.GROUP_NAMES.size() == 11
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_RESIDENTIAL).size() == 24
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_COMMERCIAL).size() == 28
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_INDUSTRIAL).size() == 18
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_SPECIAL).size() == 26
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_POWER).size() == 10
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_TRANSPORTATION).size() == 22
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_MISC).size() == 12
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_ANIMATING_I).size() == 15
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_ANIMATING_II).size() == 15
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_CONSTRUCTION).size() == 16
			and grouped_ids.size() == 186
			and grouped_unique.size() == 186,
			"SCURK Pick & Copy catalog contains all eleven original object groups",
		)
		var editor_palette := Palette.load_bmp(
			reference_root.path_join("BITMAPS/PAL_MSTR.BMP")
		)
		var editor_large := SpriteArchive.load_path(
			reference_root.path_join("DATA/LARGE.DAT")
		)
		var editor_small_medium := SpriteArchive.load_path(
			reference_root.path_join("DATA/SMALLMED.DAT")
		)
		var editor_special := SpriteArchive.load_path(
			reference_root.path_join("DATA/SPECIAL.DAT")
		)
		editor_small_medium = SpriteArchive.combine([
			editor_small_medium, editor_special,
		])
		var complete_editor_ids := ScurkEditorControl.editable_large_sprite_ids(
			original, editor_large
		)
		_check(
			complete_editor_ids.size() == 499
			and complete_editor_ids[0] == 1001
			and complete_editor_ids[complete_editor_ids.size() - 1] == 1499,
			"SCURK editor catalog exposes every original large sprite family",
		)
		var one_tile_mask := ScurkWorkspace.clip_mask(32)
		var four_tile_mask := ScurkWorkspace.clip_mask(128)
		_check(
			one_tile_mask.size() == 128 * 256
			and one_tile_mask[255 * 128 + 62] == 0
			and one_tile_mask[255 * 128 + 63] == 1
			and one_tile_mask[255 * 128 + 64] == 0
			and one_tile_mask[254 * 128 + 61] == 1
			and one_tile_mask[254 * 128 + 65] == 1
			and one_tile_mask[254 * 128 + 66] == 0
			and one_tile_mask[0 * 128 + 47] == 1
			and one_tile_mask[0 * 128 + 80] == 0
			and four_tile_mask[224 * 128 + 0] == 0
			and four_tile_mask[223 * 128 + 0] == 1,
			"SCURK clip mask follows the executable's bottom-up widening region",
		)
		var blank_workspace := PackedInt32Array()
		blank_workspace.resize(ScurkWorkspace.WIDTH * ScurkWorkspace.HEIGHT)
		blank_workspace.fill(-1)
		var blank_large := ScurkWorkspace.shape_from_workspace(blank_workspace, 32, 0)
		var blank_medium := ScurkWorkspace.shape_from_workspace(blank_workspace, 32, 1)
		var blank_small := ScurkWorkspace.shape_from_workspace(blank_workspace, 32, 2)
		_check(
			blank_large.ok and blank_large.width == 32 and blank_large.height == 1
			and blank_medium.ok and blank_medium.width == 16 and blank_medium.height == 1
			and blank_small.ok and blank_small.width == 8 and blank_small.height == 1,
			"SCURK Clear Object keeps each fixed base width and one transparent row",
		)
		var sample_shape := PackedInt32Array()
		sample_shape.resize(96 * 3)
		sample_shape.fill(-1)
		sample_shape[48] = 7
		sample_shape[96 + 47] = 8
		sample_shape[2 * 96 + 47] = 9
		var sample_workspace := ScurkWorkspace.from_shape(
			96, 3, sample_shape, ScurkEditorControl.VIEW_LARGE, 96
		)
		var sample_round_trip := ScurkWorkspace.shape_from_workspace(
			sample_workspace, 96, ScurkEditorControl.VIEW_LARGE
		)
		_check(
			sample_round_trip.ok
			and sample_round_trip.width == 96
			and sample_round_trip.height == 3
			and sample_round_trip.pixels == sample_shape,
			"SCURK drawing workspace preserves pixels inside the clip region",
		)
		var pick_working := ScurkTileSet.load_path(
			scurk_directory.path_join("ORIGINAL.MIF")
		)
		var pick_source := ScurkTileSet.load_path(
			scurk_directory.path_join("FUTURE.MIF")
		)
		var pick_target := ScurkPickCopy.group_large_ids(
			ScurkPickCopy.GROUP_RESIDENTIAL
		)[0]
		var pick_result := ScurkPickCopy.copy_objects(
			pick_working,
			pick_source,
			PackedInt32Array([pick_target]),
			editor_large,
			editor_small_medium
		)
		var copied_views_match := true

		for pick_view in 3:
			var pick_sprite_id := pick_target - pick_view * 500
			var source_entry := ScurkPickCopy.resolved_entry(
				pick_source, pick_sprite_id, editor_large, editor_small_medium
			)
			var working_entry := pick_working.overrides.find_sprite(pick_sprite_id)
			copied_views_match = (
				copied_views_match
				and source_entry != null
				and working_entry != null
				and source_entry.decode_indices().pixels
					== working_entry.decode_indices().pixels
			)

		_check(
			pick_result.ok
			and pick_result.object_count == 1
			and pick_result.shape_count == 3
			and copied_views_match,
			"SCURK Pick & Copy replaces all three equivalent object views",
		)
		var invalid_pick_bytes: PackedByteArray = pick_working.to_bytes().bytes
		var invalid_pick := ScurkPickCopy.copy_objects(
			pick_working,
			pick_source,
			PackedInt32Array([999]),
			editor_large,
			editor_small_medium
		)
		_check(
			not invalid_pick.ok
			and pick_working.to_bytes().bytes == invalid_pick_bytes,
			"SCURK Pick & Copy rejects an invalid object without another edit",
		)
		var scurk_editor := ScurkEditor.instantiate() as ScurkEditorControl
		scurk_editor._ready()
		scurk_editor.configure(
			editor_palette, editor_large, editor_small_medium, reference_root,
			GraphicsPack.load_root("res://../ext/graphics").scurk_graphics
		)

		# This control is built manually outside a SceneTree in this test.
		if scurk_editor.pick_copy_control.source_list == null:
			scurk_editor.pick_copy_control._ready()

		var editor_load := scurk_editor.load_path(
			scurk_directory.path_join("ORIGINAL.MIF")
		)
		_check(
			editor_load.ok
			and scurk_editor.object_list.item_count == 499
			and scurk_editor.pixel_canvas.sprite_width == ScurkWorkspace.WIDTH
			and scurk_editor.pixel_canvas.sprite_height == ScurkWorkspace.HEIGHT
			and scurk_editor.active_workspace,
			"SCURK editor loads all tile, terrain, network, and support sprites",
		)
		_check(
			scurk_editor.tool_buttons.size() == 12
			and scurk_editor.palette_panel.texture_control.patterns.size()
				== ScurkPixelEditor.TEXTURE_NAMES.size()
			and scurk_editor.brush_size_selector.item_count == 6
			and scurk_editor.revert_button != null
			and scurk_editor.revert_name_button != null
			and scurk_editor.paste_tool_button.disabled
			and scurk_editor.clipboard_action_buttons.size() == 3
			and not scurk_editor.pixel_canvas.original_textures_loaded
			and scurk_editor.pixel_canvas.texture_patterns.size() == 42
			and scurk_editor.cycle_colors_check.button_pressed
			and scurk_editor.increment_cycle_button.disabled
			and scurk_editor.import_bmp_dialog != null
			and scurk_editor.export_bmp_dialog != null
			and scurk_editor.copy_object_button != null
			and scurk_editor.paste_image_button != null
			and scurk_editor.clear_object_button != null
			and scurk_editor.clip_region_check != null
			and scurk_editor.snap_to_grid_check != null
			and scurk_editor.grid_width_selector.min_value == 1
			and scurk_editor.grid_width_selector.max_value == 65
			and scurk_editor.grid_height_selector.min_value == 1
			and scurk_editor.grid_height_selector.max_value == 65
			and scurk_editor.view_previews.size() == 3
			and scurk_editor.view_previews[0].preview_width == 128
			and scurk_editor.view_previews[0].preview_height == 256
			and scurk_editor.view_previews[1].preview_width == 64
			and scurk_editor.view_previews[1].preview_height == 128
			and scurk_editor.view_previews[2].preview_width == 32
			and scurk_editor.view_previews[2].preview_height == 64
			and scurk_editor.pixel_canvas.clear_background_pixels.size()
			== ScurkWorkspace.WIDTH * ScurkWorkspace.HEIGHT
			and scurk_editor.pixel_canvas.clip_background_pixels.size() == 4
			and scurk_editor.pick_copy_control != null,
			"SCURK editor exposes the recovered paint, clip, and brush controls",
		)
		scurk_editor.grid_width_selector.value = 8
		scurk_editor.grid_height_selector.value = 6
		scurk_editor.snap_to_grid_check.button_pressed = true
		scurk_editor._apply_grid_settings()
		_check(
			scurk_editor.pixel_canvas.grid_width == 8
			and scurk_editor.pixel_canvas.grid_height == 6
			and scurk_editor.pixel_canvas.snap_to_grid,
			"SCURK Grid Settings apply independent 1-through-65 dimensions",
		)
		scurk_editor.request_pick_copy()
		var same_source := scurk_editor.pick_copy_control.load_source_path(
			scurk_directory.path_join("ORIGINAL.MIF")
		)
		var future_source := scurk_editor.pick_copy_control.load_source_path(
			scurk_directory.path_join("FUTURE.MIF")
		)
		_check(
			scurk_editor.pick_copy_control.visible
			and not same_source.ok
			and not same_source.error.is_empty()
			and future_source.ok
			and scurk_editor.pick_copy_control.source_list.item_count == 24
			and scurk_editor.pick_copy_control.working_list.item_count == 24,
			"SCURK Pick & Copy keeps distinct source and working object sets",
		)
		scurk_editor.pick_copy_control._select_group(
			ScurkPickCopy.GROUP_COMMERCIAL
		)
		_check(
			scurk_editor.pick_copy_control.source_list.item_count == 28
			and scurk_editor.pick_copy_control.working_list.item_count == 28,
			"SCURK Pick & Copy filters both object sets by group",
		)
		var pick_editor_before: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		var pick_editor_id := ScurkPickCopy.group_large_ids(
			ScurkPickCopy.GROUP_COMMERCIAL
		)[0]
		scurk_editor._copy_pick_objects(
			scurk_editor.pick_copy_control.source_set,
			PackedInt32Array([pick_editor_id]),
			"Test copy"
		)
		var pick_editor_views_match := true

		for pick_editor_view in 3:
			var pick_editor_sprite := pick_editor_id - pick_editor_view * 500
			var pick_editor_source_entry := ScurkPickCopy.resolved_entry(
				scurk_editor.pick_copy_control.source_set,
				pick_editor_sprite,
				editor_large,
				editor_small_medium
			)
			pick_editor_views_match = (
				pick_editor_views_match
				and pick_editor_source_entry.decode_indices().pixels
					== scurk_editor.tile_set.overrides.find_sprite(
						pick_editor_sprite
					).decode_indices().pixels
			)

		_check(
			scurk_editor.dirty
			and scurk_editor.undo_stack.size() == 1
			and pick_editor_views_match,
			"SCURK Pick & Copy is one three-view editor transaction",
		)
		scurk_editor.undo()
		_check(
			scurk_editor.tile_set.to_bytes().bytes == pick_editor_before,
			"SCURK Undo restores a Pick & Copy transaction",
		)
		scurk_editor.pick_copy_control.request_close()
		scurk_editor._set_cycle_colors(false)
		var cycle_before := scurk_editor.pixel_canvas.palette_cycle_ticks
		scurk_editor._increment_cycle()
		_check(
			not scurk_editor.increment_cycle_button.disabled
			and scurk_editor.pixel_canvas.palette_cycle_ticks
				== cycle_before + Palette.SCURK_INCREMENT_TIMER_TICKS
			and scurk_editor.pixel_canvas.display_palette_index(Palette.FAST_CYCLE_START)
				== editor_palette.scurk_animation_index_map(
					cycle_before + Palette.SCURK_INCREMENT_TIMER_TICKS
				)[Palette.FAST_CYCLE_START],
			"SCURK Increment Cycle works only while automatic cycling is off",
		)
		scurk_editor._set_cycle_colors(true)
		scurk_editor._select_tool(ScurkPixelEditor.TOOL_COPY)
		var editor_copy_press := InputEventMouseButton.new()
		editor_copy_press.button_index = MOUSE_BUTTON_LEFT
		editor_copy_press.pressed = true
		editor_copy_press.position = Vector2(1, 1)
		scurk_editor.pixel_canvas._gui_input(editor_copy_press)
		var editor_copy_release := InputEventMouseButton.new()
		editor_copy_release.button_index = MOUSE_BUTTON_LEFT
		editor_copy_release.pressed = false
		editor_copy_release.position = Vector2(17, 17)
		scurk_editor.pixel_canvas._gui_input(editor_copy_release)
		_check(
			not scurk_editor.paste_tool_button.disabled
			and not scurk_editor.clipboard_action_buttons[0].disabled,
			"SCURK Copy enables Paste and clipboard transforms",
		)
		scurk_editor._select_tool(ScurkPixelEditor.TOOL_PENCIL)
		var original_editor_bytes: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		var edited_pixels := scurk_editor.pixel_canvas.pixels.duplicate()
		var editable_pixel := 100 * ScurkWorkspace.WIDTH + 64
		edited_pixels[editable_pixel] = (
			1 if edited_pixels[editable_pixel] != 1 else 2
		)
		scurk_editor._capture_edit_start()
		scurk_editor._commit_pixels(edited_pixels)
		var changed_editor_bytes: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		_check(
			scurk_editor.dirty
			and changed_editor_bytes != original_editor_bytes
			and scurk_editor.undo_stack.size() == 1,
			"SCURK pixel edits update the MIF document and enter undo history",
		)
		scurk_editor.undo()
		_check(
			not scurk_editor.dirty
			and scurk_editor.tile_set.to_bytes().bytes == original_editor_bytes,
			"SCURK Undo restores the byte-identical loaded MIF document",
		)
		scurk_editor.redo()
		_check(
			scurk_editor.dirty
			and scurk_editor.tile_set.to_bytes().bytes == changed_editor_bytes,
			"SCURK Redo restores the edited MIF document",
		)
		scurk_editor.undo()
		var object_edit_pixels := scurk_editor.pixel_canvas.pixels.duplicate()
		object_edit_pixels[editable_pixel] = (
			3 if object_edit_pixels[editable_pixel] != 3 else 4
		)
		scurk_editor._capture_edit_start()
		scurk_editor._commit_pixels(object_edit_pixels)
		var object_edit_bytes: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		scurk_editor.revert_object()
		_check(
			scurk_editor.tile_set.to_bytes().bytes == original_editor_bytes,
			"SCURK Revert restores the exact object-selection document state",
		)
		scurk_editor.undo()
		_check(
			scurk_editor.tile_set.to_bytes().bytes == object_edit_bytes,
			"SCURK Revert enters exact-byte Undo history",
		)
		scurk_editor.redo()
		var current_tile_id := ScurkEditorControl.object_tile_id(scurk_editor.current_large_id)
		scurk_editor.name_edit.text = "Temporary Query Name"
		scurk_editor._commit_name()
		_check(
			scurk_editor.tile_set.names.get(current_tile_id, "") == "Temporary Query Name",
			"SCURK Rename writes a custom query name",
		)
		scurk_editor.revert_name()
		_check(
			not scurk_editor.tile_set.names.has(current_tile_id),
			"SCURK Revert Name removes the custom NAME piece",
		)
		scurk_editor.undo()
		_check(
			scurk_editor.tile_set.names.get(current_tile_id, "") == "Temporary Query Name",
			"SCURK Revert Name enters Undo history",
		)
		scurk_editor.redo()
		var reference_save := scurk_editor.save_path(
			scurk_directory.path_join("DO_NOT_WRITE.MIF")
		)
		_check(
			not reference_save.ok and not reference_save.error.is_empty(),
			"SCURK editor refuses to write inside the reference directory",
		)
		var scratch_path := ProjectSettings.globalize_path(
			"user://test-scurk-editor-output.MIF"
		)
		var editor_save := scurk_editor.save_path(scratch_path)
		_check(
			editor_save.ok
			and FileAccess.get_file_as_bytes(scratch_path)
				== FileAccess.get_file_as_bytes(scurk_directory.path_join("ORIGINAL.MIF")),
			"SCURK editor saves an unchanged MIF byte-identically",
		)
		var added_sprite_id := 1256
		var added_before: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		scurk_editor.current_large_id = added_sprite_id
		scurk_editor.current_view = ScurkEditorControl.VIEW_LARGE
		scurk_editor._capture_object_start()
		scurk_editor._refresh_sprite()
		var added_pixels := scurk_editor.pixel_canvas.pixels.duplicate()
		var added_editable_pixel := 100 * ScurkWorkspace.WIDTH + 64
		added_pixels[added_editable_pixel] = (
			7 if added_pixels[added_editable_pixel] != 7 else 8
		)
		scurk_editor._capture_edit_start()
		scurk_editor._commit_pixels(added_pixels)
		_check(
			scurk_editor.tile_set.overrides.find_sprite(added_sprite_id) != null,
			"SCURK editor appends a previously absent terrain sprite to MIF",
		)
		scurk_editor.undo()
		_check(
			scurk_editor.tile_set.to_bytes().bytes == added_before
			and scurk_editor.tile_set.overrides.find_sprite(added_sprite_id) == null,
			"SCURK Undo removes an appended full-catalog sprite exactly",
		)
		var scratch_bmp_path := ProjectSettings.globalize_path(
			"user://test-scurk-editor-output.BMP"
		)
		var editor_export := scurk_editor.export_bmp_path(scratch_bmp_path)
		var exported_bitmap := IndexedBitmap.decode(
			FileAccess.get_file_as_bytes(scratch_bmp_path)
		)
		var expected_export := scurk_editor._active_output_shape()
		var expected_export_pixels: PackedInt32Array = expected_export.pixels.duplicate()

		for pixel_index in expected_export_pixels.size():
			if expected_export_pixels[pixel_index] < 0:
				expected_export_pixels[pixel_index] = 0

		_check(
			editor_export.ok
			and exported_bitmap.ok
			and exported_bitmap.width == expected_export.width
			and exported_bitmap.height == expected_export.height
			and exported_bitmap.pixels == expected_export_pixels,
			"SCURK editor exports its clipped active object view as an indexed BMP",
		)
		var imported_pixels := PackedInt32Array([-1, 1, 2, 3, 4, 5])
		var import_fixture := IndexedBitmap.save_path(
			scratch_bmp_path, 3, 2, imported_pixels, editor_palette
		)
		var editor_import := scurk_editor.import_bmp_path(scratch_bmp_path)
		var imported_output := scurk_editor._active_output_shape()
		_check(
			import_fixture.ok
			and editor_import.ok
			and scurk_editor.pixel_canvas.sprite_width == ScurkWorkspace.WIDTH
			and scurk_editor.pixel_canvas.sprite_height == ScurkWorkspace.HEIGHT
			and imported_output.width == scurk_editor.active_base_width
			and imported_output.height == 2
			and imported_output.pixels.has(1)
			and imported_output.pixels.has(2)
			and imported_output.pixels.has(4)
			and not imported_output.pixels.has(3)
			and not imported_output.pixels.has(5)
			and scurk_editor.dirty,
			"SCURK editor centers and clips an imported bitmap without changing its base",
		)
		scurk_editor.current_large_id = editable_ids[0]
		scurk_editor.current_view = ScurkEditorControl.VIEW_LARGE
		scurk_editor._refresh_sprite()
		var before_clear: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		scurk_editor.clear_object()
		var cleared_views_are_blank := true
		var clear_mismatch := ""

		for clear_view in range(3):
			var clear_entry := scurk_editor.tile_set.archive.find_sprite(
				editable_ids[0] - clear_view * 500
			)
			var clear_decoded := clear_entry.decode_indices() if clear_entry != null else IndexedImageResult.new()
			var clear_view_is_blank: bool = (
				clear_entry != null
				and clear_entry.width
					== int(scurk_editor.active_base_width / ScurkWorkspace.view_divisor(clear_view))
				and clear_entry.height == 1
				and clear_decoded.ok
				and not clear_decoded.pixels.has(0)
			)

			if not clear_view_is_blank and clear_mismatch.is_empty():
				clear_mismatch = "view %d: %s" % [clear_view, str(clear_decoded)]

			cleared_views_are_blank = cleared_views_are_blank and clear_view_is_blank

		_check(
			cleared_views_are_blank and scurk_editor.undo_stack.size() > 0,
			"SCURK Clear Object clears all three views with their fixed base widths: %s"
				% clear_mismatch,
		)
		scurk_editor.undo()
		_check(
			scurk_editor.tile_set.to_bytes().bytes == before_clear,
			"SCURK Clear Object has exact-byte Undo",
		)

		if FileAccess.file_exists(scratch_path):
			DirAccess.remove_absolute(scratch_path)

		if FileAccess.file_exists(scratch_bmp_path):
			DirAccess.remove_absolute(scratch_bmp_path)

		scurk_editor.free()

	var fill_source := PackedInt32Array([
		1, 1, -1,
		1, 2, -1,
	])
	var filled := ScurkPixelEditor.flood_fill(fill_source, 3, 2, Vector2i(0, 0), 9)
	_check(
		filled == PackedInt32Array([9, 9, -1, 9, 2, -1])
		and fill_source == PackedInt32Array([1, 1, -1, 1, 2, -1]),
		"SCURK fill edits only the connected palette region",
	)
	var checker_fill := ScurkPixelEditor.flood_fill_pattern(
		PackedInt32Array([1, 1, 1, 2, 2, 2]), 3, 2, Vector2i(0, 0),
		7, 8, ScurkPixelEditor.TEXTURE_ROWS[1]
	)
	_check(
		checker_fill == PackedInt32Array([7, 8, 7, 2, 2, 2]),
		"SCURK texture fill uses foreground and background colors",
	)
	_check(
		ScurkPixelEditor.resolve_texture_value(0xff, 7, 8) == 7
		and ScurkPixelEditor.resolve_texture_value(0xf5, 7, 8) == 8
		and ScurkPixelEditor.resolve_texture_value(0x00, 7, 8) == 8
		and ScurkPixelEditor.resolve_texture_value(0x9b, 7, 8) == 0x9b,
		"SCURK textures map sentinels and keep literal palette indices",
	)
	var hollow_box := ScurkPixelEditor.shape_points(
		ScurkPixelEditor.TOOL_RECTANGLE, Vector2i(1, 2), Vector2i(4, 4), false
	)
	var filled_box := ScurkPixelEditor.shape_points(
		ScurkPixelEditor.TOOL_RECTANGLE, Vector2i(1, 2), Vector2i(4, 4), true
	)
	_check(
		hollow_box.size() == 10
		and filled_box.size() == 12
		and hollow_box.has(Vector2i(1, 2))
		and not hollow_box.has(Vector2i(2, 3))
		and filled_box.has(Vector2i(2, 3)),
		"SCURK box tool supports hollow and filled previews",
	)
	_check(
		ScurkPixelEditor.line_points(Vector2i(0, 0), Vector2i(4, 2))
			== [
				Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1),
				Vector2i(3, 2), Vector2i(4, 2),
			]
		and not ScurkPixelEditor.shape_points(
			ScurkPixelEditor.TOOL_DIAMOND, Vector2i(0, 0), Vector2i(6, 4), false
		).is_empty()
		and not ScurkPixelEditor.shape_points(
			ScurkPixelEditor.TOOL_LEFT_WALL, Vector2i(0, 0), Vector2i(6, 8), true
		).is_empty()
		and not ScurkPixelEditor.shape_points(
			ScurkPixelEditor.TOOL_ELLIPSE, Vector2i(0, 0), Vector2i(6, 4), false
		).is_empty(),
		"SCURK line, diamond, wall, and ellipse tools produce pixel paths",
	)
	_check(
		ScurkPixelEditor.snapped_shape_point(
			Vector2i(1, 2), 4, 6, true
		) == Vector2i(0, 0)
		and ScurkPixelEditor.snapped_shape_point(
			Vector2i(2, 3), 4, 6, true
		) == Vector2i(4, 6)
		and ScurkPixelEditor.snapped_shape_point(
			Vector2i(6, 9), 4, 6, true
		) == Vector2i(8, 12)
		and ScurkPixelEditor.snapped_shape_point(
			Vector2i(6, 9), 4, 6, false
		) == Vector2i(6, 9),
		"SCURK shape snapping rounds half steps forward on each grid axis",
	)
	var view_window := ScurkViewWindow.new()
	var preview_background := PackedInt32Array()
	preview_background.resize(ScurkWorkspace.WIDTH * ScurkWorkspace.HEIGHT)
	preview_background.fill(5)
	view_window.set_preview(
		2, 1, 1, PackedInt32Array([7]), 32,
		Palette.index_encoding(), preview_background
	)
	_check(
		view_window.preview_width == 32
		and view_window.preview_height == 64
		and view_window.preview_indices[63 * 32 + 15] == 7
		and view_window.preview_indices[0] == 5
		and view_window.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"SCURK Small View Window shows the complete sampled Drawing Area and is read-only",
	)
	view_window.free()
	var snap_canvas := ScurkPixelEditor.new()
	var snap_pixels := PackedInt32Array()
	snap_pixels.resize(16 * 16)
	snap_pixels.fill(-1)
	snap_canvas.set_sprite_data(16, 16, snap_pixels, Palette.index_encoding())
	snap_canvas.set_zoom(1)
	snap_canvas.set_tool(ScurkPixelEditor.TOOL_LINE)
	snap_canvas.set_paint_indices(7, 0)
	snap_canvas.set_grid_settings(4, 6, true)
	var snap_press := InputEventMouseButton.new()
	snap_press.button_index = MOUSE_BUTTON_LEFT
	snap_press.pressed = true
	snap_press.position = Vector2(3.2, 4.2)
	snap_canvas._gui_input(snap_press)
	var snap_release := InputEventMouseButton.new()
	snap_release.button_index = MOUSE_BUTTON_LEFT
	snap_release.pressed = false
	snap_release.position = Vector2(9.2, 10.2)
	snap_canvas._gui_input(snap_release)
	_check(
		snap_canvas.pixel_at(Vector2i(4, 6)) == 7
		and snap_canvas.pixel_at(Vector2i(8, 12)) == 7
		and snap_canvas.pixel_at(Vector2i(3, 4)) == -1,
		"SCURK shape tools use snapped grid endpoints during the committed preview",
	)
	snap_canvas.free()
	var stroke_canvas := ScurkPixelEditor.new()
	stroke_canvas.set_sprite_data(
		5, 1, PackedInt32Array([-1, -1, -1, -1, -1]), Palette.index_encoding()
	)
	stroke_canvas.set_paint_indices(7, 0)
	var stroke_press := InputEventMouseButton.new()
	stroke_press.button_index = MOUSE_BUTTON_LEFT
	stroke_press.pressed = true
	stroke_press.position = Vector2(1, 1)
	stroke_canvas._gui_input(stroke_press)
	var stroke_motion := InputEventMouseMotion.new()
	stroke_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	stroke_motion.position = Vector2(17, 1)
	stroke_canvas._gui_input(stroke_motion)
	var stroke_release := InputEventMouseButton.new()
	stroke_release.button_index = MOUSE_BUTTON_LEFT
	stroke_release.pressed = false
	stroke_release.position = Vector2(17, 1)
	stroke_canvas._gui_input(stroke_release)
	_check(
		stroke_canvas.pixels == PackedInt32Array([7, 7, 7, 7, 7]),
		"SCURK pencil strokes fill every crossed pixel without gaps",
	)
	stroke_canvas.free()
	var clip_canvas := ScurkPixelEditor.new()
	var clip_pixels := PackedInt32Array()
	clip_pixels.resize(ScurkWorkspace.WIDTH * ScurkWorkspace.HEIGHT)
	clip_pixels.fill(7)
	clip_canvas.set_sprite_data(
		ScurkWorkspace.WIDTH, ScurkWorkspace.HEIGHT, clip_pixels, Palette.index_encoding()
	)
	clip_canvas.set_edit_region(ScurkWorkspace.clip_mask(32), 1)
	_check(
		clip_canvas.pixels[255 * 128 + 62] == -1
		and clip_canvas.pixels[255 * 128 + 63] == 7
		and clip_canvas.pixels[255 * 128 + 64] == -1
		and clip_canvas.pixels[0 * 128 + 48] == 7,
		"SCURK drawing tools erase pixels outside the active object base",
	)
	clip_canvas.free()
	var clipboard_source := PackedInt32Array([1, 2, 3, 4, 5, 6])
	var copied_region := ScurkPixelEditor.copy_region(
		clipboard_source, 3, 2, Vector2i(1, 0), Vector2i(2, 1)
	)
	_check(
		copied_region.width == 2
		and copied_region.height == 2
		and copied_region.pixels == PackedInt32Array([2, 3, 5, 6]),
		"SCURK Copy extracts an inclusive rectangular pixel region",
	)
	_check(
		ScurkPixelEditor.rotate_counterclockwise(clipboard_source, 3, 2)
			== PackedInt32Array([3, 6, 2, 5, 1, 4])
		and ScurkPixelEditor.flip_horizontal(clipboard_source, 3, 2)
			== PackedInt32Array([3, 2, 1, 6, 5, 4])
		and ScurkPixelEditor.flip_vertical(clipboard_source, 3, 2)
			== PackedInt32Array([4, 5, 6, 1, 2, 3]),
		"SCURK clipboard rotate and flip operations preserve palette indices",
	)
	var paste_target := PackedInt32Array()
	paste_target.resize(12)
	paste_target.fill(0)
	_check(
		ScurkPixelEditor.paste_region(
			paste_target, 4, 3, Vector2i(2, 2),
			clipboard_source, 3, 2
		) == PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2]),
		"SCURK Paste clips copied pixels at the object boundary",
	)
	var clipboard_canvas := ScurkPixelEditor.new()
	clipboard_canvas.set_sprite_data(
		5, 5, PackedInt32Array([
			1, 2, 3, 4, 5,
			6, 7, 8, 9, 10,
			11, 12, 13, 14, 15,
			16, 17, 18, 19, 20,
			21, 22, 23, 24, 25,
		]), Palette.index_encoding()
	)
	clipboard_canvas.set_zoom(4)
	clipboard_canvas.set_tool(ScurkPixelEditor.TOOL_COPY)
	var copy_press := InputEventMouseButton.new()
	copy_press.button_index = MOUSE_BUTTON_LEFT
	copy_press.pressed = true
	copy_press.position = Vector2(1, 1)
	clipboard_canvas._gui_input(copy_press)
	var copy_release := InputEventMouseButton.new()
	copy_release.button_index = MOUSE_BUTTON_LEFT
	copy_release.pressed = false
	copy_release.position = Vector2(17, 17)
	clipboard_canvas._gui_input(copy_release)
	_check(
		clipboard_canvas.clipboard_width == 5
		and clipboard_canvas.clipboard_height == 5
		and clipboard_canvas.clipboard_pixels[0] == 1
		and clipboard_canvas.clipboard_pixels[24] == 25,
		"SCURK Copy drag stores a source-sized region in its private clipboard",
	)
	var accepted_clipboard := clipboard_canvas.clipboard_pixels.duplicate()
	copy_press.position = Vector2(1, 1)
	clipboard_canvas._gui_input(copy_press)
	copy_release.position = Vector2(13, 13)
	clipboard_canvas._gui_input(copy_release)
	_check(
		clipboard_canvas.clipboard_pixels == accepted_clipboard,
		"SCURK Copy rejects endpoint spans shorter than four pixels",
	)
	clipboard_canvas.free()
	var palette_grid := ScurkPalette.new()
	_check(
		palette_grid.index_at(Vector2(0, 0)) == 0
		and palette_grid.index_at(Vector2(17, 17)) == 0
		and palette_grid.index_at(Vector2(18, 0)) == 1
		and palette_grid.index_at(Vector2(287, 287)) == 255
		and palette_grid.index_at(Vector2(288, 0)) == -1,
		"SCURK palette maps all 256 visible color cells",
	)
	palette_grid.free()

	var city_hall := ScurkTileSet.load_path(scurk_directory.path_join("CITYHAL.MIF"))
	_check(city_hall.is_valid(), "CITYHAL.MIF parses: %s" % city_hall.parse_error)

	if city_hall.is_valid():
		_check(
			city_hall.piece_count == 552
			and city_hall.shapes.size() == 552
			and city_hall.overrides.entries.size() == 3,
			"CITYHAL.MIF keeps only its three visible overrides",
		)

		for expected in [[1208, 96, 85], [708, 48, 43], [208, 24, 22]]:
			var entry := city_hall.overrides.find_sprite(expected[0])
			_check(
				entry != null and entry.width == expected[1] and entry.height == expected[2],
				"CITYHAL.MIF sprite %d has its native dimensions" % expected[0],
			)

		var base_large := SpriteArchive.load_path(
			reference_root.path_join("DATA/LARGE.DAT")
		)
		var combined_large := SpriteArchive.combine([base_large, city_hall.overrides])
		_check(
			combined_large.is_valid()
			and combined_large.find_sprite(1208)
			== city_hall.overrides.find_sprite(1208)
			and combined_large.find_sprite(1207) == base_large.find_sprite(1207),
			"A partial MIF replaces visible sprites and keeps blank base sprites",
		)

	var tile_set_one := ScurkTileSet.load_path(scurk_directory.path_join("TILESET1.MIF"))
	_check(tile_set_one.is_valid(), "TILESET1.MIF parses: %s" % tile_set_one.parse_error)

	if tile_set_one.is_valid():
		_check(
			tile_set_one.piece_count == 572
			and tile_set_one.shapes.size() == 552
			and tile_set_one.names.size() == 20,
			"TILESET1.MIF contains 552 shapes and 20 names",
		)
		_check(
			tile_set_one.names.get(0xb5, "") == "Theater",
			"SCURK NAME records decode their full ID and terminal-null text",
		)
		var original_info := tile_set_one.info_payload.duplicate()
		var edited_pixels := PackedInt32Array([
			-1, 7, -1,
			8, 9, 10,
		])
		var edited_shape := tile_set_one.set_shape_indices(1208, 3, 2, edited_pixels)
		var edited_name := tile_set_one.set_name(Tiles.THEATER_SQUARE_3X3, "Edited Theater")
		var edited_bytes := tile_set_one.to_bytes()
		var reparsed := ScurkTileSet.new()
		_check(
			edited_shape.ok and edited_name.ok and edited_bytes.ok
			and reparsed.parse(edited_bytes.bytes),
			"SCURK writes edited SHAP and NAME records",
		)

		if reparsed.is_valid():
			var edited_entry := reparsed.archive.find_sprite(1208)
			var edited_decode := edited_entry.decode_indices() if edited_entry != null else IndexedImageResult.new()
			_check(
				reparsed.info_payload == original_info
				and reparsed.names.get(0xb5, "") == "Edited Theater"
				and edited_entry != null
				and edited_entry.width == 3
				and edited_entry.height == 2
				and edited_decode.ok
				and edited_decode.pixels == edited_pixels,
				"SCURK edit writes preserve INFO and decode to the edited values",
			)

		var removed_name := tile_set_one.remove_name(Tiles.THEATER_SQUARE_3X3)
		var removed_bytes := tile_set_one.to_bytes()
		var reparsed_removed := ScurkTileSet.new()
		_check(
			removed_name.ok
			and removed_bytes.ok
			and reparsed_removed.parse(removed_bytes.bytes)
			and not reparsed_removed.names.has(0xb5)
			and reparsed_removed.piece_count == 571,
			"SCURK can remove a custom NAME piece without changing other pieces",
		)

	var unpadded := Sc2SpriteArchive.SpriteEntry.new()
	unpadded.sprite_id = 7
	unpadded.width = 1
	unpadded.height = 1
	unpadded.encoded_pixels = PackedByteArray([3, 1, 1, 4, 7, 0, 2])
	_check(
		not unpadded.decode_indices().ok,
		"Normal DAT sprites reject an unpadded odd pixel run",
	)
	unpadded.allow_unpadded_odd_runs = true
	var decoded_unpadded := unpadded.decode_indices()
	_check(
		decoded_unpadded.ok and decoded_unpadded.pixels[0] == 7,
		"SCURK sprites accept an odd pixel run that ends at the row boundary",
	)

	var city_hall_bytes := FileAccess.get_file_as_bytes(
		scurk_directory.path_join("CITYHAL.MIF")
	)
	var bad_header := city_hall_bytes.duplicate()
	bad_header[0] = 0
	var bad_header_result := ScurkTileSet.new()
	_check(
		not bad_header_result.parse(bad_header)
		and not bad_header_result.parse_error.is_empty(),
		"SCURK parser rejects an invalid form header",
	)
	var bad_pixel_length := city_hall_bytes.duplicate()
	bad_pixel_length[161] = (bad_pixel_length[161] + 1) & 0xff
	var bad_pixel_result := ScurkTileSet.new()
	_check(
		not bad_pixel_result.parse(bad_pixel_length)
		and not bad_pixel_result.parse_error.is_empty(),
		"SCURK parser rejects a SHAP pixel-length mismatch",
	)
