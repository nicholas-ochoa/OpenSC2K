extends SceneTree

class NoMenuInterface extends ApplicationInterface:
	func show_main_menu() -> void:
		pass


class TestApp extends "res://src/main.gd":
	func _init() -> void:
		interface = NoMenuInterface.new(self)



func _initialize() -> void:
	call_deferred("run_check")


func run_check() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.set_script(TestApp)
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	await process_frame
	main.new_city_session.independent_template = true
	main.new_city.open_new_city_dialog()
	# This suite tests size selection and preview jobs; terrain rules have their own tests.
	main.new_city_dialog.ocean_input.button_pressed = false
	main.new_city_dialog.river_input.button_pressed = false
	main.new_city_dialog.hills_input.value = 0
	main.new_city_dialog.water_input.value = 0
	main.new_city_dialog.trees_input.value = 0

	assert(main.new_city_dialog.size_input.get_selected_id() == 128)
	for selection in Sc2File.MAP_SIZES.size():
		var edge: int = Sc2File.MAP_SIZES[selection]
		main.new_city_dialog.size_input.select(selection)
		main.new_city_dialog.size_input.item_selected.emit(selection)
		assert(main.new_city_dialog.done_button.disabled)
		assert(main.new_city._new_city_terrain_options().size == edge)
		# Size wiring is checked for every option. The minimum-size preview exercises
		# the worker; New City workflow and terrain tests own larger generation.
		if edge != 16:
			continue
		main.new_city.make_new_city_preview()
		while main.new_city_preview_job != null:
			await process_frame
		assert(main.new_city_session.preview_document.map_size == edge)
		assert(main.new_city_session.preview_options.get("size") == edge)
		assert(main.new_city_dialog.preview_view.texture.get_width() == edge)

	main.new_city.cancel_new_city()
	main.preferences.zoom_graphics = AppSettingsStore.normalize_zoom_graphics([0, 1, 2, 2, 2, 2])
	main.map_view.zoom_factor = 0.25
	main.overlay_mode = CityViewMode.Mode.UNDERGROUND

	# Smallest and largest worker cities, then original synchronous simulation.
	for edge in [16, 512, 128]:
		assert(main.city_session.activate_document(EmptyCityTemplate.create(edge)))
		assert(main.map_view.city.map_size == edge)
		assert((main.frame_simulation != null) == (edge != 128))
		assert(main.map_view.city_source.size == CityIsometricRenderer.output_size_for_view(2, edge))

		if edge != 128:
			main.speed_controller.set_speed(GameSpeedController.Speed.CHEETAH)
			main.frame_simulation.advance_time(200, 200)
			assert(main.frame_simulation.is_pending())

	main.queue_free()
	await process_frame
	print("PASS: automatic size preview and underground city replacement with pending simulation across map sizes")
	quit()
