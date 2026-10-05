# gdstyle:ignore-file=quality/max-class-variables
class_name SimulationEngine
extends RefCounted


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
# the base type of a debug proposal, or 0 for the game rules. the answer clears it
var forced_military_base_type := 0
var scenario: ScenarioState
var terminal_state := false
var bus_passengers := 0
var rail_passengers := 0
var subway_passengers := 0
var mayor_approval := 0
var pending_disaster_type := 0
var pending_disaster_point := Vector2i.ZERO
var active_disaster_type := 0
# the unit counts that the last disaster start fixed, and a count of those starts
var dispatch_capacity := DispatchCommand.NO_CAPACITY
var dispatch_epoch := 0
var unsupported_disaster_type := 0
var disaster_map_counter := 0
var disaster_hurricane_counter := 0
# true when the last disaster scan found a fire marker. riots, crashes, and
# earthquakes also start fires, so the fire pace does not use the disaster type
var disaster_fire_active := false
var midi_playback_active := false
# runtime only; never saved. false while the player hides the vehicle layer:
# airplanes and helicopters then leave instead of crashing, as with no disasters
var vehicle_crashes_enabled := true
# true demolishes the launch arcologies in timed batches for every city
# format. false keeps the original launch, which demolishes them all in the
# annual update
var stage_arcology_launch := true
# true from a staged launch until its last launch. the days wait
var arcology_launch_active := false
# runtime only; never saved. the launch arcologies that wait to ignite, and
# the launch steps until the last flight ends. a load or a rotation scans the
# map again
var arcology_launch_sites: Array[Vector2i] = []
var arcology_launch_wait := 0


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


# Engine fields that the native engine reads and writes. SimulationSnapshot
# copies them too
const STATE_FIELDS := [
	"developed_tiles", "power_usage_percent", "water_usage_percent", "bus_passengers", "rail_passengers",
	"subway_passengers", "ship_home", "city_status_resource_id", "commerce_connections", "industry_connections",
	"mayor_approval", "midi_playback_active", "pending_disaster_type", "pending_disaster_point", "terminal_state",
	"traffic_news_deadline_msec", "stage_arcology_launch", "pending_interaction", "pending_military_site",
	"pending_military_base_type", "forced_military_base_type", "active_disaster_type", "unsupported_disaster_type",
	"disaster_map_counter", "disaster_hurricane_counter", "disaster_fire_active", "dispatch_epoch",
	"vehicle_crashes_enabled", "arcology_launch_active", "arcology_launch_sites", "arcology_launch_wait",
]


func advance_moving_things(current_time_msec := -1) -> MovingThingResult:
	if current_time_msec < 0:
		current_time_msec = Time.get_ticks_msec()

	return run("engine.advance_moving_things", {"current_time_msec": current_time_msec})


# neighbor connection counts are process-local 16-bit values, as in the original.
# a load counts them. a bought connection, disaster damage and undo change them.
# `kind` is "commerce" or "industry"
func change_connection_count(kind: String, delta: int) -> void:
	if kind == "commerce":
		commerce_connections = (commerce_connections + delta) & 0xffff
	else:
		industry_connections = (industry_connections + delta) & 0xffff


func advance_day() -> SimulationDayResult:
	if city == null or not city.is_valid():
		return SimulationDayResult.failure("city is invalid")

	return run("engine.advance_day")


func resolve_annual_budget(funding_values: PackedInt32Array, auto_budget: bool) -> SimulationDayResult:
	return run("engine.resolve_annual_budget", {"values": funding_values, "auto_budget": auto_budget})


func resolve_military_proposal(accepted: bool) -> SimulationDayResult:
	return run("engine.resolve_military_proposal", {"accepted": accepted})


func resolve_military_notice() -> SimulationDayResult:
	return run("engine.resolve_military_notice")


func advance_disaster_tick() -> DisasterMapResult:
	return run("engine.advance_disaster_tick")


# the point that a Disasters or Debug menu item of SIMCITY.EXE gives a disaster
# (0x0040f5b0 to 0x0040f7b0 and 0x00412340 to 0x004124a0). some items draw
# process random values. `fallback` is for the types without a menu item and
# for Air Crash and Hurricane, whose starts do not use the point
func menu_disaster_point(disaster_type: int, fallback: Vector2i) -> Vector2i:
	return run("engine.menu_disaster_point", {"disaster_type": disaster_type, "fallback": fallback})


func start_disaster(disaster_type: int, point: Vector2i) -> DisasterStartResult:
	if city == null or not city.is_valid():
		return DisasterStartResult.failed("city is invalid")

	return run("engine.start_disaster", {"disaster_type": disaster_type, "point": point})


func recalculate_mayor_house() -> MayorApprovalPhase.Result:
	return run("engine.recalculate_mayor_house")


func rotate_runtime_coordinates(counter_clockwise: bool) -> void:
	var map_edge: int = city.map_size if city != null else 128

	if ship_home.x >= 0 and ship_home.y >= 0:
		ship_home = _rotate_runtime_point(ship_home, counter_clockwise, map_edge)

	# the next launch step scans the rotated map
	arcology_launch_sites.clear()
	arcology_launch_wait = 0

	if pending_disaster_type != 0:
		pending_disaster_point = _rotate_runtime_point(
			pending_disaster_point, counter_clockwise, map_edge
		)


static func _rotate_runtime_point(point: Vector2i, counter_clockwise: bool, map_edge: int = 128) -> Vector2i:
	if counter_clockwise:
		return Vector2i(point.y, map_edge - 1 - point.x)

	return Vector2i(map_edge - 1 - point.y, point.x)


# run `steps` steps of a staged arcology launch
func advance_arcology_launch(steps: int) -> MicrosimAnnualPhase.LaunchStep:
	return run("engine.advance_arcology_launch", {"steps": steps})


# the original loads a city file, then scans power and water and counts the
# developed tiles. the power scan uses the process random state
func initialize_loaded_city() -> bool:
	if city == null or not city.is_valid():
		return false

	return run("engine.initialize")


# Run an engine operation of the native simulation library with the engine
# state, and keep the state that it returns. See sc2k_game::engine.
func run(operation: String, args := {}, controller: GameSpeedController = null) -> Variant:
	args["engine"] = state()
	args["scenario"] = ScenarioPhase.fields(scenario) if scenario != null else {}
	args["detailed"] = SimulationTimingSpan.detailed

	if controller != null:
		args["controller"] = controller.state()

	var response := NativeSimulationBridge.run(operation, city, random, lfsr_random, game_random, args)
	var outcome: Dictionary = response.result
	apply_state(outcome.engine)

	if not outcome.scenario_present:
		scenario = null
	elif scenario != null:
		scenario.time_limit_months = outcome.scenario_time_limit

	if controller != null:
		controller.apply_state(outcome.controller)

	return outcome.result


# The engine fields, the clock, and the pending schedule.
func state() -> Dictionary:
	var result := {}

	for field in STATE_FIELDS:
		result[field] = get(field)

	# the native library reads untyped arrays
	result.arcology_launch_sites = Array(arcology_launch_sites)
	result.city_days = clock.city_days
	result.dispatch_capacity = PackedInt32Array([dispatch_capacity.x, dispatch_capacity.y, dispatch_capacity.z])
	result.pending_day_schedule = _schedule_fields(pending_day_schedule)

	return result


func apply_state(fields: Dictionary) -> void:
	for field in STATE_FIELDS:
		if field == "arcology_launch_sites":
			arcology_launch_sites.assign(fields[field])
		else:
			set(field, fields[field])

	clock.city_days = fields.city_days
	var capacity: PackedInt32Array = fields.dispatch_capacity
	dispatch_capacity = Vector3i(capacity[0], capacity[1], capacity[2])
	pending_day_schedule = fields.pending_day_schedule


static func _schedule_fields(schedule: SimulationSchedule) -> Dictionary:
	if schedule == null:
		return {}

	return {
		"city_days": schedule.city_days, "elapsed_years": schedule.elapsed_years, "month": schedule.month,
		"month_day": schedule.month_day, "season": schedule.season, "actions": schedule.actions,
		"growth_step": schedule.growth_step, "growth_substep": schedule.growth_substep,
	}
