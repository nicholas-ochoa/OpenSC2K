extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var directory := PeBitmapResource._load_resource_directory("res://../references/SIMCITY2000/SIMCITY.EXE")
	assert(directory.ok)
	var table := PeBitmapResource._rva_to_offset(directory.bytes, 0x000ea7f8, directory.section_offset, directory.section_count)

	for i in 18:
		assert(directory.bytes.decode_u16(table + i * 2) == DesktopCursorRules.CITY_TOOLS[i])

	for pair in [[640, 3000], [799, 3000], [800, 2000], [1023, 2000], [1024, 1000], [3840, 1000]]:
		assert(DesktopCursorRules.city_family(pair[0]) == pair[1])

	assert(DesktopCursorRules.city_tool(1, 0) == 3 and DesktopCursorRules.city_tool(1, 1) == 16)
	var scurk := PeBitmapResource._load_resource_directory("res://../references/SIMCITY2000/WINSCURK.EXE")

	# Command and cursor immediates in the supplied drawing command handlers.
	for binding in [[0x43e154, 20000, 0x43e167, 30000], [0x43e11c, 20001, 0x43e12f, 30001],
		[0x43e0e4, 20002, 0x43e0f7, 30002], [0x43de58, 20008, 0x43de6b, 30002],
		[0x43dd18, 20012, 0x43dd2b, 30002], [0x43dce0, 20013, 0x43dcf3, 30003]]:
		assert(_u32_at(scurk, binding[0]) == binding[1] and _u32_at(scurk, binding[2]) == binding[3])

	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	await process_frame
	var desktop: CityDesktopPresentation = main.desktop_presentation
	desktop.set_process(false)
	var original := desktop.graphics
	var alternate := _alternate_graphics()
	main.city_files._load_city_unchecked(ProjectSettings.globalize_path("res://../references/SIMCITY2000/CITIES/ISLAND.SC2"))
	var map: CityMapControl = main.map_view
	var saved: PackedByteArray = main.document_state.current_document.serialize().data

	for tool in ToolCatalog.all_tools():
		main.selected_group = tool.group_index
		main.selected_subtool = tool.subtool_index
		main.current_tool.update_edit_state()
		assert(map.desktop_cursor_role == DesktopCursorRules.city_tool(tool.group_index, tool.subtool_index))
		map.edit_enabled = true # Check every resource route, including locked tools.

		for width in [640, 800, 1024]:
			var route := desktop.cursor_selection(map, width)

			for graphics in [original, alternate]:
				assert(not graphics.cursor(route.app, route.group).is_empty())

		map.zoom_factor = 0.25
		var small := desktop.cursor_selection(map, 1024)
		map.zoom_factor = 2.0
		assert(desktop.cursor_selection(map, 1024) == small)

	map._panning = true
	assert(desktop.cursor_selection(map, 1024).group == 1010)
	map._panning = false
	map.edit_enabled = false
	assert(desktop.cursor_selection(map, 1024).is_empty())
	assert(desktop.cursor_selection(main.city_menu_bar.file_menu, 1024).is_empty())
	assert(desktop.cursor_selection(null, 1024).is_empty())
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(157, 92)
	desktop._input(motion)
	assert(desktop._pointer_position == motion.position)
	var pixel_canvas := ScurkPixelCanvas.new()
	root.add_child(pixel_canvas)
	pixel_canvas.sprite_width = 8

	for tool in 12:
		pixel_canvas.tool = tool
		var expected := 30000 if tool == 0 else (30001 if tool == 1 else (30003 if tool == 11 else 30002))
		assert(desktop.cursor_selection(pixel_canvas, 640).group == expected)

	pixel_canvas.hide()
	assert(desktop.cursor_selection(pixel_canvas, 640).is_empty())
	var target := ScurkObjectList.new()
	target.drop_target = true
	root.add_child(target)

	for ids in [PackedInt32Array([1001]), PackedInt32Array([1001, 1002])]:
		target.force_drag({"kind": "scurk_pick_copy_objects", "large_ids": ids}, null)
		var route := desktop.cursor_selection(target, 1024)
		assert(route.group == (30004 if ids.size() == 1 else 30005))
		assert(route.shape == Input.CURSOR_CAN_DROP)
		root.gui_cancel_drag()

	assert(desktop.cursor_selection(target, 1024).is_empty())
	target.force_drag({"kind": "unrelated"}, null)
	assert(desktop.cursor_selection(target, 1024).is_empty())
	root.gui_cancel_drag()
	target.queue_free()
	var presenter := desktop.presenter
	main.scurk_workspace._ensure_scurk_editor()
	main.scurk_workspace.ensure_scurk_place_print()
	main.scurk_output._ensure_scurk_print()

	for graphics in [original, alternate]:
		desktop.set_graphics(graphics)
		main.scurk_editor.hide()
		desktop._update_icon()
		assert(desktop.icon_image == graphics.icon("city", 2, 32))
		main.scurk_editor.show()
		desktop._update_icon()
		assert(desktop.icon_image == graphics.icon("scurk", 2, 32))
		main.scurk_editor.pick_copy_control.show()
		desktop._update_icon()
		assert(desktop.icon_image == graphics.icon("scurk", 4, 32))
		main.scurk_editor.pick_copy_control.hide()
		main.scurk_editor.hide()
		main.scurk_place_print.show()
		desktop._update_icon()
		assert(desktop.icon_image == graphics.icon("scurk", 1, 32))
		main.scurk_print.show()
		desktop._update_icon()
		assert(desktop.icon_image == graphics.icon("scurk", 3, 32))
		main.scurk_print.hide()
		main.scurk_place_print.hide()
		presenter.present("scurk", 30000, Vector2(120, 90), Input.CURSOR_ARROW)
		var uploads := presenter.upload_count
		presenter.present("scurk", 30000, Vector2(128, 96), Input.CURSOR_ARROW)
		assert(presenter.upload_count == uploads)

		if graphics == original:
			assert(presenter._owns_hidden_mouse and presenter._patch.visible)
			assert(presenter._copy.rect.position == Vector2(128, 96) - Vector2(presenter.active_record.hotspot))
		else:
			assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not presenter._layer.visible)

		presenter.present("city", 1021, Vector2.ZERO, Input.CURSOR_CROSS)
		assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and presenter.active_group == 1021)
		presenter.clear_cursor()
		assert(presenter.active_group == -1 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)

	# Every encoded mask byte retains the original operation, including inversion.
	for id in [1, 2]:
		var masked: Dictionary = original.cursors.scurk[id].masked
		var encoded := DesktopCursorPresenter.mask_image(masked)

		for at in 1024:
			var color := encoded.get_pixel(at % 32, at / 32)
			var source: Color = masked.palette[masked.pixels[at]]
			assert(color.r8 == source.r8 and color.g8 == source.g8 and color.b8 == source.b8)
			assert(color.a8 == 255 * masked.and_mask[at])

	desktop.set_graphics(null)
	assert(desktop.presenter.graphics == null and desktop.presenter.active_group == -1)
	desktop._update_icon()
	assert(desktop.icon_image == desktop._project_icon)
	assert(main.document_state.current_document.serialize().data == saved, "Cursor selection does not change the city")
	pixel_canvas.queue_free()
	main.queue_free()
	await process_frame
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	print("PASS: original cursor table, display-width boundaries, 69 city tools, paint tools, original/alternate display, cursor cache, mask bytes, cleanup and unchanged city")
	quit()


func _u32_at(directory: Dictionary, address: int) -> int:
	var at := PeBitmapResource._rva_to_offset(directory.bytes, address - 0x400000, directory.section_offset, directory.section_count)
	assert(at >= 0)

	return directory.bytes.decode_u32(at)


func _alternate_graphics() -> DesktopGraphics:
	# Solid diagnostic images exercise the external cursor presentation route.
	var result := DesktopGraphics.new()

	for app in ["city", "scurk"]:
		for kind in ["icons", "cursors"]:
			for id in DesktopGraphics.resource_ids(app, kind):
				var size := DesktopGraphics.native_size(app, kind, id)
				var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
				image.fill(Color.CYAN)

				if kind == "icons":
					result.icons[app][id] = image
				else:
					result.cursors[app][id] = {"image": image, "hotspot": Vector2i.ZERO}

	return result
