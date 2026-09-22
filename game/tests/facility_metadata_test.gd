extends SceneTree
## Exercise the shared facility definitions through their city consumers.

@warning_ignore_start("integer_division")

# Independent saved tile IDs and query kinds. Hydro variants share kind 21.
const FACILITIES := [
	[0xc6, 21], [0xc7, 21], [0xc8, 20], [0xc9, 1], [0xca, 1],
	[0xcb, 1], [0xcc, 1], [0xcd, 1], [0xce, 1], [0xcf, 1],
	[0xd0, 2], [0xd1, 3], [0xd2, 4], [0xd3, 5], [0xd4, 23],
	[0xd5, 22], [0xd6, 6], [0xd7, 7], [0xd8, 8], [0xd9, 9],
	[0xda, 10], [0xdb, 11], [0xe9, 19], [0xec, 17], [0xed, 18],
	[0xf3, 12], [0xf4, 13], [0xf5, 24], [0xf8, 25], [0xfa, 14],
	[0xfb, 15], [0xfc, 15], [0xfd, 15], [0xfe, 15], [0xff, 16],
]
# Tool group, subtool, saved tile ID, budget record index.
const BUDGET_FACILITIES := [
	[13, 2, 0xd1, 7], [13, 0, 0xd2, 5], [13, 1, 0xd3, 6],
	[12, 0, 0xd6, 8], [12, 1, 0xd9, 9],
]
const POINT := Vector2i(8, 8)

var checks := 0
var failures := 0


func _initialize() -> void:
	for entry in FACILITIES:
		_check_facility(entry[0], entry[1])

	_check_unknown_tile()
	_check_budgets_and_demolition()
	print("Facility metadata: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func _stamp(city: CityState, tile: int) -> void:
	var area := DemolishStructures.structure_area(tile)
	var site := Rect2i(POINT, Vector2i(area, area))
	var buildings := city.buildings.duplicate()
	var zones := city.zones.duplicate()

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			buildings[x * city.map_size + y] = tile

	BuildingSites.set_corners(zones, site, area, city.compass_rotation(), city.map_size)
	_check(city.replace_buildings(buildings), "Store generated facility footprint")
	_check(city.replace_zones(zones), "Store generated facility corners")


func _check_facility(tile: int, kind: int) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	_stamp(city, tile)
	var microsims := city.document.find_chunk("XMIC").decoded_payload.duplicate()
	var labels := city.document.find_chunk("XLAB").decoded_payload.duplicate()
	var overlays := city.text_overlays.duplicate()
	var record := 10 if kind <= 16 else kind - 16
	var expected_label := record + 51
	var label := BuildingFacilities.provision_microsim(microsims, labels, overlays,
		tile, 1900, SimRandom.new(1), city.document.find_chunk("MISC").decoded_payload)
	_check(label == expected_label, "Tile %02x uses its dynamic or shared record" % tile)
	_check(microsims[record * 8] == tile, "Provision stores tile %02x in XMIC" % tile)
	_check(city.document.find_chunk("XMIC").set_decoded_payload(microsims), "Store provisioned XMIC")
	_check(city.document.find_chunk("XLAB").set_decoded_payload(labels), "Store provisioned XLAB")
	_check(city.set_text_overlay_id(POINT.x, POINT.y, label), "Link provisioned facility")
	var query := QueryInfo.inspect(city, POINT)
	_check(query.ok and query.kind == "specific" and query.microsim_type == kind,
		"Query resolves provisioned tile %02x to kind %d" % [tile, kind])

	var repair_city := CityState.from_document(EmptyCityTemplate.create(16))
	_stamp(repair_city, tile)
	var repair := FacilityRecordRepair.apply(repair_city)
	_check(repair.ok and repair.created == 1 and repair.linked == 1,
		"Repair creates missing record for tile %02x" % tile)
	_check(repair_city.text_overlay_id(POINT.x, POINT.y) == expected_label,
		"Repair selects the same record for tile %02x" % tile)
	query = QueryInfo.inspect(repair_city, POINT)
	_check(query.ok and query.microsim_type == kind, "Query resolves repaired tile %02x" % tile)


func _check_unknown_tile() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	_stamp(city, 0x06)
	var microsims := city.document.find_chunk("XMIC").decoded_payload.duplicate()
	var labels := city.document.find_chunk("XLAB").decoded_payload.duplicate()
	var overlays := city.text_overlays.duplicate()
	var before := [microsims.duplicate(), labels.duplicate(), overlays.duplicate()]
	var random := SimRandom.new(19)
	var label := BuildingFacilities.provision_microsim(microsims, labels, overlays,
		0x06, 1900, random, city.document.find_chunk("MISC").decoded_payload)
	_check(label == 0 and random.state == 19, "Unknown facility does not allocate or consume RNG")
	_check([microsims, labels, overlays] == before, "Unknown facility preserves all record buffers")
	_check(FacilityRecordRepair.apply(city).linked == 0, "Repair ignores a tree")
	_check(QueryInfo.inspect(city, POINT).kind == "general", "Tree retains a general query")
	# A saved link with a non-facility tile keeps the established kind-zero fallback.
	microsims[10 * 8] = 0x06
	_check(city.document.find_chunk("XMIC").set_decoded_payload(microsims), "Store unknown linked tile")
	_check(city.set_text_overlay_id(POINT.x, POINT.y, 61), "Store unknown facility link")
	var query := QueryInfo.inspect(city, POINT)
	_check(query.ok and query.kind == "specific" and query.microsim_type == 0,
		"Unknown saved facility uses the query fallback")


func _check_budgets_and_demolition() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	var random := SimRandom.new(7)
	var lfsr := SimLfsrRandom.new(11)

	for entry in BUDGET_FACILITIES:
		var before := city.document.serialize().data
		var command := BuildingCommand.apply(city, entry[0], entry[1], POINT, lfsr, random)
		_check(command.ok, "Place budget facility %02x: %s" % [entry[2], command.error])

		if not command.ok:
			continue

		_check(city.building_id(POINT.x, POINT.y) == entry[2], "Tool selects the expected facility")

		for budget in 16:
			_check(city.document.misc_u32(0x077c + budget * 0x6c) == (1 if budget == entry[3] else 0),
				"Facility %02x updates only budget %d" % [entry[2], entry[3]])

		var placed := city.document.serialize().data
		var demolition := DemolishCommand.apply_path(city, 0, 0, [POINT], random)
		_check(demolition.ok, "Demolish budget facility")
		_check(city.text_overlay_id(POINT.x, POINT.y) == 0, "Demolition removes the facility link")
		_check(DemolishCommand.undo(city, demolition, random).ok, "Undo facility demolition")
		_check(city.document.serialize().data == placed, "Demolition undo restores the city bytes")
		_check(BuildingCommand.undo(city, command, lfsr, random).ok, "Undo facility placement")
		_check(city.document.serialize().data == before, "Placement undo restores the city bytes")
		_check(random.state == 7 and lfsr.state == 11, "Placement undo restores both RNG states")

	var before := city.document.serialize().data
	var park := BuildingCommand.apply(city, 14, 0, POINT, lfsr, random)
	_check(park.ok, "Place a building without a facility budget category")

	for budget in 16:
		_check(city.document.misc_u32(0x077c + budget * 0x6c) == 0, "Small park leaves budgets unchanged")

	_check(BuildingCommand.undo(city, park, lfsr, random).ok, "Undo small park")
	_check(city.document.serialize().data == before, "Small park undo preserves city bytes")
