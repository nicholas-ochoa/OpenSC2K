extends SceneTree

const Main = preload("res://src/main.gd")
const Place = preload("res://src/tools/scurk/scurk_place_command.gd")
const ToolState = preload("res://src/tools/shared/tool_edit_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var events: Array = []

	for tile in 12:
		for frame in 3:
			events.append({"point": Vector2i(tile, 0), "frame": tile * 10 + frame})

	var original := events.duplicate(true)
	var shuffled := Main._parallel_dust_events(events)
	assert(events == original)
	var starts := {}

	for tile in 12:
		var first: int = shuffled[tile * 3].frame
		assert(first >= 0 and first <= 4)
		assert(shuffled[tile * 3 + 2].frame == first + 2)
		starts[first] = int(starts.get(first, 0)) + 1

	assert(starts.values().max() > 1, "Dust did not overlap between tiles")
	var palette := CityChildToolPalette.new()

	for sample in [[4, 1, "10 supply"], [4, 2, "100 water"], [4, 3, "2,000"], [4, 4, "20 supply"], [12, 0, "15 units"], [12, 1, "50 units"], [13, 0, "Police coverage"], [13, 1, "Fire coverage"], [13, 2, "25 units"]]:
		assert(palette.tool_button_tooltip(sample[0], sample[1], true).contains(sample[2]))

	palette.free()

	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	await process_frame
	assert(main._city_view_size() == CityIsometricRenderer.VIEW_LARGE)
	var background := main.main_menu.city_background as MainMenuCityBackground
	assert(background.demo_city != null)
	var source_bytes := FileAccess.get_file_as_bytes(background.source_path)
	assert(background.demo_city.no_disasters_enabled())
	assert(background.demo_city.auto_budget_enabled())
	assert(not background.demo_city.sound_enabled())
	assert(not background.demo_city.music_enabled())

	for step in 20:
		background._process(0.2)

	assert(FileAccess.get_file_as_bytes(background.source_path) == source_bytes)
	assert(main.city == null and main.current_document == null)
	main.main_menu.hide()
	var elapsed := background.elapsed
	background._process(1.0)
	assert(background.elapsed == elapsed, "Hidden menu kept simulating")

	main._load_city_unchecked(ProjectSettings.globalize_path("res://../references/SIMCITY2000/DEFAULT.SC2"))
	main._select_speed(GameSpeedController.Speed.PAUSED)
	var city: CityState = main.city
	var before: PackedByteArray = city.document.serialize().data
	var rng := SimRandom.new(123)
	var stamp := Place.apply(city, 359, Vector2i(32, 32), rng)
	assert(stamp.ok and city.scurk_artwork_stamps.size() == 1)
	assert(city.document.serialize().data == before and rng.state == 123)
	assert(ToolState.scurk_object(city, "city", 359).area == 1)
	assert(Place.undo(city, stamp, rng).ok and city.scurk_artwork_stamps.is_empty())
	assert(Place.redo(city, stamp, rng).ok and city.scurk_artwork_stamps.size() == 1)
	assert(city.document.serialize().data == before)

	for view in [CityIsometricRenderer.VIEW_SMALL, CityIsometricRenderer.VIEW_MEDIUM, CityIsometricRenderer.VIEW_LARGE]:
		var dimensions := CityIsometricRenderer.output_size_for_view(view)

		for indexed in [false, true]:
			var output := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_L8 if indexed else Image.FORMAT_RGBA8)
			output.fill(Color.BLACK)
			var empty_hash := hash(output.get_data())
			ScurkCityOutput._draw_artwork_stamps(output, city, main.palette_index_encoding if indexed else main.palette, main._sprite_archive_for_view(view), view)
			assert(hash(output.get_data()) != empty_hash, "Artwork missing from print or indexed bitmap output")

	main._open_manual_budget()
	await process_frame
	var budget := main.budget_dialog as BudgetDialog

	for index in range(5, budget.controls.size()):
		assert(budget.controls[index].tooltip_text.contains("100%"))
		assert(budget.controls[index].tooltip_text.contains("50%"))
		assert(budget.controls[index].tooltip_text.contains("0%"))

	for action in ["issue", "repay"]:
		budget.open_bond_confirmation(action, 8)
		assert(budget.bond_dialog.visible)
		budget.bond_dialog.hide()

	budget.hide()
	main._request_main_menu()
	await process_frame
	assert(not main.main_menu.visible)
	var prompt: ConfirmationDialog

	for child in main.get_children():
		if child is ConfirmationDialog and child.title == "Return to Main Menu":
			prompt = child

	assert(prompt != null)
	prompt.confirmed.emit()
	await process_frame
	assert(main.main_menu.visible and main.city == city)
	assert(city.document.serialize().data == before)
	assert(FileAccess.get_file_as_bytes(background.source_path) == source_bytes)
	main.queue_free()
	await process_frame
	print("PASS: overlapping dust, facility details, graphics default, isolated menu simulation, SCURK stamps and history, Budget layout and prompts, main-menu confirmation")
	quit()
