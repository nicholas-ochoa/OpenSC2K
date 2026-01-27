class_name SimulationSnapshot
extends RefCounted

const ENGINE_FIELDS := [
	"ship_home", "developed_tiles", "power_usage_percent", "water_usage_percent",
	"commerce_connections", "industry_connections", "traffic_news_deadline_msec",
	"pending_interaction", "pending_day_schedule", "terminal_state", "bus_passengers",
	"rail_passengers", "subway_passengers", "mayor_approval", "pending_disaster_type",
	"pending_disaster_point", "active_disaster_type", "unsupported_disaster_type",
	"disaster_map_counter", "disaster_hurricane_counter", "midi_playback_active",
]
const CONTROLLER_FIELDS := [
	"speed", "accumulator_msec", "fire_elapsed_msec", "subtick_counter",
	"simulation_ready", "interaction_blocked", "terminal_blocked",
]
const CITY_ARRAYS := ["altitude_words", "terrain", "buildings", "zones", "underground", "text_overlays", "tile_flags"]

static func capture(source: GameSpeedController, budget: SimulationSliceBudget) -> GameSpeedController:
	var original := source.engine.city
	var city := CityState.new()
	city.document = original.document.duplicate_document()
	city.map_size = original.map_size
	city.load_error = original.load_error
	for field in CITY_ARRAYS:
		city.set(field, original.get(field).duplicate())
	city.simulation_slice = budget
	var engine := SimulationEngine.new(null)
	engine.city = city
	copy_engine(source.engine, engine)
	if source.engine.scenario != null:
		engine.scenario = ScenarioState.from_document(city.document)
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
	for field in CITY_ARRAYS:
		city.set(field, updated.get(field))
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
		result.append(value.duplicate(true) if value is Dictionary else value)
	return result

static func copy_engine(source: SimulationEngine, target: SimulationEngine) -> void:
	_copy_fields(source, target, ENGINE_FIELDS)
	target.clock.city_days = source.clock.city_days
	target.random.state = source.random.state
	target.lfsr_random.state = source.lfsr_random.state
	target.game_random.state = source.game_random.state

static func _copy_fields(source: Object, target: Object, fields: Array) -> void:
	for field in fields:
		var value: Variant = source.get(field)
		target.set(field, value.duplicate(true) if value is Dictionary else value)
