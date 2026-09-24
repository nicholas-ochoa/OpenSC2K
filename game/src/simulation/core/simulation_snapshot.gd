class_name SimulationSnapshot
extends RefCounted

const ENGINE_FIELDS := [
	"city_status_resource_id", "ship_home", "developed_tiles", "power_usage_percent", "water_usage_percent",
	"commerce_connections", "industry_connections", "traffic_news_deadline_msec",
	"pending_interaction", "pending_day_schedule", "terminal_state", "bus_passengers",
	"rail_passengers", "subway_passengers", "mayor_approval", "pending_disaster_type",
	"pending_disaster_point", "active_disaster_type", "unsupported_disaster_type",
	"disaster_map_counter", "disaster_hurricane_counter", "midi_playback_active",
	"vehicle_crashes_enabled",
	"pending_military_site", "pending_military_base_type",
]
const CONTROLLER_FIELDS := [
	"speed", "accumulator_msec", "fire_elapsed_msec", "subtick_counter", "original_compatibility",
	"simulation_ready", "interaction_blocked", "terminal_blocked", "pause_at_day",
]


static func capture(source: GameSpeedController, budget: SimulationSliceBudget) -> GameSpeedController:
	var original := source.engine.city
	var city := CityState.new()
	city.document = original.document.duplicate_document(true)
	city.map_size = original.map_size
	city.load_error = original.load_error

	original.copy_mirrors_to(city)

	city.simulation_slice = budget
	city.disaster_damage_class = original.disaster_damage_class
	var engine := SimulationEngine.new(null)
	engine.city = city
	copy_engine(source.engine, engine)

	var controller := GameSpeedController.new(engine)
	_copy_fields(source, controller, CONTROLLER_FIELDS)

	return controller


static func publish(completed: GameSpeedController, target: GameSpeedController) -> void:
	var city := target.engine.city
	var document := city.document
	var updated := completed.engine.city

	for index in document.chunks.size():
		var from := updated.document.chunks[index]
		var into := document.chunks[index]

		if from.mutation_revision != into.mutation_revision:
			into.decoded_payload = from.decoded_payload
			into.is_dirty = from.is_dirty
			into.mutation_revision = from.mutation_revision

	updated.copy_mirrors_to(city, true)
	city.disaster_damage_class = updated.disaster_damage_class

	copy_engine(completed.engine, target.engine)
	_copy_fields(completed, target, CONTROLLER_FIELDS)


static func stamp(source: GameSpeedController) -> Array:
	var engine := source.engine
	var doc := engine.city.document
	var result: Array = [doc.get_instance_id(), engine.clock.city_days, engine.random.state, engine.lfsr_random.state, engine.game_random.state]

	for chunk in doc.chunks:
		result.append(chunk.get_instance_id())
		result.append(chunk.mutation_revision)

	for field in ENGINE_FIELDS + CONTROLLER_FIELDS:
		var value: Variant = engine.get(field) if field in ENGINE_FIELDS else source.get(field)
		if value is SimulationSchedule:
			result.append(value.stamp())
		else:
			result.append(value.duplicate(true) if value is Dictionary else value)

	return result


static func copy_engine(source: SimulationEngine, target: SimulationEngine) -> void:
	_copy_fields(source, target, ENGINE_FIELDS)
	target.scenario = ScenarioState.from_document(target.city.document) if source.scenario != null else null
	target.clock.city_days = source.clock.city_days
	target.random.state = source.random.state
	target.lfsr_random.state = source.lfsr_random.state
	target.game_random.state = source.game_random.state


static func _copy_fields(source: Object, target: Object, fields: Array) -> void:
	for field in fields:
		var value: Variant = source.get(field)
		if value is SimulationSchedule:
			target.set(field, value.copy())
		else:
			target.set(field, value.duplicate(true) if value is Dictionary else value)
