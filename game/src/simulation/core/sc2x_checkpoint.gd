class_name Sc2xCheckpoint
extends RefCounted
## The simulation state that an SC2X version 4 file saves in metadata. MISC and
## the other structures hold the city; these values belong to the engine and
## the speed controller. A save happens at a completed simulation day: a day
## that waits for the player, such as the annual budget, cannot be saved.
##
## Saved: the three random states, the `phase_state` keys of
## Sc2xMetadata.PHASE_KEYS, including the results of the load scan, the dropped
## disaster tick, and whether a staged arcology launch is in progress. A city with
## saved phase state resumes without a new load scan, so the scan does not
## draw from the random states again. A file without phase state still
## restores its random states before the load scan.
## Not saved: frame timing accumulators, the traffic news deadline (a process
## clock), music playback, the vehicle layer switch, and pause targets.

# Empty when the engine is at a completed day and can be saved
static func save_error(controller: GameSpeedController) -> String:
	if controller == null or controller.engine == null:
		return ""

	return NativeSimulation.checkpoint_save_error(controller.engine.pending_interaction)


# Store the engine state in `metadata`. Unknown phase_state keys stay. See
# native/core/game/src/checkpoint.rs
static func capture(controller: GameSpeedController, metadata: Sc2xMetadata) -> void:
	if controller == null or controller.engine == null or metadata == null:
		return

	var engine := controller.engine
	var randoms := PackedInt64Array([engine.random.state, engine.lfsr_random.state, engine.game_random.state])
	var saved := NativeSimulation.checkpoint_capture(engine.state(), controller.state(), randoms, metadata.phase_state)
	var saved_randoms: PackedInt64Array = saved.randoms
	metadata.process_random = saved_randoms[0]
	metadata.lfsr_random = saved_randoms[1]
	metadata.game_random = saved_randoms[2]
	metadata.phase_state = saved.phase_state


# True when a file holds the load-scan results, so the load does not scan again
static func has_saved_state(metadata: Sc2xMetadata) -> bool:
	return metadata != null and not metadata.phase_state.is_empty()


# Restore the engine state of a loaded file. Returns an error for a value of
# the wrong type; the engine then keeps the values of a fresh load.
static func restore(controller: GameSpeedController, metadata: Sc2xMetadata) -> String:
	if controller == null or controller.engine == null or metadata == null:
		return ""

	var engine := controller.engine
	var randoms := PackedInt64Array([metadata.process_random, metadata.lfsr_random, metadata.game_random])
	var restored := NativeSimulation.checkpoint_restore(engine.state(), controller.state(), randoms, metadata.phase_state)

	if not str(restored.error).is_empty():
		return restored.error

	restore_random(engine, metadata)
	engine.apply_state(restored.engine)
	controller.apply_state(restored.controller)

	return ""


# The random states of a loaded file. A load restores them before the load scan.
static func restore_random(engine: SimulationEngine, metadata: Sc2xMetadata) -> void:
	if engine == null or metadata == null:
		return

	engine.random.state = metadata.process_random
	engine.lfsr_random.state = metadata.lfsr_random
	engine.game_random.state = metadata.game_random


static func validate(state: Dictionary) -> String:
	return Sc2xMetadata.phase_state_error(state)
