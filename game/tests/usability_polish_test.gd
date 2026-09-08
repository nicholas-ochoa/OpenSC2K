extends SceneTree

const Place = preload("res://src/tools/scurk/scurk_place_command.gd")
const ToolState = preload("res://src/tools/shared/tool_edit_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var events: Array[EffectEvent] = []

	for tile in 12:
		for frame in 3:
			events.append(EffectEvent.new(Vector2i(tile, 0), 0, Vector2i.ZERO, false, tile * 10 + frame))

	var original := EffectEvent.copy_all(events)
	var shuffled := ApplicationEffectsAudio._parallel_dust_events(events)
	assert(EffectEvent.same_arrays(events, original))
	var starts := {}

	for tile in 12:
		var first: int = shuffled[tile * 3].frame
		assert(first >= 0 and first <= 4)
		assert(shuffled[tile * 3 + 2].frame == first + 2)
		starts[first] = int(starts.get(first, 0)) + 1

	assert(starts.values().max() > 1, "Dust did not overlap between tiles")
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	await process_frame
	assert(main.static_render.city_view_size() == CityIsometricRenderer.VIEW_LARGE)
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
	assert(main.document_state.city == null and main.document_state.current_document == null)
	main.main_menu.hide()
	var elapsed := background.elapsed
	background._process(1.0)
	assert(background.elapsed == elapsed, "Hidden menu kept simulating")

	main.city_files._load_city_unchecked(ProjectSettings.globalize_path("res://../references/SIMCITY2000/DEFAULT.SC2"))
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	var city: CityState = main.document_state.city
	var before: PackedByteArray = city.document.serialize().data
	var rng := SimRandom.new(123)
	var stamp := Place.apply(city, 359, Vector2i(32, 32), rng)
	assert(stamp.ok and city.scurk_artwork_stamps.size() == 1)
	assert(city.document.serialize().data == before and rng.state == 123)
	assert(ToolState.scurk_object(city, CityViewMode.Mode.CITY, 359).area == 1)
	var copied := stamp.copy() as ScurkPlaceResult
	copied.new_stamps[0].point = Vector2i(31, 32)
	assert(city.scurk_artwork_stamps[0].point == Vector2i(32, 32))
	assert(not Place.undo(city, copied, rng).ok, "Undo accepted changed history values")
	city.scurk_artwork_stamps[0] = ScurkArtworkStamp.new(359, Vector2i(32, 32))
	assert(Place.undo(city, stamp, rng).ok and city.scurk_artwork_stamps.is_empty())
	assert(Place.redo(city, stamp, rng).ok and city.scurk_artwork_stamps.size() == 1)
	assert(city.document.serialize().data == before)

	for view in [CityIsometricRenderer.VIEW_SMALL, CityIsometricRenderer.VIEW_MEDIUM, CityIsometricRenderer.VIEW_LARGE]:
		var dimensions := CityIsometricRenderer.output_size_for_view(view)

		for indexed in [false, true]:
			var output := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_L8 if indexed else Image.FORMAT_RGBA8)
			output.fill(Color.BLACK)
			var empty_hash := hash(output.get_data())
			ScurkCityOutput._draw_artwork_stamps(output, city, main.asset_state.palette_index_encoding if indexed else main.asset_state.palette, main.static_render.sprite_archive_for_view(view), view)
			assert(hash(output.get_data()) != empty_hash, "Artwork missing from print or indexed bitmap output")

	main.budget.open_manual_budget()
	await process_frame
	var budget := main.budget_dialog as BudgetDialog

	for action in ["issue", "repay"]:
		budget.open_bond_confirmation(action, 8)
		assert(budget.bond_dialog.visible)
		budget.bond_dialog.hide()

	budget.hide()
	main.city_files.request_main_menu()
	await process_frame
	assert(not main.main_menu.visible)
	var prompt: ConfirmationDialog

	for child in main.get_children():
		if child is ConfirmationDialog and child.visible:
			prompt = child

	assert(prompt != null)
	prompt.confirmed.emit()
	await process_frame
	assert(main.main_menu.visible and main.document_state.city == city)
	assert(city.document.serialize().data == before)
	assert(FileAccess.get_file_as_bytes(background.source_path) == source_bytes)
	main.queue_free()
	await process_frame
	print("PASS: overlapping dust, graphics default, isolated menu simulation, SCURK stamps and history, Budget prompts, main-menu confirmation")
	quit()
