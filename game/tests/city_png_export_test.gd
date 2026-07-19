extends SceneTree

const ExportJob = preload("res://src/view/city_png_export_job.gd")
const ScurkCityOutput = preload("res://src/assets/scurk_city_output.gd")
const Renderer = preload("res://src/view/city_isometric_renderer.gd")

var main: Node
var folder := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_output_sizes()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	await process_frame
	main.main_menu.hide()
	main.city_files._load_city_unchecked(ProjectSettings.globalize_path("res://../references/SIMCITY2000/DEFAULT.SC2"))
	main.frame._select_speed(GameSpeedController.Speed.PAUSED)
	folder = ProjectSettings.globalize_path("user://png_export_test")
	DirAccess.make_dir_recursive_absolute(folder)
	_check_menu_and_dialog()
	_check_render_progress()
	await _check_exports()
	await _check_progress_overlay()
	main.queue_free()
	await process_frame
	print("PASS: city PNG export options, sizes, backgrounds, files, and delayed progress")
	quit()


func _check_output_sizes() -> void:
	# Zoom is relative to the large view: each graphics size is 1:1 at its own zoom.
	assert(ExportJob.output_size(128, Renderer.VIEW_SMALL, 0.25) == Vector2i(1040, 736))
	assert(ExportJob.output_size(128, Renderer.VIEW_MEDIUM, 0.5) == Vector2i(2080, 1472))
	assert(ExportJob.output_size(128, Renderer.VIEW_LARGE, 1.0) == Vector2i(4160, 2944))
	assert(ExportJob.output_size(128, Renderer.VIEW_SMALL, 1.0) == Vector2i(4160, 2944))
	assert(ExportJob.output_size(128, Renderer.VIEW_LARGE, 0.25) == Vector2i(1040, 736))
	assert(ExportJob.fits(ExportJob.output_size(512, Renderer.VIEW_LARGE, 1.0)))
	assert(not ExportJob.fits(ExportJob.output_size(512, Renderer.VIEW_LARGE, 2.0)))


func _check_menu_and_dialog() -> void:
	var popup: PopupMenu = main.city_menu_bar.file_menu.get_popup()
	assert(popup.get_item_index(CityMenuBar.MENU_EXPORT_CITY_PNG) >= 0)
	main.map_view.zoom_factor = 0.5
	main.menus._on_file_menu(CityMenuBar.MENU_EXPORT_CITY_PNG)
	var dialog: CityPngExportDialog = main.city_png_export_dialog
	assert(dialog.visible)
	assert(DirAccess.dir_exists_absolute(dialog.folder_input.text))
	var options := dialog.options()
	assert(is_equal_approx(options.zoom, 0.5) and options.view == "city" and not options.transparent_background)
	assert(options.view_size == Renderer.VIEW_MEDIUM, "Graphics follow the zoom preference by default")
	assert(options.path.get_file().ends_with("_CITY_MEDIUM_50.png"))
	assert(not dialog.get_ok_button().disabled and dialog.summary_label.text.begins_with("Image size: 2,080 × 1,472"))

	dialog.zoom_selector.select(1)
	dialog.zoom_selector.item_selected.emit(1)
	assert(dialog.options().view_size == Renderer.VIEW_SMALL)
	dialog.graphics_selector.select(Renderer.VIEW_LARGE)
	dialog.graphics_selector.item_selected.emit(Renderer.VIEW_LARGE)
	dialog.zoom_selector.select(3)
	dialog.zoom_selector.item_selected.emit(3)
	assert(dialog.options().view_size == Renderer.VIEW_LARGE, "A chosen graphics size stays chosen")

	dialog.folder_input.text = folder.path_join("missing")
	dialog.folder_input.text_changed.emit(dialog.folder_input.text)
	assert(dialog.get_ok_button().disabled and dialog.summary_label.text == "The folder does not exist.")
	dialog.folder_input.text = main.reference_root
	dialog.folder_input.text_changed.emit(dialog.folder_input.text)
	assert(dialog.get_ok_button().disabled and "read-only" in dialog.summary_label.text)
	dialog.folder_input.text = folder
	dialog.file_name_input.text = "bad:name"
	dialog.file_name_input.text_changed.emit(dialog.file_name_input.text)
	assert(dialog.get_ok_button().disabled)
	dialog.file_name_input.text = "custom"
	dialog.file_name_input.text_changed.emit(dialog.file_name_input.text)
	assert(not dialog.get_ok_button().disabled and dialog.output_path() == folder.path_join("custom.png"))
	dialog.view_selector.select(1)
	dialog.view_selector.item_selected.emit(1)
	assert(dialog.file_name_input.text == "custom", "A typed file name stays typed")

	var zoom_graphics: Array[int] = main.app_zoom_graphics
	dialog.configure("Big", folder, 512, 4.0, "city", zoom_graphics, 0)
	assert(dialog.get_ok_button().disabled and "too large" in dialog.summary_label.text)
	dialog.hide()


func _check_render_progress() -> void:
	var values: Array[float] = []
	var result := ScurkCityOutput.render(main.city, main.palette, main.static_render._sprite_archive_for_view(Renderer.VIEW_SMALL), Renderer.VIEW_SMALL, {
		"view": "underground", "progress": func(value: float) -> void: values.append(value),
	})
	assert(result.ok and values.size() == main.city.map_size * 2 - 1)

	for index in range(1, values.size()):
		assert(values[index] > values[index - 1])

	assert(is_equal_approx(values.back(), 1.0))


func _check_exports() -> void:
	var cases := [
		["city", Renderer.VIEW_SMALL, 0.25, true, Vector2i(1040, 736)],
		["city", Renderer.VIEW_SMALL, 0.25, false, Vector2i(1040, 736)],
		["underground", Renderer.VIEW_MEDIUM, 0.25, false, Vector2i(1040, 736)],
		["underground", Renderer.VIEW_SMALL, 0.5, true, Vector2i(2080, 1472)],
	]

	for entry in cases:
		var path := folder.path_join("%s_%d_%d_%s.png" % [entry[0], entry[1], roundi(entry[2] * 100), entry[3]])
		main.city_png_export._start_export({"path": path, "view_size": entry[1], "zoom": entry[2], "view": entry[0], "transparent_background": entry[3]})
		assert(main.city_png_export.is_running())

		while main.city_png_export.is_running():
			await process_frame

		assert(path in main.status_label.text, main.status_label.text)
		var image := Image.load_from_file(path)
		assert(image != null and image.get_size() == entry[4])
		var corner := image.get_pixel(0, 0)
		var center := image.get_pixelv(image.get_size() / 2)

		if entry[3]:
			# Underground art is a wireframe; without its paper most pixels are clear.
			assert(image.detect_alpha() != Image.ALPHA_NONE and corner.a == 0.0 and image.get_used_rect().has_area())
			assert(center.a == 1.0 or entry[0] == "underground")
		else:
			assert(image.get_format() == Image.FORMAT_RGB8)
			var expected: Color = Color("18242c") if entry[0] == "city" else main.palette.color(0xff)
			assert(corner.to_rgba32() == expected.to_rgba32(), "%s background" % entry[0])

		DirAccess.remove_absolute(path)


func _check_progress_overlay() -> void:
	var overlay: ProgressOverlay = main.city_png_export_progress
	var shown := [0]
	overlay.visibility_changed.connect(func() -> void:
		if overlay.visible:
			shown[0] += 1
	)
	var options := {"path": folder.path_join("fast.png"), "view_size": Renderer.VIEW_SMALL, "zoom": 0.25, "view": "city", "transparent_background": false}
	main.city_png_export._start_export(options)

	while main.city_png_export.is_running():
		await process_frame

	assert(shown[0] == 0, "An export under one second shows no overlay")
	main.city_png_export.progress_delay_msec = 0
	options.path = folder.path_join("slow.png")
	options.view_size = Renderer.VIEW_LARGE
	options.zoom = 1.0
	main.city_png_export._start_export(options)
	var seen := false

	while main.city_png_export.is_running():
		await process_frame
		seen = seen or overlay.visible

		if overlay.visible:
			assert(overlay.bar.indeterminate or (overlay.bar.value >= 0.0 and overlay.bar.value <= 1.0))

	assert(seen and shown[0] > 0 and not overlay.visible)
	main.city_png_export.progress_delay_msec = main.city_png_export.PROGRESS_DELAY_MSEC

	for file_name in ["fast.png", "slow.png"]:
		DirAccess.remove_absolute(folder.path_join(file_name))
