extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(AudioServer.get_driver_name() == "Dummy", "Audio checks must be silent")
	_check_discharges()
	var app := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.main_menu.city_background.set_process(false)
	assert(app.city_session.activate_document(EmptyCityTemplate.create(128)))
	app.document_state.city.set_sound_enabled(true)
	var controller := app.audio_controller
	controller.application_has_focus = true
	controller.background_audio = false
	controller.effects_volume = 0.8
	app.preferences.visual_enhancements = VisualEnhancementOptions.normalize({"weather_enabled": true, "weather_mode": 2})
	var weather := app.visual_environment.weather
	var audio := weather.audio
	var before := DocumentState.capture(app.document_state.city.document)
	var engine := app.simulation_state.simulation_engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	app.preferences.visual_enhancements.weather_fixed = CityVisualWeather.Kind.LIGHT_RAIN
	weather.process(5.0, 0.0, true, 1.0)
	assert(audio.rain_players.size() == 2)
	assert(audio.rain_players[0].playing and audio.rain_players[1].playing)
	assert((audio.rain_players[0].stream as AudioStreamOggVorbis).loop)
	assert((audio.rain_players[1].stream as AudioStreamOggVorbis).loop)
	var light_gain := audio.rain_gains
	assert(light_gain.x > light_gain.y)
	app.preferences.visual_enhancements.weather_fixed = CityVisualWeather.Kind.HEAVY_RAIN
	weather.process(0.1, 0.0, true, 1.0)
	assert(audio.rain_gains.x > 0.0, "Rain switched recordings abruptly")
	weather.process(5.0, 0.0, true, 1.0)
	assert(audio.rain_gains.y > light_gain.x and audio.rain_gains.y > audio.rain_gains.x)
	var rain_player := audio.rain_players[1]
	controller.effects_volume = 0.4
	weather.process(0.0, 0.0, true, 1.0)
	assert(is_equal_approx(rain_player.volume_linear, audio.rain_gains.y * 0.4))
	assert(audio.rain_players[1] == rain_player, "A frame restarted the rain loop")
	var frozen_rain := [weather.clock, weather.rain, weather.tint, audio.rain_gains]
	weather.process(60.0, 60.0, true, 1.0, true)
	assert([weather.clock, weather.rain, weather.tint, audio.rain_gains] == frozen_rain)
	assert(audio.rain_players.all(func(player: AudioStreamPlayer) -> bool: return player.stream_paused))
	weather.process(0.1, 0.1, true, 1.0)
	assert(audio.rain_players[1] == rain_player and not rain_player.stream_paused, "Resume restarted rain ambience")
	assert(is_equal_approx(weather.clock, float(frozen_rain[0]) + 0.1))
	app.preferences.visual_enhancements.weather_fixed = CityVisualWeather.Kind.DRY_STORM
	weather.snow = 0.6
	weather.process(0.016, 0.0, true, 1.0)
	assert(weather.rain == 0.0 and weather.snow == 0.0, "Dry lightning retained precipitation during a transition")
	weather.process(5.0, 0.0, true, 1.0)
	assert(audio.wind_player != null and audio.wind_player.playing and audio.wind_player.volume_linear > 0.1)
	assert((audio.wind_player.stream as AudioStreamOggVorbis).loop)
	var wind_player := audio.wind_player
	assert(audio.rain_players.is_empty(), "Dry storm retained rain ambience")
	assert(weather.lightning.thunder_wait > 0.0)
	assert(audio.thunder_players.is_empty(), "Thunder preceded its travel delay")
	var frozen_storm := [weather.lightning.thunder_wait, weather.lightning.wait, weather.lightning.age, weather.flash, weather.lightning.random.state]
	weather.process(60.0, 60.0, true, 1.0, true)
	assert([weather.lightning.thunder_wait, weather.lightning.wait, weather.lightning.age, weather.flash, weather.lightning.random.state] == frozen_storm)
	assert(audio.thunder_players.is_empty(), "Paused storm emitted pending thunder")
	assert(wind_player.stream_paused)
	weather.process(weather.lightning.thunder_wait + 0.01, 0.0, true, 1.0)
	assert(audio.thunder_players.size() == 1 and audio.thunder_players[0].playing)
	assert(audio.wind_player == wind_player and not wind_player.stream_paused)
	var thunder_player := audio.thunder_players[0]
	weather.process(60.0, 60.0, true, 1.0, true)
	assert(thunder_player.stream_paused)
	weather.process(0.0, 0.0, true, 1.0)
	assert(audio.thunder_players[0] == thunder_player and not thunder_player.stream_paused)
	for i in 8:
		audio.play_thunder(weather.lightning, 1.0)
	assert(audio.thunder_players.size() <= CityWeatherAudio.MAX_THUNDER)
	controller.effects_volume = 0.2
	weather.process(0.0, 0.0, true, 1.0)
	assert(is_equal_approx(audio.thunder_players.back().volume_linear, weather.lightning.gain * 0.2))
	assert(is_equal_approx(wind_player.volume_linear, audio.wind_gain * 0.2))
	controller.application_has_focus = false
	weather.process(0.0, 0.0, true, 1.0)
	assert(audio.thunder_players.is_empty() and weather.lightning.thunder_wait < 0.0)
	assert(audio.wind_player == null)
	app.preferences.visual_enhancements.weather_fixed = CityVisualWeather.Kind.RAIN_STORM
	weather.process(5.0, 0.0, true, 1.0)
	assert(audio.rain_players.is_empty())
	controller.background_audio = true
	weather.process(5.0, 0.0, true, 1.0)
	assert(audio.rain_players.size() == 2 and audio.wind_player == null)
	# The general effects controller can dispose our players between frames.
	controller.stop_sound_effects()
	await process_frame
	weather.process(0.1, 0.0, true, 1.0)
	assert(audio.rain_players.size() == 2 and audio.rain_players[0].playing)
	controller.effects_volume = 0.0
	weather.process(0.0, 0.0, true, 1.0)
	assert(audio.rain_players.is_empty() and audio.thunder_players.is_empty())
	controller.effects_volume = 0.5
	weather.process(1.0, 0.0, true, 1.0)
	assert(not audio.rain_players.is_empty())
	app.preferences.visual_enhancements.weather_strength = 0.0
	weather.process(0.0, 0.0, true, 1.0)
	assert(audio.rain_players.is_empty() and weather.flash == 0.0)
	app.preferences.visual_enhancements.weather_strength = 1.0
	app.preferences.visual_enhancements.weather_enabled = false
	weather.process(0.0, 0.0, true, 1.0)
	assert(audio.thunder_players.is_empty() and weather.lightning.thunder_wait < 0.0)
	assert(audio.wind_player == null)
	app.preferences.visual_enhancements.weather_enabled = true
	weather.process(1.0, 0.0, true, 1.0)
	weather.process(0.0, 0.0, false, 1.0)
	assert(audio.rain_players.is_empty() and weather.flash == 0.0)
	weather.process(5.0, 0.0, true, 1.0)
	weather.reset()
	assert(audio.rain_players.is_empty() and audio.thunder_players.is_empty())
	assert(weather.lightning.thunder_wait < 0.0)
	app.preferences.visual_enhancements.weather_fixed = CityVisualWeather.Kind.HEAVY_SNOW
	weather.process(5.0, 0.0, true, 3.0)
	assert(audio.rain_players.is_empty(), "Snow played rain audio")
	app.preferences.visual_enhancements.weather_fixed = CityVisualWeather.Kind.SUNNY
	weather.process(5.0, 0.0, true, 1.0)
	assert(audio.rain_players.is_empty() and audio.thunder_players.is_empty())
	assert(DocumentState.capture(app.document_state.city.document) == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	app.document_state.city.set_sound_enabled(false)
	app.preferences.visual_enhancements.weather_fixed = CityVisualWeather.Kind.RAIN_STORM
	weather.process(5.0, 0.0, true, 1.0)
	assert(audio.rain_players.is_empty() and audio.thunder_players.is_empty())
	app.queue_free()
	await process_frame
	print("PASS: recorded rain crossfades, varied delayed thunder, audio gates, bounded voices, unchanged city and simulation RNG")
	quit()


func _check_discharges() -> void:
	var discharge := CityLightning.new()
	discharge.random.seed = 73411
	var last := -1
	var sounds: Dictionary = {}
	var shapes: Dictionary = {}
	for i in 30:
		discharge.wait = 0.0
		discharge.thunder_wait = -1.0
		assert(not discharge.advance(0.016, true, 1.0))
		assert(discharge.sound_index != last, "Immediate repeated thunder recording")
		last = discharge.sound_index
		sounds[last] = true
		shapes[discharge.pulses.size()] = true
		assert(discharge.flash > 0.0 and discharge.flash < 1.0)
		assert(is_equal_approx(discharge.thunder_wait, discharge.distance / 343.0))
		assert(discharge.wait > discharge.thunder_wait)
		var delay := discharge.thunder_wait
		assert(not discharge.advance(delay * 0.5, true, 1.0))
		assert(discharge.advance(delay * 0.5 + 0.01, true, 1.0))
		assert(not discharge.advance(0.0, true, 1.0), "Thunder fired twice")
		discharge.advance(2.0, true, 1.0)
		assert(discharge.flash == 0.0, "A completed discharge stayed bright")
	assert(sounds.size() == CityWeatherAudio.THUNDER.size() and shapes.size() > 1)
	discharge.wait = 0.0
	discharge.advance(0.016, true, 1.0)
	assert(not discharge.advance(30.0, false, 1.0))
	assert(discharge.flash == 0.0 and discharge.thunder_wait < 0.0)
	assert(not discharge.advance(30.0, true, 0.0))
	for stream in CityWeatherAudio.THUNDER:
		assert(stream.get_length() > 5.0 and not stream.loop)
