class_name Sc2xCheckpoint
extends RefCounted
## The simulation state that an SC2X version 4 file saves in metadata. MISC and
## the other structures hold the city; these values belong to the engine and
## the speed controller. A save happens at a completed simulation day: a day
## that waits for the player, such as the annual budget, cannot be saved.
##
## Saved: the three random states and the `phase_state` keys of
## Sc2xMetadata.PHASE_KEYS, including the results of the load scan. A city with saved phase state resumes without
## a new load scan, so the scan does not draw from the random states again.
## Not saved: frame timing accumulators, the fire timer, the traffic news
## deadline (a process clock), music playback, the vehicle layer switch, and
## pause targets.

# Empty when the engine is at a completed day and can be saved
static func save_error(controller: GameSpeedController) -> String:
	if controller == null or controller.engine == null:
		return ""

	var pending := controller.engine.pending_interaction

	if not pending.is_empty():
		return "Finish the %s before saving the city." % pending.replace("_", " ")

	return ""


# Store the engine state in `metadata`. Unknown phase_state keys stay.
static func capture(controller: GameSpeedController, metadata: Sc2xMetadata) -> void:
	if controller == null or controller.engine == null or metadata == null:
		return

	var engine := controller.engine
	metadata.process_random = engine.random.state & 0xffffffff
	# the lfsr never leaves zero; the loader rejects it
	metadata.lfsr_random = engine.lfsr_random.state if engine.lfsr_random.state != 0 else 1
	metadata.game_random = engine.game_random.state & 0xffffffff
	var state := metadata.phase_state.duplicate(true)
	state["ship_home"] = [engine.ship_home.x, engine.ship_home.y]
	state["commerce_connections"] = engine.commerce_connections
	state["industry_connections"] = engine.industry_connections
	state["bus_passengers"] = engine.bus_passengers
	state["rail_passengers"] = engine.rail_passengers
	state["subway_passengers"] = engine.subway_passengers
	state["mayor_approval"] = engine.mayor_approval
	state["pending_disaster_type"] = engine.pending_disaster_type
	state["pending_disaster_point"] = [engine.pending_disaster_point.x, engine.pending_disaster_point.y]
	state["active_disaster_type"] = engine.active_disaster_type
	state["unsupported_disaster_type"] = engine.unsupported_disaster_type
	state["disaster_map_counter"] = engine.disaster_map_counter
	state["disaster_hurricane_counter"] = engine.disaster_hurricane_counter
	state["terminal_state"] = engine.terminal_state
	state["subtick_counter"] = controller.subtick_counter
	state["simulation_ready"] = controller.simulation_ready
	state["developed_tiles"] = engine.developed_tiles
	state["power_usage_percent"] = engine.power_usage_percent
	state["water_usage_percent"] = engine.water_usage_percent
	state["city_status_resource_id"] = engine.city_status_resource_id
	metadata.phase_state = state


# Restore the engine state of a loaded file. Returns an error for a value of
# the wrong type; the engine then keeps the values of a fresh load.
# True when a file holds the load-scan results, so the load does not scan again
static func has_saved_state(metadata: Sc2xMetadata) -> bool:
	return metadata != null and not metadata.phase_state.is_empty()


static func restore(controller: GameSpeedController, metadata: Sc2xMetadata) -> String:
	if controller == null or controller.engine == null or metadata == null:
		return ""

	var engine := controller.engine
	var state := metadata.phase_state
	var error := validate(state)

	if not error.is_empty():
		return error

	engine.random.state = metadata.process_random
	engine.lfsr_random.state = metadata.lfsr_random
	engine.game_random.state = metadata.game_random

	if state.is_empty():
		return ""

	engine.ship_home = _point(state.ship_home)
	engine.commerce_connections = int(state.commerce_connections)
	engine.industry_connections = int(state.industry_connections)
	engine.bus_passengers = int(state.bus_passengers)
	engine.rail_passengers = int(state.rail_passengers)
	engine.subway_passengers = int(state.subway_passengers)
	engine.mayor_approval = int(state.mayor_approval)
	engine.pending_disaster_type = int(state.pending_disaster_type)
	engine.pending_disaster_point = _point(state.pending_disaster_point)
	engine.active_disaster_type = int(state.active_disaster_type)
	engine.unsupported_disaster_type = int(state.unsupported_disaster_type)
	engine.disaster_map_counter = int(state.disaster_map_counter)
	engine.disaster_hurricane_counter = int(state.disaster_hurricane_counter)
	engine.terminal_state = bool(state.terminal_state)
	controller.subtick_counter = int(state.subtick_counter) & 7
	controller.simulation_ready = bool(state.simulation_ready)
	controller.terminal_blocked = engine.terminal_state
	engine.developed_tiles = int(state.developed_tiles)
	engine.power_usage_percent = int(state.power_usage_percent)
	engine.water_usage_percent = int(state.water_usage_percent)
	engine.city_status_resource_id = int(state.city_status_resource_id)

	return ""


static func validate(state: Dictionary) -> String:
	return Sc2xMetadata.phase_state_error(state)


static func _point(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))
