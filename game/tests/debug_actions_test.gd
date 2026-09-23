extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_run_to_date()
	_check_military_offer()
	print("PASS: debug actions pause on the target date and offer a military base")
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
	assert(document.set_misc_u32(Sc2MiscLayout.MILITARY_BASE_TYPE, MilitaryProposalPhase.BASE_ARMY))
	var refused := CityDebugActions.offer_military_base(controller)
	assert(not refused.ok and not controller.interaction_blocked)
