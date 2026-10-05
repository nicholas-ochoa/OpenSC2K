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
# a disaster scan waits this long while a fire burns, for every city format.
# the original redraws the whole map after each scan, so its pace depends on the PC
const FIRE_TICK_MSEC := 1000.0
# a staged arcology launch ignites one arcology and launches one in each step
const LAUNCH_STEP_MSEC := 50.0
# the most launch steps that one call runs after a slow frame
const LAUNCH_MAX_STEPS := 4

var engine: SimulationEngine
var speed := Speed.PAUSED
var accumulator_msec := 0.0
var fire_elapsed_msec := 0.0
var launch_elapsed_msec := 0.0
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
			speed = saved_speed as Speed


func set_speed(value: int) -> bool:
	if not SPEED_NAMES.has(value):
		return false

	if engine == null or engine.city == null or not engine.city.is_valid():
		return false

	if not engine.city.set_simulation_speed(value):
		return false

	speed = value as Speed

	# a pause from any source cancels the target day
	if value == Speed.PAUSED:
		pause_at_day = -1

	return true


func speed_name() -> String:
	return SPEED_NAMES.get(speed, "Paused")


# Run the base ticks of `delta_msec` frame time: moving objects on each tick,
# and days at the pace of the speed. The native simulation library runs them;
# see native/core/game/src/speed.rs.
func advance_time(
	delta_msec: float, current_time_msec := -1, simulation_suspended := false
) -> SimulationTickResult:
	var invalid := _invalid_result()

	if invalid != null:
		return invalid

	if current_time_msec < 0:
		current_time_msec = Time.get_ticks_msec()

	return engine.run("game.advance_time", {
		"delta_msec": delta_msec, "current_time_msec": current_time_msec, "suspended": simulation_suspended,
	}, self)


func resolve_annual_budget(
	funding_values: PackedInt32Array, auto_budget: bool
) -> SimulationTickResult:
	if engine == null:
		return _failed("no annual budget interaction is pending")

	return engine.run("game.resolve_annual_budget", {"values": funding_values, "auto_budget": auto_budget}, self)


func resolve_military_proposal(accepted: bool) -> SimulationTickResult:
	if engine == null:
		return _failed("no military proposal interaction is pending")

	return engine.run("game.resolve_military_proposal", {"accepted": accepted}, self)


func resolve_military_notice() -> SimulationTickResult:
	if engine == null:
		return _failed("no military notice is pending")

	return engine.run("game.resolve_military_notice", {}, self)


# one day or disaster tick now, as the debug step of a day
func run_day() -> SimulationTickResult:
	return engine.run("game.run_day", {}, self)


# part of a day, as the debug step of a phase. `first` asks for the annual
# budget first; `last` starts the disaster that the day left pending
func step_schedule(schedule: SimulationSchedule, first: bool, last: bool) -> SimulationTickResult:
	return engine.run("game.step_schedule", {
		"schedule": SimulationEngine._schedule_fields(schedule), "first": first, "last": last,
	}, self)


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


# the original drops African Swallow to Cheetah when a disaster starts
# (0x00406a50). true when the speed changed
func slow_for_disaster() -> bool:
	if speed != Speed.AFRICAN_SWALLOW:
		return false

	return set_speed(Speed.CHEETAH)


func acknowledge_game_over() -> void:
	interaction_blocked = engine != null and not engine.pending_interaction.is_empty()


# The controller fields that the native speed controller reads and writes.
func state() -> Dictionary:
	return {
		"speed": speed, "accumulator_msec": accumulator_msec, "fire_elapsed_msec": fire_elapsed_msec,
		"launch_elapsed_msec": launch_elapsed_msec, "subtick_counter": subtick_counter,
		"simulation_ready": simulation_ready, "interaction_blocked": interaction_blocked,
		"terminal_blocked": terminal_blocked, "pause_at_day": pause_at_day,
	}


func apply_state(fields: Dictionary) -> void:
	speed = fields.speed as Speed
	accumulator_msec = fields.accumulator_msec
	fire_elapsed_msec = fields.fire_elapsed_msec
	launch_elapsed_msec = fields.launch_elapsed_msec
	subtick_counter = fields.subtick_counter
	simulation_ready = fields.simulation_ready
	interaction_blocked = fields.interaction_blocked
	terminal_blocked = fields.terminal_blocked
	pause_at_day = fields.pause_at_day


func _invalid_result() -> SimulationTickResult:
	if engine == null or engine.city == null or not engine.city.is_valid():
		return _failed("city is invalid")

	return null


func _failed(message: String) -> SimulationTickResult:
	var result := SimulationTickResult.new()
	result.error = message

	return result
