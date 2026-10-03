extends SceneTree
## A large city loads and saves behind the busy box, and a large demolition
## shows a limited number of effect sprites.

const GeneratedCityFixture = preload("res://tests/support/generated_city_fixture.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	var busy: BusyOverlay = main.main_overlays.busy_overlay
	var files: ApplicationCityFiles = main.city_files

	# the 512 city is read on a worker thread, and the box shows before activation
	var source := GeneratedCityFixture.path(512)
	files._load_city_in_background(source)
	assert(files.load_in_progress and main.document_state.city == null)
	var shown := false

	while files.load_in_progress:
		shown = shown or busy.visible
		await process_frame

	assert(shown, "The busy box shows while a large city loads")
	assert(not busy.visible)
	assert(main.document_state.city != null and main.document_state.city.map_size == 512)
	assert(main.document_state.saved_city_snapshot == main.document_state.current_document.content_snapshot())
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)

	# a large SC2X save shows the box until the worker thread writes the file
	var output := OS.get_temp_dir().path_join("opensc2k-busy-%d.sc2x" % OS.get_process_id())
	DirAccess.remove_absolute(output)
	assert(not files._save_copy(output))
	assert(files.save_in_progress and busy.visible)

	while files.save_in_progress:
		await process_frame

	assert(not busy.visible)
	assert(FileAccess.file_exists(output) and main.document_state.current_save_path == output)
	DirAccess.remove_absolute(output)

	# one tile effect for each tile of a large area
	var effects: Array[EffectEvent] = []

	for x in 512:
		for y in 64:
			effects.append(EffectEvent.new(Vector2i(x, y), CityEffectTiming.SMOKE_SPRITE, Vector2i.ZERO, false, 0, -1))

	var map: CityMapControl = main.map_view
	map.zoom_factor = 0.1
	map.zoom_changed.emit(10)
	var sampled: Array[EffectEvent] = main.effects_audio._sampled_effect_events(effects)
	var tiles := {}

	for event in sampled:
		tiles[event.point] = true

	assert(tiles.size() <= ApplicationEffectsAudio.EFFECT_TILE_LIMIT and tiles.size() * 2 > ApplicationEffectsAudio.EFFECT_TILE_LIMIT)
	var no_sounds: Array[SoundEvent] = []
	main.effects_audio.show_effect_events(effects, no_sounds)
	var drawn := 0

	for frame: Array in map.presentation._effect_sequences.back().frames:
		drawn += frame.size()

	assert(drawn > 0 and drawn <= ApplicationEffectsAudio.EFFECT_VISUAL_LIMIT)
	assert(main.effects_audio._effect_textures.size() <= ApplicationEffectsAudio.EFFECT_CACHE_LIMIT)
	print("PASS: Large city loads and saves behind the busy box, and large demolitions limit their effects")
	main.queue_free()
	await process_frame
	quit()
