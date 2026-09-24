class_name SimulationEngine
extends RefCounted

const RciAftermath = preload("res://src/simulation/growth/rci_aftermath_phase.gd")
const SimNation = preload("res://src/simulation/civic/simnation_phase.gd")
const Industries = preload("res://src/simulation/growth/industry_phase.gd")
const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const WeatherDisaster = preload("res://src/simulation/disasters/weather_disaster_phase.gd")
const Music = preload("res://src/audio/music_director.gd")

var city: CityState
var clock: SimulationClock
var random: SimRandom
var lfsr_random: SimLfsrRandom
var game_random: GameLcgRandom
var ship_home := Vector2i(-1, -1)
var developed_tiles := -1
var power_usage_percent := -1
var water_usage_percent := -1
var city_status_resource_id := -1
var commerce_connections := 0
var industry_connections := 0
var traffic_news_deadline_msec := 0
var pending_interaction := ""
var pending_day_schedule: SimulationSchedule
var pending_military_site := Rect2i()
var pending_military_base_type := 0
var scenario: ScenarioState
var terminal_state := false
var bus_passengers := 0
var rail_passengers := 0
var subway_passengers := 0
var mayor_approval := 0
var pending_disaster_type := 0
var pending_disaster_point := Vector2i.ZERO
var active_disaster_type := 0
var unsupported_disaster_type := 0
var disaster_map_counter := 0
var disaster_hurricane_counter := 0
var midi_playback_active := false
# runtime only; never saved. false while the player hides the vehicle layer:
# airplanes and helicopters then leave instead of crashing, as with no disasters
var vehicle_crashes_enabled := true


func _init(
	initial_city: CityState, random_seed := 1, lfsr_seed := 1, game_random_seed := 1
) -> void:
	city = initial_city
	clock = SimulationClock.new(initial_city.age_in_days() if initial_city != null else 0)
	random = SimRandom.new(random_seed)
	lfsr_random = SimLfsrRandom.new(lfsr_seed)
	game_random = GameLcgRandom.new(game_random_seed)

	if initial_city != null and initial_city.is_valid():
		midi_playback_active = initial_city.music_enabled()
		pending_disaster_type = initial_city.disaster_type() & 0xffff

		if initial_city.document.find_chunk("SCEN") != null:
			var loaded_scenario := ScenarioState.from_document(initial_city.document)

			if loaded_scenario.is_valid():
				scenario = loaded_scenario
				pending_disaster_type = scenario.disaster_type
				pending_disaster_point = Vector2i(scenario.disaster_x, scenario.disaster_y)

		var connections := RciDemandPhase.connection_counts(initial_city)
		commerce_connections = connections.commerce
		industry_connections = connections.industry

		for record in range(1, city.thing_count()):
			var thing := initial_city.thing(record)

			if thing != null and thing.type == 3:
				ship_home = Vector2i(thing.x, thing.y)
				break


# the original loads a city file, then scans power and water and counts the
# developed tiles. the power scan uses the process random state
func initialize_loaded_city() -> bool:
	if city == null or not city.is_valid():
		return false

	if CityTileCounts.exact(city) and CityTileCounts.recount(city) < 0:
		return false

	var power := PowerPhase.run(city, random)

	if not power.ok:
		return false

	var water := WaterPhase.run(city)

	if not water.ok:
		return false

	var flags := city.tile_flags.duplicate()
	var map_edge := city.map_size
	var developed := 0

	for x in map_edge:
		for y in map_edge:
			var index := city.index_of(x, y)

			# the day-three scan has the same count and half-coordinate mark
			if city.buildings[index] >= BuildingTileIds.FIRST_ROAD or city.zones[index] & Sc2ZoneLayout.TYPE_MASK:
				flags[city.index_of(x >> 1, y >> 1)] |= Sc2TileFlags.MARK
				developed += 1

	if not city.replace_tile_flags(flags):
		return false

	power_usage_percent = power.usage_percent
	water_usage_percent = water.usage_percent
	developed_tiles = developed

	return true


func advance_moving_things(current_time_msec := -1) -> MovingThingResult:
	var span := SimulationTimingSpan.new(city.simulation_slice)
	var result := _timed_advance_moving_things(current_time_msec)
	result.timing = span.finish()

	return result


func _timed_advance_moving_things(current_time_msec := -1) -> MovingThingResult:
	if terminal_state:
		return MovingThingResult.failure("the game has ended")

	if current_time_msec < 0:
		current_time_msec = Time.get_ticks_msec()

	var result := MovingThingPhase.run(
		city,
		random,
		lfsr_random,
		game_random,
		ship_home,
		true,
		current_time_msec,
		traffic_news_deadline_msec,
		not vehicle_crashes_enabled
	)

	if not result.ok:
		return result

	var queue_update := _persist_news_result(result)

	if not queue_update.ok:
		return MovingThingResult.failure(queue_update.error)

	traffic_news_deadline_msec = result.traffic_news_deadline_msec

	for change in result.connection_count_changes:
		change_connection_count(change.kind, int(change.delta))

	for request in result.disaster_start_requests:
		pending_disaster_type = int(request.type)
		pending_disaster_point = request.point

	return result


# neighbor connection counts are process-local 16-bit values, as in the original.
# a load counts them. a bought connection, explosion damage and undo change them.
# `kind` is "commerce" or "industry"
func change_connection_count(kind: String, delta: int) -> void:
	if kind == "commerce":
		commerce_connections = (commerce_connections + delta) & 0xffff
	else:
		industry_connections = (industry_connections + delta) & 0xffff


func advance_day() -> SimulationDayResult:
	var span := SimulationTimingSpan.new(city.simulation_slice if city != null else null)
	var result := _timed_advance_day()

	if result.ok:
		var measured := span.finish()
		var scheduled := result.timing
		measured.steps = scheduled.steps
		measured.steps["day setup and events"] = maxi(0, int(measured.work_usec) - int(scheduled.work_usec))
		result.timing = measured

	return result


func _timed_advance_day() -> SimulationDayResult:
	if city == null or not city.is_valid():
		return SimulationDayResult.failure("city is invalid")

	if not pending_interaction.is_empty():
		return SimulationDayResult.failure("%s interaction is pending" % pending_interaction)

	if terminal_state:
		return SimulationDayResult.failure("the game has ended")

	if active_disaster_type != 0:
		return SimulationDayResult.failure("a disaster is active")

	var schedule := clock.advance_day()

	if not city.set_age_in_days(clock.city_days):
		return SimulationDayResult.failure("cannot store the new simulation day")

	if BudgetPhase.requires_annual_budget(city):
		pending_interaction = "annual_budget"
		pending_day_schedule = schedule

		var outcome := SimulationDayResult.new()
		outcome.ok = true
		outcome.day = clock.city_days
		outcome.schedule = schedule
		outcome.applied = PackedStringArray()
		outcome.pending = schedule.actions.duplicate()
		outcome.phase_results = {}
		outcome.interaction_requests = [SimulationInteractionRequest.annual_budget(BudgetPhase.funding_values(city))]
		outcome.complete = false
		outcome.error = ""

		return outcome

	return _append_pending_disaster(_run_day_schedule(schedule, false))


func resolve_annual_budget(funding_values: PackedInt32Array, auto_budget: bool) -> SimulationDayResult:
	var span := SimulationTimingSpan.new(city.simulation_slice if city != null else null)
	var result := _timed_resolve_annual_budget(funding_values, auto_budget)

	if result.ok:
		var measured := span.finish()
		var scheduled := result.timing
		measured.steps = scheduled.steps
		measured.steps["day setup and events"] = maxi(0, int(measured.work_usec) - int(scheduled.work_usec))
		result.timing = measured

	return result


func _timed_resolve_annual_budget(funding_values: PackedInt32Array, auto_budget: bool) -> SimulationDayResult:
	if pending_interaction != "annual_budget" or pending_day_schedule == null:
		return SimulationDayResult.failure("no annual budget interaction is pending")

	var stored := BudgetPhase.set_funding(city, funding_values, auto_budget)

	if not stored.ok:
		return SimulationDayResult.failure(stored.error)

	var result := _run_day_schedule(pending_day_schedule, true)

	if result.ok:
		pending_interaction = ""
		pending_day_schedule = null

	return _append_pending_disaster(result)


func resolve_military_proposal(accepted: bool) -> SimulationDayResult:
	var span := SimulationTimingSpan.new(city.simulation_slice if city != null else null)
	var result := _timed_resolve_military_proposal(accepted)

	if result.ok:
		var measured := span.finish()
		var scheduled := result.timing
		measured.steps = scheduled.steps
		measured.steps["day setup and events"] = maxi(0, int(measured.work_usec) - int(scheduled.work_usec))
		result.timing = measured

	return result


func _timed_resolve_military_proposal(accepted: bool) -> SimulationDayResult:
	if pending_interaction != "military_proposal" or pending_day_schedule == null:
		return SimulationDayResult.failure("no military proposal interaction is pending")

	var proposal := MilitaryProposalPhase.resolve(city, accepted, game_random, true)

	if not proposal.ok:
		return SimulationDayResult.failure(proposal.error)

	if proposal.notice_id >= 0:
		pending_interaction = "military_notice"
		pending_military_site = proposal.site if not proposal.complete else Rect2i()
		pending_military_base_type = proposal.base_type
		var result := SimulationDayResult.new()
		result.ok = true
		result.day = clock.city_days
		result.schedule = pending_day_schedule
		result.pending = pending_day_schedule.actions.duplicate()
		result.phase_results = {"military_proposal": proposal}
		result.interaction_requests = [SimulationInteractionRequest.new("military_notice")]
		return result

	return _complete_military_proposal(proposal)


func resolve_military_notice() -> SimulationDayResult:
	if pending_interaction != "military_notice" or pending_day_schedule == null:
		return SimulationDayResult.failure("no military notice is pending")

	var proposal := MilitaryProposalPhase.Result.new()
	proposal.ok = true
	proposal.base_type = pending_military_base_type

	if pending_military_site.has_area():
		proposal = MilitaryProposalPhase.reserve_land_site(city, pending_military_base_type, pending_military_site)

		if not proposal.ok:
			return SimulationDayResult.failure(proposal.error)

	pending_military_site = Rect2i()
	pending_military_base_type = 0
	return _complete_military_proposal(proposal)


func _complete_military_proposal(proposal: MilitaryProposalPhase.Result) -> SimulationDayResult:
	var original_schedule: SimulationSchedule = pending_day_schedule
	var remaining_schedule := _schedule_after(original_schedule, "milestones")
	pending_interaction = ""
	pending_day_schedule = null
	var result := _run_day_schedule(remaining_schedule, false)

	if not result.ok:
		return result

	var applied := PackedStringArray(["milestones"])
	applied.append_array(result.applied)
	var phase_results: Dictionary[String, PhaseResult] = {"military_proposal": proposal}

	for phase_name in result.phase_results:
		phase_results[phase_name] = result.phase_results[phase_name]

	result.schedule = original_schedule
	result.applied = applied
	result.phase_results = phase_results

	return _append_pending_disaster(result)


func advance_disaster_tick() -> DisasterMapResult:
	var span := SimulationTimingSpan.new(city.simulation_slice)
	var result := _timed_advance_disaster_tick()
	result.timing = span.finish()

	return result


func _timed_advance_disaster_tick() -> DisasterMapResult:
	if active_disaster_type == 0:
		return DisasterMapResult.failure("no disaster is active")

	var phase_result := DisasterMapScanDispatch.run_all(
		city, random, lfsr_random, disaster_map_counter, disaster_hurricane_counter
	)

	if not phase_result.ok:
		return phase_result

	disaster_map_counter = phase_result.map_counter
	disaster_hurricane_counter = phase_result.hurricane_counter
	var still_active: bool = bool(phase_result.active) or DisasterStartObjectsState.has_active_object(
		city, active_disaster_type
	)
	var ended_type := 0

	if not still_active:
		ended_type = active_disaster_type
		active_disaster_type = 0
		disaster_map_counter = 0
		disaster_hurricane_counter = 0

		var finished := DisasterEnd.finish(city, ended_type)

		if not finished.ok:
			return DisasterMapResult.failure(finished.error)

		phase_result.news_items.append_array(finished.news_items)
		phase_result.map_changed = phase_result.map_changed or finished.removed_units > 0
		phase_result.newspaper_requested = true
		phase_result.newspaper_paper = DisasterEnd.NEWSPAPER_PAPER

		if not city.document.set_misc_u32(Sc2MiscLayout.CITY_MODE, 1):
			return DisasterMapResult.failure("cannot restore city mode after the disaster")

	var queue_update := _persist_news_result(phase_result)

	if not queue_update.ok:
		return DisasterMapResult.failure(queue_update.error)

	phase_result.active = still_active
	phase_result.disaster_type = active_disaster_type if still_active else ended_type
	phase_result.ended_type = ended_type
	phase_result.complete = not still_active

	return phase_result


func start_disaster(disaster_type: int, point: Vector2i) -> DisasterStartResult:
	if city == null or not city.is_valid():
		return DisasterStartResult.failed("city is invalid")

	if terminal_state:
		return DisasterStartResult.failed("the game has ended")

	if not pending_interaction.is_empty():
		return DisasterStartResult.failed("%s interaction is pending" % pending_interaction)

	if active_disaster_type != 0:
		return DisasterStartResult.failed("a disaster is already active")

	var started := _start_disaster_phase(disaster_type, point)

	if not started.ok:
		return started

	if not started.started:
		if not started.complete:
			unsupported_disaster_type = disaster_type

		return started

	active_disaster_type = disaster_type
	disaster_map_counter = started.map_counter
	disaster_hurricane_counter = started.hurricane_counter
	unsupported_disaster_type = 0

	if not city.document.set_misc_u32(Sc2MiscLayout.CITY_MODE, 2):
		active_disaster_type = 0
		disaster_map_counter = 0
		disaster_hurricane_counter = 0

		return DisasterStartResult.failed("cannot store active disaster mode")

	var queue_update := _persist_news_result(started)

	if not queue_update.ok:
		return DisasterStartResult.failed(queue_update.error)

	# the original runs the first disaster update in the same step as the start
	started.first_update = advance_disaster_tick()

	if not started.first_update.ok:
		return DisasterStartResult.failed(started.first_update.error)

	return started


func recalculate_mayor_house() -> MayorApprovalPhase.Result:
	var result := MayorApprovalPhase.run(city, random, mayor_approval)

	if result.ok:
		mayor_approval = result.approval
		var queue_update := _persist_news_result(result)

		if not queue_update.ok:
			return MayorApprovalPhase.failed(queue_update.error)

	return result


func rotate_runtime_coordinates(counter_clockwise: bool) -> void:
	var map_edge: int = city.map_size if city != null else 128

	if ship_home.x >= 0 and ship_home.y >= 0:
		ship_home = _rotate_runtime_point(ship_home, counter_clockwise, map_edge)

	if pending_disaster_type != 0:
		pending_disaster_point = _rotate_runtime_point(
			pending_disaster_point, counter_clockwise, map_edge
		)


static func _rotate_runtime_point(point: Vector2i, counter_clockwise: bool, map_edge: int = 128) -> Vector2i:
	if counter_clockwise:
		return Vector2i(point.y, map_edge - 1 - point.x)

	return Vector2i(map_edge - 1 - point.y, point.x)


func _run_day_schedule(schedule: SimulationSchedule, annual_budget_approved: bool) -> SimulationDayResult:
	var span := SimulationTimingSpan.new(city.simulation_slice)
	var result := _execute_day_schedule(schedule, annual_budget_approved, span)
	result.timing = span.finish()

	return result


func _execute_day_schedule(schedule: SimulationSchedule, annual_budget_approved: bool, span: SimulationTimingSpan) -> SimulationDayResult:
	return SimulationDaySchedule._execute_day_schedule(self, schedule, annual_budget_approved, span)


func _schedule_after(schedule: SimulationSchedule, completed_action: String) -> SimulationSchedule:
	return SimulationDaySchedule._schedule_after(self, schedule, completed_action)


func _persist_news_result(result: PhaseResult) -> SimulationPhaseContext.NewsPersistenceResult:
	return SimulationDaySchedule._persist_news_result(self, result)


func _append_pending_disaster(result: SimulationDayResult) -> SimulationDayResult:
	if not result.ok or not result.interaction_requests.is_empty():
		return result

	if pending_disaster_type == 0:
		return result

	var disaster_type := pending_disaster_type
	pending_disaster_type = 0

	if not city.document.set_misc_u32(Sc2MiscLayout.DISASTER_TYPE, 0):
		return SimulationDayResult.failure("cannot clear the pending disaster type")

	var started := _start_disaster_phase(disaster_type, pending_disaster_point)

	if not started.ok:
		return SimulationDayResult.failure(started.error)

	var queue_update := _persist_news_result(started)

	if not queue_update.ok:
		return SimulationDayResult.failure(queue_update.error)

	result.phase_results["disaster_start"] = started

	if started.started:
		active_disaster_type = disaster_type
		disaster_map_counter = started.map_counter
		disaster_hurricane_counter = started.hurricane_counter

		if not city.document.set_misc_u32(Sc2MiscLayout.CITY_MODE, 2):
			return SimulationDayResult.failure("cannot store active disaster mode")

		result.applied.append("disaster_start")

		# the original runs the first disaster update in the same step as the start
		var first_update := advance_disaster_tick()

		if not first_update.ok:
			return SimulationDayResult.failure(first_update.error)

		result.disaster_results.append(first_update)
	elif not started.complete:
		unsupported_disaster_type = disaster_type
		result.pending.append("disaster_start")
		result.complete = false

	return result


func _start_disaster_phase(disaster_type: int, point: Vector2i) -> DisasterStartResult:
	var started := DisasterStartPhase.start(city, disaster_type, point, random, lfsr_random)
	return MaxisManResponse.apply(city, started, random, lfsr_random)
