extends SceneTree

class ProcessRandom extends SimRandom:
	var values: Array[int]
	var calls := 0

	func _init(sequence: Array[int]) -> void:
		values = sequence

	func next_u15() -> int:
		var value := values[calls % values.size()]
		calls += 1
		return value


class GateRandom extends SimLfsrRandom:
	var value := 0
	var calls := 0

	func _init(result := 0) -> void:
		value = result

	func next_mask(mask: int) -> int:
		calls += 1
		return value & mask


var checks := 0
var failures := 0


func _initialize() -> void:
	# Disaster selection and RNG gates do not depend on grid size or data-map mode.
	_test_gates(128, false)
	for edge in [128, 256, 384, 512]:
		for native in [false, true]:
			var types := range(1, 19) if edge == 128 and not native else [7]
			_test_targets(edge, native, types)
	# Exercise both object-record widths and the largest covered pool/coordinate range.
	for edge in [128, 512]:
		var native: bool = edge == 512
		_test_edges(edge, native)
		_test_pool(edge, native)
		_test_engine(edge, native)
	_test_extended_target()
	print("Automatic Maxis Man: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func fixture(edge: int, native: bool) -> CityState:
	var document := EmptyCityTemplate.create(edge)
	if native:
		document.enable_full_resolution_maps()
	document.set_misc_u32(0x0e4c, 1)
	return CityState.from_document(document)


func start_result(point: Vector2i, type := 1, record := 0) -> Dictionary:
	return {"ok": true, "started": true, "disaster_type": type, "point": point,
		"record": record, "sound_events": [520], "view_center_requests": [point]}


func _test_gates(edge: int, native: bool) -> void:
	var city := fixture(edge, native)
	for base in [0, 2, 3, 4, 5]:
		city.document.set_misc_u32(0x0e4c, base)
		var before: PackedByteArray = city.document.serialize().data
		var random := ProcessRandom.new([0])
		var gate := GateRandom.new()
		MaxisManResponse.apply(city, start_result(Vector2i(30, 30)), random, gate)
		check(random.calls == 0 and gate.calls == 0, "Only base state one consumes the gate")
		check(city.document.serialize().data == before, "Ineligible base preserves saved bytes")

	city.document.set_misc_u32(0x0e4c, 1)
	for outcome in 4:
		var copy := CityState.from_document(city.document.duplicate_document())
		var random := ProcessRandom.new([0])
		var gate := GateRandom.new(outcome)
		var result := MaxisManResponse.apply(copy, start_result(Vector2i(30, 30)), random, gate)
		check(result.has("maxis_man_response") == (outcome == 0), "Only one of four gate outcomes creates a hero")
		check(gate.calls == 1 and random.calls == (1 if outcome == 0 else 0), "Gate and arrival RNG order")
		if outcome != 0:
			check(copy.document.serialize().data == city.document.serialize().data, "Rejected gate preserves saved bytes")

	for state in [{"ok": false}, {"ok": true, "started": false}]:
		var random := ProcessRandom.new([0])
		var gate := GateRandom.new()
		MaxisManResponse.apply(city, state, random, gate)
		check(gate.calls == 0 and random.calls == 0, "Failed or inactive starts consume no response RNG")


func _test_targets(edge: int, native: bool, types: Array) -> void:
	var target := Vector2i(edge - 20, edge - 20)
	var goals := [255, 252, 254, 251, 255, 255, 2, 2, 255, 255, 255, 255, 254, 252, 251, 247, 247, 247]
	var base := fixture(edge, native)
	var point := target + Vector2i(16, 0)
	base.set_land_altitude(point.x, point.y, 7)
	base.set_water_altitude(point.x, point.y, 12)
	base.set_text_overlay_id(point.x, point.y, 61)
	for type in types:
		var city := CityState.from_document(base.document.duplicate_document())
		var things := city.document.find_chunk("XTHG").decoded_payload.duplicate()
		ThingData.write(things, 12 + 11, 247)
		ThingData.write(things, 24, 15 if type == 7 else 5)
		ThingData.write(things, 24 + 3, target.x)
		ThingData.write(things, 24 + 4, target.y)
		city.document.find_chunk("XTHG").set_decoded_payload(things)
		var random := ProcessRandom.new([0, 1])
		var result := MaxisManResponse.apply(city, start_result(target, type, 2), random, GateRandom.new())
		check(result.ok and result.maxis_man_response.record == 1, "First free record creates the hero")
		var saved := city.document.find_chunk("XTHG").decoded_payload
		var actual: Array[int] = []
		for field in 12:
			actual.append(ThingData.read(saved, 12 + field))
		check(actual == [16, 6, 0, point.x, point.y, 9, 8, 8, target.x, target.y, 61, goals[type - 1]],
			"Disaster %d stores original hero fields at edge %d" % [type, edge])
		check(random.calls == (2 if type in [3, 13] else 1), "Only riot target selection takes a second process value")
		check(city.text_overlay_id(point.x, point.y) == OverlayData.thing_id(1), "Hero is linked to its arrival tile")
		check(result.sound_events == [520, 513] and result.view_center_requests == [target, point], "Arrival events follow the disaster events")
		# Save encoding depends on format/size, not which disaster selected the goal.
		if type == types[-1]:
			var serialized: PackedByteArray = city.document.serialize().data
			var document := Sc2File.new()
			check(document.parse(serialized), "Automatic hero save parses")
			var loaded := CityState.from_document(document)
			check(loaded.is_valid() and loaded.document.serialize().data == serialized, "Automatic hero round trips without loss")
			check(loaded.text_overlays == city.text_overlays, "Reload preserves the hero link")


func _test_edges(edge: int, native: bool) -> void:
	for direction in 4:
		var city := fixture(edge, native)
		var point := Vector2i(edge - 1, edge - 1) if direction < 2 else Vector2i.ZERO
		var result := MaxisManResponse.apply(city, start_result(point, 3), ProcessRandom.new([direction, 0]), GateRandom.new())
		check(result.maxis_man_response.point == point, "Arrival offset clips at the true map edge")
		check(result.maxis_man_response.goal == 253, "Riot zero bit selects the other riot marker")


func _test_pool(edge: int, native: bool) -> void:
	for full in [false, true]:
		var city := fixture(edge, native)
		var things := city.document.find_chunk("XTHG").decoded_payload.duplicate()
		for record in range(1, ThingData.count(things)):
			ThingData.write(things, record * 12, 1 if full else (16 if record == ThingData.count(things) - 1 else 0))
		city.document.find_chunk("XTHG").set_decoded_payload(things)
		var before: PackedByteArray = city.document.serialize().data
		var random := ProcessRandom.new([0])
		var gate := GateRandom.new()
		var result := MaxisManResponse.apply(city, start_result(Vector2i(30, 30)), random, gate)
		check(not result.has("maxis_man_response"), "Full pool or existing hero prevents creation")
		check(gate.calls == 1 and random.calls == 0, "Pool rejection happens after gate and before arrival RNG")
		check(city.document.serialize().data == before, "Pool rejection preserves every saved byte")


func _test_engine(edge: int, native: bool) -> void:
	var city := fixture(edge, native)
	var copy := CityState.from_document(city.document.duplicate_document())
	var manual := SimulationEngine.new(city, 123, 2)
	var scheduled := SimulationEngine.new(copy, 123, 2)
	var target := Vector2i(edge - 30, edge - 30)
	var direct := manual.start_disaster(7, target)
	scheduled.pending_disaster_type = 7
	scheduled.pending_disaster_point = target
	var queued := scheduled._append_pending_disaster({"ok": true, "phase_results": {}, "applied": [], "pending": []})
	check(direct.ok and direct.has("maxis_man_response"), "Manual disaster starts automatic hero")
	check(queued.ok and queued.phase_results.disaster_start.has("maxis_man_response"), "Queued disaster starts automatic hero")
	check(city.document.serialize().data == copy.document.serialize().data, "Manual and queued paths publish identical city bytes")
	check(manual.random.state == scheduled.random.state and manual.lfsr_random.state == 4, "Both paths consume exactly one response gate")
	var before: PackedByteArray = city.document.serialize().data
	var seed := manual.random.state
	check(not manual.start_disaster(7, target).ok, "Active disaster rejects a second start")
	check(city.document.serialize().data == before and manual.random.state == seed and manual.lfsr_random.state == 4, "Rejected second start has no response side effects")
	var tick := manual.advance_moving_things(0)
	check(tick.ok and tick.malformed_records == 0, "Automatic hero runs through the normal moving-object update")

	var failed := SimulationEngine.new(fixture(edge, native), 123, 2)
	var no_plant := failed.start_disaster(9, target)
	check(no_plant.ok and not no_plant.started and failed.lfsr_random.state == 2, "Failed disaster does not attempt hero creation")

	var controller := GameSpeedController.new(SimulationEngine.new(fixture(edge, native), 123, 2))
	var snapshot := SimulationSnapshot.capture(controller, null)
	var response := snapshot.engine.start_disaster(7, target)
	check(response.has("maxis_man_response") and controller.engine.city.thing(2).type == 0, "Worker hero remains private until publication")
	SimulationSnapshot.publish(snapshot, controller)
	check(controller.engine.city.document.serialize().data == snapshot.engine.city.document.serialize().data, "Worker publication preserves hero bytes and links")
	check(controller.engine.random.state == snapshot.engine.random.state and controller.engine.lfsr_random.state == 4, "Worker publication preserves response RNG")


func _test_extended_target() -> void:
	var city := fixture(512, true)
	var things := city.document.find_chunk("XTHG").decoded_payload.duplicate()
	var record := 241
	check(ThingData.count(things) > record, "SC2X supports extended target records")
	ThingData.write(things, record * 12, 15)
	city.document.find_chunk("XTHG").set_decoded_payload(things)
	var response := MaxisManResponse.apply(city, start_result(Vector2i(400, 400), 7, record), ProcessRandom.new([0]), GateRandom.new())
	var goal: int = response.maxis_man_response.goal
	check(ThingData.is_record_target(goal) and ThingData.target_record(goal) == record, "Hero targets a high SC2X record without confusing disaster markers")
