extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := ProjectSettings.globalize_path("res://../references/SIMCITY2000/CITIES/BABAR.SC2")
	var source_bytes := FileAccess.get_file_as_bytes(path)
	var document := Sc2File.load_path(path)
	assert(document.is_valid())
	var city := CityState.from_document(document)
	assert(city.age_in_days() == 0)
	var engine := SimulationEngine.new(city)
	var speed := GameSpeedController.new(engine)
	assert(speed.set_speed(GameSpeedController.Speed.TURTLE))
	var status := (load("res://src/ui/shell/city_status_bar.tscn") as PackedScene).instantiate() as CityStatusBar
	root.add_child(status)
	var resources := PeStringResource.load_ids(
		ProjectSettings.globalize_path("res://../references/SIMCITY2000/SIMCITY.EXE"),
		CityStatusMessages.resource_ids()
	)
	assert(resources.ok)
	status.resource_strings = resources.strings
	var shortage_day := -1

	# Use the same timer and event delivery as the live status bar.
	for pulse in range(1, 201):
		var result := speed.advance_time(200.0, pulse * 200)
		assert(result.ok, str(result))
		status.set_city_status(engine, false, resources.strings)
		status.update_report_rotation(0.2)
		if not result.news_items.is_empty():
			status.prepend_news_items(result.news_items)
		for item in result.news_items:
			if int(item.type) == 50:
				shortage_day = city.age_in_days()
				assert(status.reports_label.text == str(resources.strings[269]).strip_edges(),
					"Babar's shortage must have a specific status label: " + status.reports_label.text)
		if city.age_in_days() >= 25:
			break

	assert(shortage_day == 24, "Babar shortage was not reported on day 24")
	assert(city.age_in_days() == 25)
	assert(engine.water_usage_percent == 100)
	assert(status.recent_reports.has(str(resources.strings[269]).strip_edges()))
	var before := document.serialize().data as PackedByteArray
	status.update_report_rotation(CityStatusBar.REPORT_ROTATION_SECONDS)
	assert(document.serialize().data == before, "Rotating reports changed saved data")
	assert(FileAccess.get_file_as_bytes(path) == source_bytes)
	_check_status_cases(status, engine, resources.strings)
	_check_worker_state(speed)
	_check_source_tables(path.get_base_dir().get_base_dir().path_join("SIMCITY.EXE"))
	_check_weather_phase(city)
	await _check_main_ui(resources.strings)
	status.free()
	print("PASS: Babar Turtle water-shortage event reaches the status bar before February")
	quit()


func _check_status_cases(status: CityStatusBar, engine: SimulationEngine, strings: Dictionary) -> void:
	var before := engine.city.document.serialize().data as PackedByteArray
	for need in CityStatusMessages.NEED_COUNT:
		engine.city_status_resource_id = CityStatusMessages.monthly_resource(need, 0)
		status.set_city_status(engine, false, strings)
		var expected := str(strings[265 + need]).strip_edges()
		assert(not expected.is_empty())
		assert(status.reports_label.text == expected)
		assert(CityStatusBar.report_name(46 + need, strings) == expected)
		status.prepend_reports(PackedStringArray(["Unrelated report"]))
		status.update_report_rotation(8.0)
		assert(status.reports_label.text == expected, "Rotating reports lost an active need")

	for weather in CityStatusMessages.WEATHER_COUNT:
		var label := CityStatusMessages.text(33200 + weather, strings)
		assert(label == RciAftermathPhase.WEATHER_NAMES[weather])
		status.set_environment(Vector3i.ZERO, label)
		assert(status.weather_label.text.contains(label))
		if weather >= 9:
			engine.city_status_resource_id = CityStatusMessages.monthly_resource(WeatherDisasterPhase.STATUS_WEATHER, weather)
			status.set_city_status(engine, false, strings)
			assert(status.reports_label.text == str(strings[272 + weather]).strip_edges())

	for disaster in range(1, 19):
		engine.active_disaster_type = disaster
		status.set_city_status(engine, false, strings)
		var expected := str(strings[CityStatusMessages.DISASTER_IDS[disaster]]).strip_edges() if disaster <= 16 else ""
		assert(status.reports_label.text == expected)
		status.set_city_status(engine, true, strings)
		assert(status.reports_label.text == str(strings[528]).strip_edges())
		status.show_music_notice("Playing: Test")
		assert(status.reports_label.text == str(strings[528]).strip_edges())
		status.update_report_rotation(5.1)

	engine.active_disaster_type = 0
	engine.city_status_resource_id = 269
	status.set_city_status(engine, false, strings)
	assert(status.reports_label.text == str(strings[269]).strip_edges())
	engine.city_status_resource_id = CityStatusMessages.monthly_resource(WeatherDisasterPhase.STATUS_NONE, 0)
	status.set_city_status(engine, false, strings)
	assert(status.reports_label.text.is_empty(), "Cleared need restored an old report")
	status.set_city_status(null, false, strings)
	status.set_reports(PackedStringArray())
	assert(CityStatusMessages.text(280, strings) == str(strings[280]).strip_edges())
	assert(CityStatusMessages.text(0, strings).is_empty())
	assert(CityStatusMessages.monthly_resource(WeatherDisasterPhase.STATUS_WEATHER, 255) == 0)
	assert(engine.city.document.serialize().data == before, "Updating status changed saved data")


func _check_worker_state(controller: GameSpeedController) -> void:
	controller.engine.city_status_resource_id = 269
	var worker := SimulationSnapshot.capture(controller, SimulationSliceBudget.new())
	assert(worker.engine.city_status_resource_id == 269)
	worker.engine.city_status_resource_id = 283
	SimulationSnapshot.publish(worker, controller)
	assert(controller.engine.city_status_resource_id == 283)


func _check_source_tables(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	var pe := bytes.decode_u32(0x3c)
	var section_count := bytes.decode_u16(pe + 6)
	var sections := pe + 24 + bytes.decode_u16(pe + 20)
	for spec in [[0xe98b8, range(265, 284)], [0xe6078, range(33200, 33212)], [0xe6010, CityStatusMessages.DISASTER_IDS]]:
		var found := false
		for section in section_count:
			var header := sections + section * 40
			var rva := bytes.decode_u32(header + 12)
			var length := bytes.decode_u32(header + 16)
			if int(spec[0]) < rva or int(spec[0]) + spec[1].size() * 4 > rva + length:
				continue
			var offset := bytes.decode_u32(header + 20) + int(spec[0]) - rva
			for index in spec[1].size():
				assert(bytes.decode_u32(offset + index * 4) == int(spec[1][index]))
			found = true
			break
		assert(found, "Status lookup table differs from the executable")


func _check_weather_phase(source: CityState) -> void:
	for weather in CityStatusMessages.WEATHER_COUNT:
		var city := CityState.from_document(source.document.duplicate_document(true))
		assert(city.set_age_in_days(23))
		assert(city.set_no_disasters_enabled(true))
		assert(city.document.set_misc_u32(RciAftermathPhase.MISC_WEATHER_TREND, weather))
		var engine := SimulationEngine.new(city)
		engine.power_usage_percent = 0
		engine.water_usage_percent = 100
		var result := engine.advance_day()
		assert(result.ok)
		var phase: WeatherDisasterPhase.Result = result.phase_results.weather_disaster
		if weather >= 9:
			assert(phase.status_index == WeatherDisasterPhase.STATUS_WEATHER)
			assert(engine.city_status_resource_id == 272 + weather)
			assert(phase.news_items.is_empty(), "Weather alert entered the newspaper queue")
		else:
			assert(phase.status_index == WeatherDisasterPhase.STATUS_WATER)
			assert(engine.city_status_resource_id == 269)


func _check_main_ui(strings: Dictionary) -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("user://missing-test-art"))
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	main.asset_state.reference_root = ProjectSettings.globalize_path("user://missing-test-originals")
	main.preferences.settings_path = "user://water-shortage-status-test.cfg"
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.original_text_resources.original_query_strings = strings
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	main.set_process(false)
	main.city_status_bar.music_notice_seconds = 0
	main.simulation_engine.city_status_resource_id = 269
	main.frame.select_speed(GameSpeedController.Speed.TURTLE)
	assert(main.city_status_bar.reports_label.text == str(main.original_text_resources.original_query_strings[269]).strip_edges())
	for weather in CityStatusMessages.WEATHER_COUNT:
		assert(main.document_state.city.document.set_misc_u32(RciAftermathPhase.MISC_WEATHER_TREND, weather))
		main.interface.refresh_status_summary()
		assert(main.city_status_bar.weather_label.text.contains(RciAftermathPhase.WEATHER_NAMES[weather]))
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	assert(main.city_status_bar.reports_label.text == str(main.original_text_resources.original_query_strings[528]).strip_edges())
	main.simulation_engine.active_disaster_type = 16
	main.frame.select_speed(GameSpeedController.Speed.TURTLE)
	assert(main.city_status_bar.reports_label.text == str(main.original_text_resources.original_query_strings[CityStatusMessages.DISASTER_IDS[16]]).strip_edges())
	main.simulation_engine.active_disaster_type = 0
	main.interface.refresh_status_summary()
	assert(main.city_status_bar.reports_label.text == str(main.original_text_resources.original_query_strings[269]).strip_edges())
	main.queue_free()
	await process_frame
