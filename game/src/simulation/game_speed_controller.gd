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
const SPEED_NAMES := {
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
	return true


func speed_name() -> String:
	return SPEED_NAMES.get(speed, "Paused")


func advance_time(
	delta_msec: float, current_time_msec := -1, simulation_suspended := false
) -> Dictionary:
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
			if not moving.get("ok", false):
				result.error = moving.get("error", "moving-thing update failed")
				return result
			result.moving_results.append(moving)
			_append_runtime_events(result, moving)

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
		if speed != Speed.AFRICAN_SWALLOW:
			simulation_ready = false

	result.ok = true
	return result


func resolve_annual_budget(
	funding_values: PackedInt32Array, auto_budget: bool
) -> Dictionary:
	var result := _empty_result()
	if engine == null or not interaction_blocked:
		result.error = "no annual budget interaction is pending"
		return result
	var day := engine.resolve_annual_budget(funding_values, auto_budget)
	if not day.get("ok", false):
		result.error = day.get("error", "annual budget resolution failed")
		return result
	interaction_blocked = false
	_consume_day_result(result, day)
	result.ok = true
	return result


func resolve_military_proposal(accepted: bool) -> Dictionary:
	var result := _empty_result()
	if engine == null or not interaction_blocked:
		result.error = "no military proposal interaction is pending"
		return result
	var day := engine.resolve_military_proposal(accepted)
	if not day.get("ok", false):
		result.error = day.get("error", "military proposal resolution failed")
		return result
	interaction_blocked = false
	_consume_day_result(result, day)
	result.ok = true
	return result


func _is_day_due() -> bool:
	match speed:
		Speed.PAUSED:
			return subtick_counter == 0
		Speed.TURTLE:
			return (subtick_counter & 3) == 0
		Speed.LLAMA:
			return (subtick_counter & 1) == 0
		Speed.CHEETAH, Speed.AFRICAN_SWALLOW:
			return true
	return false


func _run_day(result: Dictionary) -> String:
	if engine.active_disaster_type != 0:
		if engine.active_disaster_type in [1, 12] and not original_compatibility:
			if fire_elapsed_msec < FIRE_TICK_MSEC:
				return ""
			fire_elapsed_msec = 0.0
		var disaster := engine.advance_disaster_tick()
		if not disaster.get("ok", false):
			return disaster.get("error", "disaster update failed")
		result.disaster_results.append(disaster)
		_append_runtime_events(result, disaster)
		return ""
	var day := engine.advance_day()
	if not day.get("ok", false):
		return day.get("error", "simulation day failed")
	_consume_day_result(result, day)
	return ""


func _consume_day_result(result: Dictionary, day: Dictionary) -> void:
	result.day_results.append(day)
	var requests: Array = day.get("interaction_requests", [])
	result.interaction_requests.append_array(requests)
	if not requests.is_empty():
		interaction_blocked = true
	for action in day.get("pending", PackedStringArray()):
		if not result.pending_actions.has(action):
			result.pending_actions.append(action)
	var phase_results: Dictionary = day.get("phase_results", {})
	for phase_name in phase_results:
		var phase_result: Dictionary = phase_results[phase_name]
		for refresh_request in phase_result.get("refresh_requests", []):
			if not result.refresh_requests.has(refresh_request):
				result.refresh_requests.append(refresh_request)
		result.effect_events.append_array(phase_result.get("effect_events", []))
		result.game_over_events.append_array(phase_result.get("game_over_events", []))
		if phase_name == "growth":
			result.effect_events.append_array(phase_result.get("bridge_effects", []))
		result.news_items.append_array(phase_result.get("news_items", []))
		result.sound_events.append_array(phase_result.get("sound_events", []))
		result.music_track_requests.append_array(
			phase_result.get("music_track_requests", PackedInt32Array())
		)
		result.view_center_requests.append_array(phase_result.get("view_center_requests", []))
	if not result.game_over_events.is_empty():
		terminal_blocked = true


func _append_runtime_events(result: Dictionary, phase_result: Dictionary) -> void:
	result.news_items.append_array(phase_result.get("news_items", []))
	result.effect_events.append_array(phase_result.get("effect_events", []))
	result.sound_events.append_array(phase_result.get("sound_events", []))
	result.view_center_requests.append_array(phase_result.get("view_center_requests", []))


func _empty_result() -> Dictionary:
	return {
		"ok": false,
		"error": "",
		"base_ticks": 0,
		"moving_results": [],
		"disaster_results": [],
		"day_results": [],
		"news_items": [],
		"effect_events": [],
		"sound_events": [],
		"music_track_requests": PackedInt32Array(),
		"view_center_requests": [],
		"refresh_requests": [],
		"interaction_requests": [],
		"game_over_events": [],
		"pending_actions": PackedStringArray(),
	}
