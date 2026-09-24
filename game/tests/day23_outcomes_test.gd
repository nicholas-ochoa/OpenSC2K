extends SceneTree
## Day 23 goal boundaries, modal military results, and scenario completion.

class FixedRandom extends GameLcgRandom:
	func next_mod(_divisor: int) -> int:
		return 10


func _initialize() -> void:
	_check_goal_boundaries()
	_check_military_notices()
	_check_scenario_outcomes()
	print("PASS: day 23 numeric goals, military notices, victory continuation and loss events")
	quit()


func _city() -> CityState:
	return CityState.from_document(EmptyCityTemplate.create(128))


func _goals(city: CityState) -> ScenarioState:
	var goals := ScenarioState.new()
	goals.document = city.document
	return goals


func _check_goal_boundaries() -> void:
	var city := _city()
	var goals := _goals(city)
	for building in [1, 2]:
		goals.first_building_id = 13 if building == 1 else 0
		goals.second_building_id = 13 if building == 2 else 0
		goals.first_building_tile_count = 32768
		goals.second_building_tile_count = 32768
		city.document.set_misc_u32(Sc2MiscLayout.TILE_COUNTS + 13 * 4, 1)
		assert(goals.evaluate_goals(city).met, "Building requirements use signed 16-bit words")
		goals.first_building_tile_count = 1
		goals.second_building_tile_count = 1
		city.document.set_misc_u32(Sc2MiscLayout.TILE_COUNTS + 13 * 4, 65535)
		assert(not goals.evaluate_goals(city).met, "Building counts also use signed 16-bit words")

	goals = _goals(city)
	goals.land_value_goal = -2147483648
	city.document.set_misc_u32(Sc2MiscLayout.CITY_LAND_VALUE, 0)
	assert(not goals.evaluate_goals(city).met, "Land value uses an unsigned comparison")
	city.document.set_misc_u32(Sc2MiscLayout.CITY_LAND_VALUE, 0x80000000)
	assert(goals.evaluate_goals(city).met, "Land value equality passes across the sign bit")
	city.document.set_misc_u32(Sc2MiscLayout.CITY_LAND_VALUE, 0)

	for pair in [["education_goal", Sc2MiscLayout.WORKFORCE_EDUCATION], ["life_expectancy_goal", Sc2MiscLayout.WORKFORCE_LIFE_EXPECTANCY]]:
		goals = _goals(city)
		goals.set(pair[0], 32768)
		city.document.set_misc_u32(pair[1], 32768)
		assert(not goals.evaluate_goals(city).met, "The goal word is sign-extended before unsigned comparison")
		city.document.set_misc_u32(pair[1], 0xffff8000)
		assert(goals.evaluate_goals(city).met, "The unsigned workforce value can meet the sign-extended goal")
		city.document.set_misc_u32(pair[1], 0)

	for pair in [["pollution_limit", Sc2MiscLayout.CITY_POLLUTION], ["crime_limit", Sc2MiscLayout.CITY_CRIME], ["traffic_limit", Sc2MiscLayout.CITY_TRAFFIC]]:
		goals = _goals(city)
		goals.set(pair[0], 0x80000000)
		city.document.set_misc_u32(pair[1], 0xffffffff)
		assert(goals.evaluate_goals(city).met, "A nonpositive signed limit is disabled")
		goals.set(pair[0], 0x7fffffff)
		assert(not goals.evaluate_goals(city).met, "A positive limit compares the actual value unsigned")
		city.document.set_misc_u32(pair[1], 0)

	goals = _goals(city)
	city.set_funds(-2147483648)
	city.document.set_misc_u32(Sc2MiscLayout.BONDS, 1)
	assert(goals.evaluate_goals(city).met, "Cash after bonds wraps to signed 32-bit")
	city.set_funds(2147483647)
	city.document.set_misc_u32(Sc2MiscLayout.BONDS, 0xffffffff)
	assert(not goals.evaluate_goals(city).met, "Cash overflow wraps in both directions")

	var extended := CityState.from_document(EmptyCityTemplate.create(256))
	goals = _goals(extended)
	goals.first_building_id = 13
	goals.first_building_tile_count = 32768
	extended.document.set_misc_u32(Sc2MiscLayout.TILE_COUNTS + 13 * 4, 32768)
	assert(goals.evaluate_goals(extended).met, "Extended city counts retain their wider range")


func _military_controller(terrain: int) -> GameSpeedController:
	var city := _city()
	var chunk := city.document.find_chunk("XTER")
	var data := chunk.decoded_payload.duplicate()
	data.fill(terrain)
	assert(chunk.set_decoded_payload(data))
	city = CityState.from_document(city.document)
	city.set_age_in_days(21)
	city.set_funds(-100001)
	city.document.set_misc_u32(Sc2MiscLayout.PROGRESSION, 3)
	city.document.set_misc_u32(Sc2MiscLayout.NORMAL_POPULATION, 60001)
	var controller := GameSpeedController.new(SimulationEngine.new(city))
	controller.engine.game_random = FixedRandom.new()
	controller.set_speed(GameSpeedController.Speed.CHEETAH)
	var tick := controller.advance_time(200, 200)
	assert(tick.ok and controller.interaction_blocked)
	return controller


func _check_military_notices() -> void:
	for terrain in [0, 1]:
		var controller := _military_controller(terrain)
		var city := controller.engine.city
		var zones := city.zones.duplicate()
		var result := controller.resolve_military_proposal(true)
		assert(result.ok and result.notice_ids.size() == 1)
		assert(result.notice_ids[0] == (242 if terrain == 0 else 411))
		assert(controller.engine.pending_interaction == "military_notice")
		assert(controller.interaction_blocked and not controller.terminal_blocked)
		assert(not result.day_results[0].phase_results.has("bankruptcy"))
		assert(city.zones == zones, "Land reservation waits for the result notice")
		assert(not controller.engine.advance_day().ok)
		var random_state := controller.engine.game_random.state
		result = controller.resolve_military_notice()
		assert(result.ok and result.notice_ids.is_empty(), "Acknowledgement does not repeat the notice")
		assert(controller.engine.game_random.state == random_state, "Acknowledgement does not reroll the site")
		assert(controller.engine.pending_interaction.is_empty())
		assert(controller.terminal_blocked and result.game_over_events[0].type == "bankruptcy")
		assert(city.zone_id(10, 10) == (7 if terrain == 0 else 0))

	var declined := _military_controller(0)
	var result := declined.resolve_military_proposal(false)
	assert(result.ok and result.notice_ids.is_empty() and declined.terminal_blocked)


func _scenario_city() -> CityState:
	var document := EmptyCityTemplate.create(128)
	var chunk := Sc2Chunk.new()
	chunk.chunk_id = "SCEN"
	var data := PackedByteArray()
	data.resize(56)
	BinaryData.write_u32_be(data, 0, 0x80000000)
	BinaryData.write_u16_be(data, 8, 1)
	chunk.set_decoded_payload(data)
	document.chunks.append(chunk)
	var city := CityState.from_document(document)
	city.set_age_in_days(21)
	return city


func _check_scenario_outcomes() -> void:
	for outcome in ["scenario_victory", "scenario_failure", "bankruptcy"]:
		var city := _scenario_city()
		var controller := GameSpeedController.new(SimulationEngine.new(city))
		if outcome == "scenario_failure":
			controller.engine.scenario.city_size_goal = 0xffffffff
		elif outcome == "bankruptcy":
			controller.engine.scenario = null
			city.set_funds(-100001)
		controller.set_speed(GameSpeedController.Speed.CHEETAH)
		var result := controller.advance_time(1000, 1000)
		assert(result.ok and result.game_over_events.size() == 1)
		var event := result.game_over_events[0]
		assert(event.type == outcome)
		assert(event.sound_id == (513 if outcome == "scenario_victory" else 512))
		assert(event.is_terminal() == (outcome != "scenario_victory"))
		assert(controller.engine.scenario == null, "Every outcome clears the active scenario")
		assert(city.age_in_days() == 22, "The outcome stops catch-up until acknowledgement")
		controller.acknowledge_game_over()
		assert(controller.engine.advance_day().ok == (outcome == "scenario_victory"))

	var source := GameSpeedController.new(SimulationEngine.new(_scenario_city()))
	var captured := SimulationSnapshot.capture(source, null)
	assert(captured.engine.advance_day().ok)
	assert(source.engine.scenario != null and captured.engine.scenario == null)
	SimulationSnapshot.publish(captured, source)
	assert(source.engine.scenario == null and not source.engine.terminal_state)
	assert(SimulationSnapshot.capture(source, null).engine.scenario == null)
