class_name NativeSimulationBridge
extends RefCounted
## Calls the native simulation library and stores its results in GDScript objects.
## The native call receives copies of the saved chunks and returns the chunks it wrote.

@warning_ignore_start("integer_division")

# the integers of one effect in a packed effect list
const EFFECT_STRIDE := 14
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
	"MicrosimAnnualPhase.LaunchStep": MicrosimAnnualPhase.LaunchStep,
	"WeatherDisasterPhase.Result": WeatherDisasterPhase.Result,
	"DisasterStartResult": DisasterStartResult,
	"DisasterStartResult.MaxisManArrival": DisasterStartResult.MaxisManArrival,
	"DisasterMapResult": DisasterMapResult,
	"DisasterEnd.Result": DisasterEnd.Result,
	"MovingThingResult": MovingThingResult,
	"MayorApprovalPhase.Result": MayorApprovalPhase.Result,
	"MilitaryProposalPhase.Result": MilitaryProposalPhase.Result,
	"TransportTripResult": TransportTripResult,
	"TransportTripReachResult": TransportTripReachResult,
	"EffectEvent": EffectEvent,
	"SimulationTiming": SimulationTiming,
	"RouteEditResult": RouteEditResult,
	"TunnelEditResult": TunnelEditResult,
	"OnrampEditResult": OnrampEditResult,
	"HydroEditResult": HydroEditResult,
	"SubwayToRailEditResult": SubwayToRailEditResult,
	"BuildingEditResult": BuildingEditResult,
	"ZoneEditResult": ZoneEditResult,
	"ZoneCommand.Preview": ZoneCommand.Preview,
	"DemolishEditResult": DemolishEditResult,
	"TerrainEditResult": TerrainEditResult,
	"LandscapeEditResult": LandscapeEditResult,
	"ScurkPlaceResult": ScurkPlaceResult,
	"FacilityRecordRepair.Result": FacilityRecordRepair.Result,
	"BondCommand.Result": BondCommand.Result,
	"OrdinanceCommand.Result": OrdinanceCommand.Result,
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
	commit_order := PackedStringArray(),
) -> Dictionary:
	if city.native_cache == null:
		city.native_cache = CityCacheHandle.new()

	var request := {
		"op": operation,
		"cache": city.native_cache.handle,
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

	response.failed_chunk = apply_written(city, response.written, commit_order, response.revisions)
	city.disaster_damage_class = response.disaster_damage_class
	response.result = decode(response.result)

	if not response.failed_chunk.is_empty() and response.result is Object and "ok" in response.result:
		response.result.ok = false
		response.result.error = "cannot store %s" % response.failed_chunk

	return response


static func _script(generator: RefCounted, base: Script) -> RefCounted:
	return generator if generator != null and generator.get_script() != base else null


static func city_fields(city: CityState) -> Dictionary:
	var chunks := {}
	var revisions := {}

	for chunk_id in CHUNK_IDS:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk != null:
			chunks[chunk_id] = chunk.decoded_payload
			revisions[chunk_id] = chunk.mutation_revision

	return {
		"map_size": city.map_size,
		"large_version": city.document.large_version,
		"disaster_damage_class": city.disaster_damage_class,
		"chunks": chunks,
		"revisions": revisions,
	}


# store each written chunk in `order`, then the others, and refresh their city
# mirrors. a rejected store restores the chunks already stored and returns the
# rejected chunk id. `revisions` gives the native revision of each written chunk
static func apply_written(city: CityState, written: Dictionary, order := PackedStringArray(), revisions := {}) -> String:
	if written.is_empty():
		return ""

	var ids := PackedStringArray()
	var originals := {}

	for chunk_id in order:
		if written.has(chunk_id):
			ids.append(chunk_id)

	for chunk_id: String in written:
		if not ids.has(chunk_id):
			ids.append(chunk_id)

	var applied := PackedStringArray()

	for chunk_id in ids:
		var chunk := city.document.find_chunk(chunk_id)
		var original := chunk.decoded_payload if chunk != null else PackedByteArray()

		if chunk == null or not chunk.set_decoded_payload(written[chunk_id], true):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(originals[rollback_id])

			city.resync_mirrors(applied)

			return chunk_id

		originals[chunk_id] = original
		applied.append(chunk_id)

		# the native cache holds these bytes with this revision
		if revisions.has(chunk_id):
			chunk.mutation_revision = revisions[chunk_id]

	city.resync_mirrors(applied)

	if applied.has("XTHG"):
		city.document.reconcile_object_identities()

	return ""


# build result objects from native values. dictionaries with a __class key are objects
static func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("__class"):
			# a large demolition returns an effect for each tile, as one packed list
			if value["__class"] == "EffectEventList":
				return _effect_event_list(value)

			if value["__class"] == "EffectEvent":
				return _effect_event(value)

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


# 14 integers for each effect, in the order of native effect_packing.rs
static func _effect_event_list(fields: Dictionary) -> Array[EffectEvent]:
	var values: PackedInt64Array = fields.values
	var types: PackedStringArray = fields.types
	var events: Array[EffectEvent] = []
	events.resize(values.size() / EFFECT_STRIDE)

	for index in events.size():
		var at := index * EFFECT_STRIDE
		var event := EffectEvent.new(Vector2i(values[at + 1], values[at + 2]), values[at + 3],
			Vector2i(values[at + 4], values[at + 5]), values[at + 6] != 0, values[at + 7], values[at + 8])
		event.type = types[values[at]]
		event.frames = values[at + 9]
		event.frame_msec = values[at + 10]
		event.distance = values[at + 11]
		event.depth_point = Vector2i(values[at + 12], values[at + 13])
		events[index] = event

	return events


# the native library sends every field of an effect event
static func _effect_event(fields: Dictionary) -> EffectEvent:
	var event := EffectEvent.new(fields.point, fields.sprite_id, fields.screen_offset, fields.flip, fields.frame, fields.altitude)
	event.type = fields.type
	event.frames = fields.frames
	event.frame_msec = fields.frame_msec
	event.distance = fields.distance
	event.depth_point = fields.depth_point

	return event


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
		"MovingThingResult.ConnectionChange":
			return MovingThingResult.ConnectionChange.new(fields.kind, fields.delta, fields.point)
		"MovingThingResult.DisasterRequest":
			return MovingThingResult.DisasterRequest.new(fields.type, fields.point)
		"TransportTripReachResult.ReachNode":
			return TransportTripReachResult.ReachNode.new(fields.point, fields.mode, fields.cost)
		"TransportTripReachResult.Link":
			return TransportTripReachResult.Link.new(fields.from, fields.to, fields.from_mode, fields.mode, fields.cost)
		"BridgeChoice":
			return BridgeChoice.new(fields.type, fields.name, fields.cost_per_tile, fields.cost)
		"RciAftermathPhase.MapChange":
			return RciAftermathPhase.MapChange.new(fields.point, fields.old_tile, fields.new_tile)

	assert(classes.has(class_label), "Unknown native result class: %s" % class_label)

	return classes[class_label].new()
