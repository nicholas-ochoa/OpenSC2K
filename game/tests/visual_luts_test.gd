extends SceneTree


func _initialize() -> void:
	var profiles := CityVisualLuts.new()
	profiles.reload("")
	assert(profiles.issues.is_empty())
	var options := VisualEnhancementOptions.normalize({})
	var water_only := VisualEnhancementOptions.normalize({"water_reflections": 0, "water_topography": false})
	assert(VisualEnhancementOptions.water_pass_enabled(water_only), "Seasonal water needs a pass with reflection and seabed off")
	water_only.season_water_strength = 0.0
	assert(not VisualEnhancementOptions.water_pass_enabled(water_only))
	water_only.season_water_strength = 0.35
	water_only.season_enabled = false
	assert(not VisualEnhancementOptions.water_pass_enabled(water_only))
	var neutral := profiles.parameters(options, 12.0, Vector4(0, 1, 0, 0))
	assert(neutral.environment_day_lut_weights == Vector4.ZERO)
	assert(neutral.environment_season_lut_weights == Vector4(0, 1, 0, 0), "Summer's authored tonal LUT was bypassed")
	assert(neutral.environment_weather_lut_weights_a == Vector4.ZERO)
	# Authored grading has more color separation at the tonal ends than in
	# middle gray; these numeric tables retain opaque black and legal RGB.
	for name in ["day_morning", "day_evening", "day_night"] + CityVisualLuts.GROUPS.season:
		var table := (CityVisualLuts.BUILTINS[name] as Texture2D).get_image()
		var middle := _gray_difference(table, 15)
		assert(_gray_difference(table, 4) > middle and _gray_difference(table, 28) > middle, "Tonal ends are not emphasized: " + name)
		assert(table.get_pixel(0, 0) == Color.BLACK)
	for hour in range(24):
		var weights := CityVisualLuts.day_weights(hour)
		assert(is_equal_approx(weights.x + weights.y + weights.z + weights.w, 1.0))
	assert(CityVisualLuts.day_weights(7.0) == Vector4(1, 0, 0, 0))
	assert(CityVisualLuts.day_weights(19.0) == Vector4(0, 0, 1, 0))
	assert(CityVisualLuts.day_weights(0.0) == CityVisualLuts.day_weights(24.0))
	profiles.advance_weather(0, 0, 4, true)
	profiles.advance_weather(3, 1, 4, true)
	assert(profiles.weather_weights[0] == 0.75 and profiles.weather_weights[3] == 0.25)
	profiles.advance_weather(6, 1, 4, true)
	assert(profiles.weather_weights[3] > 0.0 and profiles.weather_weights[6] == 0.25)
	var total := 0.0
	for weight in profiles.weather_weights:
		total += weight
	assert(is_equal_approx(total, 1.0), "Interrupted transition changed the total intensity")
	profiles.advance_weather(6, 0, 4, false)
	assert(profiles.weather_weights == PackedFloat32Array([1, 0, 0, 0, 0, 0, 0]))
	profiles.advance_weather(0, 0, 4, true)
	assert(profiles.weather_weights == PackedFloat32Array([1, 0, 0, 0, 0, 0, 0]))
	for _i in range(40):
		profiles.advance_weather(3, 0.1, 4, true)
	assert(is_equal_approx(profiles.weather_weights[3], 1.0))
	for _i in range(41):
		profiles.advance_weather(0, 0.1, 4, true)
	assert(profiles.weather_weights == PackedFloat32Array([1, 0, 0, 0, 0, 0, 0]), "Sunny did not finish at exact neutral")
	options.day_enabled = false
	options.season_enabled = false
	options.weather_enabled = false
	var disabled := profiles.parameters(options, 0.0, Vector4(0, 0, 0, 1))
	assert(disabled.environment_day_lut_strength == 0.0 and disabled.environment_season_lut_strength == 0.0 and disabled.environment_weather_lut_strength == 0.0)
	var folder := ProjectSettings.globalize_path("user://lut_test_%d" % OS.get_process_id())
	assert(CityVisualLuts.export_profiles(folder).is_empty())
	var path := folder.path_join("day_morning.png")
	var image := Image.create(1024, 32, false, Image.FORMAT_RGB8)
	image.fill(Color(1, 0, 0))
	assert(image.save_png(path) == OK)
	var authored := FileAccess.get_file_as_bytes(path)
	assert(CityVisualLuts.export_profiles(folder).is_empty())
	assert(FileAccess.get_file_as_bytes(path) == authored, "Export overwrote an edited LUT")
	profiles.reload(folder)
	assert(profiles.issues.is_empty())
	assert(profiles.atlases.day.get_image().get_pixel(10, 10) == Color.RED)
	DirAccess.remove_absolute(folder.path_join("weather_heavy_rain.png"))
	image = Image.create(16, 16, false, Image.FORMAT_RGB8)
	assert(image.save_png(folder.path_join("season_autumn.png")) == OK)
	image = Image.create(1024, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 0, 0, 0.5))
	assert(image.save_png(folder.path_join("day_evening.png")) == OK)
	profiles.reload(folder)
	assert(profiles.issues.size() == 3)
	assert(profiles.identities.weather[2] == 1 and profiles.identities.season[2] == 1 and profiles.identities.day[2] == 1)
	var invalid := FileAccess.open(folder.path_join("day_night.png"), FileAccess.WRITE)
	invalid.store_string("This is not a PNG image.")
	invalid.close()
	profiles.reload(folder)
	assert(profiles.issues.size() == 4 and profiles.identities.day[3] == 1)
	assert(profiles.atlases.day.get_image().get_pixel(10, 10) == Color.RED, "One invalid file discarded valid profiles")
	var prefs := VisualEnhancementOptions.normalize({"day_lut_strength": NAN, "season_lut_strength": -1, "weather_lut_strength": 2})
	assert(prefs.day_lut_strength == 0.5 and prefs.season_lut_strength == 0 and prefs.weather_lut_strength == 1)
	print("PASS: LUT assets, identity bypass, time profiles, interrupted transitions, independent strengths, safe reload/export and neutral fallbacks")
	quit()


func _gray_difference(table: Image, sample: int) -> float:
	var color := table.get_pixel(sample * 32 + sample, sample)
	var input := float(sample) / 31.0
	return maxf(absf(color.r - input), maxf(absf(color.g - input), absf(color.b - input)))
