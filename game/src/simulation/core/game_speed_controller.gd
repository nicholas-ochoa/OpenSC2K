class_name GameSpeedController
extends RefCounted

enum Speed {
	PAUSED = 1,
	TURTLE = 2,
	LLAMA = 3,
	CHEETAH = 4,
	AFRICAN_SWALLOW = 5,
}

const BASE_TICK_MSEC := 200.0
const SPEED_NAMES: Dictionary[int, String] = {
	Speed.PAUSED: "Paused",
	Speed.TURTLE: "Turtle",
	Speed.LLAMA: "Llama",
	Speed.CHEETAH: "Cheetah",
	Speed.AFRICAN_SWALLOW: "African Swallow",
}

var engine: SimulationEngine
var speed := Speed.PAUSED
var accumulator_msec := 0.0
var fire_elapsed_msec := 0.0
var original_compatibility := false
const FIRE_TICK_MSEC := 1000.0
var subtick_counter := 0
var simulation_ready := false
var interaction_blocked := false
var terminal_blocked := false
# city age in days at which the simulation pauses. -1 when there is no target
var pause_at_day := -1


func _init(initial_engine: SimulationEngine) -> void:
	engine = initial_engine

	if engine != null and engine.city != null:
		var saved_speed := engine.city.simulation_speed()

		if SPEED_NAMES.has(saved_speed):
			speed = saved_speed


func set_speed(value: int) -> bool:
	if not SPEED_NAMES.has(value):
		return false

	if engine == null or engine.city == null or not engine.city.is_valid():
		return false

	if not engine.city.set_simulation_speed(value):
		return false

	speed = value

	# a pause from any source cancels the target day
	if value == Speed.PAUSED:
		pause_at_day = -1

	return true


func speed_name() -> String:
	return SPEED_NAMES.get(speed, "Paused")


func advance_time(
	delta_msec: float, current_time_msec := -1, simulation_suspended := false
) -> SimulationTickResult:
	var result := _empty_result()

	if engine == null or engine.city == null or not engine.city.is_valid():
		result.error = "city is invalid"

		return result

	if delta_msec < 0.0:
		result.error = "elapsed time cannot be negative"

		return result

	if current_time_msec < 0:
		current_time_msec = Time.get_ticks_msec()

	accumulator_msec += delta_msec
	var ran_swallow_day := false

	while accumulator_msec >= BASE_TICK_MSEC:
		accumulator_msec -= BASE_TICK_MSEC
		result.base_ticks += 1
		subtick_counter = (subtick_counter + 1) & 7
		simulation_ready = simulation_ready or _is_day_due()

		if speed > Speed.PAUSED and not simulation_suspended and not interaction_blocked and not terminal_blocked:
			fire_elapsed_msec = minf(FIRE_TICK_MSEC, fire_elapsed_msec + BASE_TICK_MSEC) if engine.active_disaster_type in [1, 12] else 0.0

		var pulse_time := current_time_msec - int(accumulator_msec)

		if (
			speed > Speed.PAUSED
			and not simulation_suspended
			and not interaction_blocked
			and not terminal_blocked
		):
			var moving := engine.advance_moving_things(pulse_time)

			if not moving.ok:
				result.error = moving.error

				return result

			result.moving_results.append(moving)
			_append_moving_events(result, moving)

		if (
			speed > Speed.PAUSED
			and simulation_ready
			and not simulation_suspended
			and not interaction_blocked
			and not terminal_blocked
		):
			var day_error := _run_day(result)

			if not day_error.is_empty():
				result.error = day_error

				return result

			if _pause_on_target_day(result):
				break

			if speed == Speed.AFRICAN_SWALLOW:
				ran_swallow_day = true
			else:
				simulation_ready = false

	if (
		speed > Speed.PAUSED
		and simulation_ready
		and not ran_swallow_day
		and not simulation_suspended
		and not interaction_blocked
		and not terminal_blocked
	):
		var day_error := _run_day(result)

		if not day_error.is_empty():
			result.error = day_error

			return result

		_pause_on_target_day(result)

		if speed != Speed.AFRICAN_SWALLOW:
			simulation_ready = false

	result.ok = true

	return result


func resolve_annual_budget(
	funding_values: PackedInt32Array, auto_budget: bool
) -> SimulationTickResult:
	var result := _empty_result()

	if engine == null or not interaction_blocked:
		result.error = "no annual budget interaction is pending"

		return result

	var day := engine.resolve_annual_budget(funding_values, auto_budget)

	if not day.ok:
		result.error = day.error

		return result

	interaction_blocked = false
	_consume_day_result(result, day)
	result.ok = true

	return result


func resolve_military_proposal(accepted: bool) -> SimulationTickResult:
	var result := _empty_result()

	if engine == null or not interaction_blocked:
		result.error = "no military proposal interaction is pending"

		return result

	var day := engine.resolve_military_proposal(accepted)

	if not day.ok:
		result.error = day.error

		return result

	interaction_blocked = false
	_consume_day_result(result, day)
	result.ok = true

	return result


func resolve_military_notice() -> SimulationTickResult:
	var result := _empty_result()

	if engine == null or not interaction_blocked:
		result.error = "no military notice is pending"
		return result

	var day := engine.resolve_military_notice()

	if not day.ok:
		result.error = day.error
		return result

	interaction_blocked = false
	_consume_day_result(result, day)
	result.ok = true
	return result


# stop at the end of the target day. the remaining base ticks in this call do no work
func _pause_on_target_day(result: SimulationTickResult) -> bool:
	if pause_at_day < 0 or engine.city.age_in_days() < pause_at_day:
		return false

	result.paused_on_target_day = set_speed(Speed.PAUSED)
	pause_at_day = -1

	return true


# true when advance_time(delta_msec) runs a day or a disaster tick. the delta must not exceed one base tick
func tick_runs_day(delta_msec: float) -> bool:
	if simulation_ready:
		return true

	return accumulator_msec + delta_msec >= BASE_TICK_MSEC and _is_day_due((subtick_counter + 1) & 7)


func _is_day_due(counter := subtick_counter) -> bool:
	match speed:
		Speed.PAUSED:
			return counter == 0
		Speed.TURTLE:
			return (counter & 3) == 0
		Speed.LLAMA:
			return (counter & 1) == 0
		Speed.CHEETAH, Speed.AFRICAN_SWALLOW:
			return true

	return false


func _run_day(result: SimulationTickResult) -> String:
	if engine.active_disaster_type != 0:
		if engine.active_disaster_type in [1, 12] and not original_compatibility:
			if fire_elapsed_msec < FIRE_TICK_MSEC:
				return ""

			fire_elapsed_msec = 0.0

		var disaster := engine.advance_disaster_tick()

		if not disaster.ok:
			return disaster.error

		result.disaster_results.append(disaster)
		_append_runtime_events(result, disaster)

		return ""

	var day := engine.advance_day()

	if not day.ok:
		return day.error

	_consume_day_result(result, day)

	return ""


func _consume_day_result(result: SimulationTickResult, day: SimulationDayResult) -> void:
	result.day_results.append(day)
	var requests := day.interaction_requests
	result.interaction_requests.append_array(requests)

	if not requests.is_empty():
		interaction_blocked = true

	for action in day.pending:
		if not result.pending_actions.has(action):
			result.pending_actions.append(action)

	var phase_results := day.phase_results

	for phase_name in phase_results:
		var phase_result: PhaseResult = phase_results[phase_name]

		for refresh_request in phase_result.refresh_requests:
			if not result.refresh_requests.has(refresh_request):
				result.refresh_requests.append(refresh_request)

		result.effect_events.append_array(phase_result.effect_events)
		result.game_over_events.append_array(phase_result.game_over_events)

		if phase_result is GrowthResult:
			result.effect_events.append_array(phase_result.bridge_effects)

		result.news_items.append_array(phase_result.news_items)
		result.sound_events.append_array(phase_result.sound_events)
		result.music_track_requests.append_array(phase_result.music_track_requests)
		result.view_center_requests.append_array(phase_result.view_center_requests)
		result.notice_ids.append_array(phase_result.notice_ids)
		result.newspaper_requested = result.newspaper_requested or phase_result.newspaper_requested

	for event in result.game_over_events:
		terminal_blocked = terminal_blocked or event.is_terminal()
		interaction_blocked = true


func acknowledge_game_over() -> void:
	interaction_blocked = engine != null and not engine.pending_interaction.is_empty()


func _append_runtime_events(result: SimulationTickResult, phase_result: PhaseResult) -> void:
	result.news_items.append_array(phase_result.news_items)
	result.effect_events.append_array(phase_result.effect_events)
	result.sound_events.append_array(phase_result.sound_events)
	result.view_center_requests.append_array(phase_result.view_center_requests)


func _empty_result() -> SimulationTickResult:
	return SimulationTickResult.new()


func _append_moving_events(result: SimulationTickResult, moving: MovingThingResult) -> void:
	result.news_items.append_array(moving.news_items)
	result.effect_events.append_array(moving.effect_events)
	result.sound_events.append_array(moving.sound_events)
	result.view_center_requests.append_array(moving.view_center_requests)
