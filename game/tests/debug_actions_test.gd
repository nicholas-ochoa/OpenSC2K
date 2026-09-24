extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_run_to_date()
	_check_military_offer()
	_check_moving_things()
	_check_funds()
	print("PASS: debug actions pause on the target date, offer a military base, add or remove moving things and set funds")
	quit()


func _controller() -> GameSpeedController:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var controller := GameSpeedController.new(SimulationEngine.new(city, 123, 456, 789))
	assert(controller.set_speed(GameSpeedController.Speed.AFRICAN_SWALLOW))

	return controller


func _check_run_to_date() -> void:
	var controller := _controller()
	var city := controller.engine.city
	var target := CityDebugActions.age_for_date(city, 2, 4, city.founding_year())
	assert(target == CityCalendar.DAYS_PER_MONTH + 3)
	controller.pause_at_day = target
	var paused := false

	# fast speed runs one day per base tick. the pause stops the rest of the frame
	for frame in 20:
		var result := controller.advance_time(GameSpeedController.BASE_TICK_MSEC * 4.0, frame * 1000)
		assert(result.ok, result.error)
		paused = paused or result.paused_on_target_day

	assert(paused and city.age_in_days() == target, "Expected a pause on day %d, not %d" % [target, city.age_in_days()])
	assert(controller.speed == GameSpeedController.Speed.PAUSED and controller.pause_at_day == -1)
	assert(city.simulation_speed() == GameSpeedController.Speed.PAUSED, "The saved speed follows the pause")

	# a pause before the date cancels the run
	assert(controller.set_speed(GameSpeedController.Speed.TURTLE))
	controller.pause_at_day = target + 10
	assert(controller.set_speed(GameSpeedController.Speed.PAUSED) and controller.pause_at_day == -1)


func _check_military_offer() -> void:
	var controller := _controller()
	var engine := controller.engine
	var document := engine.city.document
	var day := engine.clock.city_days
	assert(CityDebugActions.offer_military_base(controller).ok)
	assert(controller.interaction_blocked and engine.pending_interaction == "military_proposal")
	assert(not CityDebugActions.offer_military_base(controller).ok, "Only one prompt can wait")
	assert(controller.advance_time(GameSpeedController.BASE_TICK_MSEC * 4.0, 0).ok)
	assert(engine.clock.city_days == day, "The simulation waits for the answer")

	# the answer runs no other day phases
	var declined := controller.resolve_military_proposal(false)
	assert(declined.ok, declined.error)
	assert(declined.day_results[0].applied == PackedStringArray(["milestones"]))
	assert(document.misc_u32(Sc2MiscLayout.MILITARY_BASE_TYPE) == MilitaryProposalPhase.BASE_DECLINED)
	assert(not controller.interaction_blocked and engine.pending_interaction.is_empty())

	# a declined offer can be shown again. a city with a base cannot get one
	assert(CityDebugActions.offer_military_base(controller).ok)
	assert(controller.resolve_military_proposal(true).ok)
	assert(controller.interaction_blocked)
	assert(controller.resolve_military_notice().ok)
	assert(document.set_misc_u32(Sc2MiscLayout.MILITARY_BASE_TYPE, MilitaryProposalPhase.BASE_ARMY))
	var refused := CityDebugActions.offer_military_base(controller)
	assert(not refused.ok and not controller.interaction_blocked)


func _check_moving_things() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/SYDNEY.SC2"))
	var document := city.document
	var engine := SimulationEngine.new(city, 123, 456, 789)
	var removed := CityDebugActions.remove_moving_things(city, document)
	assert(removed.ok and removed.count > 0, removed.error)
	assert(_thing_count(city) == 0 and _linked_tiles(city) == 0, "Removal clears records and map links")
	assert(not CityDebugActions.remove_moving_things(city, document).ok, "Nothing is left to remove")
	var edge := city.map_size
	var buildings: PackedByteArray = document.find_chunk("XBLD").decoded_payload
	var flags: PackedByteArray = document.find_chunk("XBIT").decoded_payload
	var clear_land := func(index: int) -> bool: return flags[index] & Sc2TileFlags.WATER == 0 and city.text_overlays[index] == 0
	var land := _find(city, clear_land)
	var water := _find(city, func(index: int) -> bool:
		var point := Vector2i(index / edge, index % edge)
		return point.x > 0 and point.x < edge - 1 and flags[index] & Sc2TileFlags.WATER != 0 \
			and flags[index + 1] & Sc2TileFlags.WATER != 0 and buildings[index + 1] == 0 and city.text_overlays[index + 1] == 0)
	var rail := _find(city, func(index: int) -> bool:
		return buildings[index] >= BuildingTileIds.RAIL_STRAIGHT_1 and buildings[index] <= BuildingTileIds.RAIL_CURVE_4)
	assert(land.x >= 0 and water.x >= 0 and rail.x >= 0, "The fixture has land, open water and rail")
	var added := 0

	# each land spawn takes the first clear tile, so the next spawn finds another one
	for pair in [[0, null], [1, null], [2, land], [3, water], [4, rail]]:
		var point: Vector2i = _find(city, clear_land) if pair[1] == null else pair[1]
		var spawned := CityDebugActions.spawn_moving_thing(city, document, engine, pair[0], point, 99)
		assert(spawned.ok, "%s: %s" % [CityDebugActions.SPAWN_TYPES[pair[0]], spawned.error])
		added += spawned.count

	# a train uses three records. the spawn does not change the simulation random state
	assert(_thing_count(city) == added + 2 and _linked_tiles(city) > 0)
	assert(engine.ship_home.x >= 0)
	assert(engine.random.state == 123 and engine.lfsr_random.state == 456 and engine.game_random.state == 789)
	assert(not CityDebugActions.spawn_moving_thing(city, document, engine, 0, _find(city, clear_land), 99).ok,
		"The helicopter limit applies")
	removed = CityDebugActions.remove_moving_things(city, document)
	assert(removed.ok and removed.count == added + 2 and _linked_tiles(city) == 0)


func _thing_count(city: CityState) -> int:
	var count := 0

	for record in range(1, city.thing_count()):
		if city.thing(record).type != 0:
			count += 1

	return count


func _linked_tiles(city: CityState) -> int:
	var count := 0

	for index in city.map_size * city.map_size:
		if OverlayData.is_thing(city.text_overlays[index]):
			count += 1

	return count


func _find(city: CityState, matches: Callable) -> Vector2i:
	for index in city.map_size * city.map_size:
		if matches.call(index):
			return Vector2i(index / city.map_size, index % city.map_size)

	return Vector2i(-1, -1)


func _check_funds() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))

	for amount in [0, -250000, CityDebugActions.MIN_FUNDS, CityDebugActions.MAX_FUNDS]:
		var result := CityDebugActions.set_funds(city, amount)
		assert(result.ok and city.funds() == amount, result.error)

	assert(not CityDebugActions.set_funds(city, CityDebugActions.MAX_FUNDS + 1).ok)
	assert(city.funds() == CityDebugActions.MAX_FUNDS)
