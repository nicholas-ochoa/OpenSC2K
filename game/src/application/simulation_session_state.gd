class_name SimulationSessionState
extends RefCounted


const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")

var simulation_engine: SimulationEngine
var speed_controller: GameSpeedController
var frame_simulation: FrameSimulationRunner
var nuisance_random := GameRandom.new(Time.get_ticks_msec() | 1)
var simulation_map_dirty := false
# pending simulation prompts
var annual_budget_pending := false
var military_proposal_pending := false
var game_over_active := false
