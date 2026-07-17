extends SceneTree
## Check that CityState mirrors match their chunks after both commits and
## rollbacks. A stale mirror causes later growth and rendering errors.

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	for edge in [128, 256]:
		_check_moving_thing_tick(edge)

	_check_moving_thing_rollback()
	_check_growth_apply_payloads()
	_check_growth_apply_rollback()
	_check_growth_phase()
	_check_city_rotation()
	_check_display_copy_is_exempt()
	print("City mirror invariant: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


## Compare every mirror with the chunk it decodes. ALTM is the odd one: its
## mirror is a PackedInt32Array of big-endian words, not a byte copy.
func check_mirrors(city: CityState, context: String) -> void:
	for pair in [["XTER", city.terrain], ["XBLD", city.buildings], ["XZON", city.zones],
		["XUND", city.underground], ["XTXT", city.text_overlays], ["XBIT", city.tile_flags]]:
		var payload: PackedByteArray = city.document.find_chunk(str(pair[0])).decoded_payload
		check(pair[1] == payload, "%s: %s mirror matches its chunk" % [context, pair[0]])

	var altitude: PackedByteArray = city.document.find_chunk("ALTM").decoded_payload
	var words := PackedInt32Array()
	words.resize(city.map_size * city.map_size)

	for index in words.size():
		words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]

	check(city.altitude_words == words, "%s: ALTM mirror decodes its chunk" % context)


## A tornado writes XBLD, XZON, XBIT and MISC through the shared tick buffers,
## so one fixture covers both the quiet ticks and the damaging ones.
func tornado_city(edge: int) -> CityState:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))

	for x in range(50, 70):
		for y in range(50, 70):
			city.set_zone_id(x, y, 1)
			city.set_building_id(x, y, 0x70)
			city.set_building_corners(x, y, 0x80)
			city.set_tile_flag(x, y, 0xe0, true)

	var point := Vector2i(60, 60)
	var things := city.document.find_chunk("XTHG").decoded_payload.duplicate()
	var record := city.thing_count() - 1

	var fields := {0: 15, 1: 2, 2: 0, 3: point.x, 4: point.y, 5: 0, 6: 8, 7: 8, 10: 0}

	for field in fields:
		ThingData.write(things, record * 12 + field, fields[field])

	city.document.find_chunk("XTHG").set_decoded_payload(things)
	city.set_text_overlay_id(point.x, point.y, OverlayData.thing_id(record))

	return city


func _check_moving_thing_tick(edge: int) -> void:
	var city := tornado_city(edge)
	var budget := SimulationSliceBudget.new()
	budget.grant(60000000)
	city.simulation_slice = budget
	var random := SimRandom.new(123)
	var lfsr := SimLfsrRandom.new(7)
	var game := GameLcgRandom.new(9)
	var damaging_ticks := 0

	for tick in 20:
		var before := city.buildings.duplicate()
		var result := MovingThingPhase.run(city, random, lfsr, game)
		check(result.ok, "Moving-thing tick succeeds at edge %d" % edge)
		check_mirrors(city, "moving-thing tick %d at edge %d" % [tick, edge])

		if city.document.find_chunk("XBLD").decoded_payload != before:
			damaging_ticks += 1

	check(damaging_ticks > 0, "The tornado fixture commits map damage at edge %d" % edge)


## The commit loop writes XTHG before XTXT. Rejecting the XTXT write leaves an
## applied chunk to roll back, which is the case a chunk-id resync can miss.
func _check_moving_thing_rollback() -> void:
	var city := tornado_city(128)
	var random := SimRandom.new(123)
	var lfsr := SimLfsrRandom.new(7)
	var game := GameLcgRandom.new(9)
	check(MovingThingPhase.run(city, random, lfsr, game).ok, "Rollback fixture starts from a good tick")
	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")
	text_chunk.expected_decoded_size = text_chunk.decoded_payload.size() + 1
	var things_before := thing_chunk.decoded_payload.duplicate()
	var revision_before := thing_chunk.mutation_revision
	var result := MovingThingPhase.run(city, random, lfsr, game)
	check(not result.ok, "A rejected chunk write fails the moving-thing tick")
	check(thing_chunk.mutation_revision - revision_before == 2, "XTHG was written and then rolled back")
	check(thing_chunk.decoded_payload == things_before, "Rollback restores the committed chunk")
	check_mirrors(city, "moving-thing rollback")


func _check_growth_apply_payloads() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var payloads := GrowthState._payloads(city)
	check(not payloads.is_empty(), "Growth payloads decode")
	var rollback := GrowthState._duplicate_payloads(payloads)
	var index := 40 * 128 + 40
	payloads.XBLD[index] = 0x07
	payloads.ALTM[index * 2] = 0x01
	payloads.ALTM[index * 2 + 1] = 0x23
	var applied := GrowthState._apply_payloads(city, PackedStringArray(["XBLD", "ALTM"]), payloads, rollback)
	check(applied, "Growth commit succeeds")
	check(city.buildings[index] == 0x07, "The XBLD mirror carries the committed tile")
	check(city.altitude_words[index] == 0x0123, "The ALTM mirror carries the committed word")
	check_mirrors(city, "growth commit")


## The rollback path restores what it applied, not what it was asked to write.
func _check_growth_apply_rollback() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var payloads := GrowthState._payloads(city)
	var rollback := GrowthState._duplicate_payloads(payloads)
	var index := 40 * 128 + 40
	payloads.XBLD[index] = 0x07
	payloads.ALTM = PackedByteArray()
	var applied := GrowthState._apply_payloads(city, PackedStringArray(["XBLD", "ALTM"]), payloads, rollback)
	check(not applied, "A wrong-size payload fails the growth commit")
	check(city.document.find_chunk("XBLD").decoded_payload == rollback.XBLD, "Rollback restores XBLD")
	check(city.buildings[index] != 0x07, "The mirror follows the rollback, not the request")
	check_mirrors(city, "growth rollback")


func _check_growth_phase() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))

	for y in range(8, 24):
		city.set_zone_id(12, y, 1)
		city.set_building_id(12, y, 0x70)
		city.set_building_corners(12, y, 0x80)
		city.set_tile_flag(12, y, 0xe0, true)

	var budget := SimulationSliceBudget.new()
	budget.grant(60000000)
	city.simulation_slice = budget
	var growth := GrowthPhase.run(city, SimRandom.new(123), 0, 0, SimLfsrRandom.new(456), GameLcgRandom.new(789))
	check(growth.ok, "Growth phase succeeds")
	check_mirrors(city, "growth phase")


## A whole-map tool commit still has to leave every mirror, ALTM included, in
## step with the document.
func _check_city_rotation() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	city.set_land_altitude(10, 20, 7)
	city.set_building_id(30, 40, 0x07)
	check(CityRotationCommand.apply(city, false).ok, "City rotation succeeds")
	check_mirrors(city, "city rotation")


## CityViewFilter builds a display city whose mirrors deliberately diverge from
## the document it shares. Resyncing that copy would erase the filter.
func _check_display_copy_is_exempt() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	city.set_building_id(30, 40, 0xd2)
	var hidden := CityViewFilter.surface_copy(city, {"buildings": false})
	check(hidden.document == city.document, "The display copy shares the document")
	check(hidden.buildings[30 * 128 + 40] == 0, "The display copy hides the building")
	check(city.document.find_chunk("XBLD").decoded_payload[30 * 128 + 40] == 0xd2,
		"The display copy never writes its filtered view back to the chunk")
