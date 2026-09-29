extends SceneTree
## SC2X version 4 record budgets: a full facility pool is reported and never
## evicts a record, and dispatch stops at the moving-object budget. Original
## cities keep the original allocation.

var checks := 0
var failures := 0


func _initialize() -> void:
	_check_facility_pool()
	_check_arcology_keeps_other_records()
	_check_dispatch_budget()
	print("SC2X limits: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func _fill(city: CityState, count: int, tile_id: int) -> void:
	var chunk := city.document.find_chunk("XMIC")
	var records := chunk.decoded_payload.duplicate()

	for record in range(BuildingCommand.MICROSIM_DYNAMIC_FIRST, BuildingCommand.MICROSIM_DYNAMIC_FIRST + count):
		records[record * CityState.MICROSIM_RECORD_SIZE] = tile_id

	chunk.set_decoded_payload(records)


func _check_facility_pool() -> void:
	var city := CityState.from_document(Sc2xDocument.create_empty(16).document)
	var budget := BuildingFacilities.individual_record_budget(city.document)
	_check(budget == 54, "A 16-tile city has 54 individual facility records")
	city.set_funds(1000000)
	_fill(city, budget - 1, BuildingTileIds.HOSPITAL)
	var last := BuildingCommand.apply(
		city, CityToolIds.Group.SERVICES, CityToolIds.Services.POLICE_STATION, Vector2i(4, 4), SimLfsrRandom.new(1), SimRandom.new(1))
	_check(last.ok and OverlayData.is_facility(city.text_overlay_id(4, 4)), "The last record under the budget is used")
	var before := city.document.find_chunk("XBLD").decoded_payload.duplicate()
	var full := BuildingCommand.apply(
		city, CityToolIds.Group.SERVICES, CityToolIds.Services.POLICE_STATION, Vector2i(9, 9), SimLfsrRandom.new(1), SimRandom.new(1))
	_check(not full.ok and full.error.contains("facility records are in use"), "A full pool is reported to the player")
	_check(city.document.find_chunk("XBLD").decoded_payload == before, "A full pool builds nothing without a record")
	var shared := BuildingCommand.apply(
		city, CityToolIds.Group.EDUCATION, CityToolIds.Education.LIBRARY, Vector2i(12, 12), SimLfsrRandom.new(1), SimRandom.new(1))
	_check(shared.ok, "Shared categories keep their own slots when the pool is full")

	# an original city keeps the original allocation
	var original := CityState.from_document(EmptyCityTemplate.create(128))
	_check(BuildingFacilities.individual_record_budget(original.document) < 0
		and BuildingFacilities.record_available(original.document.find_chunk("XMIC").decoded_payload, BuildingTileIds.POLICE_STATION, -1),
		"Original cities have no record budget")


func _check_arcology_keeps_other_records() -> void:
	var city := CityState.from_document(Sc2xDocument.create_empty(16).document)
	var records := city.document.find_chunk("XMIC").decoded_payload.duplicate()
	var capacity := records.size() / CityState.MICROSIM_RECORD_SIZE

	for record in range(BuildingCommand.MICROSIM_DYNAMIC_FIRST, capacity):
		records[record * CityState.MICROSIM_RECORD_SIZE] = BuildingTileIds.HOSPITAL

	var labels := city.document.find_chunk("XLAB").decoded_payload.duplicate()
	var overlays := city.text_overlays.duplicate()
	var sc2x_id := BuildingFacilities.provision_microsim(records.duplicate(), labels, overlays, BuildingTileIds.PLYMOUTH_ARCOLOGY,
		2050, SimRandom.new(1), city.document.find_chunk("MISC").decoded_payload, false, false,
		BuildingFacilities.individual_record_budget(city.document))
	_check(sc2x_id == 0, "An SC2X arcology never takes the record of another facility")
	var legacy_id := BuildingFacilities.provision_microsim(records.duplicate(), labels, overlays, BuildingTileIds.PLYMOUTH_ARCOLOGY,
		2050, SimRandom.new(1), city.document.find_chunk("MISC").decoded_payload)
	_check(legacy_id != 0, "The original allocation still replaces a record for an arcology")


func _check_dispatch_budget() -> void:
	var city := CityState.from_document(Sc2xDocument.create_empty(16).document)
	var chunk := city.document.find_chunk("XTHG")
	var things := chunk.decoded_payload.duplicate()
	var budget := DispatchCommand._thing_budget(city)
	_check(budget == 15, "A 16-tile city can use 15 moving-object records")

	for record in range(1, budget):
		ThingData.write(things, record * Sc2ThingLayout.RECORD_SIZE, Sc2ThingLayout.Type.SHIP)

	_check(DispatchCommand._first_free_thing(things, budget) == budget, "The last record under the budget is free")
	ThingData.write(things, budget * Sc2ThingLayout.RECORD_SIZE, Sc2ThingLayout.Type.SHIP)
	_check(DispatchCommand._first_free_thing(things, budget) < 0, "A pool at its budget has no free record")

	# an imported table can be larger than its budget
	var imported := PackedByteArray()
	imported.resize(32 * Sc2ThingLayout.EXTENDED_RECORD_SIZE)

	for record in range(1, 16):
		ThingData.write(imported, record * Sc2ThingLayout.RECORD_SIZE, Sc2ThingLayout.Type.SHIP)

	_check(DispatchCommand._first_free_thing(imported, budget) < 0, "An over-budget import allows no new object")
	ThingData.write(imported, Sc2ThingLayout.RECORD_SIZE, 0)
	_check(DispatchCommand._first_free_thing(imported, budget) == 1, "Removing an object below the budget allows a new one")
	_check(DispatchCommand._first_free_thing(imported) == 1, "Original cities use any free record")
