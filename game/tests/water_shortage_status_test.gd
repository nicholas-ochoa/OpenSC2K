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
	var shortage_day := -1

	# Use the same timer and event delivery as the live status bar.
	for pulse in range(1, 201):
		var result := speed.advance_time(200.0, pulse * 200)
		assert(result.ok, str(result))
		status.set_city_status(engine, false)
		status.update_report_rotation(0.2)
		if not result.news_items.is_empty():
			status.prepend_news_items(result.news_items)
		for item in result.news_items:
			if int(item.type) == 50:
				shortage_day = city.age_in_days()
				assert(status.reports_label.text == CityStatusMessages.NEEDS[4],
					"Babar's shortage must have a specific status label: " + status.reports_label.text)
		if city.age_in_days() >= 25:
			break

	assert(shortage_day == 24, "Babar shortage was not reported on day 24")
	assert(city.age_in_days() == 25)
	assert(engine.water_usage_percent == 100)
	assert(status.recent_reports.has(CityStatusMessages.NEEDS[4]))
	var before := document.serialize().data as PackedByteArray
	status.update_report_rotation(CityStatusBar.REPORT_ROTATION_SECONDS)
	assert(document.serialize().data == before, "Rotating reports changed saved data")
	assert(FileAccess.get_file_as_bytes(path) == source_bytes)
	_check_status_cases(status, engine)
	_check_worker_state(speed)
	_check_source_tables(path.get_base_dir().get_base_dir().path_join("SIMCITY.EXE"))
	_check_weather_phase(city)
	await _check_main_ui()
	status.free()
	print("PASS: Babar Turtle water-shortage event reaches the status bar before February")
	quit()


func _check_status_cases(status: CityStatusBar, engine: SimulationEngine) -> void:
	var before := engine.city.document.serialize().data as PackedByteArray
	for need in CityStatusMessages.NEED_COUNT:
		engine.city_status_resource_id = CityStatusMessages.monthly_resource(need, 0)
		status.set_city_status(engine, false)
		var expected := CityStatusMessages.NEEDS[need]
		assert(status.reports_label.text == expected)
		assert(CityStatusBar.report_name(46 + need) == expected)
		status.prepend_reports(PackedStringArray(["Unrelated report"]))
		status.update_report_rotation(8.0)
		assert(status.reports_label.text == expected, "Rotating reports lost an active need")

	for weather in CityStatusMessages.WEATHER_COUNT:
		var label := CityStatusMessages.text(33200 + weather)
		assert(label == RciAftermathPhase.WEATHER_NAMES[weather])
		status.set_environment(Vector3i.ZERO, label)
		assert(status.weather_label.text.contains(label))
		if weather >= 9:
			engine.city_status_resource_id = CityStatusMessages.monthly_resource(WeatherDisasterPhase.STATUS_WEATHER, weather)
			status.set_city_status(engine, false)
			assert(status.reports_label.text == CityStatusMessages.WARNINGS[weather - 9])

	for disaster in range(1, 19):
		engine.active_disaster_type = disaster
		status.set_city_status(engine, false)
		var expected := CityStatusMessages.DISASTERS[disaster] if disaster <= 16 else ""
		assert(status.reports_label.text == expected)
		status.set_city_status(engine, true)
		assert(status.reports_label.text == CityStatusMessages.PAUSED_TEXT)
		status.show_music_notice("Playing: Test")
		assert(status.reports_label.text == CityStatusMessages.PAUSED_TEXT)
		status.update_report_rotation(5.1)

	engine.active_disaster_type = 0
	engine.city_status_resource_id = 269
	status.set_city_status(engine, false)
	assert(status.reports_label.text == CityStatusMessages.NEEDS[4])
	engine.city_status_resource_id = CityStatusMessages.monthly_resource(WeatherDisasterPhase.STATUS_NONE, 0)
	status.set_city_status(engine, false)
	assert(status.reports_label.text.is_empty(), "Cleared need restored an old report")
	status.set_city_status(null, false)
	status.set_reports(PackedStringArray())
	assert(CityStatusMessages.text(CityStatusMessages.BROWNOUT) == CityStatusMessages.BROWNOUTS)
	assert(CityStatusMessages.text(0).is_empty())
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


## The status bar offers the locate button only while a disaster is active.
func _check_disaster_locate(main) -> void:
	var city: CityState = main.document_state.city
	assert(main.city_status_bar.locate_disaster_button.visible, "An active disaster must offer the locate button")
	main.city_status_bar.locate_disaster_button.pressed.emit()
	assert(main.status_label.text == "The disaster could not be located.",
		"An unlocated disaster must report the failure: " + main.status_label.text)
	var fire := Vector2i(60, 70)
	assert(city.set_text_overlay_id(fire.x, fire.y, DisasterMapConstants.FIRE_OVERLAY))
	assert(DisasterFocus.find_point(city) == fire, "Disaster location missed the fire marker")

	for spread in [2, 10]:
		assert(city.set_text_overlay_id(fire.x, fire.y + spread, DisasterMapConstants.FIRE_OVERLAY))

	assert(DisasterFocus.find_point(city) == Vector2i(fire.x, fire.y + 2),
		"Spread markers must locate the tile nearest their middle")
	# Map art is absent in this run, so bind the camera city the renderer would supply.
	main.map_view.city = city
	assert(main.map_view.center_on_tile(Vector2i(10, 10)))
	main.city_status_bar.locate_disaster_button.pressed.emit()
	assert(main.map_view.center_tile() == Vector2i(fire.x, fire.y + 2),
		"The locate button must center the map on the disaster: " + str(main.map_view.center_tile()))
	var monster := Vector2i(20, 30)
	var thing_chunk := city.document.find_chunk("XTHG")
	var things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	ThingData.write(things, CityState.THING_RECORD_SIZE, DisasterStartConstants.TYPE_MONSTER)
	ThingData.write(things, CityState.THING_RECORD_SIZE + 3, monster.x)
	ThingData.write(things, CityState.THING_RECORD_SIZE + 4, monster.y)
	assert(thing_chunk.set_decoded_payload(things))
	assert(DisasterFocus.find_point(city) == monster, "Map marker took priority over the disaster object")

	for spread in [0, 2, 10]:
		assert(city.set_text_overlay_id(fire.x, fire.y + spread, 0))

	ThingData.write(things, CityState.THING_RECORD_SIZE, 0)
	assert(thing_chunk.set_decoded_payload(things))
	assert(DisasterFocus.find_point(city).x < 0, "Finished disaster still returned a location")


func _check_main_ui() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("user://missing-test-art"))
	var main = (load("res://main.tscn") as PackedScene).instantiate()
	main.asset_state.reference_root = ProjectSettings.globalize_path("user://missing-test-originals")
	main.preferences.settings_path = "user://water-shortage-status-test.cfg"
	root.add_child(main)
	await process_frame
	main.set_process(false)
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	main.set_process(false)
	main.city_status_bar.music_notice_seconds = 0
	main.simulation_state.simulation_engine.city_status_resource_id = 269
	main.frame.select_speed(GameSpeedController.Speed.TURTLE)
	assert(main.city_status_bar.reports_label.text == CityStatusMessages.NEEDS[4])
	for weather in CityStatusMessages.WEATHER_COUNT:
		assert(main.document_state.city.document.set_misc_u32(RciAftermathPhase.MISC_WEATHER_TREND, weather))
		main.interface.refresh_status_summary()
		assert(main.city_status_bar.weather_label.text.contains(RciAftermathPhase.WEATHER_NAMES[weather]))
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	assert(main.city_status_bar.reports_label.text == CityStatusMessages.PAUSED_TEXT)
	main.simulation_state.simulation_engine.active_disaster_type = 16
	main.frame.select_speed(GameSpeedController.Speed.TURTLE)
	assert(main.city_status_bar.reports_label.text == CityStatusMessages.DISASTERS[16])
	_check_disaster_locate(main)
	main.simulation_state.simulation_engine.active_disaster_type = 0
	main.interface.refresh_status_summary()
	assert(not main.city_status_bar.locate_disaster_button.visible, "The locate button must leave with the disaster")
	assert(main.city_status_bar.reports_label.text == CityStatusMessages.NEEDS[4])
	main.queue_free()
	await process_frame
