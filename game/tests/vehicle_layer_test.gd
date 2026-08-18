extends SceneTree

@warning_ignore_start("integer_division")

const AirConstants = preload("res://src/simulation/moving_things/air/constants.gd")
## The Vehicles layer hides vehicles, drops their sounds and stops their
## spontaneous crashes. Disaster objects and started disasters are unchanged.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_crash_rules()
	await _check_application()
	print("PASS: the Vehicles layer hides vehicles, mutes them and stops their crashes")
	quit()


## An airplane that flies low into a tall building crashes only while vehicles
## are shown. A falling plane from a started disaster crashes either way.
func _check_crash_rules() -> void:
	for suppress in [false, true]:
		var city := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/FLARANGE.SC2"))
		# The supplied city saves No Disasters, which already stops every crash.
		assert(city.set_no_disasters_enabled(false))
		var tower := _tall_building(city)
		var record := _place_airplane(city, tower, 2, 0)
		var result := MovingThingPhase.run(city, SimRandom.new(7), SimLfsrRandom.new(9), GameLcgRandom.new(3), Vector2i(-1, -1), true, 1000, 0, suppress)
		assert(result.ok)
		var type := int(city.thing(record).type)

		if suppress:
			assert(type == 1 and result.crashed_airplanes == 0, "A hidden airplane does not hit a building")
		else:
			assert(type == 6 and result.crashed_airplanes == 1, "A shown airplane hits a building")

	var falling := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/FLARANGE.SC2"))
	assert(falling.set_no_disasters_enabled(false))
	var record := _place_airplane(falling, Vector2i(40, 40), 7, 0)
	var crash := MovingThingPhase.run(falling, SimRandom.new(7), SimLfsrRandom.new(9), GameLcgRandom.new(3), Vector2i(-1, -1), true, 1000, 0, true)
	assert(crash.ok and int(falling.thing(record).type) == 6, "A started plane crash still crashes while vehicles are hidden")


func _check_application() -> void:
	OS.set_environment("OPENSC2K_CITY_RENDERER", "cpu")
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	assert(main.city_session.activate_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/FLARANGE.SC2")))
	var vehicle := -1

	for record in main.document_state.city.thing_count():
		if int(main.document_state.city.thing(record).type) == 1:
			vehicle = record

	assert(vehicle >= 0)
	var thing: ThingRecord = main.document_state.city.thing(vehicle)
	main.map_view.zoom_factor = 1.0
	main.map_view.center_on_tile(Vector2i(int(thing.x), int(thing.y)))
	main.map_render.refresh_map()
	var shown: int = main.map_view.dynamic_sprites.size()
	assert(shown > 0, "A shown vehicle draws")
	assert(main.simulation_state.simulation_engine.vehicle_crashes_enabled)

	var sounds := [
		{"sound_id": 518, "thing_type": 1, "record": vehicle},
		{"sound_id": 514, "thing_type": 5, "record": 3},
		509,
	]
	assert(main.moving_sprites.audible_sound_events(sounds).size() == 3)

	main.city_toolbar.view_visibility_checks.vehicles.button_pressed = false
	assert(not main.view_state.show_vehicles, "The sidebar check hides vehicles")
	assert(not main.simulation_state.simulation_engine.vehicle_crashes_enabled, "Hidden vehicles cannot crash")
	assert(main.map_view.dynamic_sprites.size() < shown, "A hidden vehicle does not draw")
	var audible: Array = main.moving_sprites.audible_sound_events(sounds)
	assert(audible.size() == 2 and not audible.has(sounds[0]), "Only vehicle sounds are dropped")
	var menu := main.view_menu.get_popup() as PopupMenu
	assert(not menu.is_item_checked(menu.get_item_index(CityMenuBar.MENU_VIEW_VEHICLES)), "The View menu follows the sidebar")

	# Opening another city keeps the layer choice in its new engine.
	assert(main.city_session.activate_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/CAPE.SC2")))
	assert(not main.simulation_state.simulation_engine.vehicle_crashes_enabled)
	main.menus.on_view_menu(CityMenuBar.MENU_VIEW_VEHICLES)
	assert(main.view_state.show_vehicles and main.simulation_state.simulation_engine.vehicle_crashes_enabled, "The View menu shows vehicles again")
	assert(main.city_toolbar.view_visibility_checks.vehicles.button_pressed)
	main.queue_free()
	await process_frame


func _tall_building(city: CityState) -> Vector2i:
	for index in city.buildings.size():
		var building := int(city.buildings[index])

		# A tall building away from an airport. Z 0 hits when a third of its height is positive.
		if (
			building >= 0x71 and building <= 0xfa and (int(city.zones[index]) & 0x0f) != 8
			and int(AirConstants.BUILDING_SPRITE_HEIGHTS[building - 0x71] / 3) > 0
		):
			return Vector2i(index / city.map_size, index % city.map_size)

	assert(false, "The test city needs a tall building")

	return Vector2i.ZERO


func _place_airplane(city: CityState, point: Vector2i, state: int, z: int) -> int:
	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")
	var things := thing_chunk.decoded_payload.duplicate()
	var text := text_chunk.decoded_payload.duplicate()
	var record := -1

	for candidate in range(1, city.thing_count()):
		if things[candidate * CityState.THING_RECORD_SIZE] == 0:
			record = candidate
			break

	assert(record > 0)
	var offset := record * CityState.THING_RECORD_SIZE
	ThingData.write(things, offset, 1)
	ThingData.write(things, offset + 1, 2)
	ThingData.write(things, offset + 2, state)
	ThingData.write(things, offset + 3, point.x)
	ThingData.write(things, offset + 4, point.y)
	ThingData.write(things, offset + 5, z)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 10, OverlayData.read(text, point.x * city.map_size + point.y))
	OverlayData.write(text, point.x * city.map_size + point.y, OverlayData.thing_id(record))
	assert(thing_chunk.set_decoded_payload(things) and text_chunk.set_decoded_payload(text))
	city.text_overlays = text.duplicate()

	return record
