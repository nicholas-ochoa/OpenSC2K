extends SceneTree

const ExportJob = preload("res://src/view/city_png_export_job.gd")
const ScurkCityOutput = preload("res://src/assets/scurk_city_output.gd")
const Renderer = preload("res://src/view/city_isometric_renderer.gd")

var main: Node
var folder := ""
var overlay_shown := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_output_sizes()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	await process_frame
	main.main_menu.hide()
	main.asset_state.reference_root = ProjectSettings.globalize_path(GeneratedCityFixture.ROOT)
	main.city_files._load_city_unchecked(ProjectSettings.globalize_path("res://tests/fixtures/cities/generated-128.SC2"))
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	folder = ProjectSettings.globalize_path("user://png_export_test")
	DirAccess.make_dir_recursive_absolute(folder)
	_check_detached_workflow()
	await _check_failed_worker()
	_check_menu_and_dialog()
	_check_content_options()
	_check_render_progress()
	main.city_dialogs.png_export_progress.visibility_changed.connect(func() -> void:
		if main.city_dialogs.png_export_progress.visible:
			overlay_shown += 1
	)
	await _check_exports()
	assert(overlay_shown == 0, "Exports under one second show no overlay")
	await _check_progress_overlay()
	main.queue_free()
	await process_frame
	print("PASS: city PNG export options, 1:1 sizes, backgrounds, signs, moving things, files, and delayed progress")
	quit()


func _check_output_sizes() -> void:
	# Each graphics size exports 1:1.
	assert(ExportJob.output_size(128, Renderer.VIEW_SMALL) == Vector2i(1040, 736))
	assert(ExportJob.output_size(128, Renderer.VIEW_MEDIUM) == Vector2i(2080, 1472))
	assert(ExportJob.output_size(128, Renderer.VIEW_LARGE) == Vector2i(4160, 2944))
	assert(ExportJob.output_size(512, Renderer.VIEW_LARGE) == Vector2i(16448, 9088))


func _check_menu_and_dialog() -> void:
	var popup: PopupMenu = main.city_menu_bar.file_menu.get_popup()
	assert(popup.get_item_index(CityMenuBar.MENU_EXPORT_CITY_PNG) >= 0)
	main.menus.on_file_menu(CityMenuBar.MENU_EXPORT_CITY_PNG)
	var dialog: CityPngExportDialog = main.city_dialogs.png_export_dialog
	assert(dialog.visible)
	assert(DirAccess.dir_exists_absolute(dialog.folder_input.text))
	var options := dialog.options()
	var graphics: int = main.static_render.city_view_size()
	assert(options.view_size == graphics, "Graphics start at the size on screen")
	assert(options.view == "city" and not options.transparent_background and options.signs and options.moving_things)
	assert(options.path.get_file() == "%s_CITY_%s.png" % [main.document_state.city.display_name(), String(AppSettingsStore.GRAPHICS_SIZES[graphics]).to_upper()])
	var size := ExportJob.output_size(128, graphics)
	assert(not dialog.get_ok_button().disabled and dialog.summary_label.text.begins_with("Image size: %s × " % DisplayNumberFormat.format(size.x)))

	dialog.view_selector.select(1)
	dialog.view_selector.item_selected.emit(1)
	assert(dialog.signs_check.disabled and dialog.moving_things_check.disabled)
	assert(not dialog.options().signs and not dialog.options().moving_things, "Underground has no signs or moving things")
	assert(dialog.file_name_input.text.contains("_UNDERGROUND_"))
	dialog.view_selector.select(0)
	dialog.view_selector.item_selected.emit(0)
	dialog.signs_check.button_pressed = false
	assert(not dialog.signs_check.disabled and not dialog.options().signs and dialog.options().moving_things)

	dialog.folder_input.text = folder.path_join("missing")
	dialog.folder_input.text_changed.emit(dialog.folder_input.text)
	assert(dialog.get_ok_button().disabled and dialog.summary_label.text == "The folder does not exist.")
	dialog.folder_input.text = main.asset_state.reference_root
	dialog.folder_input.text_changed.emit(dialog.folder_input.text)
	assert(dialog.get_ok_button().disabled and "read-only" in dialog.summary_label.text)
	dialog.folder_input.text = folder
	dialog.file_name_input.text = "bad:name"
	dialog.file_name_input.text_changed.emit(dialog.file_name_input.text)
	assert(dialog.get_ok_button().disabled)
	dialog.file_name_input.text = "custom"
	dialog.file_name_input.text_changed.emit(dialog.file_name_input.text)
	assert(not dialog.get_ok_button().disabled and dialog.output_path() == folder.path_join("custom.png"))
	dialog.graphics_selector.select(0)
	dialog.graphics_selector.item_selected.emit(0)
	assert(dialog.file_name_input.text == "custom", "A typed file name stays typed")
	dialog.hide()


func _check_content_options() -> void:
	# Keep the toggle check independent of the saved vehicles' current occlusion.
	var city: CityState = main.document_state.city
	var engine := SimulationEngine.new(city, 123, 456, 789)
	assert(CityDebugActions.remove_moving_things(city, city.document).ok)
	assert(CityDebugActions.spawn_moving_thing(city, city.document, engine, 1, Vector2i(20, 20), 99).ok)
	var things := 0

	for y in main.document_state.city.map_size:
		for x in main.document_state.city.map_size:
			if OverlayData.is_thing(main.document_state.city.text_overlay_id(x, y)):
				things += 1

	assert(things > 0, "Fixture has no moving object")
	var hashes := {}

	for variant in [[true, true], [false, true], [true, false]]:
		var job := ExportJob.new()
		job.city_snapshot = main.document_state.city
		job.palette = main.asset_state.palette
		job.sprites = main.static_render.sprite_archive_for_view(Renderer.VIEW_SMALL)
		job.view_size = Renderer.VIEW_SMALL
		job.include_signs = variant[0]
		job.include_moving_things = variant[1]
		job.path = folder.path_join("content.png")
		var result := job.run()
		assert(result.ok and result.size == Vector2i(1040, 736))
		hashes[variant] = hash(Image.load_from_file(job.path).get_data())

	DirAccess.remove_absolute(folder.path_join("content.png"))
	assert(hashes[[false, true]] != hashes[[true, true]], "The signs option changes the image")
	assert(hashes[[true, false]] != hashes[[true, true]], "The moving-things option changes the image")


func _check_render_progress() -> void:
	var values: Array[float] = []
	var options := ScurkCityOutput.Options.new()
	options.view = "underground"
	options.progress = func(value: float) -> void: values.append(value)
	var result := ScurkCityOutput.render(main.document_state.city, main.asset_state.palette, main.static_render.sprite_archive_for_view(Renderer.VIEW_SMALL), Renderer.VIEW_SMALL, options)
	assert(result.ok and values.size() == main.document_state.city.map_size * 2 - 1)

	for index in range(1, values.size()):
		assert(values[index] > values[index - 1])

	assert(is_equal_approx(values.back(), 1.0))


func _check_exports() -> void:
	var cases := [
		["city", Renderer.VIEW_SMALL, 1, true, Vector2i(1040, 736)],
		["city", Renderer.VIEW_SMALL, 1, false, Vector2i(1040, 736)],
		["underground", Renderer.VIEW_MEDIUM, 2, false, Vector2i(2080, 1472)],
		["underground", Renderer.VIEW_SMALL, 3, true, Vector2i(1040, 736)],
	]

	for entry in cases:
		var path := folder.path_join("%s_%d_%d.png" % [entry[0], entry[1], entry[2]])
		var options := ExportJob.Options.new()
		options.path = path
		options.view_size = entry[1]
		options.view = entry[0]
		options.transparent_background = entry[3]
		main.city_png_export.start_export(options)
		assert(main.city_png_export.is_running())

		while main.city_png_export.is_running():
			await process_frame

		assert(path in main.status_label.text, main.status_label.text)
		var image := Image.load_from_file(path)
		assert(image != null and image.get_size() == entry[4])
		var corner := image.get_pixel(0, 0)
		var center := image.get_pixelv(image.get_size() / 2)

		if bool(entry[3]):
			# Underground art is a wireframe; without its paper most pixels are clear.
			assert(image.detect_alpha() != Image.ALPHA_NONE and corner.a == 0.0 and image.get_used_rect().has_area())
			assert(center.a == 1.0 or entry[0] == "underground")
		else:
			assert(image.get_format() == Image.FORMAT_RGB8)
			var expected: Color = Color("18242c") if entry[0] == "city" else main.asset_state.palette.color(0xff)
			assert(corner.to_rgba32() == expected.to_rgba32(), "%s background" % entry[0])

		DirAccess.remove_absolute(path)


func _check_progress_overlay() -> void:
	var overlay: ProgressOverlay = main.city_dialogs.png_export_progress
	var options := ExportJob.Options.new()
	options.path = folder.path_join("slow.png")
	options.view_size = Renderer.VIEW_MEDIUM
	main.city_png_export.progress_delay_msec = 0
	main.city_png_export.start_export(options)
	var seen := false

	while main.city_png_export.is_running():
		await process_frame
		seen = seen or overlay.visible

		if overlay.visible:
			assert(overlay.bar.indeterminate or (overlay.bar.value >= 0.0 and overlay.bar.value <= 1.0))

	assert(seen and overlay_shown > 0 and not overlay.visible)
	main.city_png_export.progress_delay_msec = main.city_png_export.PROGRESS_DELAY_MSEC

	DirAccess.remove_absolute(options.path)


func _check_detached_workflow() -> void:
	var document := ActiveDocumentState.new()
	var exporter := ApplicationCityPngExport.new(document, ViewState.new(), main.asset_state,
		func() -> int: return Renderer.VIEW_SMALL,
		func(_size: int) -> Sc2SpriteArchive: return main.asset_state.small_medium_sprites)
	var errors: Array[String] = []
	exporter.error_reported.connect(func(message: String) -> void: errors.append(message))
	exporter.open_export_dialog()
	assert(errors.size() == 1 and not exporter.is_running())
	document.current_document = EmptyCityTemplate.create(16)
	document.city = CityState.from_document(document.current_document)
	var options := ExportJob.Options.new()
	options.path = folder.path_join("detached.png")
	options.view_size = Renderer.VIEW_SMALL
	exporter.start_export(options)
	assert(exporter.is_running())
	var captured := exporter.job.city_snapshot
	var before := captured.document.serialize().data
	document.current_document = EmptyCityTemplate.create(32)
	document.city = CityState.from_document(document.current_document)
	assert(captured.map_size == 16 and captured.document.serialize().data == before)
	exporter.close()
	assert(not exporter.is_running() and FileAccess.file_exists(options.path))
	DirAccess.remove_absolute(options.path)


func _check_failed_worker() -> void:
	var exporter := ApplicationCityPngExport.new(ActiveDocumentState.new(), ViewState.new(), LoadedAssetState.new(),
		Callable(), Callable())
	var progress := preload("res://src/ui/shared/progress_overlay.tscn").instantiate() as ProgressOverlay
	root.add_child(progress)
	progress.show()
	exporter.bind_ui(null, progress)
	var errors: Array[String] = []
	exporter.error_reported.connect(func(message: String) -> void: errors.append(message))
	exporter.job = CityPngExportJob.new()
	assert(exporter.job.start() == OK)
	while exporter.is_running():
		await process_frame
		exporter.poll_export()
	assert(errors.size() == 1 and "city is not valid" in errors[0])
	assert(not progress.visible and exporter.job == null)
	exporter.poll_export()
	assert(errors.size() == 1, "A failed export reports once")
	progress.free()
