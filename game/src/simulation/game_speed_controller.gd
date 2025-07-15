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
var subtick_counter := 0
var simulation_ready := false


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


func advance_time(delta_msec: float, current_time_msec := -1) -> Dictionary:
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
		var pulse_time := current_time_msec - int(accumulator_msec)

		if speed > Speed.PAUSED:
			var moving := engine.advance_moving_things(pulse_time)
			if not moving.get("ok", false):
				result.error = moving.get("error", "moving-thing update failed")
				return result
			result.moving_results.append(moving)
			_append_runtime_events(result, moving)

		if speed > Speed.PAUSED and simulation_ready:
			var day_error := _run_day(result)
			if not day_error.is_empty():
				result.error = day_error
				return result
			if speed == Speed.AFRICAN_SWALLOW:
				ran_swallow_day = true
			else:
				simulation_ready = false

	if speed > Speed.PAUSED and simulation_ready and not ran_swallow_day:
		var day_error := _run_day(result)
		if not day_error.is_empty():
			result.error = day_error
			return result
		if speed != Speed.AFRICAN_SWALLOW:
			simulation_ready = false

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
	var day := engine.advance_day()
	if not day.get("ok", false):
		return day.get("error", "simulation day failed")
	result.day_results.append(day)
	for action in day.get("pending", PackedStringArray()):
		if not result.pending_actions.has(action):
			result.pending_actions.append(action)
	var growth: Dictionary = day.get("phase_results", {}).get("growth", {})
	if not growth.is_empty():
		result.effect_events.append_array(growth.get("bridge_effects", []))
		result.news_items.append_array(growth.get("news_items", []))
		result.sound_events.append_array(growth.get("sound_events", []))
		result.view_center_requests.append_array(growth.get("view_center_requests", []))
	return ""


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
		"day_results": [],
		"news_items": [],
		"effect_events": [],
		"sound_events": [],
		"view_center_requests": [],
		"pending_actions": PackedStringArray(),
	}
