class_name NativeSimulationBridge
extends RefCounted
## Calls the native simulation library and stores its results in GDScript objects.
## The native call receives copies of the saved chunks and returns the chunks it wrote.

# chunks that the native simulation reads. other chunks stay in the document only
const CHUNK_IDS: PackedStringArray = [
	"CNAM", "MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT",
	"XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG", "XGRP", "SCEN", "TEXT", "PICT", "TMPL",
]
# result classes by the name the native library sends in __class
static var classes := {
	"PhaseResult": PhaseResult,
	"GrowthResult": GrowthResult,
	"PollutionPhase.Result": PollutionPhase.Result,
	"NativeDataMapPhase.PollutionCoverageResult": NativeDataMapPhase.PollutionCoverageResult,
	"PowerPhase.Result": PowerPhase.Result,
	"WaterPhase.Result": WaterPhase.Result,
	"TrafficPhase.Result": TrafficPhase.Result,
	"BudgetPhase.Result": BudgetPhase.Result,
	"BankruptcyPhase.Result": BankruptcyPhase.Result,
	"CityValuePhase.Result": CityValuePhase.Result,
	"MonthStartPhase.Result": MonthStartPhase.Result,
	"MonthlyMusicResult": MonthlyMusicResult,
	"RciDemandPhase.Result": RciDemandPhase.Result,
	"RciAftermathPhase.Result": RciAftermathPhase.Result,
	"IndustryPhase.Result": IndustryPhase.Result,
	"SimNationPhase.Result": SimNationPhase.Result,
	"EducationHealthPhase.Result": EducationHealthPhase.Result,
	"GraphHistory.Result": GraphHistory.Result,
	"MilestonePhase.Result": MilestonePhase.Result,
	"ScenarioPhase.Result": ScenarioPhase.Result,
	"MicrosimAnnualPhase.Result": MicrosimAnnualPhase.Result,
	"EffectEvent": EffectEvent,
	"SimulationTiming": SimulationTiming,
}


# run one native operation on `city`. the random generators advance in place,
# and the written chunks replace the document chunks. returns the response
static func run(
	operation: String,
	city: CityState,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	game_random: GameLcgRandom,
	args := {},
) -> Dictionary:
	var request := {
		"op": operation,
		"city": city_fields(city),
		"randoms": PackedInt64Array([
			random.state if random != null else 1,
			lfsr_random.state if lfsr_random != null else 1,
			game_random.state if game_random != null else 1,
		]),
		# a subclass replaces the draws of its base class. the native
		# library then calls the subclass methods for each draw
		"scripts": [
			_script(random, SimRandom),
			_script(lfsr_random, SimLfsrRandom),
			_script(game_random, GameLcgRandom),
		],
		"args": args,
		# native loops park at frame boundaries with this lease
		"budget": city.simulation_slice.handle if city.simulation_slice != null else 0,
	}
	var response: Dictionary = NativeSimulation.run(request)

	if random != null and random.get_script() == SimRandom:
		random.state = response.randoms[0]

	if lfsr_random != null and lfsr_random.get_script() == SimLfsrRandom:
		lfsr_random.state = response.randoms[1]

	if game_random != null and game_random.get_script() == GameLcgRandom:
		game_random.state = response.randoms[2]

	apply_written(city, response.written)
	city.disaster_damage_class = response.disaster_damage_class
	response.result = decode(response.result)

	return response


static func _script(generator: RefCounted, base: Script) -> RefCounted:
	return generator if generator != null and generator.get_script() != base else null


static func city_fields(city: CityState) -> Dictionary:
	var chunks := {}

	for chunk_id in CHUNK_IDS:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk != null:
			chunks[chunk_id] = chunk.decoded_payload

	return {
		"map_size": city.map_size,
		"large_version": city.document.large_version,
		"disaster_damage_class": city.disaster_damage_class,
		"chunks": chunks,
	}


# store each written chunk and refresh its city mirror
static func apply_written(city: CityState, written: Dictionary) -> void:
	if written.is_empty():
		return

	var ids := PackedStringArray()

	for chunk_id: String in written:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk != null and chunk.set_decoded_payload(written[chunk_id], true):
			ids.append(chunk_id)

	city.resync_mirrors(ids)


# build result objects from native values. dictionaries with a __class key are objects
static func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("__class"):
			return _object(value)

		var result := {}

		for key: Variant in value:
			result[key] = decode(value[key])

		return result

	if value is Array:
		var result := []

		for item: Variant in value:
			result.append(decode(item))

		return result

	return value


static func _object(fields: Dictionary) -> Object:
	var object := _create(fields["__class"], fields)

	for name: String in fields:
		if name == "__class":
			continue

		var value: Variant = decode(fields[name])
		var current: Variant = object.get(name)

		# typed collections keep their element type when they receive the values
		if current is Array and value is Array:
			current.assign(value)
		elif current is Dictionary and value is Dictionary:
			current.assign(value)
		else:
			object.set(name, value)

	return object


static func _create(class_label: String, fields: Dictionary) -> Object:
	match class_label:
		"NewsEvent":
			return NewsEvent.new(fields.type, fields.argument)
		"SoundEvent":
			return SoundEvent.new(fields.sound_id)
		"GameOverEvent":
			return GameOverEvent.new(fields.type, fields.funds)
		"SimulationInteractionRequest":
			return SimulationInteractionRequest.new(fields.type)
		"PowerPlantExpiry":
			return PowerPlantExpiry.new(fields.record, fields.tile, Vector2i(fields.x, fields.y))
		"RciAftermathPhase.MapChange":
			return RciAftermathPhase.MapChange.new(fields.point, fields.old_tile, fields.new_tile)

	assert(classes.has(class_label), "Unknown native result class: %s" % class_label)

	return classes[class_label].new()
