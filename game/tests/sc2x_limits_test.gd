extends SceneTree
## SC2X version 4 record budgets: a full facility pool is reported and never
## evicts a record, and dispatch stops at the moving-object budget. Original
## cities keep the original allocation.

var checks := 0
var failures := 0


func _initialize() -> void:
	_check_facility_pool()
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
	# a 16-tile city has 54 individual facility records
	var budget := 54
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
